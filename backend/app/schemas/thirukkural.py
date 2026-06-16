from pydantic import BaseModel


class ThirukkuralResponse(BaseModel):
    """A single Thirukkural couplet with Tamil and English text and meanings."""

    number: int
    line1: str
    line2: str
    tamil_meaning: str
    english_couplet: str
    english_meaning: str

    # Derived structural context (Thirukkural has a fixed canonical layout).
    adhikaram: int          # Chapter 1–133 (10 kurals each)
    paal_ta: str            # Section name in Tamil
    paal_en: str            # Section name in English
