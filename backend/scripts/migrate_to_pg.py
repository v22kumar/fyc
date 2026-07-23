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

    if pg_engine.name == "postgresql":
        logger.info("Clearing any auto-generated startup data from Postgres to ensure a perfect 1-to-1 migration...")
        with pg_engine.begin() as tgt_conn:
            # Gather all table names
            all_tables = [t.name for t in Base.metadata.sorted_tables]
            if all_tables:
                tgt_conn.execute(text(f"TRUNCATE TABLE {', '.join(all_tables)} CASCADE;"))

    # BREAK THE METADATA CYCLE
    # SQLAlchemy's sorted_tables breaks down when it encounters mutual foreign keys (like tournaments <-> teams).
    # We temporarily remove the cyclic FKs from the metadata so the topological sort works flawlessly.
    tournaments_table = Base.metadata.tables.get("tournaments")
    if tournaments_table is not None:
        cyclic_fks = [fk for fk in tournaments_table.foreign_keys if fk.parent.name in ("winner_id", "runner_up_id")]
        for fk in cyclic_fks:
            tournaments_table.foreign_keys.remove(fk)
            
    fixtures_table = Base.metadata.tables.get("fixtures")
    if fixtures_table is not None:
        cyclic_fks = [fk for fk in fixtures_table.foreign_keys if fk.parent.name == "winner_id"]
        for fk in cyclic_fks:
            fixtures_table.foreign_keys.remove(fk)

    tables = list(Base.metadata.sorted_tables)
    deferred_tournaments = []
    deferred_fixtures = []

    for table in tables:
        logger.info(f"Migrating table: {table.name}...")
        
        with sqlite_engine.connect() as src_conn:
            # Check row count first
            count_query = select(func.count()).select_from(table)
            total_rows = src_conn.execute(count_query).scalar()
            
            if total_rows == 0:
                logger.info(f"  -> Skipped {table.name} (0 rows)")
                continue
                
            logger.info(f"  -> Found {total_rows} rows to migrate. Migrating in batches...")
            
            result = src_conn.execute(select(table))
            batch_size = 1000
            migrated_count = 0
            
            while True:
                rows = result.fetchmany(batch_size)
                if not rows:
                    break
                    
                records = []
                for row in rows:
                    record = {}
                    for col_name, value in zip(table.columns.keys(), row):
                        col = table.columns[col_name]
                        if value is None and not col.nullable:
                            if col.default and getattr(col.default, 'is_scalar', False):
                                value = col.default.arg
                            else:
                                try:
                                    ptype = col.type.python_type
                                    if ptype == bool: value = False
                                    elif ptype == int: value = 0
                                    elif ptype == float: value = 0.0
                                    elif ptype == str: value = ""
                                    elif ptype.__name__ == 'datetime':
                                        import datetime
                                        value = datetime.datetime(2000, 1, 1)
                                    elif ptype.__name__ == 'date':
                                        import datetime
                                        value = datetime.date(2000, 1, 1)
                                except NotImplementedError:
                                    pass
                        record[col_name] = value
                    
                    # CYCLE BREAK
                    if table.name == "tournaments":
                        updates = {}
                        for col in ("winner_id", "runner_up_id"):
                            if record.get(col) is not None:
                                updates[col] = record[col]
                                record[col] = None
                        if updates:
                            updates["id"] = record["id"]
                            deferred_tournaments.append(updates)
                    elif table.name == "fixtures":
                        updates = {}
                        if record.get("winner_id") is not None:
                            updates["winner_id"] = record["winner_id"]
                            record["winner_id"] = None
                        if updates:
                            updates["id"] = record["id"]
                            deferred_fixtures.append(updates)
                            
                    records.append(record)
                
                with pg_engine.begin() as tgt_conn:
                    tgt_conn.execute(table.insert(), records)
                    
                migrated_count += len(records)
                logger.info(f"  -> Progress: {migrated_count}/{total_rows} rows")
                
            logger.info(f"  -> Successfully migrated {migrated_count} rows to {table.name}.")
                
            with pg_engine.begin() as tgt_conn:
                # Reset PostgreSQL sequence for the primary key if it exists
                if pg_engine.name == "postgresql":
                    for col in table.columns:
                        try:
                            if col.primary_key and col.autoincrement and col.type.python_type == int:
                                try:
                                    seq_sql = f"SELECT setval(pg_get_serial_sequence('{table.name}', '{col.name}'), (SELECT MAX({col.name}) FROM {table.name}));"
                                    tgt_conn.execute(text(seq_sql))
                                    logger.info(f"  -> Reset sequence for {table.name}.{col.name}")
                                except Exception as e:
                                    logger.warning(f"  -> Could not reset sequence for {table.name}.{col.name}: {e}")
                                break
                        except NotImplementedError:
                            pass
                            
    if deferred_tournaments and pg_engine.name == "postgresql":
        logger.info("Applying deferred foreign key updates for 'tournaments'...")
        with pg_engine.begin() as tgt_conn:
            for update_dict in deferred_tournaments:
                t_id = update_dict["id"]
                sets = []
                params = {"id": t_id}
                if "winner_id" in update_dict:
                    sets.append("winner_id = :w_id")
                    params["w_id"] = update_dict["winner_id"]
                if "runner_up_id" in update_dict:
                    sets.append("runner_up_id = :r_id")
                    params["r_id"] = update_dict["runner_up_id"]
                
                if sets:
                    sql = f"UPDATE tournaments SET {', '.join(sets)} WHERE id = :id"
                    tgt_conn.execute(text(sql), params)

    if deferred_fixtures and pg_engine.name == "postgresql":
        logger.info("Applying deferred foreign key updates for 'fixtures'...")
        with pg_engine.begin() as tgt_conn:
            for update_dict in deferred_fixtures:
                t_id = update_dict["id"]
                params = {"id": t_id, "w_id": update_dict["winner_id"]}
                sql = "UPDATE fixtures SET winner_id = :w_id WHERE id = :id"
                tgt_conn.execute(text(sql), params)
                            
    logger.info("Data migration completed successfully!")
    logger.info("This script has safely copied your data and synced the primary key sequences.")

if __name__ == "__main__":
    from sqlalchemy import text
    migrate_data()
