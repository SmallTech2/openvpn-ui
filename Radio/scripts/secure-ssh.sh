#!/usr/bin/env bash
# A lancer depuis la connexion par cle validee : sudo radio-secure-ssh "$SSH_CONNECTION"
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Executer avec sudo.' >&2; exit 1; }
CONNECTION="${1:-${SSH_CONNECTION:-}}"
read -r CLIENT_IP CLIENT_PORT SERVER_IP SERVER_PORT <<< "$CONNECTION"
[[ -n "${CLIENT_IP:-}" && "${CLIENT_PORT:-}" =~ ^[0-9]+$ && "${SERVER_PORT:-}" =~ ^[0-9]+$ ]] || { echo 'Connexion SSH courante non identifiable.' >&2; exit 1; }
LOGIN_USER="${SUDO_USER:-root}"
FINGERPRINT=$(ssh-keygen -lf /home/technicien/.ssh/authorized_keys | awk 'NR==1 {print $2}')
# Le journal doit prouver l'usage de CETTE cle sur CETTE connexion, pas une simple confirmation.
if ! journalctl -b -u ssh --no-pager -o cat | grep -F "Accepted publickey for $LOGIN_USER from $CLIENT_IP port $CLIENT_PORT " | grep -Fq "ED25519 $FINGERPRINT"; then
  echo 'Aucune preuve de connexion avec cette cle : mots de passe inchanges.' >&2
  exit 1
fi
CONFIG=/etc/ssh/sshd_config.d/00-radio.conf
BACKUP=$(mktemp)
cp -p "$CONFIG" "$BACKUP"
restore(){ cp -p "$BACKUP" "$CONFIG"; /usr/sbin/sshd -t; systemctl reload ssh; }
trap 'rm -f -- "$BACKUP"' EXIT
printf 'PubkeyAuthentication yes\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' > "$CONFIG"
if ! /usr/sbin/sshd -t; then restore; exit 1; fi
EFFECTIVE=$(/usr/sbin/sshd -T -C "user=technicien,addr=$CLIENT_IP,host=$CLIENT_IP")
if ! grep -qx 'pubkeyauthentication yes' <<< "$EFFECTIVE" || ! grep -qx 'passwordauthentication no' <<< "$EFFECTIVE" || ! grep -qx 'kbdinteractiveauthentication no' <<< "$EFFECTIVE"; then
  echo 'Une autre regle SSH contredit la configuration : restauration.' >&2
  restore; exit 1
fi
if ! systemctl reload ssh; then restore; exit 1; fi
echo 'Acces par cle confirme ; authentification SSH par mot de passe desactivee.'
