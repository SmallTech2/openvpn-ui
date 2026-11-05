#!/usr/bin/env bash
# Radio Bonheur - Debian 13 AMD64, OpenVPN natif. Aucun VPS n'est modifie hors execution explicite.
# Usage : sudo bash deploy-vps.sh [install [IP_PUBLIQUE [10.N]]]
set -Eeuo pipefail
umask 077
REPO='SmallTech2/openvpn-ui'
RELEASE_TAG="${RADIO_RELEASE_TAG:-radio-build-test2}"
SOURCE_REF="${RADIO_SOURCE_REF:-}"
INSTALL_ROOT='/opt/openvpn-ui-runtime'
TMP=''
FIREWALL_PENDING=false
log(){ printf '\n==> %s\n' "$*"; }
die(){ printf '\nERREUR : %s\n' "$*" >&2; exit 1; }
cleanup(){
  local status=$?
  if $FIREWALL_PENDING; then
    echo 'Echec : arret des services VPN/UI et restauration du pare-feu precedent.' >&2
    /usr/local/sbin/radio-restore-firewall || true
  fi
  [[ -z "$TMP" ]] || rm -rf -- "$TMP"
  return "$status"
}
require_password(){
  local one two minimum="${2:-8}" pattern="${3:-}"
  local LC_ALL=C.UTF-8
  while :; do
    IFS= read -r -s -p "$1 ($minimum caracteres min.) : " one </dev/tty; printf '\n' >/dev/tty
    IFS= read -r -s -p 'Confirmer : ' two </dev/tty; printf '\n' >/dev/tty
    [[ "$one" == "$two" ]] || { echo 'Saisies differentes.'; continue; }
    [[ ${#one} -ge $minimum ]] || { echo 'Mot de passe trop court.'; continue; }
    [[ -z "$pattern" || "$one" =~ $pattern ]] || { echo 'Caracteres non autorises.'; continue; }
    REPLY="$one"; return
  done
}
fetch(){ curl --fail --silent --show-error --location --retry 3 --proto '=https' --proto-redir '=https' --tlsv1.2 "$1" -o "$2"; }

install_radio(){
  local public_ip="${1:-}" net="${2:-}" pubkey org email
  [[ -n "$public_ip" ]] || read -r -p 'IPv4 publique du VPS : ' public_ip </dev/tty
  [[ -n "$net" ]] || read -r -p 'Reseau (10.1, 10.2 ou 10.3) : ' net </dev/tty
  [[ "$public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die 'IPv4 du VPS invalide.'
  local octet
  IFS=. read -r -a ip_parts <<< "$public_ip"
  for octet in "${ip_parts[@]}"; do (( 10#$octet <= 255 )) || die 'IPv4 du VPS invalide.'; done
  (( 10#${ip_parts[0]} > 0 && 10#${ip_parts[0]} < 224 && 10#${ip_parts[0]} != 127 )) || die 'IPv4 du VPS invalide.'
  [[ "$net" =~ ^10\.[123]$ ]] || die 'Reseau attendu : 10.1, 10.2 ou 10.3.'
  [[ ! -e "$INSTALL_ROOT" && ! -e /etc/openvpn/server.conf && ! -e /etc/openvpn/pki ]] || die 'Installation existante detectee. Refus de remplacer.'
  [[ ! -f /etc/radio-vpn-deployed ]] || die 'Deploiement deja effectue.'
  [[ "$RELEASE_TAG" =~ ^[a-zA-Z0-9._-]+$ && "$RELEASE_TAG" != radio-v1 ]] || die 'Utiliser une Release de recette, pas radio-v1.'
  [[ -z "$SOURCE_REF" || ( "$SOURCE_REF" =~ ^[a-zA-Z0-9._/-]+$ && "$SOURCE_REF" != *..* ) ]] || die 'Reference Git invalide.'
  log 'Configuration du clavier : selectionner Francais (AZERTY) dans l assistant'
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends keyboard-configuration
  dpkg-reconfigure keyboard-configuration
  require_password 'Mot de passe technicien'; local technician_pw="$REPLY"; unset REPLY
  require_password 'Mot de passe admin OpenVPN UI' 12 '^[a-zA-Z0-9._@+=,:!-]+$'; local gui_pw="$REPLY"; unset REPLY
  read -r -p 'Cle SSH PUBLIQUE ED25519 du poste administrateur (obligatoire) : ' pubkey </dev/tty
  [[ "$pubkey" =~ ^ssh-ed25519[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]] || die 'Cle ED25519 invalide.'
  read -r -p 'Organisation PKI [Radio Bonheur] : ' org </dev/tty; org="${org:-Radio Bonheur}"
  read -r -p 'Email PKI [contact@radiobonheur.com] : ' email </dev/tty; email="${email:-contact@radiobonheur.com}"
  [[ "$org" =~ ^[a-zA-Z0-9\ ._@+-]+$ ]] || die 'Organisation : lettres, chiffres, espaces et ._@+- uniquement.'
  [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+$ ]] || die 'Email invalide.'

  log 'Dependances Debian (sans compilation sur le VPS)'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends sudo openssh-server ca-certificates curl unzip tar \
    openvpn easy-rsa nftables openssl python3 oathtool qrencode iproute2 util-linux
  TMP="$(mktemp -d)"; mkdir -p "$TMP/src" "$TMP/bin"
  printf '%s\n' "$pubkey" > "$TMP/admin.pub"
  ssh-keygen -lf "$TMP/admin.pub" >/dev/null || die 'Cle publique SSH illisible.'

  log 'Release de recette : verification SHA-256 avant extraction'
  local archive='radio-openvpn-ui-linux-amd64.zip' compiled_commit source_commit
  local release_url="https://github.com/$REPO/releases/download/$RELEASE_TAG"
  fetch "$release_url/$archive" "$TMP/$archive"
  fetch "$release_url/$archive.sha256" "$TMP/$archive.sha256"
  (cd "$TMP" && sha256sum -c "$archive.sha256") || die 'SHA256 de l archive invalide.'
  unzip -q "$TMP/$archive" -d "$TMP/bin"
  for f in openvpn-ui openvpn-ui.sha256 source-commit.txt SHA256SUMS; do
    [[ -s "$TMP/bin/$f" ]] || die "Release incomplete : $f absent. Recompiler les correctifs."
  done
  (cd "$TMP/bin" && sha256sum -c SHA256SUMS && sha256sum -c openvpn-ui.sha256) || die 'Contenu de Release invalide.'
  compiled_commit="$(cat "$TMP/bin/source-commit.txt")"
  [[ "$compiled_commit" =~ ^[0-9a-f]{40}$ ]] || die 'Commit du binaire invalide.'
  source_commit="$compiled_commit"
  if [[ -n "$SOURCE_REF" ]]; then
    local encoded_ref
    encoded_ref=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$SOURCE_REF")
    fetch "https://api.github.com/repos/$REPO/commits/$encoded_ref" "$TMP/commit.json"
    source_commit=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha"])' "$TMP/commit.json")
    [[ "$source_commit" == "$compiled_commit" ]] || die 'La revision demandee ne correspond pas au binaire compile. Publier une nouvelle Release.'
  fi
  fetch "https://github.com/$REPO/archive/$source_commit.tar.gz" "$TMP/source.tgz"
  tar -xzf "$TMP/source.tgz" -C "$TMP/src" --strip-components=1
  for f in genclient.sh write-client-profile.sh generate_ca_and_server_certs.sh oath.sh remove.sh renew.sh restart.sh revoke.sh rmcert.sh secure-ssh.sh; do
    [[ -s "$TMP/src/Radio/scripts/$f" ]] || die "Script absent : $f"
  done
  for f in app.conf openvpn-server-config.tpl openvpn-client-config.tpl easyrsa-vars.tpl openvpn-ui.service nftables.conf.tpl; do
    [[ -s "$TMP/src/Radio/config/$f" ]] || die "Modele absent : $f"
  done
  for f in static views swagger; do [[ -d "$TMP/bin/$f" ]] || die "Ressources UI absentes : $f"; done

  log 'Compte technicien, sudo et preparation SSH'
  if ! id -u technicien >/dev/null 2>&1; then useradd -m -s /bin/bash technicien; fi
  usermod -aG sudo technicien
  printf 'technicien:%s\n' "$technician_pw" | chpasswd; unset technician_pw
  install -d -m 700 -o technicien -g technicien /home/technicien/.ssh
  install -m 600 -o technicien -g technicien "$TMP/admin.pub" /home/technicien/.ssh/authorized_keys
  install -d -m 755 /etc/ssh/sshd_config.d
  install -d -m 755 /run/sshd
  printf 'PubkeyAuthentication yes\nPasswordAuthentication yes\n' > /etc/ssh/sshd_config.d/00-radio.conf
  /usr/sbin/sshd -t
  systemctl enable --now ssh
  systemctl reload ssh
  install -m 700 "$TMP/src/Radio/scripts/secure-ssh.sh" /usr/local/sbin/radio-secure-ssh

  log 'Installation du runtime et generation synchronisee de la base GUI et des configurations'
  install -d -m 755 "$INSTALL_ROOT" "$INSTALL_ROOT/conf" /opt/scripts /etc/openvpn/config \
    /etc/openvpn/clients /etc/openvpn/staticclients /var/log/openvpn
  install -d -m 700 "$INSTALL_ROOT/db"
  install -m 755 "$TMP/bin/openvpn-ui" "$INSTALL_ROOT/openvpn-ui"
  cp -a "$TMP/bin/static" "$TMP/bin/views" "$TMP/bin/swagger" "$INSTALL_ROOT/"
  install -m 644 "$TMP/src/LICENSE" "$INSTALL_ROOT/LICENSE"
  sed -e "s/@PUBLIC_IP@/$public_ip/g" -e "s/@VPN_NETWORK@/$net.0.0/g" \
    -e "s/@PKI_ORG@/$org/g" -e "s/@PKI_EMAIL@/$email/g" \
    "$TMP/src/Radio/config/app.conf" > "$INSTALL_ROOT/conf/app.conf"
  for f in openvpn-server-config.tpl openvpn-client-config.tpl easyrsa-vars.tpl; do
    install -m 644 "$TMP/src/Radio/config/$f" "$INSTALL_ROOT/conf/$f"
  done
  install -m 755 "$TMP/src/Radio/scripts/"*.sh /opt/scripts/
  ln -s /usr/bin/qrencode /opt/scripts/qrencode
  install -d -m 755 /usr/share/easy-rsa/pki
  ln -s /usr/share/easy-rsa/pki /etc/openvpn/pki
  printf 'OPENVPN_ADMIN_PASSWORD=%s\n' "$gui_pw" > /etc/openvpn-ui.env
  chmod 600 /etc/openvpn-ui.env
  (cd "$INSTALL_ROOT"; OPENVPN_ADMIN_USERNAME=admin OPENVPN_ADMIN_PASSWORD="$gui_pw" ./openvpn-ui -initialize-only)
  unset gui_pw
  [[ -s "$INSTALL_ROOT/db/data.db" && -s /usr/share/easy-rsa/pki/vars && -s /etc/openvpn/server.conf && -s /etc/openvpn/config/client.conf ]] || die 'Initialisation GUI incomplete.'
  cp /usr/share/easy-rsa/pki/vars /etc/openvpn/config/easy-rsa.vars
  install -m 644 "$TMP/src/Radio/config/easyrsa-vars.tpl" /etc/openvpn/config/easy-rsa.vars.template

  log 'Initialisation de la PKI unique'
  /opt/scripts/generate_ca_and_server_certs.sh init_all
  openssl verify -CAfile /etc/openvpn/pki/ca.crt /etc/openvpn/pki/issued/server.crt
  openssl crl -in /etc/openvpn/pki/crl.pem -noout -nextupdate | python3 -c \
    'import datetime,sys; expiry=datetime.datetime.strptime(sys.stdin.read().strip().split("=",1)[1], "%b %d %H:%M:%S %Y %Z").replace(tzinfo=datetime.timezone.utc); assert expiry > datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=7), "CRL trop courte"'
  install -m 644 "$TMP/src/Radio/config/openvpn-ui.service" /etc/systemd/system/openvpn-ui.service
  install_crl_timer
  systemctl daemon-reload
  systemctl start radio-renew-crl.service
  systemctl enable --now radio-renew-crl.timer

  log 'Activation persistante du pare-feu avec retour arriere'
  activate_firewall
  systemctl enable --now openvpn@server.service
  systemctl is-active --quiet openvpn@server.service || die 'OpenVPN ne demarre pas.'
  ip -4 address show tun0 | grep -Fq "inet $net.0.1/16" || die 'Adresse tun0 incorrecte.'
  ss -lun | grep -q ':1194 ' || die 'UDP 1194 absent.'
  systemctl enable --now openvpn-ui.service
  systemctl is-active --quiet openvpn-ui.service || die 'OpenVPN UI ne demarre pas.'
  curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 --max-time 10 http://127.0.0.1:8080/login >/dev/null
  /usr/sbin/sshd -t
  systemctl is-active --quiet ssh || die 'SSH inactif.'
  systemctl stop radio-firewall-rollback.timer
  [[ ! -f /run/radio-firewall-backup/rolled-back ]] || die 'Le retour arriere du pare-feu a ete declenche.'
  FIREWALL_PENDING=false
  rm -rf -- /run/radio-firewall-backup

  # Aucun mot de passe SSH n'est desactive sans preuve d'une connexion avec la cle fournie.
  if ! /usr/local/sbin/radio-secure-ssh "${SSH_CONNECTION:-}"; then
    echo 'SSH : cle installee, mots de passe conserves tant que l acces par cle n est pas confirme.'
    echo 'Depuis une connexion technicien par cle : sudo radio-secure-ssh "$SSH_CONNECTION"'
  fi
  printf 'release_tag=%s\nrelease_source_commit=%s\npublic_ip=%s\nnetwork=%s\n' "$RELEASE_TAG" "$compiled_commit" "$public_ip" "$net" > /etc/radio-vpn-deployed
  log 'Installation terminee : OpenVPN actif, UI protegee, CRL planifiee.'
  echo "GUI depuis le VPN : http://$net.0.1:8080"
  echo "Tunnel SSH : ssh -L 8080:127.0.0.1:8080 technicien@$public_ip"
  echo 'Creer les clients avec une IPv4 fixe du /16. Aucun redirect-gateway.'
}

install_crl_timer(){
  cat > /usr/local/sbin/radio-renew-crl <<'CRL'
#!/usr/bin/env bash
set -Eeuo pipefail
export EASYRSA_BATCH=1
cd /usr/share/easy-rsa
[[ -s pki/ca.crt ]] || { echo 'CA absente' >&2; exit 1; }
./easyrsa gen-crl
chmod 644 pki/crl.pem
openssl crl -in pki/crl.pem -noout -nextupdate
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
}

activate_firewall(){
  local ports
  ports=$({ /usr/sbin/sshd -T | awk '$1=="port" {print $2}'; [[ -z "${SSH_CONNECTION:-}" ]] || awk '{print $4}' <<< "$SSH_CONNECTION"; } | sort -nu | paste -sd,)
  [[ "$ports" =~ ^[0-9]+(,[0-9]+)*$ ]] || die 'Ports SSH introuvables.'
  sed "s/@SSH_PORTS@/$ports/g" "$TMP/src/Radio/config/nftables.conf.tpl" > "$TMP/nftables.conf"
  nft -c -f "$TMP/nftables.conf"
  install -d -m 700 /run/radio-firewall-backup
  { printf 'flush ruleset\n'; nft list ruleset; } > /run/radio-firewall-backup/rules.nft
  if [[ -f /etc/nftables.conf ]]; then cp -p /etc/nftables.conf /run/radio-firewall-backup/config; fi
  if systemctl is-enabled --quiet nftables; then touch /run/radio-firewall-backup/enabled; fi
  cat > /usr/local/sbin/radio-restore-firewall <<'ROLLBACK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ -d /run/radio-firewall-backup ]] || exit 0
touch /run/radio-firewall-backup/rolled-back
systemctl stop openvpn-ui.service openvpn@server.service || true
nft -f /run/radio-firewall-backup/rules.nft
if [[ -f /run/radio-firewall-backup/config ]]; then
  cp -p /run/radio-firewall-backup/config /etc/nftables.conf
else
  rm -f /etc/nftables.conf
fi
if [[ ! -f /run/radio-firewall-backup/enabled ]]; then systemctl disable nftables; fi
systemctl stop radio-firewall-rollback.timer || true
ROLLBACK
  chmod 700 /usr/local/sbin/radio-restore-firewall
  systemd-run --quiet --unit=radio-firewall-rollback --on-active=3min /usr/local/sbin/radio-restore-firewall
  FIREWALL_PENDING=true
  install -m 600 "$TMP/nftables.conf" /etc/nftables.conf
  nft -f /etc/nftables.conf
  systemctl enable nftables
  systemctl start nftables
}

main(){
  [[ $EUID -eq 0 ]] || die 'Executer en root.'
  [[ -t 0 ]] || die 'Un terminal interactif est necessaire.'
  . /etc/os-release
  [[ $ID == debian && $VERSION_ID == 13 && $(uname -m) == x86_64 ]] || die 'Debian 13 AMD64 uniquement.'
  trap cleanup EXIT
  trap 'echo "Echec du deploiement, ligne $LINENO." >&2' ERR
  trap 'exit 1' HUP INT TERM
  case "${1:-install}" in
    install) [[ $# -eq 0 ]] || shift; install_radio "$@" ;;
    *) die "Usage : sudo bash $0 [install [IP_PUBLIQUE [10.N]]]" ;;
  esac
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
