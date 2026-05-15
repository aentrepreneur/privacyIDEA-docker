# Development By AEntrepreneur [PI-docker 2026]
# =================================================================
# privacyIDEA 3.12.3 Actual - Ubuntu 22.04 Python 3.10
# =================================================================
# Dependencias parcheadas: cffi 1.14.6, cryptography 3.3.2, pyOpenSSL 20.0.1
# Usuario no-root: privacyidea
# Entrypoint: pi_entrypoint.sh
# =================================================================
ARG UBUNTU_VERSION=latest
FROM ubuntu:${UBUNTU_VERSION}

ARG PYTHON_VERSION=latest
ARG PI_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive
ENV PY_VER=${PYTHON_VERSION}
ENV PATH="/opt/privacyidea/venv/bin:$PATH"

# Instalación de Dependencias OS
RUN apt-get update && apt-get install -y \
    python${PY_VER} \
    python${PY_VER}-venv \
    python${PY_VER}-dev \
    python3-pip \
    libmariadb-dev \
    default-mysql-client \
    libpq-dev \
    build-essential \
    curl \
    gnupg \
    libffi-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    zlib1g-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Aprovisionamiento de Usuario No-Root (Seguridad)
RUN groupadd -r privacyidea && useradd -r -g privacyidea -d /opt/privacyidea -s /bin/bash privacyidea
RUN mkdir -p /opt/privacyidea/etc /opt/privacyidea/data /var/log/privacyidea \
    && chown -R privacyidea:privacyidea /opt/privacyidea /var/log/privacyidea

WORKDIR /opt/privacyidea

# Transición a Usuario No-Root
USER privacyidea

# Inicialización de Entorno Virtual (vEnv)
RUN python${PY_VER} -m venv venv

# Descarga y Parcheo de Dependencias (requirements.txt)
RUN curl -sSL https://raw.githubusercontent.com/privacyidea/privacyidea/v${PI_VERSION}/requirements.txt -o requirements.txt \
    && sed -i 's/cffi==1.7.0/cffi==1.14.6/g' requirements.txt \
    && sed -i 's/cryptography==2.4.2/cryptography==3.3.2/g' requirements.txt \
    && sed -i 's/pyOpenSSL==18.0.0/pyOpenSSL==20.0.1/g' requirements.txt \
    && sed -i 's/PyMySQL==0.8.1/PyMySQL>=0.9.3/g' requirements.txt \
    && pip install --no-cache-dir "pip<22.0" "setuptools<58.0" wheel \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir pymysql gunicorn privacyidea==${PI_VERSION}


# Inyección de Script Entrypoint
COPY pi_entrypoint.sh /opt/privacyidea/entrypoint.sh

# Asignación de Permisos de Ejecución (Temporal Root)
USER root
RUN chmod +x /opt/privacyidea/entrypoint.sh && \
    mkdir -p /etc/privacyidea && \
    chown privacyidea:privacyidea /etc/privacyidea && \
    chmod 700 /etc/privacyidea
USER privacyidea

EXPOSE 8000

# Definición de Entrypoint
ENTRYPOINT ["/opt/privacyidea/entrypoint.sh"]

#End Development By AEntrepreneur [PI-docker 2026]
