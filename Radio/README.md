# Guide d'installation et d'utilisation

Ce guide décrit le déploiement natif d'OpenVPN et d'OpenVPN UI sur Debian 13,
puis l'administration courante des clients. La version stable est
[radio-v1](https://github.com/SmallTech2/openvpn-ui/releases/tag/radio-v1).
Les exemples de réseau et d'adresses ci-dessous sont fictifs et doivent être adaptés
à votre installation. Le [périmètre validé](RELEASE-radio-v1.md) couvre également
la révocation et le renouvellement de la CRL.

## Prérequis

- VPS vierge Debian 13, architecture x86_64/AMD64, systemd et droits root/sudo.
- Session SSH interactive, commande `ip` (paquet `iproute2`) et `curl` pour le téléchargement.
- IPv4 publique fixe, accès HTTPS sortant aux miroirs Debian et à GitHub.
- Clé SSH **publique ED25519** du poste administrateur. Ne pas fournir la clé privée.
- Autoriser le port SSH utilisé et UDP 1194 dans le pare-feu de l'hébergeur.
  Ne pas ouvrir TCP 8080 sur Internet.
- Choisir un sous-réseau privé qui ne chevauche pas les réseaux des clients et du VPS.

## Installation depuis la version figée

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/radio-v1/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh
```

Pour utiliser le **choix du compte Linux et la validation SSH obligatoire** prévus pour
la future `radio-v2`, téléchargez plutôt le script de `main` :

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/main/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh
```

Cette évolution concerne les nouvelles installations depuis `main`. Le tag `radio-v1`
reste figé et crée toujours le compte `technicien`. Le parcours corrigé doit encore être
validé sur Debian 13 vierge avant publication de `radio-v2`. Aucun compte existant n'est renommé.

Au premier lancement, une confirmation précède `apt-get update`, `apt-get full-upgrade`
(en conservant les fichiers de configuration locaux) et `apt-get autoremove --purge`.
Le VPS redémarre ensuite. Après reconnexion SSH, relancer dans le même répertoire :

```sh
sudo bash deploy-vps.sh
```

L'état `/var/lib/radio-vpn/debian-upgrade-boot-id` est enregistré uniquement après
réussite des commandes APT. Le script vérifie le changement de démarrage et ne refait
pas la mise à niveau. Il ne reprend pas automatiquement et ne stocke aucun mot de passe
pour traverser le redémarrage.

Le script propose l'IPv4 publique détectée, modifiable, puis demande :

- Réseau VPN privé CIDR, par exemple `10.77.0.0/16` ou `192.168.42.0/24`.
- Avec le script de `main`, nom du compte administrateur Linux à créer (`technicien` proposé par défaut).
- Clé publique SSH, organisation et email de la PKI ; remplacez les valeurs proposées par celles de votre organisation.
- Après confirmation et configuration interactive de la disposition du clavier :
  mots de passe du compte Linux choisi et de l'administrateur OpenVPN UI.

Les deux mots de passe suivent la même règle : huit caractères minimum, aucune limite
maximale ajoutée par le script, espaces, accents et symboles acceptés sur une ligne,
saisie masquée et confirmation. Ils ne sont pas affichés dans le récapitulatif.
Une seconde confirmation précède l'installation VPN.
Avec le script de `main`, une validation obligatoire dans une seconde session SSH
intervient ensuite, après création du compte et avant la configuration du VPN : voir ci-dessous.

Les réseaux RFC1918 sont acceptés de `/16` à `/29`, limites de la directive serveur OpenVPN
avec `tun`. Une adresse d'hôte à la place de l'adresse réseau et les chevauchements
avec les routes présentes sur le VPS sont refusés. Les conflits avec les futurs réseaux
clients restent à vérifier par l'administrateur. Le serveur utilise toujours **réseau + 1** :
`10.77.0.0/16` donne `10.77.0.1/16`, `192.168.42.0/24` donne `192.168.42.1/24`.

Le script refuse de remplacer une installation ou une CA existante. Il télécharge le
paquet de la Release `radio-v1`, vérifie son SHA-256 puis les empreintes internes et
utilise les sources de déploiement du commit inscrit dans ce paquet. Il n'utilise ni
`main` ni la dernière version implicite d'une dépendance Go.

## Compte administrateur Linux et SSH

Le script de `main` demande le nom du compte Linux ; appuyez sur Entrée pour conserver
`technicien`. Le nom doit contenir de 1 à 32 caractères : lettres minuscules, chiffres,
`_` ou `-`, avec une lettre ou `_` en premier. Un nom correspondant déjà à un utilisateur
ou à un groupe est refusé pour éviter de modifier un compte existant.

Dans les exemples SSH ci-dessous, remplacez `UTILISATEUR_LINUX` par le nom choisi.
Avec le script stable `radio-v1`, ce nom reste `technicien`.
Le compte dispose d'un répertoire personnel, de Bash, de sudo avec mot de passe
et de la clé fournie. La configuration SSH est validée avant rechargement.

### Validation obligatoire avec le script de main

Le script ne force plus `PasswordAuthentication yes` pendant la préparation :
il conserve le réglage existant tant que l'accès par clé n'est pas prouvé.
Il installe et vérifie la commande `/usr/local/bin/radio-secure-ssh`, puis attend :

1. Gardez la session d'installation ouverte. Depuis un **autre terminal de votre poste**,
   utilisez la commande SSH affichée par le script pour vous connecter avec le compte créé.
   Elle impose une nouvelle authentification par clé, sans réutiliser une session multiplexée
   ni accepter de mot de passe SSH. Ajoutez `-i CHEMIN_CLE_PRIVEE` si nécessaire.
2. Dans cette nouvelle session, exécutez `echo "$SSH_CONNECTION"` et gardez-la ouverte.
3. Copiez les quatre valeurs affichées dans la demande de l'installateur.

L'installateur vérifie dans le journal du démarrage courant une authentification
`publickey` pour **ce compte, cette connexion et l'empreinte de la clé installée**.
Une simple confirmation ou une connexion par mot de passe ne suffit pas.
Sans preuve, aucun mot de passe n'est désactivé et l'installation ne continue pas.

Après cette preuve, le helper impose les valeurs suivantes et les contrôle avec
`sshd -t`, puis `sshd -T`, globalement et dans le contexte complet de la connexion
(compte, IP source, IP locale et port local), y compris les règles `Match` applicables :

```text
pubkeyauthentication yes
authenticationmethods publickey
passwordauthentication no
kbdinteractiveauthentication no
```

Seul un rechargement de `ssh` est demandé ; les sessions ouvertes sont conservées.
Une erreur de syntaxe, de configuration effective ou de rechargement provoque la restauration
du fichier précédent et une nouvelle tentative de validation. L'installateur ne déclare
pas l'installation terminée sans réussite de cette étape.
Vérifiez une nouvelle connexion après durcissement avant de fermer les sessions conservées.

La commande reste disponible pour un contrôle ou un nouveau durcissement ultérieur,
depuis la session par clé du compte administrateur :

```sh
sudo /usr/local/bin/radio-secure-ssh "$SSH_CONNECTION"
```

Elle est exécutée automatiquement par l'installateur pendant l'étape obligatoire ;
ce n'est plus une opération facultative à penser à lancer après installation.

### Différence avec radio-v1

Le script figé de `radio-v1` pouvait laisser l'authentification par mot de passe active
si son durcissement final n'aboutissait pas. La correction ci-dessus est propre à `main` ;
elle ne modifie pas la Release ni les serveurs déjà installés.

## Accès à OpenVPN UI

Le compte UI est `admin`, avec le mot de passe saisi. Depuis le VPN :
`http://ADRESSE_SERVEUR_VPN:8080`.
Depuis le poste administrateur, ouvrir un tunnel :

```sh
ssh -N -L 127.0.0.1:8080:127.0.0.1:8080 UTILISATEUR_LINUX@IP_PUBLIQUE_DU_SERVEUR
```

Ajoutez `-p PORT_SSH` à la commande si vous n'utilisez pas le port SSH 22.
Puis ouvrir `http://127.0.0.1:8080`. Le management OpenVPN reste sur `127.0.0.1:2080`.
L'UI écoute sur TCP 8080 ; c'est nftables qui bloque son accès public. Ne pas supprimer
ces règles ni démarrer l'UI sans cette protection.

## Clients, IP fixes et communication

Dans la page **Certificates** de l'UI, créer un certificat par appareil avec un nom unique
et une IPv4 fixe libre du réseau VPN. Ne pas utiliser l'adresse réseau, celle du serveur,
la diffusion ou une IP déjà attribuée. Exemple fictif pour `10.77.0.0/16` : serveur
`10.77.0.1`, clients `10.77.0.10` et `10.77.0.11`.

Télécharger chaque profil `.ovpn` dans l'UI et le transmettre de façon confidentielle.
Il contient le certificat client, sa clé privée, la CA et `tls-crypt`.
Les fichiers CCD de `/etc/openvpn/staticclients` portent les IP fixes avec le bon masque.
`nopool` et `ccd-exclusive` interdisent les attributions dynamiques ; il n'y a donc pas
`ifconfig-pool-persist`. `client-to-client` permet la communication entre clients.
Aucun `redirect-gateway` n'est poussé : les clients conservent leur Internet habituel.

Le pare-feu local de chaque client doit autoriser le trafic VPN souhaité. La connexion
simultanée de deux clients, leur interconnexion et leur reconnexion après redémarrage sont validées.

## Révocation, suppression et renouvellement des clients

1. Dans **Certificates**, repérez le nom et le numéro de série du certificat à révoquer,
   puis utilisez **Revoke**. L'opération conserve l'entrée révoquée de l'index CA et régénère la CRL.
2. Déconnectez l'appareil et vérifiez qu'une nouvelle connexion avec son ancien profil est
   refusée. Une connexion déjà établie n'est pas nécessairement interrompue immédiatement.
3. Utilisez ensuite **Delete files** si vous souhaitez nettoyer les fichiers du client.
   Cette suppression ne remplace pas la révocation et conserve son historique dans la CA.

Pour renouveler un certificat, utilisez l'action de renouvellement dans l'interface,
puis téléchargez et distribuez le nouveau profil `.ovpn` à l'appareil concerné.

## Renouvellement automatique de la CRL

Commandes de contrôle et de renouvellement :

```sh
sudo openssl crl -in /etc/openvpn/pki/crl.pem -noout -lastupdate -nextupdate
sudo openssl crl -in /etc/openvpn/pki/crl.pem -noout -text
sudo systemctl start radio-renew-crl.service
sudo journalctl -u radio-renew-crl.service -n 50 --no-pager
systemctl list-timers --all radio-renew-crl.timer
```

Le service exécute Easy-RSA `gen-crl` et rend la CRL lisible par OpenVPN.
Le timer `radio-renew-crl.timer` est hebdomadaire et persistant, avec un délai aléatoire
de trente minutes au maximum. Le déclenchement manuel par `systemctl start` est utile
pour une opération de maintenance ou un contrôle.

La révocation avec refus de reconnexion, le renouvellement de la CRL et la persistance
de la révocation après renouvellement et redémarrage ont été validés sur serveur réel.
Une session déjà établie n'est pas nécessairement interrompue dès la publication de la CRL.
Ne pas utiliser les commandes de suppression de PKI de la GUI pour retirer un seul client.

## Fichiers et services

| Élément | Rôle |
| --- | --- |
| `/opt/openvpn-ui-runtime` | Binaire, ressources UI, configuration et base SQLite |
| `/opt/scripts` | Scripts nécessaires aux operations de la GUI |
| `/etc/openvpn/server.conf` | Configuration du serveur VPN |
| `/etc/openvpn/config/client.conf` | Modèle utilisé pour produire les profils clients |
| `/etc/openvpn/staticclients` | IP fixes CCD |
| `/etc/openvpn/clients` | Profils clients confidentiels |
| `/usr/share/easy-rsa/pki` | PKI unique ; `/etc/openvpn/pki` est un lien vers elle |
| `/etc/openvpn-ui.env` | Mot de passe initial UI, accès root uniquement |
| `/etc/radio-vpn-deployed` | Release, commits du déploiement et du binaire, IP et réseau |

`openvpn@server.service` lance OpenVPN, `openvpn-ui.service` lance l'interface,
`radio-renew-crl.service` régénère la CRL et `radio-renew-crl.timer` planifie cette opération.
L'UI dépend de `nftables.service`. Le pare-feu autorise SSH sur les ports effectifs,
UDP 1194, loopback, ICMP et TCP 8080 uniquement depuis `tun0`.

A l'installation, un retour arrière systemd est armé pour trois minutes, avec retour
immédiat sur erreur. Il restaure les règles précédentes et arrête VPN/UI. Il n'est annulé
qu'après les contrôles locaux des services, de l'adresse CIDR de `tun0`, de l'UDP et du HTTP.
Vérifiez une nouvelle connexion SSH depuis votre poste avant de fermer la session
utilisée pour l'installation ou une intervention réseau.

## Diagnostic

```sh
systemctl --no-pager status openvpn@server openvpn-ui nftables radio-renew-crl.timer
sudo journalctl -u openvpn@server -u openvpn-ui -n 100 --no-pager
sudo tail -n 100 /var/log/openvpn/openvpn.log
ip -j -4 address show dev tun0
sudo ss -lunp
sudo nft list ruleset
sudo /usr/sbin/sshd -t
sudo cat /etc/radio-vpn-deployed
```

## Reconstruire un serveur

Conserver le dépôt et les fichiers de la Release, noter l'IPv4, le réseau, l'identité PKI
et la clé publique SSH a utiliser. Installer un **nouveau Debian 13 vierge**, puis suivre
la procedure du tag `radio-v1`, y compris la relance après la mise à niveau et le redémarrage.
Une reconstruction vierge génère une nouvelle CA : recréer les clients et redistribuer
les profils. Elle ne restaure pas les identités existantes.

La conservation des anciennes identités exige une sauvegarde confidentielle de la PKI,
de la base et des fichiers d'exploitation. Ces données ne doivent jamais etre publiées
sur GitHub. La copie locale du dépôt et des Releases n'inclut pas la PKI du VPS.
Aucun système supplémentaire de sauvegarde VPS n'est installé par ce projet.

## Maintenance et version stable

Suivez les mises à jour de sécurité Debian, l'état des services et les dates d'expiration
des certificats et de la CRL. Conservez une session SSH ouverte pendant les interventions.
Une modification de modèle dans le dépôt ne met pas à jour un serveur déjà installé.

La Release `radio-v1` contient le binaire, le paquet de déploiement et leurs empreintes.
Le paquet distingue les sources du binaire (`source-commit.txt`) de celles des scripts
et modèles (`deployment-source-commit.txt`). Les sources et les dépendances Go sont
conservées dans le dépôt, avec `go.mod`, `go.sum` et `vendor/`.
Les paquets système restent fournis par les miroirs Debian et peuvent évoluer.

La documentation courante est maintenue sur `main`. Pour la version stable, téléchargez
le script de `radio-v1` ; pour le compte interactif et le parcours SSH corrigé, utilisez celui de `main` comme
indiqué plus haut. Le tag et les fichiers de la Release `radio-v1` restent figés.
