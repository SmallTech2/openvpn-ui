# Maintenance — préparation de radio-v2

> **radio-v2 est la prochaine version stable, encore en préparation.** Le tag et
> la Release `radio-v2` ne sont pas encore publiés. La validation complète sur Debian 13 vierge doit
> précéder la publication. `radio-v1` reste la version stable actuellement disponible.

Les commandes de maintenance concernent un serveur déjà installé.
Les procédures fonctionnelles sont reprises sans modification de leur logique.

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

Pour `radio-v2`, attendre sa publication avant d'utiliser ses téléchargements.
Pour une reconstruction avec la version déjà disponible, suivre [la fiche radio-v1](releases/radio-v1.md).


Conserver le dépôt et les fichiers de la Release, noter l'IPv4, le réseau, l'identité PKI
et la clé publique SSH à utiliser. Installer un **nouveau Debian 13 vierge**, puis suivre
la procédure du futur tag `radio-v2`, après sa publication, y compris la relance après la mise à niveau et le redémarrage.
Une reconstruction vierge génère une nouvelle CA : recréer les clients et redistribuer
les profils. Elle ne restaure pas les identités existantes.

La conservation des anciennes identités exige une sauvegarde confidentielle de la PKI,
de la base et des fichiers d'exploitation. Ces données ne doivent jamais être publiées
sur GitHub. La copie locale du dépôt et des Releases n'inclut pas la PKI du VPS.
Aucun système supplémentaire de sauvegarde VPS n'est installé par ce projet.

## Maintenance et références de version


Suivez les mises à jour de sécurité Debian, l'état des services et les dates d'expiration
des certificats et de la CRL. Conservez une session SSH ouverte pendant les interventions.
Une modification de modèle dans le dépôt ne met pas à jour un serveur déjà installé.

La future Release `radio-v2` devra conserver le binaire, le paquet de déploiement et leurs empreintes.
Le paquet distingue les sources du binaire (`source-commit.txt`) de celles des scripts
et modèles (`deployment-source-commit.txt`). Les sources et les dépendances Go sont
conservées dans le dépôt, avec `go.mod`, `go.sum` et `vendor/`.
Les paquets système restent fournis par les miroirs Debian et peuvent évoluer.


La documentation courante est maintenue sur `main`. Les téléchargements figés de
`radio-v2` seront utilisables uniquement après validation et publication.
Les fichiers et le tag de `radio-v1` restent inchangés.
