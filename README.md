# [2026] - Despliegue Docker de privacyIDEA-docker
**Despliegue dockerizado de privacyIDEA con MySQL, Redis, Apache, FreeRADIUS y OpenLDAP**

[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-24%2B-2496ED?logo=docker)](https://docker.com)
[![privacyIDEA](https://img.shields.io/badge/privacyIDEA-3.2.2%20%7C%203.7.1%20%7C%203.12.3-green)](https://privacyidea.org)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu)](https://ubuntu.com)

---

## Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Características](#características)
- [Arquitectura del Sistema](#arquitectura-del-sistema)
  - [Diagrama de Conexiones](#diagrama-de-conexiones)
  - [Flujo de Eventos](#flujo-de-eventos)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Inicio Rápido](#inicio-rápido)
- [Servicios](#servicios)
- [Redes y Seguridad](#redes-y-seguridad)
- [Operaciones del Día a Día](#operaciones-del-día-a-día)
- [Variables de Entorno](#variables-de-entorno)
- [Solución de Problemas](#solución-de-problemas)
- [Licencia](#licencia)

---

## Descripción General

**privacyIDEA-docker** es un entorno integral para desplegar [privacyIDEA](https://privacyidea.org) en infraestructura Docker. privacyIDEA es un sistema de autenticación de dos factores (2FA) que soporta tokens OTP, push, SMS, WebAuthn y más.

Este proyecto orquesta todos los servicios necesarios para un despliegue completo en producción:

- **Autenticación 2FA** mediante tokens OTP, TOTP, HOTP, SMS y push.
- **RADIUS** para integración con VPNs, firewalls y NAS.
- **LDAP** como fuente de usuarios y directorio corporativo.
- **Proxy HTTPS** con Apache para acceso web seguro.
- **Perfiles de recursos** que se adaptan automáticamente a la capacidad del servidor.

### Versiones Soportadas de privacyIDEA

| Versión | Base | Python | MySQL | Estado |
|-------------|------|--------|-------|--------|
| **3.2.2** | Ubuntu 20.04 | 3.8 | 5.7 | Legacy |
| **3.7.1** | Ubuntu 20.04 | 3.8 | 8.0 | Estable |
| **3.12.3** | Ubuntu 22.04 | 3.10 | 8.0 | Actual |

---

## Características

- **Despliegue automatizado** con un solo comando (`sudo bash bootstrap.sh`)
- **Detección inteligente de recursos** del servidor y asignación de perfil (small/medium/large)
- **Credenciales aleatorias** generadas con entropía del sistema
- **Certificados TLS autofirmados** para Apache y OpenLDAP generados durante el bootstrap
- **Redes aisladas** con segmentación interna para hardening
- **Healthchecks** en todos los servicios con reinicio automático
- **Límites de recursos** por contenedor (CPU/RAM) según perfil detectado
- **Script de validación** que verifica el estado completo del stack
- **Persistencia de datos** mediante volúmenes Docker

---

## Arquitectura del Sistema

### Diagrama de Conexiones

```
                        INTERNET / RED CORPORATIVA
                               |
                     +---------+---------+
                     |                   |
                     |   PUERTO 443      |   PUERTO 1812/1813 UDP
                     |   (HTTPS)         |   (RADIUS)
                     |                   |
              +------v------+     +------v-------+
              |   APACHE    |     |  FreeRADIUS  |
              |  (:443)     |     |  (:1812)     |
              +------+------+     +------+-------+
                     |                   |
                     |  proxy_pass       |  rlm_perl plugin
                     |  http://pi:8000   |  http://pi:8000/validate/check
                     |                   |
              +------v-------------------v-------+
              |          privacyIDEA             |
              |         (:8000 - API REST)       |
              +-------+----------------+--------+
                      |                |
                      | MySQL          | Redis
                      | (datos)        | (caché)
              +-------v---+    +------v------+
              |   MySQL   |    |    Redis    |
              |  (:3306)  |    |   (:6379)   |
              +-----------+    +-------------+

              +-------------------+
              |    OpenLDAP       |
              |   (:389 / :636)   |
              +-------------------+
```

### Flujo de Eventos

#### Flujo de Autenticación Web (HTTPS)

```
Usuario -> Navegador
    |
    v
Apache (:443)  ->  Proxy inverso  ->  privacyidea (:8000)
                                            |
                                     +------+-------+
                                     |              |
                                  MySQL (:3306)  Redis (:6379)
                                  (tokens,       (sesiones,
                                   usuarios,      colas,
                                   políticas)     caché)
                                            |
                                     Respuesta JSON
                                            |
                                    Apache -> Navegador
                                    (200 OK / 401 / Redirect)
```

**Secuencia detallada:**

1. El usuario accede a `https://<servidor>` desde su navegador.
2. Apache recibe la conexión en el puerto 443 con TLS.
3. Apache hace proxy inverso a `http://privacyidea:8000`.
4. privacyIDEA procesa la solicitud:
   - Lee usuarios desde la base MySQL.
   - Verifica tokens y políticas en MySQL.
   - Usa Redis para caché de sesiones y colas ligeras.
5. privacyIDEA devuelve la respuesta a Apache.
6. Apache entrega la respuesta al navegador del usuario.

#### Flujo de Autenticación RADIUS

```
NAS/VPN/Firewall  ->  Access-Request (UDP :1812)
    |
    v
FreeRADIUS  ->  rlm_perl.so  ->  HTTP GET/POST
    |                              |
    |                   privacyidea (:8000)
    |                   /validate/check
    |                              |
    |                    +---------+---------+
    |                    |                   |
    |                 MySQL (:3306)      Redis (:6379)
    |                 (validación        (rate-limiting,
    |                  de token)          caché)
    |                    |                   |
    |                    +---------+---------+
    |                              |
    |                   privacyidea responde
    |                   JSON: accept/reject/challenge
    |
    v
Access-Accept / Access-Reject / Access-Challenge (UDP :1812 / :1813)
    |
    v
NAS/VPN/Firewall  ->  Concede o deniega acceso
```

**Secuencia detallada:**

1. Un NAS (VPN, firewall, switch, AP WiFi) envía un paquete `Access-Request` UDP al puerto 1812 de FreeRADIUS.
2. FreeRADIUS recibe la petición y delega la validación al módulo Perl (`rlm_perl`).
3. El plugin Perl construye una petición HTTP hacia `http://privacyidea:8000/validate/check`.
4. privacyIDEA evalúa el token contra MySQL (persistencia) y Redis (caché/rate-limit).
5. privacyIDEA responde con `accept`, `reject` o `challenge` en formato JSON.
6. FreeRADIUS traduce la respuesta a un paquete RADIUS estándar.
7. El NAS recibe la respuesta y actúa en consecuencia (concede acceso, deniega, o solicita segundo factor).

#### Flujo de Aprovisionamiento (Bootstrap)

```
bootstrap.sh
    |
    +---> Bloque 1: Instalar Docker Engine (si no existe)
    |         + Limpiar contenedores previos
    |         + Normalizar archivos y permisos
    |
    +---> Bloque 2: Detectar recursos del host
    |         + CPU, RAM, disco
    |         + Asignar perfil (small/medium/large)
    |         + Configurar swap y swappiness
    |
    +---> Bloque 3: Configuración interactiva
    |         + Elegir versión de privacyIDEA
    |         + Generar credenciales aleatorias
    |         + Escribir archivo .env
    |
    +---> Bloque 4: Despliegue y validación
              + Generar certificados TLS
              + Preparar configuración OpenLDAP
              + Construir imágenes Docker
              + Levantar stack completo
              + Mostrar credenciales y validación final
```

---

## Requisitos del Sistema

| Recurso | Mínimo | Recomendado |
|---------|-----------|-------------|
| **Sistema Operativo** | Ubuntu 20.04 | Ubuntu 22.04 / 24.04 |
| **RAM total** | 4 GB | 8+ GB |
| **CPU** | 2 núcleos | 4+ núcleos |
| **Disco** | 20 GB libres | 50+ GB SSD |
| **Docker Engine** | 24.0+ | Última estable |
| **Docker Compose** | v2 (plugin) | v2 (plugin) |
| **Puertos requeridos** | 443, 3306, 6379, 8000, 389/636, 1812-1813/UDP | Abiertos en firewall |

### Perfiles de Recursos

El bootstrap detecta la RAM del servidor y asigna un perfil automáticamente:

| Perfil | RAM Límite | Workers (típico) | Swap | RAM total del stack |
|--------|---------------|----------------------|------|---------------------|
| **small** | <= 4 GB | 5 | 4 GB | ~3.9 GB |
| **medium** | <= 8 GB | 7 | 4 GB | ~5.6 GB |
| **large** | > 8 GB | 9 | 8 GB | ~9.2 GB |

Los workers de Gunicorn se calculan con la fórmula `(2 x min(núcleos, 4) + 1)`.

---

## Inicio Rápido

### 1. Aprovisionar el Servidor

```bash
sudo bash bootstrap.sh
```

### 2. Elegir Versión de privacyIDEA

Durante el bootstrap se te pedirá elegir la versión:

```
1) v3.2.2  (Legacy - Ubuntu 20.04, Python 3.8, MySQL 5.7)
2) v3.7.1  (Estable - Ubuntu 20.04, Python 3.8, MySQL 8.0)
3) v3.12.3 (Actual  - Ubuntu 22.04, Python 3.10, MySQL 8.0)
```

### 3. Guardar las Credenciales

Al finalizar, el bootstrap muestra las credenciales generadas. **Guárdalas en un lugar seguro**.

### 4. Acceder a la Web UI

```
URL:    https://<IP-del-servidor>
Usuario: admin
Clave:  (la generada por el bootstrap)
```

### 5. Configurar FreeRADIUS para Producción

Editar `config/freeradius/clients.conf` con las IPs reales de los dispositivos NAS/VPN:

```bash
nano config/freeradius/clients.conf
# Agregar los clientes RADIUS con sus IPs y secretos
sudo docker compose restart freeradius
```

---

## Servicios

### Detalle de Servicios

| Servicio | Puerto | Imagen Base | Función Principal | Persistencia |
|----------|--------|-------------|----------------------|--------------|
| **mysql** | 3306 | mysql:5.7/8.0 | Base de datos de privacyIDEA | Volumen `mysql_data` |
| **privacyidea** | 8000 | Ubuntu + Python | API REST, admin UI, validación OTP | Volumen `pi_data` + `pi_custom` |
| **redis** | 6379 | redis:7-alpine | Caché, sesiones y colas | Directorio `config/redis/data` |
| **openldap** | 389/636 | Ubuntu 20.04 | Directorio LDAP y resolución de usuarios | Directorio `config/openldap/data` |
| **apache** | 443 | httpd:latest | Proxy HTTPS hacia privacyIDEA | Certificados en `config/apache/certs` |
| **freeradius** | 1812-1813/UDP | Ubuntu 20.04 | Autenticación RADIUS vía plugin Perl | Configuración en `config/freeradius` |

### Puertos Expuestos

| Puerto | Protocolo | Servicio | Uso |
|--------|-----------|----------|-----|
| 443 | TCP | Apache | Web UI HTTPS |
| 3306 | TCP | MySQL | Base de datos (solo red interna) |
| 6379 | TCP | Redis | Caché (solo red interna) |
| 8000 | TCP | privacyIDEA | API REST (solo red interna) |
| 389 | TCP | OpenLDAP | LDAP sin TLS |
| 636 | TCP | OpenLDAP | LDAP con TLS |
| 1812 | UDP | FreeRADIUS | Autenticación RADIUS |
| 1813 | UDP | FreeRADIUS | Contabilidad RADIUS |

---

## Redes y Seguridad

### Topología de Redes

```
+---------------------------------------------------+
|                   docker_net (bridge)              |
|   Expuesta al host para recibir tráfico          |
|                                                     |
|   +--------+    +-----------+    +------------+    |
|   | Apache |    | privacyIDEA |   | FreeRADIUS  |   |
|   | :443   |    | :8000      |   | :1812/UDP   |   |
|   +--------+    +-----------+    +------------+    |
+---------------------------------------------------+
                        |
                        | (conectados a ambas redes)
                        |
+---------------------------------------------------+
|               internal_net (internal: true)        |
|   Aislada del host y del exterior                  |
|                                                     |
|   +--------+    +-----------+    +------------+    |
|   | MySQL  |    |   Redis   |    | OpenLDAP   |    |
|   | :3306  |    |  :6379    |    | :389/636   |    |
|   +--------+    +-----------+    +------------+    |
|                                                     |
|   +-----------+                                    |
|   | privacyIDEA |   (también en internal_net)     |
|   | :8000      |   (habla con MySQL, Redis)         |
|   +-----------+                                    |
|                                                     |
|   +------------+                                   |
|   | FreeRADIUS  |   (también en internal_net)     |
|   | :1812/UDP  |   (habla con privacyIDEA)         |
|   +------------+                                   |
+---------------------------------------------------+
```

### Medidas de Seguridad

- **Red internal_net** con `internal: true`: los contenedores en esta red no tienen acceso al exterior ni al host. MySQL, Redis y OpenLDAP solo son accesibles desde privacyIDEA y FreeRADIUS.
- **Red docker_net** (bridge): Apache, privacyIDEA y FreeRADIUS están expuestos al host para recibir tráfico entrante.
- **`no-new-privileges:true`** en todos los servicios.
- **Recursos limitados** por contenedor (CPU y RAM).
- **Healthchecks** en todos los servicios con reinicio automático (`restart: unless-stopped`).
- **Credenciales aleatorias** generadas con entropía del sistema.
- **Certificados TLS autofirmados** generados durante el bootstrap.
- **`.env` excluido de Git** (listado en `.gitignore`).

---

## Operaciones del Día a Día

### Estado de Servicios

```bash
sudo docker compose ps                                    # Estado de todos los servicios
sudo docker stats --no-stream                              # Uso real de CPU/RAM
sudo docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'
```

### Registros (Logs)

```bash
sudo docker compose logs -f privacyidea    # Logs de privacyIDEA en tiempo real
sudo docker compose logs -f mysql           # Logs de MySQL
sudo docker compose logs -f apache          # Logs de Apache
sudo docker compose logs -f freeradius      # Logs de FreeRADIUS
sudo docker compose logs -f openldap        # Logs de OpenLDAP
sudo docker compose logs -f redis           # Logs de Redis
```

### Validación del Stack

```bash
sudo bash scripts/validate_pi_docker.sh
```

Este script ejecuta 7 pruebas automatizadas: versiones, MySQL ping, API de privacyIDEA, administradores, RADIUS, Redis y Apache.

### Verificaciones Individuales

```bash
# MySQL
docker exec -it mysql mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}"

# Redis
docker exec -it redis redis-cli -a "${REDIS_PASSWORD}" ping

# API de privacyIDEA
docker exec -it privacyidea curl -s http://localhost:8000

# Web UI
curl -k https://localhost:443

# FreeRADIUS (verificar módulo Perl cargado)
docker exec -it freeradius freeradius -X 2>&1 | grep -i perl

# OpenLDAP
docker exec -it openldap ldapwhoami -x -H ldap://localhost
```

### Respaldo del Stack

```bash
sudo bash scripts/make_backup.sh
```

Genera un backup completo en `restore/pi-docker-backup-YYYYMMDD_HHMMSS.tgz` que incluye SQL dump, llaves criptográficas, GPG/CA y configuración de FreeRADIUS.

### Restauración de Backup

```bash
sudo bash scripts/restore_backup.sh restore/pi-docker-backup-20260515.tgz
```

Restaura un backup previo o migra datos desde un servidor on-premise. Recrea la base de datos, restaura llaves, GPG y FreeRADIUS, y sincroniza credenciales.

### Detección de Recursos

```bash
sudo bash scripts/detect_resources.sh
```

Muestra el perfil detectado, recursos por servicio y validación de capacidad del servidor.

### Regenerar OpenLDAP

```bash
sudo rm -rf config/openldap/data/*
sudo rm -rf config/openldap/config/*
sudo bash bootstrap.sh
```

---

## Variables de Entorno

El archivo `.env` se genera automáticamente durante el bootstrap con todas las credenciales y configuraciones.

### Variables Generadas

| Variable | Descripción |
|----------|----------------|
| `PI_VERSION` | Versión de privacyIDEA |
| `MYSQL_VERSION` | Versión de MySQL |
| `MYSQL_ROOT_PASSWORD` | Clave root de MySQL |
| `MYSQL_USER` | Usuario de aplicación |
| `MYSQL_PASSWORD` | Clave del usuario de aplicación |
| `MYSQL_DATABASE` | Nombre de la base de datos |
| `PI_ADMIN_USER` | Usuario admin de privacyIDEA |
| `PI_ADMIN_PASSWORD` | Clave del admin |
| `PI_SECRET_KEY` | Secret key de Flask |
| `PI_PEPPER` | Pepper de privacyIDEA |
| `REDIS_PASSWORD` | Clave de Redis |
| `LDAP_ADMIN_PASSWORD` | Clave admin de LDAP |
| `LDAP_CONFIG_PASSWORD` | Clave de configuración LDAP |
| `RADIUS_SECRET` | Secreto compartido de FreeRADIUS |
| `PROFILE_NAME` | Perfil detectado (small/medium/large) |
| `GUNICORN_WORKERS` | Workers de Gunicorn |
| Variables de recursos | Límites de CPU/RAM por servicio |

**Importante:** El archivo `.env` contiene todas las credenciales del sistema. No lo compartas ni lo subas a Git.

---

## Solución de Problemas

### Error: "docker: command not found"

El bootstrap instala Docker automáticamente, pero si falla:

```bash
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar
```

### Error: Puerto en uso

```bash
sudo lsof -i :443
# Detener el proceso que ocupa el puerto o cambiar HTTPS_PORT en .env
```

### El contenedor no arranca

```bash
sudo docker compose logs <servicio>   # Ver el error específico
sudo docker compose down              # Limpiar
sudo docker compose up -d             # Reintentar
```

### La Web UI no responde

```bash
# Verificar que privacyIDEA está vivo
curl -k https://localhost:443
# Ver logs de Apache y privacyIDEA
sudo docker compose logs apache
sudo docker compose logs privacyidea
```

### Error de conexión MySQL

```bash
# Verificar que MySQL está saludable
sudo docker compose logs mysql
docker exec -it mysql mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}"
```

---

## Estructura del Proyecto

```
./
├── bootstrap.sh                    # Aprovisionamiento completo
├── docker-compose.yml              # Orquestación de servicios
├── restore/                        # Backup files (.tgz) y temporales
├── config/
│   ├── apache/                     # Proxy HTTPS
│   │   ├── apache.dockerfile
│   │   ├── httpd.conf
│   │   └── httpd-ssl.conf
│   ├── freeradius/                 # Servidor RADIUS
│   │   ├── freeradius.dockerfile
│   │   ├── clients.conf
│   │   ├── rlm_perl.ini
│   │   └── mods-config/perl/
│   ├── mysql/                      # Base de datos
│   │   ├── mysql_5.7.dockerfile
│   │   └── mysql_8.0.dockerfile
│   ├── openldap/                   # Directorio LDAP
│   │   ├── openldap.dockerfile
│   │   ├── config/slapd.conf
│   │   └── custom/01-base.ldif
│   ├── privacyidea/                # Núcleo 2FA
│   │   ├── privacyidea_*.dockerfile
│   │   ├── pi.cfg
│   │   ├── logging.cfg
│   │   └── pi_entrypoint.sh
│   └── redis/                      # Caché
│       └── redis.dockerfile
└── scripts/
    ├── detect_resources.sh         # Detección de perfil del servidor
    ├── make_backup.sh              # Backup completo del stack
    ├── offline_resources.sh        # Generación de paquetes offline
    ├── restore_backup.sh           # Restauración de backup / migración on-premise
    └── validate_pi_docker.sh       # Validación post-despliegue
```

---

## Licencia

Este proyecto se distribuye bajo licencia **GNU General Public License v3.0**.

privacyIDEA es software libre bajo licencia AGPLv3.

---

## Acerca de

Creado y mantenido por **AEntrepreneur**.

Si este proyecto te resulta útil, considera darle una estrella en GitHub.

#End Development By AEntrepreneur [PI-docker 2026]
