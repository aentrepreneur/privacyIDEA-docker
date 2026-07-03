# privacyIDEA-docker

Despliegue containerizado de [privacyIDEA](https://github.com/privacyidea/privacyidea) con Docker Compose: servidor OTP con PostgreSQL, configurado para autenticacion de dos factores (2FA/TOTP) en entornos corporativos.

## Caracteristicas

- Servidor privacyIDEA via Apache+mod_wsgi
- PostgreSQL 14 como backend persistente
- Variables de entorno para configuracion sensible
- Seed automatico de admin y realm por defecto
- Healthcheck contra `/auth` endpoint
- Logs de aplicacion persistentes en volumen

## Requisitos

- Docker + Docker Compose v2
- Puerto 8080 disponible (host)

## Uso rapido

```bash
git clone https://github.com/aentrepreneur/privacyIDEA-docker.git
cd privacyIDEA-docker
cp .env.example .env   # editar variables
docker compose up -d
```

Acceder a `http://localhost:8080` e iniciar sesion con el admin definido en `.env`.

## Estructura

```
privacyIDEA-docker/
├── docker-compose.yml
├── .env.example
├── entrypoint.sh
├── scripts/
│   └── seed_admin.sh
└── docs/
    └── DEPLOYMENT.md
```

## Documentacion

- [DEPLOYMENT.md](docs/DEPLOYMENT.md) — guia de instalacion, variables y troubleshooting
