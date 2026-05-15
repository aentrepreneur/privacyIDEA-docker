#!/bin/bash
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Preparacion Host, Instalacion Docker y Despliegue
# =================================================================
# sudo bash bootstrap.sh
# =================================================================
PI_PATH=$(dirname "$(readlink -f "$0")")

# Garantizar estructura minima de directorios
for dir in scripts config restore; do
    [ -d "$PI_PATH/$dir" ] || mkdir -p "$PI_PATH/$dir"
done

echo ""
echo "--- Proyecto: $PI_PATH ---"

# Repositorios Previos Evitar Conflictos GPG
export DEBIAN_FRONTEND=noninteractive
sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null

# Instalación dependencias base sistema
sudo apt-get update -y > /dev/null 2>&1
sudo apt-get upgrade -y > /dev/null 2>&1
sudo apt-get autoremove -y > /dev/null 2>&1
sudo apt-get install -y ca-certificates curl dos2unix gnupg htop openssh-server sysstat tree unzip > /dev/null 2>&1

if ! command -v docker &> /dev/null; then
    echo "--- Instalando Docker Engine ---"    
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo rm -f /etc/apt/keyrings/docker.gpg
    # Método Seguro (Validando SSL) Llave GPG
    # curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes > /dev/null 2>&1
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    # Registro Repositorio
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs 2>/dev/null || . /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    # Instalación Docker
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker ${SUDO_USER:-$USER}
else
    echo ""
    echo "--- Docker Instalado - Limpieza Total ---"
    echo ""
    cd "$PI_PATH"
    sudo docker compose down -v --remove-orphans 2>/dev/null || true
    sudo docker system prune -f 2>/dev/null || true
fi
echo ""
echo "--- Normalizando Archivos y Permisos ---"
sudo find . -type f -not -path '*/.*' -exec dos2unix -q {} + 2>/dev/null || true
sudo chmod +x scripts/*.sh config/privacyidea/*.sh 2>/dev/null || true
# =================================================================
# Script Aprovisionamiento privacyidea (privacyIDEA-docker)
# =================================================================
set -e

LOCATE=$(cd "$(dirname "$(dirname "$0")")" && pwd)

# Validación y Corrección Ruta Ejecución Oficial
if [ "$PWD" != "$PI_PATH" ]; then
    echo "--- Detectada Ejecución Fuera Ruta Oficial ---"
    echo "--- ORIGEN: $LOCATE"
    echo "--- PI_PATH: $PI_PATH ---"

    sudo mkdir -p "$PI_PATH"
    sudo cp -a "$LOCATE/." "$PI_PATH/"
    echo "--- Copia Completa. Saltando PI_PATH... ---"

    cd "$PI_PATH"
    exec sudo bash "scripts/bootstrap.sh" "$@"
fi
echo ""
echo "--- Ejecutando: $PWD ---"

# =================================================================
# Bloque 2: Detección de Recursos y Hardening SO
# =================================================================
echo ""
echo "--- 2. Detectando Recursos del Host ---"
echo ""
TOTAL_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 2)
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')

echo "      -> CPU Cores detectados: $TOTAL_CORES"
echo "      -> RAM total: ${TOTAL_RAM_MB}MB"

if [ $TOTAL_RAM_MB -le 4096 ]; then
    PROFILE_NAME="small"
    SWAP_SIZE="4G"
    PI_CPU="1.5"
    PI_MEMORY="1500M"
    MYSQL_CPU="0.80"
    MYSQL_MEMORY="1200M"
    REDIS_CPU="0.20"
    REDIS_MEMORY="256M"
    OPENLDAP_CPU="0.40"
    OPENLDAP_MEMORY="512M"
    APACHE_CPU="0.30"
    APACHE_MEMORY="300M"
    FREERADIUS_CPU="0.20"
    FREERADIUS_MEMORY="200M"
    PI_CHECK_RELOAD="600"
    PI_LOG_LEVEL="INFO"
elif [ $TOTAL_RAM_MB -le 8192 ]; then
    PROFILE_NAME="medium"
    SWAP_SIZE="4G"
    PI_CPU="2.0"
    PI_MEMORY="2000M"
    MYSQL_CPU="1.5"
    MYSQL_MEMORY="2000M"
    REDIS_CPU="0.30"
    REDIS_MEMORY="384M"
    OPENLDAP_CPU="0.50"
    OPENLDAP_MEMORY="512M"
    APACHE_CPU="0.50"
    APACHE_MEMORY="400M"
    FREERADIUS_CPU="0.30"
    FREERADIUS_MEMORY="256M"
    PI_CHECK_RELOAD="300"
    PI_LOG_LEVEL="INFO"
else
    PROFILE_NAME="large"
    SWAP_SIZE="8G"
    PI_CPU="4.0"
    PI_MEMORY="4000M"
    MYSQL_CPU="2.0"
    MYSQL_MEMORY="3000M"
    REDIS_CPU="0.50"
    REDIS_MEMORY="512M"
    OPENLDAP_CPU="0.80"
    OPENLDAP_MEMORY="768M"
    APACHE_CPU="0.80"
    APACHE_MEMORY="512M"
    FREERADIUS_CPU="0.50"
    FREERADIUS_MEMORY="384M"
    PI_CHECK_RELOAD="180"
    PI_LOG_LEVEL="WARNING"
fi

# Workers escalan segun cores reales (maximo 4 asumidos)
ASSUMED_CORES=$(( TOTAL_CORES > 4 ? 4 : TOTAL_CORES ))
PI_WORKERS=$(( 2 * ASSUMED_CORES + 1 ))

echo "      -> Perfil asignado: $PROFILE_NAME"
echo "      -> Swap asignado: $SWAP_SIZE"

# Configurar Swap proporcional
sudo swapoff -a 2>/dev/null || true
sudo rm -f /swapfile
if [ "$SWAP_SIZE" = "4G" ]; then
    SWAP_BLOCKS=4096
else
    SWAP_BLOCKS=8192
fi
sudo fallocate -l $SWAP_SIZE /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_BLOCKS
sudo chmod 600 /swapfile
sudo mkswap /swapfile >/dev/null && sudo swapon /swapfile

if ! grep -q "/swapfile" /etc/fstab; then
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

sudo sysctl vm.swappiness=10 >/dev/null
if ! grep -q "vm.swappiness=10" /etc/sysctl.conf; then
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
fi

echo "      -> Swappiness: $(cat /proc/sys/vm/swappiness)"
echo ""
sudo swapon --show >/dev/null

# =================================================================
# Bloque 3: Selección de Versión y Generación .env
# =================================================================
echo ""
echo "--- 3. Configurar Versión: $PI_PATH ---"
cd "$PI_PATH"
echo ""
echo "Seleccionar version de privacyIDEA:"
echo ""
echo "1) v3.2.2  (Legacy - Ubuntu20.04, Python3.8, MySQL5.7)"
echo "2) v3.7.1  (Estable - Ubuntu20.04, Python3.8, MySQL8.0)"
echo "3) v3.12.3 (Actual  - Ubuntu22.04, Python3.10, MySQL8.0)"
echo ""
while true; do
    read -p "Opción [1-3]: " OPCION
    case $OPCION in
        1)
            V_PI="3.2.2"
            V_UBUNTU="20.04"
            V_PYTHON="3.8"
            V_MYSQL="5.7"
            V_RADIUS="3.0.20"
            break
            ;;
        2)
            V_PI="3.7.1"
            V_UBUNTU="20.04"
            V_PYTHON="3.8"
            V_MYSQL="8.0"
            V_RADIUS="3.0.21"
            break
            ;;
        3)
            V_PI="3.12.3"
            V_UBUNTU="22.04"
            V_PYTHON="3.10"
            V_MYSQL="8.0"
            V_RADIUS="3.0.26"
            break
            ;;
        *)
            echo "Opción Incorrecta, intenta de nuevo..."
            ;;
    esac
done

# Generación de credenciales aleatorias con triple fallback
safe_generate_password() {
    local length="${1:-16}"
    local default="$2"
    local result

    result=$(openssl rand -base64 48 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c "$length")
    if [ -n "$result" ] && [ ${#result} -ge "$length" ]; then
        echo "$result"
        return
    fi

    result=$(head -c 128 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length")
    if [ -n "$result" ] && [ ${#result} -ge "$length" ]; then
        echo "$result"
        return
    fi

    echo "$default"
}

MYSQL_ROOT_PASSWORD=$(safe_generate_password 16 "root_secret_2026")
MYSQL_PASSWORD=$(safe_generate_password 16 "pi_db_password_2026")
PI_ADMIN_PASSWORD=$(safe_generate_password 16 "pi_admin_2026")
PI_SECRET_KEY=$(safe_generate_password 32 "pi_secret_key_2026")
PI_PEPPER=$(safe_generate_password 24 "pi_pepper_2026")
REDIS_PASSWORD=$(safe_generate_password 16 "redis_password_2026")
LDAP_ADMIN_PASSWORD=$(safe_generate_password 16 "ldap_admin_2026")
LDAP_CONFIG_PASSWORD=$(safe_generate_password 16 "ldap_config_2026")
RADIUS_SECRET=$(safe_generate_password 16 "radius_secret_2026")

echo ""
echo "--- Generando Accesos: privacyIDEA $V_PI ---"

# Escritura Archivo Técnico .env
cat <<EOF | sudo tee .env > /dev/null
# privacyIDEA
UBUNTU_VERSION=$V_UBUNTU
PYTHON_VERSION=$V_PYTHON
PI_VERSION=$V_PI
PI_PATH=$PI_PATH

# MYSQL
MYSQL_VERSION=$V_MYSQL
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_USER=pi_user
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_DATABASE=privacyidea

# SECURITY
PI_ADMIN_USER=admin
PI_ADMIN_PASSWORD=$PI_ADMIN_PASSWORD
PI_SECRET_KEY=$PI_SECRET_KEY
PI_PEPPER=$PI_PEPPER
PI_URL=http://privacyidea:8000/validate/check

# PROXY
APACHE_VERSION=2.4.66
HTTPS_PORT=443
REDIS_VERSION=7.4-alpine
REDIS_PASSWORD=$REDIS_PASSWORD

# OPENLDAP
LDAP_VERSION=ubuntu-slapd
LDAP_ORGANISATION=privacyIDEA-docker
LDAP_DOMAIN=docker.local
LDAP_BASE_DN=dc=docker,dc=local
LDAP_ADMIN_PASSWORD=$LDAP_ADMIN_PASSWORD
LDAP_CONFIG_PASSWORD=$LDAP_CONFIG_PASSWORD
LDAP_TLS_COMMON_NAME=openldap.docker.local
LDAP_TLS_COUNTRY=ES
LDAP_TLS_STATE=Local
LDAP_TLS_LOCALITY=Local
LDAP_TLS_ORG=privacyIDEA-docker
LDAP_TLS_OU=IT

# FREERADIUS
FREERADIUS_VERSION=$V_RADIUS
RADIUS_SECRET=$RADIUS_SECRET

# RESOURCE PROFILE (auto-detected: $PROFILE_NAME)
PROFILE_NAME=$PROFILE_NAME
TOTAL_CORES=$TOTAL_CORES
TOTAL_RAM_MB=$TOTAL_RAM_MB

# GUNICORN
GUNICORN_WORKERS=$PI_WORKERS

# PRIVACYIDEA RESOURCES
PI_CPU=$PI_CPU
PI_MEMORY=$PI_MEMORY
PI_CHECK_RELOAD_CONFIG=$PI_CHECK_RELOAD
PI_LOG_LEVEL=$PI_LOG_LEVEL

# MYSQL RESOURCES
MYSQL_CPU=$MYSQL_CPU
MYSQL_MEMORY=$MYSQL_MEMORY

# REDIS RESOURCES
REDIS_CPU=$REDIS_CPU
REDIS_MEMORY=$REDIS_MEMORY

# OPENLDAP RESOURCES
OPENLDAP_CPU=$OPENLDAP_CPU
OPENLDAP_MEMORY=$OPENLDAP_MEMORY

# APACHE RESOURCES
APACHE_CPU=$APACHE_CPU
APACHE_MEMORY=$APACHE_MEMORY

# FREERADIUS RESOURCES
FREERADIUS_CPU=$FREERADIUS_CPU
FREERADIUS_MEMORY=$FREERADIUS_MEMORY
EOF

# Carga Variables Entorno Actual
set -a
source ./.env
set +a

# Copiar archivos .gitignore y .dockerignore
sudo cp "$PI_PATH/.gitignore" "$PI_PATH/.dockerignore" "$PI_PATH/" 2>/dev/null || true

# =================================================================
# Bloque 4: Despliegue y Validación Final
# =================================================================
echo ""
echo "--- 4. Iniciando Despliegue Docker Compose v2 ---"
cd "$PI_PATH"

# Crear Estructura Directorios Persistentes
sudo mkdir -p config/apache/certs/ config/redis/data/ config/openldap/data/ config/openldap/config/
sudo mkdir -p config/openldap/certs/ config/openldap/custom/
sudo mkdir -p config/freeradius/mods-enabled config/freeradius/sites-enabled config/freeradius/mods-config/perl
sudo chmod -R 755 config/freeradius/

# Generar Certificados SSL/TLS Apache
echo ""
echo "      -> Generando Certificados Temporales..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout config/apache/certs/pi.key \
        -out config/apache/certs/pi.pem -subj "/C=ES/ST=Local/L=Local/O=IT/CN=privacyidea.local" 2>/dev/null

# === Preparar OpenLDAP ===
echo ""
echo "--- 4.1. Configuración OpenLDAP..."
echo ""
cd "$PI_PATH"

# Generar Certificados TLS OpenLDAP
if [ ! -f config/openldap/certs/server.key ] || [ ! -f config/openldap/certs/server.crt ]; then
    echo "      -> Generando Certificados TLS OpenLDAP..."
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout config/openldap/certs/server.key \
        -out config/openldap/certs/server.crt \
        -subj "/C=${LDAP_TLS_COUNTRY}/ST=${LDAP_TLS_STATE}/L=${LDAP_TLS_LOCALITY}/O=${LDAP_TLS_ORG}/OU=${LDAP_TLS_OU}/CN=${LDAP_TLS_COMMON_NAME}" \
        2>/dev/null
fi

# Creación Archivo Base slapd.conf
echo "      -> Creando Configuración slapd.conf..."
sudo mkdir -p config/openldap/config
sudo tee config/openldap/config/slapd.conf > /dev/null <<SLAPDCONF
include /etc/ldap/schema/core.schema
include /etc/ldap/schema/cosine.schema
include /etc/ldap/schema/inetorgperson.schema
include /etc/ldap/schema/nis.schema

pidfile /var/run/slapd/slapd.pid
argsfile /var/run/slapd/slapd.args

modulepath /usr/lib/ldap
moduleload back_mdb

TLSCertificateFile /opt/bootstrap/certs/server.crt
TLSCertificateKeyFile /opt/bootstrap/certs/server.key

database mdb
suffix "${LDAP_BASE_DN}"
rootdn "cn=admin,${LDAP_BASE_DN}"
rootpw ${LDAP_ADMIN_PASSWORD}
directory /var/lib/ldap

index objectClass eq
index cn,sn,uid pres,eq,sub
SLAPDCONF

echo "      -> Infraestructura OpenLDAP Completa."
# === Fin Preparación OpenLDAP ===

# === Preparar FreeRADIUS ===
echo ""
echo "--- 4.2. Configuración FreeRADIUS..."
echo ""
cd "$PI_PATH"

sudo mkdir -p config/freeradius
sudo tee config/freeradius/clients.conf > /dev/null <<CLIENTSCONF
# clients.conf --- RADIUS NAS/clients
# Generado por bootstrap.sh - privacyIDEA-docker

client localhost_test {
    ipaddr      = 127.0.0.1/32
    secret      = ${RADIUS_SECRET}
    shortname   = localhost_test
    nastype     = other
}

# client vpn_gateway {
#     ipaddr   = 192.168.1.1/32
#     secret   = secreto_muy_seguro
#     shortname = fw-vpn
#     nastype  = other
# }
CLIENTSCONF

echo "      -> Infraestructura FreeRADIUS Completa."
# === Fin Preparación FreeRADIUS ===

# Construcción y Levantamiento Contenedores
echo "      -> Construyendo Contenedores..."
echo ""
sudo docker compose up -d --build
echo ""
echo "=========================================================="
echo "--- VALIDACIÓN FINAL ---"
echo "=========================================================="
# Pausa para inicializacion de servicios
sleep 10 

echo ""
echo "[+] Perfil de Recursos: $PROFILE_NAME (CPU cores: $TOTAL_CORES | RAM: ${TOTAL_RAM_MB}MB)"
echo "[+] Contenedores:"
sudo docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo ""
echo "[+] Versionamiento:"
echo -n "privacyIDEA:  " && docker exec privacyidea pip show privacyidea | grep Version && \
echo -n "freeRADIUS:   " && docker exec freeradius freeradius -v | grep Version | head -n 1 | cut -d',' -f1 && \
echo -n "MySQL:        " && docker exec mysql mysql -V | cut -d',' -f1 && \
echo -n "openLDAP:     " && docker exec openldap slapd -V 2>&1 | head -n 1 | awk -F' ' '{print $1,$2,$3,$4")"}' && \
echo -n "Redis:        " && docker exec redis redis-server -v | cut -d' ' -f1-3 && \
echo -n "Apache:       " && docker exec apache httpd -v | grep version | cut -d'/' -f2 && \
echo -n "OS (PI):      " && docker exec privacyidea cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 && \
echo ""
echo "[+] Memoria:"
free -h

echo ""
echo "[+] Espacio:"
df -Th /

echo ""
echo "=========================================="
echo "  CREDENCIALES GENERADAS (GUARDAR)"
echo "=========================================="
echo "  MySQL Root:      $MYSQL_ROOT_PASSWORD"
echo "  MySQL App:       $MYSQL_PASSWORD"
echo "  PI Admin User:   admin"
echo "  PI Admin Pass:   $PI_ADMIN_PASSWORD"
echo "  Redis:           $REDIS_PASSWORD"
echo "  LDAP Admin:      $LDAP_ADMIN_PASSWORD"
echo "  LDAP Config:     $LDAP_CONFIG_PASSWORD"
echo "  RADIUS Secret:   $RADIUS_SECRET"
echo "=========================================="
echo "  Estas credenciales están en .env"
echo "  Si las pierdes, deberás regenerarlas"
echo "=========================================="

echo ""
echo "¡Aprovisionado Correctamente!"
echo ""

#End Development By AEntrepreneur [PI-docker 2026]
