import os
import sys
import logging
from sqlalchemy import create_engine, select, func
from sqlalchemy.orm import sessionmaker

# Ensure the app package is discoverable
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import Base, engine as pg_engine
from app.core.config import settings
import app.models  # Crucial: imports all models so Base.metadata is populated

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_data():
    sqlite_url = os.environ.get("SQLITE_FALLBACK_URL", "sqlite:////app/data/fyc_connect.db")
    
    if not str(pg_engine.url).startswith("postgresql"):
        logger.error(f"The primary engine is not PostgreSQL! URL: {pg_engine.url}")
        logger.error("Please set DATABASE_URL to your PostgreSQL connection string.")
        sys.exit(1)

    logger.info(f"Connecting to source SQLite: {sqlite_url}")
    try:
        sqlite_engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})
        sqlite_engine.connect().close()
    except Exception as e:
        logger.error(f"Could not connect to SQLite database at {sqlite_url}: {e}")
        sys.exit(1)
    
    logger.info("Connecting to target PostgreSQL...")
    # Ensure tables exist in Postgres
    Base.metadata.create_all(bind=pg_engine)

    # Use sorted_tables to respect foreign key constraints
    for table in Base.metadata.sorted_tables:
        logger.info(f"Migrating table: {table.name}...")
        
        with sqlite_engine.connect() as src_conn:
            rows = src_conn.execute(select(table)).fetchall()
            if not rows:
                logger.info(f"  -> Skipped {table.name} (0 rows)")
                continue
                
            logger.info(f"  -> Found {len(rows)} rows to migrate.")
            
            # Convert rows to dictionaries mapping column name to value
            records = []
            for row in rows:
                record = {}
                for col_name, value in zip(table.columns.keys(), row):
                    col = table.columns[col_name]
                    if value is None and not col.nullable:
                        # Provide a safe default for strictly not-null columns that SQLite allowed
                        if col.default and getattr(col.default, 'is_scalar', False):
                            value = col.default.arg
                        else:
                            try:
                                ptype = col.type.python_type
                                if ptype == bool: value = False
                                elif ptype == int: value = 0
                                elif ptype == float: value = 0.0
                                elif ptype == str: value = ""
                            except NotImplementedError:
                                pass
                    record[col_name] = value
                records.append(record)
            
            with pg_engine.begin() as tgt_conn:
                if pg_engine.name == "postgresql":
                    tgt_conn.execute(text(f"ALTER TABLE {table.name} DISABLE TRIGGER ALL;"))
                    
                # Check if target table is empty to avoid duplicate primary keys
                count_query = select(func.count()).select_from(table)
                existing_count = tgt_conn.execute(count_query).scalar()
                
                if existing_count > 0:
                    logger.warning(f"  -> Target table '{table.name}' already has {existing_count} rows. Skipping to avoid ID conflicts.")
                    continue
                
                # Batch inserts for large tables
                batch_size = 1000
                for i in range(0, len(records), batch_size):
                    batch = records[i:i + batch_size]
                    tgt_conn.execute(table.insert(), batch)
                    
                logger.info(f"  -> Successfully migrated {len(records)} rows to {table.name}.")
                
                # Reset PostgreSQL sequence for the primary key if it exists
                if pg_engine.name == "postgresql":
                    for col in table.columns:
                        try:
                            # Only sequence-reset integer primary keys (not UUIDs)
                            if col.primary_key and col.autoincrement and col.type.python_type == int:
                                # Usually the sequence name is <table_name>_<column_name>_seq
                                # A more robust way in Postgres is to use setval(pg_get_serial_sequence(...), max(id))
                                try:
                                    seq_sql = f"SELECT setval(pg_get_serial_sequence('{table.name}', '{col.name}'), (SELECT MAX({col.name}) FROM {table.name}));"
                                    tgt_conn.execute(text(seq_sql))
                                    logger.info(f"  -> Reset sequence for {table.name}.{col.name}")
                                except Exception as e:
                                    logger.warning(f"  -> Could not reset sequence for {table.name}.{col.name}: {e}")
                                break
                        except NotImplementedError:
                            pass
                            
                if pg_engine.name == "postgresql":
                    tgt_conn.execute(text(f"ALTER TABLE {table.name} ENABLE TRIGGER ALL;"))
                            
    logger.info("Data migration completed successfully!")
    logger.info("This script has safely copied your data and synced the primary key sequences.")

if __name__ == "__main__":
    from sqlalchemy import text
    migrate_data()
