import logging
import os
import requests
from typing import Any, Dict, Sequence, Union

# Meta's template body parameters are positional ({{1}}, {{2}}, …). A sequence
# says that; a dict is accepted only for backward compatibility and is sorted
# by key, which is a guess. New callers should pass a list or tuple.
TemplateParams = Union[Sequence[Any], Dict[str, Any], None]

logger = logging.getLogger(__name__)

class WhatsAppProvider:
    """Abstract interface for WhatsApp delivery."""
    def send_template(self, phone: str, template_name: str, parameters: TemplateParams = None) -> bool:
        raise NotImplementedError()

class MetaCloudWhatsAppProvider(WhatsAppProvider):
    """Implementation for Meta Cloud API."""
    def __init__(self, api_key: str, phone_number_id: str):
        self.api_key = api_key
        self.phone_number_id = phone_number_id
        # WhatsApp graph API version
        self.api_version = "v25.0"

    def send_template(self, phone: str, template_name: str, parameters: TemplateParams = None) -> bool:
        logger.info(f"[META CLOUD API] Sending template '{template_name}' to {phone}")

        # Strip any leading '+' from phone number as WhatsApp API expects pure numbers
        clean_phone = phone.lstrip('+')

        url = f"https://graph.facebook.com/{self.api_version}/{self.phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        data = {
            "messaging_product": "whatsapp",
            "to": clean_phone,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {"code": "en_US"},
            }
        }

        # The parameters were accepted and then thrown away: this payload
        # carried a template name and a language and no `components` block, so
        # every {{1}} in an approved template went out empty — or, more often,
        # Meta rejected the whole message, because it requires the body
        # parameter count to match the template exactly.
        #
        # Meta's body parameters are POSITIONAL ({{1}}, {{2}}), and a dict has
        # no order that survives a round trip. `sorted()` gives a stable one,
        # which is not the same as a correct one: the caller must name its keys
        # so that sorting them yields {{1}}, {{2}}, … For the two callers today
        # ({"title": …, "body": …}) that happens to be wrong — "body" sorts
        # before "title" — so they pass an ordered sequence instead. A dict is
        # still accepted for compatibility, sorted, and logged as a guess.
        if parameters:
            if isinstance(parameters, dict):
                logger.warning(
                    "[META CLOUD API] template '%s' got parameters as a dict; "
                    "ordering them by key, which may not match the template's "
                    "{{1}}, {{2}} positions. Pass a list or tuple to be sure.",
                    template_name,
                )
                ordered = [parameters[k] for k in sorted(parameters)]
            else:
                ordered = list(parameters)
            data["template"]["components"] = [{
                "type": "body",
                "parameters": [{"type": "text", "text": str(v)} for v in ordered],
            }]

        try:
            response = requests.post(url, headers=headers, json=data, timeout=10)
            response.raise_for_status()
            logger.info(f"[META CLOUD API] Successfully sent template '{template_name}' to {phone}")
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"[META CLOUD API] Failed to send WhatsApp message: {e}")
            if hasattr(e, 'response') and e.response is not None:
                logger.error(f"[META CLOUD API] Error response: {e.response.text}")
            return False

class TwilioWhatsAppProvider(WhatsAppProvider):
    """Implementation for Twilio WhatsApp API."""
    def __init__(self, account_sid: str, auth_token: str, from_number: str):
        self.account_sid = account_sid
        self.auth_token = auth_token
        self.from_number = from_number

    def send_template(self, phone: str, template_name: str, parameters: TemplateParams = None) -> bool:
        logger.info(f"[TWILIO API] Sent template '{template_name}' to {phone}")
        # Use twilio client here
        return True

class WhatsAppMockProvider(WhatsAppProvider):
    def send_template(self, phone: str, template_name: str, parameters: TemplateParams = None) -> bool:
        logger.info(f"[MOCK WHATSAPP] Delivered '{template_name}' to {phone} with params {parameters}")
        return True

class WhatsAppQueueManager:
    """
    Queue abstraction for WhatsApp messages to handle rate limits and bulk sending.
    For production, this would be backed by Celery or Redis Queue.
    """
    def __init__(self, provider: WhatsAppProvider):
        self.provider = provider

    def enqueue_template(self, phone: str, template_name: str, parameters: TemplateParams = None) -> bool:
        # In a real system, push to Redis Queue. 
        # Here we process synchronously for the MVP abstraction.
        try:
            return self.provider.send_template(phone, template_name, parameters)
        except Exception as e:
            logger.error(f"Failed to enqueue WhatsApp message: {e}")
            return False

# Initialize the correct provider based on environment variables
_whatsapp_api_token = os.getenv("WHATSAPP_API_TOKEN")
_whatsapp_phone_id = os.getenv("WHATSAPP_PHONE_ID")

if _whatsapp_api_token and _whatsapp_phone_id:
    _provider = MetaCloudWhatsAppProvider(
        api_key=_whatsapp_api_token, 
        phone_number_id=_whatsapp_phone_id
    )
    logger.info("WhatsApp Service initialized with Meta Cloud API provider.")
else:
    _provider = WhatsAppMockProvider()
    logger.info("WhatsApp Service initialized with Mock provider.")

# Global instance for the service layer to use
whatsapp_queue = WhatsAppQueueManager(_provider)
