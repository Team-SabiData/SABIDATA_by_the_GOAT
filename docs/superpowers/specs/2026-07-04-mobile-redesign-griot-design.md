# Refonte design mobile SabiData — « Griot énergique »

**Date :** 2026-07-04
**Périmètre :** app Flutter (`sabiData_frontend/`) — onboarding + boucle cœur (~10 écrans).
**Hors périmètre :** panel admin (`admin-web/`, cycle séparé), écrans secondaires (leaderboard, revenus, retrait, carte des dialectes, profil, classroom, expert, conversion, transcription — ils hériteront des composants dans une passe ultérieure), tout changement backend.

## Intention

Rendre l'app attirante et motivante : **énergie de jeu** (points, série, célébrations, progression visible) sur une **base de fierté culturelle burkinabè** (motif tissé faso dan fani, salutations locales, identités par langue). La marque validée le 2026-07-01 est conservée telle quelle : thème clair, fond blanc chaud, accent rouge vif — lisible au soleil.

## Décisions actées (brainstorming)

1. Mobile d'abord ; l'admin aura son propre cycle design → spec → plan.
2. Marque conservée, exécution sublimée (pas de nouvelle identité).
3. Périmètre : splash, login, inscription, OTP, téléphone, sélection de langue, consentement, dashboard, enregistrement, revue, validation.
4. Personnalité : gamification dominante + chaleur culturelle (options « 2 et 4 »).
5. Direction d'exécution : **A — Griot énergique** (retenue face à « Arcade clay » et « Blocs tissés »).

---

## 1. Fondations (`lib/theme/`)

### Couleurs — `app_theme.dart`
Palette existante inchangée. Ajouts :

| Token | Valeur | Usage |
|---|---|---|
| `gold` | `#C9922A` | série (flamme), récompenses, rareté — convention or existante |
| `goldSoft` | or à ~10 % | fonds de pastilles série/récompense |
| `primarySoft` | rouge à ~10 % | remplissages doux (remplace les `withValues(alpha: .08–.12)` recalculés à la main partout) |

### Typographie
- **Corps :** Plus Jakarta Sans (inchangé).
- **Display :** **Bricolage Grotesque** via `google_fonts`, réservée aux titres d'écran et gros chiffres (points, minuteur, compteurs, OTP).
- Échelle fixe : 12 / 13 / 15 / 17 / 22 / 28 / 40. Chiffres tabulaires (`FontFeature.tabularFigures`) pour minuteur, points, OTP.

### Formes & espacement
- Rayons systématisés : **cartes 20**, **boutons 16**, **pastilles 999** (pill). Aucune autre valeur.
- Rythme d'espacement 4/8 ; paliers de sections 16 / 24 / 32.

### Motif tissé — `patterns.dart`
`CustomPainter` « faso dan fani » : bandes horizontales de losanges/triangles géométriques, opacité 4–6 %, couleur paramétrable (teinté selon la langue active : mooré = or, dioula = vert, fulfuldé = bleu, gulmancema = violet). Usages : bandeau haut du dashboard, fond du splash, en-tête des écrans de flux, liseré des `AppCard.accent`.

### Mouvement — `motion.dart`
Tokens de durée 150 / 250 / 400 ms ; entrée ease-out, sortie ease-in ; toutes les animations de l'app y puisent. Respect de `MediaQuery.disableAnimations` partout (reduced motion → fondus simples, pas de confettis).

### Iconographie
Emojis structurels (👤 📍 🥉 ▶ …) remplacés par **Material Symbols rounded** (inclus dans Flutter, zéro dépendance). Emojis conservés uniquement en décoration de célébration.

### Dépendances nouvelles
`google_fonts`, `shared_preferences`. Rien d'autre.

---

## 2. Composants partagés (`lib/widgets/`)

| Composant | Rôle |
|---|---|
| `SpringTap` | Enveloppe tactile universelle : scale 0.96 en ~100 ms au toucher, retour spring, haptique légère (`HapticFeedback.lightImpact`). Tous les éléments tactiles passent par lui. |
| `PrimaryButton` (refonte) | Rouge plein, hauteur 56, radius 16, état chargement intégré, bâti sur `SpringTap`. |
| `SecondaryButton` | Variante contour. |
| `RewardChip` | Pastille `+N pts` or sur `goldSoft` — partout où des points sont promis ou gagnés. |
| `ProgressRing` | Anneau de progression (CustomPainter) rouge sur piste `hairline`, chiffre display au centre. Variante fine pour compteurs. |
| `StreakBadge` | Flamme + jours consécutifs, or ; pulse doux (1.0→1.06, 1,2 s) seulement le jour où la série s'incrémente. |
| `CelebrationOverlay` | Confettis particules (couleurs marque + or, ~1,2 s, interruptibles au tap) + `RewardChip` « volant » vers le compteur de points. Reduced motion → fondu. |
| `AppCard` (refonte) | Surface blanche, radius 20, **une seule** ombre douce standard dans toute l'app. Variante `.accent` avec liseré motif tissé. |
| `AuthField` (refonte) | Label visible au-dessus (jamais placeholder seul), erreur sous le champ, hauteur 52, focus ring rouge 2 px, `keyboardType` sémantique. |
| `state_views` (restylage) | Squelettes shimmer pour chargements > 300 ms au lieu de spinners. |

**Transitions d'écran** (go_router `pageBuilder`) : push = glissement gauche + fondu 250 ms, retour inversé. Hero transition : cercle micro du dashboard → cercle d'enregistrement.

**Règle d'architecture :** tokens, durées et motifs vivent dans `lib/theme/` ; les écrans ne contiennent plus aucune valeur de style en dur (couleur, rayon, durée).

---

## 3. Écrans

### Splash
Fond motif tissé or pleine page (5 %), « SabiData » en display XXL, point du « i » en losange rouge, tagline « Ta voix a de la valeur », fondu sortant.

### Login / Inscription / Téléphone
Squelette commun : en-tête compact (bandeau motif + titre display), `AuthField`, un seul `PrimaryButton` par écran, liens secondaires sobres.

### OTP
Cases à 6 chiffres, auto-avance, chiffres display tabulaires, collage supporté.

### Sélection de langue
Cartes langues : fond clair conservé, identité par **liseré dégradé 2 px + motif tissé teinté** (pas d'aplat total), coche animée à la sélection.

### Consentement
Cartes `AppCard` scannables (icône + phrase courte), toggle usage commercial très visible, CTA collant en bas. Ton rassurant.

### Dashboard (refonte la plus visible)
1. Bandeau haut : motif tissé or + salutation locale (« Yambã wend, {prénom} ») + `StreakBadge`.
2. Carte héros : `ProgressRing` points → prochain niveau + nom du niveau (Bronze → Argent). Remplace le bandeau badge actuel.
3. Deux grosses actions côte à côte : **Parler** (rouge plein, icône micro, `RewardChip +150`) et **Valider** (contour, `RewardChip +20`), hero transition.
4. Carte « Défi du jour » : progression N/5 clips.
5. Dialecte, revenus, classement : `AppCard` compactes en dessous.

### Enregistrement
Cercle rouge pulsant conservé ; **forme d'onde honnête** branchée sur l'amplitude réelle du micro (API amplitude du package `record`) ; phrase à lire en display plus grande ; minuteur tabulaire ; motif en filigrane.

### Revue
Lecteur réel : gros play/pause avec état, position/durée réelles (`audioplayers` streams), barre de progression de lecture réelle. Soumission réussie → `CelebrationOverlay` + écran succès restylé.

### Validation
Même lecteur réel ; verdicts en `SpringTap` pleine largeur ; anneau fin « validés aujourd'hui » dans l'en-tête ; micro-feedback `+20` volant à chaque vote.

---

## 4. Données de gamification — cadrage

**Aucun changement backend.**
- Points / niveaux : ce que l'API renvoie déjà.
- **Série** et **défi du jour** : calcul local (`shared_preferences`) — jours consécutifs avec ≥ 1 soumission ; compteur de clips du jour. Branchables sur le backend plus tard s'il les fournit.
- Salutations locales : table statique par langue choisie.
- Le dashboard garde ses données mockées là où l'API n'existe pas encore (nom, dialecte) — la refonte est visuelle, pas un câblage de données nouveau.

## 5. Accessibilité & qualité (issues d'ui-ux-pro-max)

- Contraste texte ≥ 4.5:1 sur fond clair (statuts déjà recalibrés pour ça).
- Cibles tactiles ≥ 48 dp, espacement ≥ 8 dp.
- Feedback visuel < 100 ms sur tout tap (`SpringTap`).
- Micro-interactions 150–300 ms, jamais > 500 ms ; sorties plus courtes que les entrées.
- `Semantics` labels sur les contrôles à icône seule (play, micro, verdicts).
- Reduced motion respecté ; pas d'information portée par la couleur seule (icône + texte sur les statuts).
- Pas d'emoji comme icône fonctionnelle.

## 6. Vérification

- `flutter analyze` sans erreur et tests existants verts à chaque tâche.
- Test widget nouveau : `SpringTap` (feedback press), `ProgressRing` (valeurs bornées), logique série/défi (pure, testable sans device).
- Passe visuelle sur device physique en fin de refonte — combinable avec la Task 12 audio (vérif bout-en-bout multipart) encore en attente.

## 7. Risques & limites

- `google_fonts` télécharge les polices au premier lancement → prévoir fallback système propre (comportement par défaut du package) ; option bundle si hors-ligne critique.
- L'amplitude micro selon plateforme peut être irrégulière → lissage (moyenne glissante) dans le widget d'onde.
- Les écrans hors périmètre auront un léger décalage visuel temporaire (ancien `PrimaryButton` remplacé partout, donc décalage limité aux ombres/spacings) — assumé jusqu'à la passe 2.
