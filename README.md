# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Despliegue Docker de privacyIDEA 2FA
# =================================================================

# privacyIDEA-docker

**Despliegue dockerizado de privacyIDEA con MySQL, Redis, Apache, FreeRADIUS y OpenLDAP**

[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-24%2B-2496ED?logo=docker)](https://docker.com)
[![privacyIDEA](https://img.shields.io/badge/privacyIDEA-3.2.2%20%7C%203.7.1%20%7C%203.12.3-green)](https://privacyidea.org)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu)](https://ubuntu.com)

---

## Tabla de Contenidos

- [Descripci\u00f3n General](#descripci\u00f3n-general)
- [Caracter\u00edsticas](#caracter\u00edsticas)
- [Migraci\u00f3n desde On-Premise](#migraci\u00f3n-desde-on-premise)
  - [Flujo de Migraci\u00f3n](#flujo-de-migraci\u00f3n)
  - [Compatibilidad de Versiones](#compatibilidad-de-versiones)
  - [make_backup.sh](#make_backupsh)
  - [restore_backup.sh](#restore_backupsh)
- [Arquitectura del Sistema](#arquitectura-del-sistema)
  - [Diagrama de Conexiones](#diagrama-de-conexiones)
  - [Flujo de Eventos](#flujo-de-eventos)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Inicio R\u00e1pido](#inicio-r\u00e1pido)
- [Servicios](#servicios)
- [Redes y Seguridad](#redes-y-seguridad)
- [Operaciones del D\u00eda a D\u00eda](#operaciones-del-d\u00eda-a-d\u00eda)
- [Variables de Entorno](#variables-de-entorno)
- [Soluci\u00f3n de Problemas](#soluci\u00f3n-de-problemas)
- [Licencia](#licencia)

---

## Descripci\u00f3n General

**privacyIDEA-docker** es un entorno integral para desplegar [privacyIDEA](https://privacyidea.org) en infraestructura Docker. privacyIDEA es un sistema de autenticaci\u00f3n de dos factores (2FA) que soporta tokens OTP, push, SMS, WebAuthn y m\u00e1s.

Este proyecto orquesta todos los servicios necesarios para un despliegue completo en producci\u00f3n:

- **Autenticaci\u00f3n 2FA** mediante tokens OTP, TOTP, HOTP, SMS y push.
- **RADIUS** para integraci\u00f3n con VPNs, firewalls y NAS.
- **LDAP** como fuente de usuarios y directorio corporativo.
- **Proxy HTTPS** con Apache para acceso web seguro.
- **Perfiles de recursos** que se adaptan autom\u00e1ticamente a la capacidad del servidor.

### Versiones Soportadas de privacyIDEA

| Versi\u00f3n | Base | Python | MySQL | Estado |
|-------------|------|--------|-------|--------|
| **3.2.2** | Ubuntu 20.04 | 3.8 | 5.7 | Legacy |
| **3.7.1** | Ubuntu 20.04 | 3.8 | 8.0 | Estable |
| **3.12.3** | Ubuntu 22.04 | 3.10 | 8.0 | Actual |

---

## Caracter\u00edsticas

- **Despliegue automatizado** con un solo comando (`sudo bash bootstrap.sh`)
- **Detecci\u00f3n inteligente de recursos** del servidor y asignaci\u00f3n de perfil (small/medium/large)
- **Credenciales aleatorias** generadas con entrop\u00eda del sistema
- **Certificados TLS autofirmados** para Apache y OpenLDAP generados durante el bootstrap
- **Redes aisladas** con segmentaci\u00f3n interna para hardening
- **Healthchecks** en todos los servicios con reinicio autom\u00e1tico
- **L\u00edmites de recursos** por contenedor (CPU/RAM) seg\u00fan perfil detectado
- **Script de validaci\u00f3n** que verifica el estado completo del stack
- **Persistencia de datos** mediante vol\u00famenes Docker

---

## Migraci\u00f3n desde On-Premise

Este proyecto naci\u00f3 para facilitar la migraci\u00f3n de instancias **on-premise** de privacyIDEA hacia un entorno Docker moderno, aislado y replicable. Los scripts `make_backup.sh` y `restore_backup.sh` est\u00e1n dise\u00f1ados para este flujo de trabajo.

### Flujo de Migraci\u00f3n

```
        SERVIDOR ON-PREMISE                  SERVIDOR DOCKER (NUEVO)
        =====================                ===========================

    +-----------------------------+
    |   privacyIDEA on-premise    |
    |   - MySQL / MariaDB         |
    |   - enckey, RSA keys        |
    |   - GPG home, CA            |
    |   - FreeRADIUS config       |
    |   - pi.cfg personalizado    |
    +-------------+---------------+
                  |
                  | 1. Ejecutar make_backup.sh
                  v
        +-----------------------+
        |  backup-20260515.tgz  |
        |  (SQL + llaves + cfg) |
        +----------+------------+
                   |
                   | 2. Transferir via SCP
                   v
        +-----------------------+
        |  ~/privacyIDEA-docker |
        |  /restore/            |
        +----------+------------+
                   |
                   | 3. bootstrap.sh (aprovisionar Docker)
                   v
        +-----------------------+
        |  Stack Docker listo   |
        |  (sin datos aun)      |
        +----------+------------+
                   |
                   | 4. restore_backup.sh
                   v
        +-----------------------+
        |  Stack Docker listo   |
        |  CON datos migrados   |
        |  - Tokens OTP         |
        |  - Usuarios/admin     |
        |  - Politicas          |
        |  - Llaves cifrado     |
        |  - FreeRADIUS cfg     |
        +-----------------------+
                   |
                   | 5. validate_pi_docker.sh
                   v
        +-----------------------+
        |  Validacion exitosa   |
        |  Todo operativo       |
        +-----------------------+
```

### Que se Migra y Que No

| Se migra | No se migra |
|----------|-------------|
| Tokens OTP, usuarios, pol\u00edticas, eventos | Direcciones IP de NAS/VPN en clients.conf |
| Llaves de cifrado (enckey, RSA, GPG) | Certificados TLS (se regeneran en Docker) |
| Configuraci\u00f3n de FreeRADIUS completa | Resolvers LDAP (requieren reconexi\u00f3n) |
| Base de datos MySQL completa | Configuraciones de red del host |
| Secret key y Pepper de privacyIDEA | Respaldo de im\u00e1genes Docker |
| Archivo pi.cfg personalizado | Archivos temporales y logs |

### Compatibilidad de Versiones

Para una migraci\u00f3n exitosa, la versi\u00f3n de privacyIDEA en el destino Docker debe coincidir o ser superior a la del origen on-premise. El script `restore_backup.sh` restaura el SQL dump directamente sin transformaciones, por lo que la compatibilidad del esquema de base de datos es cr\u00edtica.

| Versi\u00f3n Origen (On-Premise) | MySQL Origen | Imagen Docker Recomendada | MySQL Destino | Compatible |
|-------------------------------|-------------|---------------------------|---------------|------------|
| 2.x - 3.0.x | MySQL 5.x / MariaDB 10.x | `privacyidea_3.2.2` (Legacy) | 5.7 | Si (dump directo) |
| 3.1 - 3.3 | MySQL 5.x / MariaDB 10.x | `privacyidea_3.2.2` (Legacy) | 5.7 | Si (dump directo) |
| 3.3 - 3.7 | MySQL 5.7+ / MariaDB 10.3+ | `privacyidea_3.7.1` (Estable) | 8.0 | Si (dump directo) |
| 3.8 - 3.12 | MySQL 8.0 | `privacyidea_3.12.3` (Actual) | 8.0 | Si (dump directo) |
| 3.12+ | MySQL 8.0 | `privacyidea_3.12.3` (Actual) | 8.0 | Si (dump directo) |

**Notas importantes:**

- Si migras desde MySQL 5.x a 8.0, el dump SQL se importa sin problemas. MySQL 8.0 es compatible con dumps generados en 5.7.
- Las llaves criptogr\u00e1ficas (enckey, private.pem, public.pem) no dependen de la versi\u00f3n de privacyIDEA. Se migran tal cual.
- El GPG home y CA se copian completos. No requieren conversi\u00f3n.
- La configuraci\u00f3n de FreeRADIUS se migra pero debe revisarse: las rutas on-premise (`/etc/freeradius/3.0/`) se adaptan autom\u00e1ticamente al entorno Docker.
- Si tu versi\u00f3n on-premise es anterior a la 3.0, se recomienda actualizar privacyIDEA on-premise primero, o migrar a la imagen Legacy 3.2.2.

### make_backup.sh

Genera un respaldo completo del stack actual (on-premise o Docker) en un archivo `.tgz` listo para transferir.

**Uso:**

```bash
# Respaldo con nombre automatico
sudo bash scripts/make_backup.sh

# Respaldo con ruta especifica
sudo bash scripts/make_backup.sh /ruta/personalizada/backup.tgz
```

**Que incluye el respaldo:**

| Componente | Origen | Destino en el .tgz |
|------------|--------|--------------------|
| SQL dump | MySQL via `docker exec mysql mysqldump` | `var/lib/privacyidea/backup/dbdump-*.sql` |
| Encryption key | Volumen `pi_data` (enckey) | `etc/privacyidea/enckey` |
| RSA key pair | Volumen `pi_data` (private.pem, public.pem) | `etc/privacyidea/` |
| GPG home | Volumen `pi_data` (gpg/) | `etc/privacyidea/gpg/` |
| CA directory | Volumen `pi_data` (CA/) | `etc/privacyidea/CA/` |
| Config PI | `config/privacyidea/pi.cfg` | `etc/privacyidea/pi.cfg` |
| Config Logging | `config/privacyidea/logging.cfg` | `etc/privacyidea/logging.cfg` |
| FreeRADIUS sites | `config/freeradius/sites-enabled/` | `etc/freeradius/3.0/sites-enabled/` |
| FreeRADIUS mods | `config/freeradius/mods-enabled/` | `etc/freeradius/3.0/mods-enabled/` |
| FreeRADIUS mods-config | `config/freeradius/mods-config/` | `etc/freeradius/3.0/mods-config/` |
| FreeRADIUS clients | `config/freeradius/clients.conf` | `etc/freeradius/3.0/clients.conf` |
| FreeRADIUS (contenedor) | mods-available, sites-available, proxy.conf, diccionarios | `etc/freeradius/3.0/` |
| Docker project | docker-compose.yml, bootstrap.sh, config/ | `docker/` |
| rlm_perl.ini | `config/freeradius/rlm_perl.ini` | `etc/privacyidea/rlm_perl.ini` |

**Ejemplo de salida:**

```
--- Iniciando backup privacyIDEA-docker ---
--- Generando dump de base de datos ---
--- Copiando configuracion de privacyIDEA (local) ---
--- Copiando llaves persistentes desde contenedor ---
--- Copiando FreeRADIUS desde proyecto local ---
--- Copiando FreeRADIUS desde contenedor ---
--- Incluyendo configuracion Docker del proyecto ---
--- Ajustando permisos del respaldo ---
--- Empaquetando respaldo en formato on-premise ---
--- Backup completado: /opt/privacyIDEA-docker/restore/pi-docker-backup-20260515_120000.tgz ---
--- Tamanio: 12M ---
```

### restore_backup.sh

Restaura un respaldo (generado por `make_backup.sh` o proveniente de un servidor on-premise) en el stack Docker.

**Uso:**

```bash
# Restaurar el respaldo mas reciente de restore/
sudo bash scripts/restore_backup.sh

# Restaurar un archivo especifico
sudo bash scripts/restore_backup.sh restore/pi-docker-backup-20260515_120000.tgz

# Restaurar desde una ruta externa
sudo bash scripts/restore_backup.sh /tmp/mibackup.tgz
```

**Que restaura y como:**

| Paso | Componente | Accion |
|------|------------|--------|
| 1 | SQL dump | Recrea la base de datos y restaura todos los datos (tokens, usuarios, pol\u00edticas, eventos) |
| 2 | Encryption key (enckey) | Restaura la clave de cifrado sim\u00e9trico en el volumen `pi_data` |
| 3 | RSA keys (private.pem, public.pem) | Restaura el par de llaves RSA para auditor\u00eda |
| 4 | GPG home | Restaura el directorio de llaves GPG completo |
| 5 | CA directory | Restaura la autoridad certificadora si existe en el respaldo |
| 6 | pi.cfg | Extrae SECRET_KEY y PI_PEPPER y los sincroniza con el archivo `.env` del proyecto |
| 7 | FreeRADIUS | Restaura toda la configuraci\u00f3n: sites, mods, clients, diccionarios, pol\u00edticas |
| 8 | Admin password | Sincroniza la contrase\u00f1a del admin de privacyIDEA post-restauraci\u00f3n |

**Toggles de restauración:**

El script incluye variables al inicio para habilitar/deshabilitar componentes espec\u00edficos:

```bash
RESTORE_SQL=true          # Restaurar base de datos
RESTORE_KEYS=true         # Restaurar llaves (enckey, RSA)
RESTORE_GPG=true          # Restaurar GPG home y CA
RESTORE_FREERADIUS=true   # Restaurar configuracion FreeRADIUS
RESTORE_PI_CFG=true       # Restaurar SECRET_KEY y PI_PEPPER
```

**Flujo interno del script:**

```
restore_backup.sh
    |
    +---> Validar .tgz y extraer
    |
    +---> Detener servicios (privacyidea, freeradius)
    |
    +---> [1] SQL DUMP
    |         + DROP DATABASE
    |         + CREATE DATABASE
    |         + Importar dump SQL
    |
    +---> [2] LLAVES (enckey, private.pem, public.pem)
    |         + Copiar a volumen pi_data
    |         + Ajustar permisos (chmod 400)
    |
    +---> [3] GPG / CA
    |         + Copiar directorios completos
    |
    +---> [4] PI.CFG (SECRET_KEY / PI_PEPPER)
    |         + Extraer valores y sincronizar .env
    |
    +---> [5] FREERADIUS
    |         + Restaurar sites, mods, clients, diccionarios
    |         + Desenlazar symlinks (Docker bind mount requiere archivos regulares)
    |         + Unificar RADIUS_SECRET con valor on-premise
    |         + Corregir URL en rlm_perl.ini (localhost -> contenedor Docker)
    |
    +---> Levantar servicios + validar MySQL
    |
    +---> [6] ADMIN: Sincronizar password de administrador
    |
    +---> Limpiar temporales
    |
    +---> Mostrar accesos post-restauracion
```

**Ejemplo de salida:**

```
--- Deteniendo servicios ---
--- Descomprimiendo respaldo restore/pi-docker-backup-20260515.tgz ---
--- [1] SQL DUMP - Iniciando restauracion ---
--- Recreando base de datos privacyidea ---
--- Importando dump SQL: dbdump-20260515-120000.sql ---
--- [1] SQL DUMP - Completado ---
--- [2] LLAVES - Iniciando restauracion ---
--- Restaurando llaves a volumen pi_data ---
--- [2] LLAVES - Completado ---
--- [3] GPG/CA - Buscando en respaldo ---
--- Restaurando directorio GPG ---
--- [3] GPG/CA - Completado ---
--- [4] PI.CFG - Buscando identidad en respaldo ---
--- Actualizando PI_SECRET_KEY en .env ---
--- [4] PI.CFG - Completado ---
--- [5] FREERADIUS - Buscando en respaldo ---
--- RADIUS_SECRET unificado con valor on-premise ---
--- [5] FREERADIUS - Completado ---
--- Levantando privacyIDEA ---
--- Verificando Base de Datos... ---
--- [6] ADMIN - Sincronizando contrasena de administrador ---
--- Admin admin creado correctamente ---
--- Reiniciando FreeRADIUS ---
--- Restauracion Completada ---
```

**Notas importantes:**

- El script **no modifica** los resolvers LDAP del backup. Si usabas un resolver LDAP on-premise, deber\u00e1s reconectarlo manualmente desde la UI de privacyIDEA apuntando al nuevo servidor LDAP o al mismo si sigue disponible.
- Los clientes RADIUS en `clients.conf` se migran tal cual. Verificar que las IPs de los NAS/VPN sigan siendo v\u00e1lidas.
- La contrase\u00f1a del admin de privacyIDEA se fuerza al valor de `PI_ADMIN_PASSWORD` del `.env` actual. Los dem\u00e1s usuarios administradores del backup conservan sus contrase\u00f1as originales.
- Si hay **m\u00faltiples** archivos `pi-docker-backup-*.tgz` en `restore/`, el script pedir\u00e1 que especifiques cu\u00e1l restaurar.

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
                      | (datos)        | (cach\u00e9)
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

#### Flujo de Autenticaci\u00f3n Web (HTTPS)

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
                                   pol\u00edticas)     cach\u00e9)
                                            |
                                     Respuesta JSON
                                            |
                                    Apache -> Navegador
                                    (200 OK / 401 / Redirect)
```

**Secuencia detallada:**

1. El usuario accede a `https://<servidor>` desde su navegador.
2. Apache recibe la conexi\u00f3n en el puerto 443 con TLS.
3. Apache hace proxy inverso a `http://privacyidea:8000`.
4. privacyIDEA procesa la solicitud:
   - Lee usuarios desde la base MySQL.
   - Verifica tokens y pol\u00edticas en MySQL.
   - Usa Redis para cach\u00e9 de sesiones y colas ligeras.
5. privacyIDEA devuelve la respuesta a Apache.
6. Apache entrega la respuesta al navegador del usuario.

#### Flujo de Autenticaci\u00f3n RADIUS

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
    |                 (validaci\u00f3n        (rate-limiting,
    |                  de token)          cach\u00e9)
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

1. Un NAS (VPN, firewall, switch, AP WiFi) env\u00eda un paquete `Access-Request` UDP al puerto 1812 de FreeRADIUS.
2. FreeRADIUS recibe la petici\u00f3n y delega la validaci\u00f3n al m\u00f3dulo Perl (`rlm_perl`).
3. El plugin Perl construye una petici\u00f3n HTTP hacia `http://privacyidea:8000/validate/check`.
4. privacyIDEA eval\u00faa el token contra MySQL (persistencia) y Redis (cach\u00e9/rate-limit).
5. privacyIDEA responde con `accept`, `reject` o `challenge` en formato JSON.
6. FreeRADIUS traduce la respuesta a un paquete RADIUS est\u00e1ndar.
7. El NAS recibe la respuesta y act\u00faa en consecuencia (concede acceso, deniega, o solicita segundo factor).

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
    +---> Bloque 3: Configuraci\u00f3n interactiva
    |         + Elegir versi\u00f3n de privacyIDEA
    |         + Generar credenciales aleatorias
    |         + Escribir archivo .env
    |
    +---> Bloque 4: Despliegue y validaci\u00f3n
              + Generar certificados TLS
              + Preparar configuraci\u00f3n OpenLDAP
              + Construir im\u00e1genes Docker
              + Levantar stack completo
              + Mostrar credenciales y validaci\u00f3n final
```

---

## Requisitos del Sistema

| Recurso | M\u00ednimo | Recomendado |
|---------|-----------|-------------|
| **Sistema Operativo** | Ubuntu 20.04 | Ubuntu 22.04 / 24.04 |
| **RAM total** | 4 GB | 8+ GB |
| **CPU** | 2 n\u00facleos | 4+ n\u00facleos |
| **Disco** | 20 GB libres | 50+ GB SSD |
| **Docker Engine** | 24.0+ | \u00daltima estable |
| **Docker Compose** | v2 (plugin) | v2 (plugin) |
| **Puertos requeridos** | 443, 3306, 6379, 8000, 389/636, 1812-1813/UDP | Abiertos en firewall |

### Perfiles de Recursos

El bootstrap detecta la RAM del servidor y asigna un perfil autom\u00e1ticamente:

| Perfil | RAM L\u00edmite | Workers (t\u00edpico) | Swap | RAM total del stack |
|--------|---------------|----------------------|------|---------------------|
| **small** | <= 4 GB | 5 | 4 GB | ~3.9 GB |
| **medium** | <= 8 GB | 7 | 4 GB | ~5.6 GB |
| **large** | > 8 GB | 9 | 8 GB | ~9.2 GB |

Los workers de Gunicorn se calculan con la f\u00f3rmula `(2 x min(n\u00facleos, 4) + 1)`.

---

## Inicio R\u00e1pido

### 1. Aprovisionar el Servidor

```bash
sudo bash bootstrap.sh
```

### 2. Elegir Versi\u00f3n de privacyIDEA

Durante el bootstrap se te pedir\u00e1 elegir la versi\u00f3n:

```
1) v3.2.2  (Legacy - Ubuntu 20.04, Python 3.8, MySQL 5.7)
2) v3.7.1  (Estable - Ubuntu 20.04, Python 3.8, MySQL 8.0)
3) v3.12.3 (Actual  - Ubuntu 22.04, Python 3.10, MySQL 8.0)
```

### 3. Guardar las Credenciales

Al finalizar, el bootstrap muestra las credenciales generadas. **Gu\u00e1rdalas en un lugar seguro**.

### 4. Acceder a la Web UI

```
URL:    https://<IP-del-servidor>
Usuario: admin
Clave:  (la generada por el bootstrap)
```

### 5. Configurar FreeRADIUS para Producci\u00f3n

Editar `config/freeradius/clients.conf` con las IPs reales de los dispositivos NAS/VPN:

```bash
nano config/freeradius/clients.conf
# Agregar los clientes RADIUS con sus IPs y secretos
sudo docker compose restart freeradius
```

---

## Servicios

### Detalle de Servicios

| Servicio | Puerto | Imagen Base | Funci\u00f3n Principal | Persistencia |
|----------|--------|-------------|----------------------|--------------|
| **mysql** | 3306 | mysql:5.7/8.0 | Base de datos de privacyIDEA | Volumen `mysql_data` |
| **privacyidea** | 8000 | Ubuntu + Python | API REST, admin UI, validaci\u00f3n OTP | Volumen `pi_data` + `pi_custom` |
| **redis** | 6379 | redis:7-alpine | Cach\u00e9, sesiones y colas | Directorio `config/redis/data` |
| **openldap** | 389/636 | Ubuntu 20.04 | Directorio LDAP y resoluci\u00f3n de usuarios | Directorio `config/openldap/data` |
| **apache** | 443 | httpd:latest | Proxy HTTPS hacia privacyIDEA | Certificados en `config/apache/certs` |
| **freeradius** | 1812-1813/UDP | Ubuntu 20.04 | Autenticaci\u00f3n RADIUS v\u00eda plugin Perl | Configuraci\u00f3n en `config/freeradius` |

### Puertos Expuestos

| Puerto | Protocolo | Servicio | Uso |
|--------|-----------|----------|-----|
| 443 | TCP | Apache | Web UI HTTPS |
| 3306 | TCP | MySQL | Base de datos (solo red interna) |
| 6379 | TCP | Redis | Cach\u00e9 (solo red interna) |
| 8000 | TCP | privacyIDEA | API REST (solo red interna) |
| 389 | TCP | OpenLDAP | LDAP sin TLS |
| 636 | TCP | OpenLDAP | LDAP con TLS |
| 1812 | UDP | FreeRADIUS | Autenticaci\u00f3n RADIUS |
| 1813 | UDP | FreeRADIUS | Contabilidad RADIUS |

---

## Redes y Seguridad

### Topolog\u00eda de Redes

```
+---------------------------------------------------+
|                   docker_net (bridge)              |
|   Expuesta al host para recibir tr\u00e1fico          |
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
|   | privacyIDEA |   (tambi\u00e9n en internal_net)     |
|   | :8000      |   (habla con MySQL, Redis)         |
|   +-----------+                                    |
|                                                     |
|   +------------+                                   |
|   | FreeRADIUS  |   (tambi\u00e9n en internal_net)     |
|   | :1812/UDP  |   (habla con privacyIDEA)         |
|   +------------+                                   |
+---------------------------------------------------+
```

### Medidas de Seguridad

- **Red internal_net** con `internal: true`: los contenedores en esta red no tienen acceso al exterior ni al host. MySQL, Redis y OpenLDAP solo son accesibles desde privacyIDEA y FreeRADIUS.
- **Red docker_net** (bridge): Apache, privacyIDEA y FreeRADIUS est\u00e1n expuestos al host para recibir tr\u00e1fico entrante.
- **`no-new-privileges:true`** en todos los servicios.
- **Recursos limitados** por contenedor (CPU y RAM).
- **Healthchecks** en todos los servicios con reinicio autom\u00e1tico (`restart: unless-stopped`).
- **Credenciales aleatorias** generadas con entrop\u00eda del sistema.
- **Certificados TLS autofirmados** generados durante el bootstrap.
- **`.env` excluido de Git** (listado en `.gitignore`).

---

## Operaciones del D\u00eda a D\u00eda

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

### Validaci\u00f3n del Stack

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

# FreeRADIUS (verificar m\u00f3dulo Perl cargado)
docker exec -it freeradius freeradius -X 2>&1 | grep -i perl

# OpenLDAP
docker exec -it openldap ldapwhoami -x -H ldap://localhost
```

### Respaldo del Stack

```bash
sudo bash scripts/make_backup.sh
```

Genera un backup completo en `restore/pi-docker-backup-YYYYMMDD_HHMMSS.tgz` que incluye SQL dump, llaves criptogr\u00e1ficas, GPG/CA y configuraci\u00f3n de FreeRADIUS.

### Restauraci\u00f3n de Backup

```bash
sudo bash scripts/restore_backup.sh restore/pi-docker-backup-20260515.tgz
```

Restaura un backup previo o migra datos desde un servidor on-premise. Recrea la base de datos, restaura llaves, GPG y FreeRADIUS, y sincroniza credenciales.

### Detecci\u00f3n de Recursos

```bash
sudo bash scripts/detect_resources.sh
```

Muestra el perfil detectado, recursos por servicio y validaci\u00f3n de capacidad del servidor.

### Regenerar OpenLDAP

```bash
sudo rm -rf config/openldap/data/*
sudo rm -rf config/openldap/config/*
sudo bash bootstrap.sh
```

---

## Variables de Entorno

El archivo `.env` se genera autom\u00e1ticamente durante el bootstrap con todas las credenciales y configuraciones.

### Variables Generadas

| Variable | Descripci\u00f3n |
|----------|----------------|
| `PI_VERSION` | Versi\u00f3n de privacyIDEA |
| `MYSQL_VERSION` | Versi\u00f3n de MySQL |
| `MYSQL_ROOT_PASSWORD` | Clave root de MySQL |
| `MYSQL_USER` | Usuario de aplicaci\u00f3n |
| `MYSQL_PASSWORD` | Clave del usuario de aplicaci\u00f3n |
| `MYSQL_DATABASE` | Nombre de la base de datos |
| `PI_ADMIN_USER` | Usuario admin de privacyIDEA |
| `PI_ADMIN_PASSWORD` | Clave del admin |
| `PI_SECRET_KEY` | Secret key de Flask |
| `PI_PEPPER` | Pepper de privacyIDEA |
| `REDIS_PASSWORD` | Clave de Redis |
| `LDAP_ADMIN_PASSWORD` | Clave admin de LDAP |
| `LDAP_CONFIG_PASSWORD` | Clave de configuraci\u00f3n LDAP |
| `RADIUS_SECRET` | Secreto compartido de FreeRADIUS |
| `PROFILE_NAME` | Perfil detectado (small/medium/large) |
| `GUNICORN_WORKERS` | Workers de Gunicorn |
| Variables de recursos | L\u00edmites de CPU/RAM por servicio |

**Importante:** El archivo `.env` contiene todas las credenciales del sistema. No lo compartas ni lo subas a Git.

---

## Soluci\u00f3n de Problemas

### Error: "docker: command not found"

El bootstrap instala Docker autom\u00e1ticamente, pero si falla:

```bash
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
# Cerrar sesi\u00f3n y volver a entrar
```

### Error: Puerto en uso

```bash
sudo lsof -i :443
# Detener el proceso que ocupa el puerto o cambiar HTTPS_PORT en .env
```

### El contenedor no arranca

```bash
sudo docker compose logs <servicio>   # Ver el error espec\u00edfico
sudo docker compose down              # Limpiar
sudo docker compose up -d             # Reintentar
```

### La Web UI no responde

```bash
# Verificar que privacyIDEA est\u00e1 vivo
curl -k https://localhost:443
# Ver logs de Apache y privacyIDEA
sudo docker compose logs apache
sudo docker compose logs privacyidea
```

### Error de conexi\u00f3n MySQL

```bash
# Verificar que MySQL est\u00e1 saludable
sudo docker compose logs mysql
docker exec -it mysql mysqladmin ping -u root -p"${MYSQL_ROOT_PASSWORD}"
```

---

## Estructura del Proyecto

```
./
├── bootstrap.sh                    # Aprovisionamiento completo
├── docker-compose.yml              # Orquestaci\u00f3n de servicios
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
│   ├── privacyidea/                # N\u00facleo 2FA
│   │   ├── privacyidea_*.dockerfile
│   │   ├── pi.cfg
│   │   ├── logging.cfg
│   │   └── pi_entrypoint.sh
│   └── redis/                      # Cach\u00e9
│       └── redis.dockerfile
└── scripts/
    ├── detect_resources.sh         # Detecci\u00f3n de perfil del servidor
    ├── make_backup.sh              # Backup completo del stack
    ├── offline_resources.sh        # Generaci\u00f3n de paquetes offline
    ├── restore_backup.sh           # Restauraci\u00f3n de backup / migraci\u00f3n on-premise
    └── validate_pi_docker.sh       # Validaci\u00f3n post-despliegue
```

---

## Licencia

Este proyecto se distribuye bajo licencia **GNU General Public License v3.0**.

privacyIDEA es software libre bajo licencia AGPLv3.

---

## Acerca de

Creado y mantenido por **AEntrepreneur**.

Si este proyecto te resulta \u00fatil, considera darle una estrella en GitHub.

#End Development By AEntrepreneur [PI-docker 2026]
