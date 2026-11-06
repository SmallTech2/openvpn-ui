# Deploiement natif OpenVPN — radio-v1

## Version et perimetre valide

Version stable : [radio-v1](https://github.com/SmallTech2/openvpn-ui/releases/tag/radio-v1).
La recette reelle sur Infomaniak Debian 13 a valide : installation complete, PKI,
acces UI par tunnel SSH, deux clients a IP fixes connectes simultanement,
communication interclients et avec `10.3.0.1`, Internet habituel conserve,
puis reconnexion SSH et clients apres un redemarrage complet du VPS.
Les services `openvpn@server`, `openvpn-ui`, `nftables` et `radio-renew-crl.timer`
etaient actifs apres redemarrage. Cette validation est rapportee par l'exploitant.

Restent a valider sur le VPS reel : le cycle de revocation et le renouvellement effectif
de la CRL. Voir la procedure plus bas. Les tests automatises historiques ne remplacent
pas ces tests d'exploitation.

## Prerequis

- VPS vierge Debian 13, architecture x86_64/AMD64, systemd et droits root/sudo.
- Session SSH interactive, commande `ip` (paquet `iproute2`) et `curl` pour le telechargement.
- IPv4 publique fixe, acces HTTPS sortant aux miroirs Debian et a GitHub.
- Cle SSH **publique ED25519** du poste administrateur. Ne pas fournir la cle privee
  ni utiliser la cle de deploiement reservee a GitHub.
- Autoriser le port SSH utilise et UDP 1194 dans le pare-feu de l'hebergeur.
  Ne pas ouvrir TCP 8080 sur Internet.
- Choisir un sous-reseau prive qui ne chevauche pas les reseaux des clients et du VPS.

## Installation depuis la version figee

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/radio-v1/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo bash deploy-vps.sh
```

Au premier lancement, une confirmation precede `apt-get update`, `apt-get full-upgrade`
(en conservant les fichiers de configuration locaux) et `apt-get autoremove --purge`.
Le VPS redemarre ensuite. Apres reconnexion SSH, relancer dans le meme repertoire :

```sh
sudo bash deploy-vps.sh
```

L'etat `/var/lib/radio-vpn/debian-upgrade-boot-id` est enregistre uniquement apres
reussite des commandes APT. Le script verifie le changement de demarrage et ne refait
pas la mise a niveau. Il ne reprend pas automatiquement et ne stocke aucun mot de passe
pour traverser le redemarrage.

Le script propose l'IPv4 publique detectee, modifiable, puis demande :

- Reseau VPN prive CIDR, par exemple `10.3.0.0/16`, `172.23.0.0/16` ou `192.168.42.0/24`.
- Cle publique SSH, organisation et email de la PKI.
- Apres confirmation et configuration interactive du clavier francais AZERTY :
  mots de passe du compte `technicien` et de l'administrateur OpenVPN UI.

Les deux mots de passe suivent la meme regle : huit caracteres minimum, aucune limite
maximale ajoutee par le script, espaces, accents et symboles acceptes sur une ligne,
saisie masquee et confirmation. Ils ne sont pas affiches dans le recapitulatif.
Une seconde confirmation precede l'installation VPN.

Les reseaux RFC1918 sont acceptes de /16 a /29, limites de la directive serveur OpenVPN
avec `tun`. Une adresse d'hote a la place de l'adresse reseau et les chevauchements
avec les routes presentes sur le VPS sont refuses. Les conflits avec les futurs reseaux
clients restent a verifier par l'administrateur. Le serveur utilise toujours **reseau + 1** :
`10.3.0.0/16` donne `10.3.0.1/16`, `192.168.42.0/24` donne `192.168.42.1/24`.

Le script refuse de remplacer une installation ou une CA existante. Il telecharge le
paquet de la Release `radio-v1`, verifie son SHA-256 puis les empreintes internes et
utilise les sources de deploiement du commit inscrit dans ce paquet. Il n'utilise ni
`main` ni la derniere version implicite d'une dependance Go.

## Compte technicien et SSH

`technicien` dispose d'un repertoire personnel, d'un shell Bash, de sudo avec mot de passe
et de la cle fournie. La configuration SSH est validee avant rechargement.
Les mots de passe SSH ne sont desactives qu'apres preuve, dans le journal du demarrage,
d'une connexion avec cette cle. Sinon ils restent actifs.

Apres connexion avec la cle du poste, la commande suivante peut terminer ce durcissement :

```sh
sudo radio-secure-ssh "$SSH_CONNECTION"
```

Garder la session ouverte et verifier une nouvelle connexion avant de la fermer.

## Acces a OpenVPN UI

Le compte UI est `admin`, avec le mot de passe saisi. Depuis le VPN :
`http://ADRESSE_SERVEUR_VPN:8080`.
Depuis le poste administrateur, ouvrir un tunnel :

```sh
ssh -N -L 127.0.0.1:8080:127.0.0.1:8080 technicien@IP_PUBLIQUE
```

Puis ouvrir `http://127.0.0.1:8080`. Le management OpenVPN reste sur `127.0.0.1:2080`.
L'UI ecoute sur TCP 8080 ; c'est nftables qui bloque son acces public. Ne pas supprimer
ces regles ni demarrer l'UI sans cette protection.

## Clients, IP fixes et communication

Dans la page des certificats de l'UI, creer un certificat par appareil avec un nom unique
et une IPv4 fixe libre du reseau VPN. Ne pas utiliser l'adresse reseau, celle du serveur,
la diffusion ou une IP deja attribuee. Par exemple, pour `10.3.0.0/16` : serveur
`10.3.0.1`, clients `10.3.0.10` et `10.3.0.11`.

Telecharger chaque profil `.ovpn` dans l'UI et le transmettre de facon confidentielle.
Il contient le certificat client, sa cle privee, la CA et `tls-crypt`.
Les fichiers CCD de `/etc/openvpn/staticclients` portent les IP fixes avec le bon masque.
`nopool` et `ccd-exclusive` interdisent les attributions dynamiques ; il n'y a donc pas
`ifconfig-pool-persist`. `client-to-client` permet la communication entre clients.
Aucun `redirect-gateway` n'est pousse : les clients conservent leur Internet habituel.

Le pare-feu local de chaque client doit autoriser le trafic VPN souhaite. Les essais
reels de deux clients, interconnexion et reconnexion apres reboot sont valides.

## Revocation et CRL : procedure a valider sur le VPS reel

1. Utiliser un client de test, relever son nom et son numero de serie dans l'UI,
   et conserver son ancien profil hors du depot pour le test de refus.
2. Dans l'UI, revoquer le certificat correspondant. Le script cible son numero de serie,
   conserve l'entree revoquee de l'index CA et regenere la CRL.
3. Deconnecter le client de test, puis tenter une nouvelle connexion avec l'ancien profil :
   elle doit etre refusee. Verifier que l'autre client reste utilisable. Ne pas supposer
   qu'une session deja etablie est immediatement coupee par la nouvelle CRL.
4. Verifier la CRL, declencher son renouvellement et retester le refus apres regeneration
   puis apres reboot. Les numeros de serie revoques doivent toujours etre presents.
5. L'action **Delete files**, facultative apres revocation, nettoie les fichiers clients ;
   elle ne remplace pas la revocation et ne purge pas l'historique CA.

Commandes de controle et de renouvellement :

```sh
sudo openssl crl -in /etc/openvpn/pki/crl.pem -noout -lastupdate -nextupdate
sudo openssl crl -in /etc/openvpn/pki/crl.pem -noout -text
sudo systemctl start radio-renew-crl.service
sudo journalctl -u radio-renew-crl.service -n 50 --no-pager
systemctl list-timers --all radio-renew-crl.timer
```

Le service execute Easy-RSA `gen-crl` et rend la CRL lisible par OpenVPN.
Le timer est hebdomadaire, persistant, avec delai aleatoire. Son etat actif apres reboot
est valide ; l'execution reelle du renouvellement et le refus d'un certificat revoque
restent **a valider**. Ne pas utiliser les commandes de suppression de PKI de la GUI
pour retirer un seul client.

## Fichiers et services

| Element | Role |
| --- | --- |
| `/opt/openvpn-ui-runtime` | Binaire, ressources UI, configuration et base SQLite |
| `/opt/scripts` | Scripts necessaires aux operations de la GUI |
| `/etc/openvpn/server.conf` | Configuration du serveur VPN |
| `/etc/openvpn/config/client.conf` | Modele utilise pour produire les profils clients |
| `/etc/openvpn/staticclients` | IP fixes CCD |
| `/etc/openvpn/clients` | Profils clients confidentiels |
| `/usr/share/easy-rsa/pki` | PKI unique ; `/etc/openvpn/pki` est un lien vers elle |
| `/etc/openvpn-ui.env` | Mot de passe initial UI, acces root uniquement |
| `/etc/radio-vpn-deployed` | Release, commits du deploiement et du binaire, IP et reseau |

`openvpn@server.service` lance OpenVPN, `openvpn-ui.service` lance l'interface,
`radio-renew-crl.service` regenere la CRL et `radio-renew-crl.timer` planifie cette operation.
L'UI depend de `nftables.service`. Le pare-feu autorise SSH sur les ports effectifs,
UDP 1194, loopback, ICMP et TCP 8080 uniquement depuis `tun0`.

A l'installation, un retour arriere systemd est arme pour trois minutes, avec retour
immediat sur erreur. Il restaure les regles precedentes et arrete VPN/UI. Il n'est annule
qu'apres les controles locaux des services, de l'adresse CIDR de `tun0`, de l'UDP et du HTTP.
Ce mecanisme a ete observe pendant les recettes ; il ne remplace pas le test d'une
nouvelle connexion SSH depuis le poste.

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

## Refaire un VPS complet

Conserver le depot et les fichiers de la Release, noter l'IPv4, le reseau, l'identite PKI
et la cle publique SSH a utiliser. Installer un **nouveau Debian 13 vierge**, puis suivre
la procedure du tag `radio-v1`, y compris la relance apres la mise a niveau et le reboot.
Une reconstruction vierge genere une nouvelle CA : recreer les clients et redistribuer
les profils. Elle ne restaure pas les identites existantes.

La conservation des anciennes identites exige une sauvegarde confidentielle de la PKI,
de la base et des fichiers d'exploitation. Ces donnees ne doivent jamais etre publiees
sur GitHub. La copie locale du depot et des Releases n'inclut pas la PKI du VPS.
Aucun systeme supplementaire de sauvegarde VPS n'est installe par ce projet.

## Sources, binaire et reconstruction du logiciel

Le binaire valide est conserve **octet pour octet** depuis `radio-build-test3`, sources
`684151fb3a0ad27e392f79e617cb649583c4e8ff`. SHA-256 :
`5e5255d176839be76df6d08fd373dd62fc915fd86bb2ffb90ad9bfe34d8b53b8`.
Le deploiement fonctionnel valide est `db5b79d24ceb57eeee864e3ec15783ffba51fc91`.
Le tag `radio-v1` ajoute le gel des references et la documentation sans changer le code Go.

Le paquet stable contient : `source-commit.txt` (sources du binaire),
`deployment-source-commit.txt` (sources des scripts et modeles figes),
`validated-deployment-commit.txt` (recette), `openvpn-ui.sha256` et `SHA256SUMS`.
Le ZIP a sa propre empreinte externe. Les scripts sont recuperes par commit exact.
Le tag et les fichiers de Release doivent etre conserves, sans remplacement en place.

Les dependances Go sont versionnees dans `go.mod`, `go.sum` et `vendor/`.
Une reconstruction technique exige Go 1.26.5, un compilateur C pour SQLite/CGO,
Linux AMD64 et les outils de paquetage Bash, Python 3 et ZIP. La commande de compilation
est dans `.github/workflows/radio-build.yml`, avec `-mod=vendor` et `CGO_ENABLED=1`.
Elle n'est pas executee pendant le gel stable. Les scripts de publication restent distincts
du deploiement sur le VPS.

Les elements externes restent : l'outil Go, le compilateur C et les outils de construction,
les actions GitHub, et les paquets des miroirs Debian 13 (OpenVPN, Easy-RSA, OpenSSL,
Python, systemd, nftables...). Les paquets Debian et le runner `ubuntu-24.04` evoluent :
le depot permet de reconstruire les sources, mais ne garantit pas un nouveau binaire
identique octet pour octet ni les memes versions de paquets systeme. Le binaire deja
valide et ses empreintes sont donc conserves dans la Release et dans la copie locale.

## Publication et droits GitHub

Tous les workflows ont `contents: read` par defaut. L'ecriture `contents: write` est limitee
aux jobs de publication de Release ; le jeton est fourni uniquement a l'etape de publication.
Le workflow de recette ne publie que des preversions `radio-build-testN`, par tag ou demande
manuelle explicite. Les pull requests ne publient pas. Le workflow stable ne publie que lors
de la creation explicite du tag exact `radio-v1`, sans compilation ni tests lourds.
Il verifie les empreintes du paquet et du binaire valides, et l'absence de changement des
sources Go, dependances et ressources UI depuis le commit du binaire.

Les controles administrateur n'ont pas pu etre lus avec la cle Git SSH de ce projet.
A verifier dans **SmallTech2/openvpn-ui > Settings** :

- **Actions > General > Workflow permissions** : lecture seule par defaut ; ne pas autoriser
  les workflows a creer/approuver des pull requests si ce n'est pas necessaire.
- **Deploy keys** : apres cette publication, retirer le droit d'ecriture de la cle Codex
  ou supprimer cette cle si elle n'est plus necessaire.
- **Collaborators / Manage access** : conserver seulement les personnes et integrations utiles,
  et les droits minimums necessaires.
- **Rules > Rulesets** : proteger `radio-v1` contre modification et suppression ; proteger
  `main` contre les force-push et limiter ses acces d'ecriture selon votre organisation.
- Ne jamais joindre une PKI, une cle SSH privee, un profil client ou un mot de passe aux
  commits ou aux Releases. Les seuls secrets necessaires aux jobs sont les jetons temporaires GitHub.

## Copie locale a conserver sur Windows

Conserver ensemble le bundle Git `openvpn-ui.bundle` (historique et tags), l'archive des
sources `radio-v1-source.zip`, les sept fichiers de la Release et `SAUVEGARDE.txt`.
Le dossier `Sauvegarde-OpenVPN-radio-v1` de l'espace de travail contient cette copie.
Il peut etre pris en charge par la sauvegarde existante vers les deux NAS Synology ;
aucune tache ou infrastructure de sauvegarde supplementaire n'est creee.
Le bundle se restaure avec `git clone openvpn-ui.bundle openvpn-ui`.
