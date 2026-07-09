<div align="center">

# PrivacyIDEA Docker

Containerized MFA OTP server for corporate environments

![Status](https://img.shields.io/badge/status-Stable-28a745?style=flat-square)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-27.0+-2496ED?style=flat-square&logo=docker)](https://docker.com)
![Updated](https://img.shields.io/github/last-commit/aentrepreneur/privacyIDEA-docker?style=flat-square)

</div>

## Overview

Production-ready Docker Compose deployment of [privacyIDEA](https://github.com/privacyidea/privacyidea) OTP server with PostgreSQL backend, Apache+mod_wsgi, and automated admin seeding for TOTP-based two-factor authentication (2FA).

## Features

- privacyIDEA server via Apache + mod_wsgi
- PostgreSQL 14 as persistent backend
- Environment variables for sensitive configuration
- Automated admin and realm seeding at startup
- Healthcheck against `/auth` endpoint
- Persistent application logs via volumes

## Requirements

- Docker + Docker Compose v2
- Port 8080 available on host

## Quick Start

```bash
git clone https://github.com/aentrepreneur/privacyIDEA-docker.git
cd privacyIDEA-docker
cp .env.example .env   # edit variables
docker compose up -d
```

Access `http://localhost:8080` and log in with the admin defined in `.env`.

## Structure

```text
privacyIDEA-docker/
├── docker-compose.yml
├── .env.example
├── entrypoint.sh
├── scripts/
│   └── seed_admin.sh
└── docs/
    └── DEPLOYMENT.md
```

## Documentation

- `docs/DEPLOYMENT.md` — installation guide, environment variables, troubleshooting

## License

MIT — see [LICENSE](LICENSE)

## Author

Angel Esquivel — [@aentrepreneur](https://github.com/aentrepreneur)
