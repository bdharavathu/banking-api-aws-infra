from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse, RedirectResponse

from banking_api import __version__
from banking_api.config import get_settings
from banking_api.logging_config import configure_logging
from banking_api.middleware import request_context_middleware
from banking_api.routes import accounts_router, health_router
from banking_api.services import (
    AccountNotFoundError,
    IdempotencyConflictError,
    InsufficientFundsError,
)

_DOMAIN_ERRORS: dict[type[Exception], tuple[int, str]] = {
    AccountNotFoundError: (status.HTTP_404_NOT_FOUND, "Account not found"),
    InsufficientFundsError: (status.HTTP_409_CONFLICT, "Insufficient funds"),
    IdempotencyConflictError: (
        status.HTTP_422_UNPROCESSABLE_CONTENT,
        "Idempotency-Key was already used for a different request",
    ),
}


async def _domain_error_handler(_: Request, exc: Exception) -> JSONResponse:
    status_code, detail = _DOMAIN_ERRORS[type(exc)]
    return JSONResponse(status_code=status_code, content={"detail": detail})


def create_app() -> FastAPI:
    settings = get_settings()
    configure_logging(settings.log_level)

    app = FastAPI(
        title="Banking API",
        version=__version__,
        docs_url="/docs" if settings.enable_docs else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.enable_docs else None,
        swagger_ui_parameters={"persistAuthorization": True},
    )
    app.middleware("http")(request_context_middleware)
    for exc_type in _DOMAIN_ERRORS:
        app.add_exception_handler(exc_type, _domain_error_handler)
    app.include_router(health_router)
    app.include_router(accounts_router)
    if settings.enable_docs:

        @app.get("/", include_in_schema=False)
        def root() -> RedirectResponse:
            return RedirectResponse("/docs")

    return app


app = create_app()
