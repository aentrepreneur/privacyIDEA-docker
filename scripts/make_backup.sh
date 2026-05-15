#!/bin/bash
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Crea Backup Completo del Stack privacyIDEA-docker
# =================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DATE="$(date +%Y%m%d)"
ARCHIVES_DIR="$PROJECT_DIR/restore"
WORK_DIR="$ARCHIVES_DIR/pi-docker_bk_$TIMESTAMP"
FINAL_TGZ="$ARCHIVES_DIR/pi-docker-backup-$TIMESTAMP.tgz"

log() {
    printf '%s\n' "--- $* ---"
}

die() {
    printf '%s\n' "ERROR: $*" >&2
    exit 1
}

if [ ! -d "$ARCHIVES_DIR" ]; then
    mkdir -p "$ARCHIVES_DIR"
    log "Creado directorio: $ARCHIVES_DIR"
fi

if [ ! -f "$PROJECT_DIR/.env" ]; then
    die "No existe $PROJECT_DIR/.env"
fi

source "$PROJECT_DIR/.env"

log "Iniciando backup privacyIDEA-docker..."

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/var/lib/privacyidea/backup"
mkdir -p "$WORK_DIR/etc/privacyidea"
mkdir -p "$WORK_DIR/etc/freeradius/3.0"

log "Generando dump de base de datos"
docker exec -i mysql mysqldump \
    --single-transaction \
    --skip-lock-tables \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    "${MYSQL_DATABASE}" > "$WORK_DIR/var/lib/privacyidea/backup/dbdump-$DATE-$TIMESTAMP.sql"

log "Copiando configuracion de privacyIDEA (local)"
cp "$PROJECT_DIR/config/privacyidea/pi.cfg" "$WORK_DIR/etc/privacyidea/" 2>/dev/null || true
cp "$PROJECT_DIR/config/privacyidea/logging.cfg" "$WORK_DIR/etc/privacyidea/" 2>/dev/null || true

log "Copiando llaves persistentes desde contenedor"
docker cp privacyidea:/opt/privacyidea/data/enckey "$WORK_DIR/etc/privacyidea/"
docker cp privacyidea:/opt/privacyidea/data/private.pem "$WORK_DIR/etc/privacyidea/"
docker cp privacyidea:/opt/privacyidea/data/public.pem "$WORK_DIR/etc/privacyidea/"
docker cp privacyidea:/opt/privacyidea/data/gpg "$WORK_DIR/etc/privacyidea/" 2>/dev/null || true
docker cp privacyidea:/opt/privacyidea/data/CA "$WORK_DIR/etc/privacyidea/" 2>/dev/null || true

log "Copiando rlm_perl.ini a etc/privacyidea/"
cp "$PROJECT_DIR/config/freeradius/rlm_perl.ini" "$WORK_DIR/etc/privacyidea/" 2>/dev/null || true

log "Copiando FreeRADIUS desde proyecto local"
mkdir -p "$WORK_DIR/etc/freeradius/3.0"
cp -a "$PROJECT_DIR/config/freeradius/sites-enabled" "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
cp -a "$PROJECT_DIR/config/freeradius/mods-enabled" "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
cp -a "$PROJECT_DIR/config/freeradius/mods-config" "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
cp "$PROJECT_DIR/config/freeradius/clients.conf" "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true

log "Copiando FreeRADIUS desde contenedor (mods-available, sites-available, etc)"
docker cp freeradius:/etc/freeradius/3.0/mods-available "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
docker cp freeradius:/etc/freeradius/3.0/sites-available "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
docker cp freeradius:/etc/freeradius/3.0/proxy.conf "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
docker cp freeradius:/etc/freeradius/3.0/dictionary "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
docker cp freeradius:/etc/freeradius/3.0/trigger.conf "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
docker cp freeradius:/etc/freeradius/3.0/scripts "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true
docker cp freeradius:/etc/freeradius/3.0/policy.d "$WORK_DIR/etc/freeradius/3.0/" 2>/dev/null || true

log "Incluyendo configuracion Docker del proyecto (pre-bootstrap)"
mkdir -p "$WORK_DIR/docker"
cp "$PROJECT_DIR/docker-compose.yml" "$WORK_DIR/docker/"
# env.template no incluido en pi-docker
[ -f "$PROJECT_DIR/.env.template" ] && cp "$PROJECT_DIR/.env.template" "$WORK_DIR/docker/.env.template" 2>/dev/null || true
cp "$PROJECT_DIR/bootstrap.sh" "$WORK_DIR/docker/"

if [ -d "$PROJECT_DIR/config" ]; then
    cp -a "$PROJECT_DIR/config" "$WORK_DIR/docker/"
    rm -rf "$WORK_DIR/docker/config/apache/certs" \
           "$WORK_DIR/docker/config/openldap/certs" \
           "$WORK_DIR/docker/config/openldap/data" \
           "$WORK_DIR/docker/config/redis/data"
fi

log "Ajustando permisos del respaldo"
find "$WORK_DIR" -type f -name 'enckey' -exec chmod 400 {} + 2>/dev/null || true
find "$WORK_DIR" -type f -name 'private.pem' -exec chmod 400 {} + 2>/dev/null || true
find "$WORK_DIR" -type f -name 'public.pem' -exec chmod 400 {} + 2>/dev/null || true

log "Empaquetando respaldo en formato on-premise"
tar -czf "$FINAL_TGZ" -C "$WORK_DIR" .

rm -rf "$WORK_DIR"

log "Backup completado: $FINAL_TGZ"
log "Tamanio: $(du -h "$FINAL_TGZ" | cut -f1)"

#End Development By AEntrepreneur [PI-docker 2026]
