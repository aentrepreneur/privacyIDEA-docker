# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Servidor OpenLDAP con TLS
# =================================================================
# Paquetes: slapd, ldap-utils, openssl, gettext-base
# =================================================================
ARG UBUNTU_VERSION=20.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    slapd \
    ldap-utils \
    openssl \
    gettext-base \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/ldap /etc/ldap /var/run/slapd \
    && chown -R openldap:openldap /var/lib/ldap /etc/ldap /var/run/slapd 2>/dev/null || true

EXPOSE 389 636

CMD ["slapd", "-d", "0", "-f", "/etc/ldap/slapd.conf", "-h", "ldap:/// ldaps:/// ldapi:///", "-4"]

#End Development By AEntrepreneur [PI-docker 2026]
