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
et de la clé publique ED25519 fournie. L’administration SSH s’effectue avec cette clé.
Ne copiez jamais votre clé privée sur le serveur.

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

Ne désactivez jamais les mots de passe avant la réussite de cette nouvelle connexion par clé.
Après validation de cette preuve, le durcissement SSH désactive l’authentification par mot
de passe et par clavier interactif, tout en conservant l’accès par clé ED25519.
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

## Filtrage entrant avec nftables

Le filtrage entrant des services du VPS utilise une politique de refus par défaut
(`input`, `policy drop`). Dans la configuration standard avec SSH sur son port habituel,
**seuls deux ports acceptent de nouvelles connexions depuis Internet** :

| Port entrant public | Usage |
| --- | --- |
| **TCP 22** | Administration SSH par clé ED25519 |
| **UDP 1194** | Connexions des clients OpenVPN |

Les autres ports entrants depuis Internet sont bloqués par défaut. Les exceptions
nécessaires au fonctionnement réseau comprennent ICMP et ICMPv6. Le pare-feu accepte
également le trafic local de loopback et les paquets des connexions déjà établies ou associées.

Si SSH est volontairement configuré sur un autre port, l'installateur conserve les ports
SSH effectifs pour éviter une perte d'accès ; il ne les remplace pas arbitrairement par 22.
Le pare-feu de l'hébergeur doit autoriser le port SSH réellement utilisé et UDP 1194.

OpenVPN UI écoute sur **TCP 8080**, mais ce port **n'est pas directement accessible
depuis Internet**. Son accès est permis localement sur le VPS ou depuis l'interface VPN
`tun0`. Il n'est pas nécessaire d'ouvrir 8080, ni le port local du tunnel, dans le pare-feu public.
Le management OpenVPN reste local sur `127.0.0.1:2080`.

Cette politique décrit l'accès aux services du VPS, dans la chaîne `input`.
Les vérifications réelles ont confirmé SSH par clé, UDP 1194, le blocage public de TCP 8080,
les deux accès à l'interface, le ping et le refus par défaut des autres ports entrants.

## Routage du noyau et communication interclients

Dans la configuration vérifiée, le routage IP du noyau est désactivé :

```ini
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
```

La chaîne nftables `forward` conserve sa politique `accept`. Elle n'assure donc pas,
à elle seule, un refus des transferts : c'est la désactivation du routage du noyau qui
empêche ce serveur de servir de routeur IP entre réseaux dans cette configuration.
La communication entre clients VPN utilise la directive OpenVPN `client-to-client`.
Elle ne nécessite pas d'activer le routage IP du noyau pour cet usage.

Ces paramètres sont des valeurs constatées, pas des réglages imposés par l'installateur.
Vérifiez-les sur chaque nouvelle image serveur :

```sh
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
```

Les règles sont conservées pour cet usage précis : elles ne constituent pas un pare-feu
universel pour tous les usages. L'ajout d'un rôle de routeur, d'un accès à d'autres réseaux
ou l'activation du forwarding impose une analyse distincte du routage et du filtrage.

## Accès à OpenVPN UI par tunnel SSH

Cette méthode ne nécessite **aucune connexion OpenVPN** : seule une connexion SSH
à l'IPv4 publique du VPS est nécessaire. Depuis votre poste, remplacez le chemin de clé,
le nom d'utilisateur et l'adresse publique dans cet exemple générique :

```sh
ssh -N -T -i "/chemin/vers/cle_privee" \
  -L 127.0.0.1:8083:127.0.0.1:8080 \
  utilisateur@IP_PUBLIQUE_DU_VPS
```

Ajoutez `-p PORT_SSH` si le serveur n'utilise pas le port SSH 22. Une fois le tunnel établi,
ouvrez [http://127.0.0.1:8083/](http://127.0.0.1:8083/) dans le navigateur de ce même poste.
Le port **8083 est local au poste** ; SSH transmet la connexion vers `127.0.0.1:8080`
sur le VPS. Il n'expose pas l'interface Web sur l'adresse publique du serveur.

**Le tunnel SSH doit rester actif pendant toute la durée de l'administration.**
Cette méthode fonctionne même si le service OpenVPN est arrêté, à condition que le VPS,
le service SSH et OpenVPN UI fonctionnent et que la protection nftables soit conservée.
L'interface dépend de nftables, pas du service OpenVPN.

## Accès à OpenVPN UI depuis le VPN

Avec une **connexion VPN active**, un client peut accéder directement à l'interface Web
à l'adresse VPN privée du serveur, sur TCP 8080.

Exemple générique pour le réseau `10.3.0.0/16`, dont la première adresse utilisable est
celle du serveur : [http://10.3.0.1:8080/](http://10.3.0.1:8080/).
Adaptez l'adresse au réseau effectivement choisi lors du déploiement.

Cet accès nécessite que le service OpenVPN fonctionne et que le client soit connecté au VPN.
Sans VPN actif, utilisez le tunnel SSH décrit ci-dessus.

## Protection pendant l'installation

L'interface dépend de `nftables.service`. Ne la démarrez pas sans la protection du pare-feu.
À l'installation, un retour arrière systemd est armé pour trois minutes, avec retour
immédiat sur erreur. Il restaure les règles précédentes et arrête VPN/UI. Il n'est annulé
qu'après les contrôles locaux des services, de l'adresse CIDR de `tun0`, de l'UDP et du HTTP.
Vérifiez une nouvelle connexion SSH depuis votre poste avant de fermer la session
utilisée pour l'installation ou une intervention réseau.
