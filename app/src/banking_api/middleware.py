import logging
import re
import time
import uuid
from collections.abc import Awaitable, Callable

from fastapi import Request, Response
from fastapi.responses import JSONResponse

from banking_api.logging_config import request_id_ctx

logger = logging.getLogger("banking_api.access")

_REQUEST_ID_RE = re.compile(r"^[A-Za-z0-9-]{1,64}$")
_QUIET_PATHS = frozenset({"/health", "/ready"})

SECURITY_HEADERS = {
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Cache-Control": "no-store",
}


async def request_context_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    incoming = request.headers.get("x-request-id")
    request_id = incoming if incoming and _REQUEST_ID_RE.match(incoming) else uuid.uuid4().hex
    token = request_id_ctx.set(request_id)
    start = time.perf_counter()
    try:
        try:
            response = await call_next(request)
        except Exception:
            logger.exception("unhandled error", extra={"event": "unhandled_error"})
            response = JSONResponse(
                status_code=500,
                content={"detail": "Internal server error", "request_id": request_id},
            )

        route = request.scope.get("route")
        logger.log(
            logging.DEBUG if request.url.path in _QUIET_PATHS else logging.INFO,
            "request completed",
            extra={
                "event": "http_request",
                "method": request.method,
                "path": request.url.path,
                "route": getattr(route, "path", None),
                "status": response.status_code,
                "duration_ms": round((time.perf_counter() - start) * 1000, 2),
                "client_ip": request.client.host if request.client else None,
                "trace_id": request.headers.get("x-amzn-trace-id"),
            },
        )
        response.headers["X-Request-ID"] = request_id
        for header, value in SECURITY_HEADERS.items():
            response.headers.setdefault(header, value)
        return response
    finally:
        request_id_ctx.reset(token)
