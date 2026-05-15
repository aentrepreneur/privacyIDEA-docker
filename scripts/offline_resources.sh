#!/bin/bash
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Genera Paquetes Offline para Instalacion Sin Internet
# =================================================================
# Uso: sudo bash scripts/offline_resources.sh
# =================================================================
# Descarga paquetes .deb (Docker + System) y exporta imagenes dg/*
# Genera guia en restore/offline_bundle/ para servidor offline
# =================================================================

set -e

# Auto-deteccion de rutas
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
ARCHIVE_DIR="$PROJECT_DIR/restore"
[ -d "$ARCHIVE_DIR" ] || mkdir -p "$ARCHIVE_DIR"

OUTDIR="$ARCHIVE_DIR/offline_bundle"
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

TEMPDIR=$(mktemp -d)
trap "rm -rf $TEMPDIR" EXIT

echo ""
echo "============================================"
echo "  OFFLINE RESOURCES - privacyIDEA-docker"
echo "============================================"
echo ""
echo "Proyecto:     $PROJECT_DIR"
echo "Output:       $OUTDIR/"
echo ""

# Detectar SO y arquitectura
OS_ID=$(lsb_release -si 2>/dev/null || (. /etc/os-release && echo "$ID"))
OS_CODENAME=$(lsb_release -sc 2>/dev/null || (. /etc/os-release && echo "$VERSION_CODENAME"))
OS_RELEASE=$(lsb_release -sr 2>/dev/null || (. /etc/os-release && echo "$VERSION_ID"))
OS_ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
OS_TAG=$(echo "$OS_ID" | tr '[:upper:]' '[:lower:]')-${OS_RELEASE}
DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
COMPOSE_VERSION=$(docker compose version 2>/dev/null | cut -d' ' -f4 | tr -d ',')

# Advertencia si SO no es Ubuntu LTS conocido
KNOWN_LTS=("20.04" "22.04" "24.04")
OS_MATCH=0
for ver in "${KNOWN_LTS[@]}"; do
    [ "$OS_RELEASE" = "$ver" ] && OS_MATCH=1 && break
done
if [ "$OS_MATCH" -eq 0 ]; then
    echo "  [WARN] SO $OS_ID $OS_RELEASE no es Ubuntu LTS conocido"
    echo "         Verificar compatibilidad con servidor destino"
fi

echo "OS:           $OS_ID $OS_RELEASE ($OS_CODENAME / $OS_ARCH)"
echo "Docker:       $DOCKER_VERSION"
echo "Compose:      $COMPOSE_VERSION"
echo ""

# =================================================================
# 1/3 Descargar Paquetes .deb (Docker + System)
# =================================================================
echo "--- 1/3: Descargando paquetes .deb ---"

TOP_PKGS=(
    docker-ce docker-ce-cli containerd.io
    docker-buildx-plugin docker-compose-plugin
    ca-certificates curl dos2unix gnupg
    htop openssh-server sysstat tree unzip
)

echo "  -> Resolviendo dependencias..."
ALL_DEPS=$(apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances \
    "${TOP_PKGS[@]}" 2>/dev/null \
    | awk '/^\s+\w+:/ {print $2}' \
    | sed 's/:any$//;s/:i386$//;s/:amd64$//' \
    | sort -u)

TOTAL_DEPS=$(echo "$ALL_DEPS" | wc -w)

echo "  -> Descargando $TOTAL_DEPS paquetes..."
cd "$TEMPDIR"
apt-get download $ALL_DEPS 2>&1 | tail -3 || true

# Eliminar descargas fallidas
find . -name "*.deb" -size 0 -delete 2>/dev/null || true
DEB_COUNT=$(find . -name "*.deb" | wc -l)
echo "  -> Descomprimidos: ${DEB_COUNT} .deb"

APT_FILE="offline-docker-packages-${OS_TAG}.tar.gz"
echo "  -> Comprimiendo $APT_FILE..."
tar -czf "$OUTDIR/$APT_FILE" *.deb 2>/dev/null
echo "  -> OK: $APT_FILE"

# =================================================================
# 2/3 Exportar Imagenes Docker dg/*
# =================================================================
echo ""
echo "--- 2/3: Exportando imagenes dg/* ---"

DG_IMAGES=$(docker image ls --filter "reference=dg/*" --format "{{.Repository}}:{{.Tag}}")

if [ -z "$DG_IMAGES" ]; then
    echo "  -> [ERROR] No se encontraron imagenes dg/*"
    echo "     Ejecuta 'docker compose build' primero"
    exit 1
fi

echo "  -> Imagenes detectadas:"
for img in $DG_IMAGES; do
    img_size=$(docker image ls --format "{{.Size}}" "$img" 2>/dev/null)
    echo "       $img  ($img_size)"
done

echo ""
echo "  -> Exportando y comprimiendo (puede tardar)..."
docker save $DG_IMAGES | gzip -9 > "$OUTDIR/offline-dg-images.tar.gz"

DG_FILE="offline-dg-images-${OS_TAG}.tar.gz"

# Renombrar con OS_TAG si existe
if [ -f "$OUTDIR/offline-dg-images.tar.gz" ]; then
    mv "$OUTDIR/offline-dg-images.tar.gz" "$OUTDIR/$DG_FILE"
fi

DG_SIZE=$(du -sh "$OUTDIR/$DG_FILE" | cut -f1)
echo "  -> OK: $DG_FILE ($DG_SIZE)"

# =================================================================
# Generar Metadata
# =================================================================
DG_COUNT=$(echo "$DG_IMAGES" | wc -l)

cat > "$OUTDIR/offline_bundle_metadata.txt" <<META
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Metadata del Bundle Offline - privacyIDEA-docker
# =================================================================
SOURCE_OS=$OS_ID $OS_RELEASE ($OS_CODENAME)
SOURCE_ARCH=$OS_ARCH
DOCKER_VERSION=$DOCKER_VERSION
COMPOSE_VERSION=$COMPOSE_VERSION
GENERATED=$(date +%Y-%m-%d)
PACKAGES_DEB=$DEB_COUNT
DG_IMAGES=$DG_COUNT
APT_FILE=$APT_FILE
DG_FILE=$DG_FILE
#End Development By AEntrepreneur [PI-docker 2026]
META
echo "  -> OK: offline_bundle_metadata.txt"

# =================================================================
# 3/3 Generar Guia de Despliegue
# =================================================================
echo ""
echo "--- 3/3: Generando offline_deploy_guide.md ---"

APT_SIZE=$(du -sh "$OUTDIR/$APT_FILE" | cut -f1)
DG_COUNT=$(echo "$DG_IMAGES" | wc -l)

cat > "$OUTDIR/offline_deploy_guide.md" <<GUIDE
# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Guia de Despliegue Offline - privacyIDEA-docker
# =================================================================

## Requisitos del Servidor Destino

- SO: $OS_ID $OS_RELEASE ($OS_CODENAME) - MISMO QUE DONDE SE GENERO
- Arquitectura: $OS_ARCH
- User: sudo/root

## Validacion de Compatibilidad

Ejecutar esto en el servidor offline ANTES de instalar:

\`\`\`bash
cat /etc/os-release
\`\`\`

Debe coincidir con:
- ID: $OS_ID (o similar, ej: ubuntu)
- VERSION_ID: "$OS_RELEASE" (debe ser exacto)
- dpkg --print-architecture: $OS_ARCH

> Si el SO no coincide, los .deb pueden fallar por dependencias
> incompatibles (libc, libssl, etc.). Regenerar el bundle en una
> maquina con el mismo SO que el servidor destino.

## Archivos Incluidos

| Archivo | Tamanio | Contenido |
|---------|---------|-----------|
| $APT_FILE | $APT_SIZE | Paquetes .deb Docker + system + dependencias |
| $DG_FILE | $DG_SIZE | Imagenes Docker dg/* ($DG_COUNT tags) |
| offline_bundle_metadata.txt | - | Metadatos del bundle |
| offline_deploy_guide.md | - | Esta guia |

## Paso 1: Transferir al Servidor Offline

\`\`\`bash
# Desde maquina con internet, transferir via SCP/USB
scp -r offline_bundle/ usuario@servidor-offline:/tmp/
\`\`\`

## Paso 2: Instalar Paquetes .deb (Docker + System)

\`\`\`bash
cd /tmp/offline_bundle
tar -xzf $APT_FILE
sudo dpkg -i *.deb
\`\`\`

Verificar instalacion:
\`\`\`bash
docker --version
docker compose version
\`\`\`

## Paso 3: Cargar Imagenes Docker

\`\`\`bash
gzip -dc $DG_FILE | docker load
\`\`\`

Verificar:
\`\`\`bash
docker images --filter "reference=dg/*"
\`\`\`

## Paso 4: Ejecutar Bootstrap (crea .env, volumenes, redes, certificados)

\`\`\`bash
sudo bash bootstrap.sh
\`\`\`

## Paso 5: Validar Instalacion

\`\`\`bash
docker ps -a
docker compose logs --tail=20
\`\`\`

## Notas

- Los paquetes .deb se generaron para $OS_ID $OS_RELEASE ($OS_CODENAME / $OS_ARCH)
  Usar en mismo SO y arquitectura para evitar conflictos de librerias
- Las imagenes Docker (dg/*) encapsulan Python y pip, no dependen del SO host
- Los volumenes, redes, .env y certificados se crean en bootstrap.sh
- Ver metadata en offline_bundle_metadata.txt para detalles tecnicos

#End Development By AEntrepreneur [PI-docker 2026]
GUIDE

echo "  -> OK: offline_deploy_guide.md"

# =================================================================
# Resumen Final
# =================================================================
echo ""
echo "============================================"
echo "  RESUMEN - OFFLINE BUNDLE"
echo "============================================"
echo ""
echo "Output:    $OUTDIR/"
echo "SO Origen: $OS_ID $OS_RELEASE ($OS_CODENAME / $OS_ARCH)"
echo ""
printf "  %-55s %s\n" "$APT_FILE" "$APT_SIZE"
printf "  %-55s %s\n" "$DG_FILE" "$DG_SIZE"
printf "  %-55s %s\n" "offline_deploy_guide.md" "-"
printf "  %-55s %s\n" "offline_bundle_metadata.txt" "-"
echo ""
echo "Peso total:"
TOTAL=$(du -sh "$OUTDIR" | cut -f1)
echo "  $TOTAL"
echo ""
echo "Transferencia:"
echo "  scp -r $OUTDIR usuario@servidor-offline:/tmp/"
echo ""
echo "¡Listo!"
echo ""

#End Development By AEntrepreneur [PI-docker 2026]