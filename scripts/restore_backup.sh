#!/bin/bash
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Restaura Backup On-Premise al Entorno Docker
# =================================================================
# Restaura: SQL dump, enckey, private.pem, public.pem
# Restaura: GPG home, CA, config FreeRADIUS
# Valida integridad antes de cada restauracion
# =================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVES_DIR="$PROJECT_DIR/restore"
RESTORE_DIR="$ARCHIVES_DIR/restore_$TIMESTAMP"

log() {
    printf '%s\n' "--- $* ---"
}

die() {
    printf '%s\n' "ERROR: $*" >&2
    exit 1
}

# ================================================
# TOGGLES: Habilitar/Deshabilitar restauracion de servicios
# Nota: RESTORE_DOCKER no aplica para backup on-premise
# ================================================
RESTORE_SQL=true
RESTORE_KEYS=true
RESTORE_GPG=true
RESTORE_FREERADIUS=true
RESTORE_PI_CFG=true

# ================================================
# FUNCIONES AUXILIARES
# ================================================

find_single_file() {
    local search_dir="$1"
    local pattern="$2"

    find "$search_dir" -type f -name "$pattern" 2>/dev/null | sort | head -n 1
}

resolve_backup_file() {
    if [ "$#" -gt 0 ]; then
        local given_file="$1"
        if [ -f "$given_file" ]; then
            printf '%s\n' "$given_file"
            return 0
        fi
        if [ -f "$ARCHIVES_DIR/$given_file" ]; then
            printf '%s\n' "$ARCHIVES_DIR/$given_file"
            return 0
        fi
        die "No se pudo localizar el respaldo: $given_file"
    fi

    shopt -s nullglob
    local backups=("$ARCHIVES_DIR"/pi-docker-backup-*.tgz)
    shopt -u nullglob

    if [ "${#backups[@]}" -eq 0 ]; then
        die "No se encontro ningun archivo pi-docker-backup-*.tgz en $ARCHIVES_DIR"
    fi

    if [ "${#backups[@]}" -gt 1 ]; then
        die "Hay varios pi-docker-backup-*.tgz en $ARCHIVES_DIR. Indica cual restaurar como argumento"
    fi

    printf '%s\n' "${backups[0]}"
}

restore_key_if_present() {
    local source_path="$1"
    local target_path="$2"

    if [ -n "$source_path" ] && [ -f "$source_path" ]; then
        sudo cp "$source_path" "$target_path"
    fi
}

get_pi_uid() {
    local uid
    uid=$(docker exec privacyidea id -u privacyidea 2>/dev/null || true)
    if [ -n "$uid" ] && [ "$uid" != "0" ]; then
        echo "$uid"
        return
    fi
    local pi_image
    pi_image=$(docker inspect privacyidea --format '{{.Config.Image}}' 2>/dev/null || true)
    if [ -n "$pi_image" ]; then
        uid=$(docker run --rm --entrypoint id "$pi_image" -u privacyidea 2>/dev/null || true)
        if [ -n "$uid" ]; then
            echo "$uid"
            return
        fi
    fi
    echo "999"
}

if [ ! -d "$ARCHIVES_DIR" ]; then
    mkdir -p "$ARCHIVES_DIR"
    log "Creado directorio: $ARCHIVES_DIR"
fi

if [ ! -f "$PROJECT_DIR/.env" ]; then
    die "No existe $PROJECT_DIR/.env"
fi

source "$PROJECT_DIR/.env"

BACKUP_FILE="$(resolve_backup_file "$@")"

if [ ! -f "$BACKUP_FILE" ]; then
    die "No existe el archivo $BACKUP_FILE"
fi

PI_DATA_PATH="$(docker volume inspect pi_data --format '{{ .Mountpoint }}' 2>/dev/null || true)"

if [ -z "$PI_DATA_PATH" ]; then
    die "No se pudo localizar el volumen Docker pi_data"
fi

rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"

log "Deteniendo servicios"
docker compose -f "$PROJECT_DIR/docker-compose.yml" stop privacyidea freeradius 2>/dev/null || true

log "Descomprimiendo respaldo $BACKUP_FILE"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# ================================================
# [1] SQL DUMP
# ================================================
if [ "$RESTORE_SQL" = true ]; then
    log "[1] SQL DUMP - Iniciando restauracion"

    SQL_FILE="$(find "$RESTORE_DIR" -path "*/var/lib/privacyidea/backup/*.sql" -type f 2>/dev/null | sort | head -n 1 || true)"

    if [ -z "$SQL_FILE" ]; then
        SQL_FILE="$(find "$RESTORE_DIR/var" -name "*.sql" -type f 2>/dev/null | sort | head -n 1 || true)"
    fi

    if [ -z "$SQL_FILE" ]; then
        SQL_FILE="$(find_single_file "$RESTORE_DIR" "*.sql")"
    fi

    if [ -z "$SQL_FILE" ]; then
        die "No se encontro ningun dump SQL dentro del respaldo"
    fi

    log "Recreando base de datos ${MYSQL_DATABASE}"
    docker exec -i mysql mysql \
        -u root \
        -p"${MYSQL_ROOT_PASSWORD}" \
        -e "DROP DATABASE IF EXISTS \`${MYSQL_DATABASE}\`; CREATE DATABASE \`${MYSQL_DATABASE}\` CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

    log "Importando dump SQL: $(basename "$SQL_FILE")"
    docker exec -i mysql mysql \
        -u root \
        -p"${MYSQL_ROOT_PASSWORD}" \
        "${MYSQL_DATABASE}" < "$SQL_FILE"

    log "[1] SQL DUMP - Completado"
else
    log "[1] SQL DUMP - Omitido (RESTORE_SQL=false)"
fi

# ================================================
# [2] LLAVES
# ================================================
if [ "$RESTORE_KEYS" = true ]; then
    log "[2] LLAVES - Iniciando restauracion"

    ENCKEY_FILE="$(find_single_file "$RESTORE_DIR" "enckey")"
    PRIVATE_KEY_FILE="$(find_single_file "$RESTORE_DIR" "private.pem")"
    PUBLIC_KEY_FILE="$(find_single_file "$RESTORE_DIR" "public.pem")"

    if [ -z "$ENCKEY_FILE" ]; then
        die "No se encontro enckey dentro del respaldo. No es seguro restaurar sin esa llave"
    fi

    log "Restaurando llaves a volumen pi_data"
    restore_key_if_present "$ENCKEY_FILE" "$PI_DATA_PATH/enckey"
    restore_key_if_present "$PRIVATE_KEY_FILE" "$PI_DATA_PATH/private.pem"
    restore_key_if_present "$PUBLIC_KEY_FILE" "$PI_DATA_PATH/public.pem"

    PI_UID=$(get_pi_uid)
    sudo chown -R "$PI_UID:$PI_UID" "$PI_DATA_PATH"
    sudo chmod 400 "$PI_DATA_PATH/enckey" 2>/dev/null || true

    if [ -f "$PI_DATA_PATH/private.pem" ]; then
        sudo chmod 400 "$PI_DATA_PATH/private.pem"
    fi

    if [ -f "$PI_DATA_PATH/public.pem" ]; then
        sudo chmod 400 "$PI_DATA_PATH/public.pem"
    fi

    log "[2] LLAVES - Completado"
else
    log "[2] LLAVES - Omitido (RESTORE_KEYS=false)"
fi

# ================================================
# [3] GPG/CA
# ================================================
if [ "$RESTORE_GPG" = true ]; then
    log "[3] GPG/CA - Buscando en respaldo"

    GPG_DIR="$(find "$RESTORE_DIR" -type d -name 'gpg' 2>/dev/null | sort | head -n 1 || true)"
    CA_DIR="$(find "$RESTORE_DIR" -type d -name 'CA' 2>/dev/null | sort | head -n 1 || true)"

    if [ -n "$GPG_DIR" ]; then
        log "Restaurando directorio GPG"
        sudo rm -rf "$PI_DATA_PATH/gpg"
        sudo cp -a "$GPG_DIR" "$PI_DATA_PATH/"
    else
        log "[3] GPG/CA - No encontrado, omitido"
    fi

    if [ -n "$CA_DIR" ]; then
        log "Restaurando directorio CA"
        sudo rm -rf "$PI_DATA_PATH/CA"
        sudo cp -a "$CA_DIR" "$PI_DATA_PATH/"
    fi

    log "[3] GPG/CA - Completado"
else
    log "[3] GPG/CA - Omitido (RESTORE_GPG=false)"
fi

# ================================================
# [4] PI.CFG (SECRET_KEY / PI_PEPPER)
# ================================================
if [ "$RESTORE_PI_CFG" = true ]; then
    log "[4] PI.CFG - Buscando identidad en respaldo"

    PI_CFG_FILE="$(find_single_file "$RESTORE_DIR" "pi.cfg")"

    if [ -n "$PI_CFG_FILE" ]; then
        log "Extrayendo llaves criptográficas de $PI_CFG_FILE"

        # 1. Extraer valores del archivo de respaldo
        OLD_SECRET=$(grep -E "^[[:space:]]*SECRET_KEY" "$PI_CFG_FILE" | cut -d'=' -f2 | tr -d " '\"" | tail -n1)
        OLD_PEPPER=$(grep -E "^[[:space:]]*PI_PEPPER" "$PI_CFG_FILE" | cut -d'=' -f2 | tr -d " '\"" | tail -n1)

        # 2. Actualizar el archivo .env del proyecto (HOST)
        if [ -n "$OLD_SECRET" ]; then
            log "Actualizando PI_SECRET_KEY en .env"
            sed -i "s|^PI_SECRET_KEY=.*|PI_SECRET_KEY=$OLD_SECRET|" "$PROJECT_DIR/.env"
        fi

        if [ -n "$OLD_PEPPER" ]; then
            log "Actualizando PI_PEPPER en .env"
            # Si la variable no existe en el .env, la añade. Si existe, la reemplaza.
            if grep -q "^PI_PEPPER=" "$PROJECT_DIR/.env"; then
                sed -i "s|^PI_PEPPER=.*|PI_PEPPER=$OLD_PEPPER|" "$PROJECT_DIR/.env"
            else
                echo "PI_PEPPER=$OLD_PEPPER" >> "$PROJECT_DIR/.env"
            fi
        fi

        # 3. Opcional: Copiar el archivo físico si lo deseas (aunque el .env manda)
        sudo cp "$PI_CFG_FILE" "$PI_DATA_PATH/pi.cfg.backup"
        log "Valores de identidad sincronizados con .env"
    else
        log "[4] PI.CFG - No encontrado, se mantienen valores actuales"
    fi

    log "[4] PI.CFG - Completado"
else
    log "[4] PI.CFG - Omitido (RESTORE_PI_CFG=false)"
fi

# ================================================
# [5] FREERADIUS
# ================================================
FREERADIUS_RESTORED=false

if [ "$RESTORE_FREERADIUS" = true ]; then
    log "[5] FREERADIUS - Buscando en respaldo"

    RADIUS_DIR=""
    RADIUS_DIR="$(find "$RESTORE_DIR" -type d -path '*/freeradius/3.0' 2>/dev/null | sort | head -n 1 || true)"

    if [ -z "$RADIUS_DIR" ]; then
        RADIUS_DIR="$(find "$RESTORE_DIR" -type d -path '*/freeradius' 2>/dev/null | grep -v '/3.0' | sort | head -n 1 || true)"
    fi

    if [ -z "$RADIUS_DIR" ]; then
        log "[5] FREERADIUS - No encontrado, omitido"
    else
        log "Restaurando FreeRADIUS desde: $(basename "$RADIUS_DIR")"

        RADIUS_TARGET="$PROJECT_DIR/config/freeradius"
        sudo mkdir -p "$RADIUS_TARGET"
        
        RADIUS_DIR_30="$RADIUS_DIR/3.0"
        if [ -d "$RADIUS_DIR_30" ]; then
            RADIUS_DIR="$RADIUS_DIR_30"
        fi

        if [ -d "$RADIUS_DIR/sites-enabled" ]; then
            sudo cp -a "$RADIUS_DIR/sites-enabled" "$RADIUS_TARGET/"
            FREERADIUS_RESTORED=true
        fi

        if [ -d "$RADIUS_DIR/mods-available" ]; then
            sudo cp -a "$RADIUS_DIR/mods-available" "$RADIUS_TARGET/"
            FREERADIUS_RESTORED=true
        fi

        if [ -d "$RADIUS_DIR/mods-enabled" ]; then
            sudo cp -a "$RADIUS_DIR/mods-enabled" "$RADIUS_TARGET/"
            # Docker bind mounts require regular files, not symlinks
            for _f in "$RADIUS_TARGET/mods-enabled/"*; do
                if [ -L "$_f" ]; then
                    _symlink_target=$(readlink "$_f")
                    _basename_target=$(basename "$_symlink_target")
                    _available_file="$RADIUS_TARGET/mods-available/$_basename_target"
                    if [ -f "$_available_file" ]; then
                        sudo rm -f "$_f" && sudo cp "$_available_file" "$_f"
                    else
                        sudo rm -f "$_f"
                    fi
                fi
            done
            # Remove localperl block if privacyidea_radiuslocal.pm does not exist in container
            # This prevents FreeRADIUS crash on missing file
            if [ -f "$RADIUS_TARGET/mods-enabled/perl" ]; then
                sudo sed -i '/^perl localperl {/,/^}/d' "$RADIUS_TARGET/mods-enabled/perl"
            fi
            FREERADIUS_RESTORED=true
        fi

        if [ -d "$RADIUS_DIR/mods-config" ]; then
            sudo cp -a "$RADIUS_DIR/mods-config" "$RADIUS_TARGET/"
            FREERADIUS_RESTORED=true
        fi

        if [ -f "$RADIUS_DIR/clients.conf" ]; then
            sudo cp "$RADIUS_DIR/clients.conf" "$RADIUS_TARGET/"
            FREERADIUS_RESTORED=true
        fi

        RLM_PERL_INI="$(find_single_file "$RESTORE_DIR" "rlm_perl.ini")"
        if [ -n "$RLM_PERL_INI" ]; then
            sudo cp "$RLM_PERL_INI" "$RADIUS_TARGET/"
            FREERADIUS_RESTORED=true
        fi

        if [ -d "$RADIUS_DIR/sites-available" ]; then
            sudo cp -a "$RADIUS_DIR/sites-available" "$RADIUS_TARGET/"
            FREERADIUS_RESTORED=true
        fi

        # Archivos de configuracion adicionales del backup on-premise
        for _f in proxy.conf dictionary trigger.conf; do
            if [ -f "$RADIUS_DIR/$_f" ]; then
                sudo cp "$RADIUS_DIR/$_f" "$RADIUS_TARGET/"
                log "$_f restaurado"
                FREERADIUS_RESTORED=true
            fi
        done

        # policy.d/ - politicas personalizadas
        if [ -d "$RADIUS_DIR/policy.d" ]; then
            sudo cp -a "$RADIUS_DIR/policy.d" "$RADIUS_TARGET/"
            log "policy.d restaurado"
            FREERADIUS_RESTORED=true
        fi

        # scripts/ - scripts de mantenimiento (NO certificados)
        if [ -d "$RADIUS_DIR/scripts" ]; then
            sudo cp -a "$RADIUS_DIR/scripts" "$RADIUS_TARGET/"
            log "scripts restaurado"
            FREERADIUS_RESTORED=true
        fi

        # certs/ NO se restaura - no portables a Docker, el container genera los suyos

        log "Aplicando Permisos de Seguridad a FreeRADIUS..."
        # Contenedor freeradius corre como root (sin USER en Dockerfile)
        sudo find "$RADIUS_TARGET" -type d -exec chmod 750 {} +
        sudo find "$RADIUS_TARGET" -type f -exec chmod 640 {} +
        # rlm_perl.ini necesita world-readable porque freerad (uid 1003) no es owner en host
        if [ -f "$RADIUS_TARGET/rlm_perl.ini" ]; then
            sudo chmod 644 "$RADIUS_TARGET/rlm_perl.ini"
        fi

        # Fusion Post-Restore: Adaptar configs on-premise a Docker
        # --- 5a. RADIUS SECRET: capturar valor real del backup, limpiar espacios/comentarios ---
        if [ -f "$RADIUS_TARGET/clients.conf" ]; then
            ONPREMISE_SECRET=$(grep -E "^[[:space:]]*secret[[:space:]]*=" "$RADIUS_TARGET/clients.conf" \
                | head -1 | awk -F'=' '{print $2}' | cut -d'#' -f1 | xargs)

            if [ -n "$ONPREMISE_SECRET" ]; then
                # Hay clients reales en el backup - unificar secret en .env
                if [ "$ONPREMISE_SECRET" != "${RADIUS_SECRET:-}" ]; then
                    sed -i "s|^RADIUS_SECRET=.*|RADIUS_SECRET=$ONPREMISE_SECRET|" "$PROJECT_DIR/.env"
                    RADIUS_SECRET="$ONPREMISE_SECRET"
                    log "RADIUS_SECRET unificado con valor on-premise: $ONPREMISE_SECRET"
                fi
            else
                # Solo placeholders en el backup - regenerar clients.conf para Docker
                log "No hay secrets reales en el backup - regenerando clients.conf para Docker"
                sudo tee "$RADIUS_TARGET/clients.conf" > /dev/null <<CLIENTSCONF
client localhost_test {
    ipaddr      = 127.0.0.1/32
    secret      = ${RADIUS_SECRET}
    shortname   = localhost_test
    nastype     = other
}
CLIENTSCONF
                sudo chmod 640 "$RADIUS_TARGET/clients.conf"
            fi
        fi

        # --- 5b. RLM_PERL.INI: corregir URL a Docker si viene como localhost ---
        if [ -f "$RADIUS_TARGET/rlm_perl.ini" ]; then
            sudo sed -i "s|^URL = https://localhost/validate/check|URL = http://privacyidea:8000/validate/check|" \
                "$RADIUS_TARGET/rlm_perl.ini"
        fi
    fi

    log "[5] FREERADIUS - Completado"
else
    log "[5] FREERADIUS - Omitido (RESTORE_FREERADIUS=false)"
fi

# ================================================
# LEVANTAR SERVICIOS
# ================================================
log "Levantando privacyIDEA"
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d privacyidea

sleep 5

echo""
log "Verificando Base de Datos..."
docker exec mysql mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}" --silent || die "MySQL Sin Respuesta Después de Restaurar..."

# ================================================
# [6] ADMIN PASSWORD SYNC
# ================================================
log "[6] ADMIN - Sincronizando contrasena de administrador"
log "Esperando que privacyIDEA termine entrypoint..."
sleep 15
PI_USER="${PI_ADMIN_USER:-admin}"
docker exec privacyidea pi-manage admin add "${PI_USER}" -p "${PI_ADMIN_PASSWORD}" 2>/dev/null && \
    log "Admin ${PI_USER} creado correctamente" || {
    log "Admin ${PI_USER} existe, forzando actualizacion..."
    docker exec mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" \
        -e "DELETE FROM admin WHERE username='${PI_USER}';" 2>/dev/null || true
    docker exec privacyidea pi-manage admin add "${PI_USER}" -p "${PI_ADMIN_PASSWORD}"
    log "Password de ${PI_USER} actualizada"
}
log "[6] ADMIN - Completado"

if [ "$FREERADIUS_RESTORED" = true ]; then
    echo""
    log "Reiniciando FreeRADIUS"
    docker compose -f "$PROJECT_DIR/docker-compose.yml" restart freeradius
fi

echo""
log "Limpieza Temporales..."
rm -rf "$RESTORE_DIR"

echo""
log "Restauracion Completada."

echo ""
echo "============================================================"
echo "  ACCESOS DEL SISTEMA PRIVACYIDEA-DOCKER (RESTORE)"
echo "============================================================"
echo ""
echo "  [URL]  https://$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")"
echo ""
echo "  [ADMIN WEB UI]"
echo "    Usuario: ${PI_ADMIN_USER:-admin}"
echo "    Password: ${PI_ADMIN_PASSWORD}"
echo "    Usuarios heredados del backup on-premise:"
docker exec mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" \
    -e "SELECT username FROM admin WHERE username != '${PI_ADMIN_USER}';" 2>/dev/null | tail -n +2 | while read -r user; do
    echo "      - $user (password: original del backup)"
done
echo ""
echo "  [MYSQL]"
echo "    Host: mysql / Puerto: 3306 / DB: ${MYSQL_DATABASE}"
echo "    Usuario: ${MYSQL_USER}"
echo "    Password: ${MYSQL_PASSWORD}"
echo "    Root Password: ${MYSQL_ROOT_PASSWORD}"
echo ""
echo "  [REDIS]"
echo "    Host: redis / Puerto: 6379"
echo "    Password: ${REDIS_PASSWORD}"
echo ""
echo "  [FREERADIUS]"
echo "    Secret: ${RADIUS_SECRET}"
echo ""
echo "  [OPENLDAP]"
echo "    Domain: ${LDAP_DOMAIN}"
echo "    Admin Password: ${LDAP_ADMIN_PASSWORD}"
echo "    Config Password: ${LDAP_CONFIG_PASSWORD}"
echo ""
echo "  [REALMS DEL BACKUP]"
echo "    defrealm (default) - usa resolver passwd local"
echo "    Los tokens de realms LDAP requieren reconexion a servidor LDAP valido"
echo ""
echo "============================================================"

#End Development By AEntrepreneur [PI-docker 2026]
