# Plan : DX — Améliorer l'expérience `npm run dev`

## Contexte

Quand on fait `npm run dev`, Vite affiche `http://localhost:5173` — ce n'est pas le bon lien (le site est sur `:8080`). Ctrl+C ne tue que Vite (sync.js reste orphelin en background). L'utilisateur ne sait pas comment arrêter Docker. Et si on lance deux projets, les ports/volumes Docker se marchent dessus.

---

## 1. Remplacer `&` par un script `bin/dev.js` propre

**Problème :** `node bin/sync.js --watch & vite` lance sync en background. Ctrl+C ne le tue pas.

**Solution :** Créer `bin/dev.js` qui :

- Lance sync.js et vite comme child processes
- Affiche un message de bienvenue clair avec les bons URLs
- Intercepte SIGINT (Ctrl+C) pour tuer les deux proprement
- Optionnellement stoppe Docker à la fin (avec confirmation)

**Fichier :** `bin/dev.js` (nouveau)

```
npm run dev → node bin/dev.js
```

Le script :

1. Lance `node bin/sync.js --watch` (child process)
2. Lance `npx vite` (child process, stdout capturé pour détecter "ready")
3. Quand Vite est prêt, affiche :

```
╔══════════════════════════════════════════╗
║         Development server ready         ║
╠══════════════════════════════════════════╣
║  WordPress :  http://localhost:8080      ║
║  Vite HMR  :  http://localhost:5173      ║
║  phpMyAdmin :  http://localhost:8081      ║
╚══════════════════════════════════════════╝

  Vite gère le HMR (hot reload CSS/JS).
  Ouvrez WordPress dans votre navigateur.

  Ctrl+C pour arrêter.
```

4. Sur Ctrl+C : tue sync + vite, puis demande "Arrêter les containers Docker ? [y/N]"

**Fichiers modifiés :**

- `bin/dev.js` — **nouveau**
- `package.json` — `"dev": "node bin/dev.js"`

---

## 2. Scoper Docker par projet (éviter les conflits)

**Problème :** Deux projets sur le même poste partagent les mêmes ports (8080, 8081) et le volume `db_data` prend le nom du dossier parent comme préfixe Docker Compose par défaut (`docker_db_data`). Si les deux projets ont leur `docker-compose.yml` dans un dossier `docker/`, le préfixe sera identique → conflit.

**Solution :**

- Ajouter `COMPOSE_PROJECT_NAME=${PROJECT_NAME}` dans `.env` (généré par setup.sh)
- Passer le `.env` du projet à docker compose : `docker compose --env-file ../.env`
- Rendre les ports configurables dans `.env` :
    - `WP_PORT=8080` (défaut)
    - `PMA_PORT=8081` (défaut)
- Dans docker-compose.yml : `"${WP_PORT:-8080}:80"` et `"${PMA_PORT:-8081}:80"`

**Fichiers modifiés :**

- `docker/docker-compose.yml` — ports dynamiques, env-file
- `.env.example` — ajouter `WP_PORT`, `PMA_PORT`, `COMPOSE_PROJECT_NAME`
- `bin/setup.sh` — générer ces variables dans `.env`
- `bin/dev.js` — lire les ports depuis `.env` pour l'affichage

---

## 3. Setup lance `npm run dev` à la fin (optionnel)

**À la fin du setup (après "Setup complete!"):**

```
Lancer le serveur de développement maintenant ? [Y/n]
```

Si oui → exécute `npm run dev` (qui lance le nouveau `bin/dev.js`).

**Fichier modifié :** `bin/setup.sh` — ajouter la question finale

---

## Fichiers à modifier

| Fichier                     | Action                                                                 |
| --------------------------- | ---------------------------------------------------------------------- |
| `bin/dev.js`                | **Nouveau** — orchestrateur dev (sync + vite + messages + cleanup)     |
| `package.json`              | Changer `"dev"` → `"node bin/dev.js"`                                  |
| `docker/docker-compose.yml` | Ports dynamiques via variables, env-file                               |
| `.env.example`              | Ajouter `WP_PORT`, `PMA_PORT`, `COMPOSE_PROJECT_NAME`                  |
| `bin/setup.sh`              | Générer les nouvelles variables + question "lancer dev ?"              |
| `vite.config.js`            | Optionnel : lire le port depuis .env si on veut le rendre configurable |

---

## Vérification

1. `npm run dev` → affiche le message avec les bons URLs (`:8080`, pas `:5173`)
2. Ctrl+C → tue sync + vite proprement, propose d'arrêter Docker
3. Deux projets différents avec des `PROJECT_NAME` différents → pas de conflit de ports/volumes
4. `npm run setup` → à la fin, propose de lancer `npm run dev`
5. Vérifier que `ps aux | grep sync` ne montre plus de processus orphelin après Ctrl+C
