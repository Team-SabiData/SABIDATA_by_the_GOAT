# SabiData — Application Mobile Flutter

Application mobile de collecte crowdsourcée de données audio en langues nationales burkinabè (mooré, dioula, fulfuldé, gulmancema). Conçue pour être **offline-first**, accessible aux utilisateurs peu alphabétisés, et optimisée pour les connexions lentes.

---

## Stack technique

| Élément | Choix |
|---------|-------|
| Framework | Flutter 3.38+ |
| Navigation | go_router 14 |
| Police | Plus Jakarta Sans (google_fonts) |
| Thème | Sombre exclusif (Dark-only) |
| État | setState local (provider en dépendance, prêt pour expansion) |

---

## Architecture du projet

```
lib/
├── main.dart                    # Point d'entrée, MaterialApp.router
├── router.dart                  # GoRouter — toutes les routes
├── theme/
│   └── app_theme.dart           # Tokens de couleur (AppColors) + ThemeData
├── widgets/
│   ├── status_bar.dart          # Barre de statut simulée (9:41, wifi, batterie)
│   └── primary_button.dart      # Bouton CTA réutilisable
└── screens/
    ├── splash_screen.dart                # 1a · Écran d'accueil / Splash
    ├── language_selection_screen.dart    # 1b · Sélection multi-langue
    ├── skill_profile_screen.dart         # 1c · Profil de compétence
    ├── dialect_region_screen.dart        # 1d · Dialecte & région
    ├── dashboard_screen.dart             # 2  · Tableau de bord principal
    ├── recording_screen.dart             # 3b · Enregistrement en cours
    ├── validation_screen.dart            # 4  · Module validation
    ├── transcription_screen.dart         # 5b · Transcription + clavier spécial
    ├── leaderboard_screen.dart           # 8a · Classement communautaire
    ├── revenue_screen.dart               # 9  · Tableau de bord revenus
    └── dialect_map_screen.dart           # 7  · Carte des dialectes
```

---

## Écrans implémentés

### A — Onboarding
| Écran | Route | Description |
|-------|-------|-------------|
| Splash | `/` | Logo animé, baseline, boutons "Commencer" / "J'ai déjà un compte" |
| Sélection de langue | `/language-select` | Cartes multi-sélection (Mooré, Dioula, Fulfuldé, Gulmancema) |
| Profil de compétence | `/skill-profile` | Toggles Parler / Lire, sélecteur 3 niveaux pour Écrire |
| Dialecte & Région | `/dialect-region` | GPS auto-detect, zones avec indicateurs de rareté ⭐⭐ |

### B — Collecte
| Écran | Route | Description |
|-------|-------|-------------|
| Tableau de bord | `/dashboard` | En-tête utilisateur, badge niveau, tâche du jour, grille modules, nav bar |
| Enregistrement | `/recording` | Indicateur REC, chronomètre, forme d'onde animée, bouton stop pulsant |
| Validation | `/validation` | Lecteur audio, 3 boutons verdict (Oui +20pts / Non / Pas sûr) |

### C — Communauté & Revenus
| Écran | Route | Description |
|-------|-------|-------------|
| Leaderboard | `/leaderboard` | Podium top-3, liste classée, position épinglée de l'utilisateur |
| Revenus | `/revenue` | Solde FCFA, mobile money (Orange/Moov/Wave), historique des gains |
| Transcription | `/transcription` | Lecteur RTB 0.5×/1×/1.5×, champ de saisie, clavier ɛ/ɔ/ŋ/tons |
| Carte des dialectes | `/dialect-map` | Carte Burkina Faso (CustomPainter), densité choroplèthe, épingle utilisateur |

---

## Navigation

```
/ (Splash) → /language-select → /skill-profile → /dialect-region → /dashboard
                                                                         ├── /recording
                                                                         ├── /validation
                                                                         ├── /transcription
                                                                         ├── /leaderboard
                                                                         ├── /revenue
                                                                         └── /dialect-map
```

---

## Design tokens

```dart
AppColors.bg              = #0C1020   // fond principal
AppColors.surface         = #131826   // cartes
AppColors.surfaceElevated = #1C2235   // cartes surélevées
AppColors.primary         = #F5A624   // orange SabiData
AppColors.green           = #2BC49A   // validation / revenus
AppColors.blue            = #4A9EF5   // info / transcription
AppColors.red             = #E84040   // enregistrement / rejet
AppColors.orange          = #E87D3E   // RTB / bronze
AppColors.textPrimary     = #F0EDE8
AppColors.textSecondary   = #6B7E9E
```

---

## Lancer l'application

```bash
cd sabidata_app
flutter pub get
flutter run
```

Pour builder un APK debug :
```bash
flutter build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk
```

---

## Ce qui reste à implémenter (backend — phase 2)

- Authentification utilisateur (JWT / OAuth)
- API REST pour la synchronisation des clips audio
- Stockage offline SQLite / Isar + queue de synchronisation
- Enregistrement audio réel (package `record`)
- Lecture audio réelle (package `just_audio`)
- Module Expert / Linguiste (`/expert`)
- Classroom Challenge B2B (`/classroom`)
- Data Marketplace (interface web séparée)
- Localisation i18n (fr / mooré / dioula)
- Intégration CinetPay / FedaPay pour les paiements mobile money
- Notifications push

---

## Design source

Le design de référence est disponible dans :
```
Inspection du projet (1)/SabiData Screens.dc.html
```
Ouvrir dans un navigateur pour voir les 11 maquettes haute-fidélité.
