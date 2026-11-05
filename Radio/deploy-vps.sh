#!/usr/bin/env bash
# Radio Bonheur — installateur Debian 13 / OpenVPN natif
# VERSION DE RECETTE : NE PAS EXECUTER AVANT REVUE ET SAUVEGARDE DE L'ANCIEN VPS.
# Usage : sudo bash deploy-vps.sh install <IP_PUBLIQUE> <10.N>
#         sudo bash deploy-vps.sh start
set -Eeuo pipefail
umask 077
REPO='SmallTech2/openvpn-ui'
SOURCE_REF="${RADIO_SOURCE_REF:-main}"         # test uniquement ; figer au tag validé
RELEASE_TAG='radio-build-test1'
INSTALL_ROOT='/opt/openvpn-ui-runtime'
TMP=''
log(){ printf '\n==> %s\n' "$*"; }
die(){ printf '\nERREUR : %s\n' "$*" >&2; exit 1; }
cleanup(){ [[ -z "$TMP" ]] || rm -rf -- "$TMP"; }
trap cleanup EXIT
[[ $EUID -eq 0 ]] || die 'Exécuter en root.'
[[ -t 0 ]] || die 'Un terminal interactif est nécessaire.'
[[ -r /etc/os-release ]] || die '/etc/os-release introuvable.'
. /etc/os-release
[[ $ID == debian && $VERSION_ID == 13 ]] || die 'Debian 13 uniquement.'
[[ $(uname -m) == x86_64 ]] || die 'Architecture AMD64 uniquement.'

require_password(){
  local one two
  while :; do
    read -r -s -p "$1 (12 caractères min.) : " one </dev/tty; printf '\n' >/dev/tty
    read -r -s -p 'Confirmer : ' two </dev/tty; printf '\n' >/dev/tty
    [[ "$one" == "$two" ]] || { echo 'Saisies différentes.'; continue; }
    [[ ${#one} -ge 12 && "$one" =~ ^[a-zA-Z0-9._@+=,:!-]+$ ]] || { echo 'Mot de passe trop court ou caractères non autorisés.'; continue; }
    REPLY="$one"; return
  done
}

install_radio(){
  local public_ip="${1:-}" net="${2:-}" octet=''
  [[ "$public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die 'IP publique invalide.'
  IFS=. read -r -a ip_parts <<< "$public_ip"
  for octet in "${ip_parts[@]}"; do (( 10#$octet <= 255 )) || die 'IP publique invalide.'; done
  [[ "$net" =~ ^10\.[123]$ ]] || die 'Réseau attendu : 10.1, 10.2 ou 10.3.'
  [[ ! -e "$INSTALL_ROOT" && ! -e /etc/openvpn/server.conf && ! -e /etc/openvpn/pki ]] || die 'Installation existante détectée. Refus de remplacer.'
  [[ ! -f /etc/radio-vpn-deployed ]] || die 'Déploiement déjà effectué.'
  [[ "$SOURCE_REF" =~ ^[a-zA-Z0-9._/-]+$ && "$SOURCE_REF" != *..* ]] || die 'Référence Git invalide.'
  [[ "$SOURCE_REF" == main ]] && echo 'ATTENTION : modèles depuis main (recette seulement). La Release a son propre commit compilé.'

  log 'Création des mots de passe'
  require_password 'Mot de passe technicien'; local technician_pw="$REPLY"; unset REPLY
  require_password 'Mot de passe admin OpenVPN UI'; local gui_pw="$REPLY"; unset REPLY
  log 'Clé SSH publique du poste administrateur'
  echo 'Collez la clé PUBLIQUE ED25519 (ligne ssh-ed25519 ...), ou laissez vide pour reporter cette étape.'
  local pubkey
  read -r -p 'Clé SSH publique : ' pubkey </dev/tty
  if [[ -n "$pubkey" ]]; then
    [[ "$pubkey" =~ ^ssh-ed25519[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]] || die 'Clé publique ED25519 invalide.'
  fi

  log 'Dépendances Debian (sans Go et sans Docker)'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends sudo openssh-server ca-certificates curl unzip tar \
    openvpn easy-rsa nftables openssl python3 oathtool qrencode iproute2 util-linux

  log 'Téléchargement de la source du fork et du binaire de Release'
  TMP="$(mktemp -d)"; mkdir -p "$TMP/src" "$TMP/bin"
  curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
    "https://github.com/$REPO/archive/refs/heads/$SOURCE_REF.tar.gz" -o "$TMP/source.tgz" \
    || { [[ "$SOURCE_REF" == main ]] || die 'Téléchargement Git impossible : utiliser le tag validé.'; die 'Source GitHub inaccessible.'; }
  tar -xzf "$TMP/source.tgz" -C "$TMP/src" --strip-components=1
  curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
    "https://github.com/$REPO/releases/download/$RELEASE_TAG/radio-openvpn-ui-linux-amd64.zip" \
    -o "$TMP/openvpn-ui.zip"
  unzip -q "$TMP/openvpn-ui.zip" -d "$TMP/bin"
  [[ -s "$TMP/bin/openvpn-ui" && -s "$TMP/bin/openvpn-ui.sha256" && -s "$TMP/bin/source-commit.txt" ]] || die 'Release incomplète : binaire, SHA256 ou commit absent.'
  [[ $(cat "$TMP/bin/source-commit.txt") =~ ^[0-9a-f]{40}$ ]] || die 'Commit du binaire invalide.'
  (cd "$TMP/bin" && sha256sum -c openvpn-ui.sha256) || die 'SHA256 du binaire invalide.'
  [[ -d "$TMP/src/Radio/scripts" && -d "$TMP/src/Radio/config" ]] || die 'Radio/scripts ou Radio/config absent du fork.'
  local f
  for f in genclient.sh generate_ca_and_server_certs.sh oath.sh remove.sh renew.sh restart.sh revoke.sh rmcert.sh; do
    [[ -s "$TMP/src/Radio/scripts/$f" ]] || die "Script manquant dans Radio/scripts : $f"
  done
  for f in app.conf server.conf.tpl client.conf.tpl openvpn-server-config.tpl openvpn-client-config.tpl easyrsa-vars.tpl openvpn-ui.service nftables.conf.tpl; do
    [[ -s "$TMP/src/Radio/config/$f" ]] || die "Modèle manquant : $f"
  done
  for f in static views swagger; do [[ -d "$TMP/src/$f" ]] || die "Ressources UI manquantes : $f"; done
  grep -q 'management 127.0.0.1 2080' "$TMP/src/Radio/config/server.conf.tpl" || die 'Management non restreint dans le modèle.'

  log 'Création du compte technicien et configuration SSH'
  if ! id -u technicien >/dev/null 2>&1; then useradd -m -s /bin/bash technicien; fi
  usermod -aG sudo technicien
  printf 'technicien:%s\n' "$technician_pw" | chpasswd
  unset technician_pw
  if [[ -n "$pubkey" ]]; then
    install -d -m 700 -o technicien -g technicien /home/technicien/.ssh
    printf '%s\n' "$pubkey" >> /home/technicien/.ssh/authorized_keys
    chown technicien:technicien /home/technicien/.ssh/authorized_keys
    chmod 600 /home/technicien/.ssh/authorized_keys
  fi
  systemctl enable --now ssh
  # Aucune désactivation du mot de passe avant validation SSH par clé sur un 2e terminal.

  log 'Installation des fichiers OpenVPN UI'
  install -d -m 755 "$INSTALL_ROOT" /opt/scripts /etc/openvpn/config \
    /etc/openvpn/clients /etc/openvpn/staticclients /var/log/openvpn
  install -m 755 "$TMP/bin/openvpn-ui" "$INSTALL_ROOT/openvpn-ui"
  cp -a "$TMP/src/static" "$TMP/src/views" "$TMP/src/swagger" "$INSTALL_ROOT/"
  [[ -f "$TMP/src/LICENSE" ]] && cp "$TMP/src/LICENSE" "$INSTALL_ROOT/" || true
  install -d -m 755 "$INSTALL_ROOT/conf"; install -d -m 700 "$INSTALL_ROOT/db"
  install -m 644 "$TMP/src/Radio/config/app.conf" "$INSTALL_ROOT/conf/app.conf"
  install -m 644 "$TMP/src/Radio/config/openvpn-server-config.tpl" "$INSTALL_ROOT/conf/openvpn-server-config.tpl"
  install -m 644 "$TMP/src/Radio/config/openvpn-client-config.tpl" "$INSTALL_ROOT/conf/openvpn-client-config.tpl"
  install -m 644 "$TMP/src/Radio/config/easyrsa-vars.tpl" "$INSTALL_ROOT/conf/easyrsa-vars.tpl"
  install -m 755 "$TMP/src/Radio/scripts/"*.sh /opt/scripts/
  # Certains scripts historiques utilisent /opt/scripts/qrencode
  ln -s /usr/bin/qrencode /opt/scripts/qrencode
  # Répertoire de travail figé, PKI unique (au même emplacement que Easy-RSA)
  install -d -m 755 /usr/share/easy-rsa/pki
  ln -s /usr/share/easy-rsa/pki /etc/openvpn/pki
  sed -e "s/@PUBLIC_IP@/$public_ip/g" "$TMP/src/Radio/config/client.conf.tpl" > /etc/openvpn/config/client.conf
  sed -e "s/@VPN_NETWORK@/$net.0.0/g" "$TMP/src/Radio/config/server.conf.tpl" > /etc/openvpn/server.conf
  install -m 644 "$TMP/src/Radio/config/openvpn-ui.service" /etc/systemd/system/openvpn-ui.service
  # Valeur contrôlée : pas de caractères nécessitant un échappement systemd.
  printf 'OPENVPN_ADMIN_PASSWORD=%s\n' "$gui_pw" > /etc/openvpn-ui.env
  chmod 600 /etc/openvpn-ui.env
  unset gui_pw
  # Source de templates également fournie à la GUI pour modifications ultérieures.
  install -m 644 "$TMP/src/Radio/config/easyrsa-vars.tpl" /etc/openvpn/config/easy-rsa.vars.template
  systemctl daemon-reload
  systemctl enable --now openvpn-ui
  systemctl is-active --quiet openvpn-ui || die 'OpenVPN UI ne démarre pas : journalctl -u openvpn-ui -n 50'

  log 'Préparation pare-feu (NON activé automatiquement : validation SSH préalable)'
  install -m 600 "$TMP/src/Radio/config/nftables.conf.tpl" /etc/nftables.conf
  nft -c -f /etc/nftables.conf || die 'Configuration nftables incorrecte.'
  log 'Préparation du renouvellement CRL (activé après initialisation PKI)'
  cat > /usr/local/sbin/radio-renew-crl <<'CRL'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ -s /etc/openvpn/pki/ca.crt ]] || exit 0
cd /usr/share/easy-rsa
./easyrsa gen-crl
chmod 644 /usr/share/easy-rsa/pki/crl.pem
openssl crl -in /usr/share/easy-rsa/pki/crl.pem -noout -nextupdate
CRL
  chmod 700 /usr/local/sbin/radio-renew-crl
  cat > /etc/systemd/system/radio-renew-crl.service <<'UNIT'
[Unit]
Description=Radio Bonheur - renouvellement de la CRL
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/radio-renew-crl
UNIT
  cat > /etc/systemd/system/radio-renew-crl.timer <<'UNIT'
[Unit]
Description=Radio Bonheur - renouvellement hebdomadaire de la CRL
[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=30min
[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload
  printf 'source_ref=%s\nrelease_tag=%s\nrelease_source_commit=%s\npublic_ip=%s\nnetwork=%s\n' "$SOURCE_REF" "$RELEASE_TAG" "$(cat "$TMP/bin/source-commit.txt")" "$public_ip" "$net" > /etc/radio-vpn-deployed
  chmod 600 /etc/radio-vpn-deployed
  log 'Préparation terminée. Finaliser les paramètres PKI dans la GUI via tunnel SSH.'
  echo "Tunnel depuis Windows : ssh -L 8080:127.0.0.1:8080 technicien@$public_ip"
  echo 'GUI : http://127.0.0.1:8080 ; ne PAS ouvrir 8080 dans le pare-feu cloud.'
  echo 'Initialiser la PKI une seule fois, puis exécuter : sudo bash deploy-vps.sh start'
  echo 'nftables et le durcissement SSH nécessitent encore validation avant activation.'
}
start_radio(){
  [[ -f /etc/radio-vpn-deployed ]] || die 'Exécuter install avant start.'
  local f
  for f in ca.crt issued/server.crt private/server.key crl.pem dh.pem ta.key; do
    [[ -s /etc/openvpn/pki/$f ]] || die "PKI incomplète : $f";
  done
  openssl crl -in /etc/openvpn/pki/crl.pem -noout -nextupdate
  chmod 644 /etc/openvpn/pki/crl.pem
  chmod 755 /etc/openvpn/staticclients
  systemctl enable --now openvpn@server.service
  systemctl is-active --quiet openvpn@server.service || die 'OpenVPN arrêté : journalctl -u openvpn@server -n 60'
  local vpn_net
  vpn_net="$(sed -n 's/^network=//p' /etc/radio-vpn-deployed)"
  ip -4 address show tun0 | grep -Fq "inet ${vpn_net}.0.1/16" || die "tun0 absente ou IP différente de ${vpn_net}.0.1/16"
  ss -lun | grep -q ':1194' || die 'OpenVPN ne semble pas écouter en UDP 1194.'
  systemctl enable --now radio-renew-crl.timer
  log 'OpenVPN actif et CRL planifiée. Tester un client avant de durcir le pare-feu et SSH.'
}
case "${1:-}" in
 install) shift; install_radio "$@" ;;
 start) shift; start_radio ;;
 *) echo "Usage: bash $0 install <IP_PUBLIQUE> <10.N> | start"; exit 2;;
esac
