#!/usr/bin/env python3
"""Start the backend API locally with robust dotenv handling.

This loader avoids shell parsing issues for JSON environment values and
generates temporary Firebase credentials when placeholders are still present.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from dotenv import dotenv_values
import uvicorn

ROOT = Path(__file__).resolve().parents[1]


def _load_root_dotenv() -> None:
    for key, value in dotenv_values(ROOT / ".env").items():
        if value is not None:
            os.environ[key] = value


def _is_placeholder_credentials(raw_value: str) -> bool:
    return (
        not raw_value
        or "YOUR_PRIVATE_KEY_CONTENT" in raw_value
        or "YOUR_PRIVATE_KEY_ID" in raw_value
        or "backend-service@grantflow.iam.gserviceaccount.com" in raw_value
    )


def _build_local_firebase_credentials() -> str:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_key_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")

    project_id = os.environ.get("NEXT_PUBLIC_FIREBASE_PROJECT_ID", "grantflow-local")
    credentials: dict[str, Any] = {
        "type": "service_account",
        "project_id": project_id,
        "private_key_id": "local-dev-key",
        "private_key": private_key_pem,
        "client_email": f"backend-local@{project_id}.iam.gserviceaccount.com",
        "client_id": "1234567890",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": (
            "https://www.googleapis.com/robot/v1/metadata/x509/"
            f"backend-local%40{project_id}.iam.gserviceaccount.com"
        ),
        "universe_domain": "googleapis.com",
    }
    return json.dumps(credentials, separators=(",", ":"))


def main() -> None:
    if str(ROOT) not in sys.path:
        sys.path.insert(0, str(ROOT))

    _load_root_dotenv()

    raw_credentials = os.environ.get("FIREBASE_SERVICE_ACCOUNT_CREDENTIALS", "")
    if _is_placeholder_credentials(raw_credentials):
        os.environ["FIREBASE_SERVICE_ACCOUNT_CREDENTIALS"] = _build_local_firebase_credentials()

    os.environ.setdefault("DATABASE_CONNECTION_STRING", "postgresql+asyncpg://local:local@localhost:5432/local")
    os.environ.setdefault("DEBUG", "True")
    os.environ.setdefault("ENVIRONMENT", "development")

    host = os.environ.get("BACKEND_HOST", "0.0.0.0")
    port = int(os.environ.get("BACKEND_PORT", "8000"))
    uvicorn.run("services.backend.src.main:app", host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()
