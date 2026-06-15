import uuid
import enum
from sqlalchemy import Column, String, Text, Boolean, Integer, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import GUID, TimestampMixin, TenantModelMixin


class ContactCategory(str, enum.Enum):
    POLICE = "POLICE"
    FIRE = "FIRE"
    AMBULANCE = "AMBULANCE"
    HOSPITAL = "HOSPITAL"
    ELECTRICITY_BOARD = "ELECTRICITY_BOARD"
    REVENUE_OFFICE = "REVENUE_OFFICE"
    TALUK_OFFICE = "TALUK_OFFICE"
    RTO = "RTO"
    MUNICIPALITY = "MUNICIPALITY"
    CM_HELPLINE = "CM_HELPLINE"
    OTHER = "OTHER"


class DirectoryContact(Base, TimestampMixin, TenantModelMixin):
    """
    Public emergency and civic contacts for a tenant (district-level directory).
    Bilingual names and designations; soft-deleteable via is_active flag.
    """
    __tablename__ = "directory_contacts"

    id = Column(GUID(), primary_key=True, default=uuid.uuid4)
    category = Column(SAEnum(ContactCategory, name="contact_category"), nullable=False)
    name_ta = Column(String(150), nullable=False)
    name_en = Column(String(150), nullable=False)
    designation_ta = Column(String(100), nullable=True)
    designation_en = Column(String(100), nullable=True)
    phone_primary = Column(String(20), nullable=False)
    phone_secondary = Column(String(20), nullable=True)
    whatsapp_number = Column(String(20), nullable=True)
    address_ta = Column(Text, nullable=True)
    address_en = Column(Text, nullable=True)
    geography_id = Column(
        GUID(),
        ForeignKey("geographic_nodes.id", ondelete="SET NULL"),
        nullable=True
    )
    is_active = Column(Boolean, default=True, nullable=False)
    display_order = Column(Integer, default=0, nullable=False)

    geography = relationship("GeographicNode", foreign_keys=[geography_id])


def seed_default_contacts(db, organization_id: uuid.UUID) -> None:
    """
    Seed well-known emergency and civic contacts for Kanyakumari district.
    Safe to call multiple times: skips rows where phone_primary already exists
    for the given organization.

    Args:
        db: SQLAlchemy Session
        organization_id: UUID of the target organization / tenant
    """
    defaults = [
        dict(
            category=ContactCategory.POLICE,
            name_ta="காவல் துறை அவசர உதவி",
            name_en="Police Emergency",
            designation_ta=None,
            designation_en=None,
            phone_primary="100",
            phone_secondary="04652-230100",
            whatsapp_number=None,
            address_ta="கன்னியாகுமரி மாவட்ட காவல் கட்டுப்பாட்டு அறை",
            address_en="Kanyakumari District Police Control Room",
            display_order=10,
        ),
        dict(
            category=ContactCategory.FIRE,
            name_ta="தீயணைப்பு அவசர உதவி",
            name_en="Fire & Rescue Services",
            designation_ta=None,
            designation_en=None,
            phone_primary="101",
            phone_secondary=None,
            whatsapp_number=None,
            address_ta=None,
            address_en=None,
            display_order=20,
        ),
        dict(
            category=ContactCategory.AMBULANCE,
            name_ta="ஆம்புலன்ஸ் அவசர உதவி",
            name_en="Ambulance Emergency",
            designation_ta=None,
            designation_en=None,
            phone_primary="108",
            phone_secondary=None,
            whatsapp_number=None,
            address_ta=None,
            address_en=None,
            display_order=30,
        ),
        dict(
            category=ContactCategory.ELECTRICITY_BOARD,
            name_ta="மின்சார புகார் மையம்",
            name_en="Electricity Board Complaints",
            designation_ta="TNEB புகார் மையம்",
            designation_en="TNEB Complaint Centre",
            phone_primary="1912",
            phone_secondary=None,
            whatsapp_number=None,
            address_ta=None,
            address_en=None,
            display_order=40,
        ),
        dict(
            category=ContactCategory.CM_HELPLINE,
            name_ta="முதலமைச்சர் உதவி மையம்",
            name_en="Chief Minister Helpline",
            designation_ta=None,
            designation_en=None,
            phone_primary="1100",
            phone_secondary=None,
            whatsapp_number=None,
            address_ta=None,
            address_en=None,
            display_order=50,
        ),
        dict(
            category=ContactCategory.REVENUE_OFFICE,
            name_ta="கன்னியாகுமரி மாவட்ட ஆட்சியர் அலுவலகம்",
            name_en="Kanyakumari District Collectorate",
            designation_ta="மாவட்ட ஆட்சியர்",
            designation_en="District Collector",
            phone_primary="04652-230311",
            phone_secondary="04652-230300",
            whatsapp_number=None,
            address_ta="கலெக்டர் அலுவலகம், நாகர்கோவில் - 629 001",
            address_en="Collector Office, Nagercoil - 629 001",
            display_order=60,
        ),
        dict(
            category=ContactCategory.HOSPITAL,
            name_ta="மாவட்ட அரசு மருத்துவமனை, நாகர்கோவில்",
            name_en="District Government Hospital, Nagercoil",
            designation_ta="மருத்துவமனை கட்டுப்பாட்டு அறை",
            designation_en="Hospital Control Room",
            phone_primary="04652-230016",
            phone_secondary="04652-230017",
            whatsapp_number=None,
            address_ta="அரசு மருத்துவமனை வளாகம், நாகர்கோவில் - 629 001",
            address_en="Government Hospital Campus, Nagercoil - 629 001",
            display_order=70,
        ),
    ]

    for entry in defaults:
        exists = (
            db.query(DirectoryContact)
            .filter(
                DirectoryContact.organization_id == organization_id,
                DirectoryContact.phone_primary == entry["phone_primary"],
            )
            .first()
        )
        if exists:
            continue
        contact = DirectoryContact(
            organization_id=organization_id,
            is_active=True,
            **entry,
        )
        db.add(contact)

    db.commit()
