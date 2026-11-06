# Administration — préparation de radio-v2

> **radio-v2 est la prochaine version stable, encore en préparation.** Le tag et
> la Release `radio-v2` ne sont pas encore publiés. La validation complète sur Debian 13 vierge doit
> précéder la publication. `radio-v1` reste la version stable actuellement disponible.

Le fonctionnement décrit reprend les opérations existantes du logiciel.
Les résultats de validation de la version historique sont conservés dans
[la fiche radio-v1](releases/radio-v1.md) ; ils ne constituent pas une validation complète
anticipée de `radio-v2`. Les exemples de réseaux sont fictifs.
Remplacez `UTILISATEUR_LINUX` par le compte choisi à l'installation.

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


Voir aussi le [renouvellement de la CRL et le diagnostic](maintenance.md)
et la [validation SSH obligatoire](security.md#validation-obligatoire-par-clé).
