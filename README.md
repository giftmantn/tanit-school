# Tanit School — المدرسة الافتراضية للتلميذ التونسي

Une bibliothèque numérique gratuite pour les élèves de Tunisie, du **primaire au baccalauréat**. Cours, exercices, résumés et examens — classés par **niveau** et par **matière**, en **arabe / français / anglais**.

## ✨ Fonctionnalités

| Rôle | Ce qu'il peut faire |
|---|---|
| **Élève** | Créer un compte, parcourir la bibliothèque, rechercher/filtrer, sauvegarder des favoris, lire les PDF |
| **Enseignant** | Publier des documents via un **lien Google Drive public**, les modifier, les supprimer |
| **Super admin** | Gérer les utilisateurs (rôles), les documents (approbation/suppression), les niveaux et les matières |

Autres points :
- Interface **mobile + desktop** (responsive)
- **3 langues** : Arabe (RTL), Français, Anglais — avec sélecteur de langue
- **Mode clair / sombre** (toggle en haut à droite)
- **0 coût de stockage** : les fichiers restent sur Google Drive, la base ne stocke que les liens

## 🗂️ Structure du projet

```
TANIT SCHOOL/
├── index.html        Page d'accueil
├── auth.html         Connexion / inscription
├── browse.html       Bibliothèque (filtres + recherche)
├── document.html     Lecteur de document (PDF Drive)
├── favorites.html    Favoris de l'élève
├── teacher.html      Espace enseignant
├── admin.html        Panneau d'administration
├── config.js         ⚙️ À configurer (clés Supabase)
├── database-schema.sql  ⚙️ À exécuter dans Supabase
└── css/  js/         Styles + logique (i18n, Supabase)
```

## 🚀 Installation (pas à pas)

### 1. Créer le backend Supabase (gratuit)

1. Allez sur **https://supabase.com** et créez un projet (gratuit).
2. Dans le menu de gauche : **SQL Editor** → **New query**.
3. Copiez tout le contenu de **`database-schema.sql`**, collez-le, puis cliquez sur **Run**.
   - Cela crée les tables : `profiles`, `levels`, `subjects`, `documents`, `favorites`
   - Insère les niveaux (1ère année primaire → Bac) et les matières
   - Active la sécurité (Row Level Security)
4. Allez dans **Project Settings** → **API** et copiez :
   - **Project URL**
   - **anon public key**

### 2. Configurer les clés

Ouvrez **`config.js`** et remplacez les valeurs :

```js
window.SUPABASE_URL = "https://XXXX.supabase.co";   // votre URL
window.SUPABASE_ANON_KEY = "eyJhbGciOi...";         // votre anon key
```

### 3. Créer votre premier compte admin

1. Sur le site, inscrivez-vous (onglet « Créer un compte »).
2. Dans Supabase : **Table Editor** → table `profiles`.
3. Trouvez votre ligne et changez `role` de `student` en `admin`.
4. Reconnectez-vous → le lien « Administration » apparaît dans le menu.

### 4. Mettre le site en ligne (GitHub)

**Option A — GitHub Pages (site vitrine statique, recommandé)**
1. Créez un dépôt sur **https://github.com/new** (par ex. `tanit-school`).
2. **Add file → Upload files** : glissez-déposez tous les fichiers (et les dossiers `css/`, `js/`).
3. **Settings → Pages** → Source : **Deploy from a branch** → `main` → Enregistrer.
4. Votre site est en ligne sur `https://VOTRE_NOM.github.io/tanit-school/`.

**Option B — Vercel / Netlify**
- Déposez le dépôt GitHub sur **vercel.com** ou **netlify.com** : déploiement automatique.

## 👨‍🏫 Publier un document (enseignant)

1. Mettez votre fichier (PDF, etc.) sur Google Drive.
2. **Partager → « Toute personne disposant du lien »**.
3. Copiez le lien, collez-le dans le formulaire (Espace enseignant).
4. Remplissez les titres en FR/AR/EN, choisissez niveau + matière → **Ajouter**.

> Le site convertit automatiquement le lien en lecteur intégré, bouton de téléchargement et vignette.

## 🔐 Rôles & sécurité

- Chaque table a des règles (RLS) : un élève ne voit que les documents **approuvés**, un enseignant ne modifie que **ses** documents, seul l'admin gère les niveaux/matières et les rôles.
- Un compte enseignant est accordé à l'inscription ; l'admin peut changer les rôles à tout moment.

## 🧰 Personnalisation

- **Couleurs** : `css/style.css` → variables dans `:root` (et `:root[data-theme="dark"]` pour le mode sombre).
- **Textes / langues** : `js/i18n.js` → dictionnaires `ar`, `fr`, `en`.
- **Niveaux / matières** : administrables directement depuis le panneau admin.

## 📄 Licence

Projet personnel — usage éducatif libre.
