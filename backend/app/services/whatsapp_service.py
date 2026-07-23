import logging
import os
import requests
from typing import Dict, Any

logger = logging.getLogger(__name__)

class WhatsAppProvider:
    """Abstract interface for WhatsApp delivery."""
    def send_template(self, phone: str, template_name: str, parameters: Dict[str, Any]) -> bool:
        raise NotImplementedError()

class MetaCloudWhatsAppProvider(WhatsAppProvider):
    """Implementation for Meta Cloud API."""
    def __init__(self, api_key: str, phone_number_id: str):
        self.api_key = api_key
        self.phone_number_id = phone_number_id
        # WhatsApp graph API version
        self.api_version = "v25.0"

    def send_template(self, phone: str, template_name: str, parameters: Dict[str, Any]) -> bool:
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

    def send_template(self, phone: str, template_name: str, parameters: Dict[str, Any]) -> bool:
        logger.info(f"[TWILIO API] Sent template '{template_name}' to {phone}")
        # Use twilio client here
        return True

class WhatsAppMockProvider(WhatsAppProvider):
    def send_template(self, phone: str, template_name: str, parameters: Dict[str, Any]) -> bool:
        logger.info(f"[MOCK WHATSAPP] Delivered '{template_name}' to {phone} with params {parameters}")
        return True

class WhatsAppQueueManager:
    """
    Queue abstraction for WhatsApp messages to handle rate limits and bulk sending.
    For production, this would be backed by Celery or Redis Queue.
    """
    def __init__(self, provider: WhatsAppProvider):
        self.provider = provider

    def enqueue_template(self, phone: str, template_name: str, parameters: Dict[str, Any]) -> bool:
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
