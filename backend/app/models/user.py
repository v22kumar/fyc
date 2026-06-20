import uuid
from sqlalchemy import Column, String, Boolean, JSON, DateTime, ForeignKey, Numeric, UniqueConstraint, func, Date
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin

class User(Base, TimestampMixin, TenantModelMixin):
    """
    Multi-tenant user table. Authenticates via OTP (phone) or password (admin).
    """
    __tablename__ = "users"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    phone_number = Column(String(15), nullable=True)   # nullable for Google-only accounts
    email = Column(String(100), nullable=True)
    google_sub = Column(String(100), nullable=True)    # Google OAuth subject ID
    password_hash = Column(String(255), nullable=True)
    role = Column(String(30), nullable=False)  # 'PUBLIC_CITIZEN', 'VOLUNTEER', 'CLUB_MEMBER', 'EXECUTIVE_MEMBER', 'ADMIN', 'SUPER_ADMIN'
    is_verified = Column(Boolean(), default=False)
    preferred_language = Column(String(5), default="ta")  # 'ta' or 'en'
    fcm_token = Column(String(255), nullable=True)

    # Relationships
    profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    membership_card = relationship("MembershipCard", back_populates="user", uselist=False, cascade="all, delete-orphan")
    volunteer_metadata = relationship("VolunteerMetadata", back_populates="user", uselist=False, cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("organization_id", "phone_number", name="uq_org_phone"),
    )

class UserProfile(Base):
    """
    Detailed profile information for a user (bilingual names and fields).
    """
    __tablename__ = "user_profiles"

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    full_name_ta = Column(String(150), nullable=False)
    full_name_en = Column(String(150), nullable=False)
    address_line_ta = Column(String(255), nullable=True)
    address_line_en = Column(String(255), nullable=True)
    geography_id = Column(GUID(), nullable=True)  # Links to geographic hierarchy node
    gender = Column(String(20), nullable=True)  # 'MALE', 'FEMALE', or 'OTHER'
    date_of_birth = Column(Date, nullable=True)
    profile_image_url = Column(String(255), nullable=True)
    last_login_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="profile")

class MembershipCard(Base):
    """
    Digital identity card metadata for club members and executives (SNO-005).
    """
    __tablename__ = "membership_cards"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    membership_number = Column(String(50), unique=True, nullable=False)
    qr_code_payload = Column(String(255), nullable=False)
    status = Column(String(20), default="ACTIVE")  # 'ACTIVE', 'SUSPENDED', 'EXPIRED'
    designation_ta = Column(String(100), default="உறுப்பினர்")
    designation_en = Column(String(100), default="Member")
    issued_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    # Relationships
    user = relationship("User", back_populates="membership_card")

class VolunteerMetadata(Base):
    """
    Tracks skills, availability, and volunteering hours for volunteers (SNO-004).
    """
    __tablename__ = "volunteer_metadata"

    user_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    skills = Column(JSON, nullable=False, default=list)  # e.g., ["Blood Coordination", "First Aid"]
    availability_status = Column(String(20), default="AVAILABLE")  # 'AVAILABLE', 'BUSY', 'INACTIVE'
    total_hours_accrued = Column(Numeric(10, 2), default=0.00)

    # Relationships
    user = relationship("User", back_populates="volunteer_metadata")
