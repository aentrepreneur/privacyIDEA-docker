# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Servidor FreeRADIUS 3.0 con plugin Perl privacyIDEA
# =================================================================
# Dependencias Perl: libwww, libjson, IO::Socket::SSL, Config::IniFiles, URI::Encode
# Plugin: privacyidea_radius.pm via rlm_perl
# LDAP: freeradius-ldap para mods-enabled/ldap
# =================================================================
ARG UBUNTU_VERSION=20.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

# Instalar FreeRADIUS + dependencias Perl para el plugin privacyIDEA + LDAP
RUN apt-get update && apt-get install -y \
    freeradius \
    freeradius-utils \
    libwww-perl \
    libjson-perl \
    libio-socket-ssl-perl \
    libconfig-inifiles-perl \
    liburi-encode-perl \
    freeradius-ldap \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Directorios necesarios para el plugin y su configuración
RUN mkdir -p /usr/share/privacyidea/freeradius \
    && mkdir -p /etc/privacyidea \
    && mkdir -p /etc/freeradius/3.0/mods-available \
    && mkdir -p /etc/freeradius/3.0/mods-enabled \
    && mkdir -p /etc/freeradius/3.0/sites-available \
    && mkdir -p /etc/freeradius/3.0/sites-enabled \
    && mkdir -p /etc/freeradius/3.0/mods-config/files

# Descargar el .pm oficial de privacyIDEA (plugin rlm_perl)
RUN curl -sSL https://raw.githubusercontent.com/privacyidea/freeradius/master/privacyidea_radius.pm \
    -o /usr/share/privacyidea/freeradius/privacyidea_radius.pm \
    && chmod 644 /usr/share/privacyidea/freeradius/privacyidea_radius.pm

# Módulos Críticos mediante enlaces simbólicos
# RUN ln -s /etc/freeradius/3.0/mods-available/perl /etc/freeradius/3.0/mods-enabled/perl || true \
#     && ln -s /etc/freeradius/3.0/mods-available/ldap /etc/freeradius/3.0/mods-enabled/ldap || true

# Exponer puertos RADIUS estándar
EXPOSE 1812/udp 1813/udp

# Con Ubuntu, el comando es 'freeradius', no 'radiusd'
# -f = foreground, -X = debug (quitar -X en producción)
CMD ["freeradius", "-f"]

#End Development By AEntrepreneur [PI-docker 2026]