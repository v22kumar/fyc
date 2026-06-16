import contextvars
from typing import Optional
from uuid import UUID
from fastapi import HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

# Thread-safe context variable to store the active organization/tenant ID
tenant_id_context: contextvars.ContextVar[Optional[UUID]] = contextvars.ContextVar(
    "tenant_id", default=None
)

def get_current_tenant_id() -> Optional[UUID]:
    """Retrieve the current active tenant ID from thread-safe context."""
    return tenant_id_context.get()

def set_current_tenant_id(tenant_id: Optional[UUID]) -> None:
    """Explicitly set the active tenant ID in the thread-safe context."""
    tenant_id_context.set(tenant_id)

def require_tenant_id() -> UUID:
    """
    FastAPI dependency for public/anonymous endpoints that must always be
    tenant-scoped. Raises 400 instead of silently falling back to an
    unscoped, cross-tenant query when X-Organization-ID is missing/invalid.
    """
    tenant_id = tenant_id_context.get()
    if not tenant_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="X-Organization-ID header is required",
        )
    return tenant_id

class TenantMiddleware(BaseHTTPMiddleware):
    """
    Middleware that extracts X-Organization-ID from request headers
    and binds it to a thread-local contextvar for query isolation.
    """
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        org_id_str = request.headers.get("X-Organization-ID")
        tenant_id = None
        
        if org_id_str:
            try:
                tenant_id = UUID(org_id_str)
            except ValueError:
                # Invalid UUID format, will treat as None/no tenant
                pass

        # Set tenant in context for duration of this request execution
        token = tenant_id_context.set(tenant_id)
        try:
            response = await call_next(request)
            return response
        finally:
            # Reset context back to previous state
            tenant_id_context.reset(token)
