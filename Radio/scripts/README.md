# Scripts d'administration natifs

Ces scripts sont installés dans `/opt/scripts` pour le déploiement et les opérations
d'administration d'OpenVPN UI.
Le [guide principal](../README.md) décrit leur utilisation depuis l'interface.
Les chemins de la PKI et d'OpenVPN sont lus dans
`/opt/openvpn-ui-runtime/conf/app.conf`. Certains scripts acceptent `OPENVPN_UI_CONFIG`
pour sélectionner un autre fichier de configuration.

| Script | Responsabilité |
| --- | --- |
| `generate_ca_and_server_certs.sh` | Initialiser une PKI unique et les certificats serveur, sans remplacer une CA existante |
| `genclient.sh` / `write-client-profile.sh` | Générer le certificat puis assembler le profil complet avec ses blocs PEM et `tls-crypt` |
| `renew.sh` | Renouveler le certificat et régénérer le profil sans purger l'historique CA |
| `revoke.sh` | Révoquer le numéro de série visé, conserver l'entrée dans l'index et régénérer la CRL |
| `rmcert.sh` | Nettoyer les fichiers d'un certificat révoqué, sans supprimer l'historique des révocations |
| `restart.sh` | Redémarrer les services natifs via systemd |
| `secure-ssh.sh` | Désactiver les mots de passe SSH après preuve d'une connexion avec la clé fournie |
| `oath.sh` | Exemple de vérification OTP, non activé par le déploiement standard |
| `remove.sh` | Suppressions globales explicitement demandées dans l'interface ; opérations destructives |

Le code applicatif valide l'IP fixe et crée le fichier CCD en complément de l'appel
au générateur de certificat. Un appel isolé à `genclient.sh`
ne remplace donc pas le parcours complet de création d'un client dans l'interface.

Conservez la PKI et les profils hors du dépôt public. Ne purgez pas l'index de la CA
pour supprimer un client : les entrées révoquées restent nécessaires aux futures CRL.
La planification systemd de la CRL est créée par `../deploy-vps.sh`.

Lors d'une installation depuis le script de `main`, l'installateur adapte les chemins
et le contexte utilisateur de `secure-ssh.sh` au compte Linux choisi, puis installe
la commande `/usr/local/sbin/radio-secure-ssh`. Utilisez cette commande depuis la session
SSH de ce compte ; les scripts de la Release stable restent inchangés.
