"""One place that sends a plain SMS.

Twilio is already configured in this project, but only for OTP — via Verify,
which sends a code it generated and cannot carry our text. So this is the
messaging API, kept separate and deliberately small.

It exists for one rung of the SOS degradation ladder, and that rung is the most
important one: **the phone may already be gone.** Trusted contacts used to live
only in the device's `SharedPreferences`, so a handset that was taken, smashed
or out of battery took the only copy of them with it and the people who would
actually come never heard anything. Sending from the server is what fixes that,
and it needs a way to send.

Returns False rather than raising, always. A missing provider must degrade the
alert, never fail it.
"""
import logging
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)


def is_configured() -> bool:
    """Can this deployment send an SMS at all?

    Worth asking out loud: the safety setup screen should say "we cannot test
    this number from here" rather than leaving a member to conclude their
    contact is fine because nothing complained.
    """
    return bool(
        settings.TWILIO_ACCOUNT_SID
        and settings.TWILIO_AUTH_TOKEN
        and getattr(settings, "TWILIO_SMS_FROM", "")
    )


def send_sms(to: str, body: str) -> bool:
    """Send one message. Never raises."""
    if not is_configured():
        logger.info("SMS skipped (no provider configured): %s", to)
        return False
    try:
        from twilio.rest import Client

        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(
            to=to,
            from_=settings.TWILIO_SMS_FROM,
            # Trimmed to a single segment's worth of headroom. A long body is
            # not worth the extra failure modes on a path that has to work.
            body=body[:600],
        )
        return True
    except Exception as exc:
        logger.warning("SMS to %s failed: %s", to, exc)
        return False


def sos_text(name: str, maps_url: Optional[str], place: Optional[str]) -> str:
    """The message a trusted contact receives.

    Plain ASCII on purpose. A Tamil body is more thoughtful and also more
    likely to arrive mangled on an old handset, and this is the one message in
    the app that absolutely must be readable when it lands.
    """
    where = ""
    if maps_url:
        where = f" Location: {maps_url}"
    elif place:
        where = f" Near: {place}"
    return f"SOS - {name} needs help.{where} - FYC Connect"
