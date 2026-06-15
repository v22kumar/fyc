"""
OTP delivery service — tries channels in order: WhatsApp → Email → log.
Configure via .env:

  # Twilio WhatsApp (recommended for India)
  TWILIO_ACCOUNT_SID=ACxxxx
  TWILIO_AUTH_TOKEN=xxxx
  TWILIO_WHATSAPP_FROM=whatsapp:+14155238886   # Twilio sandbox or your approved number

  # Email (Gmail app password or any SMTP)
  SMTP_HOST=smtp.gmail.com
  SMTP_PORT=587
  SMTP_USER=your@gmail.com
  SMTP_PASSWORD=your-app-password
  SMTP_FROM_EMAIL=noreply@fycconnect.org
"""

import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from app.core.config import settings

logger = logging.getLogger(__name__)


def _send_whatsapp_otp(phone: str, otp: str) -> bool:
    """Send OTP via Twilio WhatsApp API."""
    if not (settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN):
        return False
    try:
        from twilio.rest import Client
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        wa_to = f"whatsapp:{phone}"
        body = (
            f"உங்கள் FYC Connect OTP: *{otp}*\n"
            f"Your FYC Connect OTP: *{otp}*\n"
            f"Valid for 10 minutes. Do not share this code."
        )
        client.messages.create(
            from_=settings.TWILIO_WHATSAPP_FROM,
            to=wa_to,
            body=body,
        )
        logger.info(f"WhatsApp OTP sent to {phone}")
        return True
    except Exception as e:
        logger.warning(f"WhatsApp OTP failed for {phone}: {e}")
        return False


def _send_email_otp(email: str, otp: str) -> bool:
    """Send OTP via SMTP email."""
    if not (settings.SMTP_USER and settings.SMTP_PASSWORD and email):
        return False
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = f"FYC Connect OTP: {otp}"
        msg["From"] = settings.SMTP_FROM_EMAIL or settings.SMTP_USER
        msg["To"] = email

        text = f"Your FYC Connect OTP is: {otp}\nஉங்கள் OTP: {otp}\nValid for 10 minutes."
        html = f"""
        <div style="font-family:sans-serif;max-width:400px;margin:auto;padding:24px;
                    border:1px solid #e5e7eb;border-radius:8px;">
          <h2 style="color:#064e3b;">FYC Connect</h2>
          <p>Your one-time password is:</p>
          <h1 style="letter-spacing:8px;color:#064e3b;font-size:36px;">{otp}</h1>
          <p style="color:#6b7280;font-size:13px;">Valid for 10 minutes. Do not share this code.</p>
          <hr style="border:none;border-top:1px solid #e5e7eb;">
          <p style="color:#6b7280;font-size:12px;">Friends Youth Club, Nagercoil</p>
        </div>
        """
        msg.attach(MIMEText(text, "plain"))
        msg.attach(MIMEText(html, "html"))

        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.ehlo()
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(msg["From"], email, msg.as_string())

        logger.info(f"Email OTP sent to {email}")
        return True
    except Exception as e:
        logger.warning(f"Email OTP failed for {email}: {e}")
        return False


def send_otp(phone: str, otp: str, email: str | None = None) -> dict:
    """
    Attempt OTP delivery across available channels.
    Returns dict of channel → success for logging/debugging.
    """
    results = {}

    # 1. Try WhatsApp
    results["whatsapp"] = _send_whatsapp_otp(phone, otp)

    # 2. Try Email (if provided)
    if email:
        results["email"] = _send_email_otp(email, otp)

    # 3. Always log (dev fallback — visible in docker logs)
    if not any(results.values()):
        logger.warning(f"[OTP FALLBACK — configure Twilio/SMTP] {phone} → {otp}")
        print(f"[OTP] {phone} → {otp}")

    return results
