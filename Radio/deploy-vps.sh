#!/usr/bin/env bash
# =============================================================================
# deploy-vps.sh (v2) — Déploie un serveur OpenVPN + openvpn-ui à partir du kit
#
# Cible : Debian 13 NEUVE (même architecture que le VPS de référence), en root.
# Prérequis : compte/SSH déjà en place, pare-feu cloud réglé, et SUR CE VPS :
#     /root/radio-vpn-kit.tgz  et  /root/radio-vpn-kit.tgz.sha256   (produits par make-kit.sh)
#
#   1) ./deploy-vps.sh install <IP_PUBLIQUE> <RESEAU_VPN>
#          ex. ./deploy-vps.sh install 84.1.2.3 10.1
#
#   2) GUI (via tunnel SSH) : ouvrir les 3 pages de configuration, vérifier l'IP
#      et le réseau, Save Config sur chacune, puis Initialize All (UNE seule fois).
#
#   3) ./deploy-vps.sh start
#          (contrôle la PKI, démarre OpenVPN, vérifie tun0 et l'écoute UDP 1194)
#
# Aucun mot de passe n'est contenu dans ce script ni passé en argument ou en
# variable d'environnement : il est demandé au clavier (saisie masquée, jamais
# écrit dans le journal) puis stocké uniquement dans /etc/openvpn-ui.env (root, 600).
#
# Variables optionnelles :
#   KIT=/chemin/radio-vpn-kit.tgz   (défaut : /root/radio-vpn-kit.tgz)
#   ALLOW_SAME_NET=1                (autorise le même réseau VPN que la référence)
#
# Principe : toute la préparation et TOUTES les validations se font dans un
# dossier temporaire AVANT de toucher au système. Une erreur de validation arrête
# le script sans rien avoir installé.
#
# Journal : /var/log/deploy-vps.log
# =============================================================================
set -euo pipefail

KIT="${KIT:-/root/radio-vpn-kit.tgz}"
LOG=/var/log/deploy-vps.log
PKI_FILES=(ca.crt issued/server.crt private/server.key crl.pem dh.pem ta.key)
ALLOWED_PATHS='^(opt/openvpn-ui-runtime|opt/scripts|etc/systemd/system/openvpn-ui\.service|etc/nftables\.conf|etc/openvpn/server\.conf|etc/openvpn/config|etc/radio-vpn-kit\.env)(/|$)'
STAGE=""

say()  { printf '\n==> %s\n' "$*"; }
ok()   { printf '    [OK] %s\n' "$*"; }
warn() { printf '    [ATTENTION] %s\n' "$*"; }
die()  { printf '\n[ERREUR] %s\n' "$*" >&2; exit 1; }

need_root() { [[ $EUID -eq 0 ]] || die "à lancer en root (sudo -i)"; }
cleanup()   { [[ -n $STAGE ]] && rm -rf "$STAGE"; return 0; }
trap cleanup EXIT

# Demande le mot de passe admin de la GUI au clavier (terminal uniquement :
# ni affiché, ni journalisé, ni passé en argument). Résultat dans la variable PW.
ask_password() {
  { : >/dev/tty; } 2>/dev/null \
    || die "aucun terminal : lancer le script depuis une session SSH interactive (le mot de passe se saisit au clavier)"
  local p1 p2
  while true; do
    printf '    Mot de passe admin de la GUI (12 car. min. ; lettres, chiffres et . _ @ + = , : - ; saisie masquée) : ' >/dev/tty
    read -rs p1 </dev/tty; printf '\n' >/dev/tty
    printf '    Confirmer le mot de passe : ' >/dev/tty
    read -rs p2 </dev/tty; printf '\n' >/dev/tty
    if [[ $p1 != "$p2" ]]; then printf '    Les deux saisies diffèrent, recommencer.\n' >/dev/tty; continue; fi
    if [[ ! $p1 =~ ^[A-Za-z0-9._@+=,:-]{12,}$ ]]; then printf '    Mot de passe non conforme, recommencer.\n' >/dev/tty; continue; fi
    PW="$p1"
    return 0
  done
}

# Lit UNE valeur "CLE=valeur" dans un fichier, sans jamais l'exécuter
kitval() { sed -n "s/^$1=//p" "$2" | head -n1 | tr -d '"'; }

# ---------------------------------------------------------------------------
cmd_install() {
  local ip="${1:-}" net="${2:-}"
  need_root
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "IP publique invalide : '$ip'"
  [[ $net =~ ^10\.[0-9]{1,3}$ ]] || die "réseau VPN invalide : '$net' (attendu : 10.N, ex. 10.1)"
  exec > >(tee -a "$LOG") 2>&1

  say "Contrôles préalables (le serveur doit être NEUF)"
  [[ ! -e /opt/openvpn-ui-runtime ]]  || die "/opt/openvpn-ui-runtime existe déjà : serveur non vierge"
  [[ ! -e /opt/scripts ]]             || die "/opt/scripts existe déjà : serveur non vierge"
  [[ ! -e /etc/openvpn/pki ]]         || die "/etc/openvpn/pki existe déjà : serveur non vierge"
  [[ ! -e /etc/openvpn/server.conf ]] || die "/etc/openvpn/server.conf existe déjà : serveur non vierge"
  [[ -z "$(ls -A /usr/share/easy-rsa/pki 2>/dev/null || true)" ]] \
    || die "/usr/share/easy-rsa/pki n'est pas vide : serveur non vierge"
  grep -q '^VERSION_ID="13"' /etc/os-release \
    || die "ce n'est pas Debian 13 : la procédure n'est validée que sur Debian 13"
  ok "serveur vierge, Debian 13"

  # Mot de passe admin de la GUI : saisi et validé avant toute installation
  say "Mot de passe administrateur de la GUI (à saisir maintenant)"
  local pw
  ask_password
  pw="$PW"; unset PW
  ok "mot de passe saisi et confirmé"

  say "Intégrité et contenu du kit"
  [[ -f $KIT ]] || die "kit introuvable : $KIT"
  local shafile="${KIT}.sha256"
  [[ -f $shafile ]] || die "empreinte absente : $shafile (copier le .sha256 avec le kit)"
  ( cd "$(dirname "$KIT")" && sha256sum -c "$(basename "$shafile")" >/dev/null 2>&1 ) \
    || die "empreinte SHA-256 incorrecte : kit altéré ou incomplet"
  ok "SHA-256 conforme"

  local listing bad
  listing="$(tar -tzf "$KIT")" || die "kit illisible"
  if printf '%s\n' "$listing" | grep -qE '(^|/)\.\.(/|$)|^/'; then
    die "le kit contient des chemins absolus ou '..' : refusé"
  fi
  bad="$(printf '%s\n' "$listing" | grep -vE "$ALLOWED_PATHS" || true)"
  if [[ -n $bad ]]; then
    printf '%s\n' "$bad" | head -n 10
    die "le kit contient des chemins non autorisés (ci-dessus) : refusé"
  fi
  ok "chemins du kit conformes"

  STAGE="$(mktemp -d)"
  tar -xzf "$KIT" -C "$STAGE"

  # Métadonnées : lues et validées une par une, JAMAIS exécutées
  local envf="$STAGE/etc/radio-vpn-kit.env" REF_IP REF_NET COMMIT ARCH BUILT
  [[ -f $envf ]] || die "kit invalide : etc/radio-vpn-kit.env absent"
  REF_IP="$(kitval REF_IP "$envf")"
  REF_NET="$(kitval REF_NET "$envf")"
  COMMIT="$(kitval COMMIT "$envf")"
  ARCH="$(kitval ARCH "$envf")"
  BUILT="$(kitval BUILT "$envf")"
  [[ $REF_IP  =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]   || die "kit : REF_IP invalide"
  [[ $REF_NET =~ ^10\.[0-9]{1,3}$ ]]                || die "kit : REF_NET invalide"
  [[ $COMMIT  =~ ^([0-9a-f]{40}|inconnu)$ ]]        || die "kit : COMMIT invalide"
  [[ $ARCH    =~ ^[A-Za-z0-9_]+$ ]]                 || die "kit : ARCH invalide"
  BUILT="${BUILT//[^0-9T:+-]/}"
  [[ $ARCH == "$(uname -m)" ]] || die "architecture différente : kit=$ARCH, ce serveur=$(uname -m)"
  ok "kit : commit=$COMMIT, construit le ${BUILT:-?}"

  if [[ $net == "$REF_NET" && ${ALLOW_SAME_NET:-0} != 1 ]]; then
    die "réseau $net identique à celui du VPS de référence : choisir un autre réseau (ou ALLOW_SAME_NET=1 en connaissance de cause)"
  fi

  say "Adaptation dans le dossier temporaire (IP publique $ip, réseau VPN $net.0.0/16)"
  local esc_ip="${REF_IP//./\\.}" esc_refnet="${REF_NET//./\\.}" esc_net="${net//./\\.}"
  local cc="$STAGE/etc/openvpn/config/client.conf" sc="$STAGE/etc/openvpn/server.conf"
  [[ -f $cc && -f $sc ]] || die "kit incomplet : client.conf ou server.conf absent"
  sed -i "s/${esc_ip}/${ip}/g" "$cc"
  sed -i -E "s/^(server[[:space:]]+)${esc_refnet}\.0\.0([[:space:]])/\1${net}.0.0\2/" "$sc"
  grep -q "^remote[[:space:]]\+${ip}[[:space:]]" "$cc" \
    || die "client.conf : la ligne 'remote' n'a pas été mise à jour"
  grep -qE "^server[[:space:]]+${esc_net}\.0\.0[[:space:]]" "$sc" \
    || die "server.conf : la ligne 'server' n'a pas été mise à jour"

  # Plus aucune trace (hors commentaires) de l'ancienne IP ni de l'ancien réseau
  local stale
  stale="$(grep -nE "${esc_ip}" "$cc" "$sc" | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
  [[ -z $stale ]] || { printf '%s\n' "$stale"; die "l'ancienne IP $REF_IP subsiste (ci-dessus) : corriger le kit"; }
  stale="$(grep -nE "${esc_refnet}\.[0-9]" "$cc" "$sc" | grep -vE ':[0-9]+:[[:space:]]*#' || true)"
  [[ -z $stale ]] || { printf '%s\n' "$stale"; die "l'ancien réseau $REF_NET subsiste (ci-dessus) : corriger le kit"; }
  ok "client.conf : remote $ip ; server.conf : server $net.0.0 ; aucune trace de l'ancien VPS"

  # --- À partir d'ici seulement, le système est modifié -----------------------
  say "Paquets Debian (mise à jour + outils nécessaires, sans Go ni compilateur)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get full-upgrade -y
  apt-get install -y openvpn easy-rsa nftables python3 curl jq oathtool sed \
    ca-certificates tar openssl iproute2 util-linux coreutils
  ok "paquets installés : $(openvpn --version | head -1)"

  say "Mise en place des fichiers du kit"
  install -d -m 755 /etc/openvpn/config /etc/openvpn/clients /etc/openvpn/staticclients \
                    /var/log/openvpn /usr/share/easy-rsa/pki
  cp -a "$STAGE/opt/openvpn-ui-runtime" /opt/
  cp -a "$STAGE/opt/scripts" /opt/
  cp -a "$STAGE/etc/openvpn/config/." /etc/openvpn/config/
  install -m 644 "$STAGE/etc/openvpn/server.conf" /etc/openvpn/server.conf
  install -m 644 "$STAGE/etc/systemd/system/openvpn-ui.service" /etc/systemd/system/openvpn-ui.service
  install -m 644 "$STAGE/etc/nftables.conf" /etc/nftables.conf
  install -m 644 "$envf" /etc/radio-vpn-kit.env
  install -d -m 700 /opt/openvpn-ui-runtime/db
  chmod 755 /opt/openvpn-ui-runtime/openvpn-ui /opt/scripts/qrencode
  chmod 755 /opt/scripts/*.sh
  ln -s /usr/share/easy-rsa/pki /etc/openvpn/pki
  [[ "$(readlink /etc/openvpn/pki)" == /usr/share/easy-rsa/pki ]] || die "lien PKI incorrect"
  ok "/etc/openvpn/pki -> /usr/share/easy-rsa/pki"

  say "Enregistrement du mot de passe administrateur"
  install -m 600 /dev/null /etc/openvpn-ui.env
  printf 'OPENVPN_ADMIN_PASSWORD=%s\n' "$pw" > /etc/openvpn-ui.env
  chmod 600 /etc/openvpn-ui.env
  ok "écrit dans /etc/openvpn-ui.env (droits 600)"

  say "Service openvpn-ui"
  systemctl daemon-reload
  systemctl enable --now openvpn-ui
  sleep 3
  if ! systemctl is-active --quiet openvpn-ui; then
    journalctl -u openvpn-ui -n 40 --no-pager || true
    die "openvpn-ui n'a pas démarré (journal ci-dessus)"
  fi
  ss -lnt | grep -q ':8080 ' || die "openvpn-ui ne répond pas sur le port 8080"
  ok "openvpn-ui actif, écoute sur 8080"

  echo "ip=$ip net=$net commit=$COMMIT date=$(date -Is)" > /etc/radio-vpn-deployed

  # nftables en DERNIER : si une règle coupait la session SSH, tout le reste est déjà fait
  say "Pare-feu nftables (avec retour arrière automatique)"
  nft -c -f /etc/nftables.conf || die "nftables.conf invalide : pare-feu NON appliqué"
  if [[ ! -t 0 ]]; then
    warn "pas de terminal interactif : nftables NON activé. Une fois connecté : systemctl enable --now nftables"
  else
    # Si rien n'est confirmé sous 3 minutes : règles vidées ET service désactivé (pas de réapplication au reboot)
    systemd-run --quiet --on-active=180 --unit=nft-rollback \
      /bin/sh -c 'nft flush ruleset; systemctl disable nftables' \
      || die "impossible d'armer le retour arrière : nftables NON activé"
    systemctl enable --now nftables
    local answer=""
    printf '\n    Ouvrez MAINTENANT une 2e session SSH vers ce VPS.\n    Si elle fonctionne, tapez OK ici (3 minutes maximum) : '
    read -r -t 170 answer || answer=""
    if [[ ${answer^^} == OK ]]; then
      systemctl stop nft-rollback.timer
      ok "nftables confirmé : actif, et réappliqué au démarrage"
    else
      warn "pas de confirmation : le pare-feu local va être DÉSACTIVÉ automatiquement (retour arrière)."
      warn "Seul le pare-feu cloud protège alors ce VPS. Pour réessayer : systemctl enable --now nftables"
    fi
  fi

  cat <<EOF

==> INSTALLATION TERMINÉE. Suite (ne PAS démarrer OpenVPN avant Initialize All) :

  1. Depuis votre poste, tunnel SSH vers la GUI :
       ssh -i <cle_privee> -N -L 8080:127.0.0.1:8080 technicien@$ip
     puis ouvrir http://127.0.0.1:8080  (login : admin)
  2. Configuration -> Easy RSA vars, OpenVPN Server, OpenVPN Client :
     vérifier l'IP ($ip) et le réseau ($net.0.0), puis Save Config sur chaque page.
  3. Configuration -> Maintenance -> INITIALIZE ALL (UNE seule fois, attendre la fin).
  4. Revenir ici :  ./deploy-vps.sh start
EOF
}

# ---------------------------------------------------------------------------
cmd_start() {
  need_root
  exec > >(tee -a "$LOG") 2>&1

  say "Contrôle de la PKI (après Initialize All)"
  [[ -L /etc/openvpn/pki ]] || die "/etc/openvpn/pki n'est pas un lien symbolique"
  local f missing=0
  for f in "${PKI_FILES[@]}"; do
    if [[ -s /etc/openvpn/pki/$f ]]; then ok "$f"; else warn "manquant : $f"; missing=1; fi
  done
  [[ $missing -eq 0 ]] || die "PKI incomplète. Lire : journalctl -u openvpn-ui -n 80 --no-pager. Ne PAS relancer Initialize All si des certificats existent."

  # OpenVPN abandonne les droits root (nobody) puis relit la CRL : elle doit être lisible
  setpriv --reuid=nobody --regid=nogroup --clear-groups head -c1 /etc/openvpn/pki/crl.pem >/dev/null \
    || die "crl.pem illisible par l'utilisateur 'nobody' (droits du fichier ou des dossiers parents)"
  ok "crl.pem lisible par nobody"

  if compgen -G '/etc/openvpn/staticclients/*' >/dev/null; then
    for f in /etc/openvpn/staticclients/*; do
      if setpriv --reuid=nobody --regid=nogroup --clear-groups head -c1 "$f" >/dev/null 2>&1; then
        ok "CCD lisible : $(basename "$f")"
      else
        die "CCD illisible par nobody : $f (chmod 644 le fichier, 755 le dossier)"
      fi
    done
  fi

  say "Démarrage d'OpenVPN"
  local srv_net srv_ip
  srv_net="$(awk '/^server[[:space:]]/{print $2; exit}' /etc/openvpn/server.conf)"
  [[ -n $srv_net ]] || die "ligne 'server' introuvable dans /etc/openvpn/server.conf"
  srv_ip="${srv_net%.*}.1"

  systemctl enable --now openvpn@server
  for _ in $(seq 1 20); do
    ip -4 addr show tun0 2>/dev/null | grep -q "inet ${srv_ip}/" && break
    sleep 1
  done
  if ! ip -4 addr show tun0 2>/dev/null | grep -q "inet ${srv_ip}/"; then
    tail -n 40 /var/log/openvpn/openvpn.log 2>/dev/null || true
    die "tun0 n'a pas l'adresse attendue ${srv_ip} (journal ci-dessus)"
  fi
  ok "tun0 = ${srv_ip}"
  ss -lun | grep -q ':1194 ' || die "OpenVPN n'écoute pas en UDP 1194"
  ok "UDP 1194 en écoute"
  systemctl is-active --quiet openvpn@server && ok "openvpn@server actif"
  systemctl is-enabled --quiet openvpn-ui openvpn@server && ok "openvpn-ui et openvpn@server activés au démarrage"
  if systemctl is-active --quiet nftables && systemctl is-enabled --quiet nftables; then
    ok "nftables actif et activé au démarrage"
  else
    warn "nftables INACTIF ou non activé : seul le pare-feu cloud protège ce VPS (systemctl enable --now nftables)"
  fi

  say "Échéance de la CRL (OpenVPN refuse TOUS les clients si elle expire)"
  openssl crl -in /etc/openvpn/pki/crl.pem -noout -nextupdate
  warn "noter cette date dans l'agenda : la régénération n'est PAS automatique"

  cat <<EOF

==> OPENVPN DÉMARRÉ. Suite :
  1. GUI -> Certificates -> Create Certificate (un seul clic), IP fixe.
  2. Vérifier le profil .ovpn et le fichier CCD (/etc/openvpn/staticclients/<CN>).
  3. Tester depuis un client, puis redémarrer le VPS (reboot) et re-tester.
  4. Sauvegarder HORS du VPS : PKI, /etc/openvpn, /opt/openvpn-ui-runtime, /etc/openvpn-ui.env.
EOF
}

# ---------------------------------------------------------------------------
case "${1:-}" in
  install) shift; cmd_install "$@" ;;
  start)   shift; cmd_start ;;
  *) sed -n '2,32p' "$0"; exit 1 ;;
esac
