import uvicorn

from banking_api.config import get_settings


def main() -> None:
    settings = get_settings()
    uvicorn.run(
        "banking_api.main:app",
        host=settings.host,
        port=settings.port,
        log_config=None,
        access_log=False,
        proxy_headers=True,
        forwarded_allow_ips=settings.forwarded_allow_ips,
        server_header=False,
    )


if __name__ == "__main__":
    main()
