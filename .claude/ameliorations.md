# Améliorations futures

## Reverse proxy Traefik (priorité haute)

**Problème :** Chaque projet utilise un port différent (8080, 8081...). Les ports sont attribués au moment du setup selon ce qui est libre. Si on setup un projet C alors que A et B sont éteints, C prend le port 8080 → conflit au lancement simultané de A et C. Les URLs en DB sont liées au port.

**Solutions :**
1. **Traefik partagé** — un container Traefik global écoute sur port 80/443, chaque projet est accessible via `{slug}.localhost` (résolu nativement par les navigateurs). Plus de gestion de ports. C'est l'approche de DDEV, Lando, DevKinsta.
2. **Court terme** — garder les ports mais demander confirmation au setup + vérifier au `npm run dev` que le port n'est pas déjà pris.

---

## Import de dump DB au setup

**Problème :** Après un `npm run reset` ou un clone frais, on repart d'une DB vierge. Le contenu WordPress (pages, ACF, menus) est perdu.

**Solutions :**
1. Au setup, si des dumps existent dans `database/`, proposer un menu : choisir un dump ou DB vierge.
2. Après import : `wp search-replace 'ancienne-url' 'nouvelle-url' --all-tables --skip-columns=guid` pour corriger les URLs.
3. `wp cache flush` + `wp rewrite flush` pour finaliser.
4. Importer via `mysql` CLI (container `db`), pas `wp db import` (WP pas encore bootstrappé à ce stade).

---

## npm run import (standalone)

**Problème :** Pouvoir importer un dump en dehors du setup, sur un projet déjà configuré.

**Solutions :**
1. Script qui liste les dumps dans `database/`, propose de choisir ou accepte un fichier en argument.
2. Même flow : import MySQL + `wp search-replace` + flush.

---

## Commande npx create-wp-boilerplate

**Problème :** Pour utiliser le boilerplate, il faut cloner le repo manuellement.

**Solution :** Publier un package npm avec `npx create-wp-boilerplate mon-projet` qui clone, supprime le `.git`, et lance le setup.
