from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

# Determine database type and configure accordingly
is_sqlite = settings.DATABASE_URL.startswith("sqlite")

connect_args = {}
if is_sqlite:
    # Required for SQLite to be accessed in multi-threaded FastAPI contexts
    connect_args = {"check_same_thread": False}

# Create engine
engine_kwargs = dict(
    connect_args=connect_args,
    pool_pre_ping=True,  # Crucial for Postgres to recover from disconnected sockets
    echo=False,
)
if not is_sqlite:
    # Size the pool for a remote Postgres so threadpooled sync requests don't
    # queue waiting for a connection, while staying under the provider's limit.
    engine_kwargs.update(
        pool_size=settings.DB_POOL_SIZE,
        max_overflow=settings.DB_MAX_OVERFLOW,
        pool_recycle=settings.DB_POOL_RECYCLE,
    )
engine = create_engine(settings.DATABASE_URL, **engine_kwargs)

# Create session maker
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base class for SQLAlchemy models
Base = declarative_base()

# Enforce foreign key constraints in SQLite
if is_sqlite:
    @event.listens_for(Engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        # Concurrency hardening for the single-file production DB under load
        # (many users + live chess/sports scoring writing at once):
        #   WAL          — readers don't block the writer and vice-versa
        #   busy_timeout — a blocked writer waits up to 8s for the lock instead
        #                  of failing immediately with "database is locked"
        #   NORMAL sync  — keeps WAL durability while cutting fsync overhead
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA busy_timeout=8000")
        cursor.execute("PRAGMA synchronous=NORMAL")
        cursor.close()

# Dependency to yield database sessions
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
