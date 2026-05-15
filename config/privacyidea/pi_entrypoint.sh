#!/bin/bash
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Entrypoint del Contenedor privacyIDEA
# =================================================================
# Pasos: espera MySQL, crea esquema DDL, genera enckey/RSA, crea admin, arranca Gunicorn
# Workers: configurable via GUNICORN_WORKERS
# Persistencia: volumen pi_data (enckey, private.pem)
# =================================================================
set -e

# Variables de Entorno Críticas
export PRIVACYIDEA_CONFIGFILE=/opt/privacyidea/etc/pi.cfg
WORKERS=${GUNICORN_WORKERS:-4}

echo "Iniciando proceso de arranque de privacyIDEA v${PI_VERSION}..."
sleep 10
# 0. Esperar Conexion a Base de Datos (MySQL)
echo "[0/5] Esperando conexion real a Base de Datos..."
until mysql -h mysql -u"${MYSQL_USER:-CHANGE_ME}" -p"${MYSQL_PASSWORD:-CHANGE_ME}" \
      "${MYSQL_DATABASE:-CHANGE_ME}" -e "SELECT 1;"; do
    echo "      -> Base de Datos no disponible. Reintentando en 3s..."
    sleep 3
done
echo "      -> Conexion a Base de Datos establecida."

# 1. Inicialización de Esquema DDL
echo "[1/5] Verificando esquema de Base de Datos..."
pi-manage createdb || true

# 2. Gestión de Llave Criptográfica Simétrica (enckey)
echo "[2/5] Validando integridad de claves de cifrado simétrico..."
if [ ! -f /opt/privacyidea/data/enckey ]; then
    echo "      -> Generando nueva clave (enckey)..."
    pi-manage create_enckey 
else
    echo "      -> Clave enckey persistente detectada. Omitiendo generación."
fi

# 3. Gestion de Par de Llaves RSA (Auditoria)
echo "[3/5] Validando integridad de claves de auditoría RSA..."
if [ ! -f /opt/privacyidea/data/private.pem ]; then
    echo "      -> Generando par de claves RSA para auditoría..."
    pi-manage create_audit_keys 
else
    echo "      -> Claves de auditoría persistentes detectadas. Omitiendo generación."
fi

# 4. Aprovisionamiento de Administrador Base
echo "[4/5] Verificando cuenta de administrador maestro..."
pi-manage admin add "${PI_ADMIN_USER:-CHANGE_ME}" -p "${PI_ADMIN_PASSWORD:-CHANGE_ME}" 2>&1 || \
    echo "[WARN] Admin ${PI_ADMIN_USER} ya existe, se conserva password del backup"

# 5. Arranque de Motor WSGI (Gunicorn)
echo "[5/5] Levantando Gunicorn WSGI Server con $WORKERS workers concurrentes..."
exec gunicorn -b 0.0.0.0:8000 -w $WORKERS --access-logfile - --error-logfile - "privacyidea.app:create_app(config_name='production', config_file='/opt/privacyidea/etc/pi.cfg')"

#End Development By AEntrepreneur [PI-docker 2026]
