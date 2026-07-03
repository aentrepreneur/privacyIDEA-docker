# Deployment Guide — privacyIDEA-docker

## Requisitos

- Docker 24+ y Docker Compose v2
- Puerto 8080 disponible en el host
- DNS configurado (opcional, para TLS)

## Variables de Entorno

| Variable | Descripcion | Default |
|----------|-------------|---------|
| `POSTGRES_DB` | Nombre BD | privacyidea |
| `POSTGRES_USER` | Usuario BD | privacyidea |
| `POSTGRES_PASSWORD` | Password BD | *(requerido)* |
| `ADMIN_USER` | Admin inicial | admin |
| `ADMIN_PASSWORD` | Password admin | *(requerido)* |
| `SECRET_KEY` | Flask secret key | *(requerido)* |
| `PI_PEPPER` | Pepper para OTP | *(requerido)* |
| `TZ` | Zona horaria | UTC |

## Despliegue

```bash
cp .env.example .env
# Editar .env con valores seguros
docker compose up -d
docker compose logs -f  # verificar startup
```

## Healthcheck

El contenedor expone healthcheck en `/auth`. Verificar con:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/auth
# Respuesta esperada: 200
```

## Troubleshooting

- **502 Bad Gateway**: Apache no termino de iniciar. Esperar 10-15s.
- **Conexion BD rechazada**: PostgreSQL tarda en arrancar. El entrypoint reintenta automaticamente.
- **Logs de aplicacion**: `docker compose logs app`
