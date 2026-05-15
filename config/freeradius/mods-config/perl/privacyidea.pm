# privacyidea.pm — Override de variables legacy para rlm_perl
# Este archivo es leído por FreeRADIUS mods-config/perl/
# Con rlm_perl.ini correctamente configurado, esto es solo fallback

# URL del servicio privacyIDEA (nombre de servicio Docker)
$URL = "http://privacyidea:8000/validate/check";

# 0 = no verificar SSL (correcto para HTTP interno)
$SSL_VERIFY = 0;