# Améliorations futures

## Reverse proxy Traefik (priorité haute)

**Problème :** Chaque projet utilise un port différent (8080, 8081...). Les ports sont attribués au moment du setup selon ce qui est libre. Si on setup un projet C alors que A et B sont éteints, C prend le port 8080 → conflit au lancement simultané de A et C. Les URLs en DB sont liées au port.

**Solutions :**
1. **Traefik partagé** — un container Traefik global écoute sur port 80/443, chaque projet est accessible via `{slug}.localhost` (résolu nativement par les navigateurs). Plus de gestion de ports. C'est l'approche de DDEV, Lando, DevKinsta.
2. **Court terme** — garder les ports mais demander confirmation au setup + vérifier au `npm run dev` que le port n'est pas déjà pris.

---

---

## Commande npx create-wp-boilerplate

**Problème :** Pour utiliser le boilerplate, il faut cloner le repo manuellement.

**Solution :** Publier un package npm avec `npx create-wp-boilerplate mon-projet` qui clone, supprime le `.git`, et lance le setup.
