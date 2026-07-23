import httpx
import logging

logger = logging.getLogger(__name__)

async def run_keepalive():
    try:
        async with httpx.AsyncClient(timeout=5) as c:
            await c.get("http://localhost:8000/api/health")
    except Exception as exc:
        logger.debug("[scheduler] keepalive ping failed: %s", exc)
