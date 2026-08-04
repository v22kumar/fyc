"""Generic SMTP mailer — the single place that actually dispatches email.

Used by the civic-complaint forwarding (issues) and reusable elsewhere. Returns
False (never raises) when SMTP isn't configured or a send fails, so callers can
degrade gracefully (log the attempt, show the citizen a phone/portal fallback).
"""
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Iterable, Optional, Union

from app.core.config import settings

logger = logging.getLogger(__name__)


def is_configured() -> bool:
    return bool(settings.SMTP_USER and settings.SMTP_PASSWORD)


def send_email(
    to: Union[str, Iterable[str]],
    subject: str,
    body_text: str,
    body_html: Optional[str] = None,
    cc: Optional[Iterable[str]] = None,
    reply_to: Optional[str] = None,
) -> bool:
    """Send an email via SMTP. Returns True on success, False otherwise."""
    recipients = [to] if isinstance(to, str) else [t for t in to if t]
    recipients = [r for r in recipients if r]
    cc_list = [c for c in (cc or []) if c]
    if not is_configured() or not recipients:
        logger.warning("[mailer] not sent (configured=%s, recipients=%s)", is_configured(), recipients)
        return False
    sender = settings.SMTP_FROM_EMAIL or settings.SMTP_USER
    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = sender
        msg["To"] = ", ".join(recipients)
        if cc_list:
            msg["Cc"] = ", ".join(cc_list)
        if reply_to:
            msg["Reply-To"] = reply_to
        msg.attach(MIMEText(body_text, "plain", "utf-8"))
        if body_html:
            msg.attach(MIMEText(body_html, "html", "utf-8"))
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=20) as server:
            server.ehlo()
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.sendmail(sender, recipients + cc_list, msg.as_string())
        logger.info("[mailer] sent to %s (cc %s)", recipients, cc_list)
        return True
    except Exception as e:
        logger.warning("[mailer] send failed to %s: %s", recipients, e)
        return False
