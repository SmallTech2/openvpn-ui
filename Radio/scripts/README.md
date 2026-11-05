# Scripts Radio Bonheur - Debian 13 native

Les chemins sont lus dans `/opt/openvpn-ui-runtime/conf/app.conf`.
`OPENVPN_UI_CONFIG` permet de choisir un fichier temporaire pour les tests isoles.

- `generate_ca_and_server_certs.sh` : PKI unique, refus de reinitialiser une CA existante, generation native.
- `genclient.sh` / `write-client-profile.sh` : certificat client et profil PEM complet avec `tls-crypt`.
- `renew.sh` : renouvellement sans purge de l'index, regeneration du profil.
- `revoke.sh` : revocation du numero de serie vise (courant ou renouvele), puis CRL.
- `rmcert.sh` : nettoyage des fichiers d'un certificat revoque ; toutes les entrees CA sont conservees.
- `restart.sh` : gestion native par systemd.
- `secure-ssh.sh` : desactivation conditionnelle des mots de passe, uniquement apres preuve d'acces par cle.
- `oath.sh` / `remove.sh` : operations historiques conservees ; la suppression explicite d'une PKI reste destructive.

Les sauvegardes et migrations d'une PKI existante ne font pas partie du deploiement d'un VPS vierge.
Les tests automatises ne remplacent pas la recette VPN/systemd/SSH/nftables sur Debian 13.
