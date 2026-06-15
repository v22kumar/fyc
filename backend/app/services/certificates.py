from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from io import BytesIO
import datetime


def generate_volunteer_certificate(
    full_name: str,
    org_name: str,
    total_hours: float,
    issued_date: datetime.date,
    cert_id: str,
) -> bytes:
    """Generate a PDF volunteer certificate and return as bytes."""
    buffer = BytesIO()
    c = canvas.Canvas(buffer, pagesize=A4)
    w, h = A4

    c.setFont("Helvetica-Bold", 28)
    c.drawCentredString(w / 2, h - 100, "Certificate of Volunteering")

    c.setFont("Helvetica", 16)
    c.drawCentredString(w / 2, h - 160, f"This certifies that")

    c.setFont("Helvetica-Bold", 22)
    c.drawCentredString(w / 2, h - 200, full_name)

    c.setFont("Helvetica", 14)
    c.drawCentredString(w / 2, h - 240, f"has volunteered {total_hours:.1f} hours with")
    c.drawCentredString(w / 2, h - 270, org_name)
    c.drawCentredString(w / 2, h - 320, f"Issued: {issued_date.strftime('%d %B %Y')}")
    c.drawCentredString(w / 2, h - 350, f"Certificate ID: {cert_id}")
    c.drawCentredString(w / 2, h - 380, "Verify at: fycconnect.org/verify/cert/" + cert_id)

    c.save()
    buffer.seek(0)
    return buffer.read()
