import uuid
from sqlalchemy import Column, String, Boolean, JSON, DateTime, ForeignKey, Numeric, UniqueConstraint, func, Date, Integer
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

    # Verification is per channel, not per person.
    #
    # `is_verified` above is one boolean for a whole human, which cannot say
    # the true thing: that a phone is proven while an email is not, or the
    # reverse. It is kept for the code that still reads it and now means "at
    # least one identifier is proven".
    #
    # These two are what actually govern trust. A NULL is not a smaller truth
    # than a date — it is the difference between a number somebody typed and a
    # number somebody answered.
    phone_verified_at = Column(DateTime(timezone=True), nullable=True)
    email_verified_at = Column(DateTime(timezone=True), nullable=True)
    is_blocked = Column(Boolean(), default=False)
    preferred_language = Column(String(5), default="ta")  # 'ta' or 'en'
    fcm_token = Column(String(255), nullable=True)
    # Bumped to revoke ALL of a user's outstanding refresh tokens at once
    # (logout-everywhere, password reset, account disable). Refresh tokens carry
    # this value as a `tv` claim; /auth/refresh rejects any whose tv != this.
    token_version = Column(Integer, nullable=False, server_default="0", default=0)
    # Where this account came from. NULL = a real self-registered user; a value
    # like 'F2S_IMPORT' marks a directory contact imported from Friends2Support
    # (a donor-only entry, not a real app user/member). Used to keep imported
    # contacts out of member/opponent lists while still letting them exist as
    # donors — orthogonal to `role`, so a real member who is also a donor is NOT
    # marked and still appears everywhere.
    source = Column(String(30), nullable=True)

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
    geography_id = Column(
        GUID(),
        ForeignKey("geographic_nodes.id", ondelete="SET NULL"),
        nullable=True,
    )  # Links to geographic hierarchy node
    gender = Column(String(20), nullable=True)  # 'MALE', 'FEMALE', or 'OTHER'
    blood_group = Column(String(10), nullable=True)
    date_of_birth = Column(Date, nullable=True)
    # Celebrations. The anniversary recurs yearly like the birthday; the flag
    # decides whether the CLUB is told — the personal greeting always comes.
    # Only day and month are ever shown publicly; the year (someone's age,
    # someone's wedding year) never leaves the profile.
    wedding_anniversary = Column(Date, nullable=True)
    # Nullable with NO server default, deliberately: the startup reconcile
    # adds missing columns with a plain ADD COLUMN, and Postgres rejects
    # `BOOLEAN DEFAULT 1` (an integer default on a boolean) — which left this
    # column missing in production and 500'd every query selecting a profile.
    # NULL means "never chose" and is treated as public wherever it is read.
    celebrate_publicly = Column(Boolean(), nullable=True, default=True)
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

class UserBlock(Base, TimestampMixin, TenantModelMixin):
    """
    Tracks which user blocked whom. Blocking prevents the blocker from seeing the blocked user's content.
    """
    __tablename__ = "user_blocks"

    __table_args__ = (
        UniqueConstraint("blocker_id", "blocked_id", name="uq_user_block"),
    )

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    blocker_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    blocked_id = Column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
