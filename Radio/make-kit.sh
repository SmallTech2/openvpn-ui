#!/usr/bin/env bash
# Radio Bonheur — kit de référence OpenVPN UI (Debian 13, sans Docker)
# Usage (root, VPS fonctionnel) : bash make-kit.sh [chemin_archive.tgz]
set -euo pipefail
umask 077

OUT="${1:-/root/radio-vpn-kit.tgz}"
die() { printf '[ERREUR] %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }
[[ $EUID -eq 0 ]] || die 'Exécuter en root.'
[[ $OUT == *.tgz ]] || die 'Le fichier de sortie doit se terminer par .tgz.'
OUT_DIR="$(dirname "$OUT")"
[[ -d $OUT_DIR ]] || die "Répertoire de sortie absent : $OUT_DIR"
OUT="$(cd "$OUT_DIR" && pwd)/$(basename "$OUT")"

REQUIRED=(
  /opt/openvpn-ui-runtime/openvpn-ui
  /opt/openvpn-ui-runtime/conf/app.conf
  /opt/scripts/genclient.sh
  /opt/scripts/qrencode
  /etc/systemd/system/openvpn-ui.service
  /etc/nftables.conf
  /etc/openvpn/server.conf
  /etc/openvpn/config/easy-rsa.vars
  /etc/openvpn/config/client.conf
)
for item in "${REQUIRED[@]}"; do
  [[ -e $item ]] || die "Élément manquant : $item"
done
grep -q '<tls-crypt>' /opt/scripts/genclient.sh || die 'genclient.sh ne contient pas le correctif tls-crypt.'

REF_IP="$(awk '$1=="remote"{print $2;exit}' /etc/openvpn/config/client.conf)"
REF_NET="$(awk '$1=="server"{split($2,a,".");print a[1]"."a[2];exit}' /etc/openvpn/server.conf)"
[[ $REF_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die 'IP de référence introuvable dans client.conf.'
[[ $REF_NET =~ ^10\.[0-9]{1,3}$ ]] || die 'Réseau de référence invalide dans server.conf.'
COMMIT="$(git -C /opt/openvpn-ui rev-parse HEAD 2>/dev/null)" || die 'Commit Git introuvable.'
[[ $COMMIT =~ ^[0-9a-f]{40}$ ]] || die 'Commit Git invalide.'

STAGE="$(mktemp -d)"
TMP_ARCHIVE=''
cleanup() { rm -rf -- "$STAGE"; [[ -z $TMP_ARCHIVE ]] || rm -f -- "$TMP_ARCHIVE"; }
trap cleanup EXIT

info 'Copie contrôlée des fichiers nécessaires'
mkdir -p "$STAGE/opt" "$STAGE/etc/systemd/system" "$STAGE/etc/openvpn/config" "$STAGE/etc"
cp -a /opt/openvpn-ui-runtime "$STAGE/opt/"
cp -a /opt/scripts "$STAGE/opt/"
cp -a /etc/systemd/system/openvpn-ui.service "$STAGE/etc/systemd/system/"
cp -a /etc/nftables.conf "$STAGE/etc/"
cp -a /etc/openvpn/server.conf "$STAGE/etc/openvpn/"
cp -a /etc/openvpn/config/easy-rsa.vars /etc/openvpn/config/client.conf "$STAGE/etc/openvpn/config/"

# Pas de données d'exploitation, même si la DB porte un autre nom.
rm -rf -- "$STAGE/opt/openvpn-ui-runtime/db"
# Aucun profil client/certificat/clé privée ou archive dérivée ne doit partir dans le kit.
# Refuser plutôt qu'effacer silencieusement un fichier inattendu.
BAD_FILES="$(find "$STAGE" \( -type f -o -type l \) \
  \( -iname '*.ovpn' -o -iname '*.key' -o -iname '*.crt' -o -iname '*.pem' \
     -o -iname '*.p12' -o -iname '*.pfx' -o -iname '*.db' -o -iname '*.sqlite*' \
     -o -iname '*.tgz' -o -iname '*.tar' -o -iname '*.zip' -o -name '.env' \
     -o -name '*-ui.env' \) -print)"
[[ -z $BAD_FILES ]] || die "Fichiers potentiellement sensibles détectés dans le kit :\n$BAD_FILES"

# Nettoyage ciblé des paramètres OAuth non utilisés. Les autres paramètres sont conservés.
for conf in "$STAGE/opt/scripts/app.conf" "$STAGE/opt/openvpn-ui-runtime/conf/app.conf"; do
  [[ -f $conf ]] || continue
  sed -i -E '/^[[:space:]]*(googleClientID|googleClientSecret)[[:space:]]*=/I s/=.*/= ""/' "$conf"
done

# Refuser tout contenu de clés privées au sein de fichiers au nom anodin.
if grep -rIlE -- '-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----' \
  "$STAGE/opt" "$STAGE/etc" >/dev/null; then
  die 'Bloc de clé privée détecté dans les fichiers du kit.'
fi

cat > "$STAGE/etc/radio-vpn-kit.env" <<META
REF_IP=$REF_IP
REF_NET=$REF_NET
COMMIT=$COMMIT
ARCH=$(uname -m)
OPENVPN_VERSION=$(openvpn --version | head -n1)
BUILT=$(date -Is)
META

info 'Création de l’archive (sans toucher à une archive existante en cas d’échec)'
TMP_ARCHIVE="$(mktemp "$OUT_DIR/.radio-vpn-kit.XXXXXXXX.tgz")"
(
  cd "$STAGE"
  tar -czf "$TMP_ARCHIVE" opt/openvpn-ui-runtime opt/scripts \
    etc/systemd/system/openvpn-ui.service etc/nftables.conf \
    etc/openvpn/server.conf etc/openvpn/config/easy-rsa.vars \
    etc/openvpn/config/client.conf etc/radio-vpn-kit.env
)
tar -tzf "$TMP_ARCHIVE" >/dev/null || die 'Archive invalide.'
if tar -tzf "$TMP_ARCHIVE" | grep -Ei '(^|/)(pki|db)(/|$)|\.(ovpn|key|crt|pem|p12|pfx|sqlite|db)$|(^|/)openvpn-ui\.env$' ; then
  die 'Élément interdit détecté dans l’archive.'
fi
chmod 600 "$TMP_ARCHIVE"
mv -f -- "$TMP_ARCHIVE" "$OUT"
TMP_ARCHIVE=''
( cd "$OUT_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
chmod 600 "$OUT.sha256"
printf '\nKit créé : %s\nEmpreinte : %s.sha256\nCommit : %s\n' "$OUT" "$OUT" "$COMMIT"
printf 'À récupérer sur le PC : les deux fichiers ci-dessus.\n'
