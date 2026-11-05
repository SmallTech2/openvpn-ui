# Radio Bonheur — scripts OpenVPN UI (installation native Debian 13)

Fichiers repris de l’installation du 4 novembre 2026, avec adaptations ciblées :
- `restart.sh` : redémarrage systemd.
- `genclient.sh`, `revoke.sh`, `rmcert.sh` : profils générés avec `<tls-crypt>`.
- `revoke.sh`, `rmcert.sh`, `renew.sh`, `remove.sh` : chemins absolus vers `conf/app.conf`.
- `generate_ca_and_server_certs.sh` : génération de clé TLS en natif sans Docker et blocage `init_all` si une CA existe déjà.

**Non validé en production** : les opérations de création, renouvellement, révocation et suppression de certificats doivent être vérifiées sur le VPS de recette. Le script `deploy-vps.sh` actuel est encore basé sur un kit `.tgz` et ne sait pas déployer directement ces fichiers depuis GitHub.

`backup.sh` et `start.sh` ne sont pas intégrés : ils sont spécifiques à l’ancien mode Docker ou au répertoire historique et ne sont pas requis par les services systemd décrits. `app.conf` n’est pas intégré car le modèle doit être construit et paramétré par le déploiement. `easyrsa-tools.lib` n’est pas embarqué : utiliser la version installée avec Easy-RSA Debian. Ces choix restent à confirmer lors de la recette.
