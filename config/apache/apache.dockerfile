# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# Proxy HTTPS Apache 2.4 para privacyIDEA
# =================================================================
ARG APACHE_VERSION=latest

FROM httpd:${APACHE_VERSION}

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

#End Development By AEntrepreneur [PI-docker 2026]
