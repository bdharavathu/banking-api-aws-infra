import hashlib
import hmac
import logging

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader

from banking_api.config import get_settings

logger = logging.getLogger(__name__)

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


def require_api_key(api_key: str | None = Security(api_key_header)) -> None:
    valid_hashes = get_settings().api_key_hash_set()
    if api_key and valid_hashes:
        digest = hashlib.sha256(api_key.encode()).hexdigest()
        if any(hmac.compare_digest(digest, h) for h in valid_hashes):
            return

    logger.warning(
        "authentication failed",
        extra={"event": "auth_failed", "reason": "missing" if not api_key else "invalid"},
    )
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing API key",
        headers={"WWW-Authenticate": "ApiKey"},
    )
