# Installation — préparation de radio-v2

> **radio-v2 est la prochaine version stable, encore en préparation.** Le tag et
> la Release `radio-v2` ne sont pas encore publiés. La validation complète sur Debian 13 vierge doit
> précéder la publication. `radio-v1` reste la version stable actuellement disponible.

Les exemples de réseaux sont fictifs. Adaptez-les à votre installation.

## Prérequis

- VPS vierge Debian 13, architecture x86_64/AMD64, systemd et droits root/sudo.
- Session SSH interactive, commande `ip` (paquet `iproute2`) et `curl` pour le téléchargement.
- IPv4 publique fixe, accès HTTPS sortant aux miroirs Debian et à GitHub.
- Clé SSH **publique ED25519** du poste administrateur. Ne pas fournir la clé privée.
- Autoriser le port SSH utilisé et UDP 1194 dans le pare-feu de l'hébergeur.
  Ne pas ouvrir TCP 8080 sur Internet.
- Choisir un sous-réseau privé qui ne chevauche pas les réseaux des clients et du VPS.

## Téléchargement après publication

**Ne lancez pas ce bloc avant la publication du tag et de la Release `radio-v2`.**
Les URL ci-dessous sont préparées pour cette publication et ne sont pas encore disponibles.

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/radio-v2/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo env RADIO_RELEASE_TAG=radio-v2 bash deploy-vps.sh
```

La variable `RADIO_RELEASE_TAG` est déjà prise en charge par l'installateur. Elle est
indiquée explicitement pour demander le paquet `radio-v2` : le script courant de `main`
utilise encore `radio-v1` par défaut. Cette réorganisation ne change pas le script.

## Recette avant publication

Pour préparer la validation depuis la branche de développement, utilisez uniquement
un serveur Debian 13 vierge réservé à la recette :

```sh
curl --fail --location --proto '=https' --proto-redir '=https' \
  https://raw.githubusercontent.com/SmallTech2/openvpn-ui/main/Radio/deploy-vps.sh \
  -o deploy-vps.sh
sudo env RADIO_RELEASE_TAG=radio-v1 bash deploy-vps.sh
```

Ce parcours teste le script de `main` avec le paquet déjà publié `radio-v1` et le helper
SSH corrigé récupéré par commit exact. Il n'installe pas une Release `radio-v2` inexistante.
Pour la relance après redémarrage pendant cette recette, conservez `RADIO_RELEASE_TAG=radio-v1`.
Pour l'installation stable historique, consultez [radio-v1](releases/radio-v1.md).

## Préparation Debian et paramètres interactifs

Les commandes de relance de cette section sont celles de la future version publiée.
Pendant la recette de `main`, utilisez la valeur `radio-v1` indiquée ci-dessus.

Au premier lancement, une confirmation précède `apt-get update`, `apt-get full-upgrade`
(en conservant les fichiers de configuration locaux) et `apt-get autoremove --purge`.
Le VPS redémarre ensuite. Après reconnexion SSH, relancer dans le même répertoire :

```sh
sudo env RADIO_RELEASE_TAG=radio-v2 bash deploy-vps.sh
```

L'état `/var/lib/radio-vpn/debian-upgrade-boot-id` est enregistré uniquement après
réussite des commandes APT. Le script vérifie le changement de démarrage et ne refait
pas la mise à niveau. Il ne reprend pas automatiquement et ne stocke aucun mot de passe
pour traverser le redémarrage.

Le script propose l'IPv4 publique détectée, modifiable, puis demande :

- Réseau VPN privé CIDR, par exemple `10.77.0.0/16` ou `192.168.42.0/24`.
- Nom du compte administrateur Linux à créer (`technicien` proposé par défaut).
- Clé publique SSH, organisation et email de la PKI ; remplacez les valeurs proposées par celles de votre organisation.
- Après confirmation et configuration interactive de la disposition du clavier :
  mots de passe du compte Linux choisi et de l'administrateur OpenVPN UI.

Les deux mots de passe suivent la même règle : huit caractères minimum, aucune limite
maximale ajoutée par le script, espaces, accents et symboles acceptés sur une ligne,
saisie masquée et confirmation. Ils ne sont pas affichés dans le récapitulatif.
Une seconde confirmation précède l'installation VPN.
Une validation obligatoire dans une seconde session SSH
intervient ensuite, après création du compte et avant la configuration du VPN : [voir le guide de sécurité](security.md#validation-obligatoire-par-clé).

Les réseaux RFC1918 sont acceptés de `/16` à `/29`, limites de la directive serveur OpenVPN
avec `tun`. Une adresse d'hôte à la place de l'adresse réseau et les chevauchements
avec les routes présentes sur le VPS sont refusés. Les conflits avec les futurs réseaux
clients restent à vérifier par l'administrateur. Le serveur utilise toujours **réseau + 1** :
`10.77.0.0/16` donne `10.77.0.1/16`, `192.168.42.0/24` donne `192.168.42.1/24`.

Le script refuse de remplacer une installation ou une CA existante. Il télécharge le
paquet de la future Release `radio-v2`, une fois publiée, vérifie son SHA-256 puis les empreintes internes et
utilise les sources de déploiement du commit inscrit dans ce paquet. Le téléchargement figé n'utilisera pas
`main` ni la dernière version implicite d'une dépendance Go.


Après installation : [administration](administration.md), [sécurité SSH](security.md)
et [maintenance](maintenance.md).
