import logging
import time
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

    def send_template(self, phone: str, template_name: str, parameters: Dict[str, Any]) -> bool:
        logger.info(f"[META CLOUD API] Sent template '{template_name}' to {phone}")
        # Make requests.post to graph.facebook.com here
        return True

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

# Global instance for the service layer to use
whatsapp_queue = WhatsAppQueueManager(WhatsAppMockProvider())
