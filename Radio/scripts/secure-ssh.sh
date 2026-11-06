#!/usr/bin/env bash
# Depuis une session SSH par cle : sudo /usr/local/bin/radio-secure-ssh "$SSH_CONNECTION"
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Executer avec sudo.' >&2; exit 1; }
LOGIN_USER="${SUDO_USER:-}"
[[ "$LOGIN_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$LOGIN_USER" != root ]] || { echo 'Lancer depuis la session du compte administrateur, avec sudo.' >&2; exit 1; }
CONNECTION="${1:-${SSH_CONNECTION:-}}"
read -r CLIENT_IP CLIENT_PORT SERVER_IP SERVER_PORT EXTRA <<< "$CONNECTION"
[[ -n "$CLIENT_IP" && -n "$SERVER_IP" && -z "$EXTRA" && "$CLIENT_PORT" =~ ^[0-9]+$ && "$SERVER_PORT" =~ ^[0-9]+$ ]] || { echo 'Connexion SSH non identifiable.' >&2; exit 1; }
ACCOUNT=$(getent passwd "$LOGIN_USER")
IFS=: read -r _ _ _ _ _ USER_HOME _ <<< "$ACCOUNT"
[[ -n "$USER_HOME" ]] || { echo 'Repertoire du compte introuvable.' >&2; exit 1; }
FINGERPRINT=$(ssh-keygen -lf "$USER_HOME/.ssh/authorized_keys" | awk 'NR==1 {print $2}')
[[ -n "$FINGERPRINT" ]] || exit 1
AUTH_LOG=$(journalctl -b -u ssh --no-pager -o cat)
# Les deux grep consomment toute leur entree : pas de faux echec SIGPIPE avec pipefail.
if ! grep -F "Accepted publickey for $LOGIN_USER from $CLIENT_IP port $CLIENT_PORT " <<< "$AUTH_LOG" | grep -F "ED25519 $FINGERPRINT" >/dev/null; then
  echo 'Aucune preuve de connexion avec cette cle : configuration inchangee.' >&2
  exit 1
fi
CONFIG=/etc/ssh/sshd_config.d/00-radio.conf
BACKUP=$(mktemp)
cp -p "$CONFIG" "$BACKUP"
HARDENED=false
cleanup(){
  local status=$?
  if ! $HARDENED; then
    echo 'Echec du durcissement : restauration de la configuration SSH precedente.' >&2
    if ! { cp -p "$BACKUP" "$CONFIG" && /usr/sbin/sshd -t && systemctl reload ssh; }; then
      echo 'Restauration SSH a verifier depuis la session conservee.' >&2
    fi
  fi
  rm -f -- "$BACKUP"
  return "$status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
printf 'PubkeyAuthentication yes\nAuthenticationMethods publickey\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' > "$CONFIG"
/usr/sbin/sshd -t
DEFAULT_EFFECTIVE=$(/usr/sbin/sshd -T)
EFFECTIVE=$(/usr/sbin/sshd -T -C "user=$LOGIN_USER,addr=$CLIENT_IP,host=$CLIENT_IP,laddr=$SERVER_IP,lport=$SERVER_PORT")
for setting in 'pubkeyauthentication yes' 'authenticationmethods publickey' 'passwordauthentication no' 'kbdinteractiveauthentication no'; do
  if ! grep -qx "$setting" <<< "$DEFAULT_EFFECTIVE" || ! grep -qx "$setting" <<< "$EFFECTIVE"; then
    echo "Configuration SSH effective inattendue : $setting" >&2
    exit 1
  fi
done
systemctl reload ssh
HARDENED=true
echo 'Acces par cle prouve ; SSH limite aux cles, mots de passe et clavier interactif desactives.'
