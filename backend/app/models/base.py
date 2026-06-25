import uuid
from sqlalchemy import Column, DateTime, ForeignKey, func, JSON
from sqlalchemy.types import TypeDecorator, CHAR
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import declared_attr
from app.core.database import Base

class GUID(TypeDecorator):
    """
    Platform-independent GUID type.
    Uses PostgreSQL's native UUID type, otherwise CHAR(32) storing hex strings.
    """
    impl = CHAR
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == 'postgresql':
            return dialect.type_descriptor(PostgresUUID(as_uuid=True))
        else:
            return dialect.type_descriptor(CHAR(32))

    def process_bind_param(self, value, dialect):
        if value is None:
            return value
        elif dialect.name == 'postgresql':
            return value
        else:
            if isinstance(value, uuid.UUID):
                return value.hex
            else:
                try:
                    return uuid.UUID(str(value)).hex
                except ValueError:
                    return str(value).replace("-", "")

    def process_result_value(self, value, dialect):
        if value is None:
            return value
        if isinstance(value, uuid.UUID):
            return value
        return uuid.UUID(value)

class TimestampMixin:
    """Mixin to add created_at and updated_at fields."""
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False
    )
    deleted_at = Column(
        DateTime(timezone=True),
        nullable=True
    )
    metadata_json = Column(
        JSON,
        nullable=True
    )

class TenantModelMixin:
    """Mixin to add organization_id and associate it with organization table."""
    @declared_attr
    def organization_id(cls):
        return Column(
            GUID(),
            ForeignKey("organizations.id", ondelete="CASCADE"),
            nullable=False,
            index=True
        )
