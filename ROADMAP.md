# SIG-Lycée — Application Flutter cross-platform

Portage progressif du frontend web React (`../frontend`) vers Flutter, pour une
application mobile/desktop cross-platform consommant la même API Django (`../backend`).
Référence croisée : `../frontend_fun.md` recense toutes les fonctionnalités et endpoints
du web, section par section — c'est la checklist de parité utilisée pour ce portage.

## État actuel

### Fondations (terminées)
- **Auth JWT** avec rafraîchissement automatique (`lib/core/api/api_client.dart`), stockage
  sécurisé (`flutter_secure_storage`), connexion par **email ou matricule** (miroir de
  `CustomTokenObtainPairSerializer`).
- **Routing** par rôle avec garde d'accès (`lib/core/router/app_router.dart`, via `go_router`)
  — miroir de `ProtectedRoute.jsx` / `ROLE_HOME`.
- **État applicatif** avec Riverpod (`FutureProvider` par ressource — équivalent de
  `useResourceList`/TanStack Query côté web).
- **Thème** Material 3 aligné sur la charte indigo du web (`lib/core/theme/app_theme.dart`).
- **Coquille de navigation** réutilisable par rôle (`lib/core/widgets/role_shell.dart`) —
  drawer avec la même liste de sections que chaque `*Dashboard.jsx`, avatar/déconnexion
  toujours accessibles.
- **Client REST générique** (`lib/core/api/resource_service.dart`) miroir de
  `createResourceService()`.
- **Mon Profil partagé** (`lib/features/parametres/mon_profil_screen.dart`) — édition
  nom/prénom/téléphone/photo (`image_picker` + `PATCH /auth/profile/`) et changement de
  mot de passe, accessible depuis la feuille de profil de `RoleShell` (bouton "Modifier
  mon profil"), pour les **4 rôles**. Miroir de `MonProfilPanel.jsx`.

### Élève (`lib/features/student/`) — complet
- Tableau de bord (classe, trimestre actif, notes récentes)
- Mon Profil (dossier élève, lecture) + édition partagée via la feuille de profil
- Gestion Académique (matières de l'établissement + cahier de textes en lecture seule)
- Emploi du Temps (agenda par jour)
- Devoirs (liste + statut d'échéance)
- Notes & Résultats (par trimestre + **moyenne générale annuelle**, même calcul que
  `services/moyenne.py` — arrondi trimestre par trimestre avant la moyenne finale)
- Présence (compteurs + historique + soumission de justificatif)
- Gestion Administrative, Communications, Mes Documents

### Enseignant (`lib/features/teacher/`) — complet
- Tableau de bord (classes + effectifs)
- Emploi du Temps
- Notes & Évaluations (sélection matière/trimestre, saisie d'une note par élève)
- Devoirs (création + liste + suppression — **sans** pièce jointe/photo/scan OCR)
- Cahier de textes (distinct des devoirs)
- Présence & Absences (pointage + validation des justificatifs)
- Communication + Chat de classe (ouverture/fermeture, pièces jointes)
- Historique Étudiants, Rapports
- Paramètres : photo de profil via la feuille de profil partagée (voir Fondations)

### Parent (`lib/features/parent/`) — complet
- Accueil (moyenne par enfant)
- Mes Enfants
- Bulletins (téléchargement + ouverture du PDF)
- Cahier de textes (lecture seule)
- Absences
- Paiements (dossier financier par enfant)
- Communication
- Mon Profil : via la feuille de profil partagée (voir Fondations)

### Admin (`lib/features/admin/`) — complet
- Tableau de bord : cartes de synthèse + **graphiques Area (taux par trimestre) et Radar
  (distribution par classe)** via `fl_chart` (`lib/features/admin/widgets/`), miroir de
  `TauxParTrimestreChart.jsx` / `DistributionClasseRadarChart.jsx`.
- Gestion Étudiants (liste + recherche + **détail par élève** : dossier financier et
  parents/tuteurs dans une feuille modale, miroir de `InfosEtudiantParentsDialog` —
  **sans** création/modification du dossier élève)
- Demandes d'inscription (liste + valider/rejeter)
- Gestion des Profs (liste + création de compte, réutilise `AdminPersonnelScreen`)
- Gestion Académique (Classes/Matières/Salles par onglets, création minimale)
- Emploi du Temps (par classe, agenda + ajout de créneau)
- Notes & Évaluations (classement par trimestre **et** bilan annuel passage/redoublement,
  réutilise `GET /classes/<id>/classement-annuel/`)
- Présence & Absences (indicateurs + validation des justificatifs)
- Gestion Administrative (Paiements/Documents/Utilisateurs par onglets)
- Communication, Rapports & Stats

Les rôles RESPONSABLE et SECRETARIAT (dashboards web séparés) ne sont **pas** couverts —
décision explicite, ces utilisateurs restent sur le web pour l'instant.

## Vérifié en conditions réelles

Testé en direct (Chrome headless, build web servi statiquement) contre le backend Django
local, tenant "Label de test" (`contact@label.com`) :
- Tableau de bord admin avec données réelles (22 élèves, 14 enseignants, 7 classes),
  graphiques Area (taux par trimestre) et Radar (distribution par classe) rendus avec les
  vraies données de `/statistiques/`.
- Les 11 sections du drawer Admin (dont les 7 précédemment orphelines : Demandes
  d'inscription, Gestion des Profs, Gestion Académique, Emploi du Temps, Présence &
  Absences, Gestion Administrative, Rapports & Stats) chargent sans erreur console/page.
- Détail élève (Gestion Étudiants → tap sur une ligne) : dossier financier + parents/
  tuteurs affichés correctement dans la feuille modale (ex. Voahangy ANDRIAMBOLOLONA —
  792 000 Ar dû, 672 000 Ar payé, statut "Partiel", 2 tuteurs liés).
- "Modifier mon profil" (feuille de profil → bouton dédié) testé sur les 4 rôles : édition
  + `PATCH /auth/profile/` → 200, snackbar de confirmation.
- Connexion élève par **matricule** → notes réelles affichées, nouvel onglet Gestion
  Académique (matières + cahier de textes) opérationnel.
- Connexion parent multi-enfants (`rad@gmail.com`) → les deux enfants (Voahangy, Mialy)
  bien listés à l'Accueil et dans la feuille de profil.
- Connexion enseignant → drawer et tableau de bord intacts après les changements partagés
  (`role_shell.dart`).

`flutter analyze` : 0 erreur (seulement des suggestions de style mineures, pré-existantes).
`flutter build web` : succès.

## Connu, à corriger

- **Glyphe manquant** : le caractère « ᵉ » (ordinal, ex. "6ᵉ") s'affiche en tofu box sur le
  build web — la police Roboto par défaut ne l'inclut pas dans le subset tree-shaké.
  Solution : embarquer une police avec ce glyphe, ou l'éviter dans les libellés de classe.
- Le scan OCR, la capture photo (devoirs enseignant) ne sont pas portés — fonctionnalités
  coûteuses à reproduire (tesseract.js n'a pas d'équivalent direct ; le chat de classe,
  lui, est porté, voir Enseignant ci-dessus).
- Gestion Étudiants (Admin) reste en lecture + détail, sans création/modification du
  dossier élève ; Gestion Académique (Admin) n'a que la création minimale, pas l'édition.
- RESPONSABLE et SECRETARIAT n'ont toujours pas de dashboard Flutter dédié.

## Config réseau

`lib/core/api/api_client.dart` choisit l'URL de base automatiquement :
- Web / iOS / desktop : `http://127.0.0.1:8000/api`
- Émulateur Android : `http://10.0.2.2:8000/api` (routage spécial vers l'hôte)
- Appareil physique : lancer avec `--dart-define=API_BASE_URL=http://<ip-lan>:8000/api`

## Lancer l'app

```bash
cd cross
flutter pub get
flutter run                 # choisit un device connecté
flutter run -d chrome        # web
flutter build web            # build de prod
```

Le backend Django (`../backend`) doit tourner sur le port 8000, avec `CORS_ALLOW_ALL_ORIGINS`
déjà activé en dev (`backend/settings.py`).

## Prochaines étapes suggérées (par ordre d'impact)

1. CRUD complet Admin (création/édition du dossier étudiant, des enseignants, édition des
   classes/matières/salles — actuellement création minimale seulement).
2. Dashboards RESPONSABLE et SECRETARIAT (dernier écart de parité avec le web).
3. Notifications push (le backend a déjà un modèle `Notification` — manque juste le
   transport push mobile, ex. Firebase Cloud Messaging).
4. Mode hors-ligne / cache local pour l'emploi du temps et les notes (déjà consulté très
   régulièrement, données qui changent peu).
5. Scan OCR et capture photo pour les devoirs enseignant (voir "Connu, à corriger").
