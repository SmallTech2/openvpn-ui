#!/usr/bin/env bash
set -Eeuo pipefail
CERT_NAME="${1:?Nom manquant}"
CERT_SERIAL="${2:?Numero de serie manquant}"
[[ "$CERT_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.@-]*$ && "$CERT_SERIAL" =~ ^[a-fA-F0-9]+$ ]] || exit 1
APP_CONF="${OPENVPN_UI_CONFIG:-/opt/openvpn-ui-runtime/conf/app.conf}"
EASY_RSA=$(grep -E '^EasyRsaPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
OPENVPN_DIR=$(grep -E '^OpenVpnPath\s*=' "$APP_CONF" | cut -d= -f2 | tr -d '"[:space:]')
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$EASY_RSA"
export EASYRSA_BATCH=1
STATUS=$(awk -F '\t' -v serial="$CERT_SERIAL" 'toupper($4)==toupper(serial){print $1}' pki/index.txt)
[[ "$STATUS" =~ ^[VER]$ ]] || { echo 'Certificat absent ou serie ambigue.' >&2; exit 1; }

if [[ "$STATUS" != R ]]; then
  FOUND=false
  for kind in issued renewed/issued; do
    file="pki/$kind/$CERT_NAME.crt"
    [[ -s "$file" ]] || continue
    serial=$(openssl x509 -in "$file" -noout -serial)
    [[ "${serial#serial=}" == "${CERT_SERIAL^^}" ]] || continue
    if [[ "$kind" == issued ]]; then
      ./easyrsa revoke-issued "$CERT_NAME"
      rm -f -- "$OPENVPN_DIR/clients/$CERT_NAME.ovpn"
    else
      ./easyrsa revoke-renewed "$CERT_NAME"
      bash "$SCRIPT_DIR/write-client-profile.sh" "$CERT_NAME"
    fi
    FOUND=true
    break
  done
  $FOUND || { echo 'Le fichier du certificat ne correspond pas a la serie.' >&2; exit 1; }
fi
# Ne jamais supprimer les entrees R : elles alimentent toutes les futures CRL.
./easyrsa gen-crl
chmod 644 pki/crl.pem
 echo 'Certificat revoque ; historique CA conserve.'
