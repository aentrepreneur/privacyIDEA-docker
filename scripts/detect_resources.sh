#!/bin/bash
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Deteccion de Recursos del Host - Perfil de Recursos
# =================================================================

echo ""
echo "========================================"
echo "  DETECCION DE RECURSOS - privacyIDEA-docker"
echo "========================================"

# Detectar CPU cores
TOTAL_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 2)

# Detectar RAM total en MB
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')

# Detectar Swap
SWAP_MB=$(free -m | awk '/^Swap:/ {print $2}')
[ -z "$SWAP_MB" ] && SWAP_MB=0

# Asignar perfil
if [ $TOTAL_RAM_MB -le 4096 ]; then
    PROFILE_NAME="small"
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

# Calcular totales
TOTAL_CPU=$(awk "BEGIN {printf \"%.2f\", $PI_CPU + $MYSQL_CPU + $REDIS_CPU + $OPENLDAP_CPU + $APACHE_CPU + $FREERADIUS_CPU}" 2>/dev/null || echo "N/A")
TOTAL_RAM=$(( ${PI_MEMORY//M/} + ${MYSQL_MEMORY//M/} + ${REDIS_MEMORY//M/} + ${OPENLDAP_MEMORY//M/} + ${APACHE_MEMORY//M/} + ${FREERADIUS_MEMORY//M/} ))
WORKERS_FORMULA="2 x $ASSUMED_CORES + 1"

echo ""
echo "HOST INFORMATION:"
echo "  CPU Cores:        $TOTAL_CORES"
echo "  RAM Total:        ${TOTAL_RAM_MB} MB"
echo "  Swap:             ${SWAP_MB} MB"
echo ""
echo "DETECTED PROFILE:   $PROFILE_NAME"
echo ""
echo "RESOURCE ALLOCATION:"
printf "┌──────────────┬──────────┬──────────┐\n"
printf "│ %-12s │ %-8s │ %-8s │\n" "Service" "CPU" "Memory"
printf "├──────────────┼──────────┼──────────┤\n"
printf "│ %-12s │ %-8s │ %-8s │\n" "privacyIDEA" "$PI_CPU" "$PI_MEMORY"
printf "│ %-12s │ %-8s │ %-8s │\n" "MySQL" "$MYSQL_CPU" "$MYSQL_MEMORY"
printf "│ %-12s │ %-8s │ %-8s │\n" "Redis" "$REDIS_CPU" "$REDIS_MEMORY"
printf "│ %-12s │ %-8s │ %-8s │\n" "OpenLDAP" "$OPENLDAP_CPU" "$OPENLDAP_MEMORY"
printf "│ %-12s │ %-8s │ %-8s │\n" "Apache" "$APACHE_CPU" "$APACHE_MEMORY"
printf "│ %-12s │ %-8s │ %-8s │\n" "FreeRADIUS" "$FREERADIUS_CPU" "$FREERADIUS_MEMORY"
printf "├──────────────┼──────────┼──────────┤\n"
printf "│ %-12s │ %-8s │ %-8s │\n" "TOTAL STACK" "$TOTAL_CPU" "${TOTAL_RAM}M"
printf "└──────────────┴──────────┴──────────┘\n"
echo ""
echo "GUNICORN:"
echo "  Formula:        ($WORKERS_FORMULA) = $PI_WORKERS"
echo "  Workers:        $PI_WORKERS"
echo ""
echo "PERFORMANCE:"
echo "  PI_CHECK_RELOAD:  ${PI_CHECK_RELOAD}s"
echo "  Log Level:        $PI_LOG_LEVEL"
echo ""

# Verificar si los recursos caben en el host
if [ $TOTAL_RAM -gt $TOTAL_RAM_MB ]; then
    echo "STATUS:   [WARN] Stack requiere ${TOTAL_RAM}MB pero solo hay ${TOTAL_RAM_MB}MB disponibles"
    echo "          Considerar usar un perfil menor o aumentar RAM"
elif [ "$TOTAL_CPU" != "N/A" ]; then
    INT_CPU=$(echo "$TOTAL_CPU" | cut -d'.' -f1)
    if [ "${INT_CPU:-0}" -gt "$TOTAL_CORES" ]; then
        echo "STATUS:   [WARN] CPU asignada ($TOTAL_CPU) excede cores disponibles ($TOTAL_CORES)"
        echo "          Los contenedores compartiran CPU con throttling"
    else
        echo "STATUS:   [OK] Resources within available capacity"
    fi
else
    echo "STATUS:   [OK] Profile assigned (CPU total calculation skipped)"
fi

echo ""
echo "ENV VARIABLES (para .env):"
echo "  PROFILE_NAME=$PROFILE_NAME"
echo "  GUNICORN_WORKERS=$PI_WORKERS"
echo "  PI_CPU=$PI_CPU"
echo "  PI_MEMORY=$PI_MEMORY"
echo "  MYSQL_CPU=$MYSQL_CPU"
echo "  MYSQL_MEMORY=$MYSQL_MEMORY"
echo "  PI_CHECK_RELOAD_CONFIG=$PI_CHECK_RELOAD"
echo "  PI_LOG_LEVEL=$PI_LOG_LEVEL"
echo ""

#End Development By AEntrepreneur [PI-docker 2026]
