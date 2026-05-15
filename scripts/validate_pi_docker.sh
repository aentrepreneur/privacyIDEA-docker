#!/bin/bash
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Auditoria de Contenedores privacyIDEA-docker
# =================================================================
cd $(dirname "$(dirname "$(readlink -f "$0")")")
set -a && source .env 2>/dev/null && set +a

echo ""
echo "--- AUDITORIA PRIVACYIDEA-DOCKER (MULTIPLATFORM) ---"
echo -n "privacyIDEA:  " && docker exec privacyidea pip show privacyidea | grep Version
echo -n "freeRADIUS:   " && docker exec freeradius freeradius -v | grep Version | head -n 1 | cut -d"," -f1
echo -n "MySQL:        " && docker exec mysql mysql -V | cut -d"," -f1
echo -n "openLDAP:     " && docker exec openldap slapd -V 2>&1 | head -n 1 | awk -F" " '{print $1,$2,$3,$4")"}'
echo -n "Redis:        " && docker exec redis redis-server -v | cut -d" " -f1-3
echo -n "Apache:       " && docker exec apache httpd -v | grep version | cut -d"/" -f2
echo -n "OS (PI):      " && docker exec privacyidea cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2
echo -e "--------------------------------------\n"

echo "--- [VALIDACION DE INFRAESTRUCTURA PRIVACYIDEA-DOCKER] ---"
echo -e "\n[1] Verificando Base de Datos (MySQL)..."
docker exec mysql mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}"
echo -e "\n[2] Verificando API de privacyIDEA (Core)..."
HTTP_CODE=$(docker exec privacyidea curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/)
echo "HTTP $HTTP_CODE"
echo -e "\n[3] Verificando Conexion PrivacyIdea -> MySQL (Listar Admins)..."
docker exec privacyidea pi-manage admin list
echo -e "\n[4] Verificando Conexion FreeRADIUS -> PrivacyIdea..."
docker exec freeradius radtest admin "${PI_ADMIN_PASSWORD}" localhost 0 "${RADIUS_SECRET}"
echo -e "\n[5] Verificando Conexion FreeRADIUS -> OpenLDAP (Puerto 389)..."
docker exec freeradius bash -c "timeout 1 bash -c 'cat < /dev/null > /dev/tcp/openldap/389' && echo OPEN || echo CLOSED"
echo -e "\n[6] Verificando Persistencia en Redis..."
docker exec redis redis-cli -a "${REDIS_PASSWORD}" ping
echo -e "\n[7] Verificando Proxy Apache..."
docker exec apache httpd -v
echo -e "\n--- [FIN DE PRUEBAS] ---"

#End Development By AEntrepreneur [PI-docker 2026]
