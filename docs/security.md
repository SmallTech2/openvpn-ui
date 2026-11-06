# Sécurité

Utilisez la référence publiée indiquée dans le [README principal](../README.md#version-stable-et-démarrage-rapide).
Les options exactes et les étapes de validation sont celles de l'installateur téléchargé ;
une fonction présente sur une branche de développement n'est pas automatiquement disponible
avec la référence stable.

## Compte administrateur et SSH

Utilisez le compte Linux créé par le script, indiqué dans le README principal ou dans
le récapitulatif de l'installation. Si le script propose de choisir ce nom, respectez
sa validation et conservez la valeur choisie pour les commandes SSH et sudo.
Le compte dispose d'un répertoire personnel, de Bash, de sudo avec mot de passe
et de la clé publique fournie. Ne copiez jamais votre clé privée sur le serveur.

## Vérifier l'accès par clé

Gardez la session d'installation ouverte. Depuis un autre terminal de votre poste,
ouvrez une nouvelle connexion avec le compte créé et la clé fournie :

```sh
ssh -o ControlMaster=no -o ControlPath=none -o PreferredAuthentications=publickey \
  -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
  UTILISATEUR_LINUX@IP_PUBLIQUE_DU_SERVEUR
```

Ajoutez `-p PORT_SSH` si nécessaire et `-i CHEMIN_CLE_PRIVEE` si la clé n'est pas sélectionnée
automatiquement. Une demande de phrase secrète locale pour ouvrir la clé privée ne constitue
pas une authentification SSH par mot de passe.

Ne désactivez jamais les mots de passe avant la réussite de cette connexion par clé.
Si l'installateur demande les valeurs de `echo "$SSH_CONNECTION"` dans cette nouvelle
session, transmettez-les à sa demande et gardez les deux sessions ouvertes.

## Vérifier le durcissement effectif

Ne vous fiez pas uniquement au contenu d'un fichier : les inclusions et les règles
`Match` peuvent changer la configuration effective. Dans la session SSH concernée :

```sh
sudo /usr/sbin/sshd -t
read -r CLIENT_IP CLIENT_PORT SERVER_IP SERVER_PORT <<< "$SSH_CONNECTION"
sudo /usr/sbin/sshd -T -C "user=$(id -un),addr=$CLIENT_IP,host=$CLIENT_IP,laddr=$SERVER_IP,lport=$SERVER_PORT" \
  | grep -E '^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|authenticationmethods) '
```

Le contrôle doit confirmer au minimum `pubkeyauthentication yes`,
`passwordauthentication no` et `kbdinteractiveauthentication no`.
Lorsque `AuthenticationMethods publickey` est configuré, vérifiez également
`authenticationmethods publickey`.

Le helper de durcissement peut être fourni par l'installateur. Utilisez uniquement la
commande effectivement installée et son chemin indiqué dans la documentation de cette
référence ; ne récupérez pas un helper non validé depuis une branche de développement
pour compléter une installation publiée.
Un helper doit vérifier la preuve d'accès par clé avant de modifier la configuration,
contrôler les valeurs effectives et restaurer la configuration précédente en cas d'échec.
Un contrôle manquant ou en échec ne constitue pas un durcissement réussi.

Gardez les sessions existantes ouvertes et vérifiez une nouvelle connexion par clé
après tout rechargement de SSH avant de les fermer.

## Protection réseau et retour arrière

L'UI dépend de `nftables.service`. Le pare-feu autorise SSH sur les ports effectifs,
UDP 1194, loopback, ICMP et TCP 8080 uniquement depuis `tun0`.

A l'installation, un retour arrière systemd est armé pour trois minutes, avec retour
immédiat sur erreur. Il restaure les règles précédentes et arrête VPN/UI. Il n'est annulé
qu'après les contrôles locaux des services, de l'adresse CIDR de `tun0`, de l'UDP et du HTTP.
Vérifiez une nouvelle connexion SSH depuis votre poste avant de fermer la session
utilisée pour l'installation ou une intervention réseau.


L'accès à l'interface Web et le tunnel SSH sont décrits dans le
[guide d'administration](administration.md#accès-à-openvpn-ui).
