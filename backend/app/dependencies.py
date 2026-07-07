from typing import List, Optional
from uuid import UUID
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token
import jwt
from app.middleware.tenant import get_current_tenant_id
from app.models.user import User

# Header security schemes
api_key_header = APIKeyHeader(name="Authorization", auto_error=False)

def get_current_token_payload(
    authorization: Optional[str] = Security(api_key_header)
) -> dict:
    """Extract and validate the JWT token payload from Authorization header."""
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization Header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Expecting: "Bearer <token>"
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token format. Use 'Bearer <JWT>'",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = parts[1]
    try:
        payload = decode_token(token)
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "TOKEN_EXPIRED", "message": "Your session has expired. Please sign in again."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "INVALID_TOKEN", "message": "Invalid authentication token."},
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "AUTH_ERROR", "message": "Could not validate credentials."},
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_user(
    payload: dict = Depends(get_current_token_payload),
    db: Session = Depends(get_db)
) -> User:
    """Retrieve the logged in user based on the validated JWT token."""
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token does not contain user identifier",
        )
    
    # Load user
    user = db.query(User).filter(User.id == UUID(user_id)).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    
    # Verify tenant match. The active tenant header must match the user's organization.
    current_tenant = get_current_tenant_id()
    if not current_tenant or user.organization_id != current_tenant:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cross-tenant access denied. Organization mismatch.",
        )
        
    return user

def get_current_user_optional(
    authorization: Optional[str] = Security(api_key_header),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """Retrieve the logged in user based on the JWT token, or None if missing/invalid."""
    if not authorization:
        return None
    try:
        payload = get_current_token_payload(authorization)
        return get_current_user(payload=payload, db=db)
    except HTTPException:
        return None

class RoleChecker:
    """Dependency factory to restrict access to specific roles."""
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. User role '{current_user.role}' not permitted.",
            )
        return current_user
