# Carte des dialectes — branchement sur les données réelles

**Date** : 2026-07-12 · **Statut** : validé par Abdoulaye

## Problème

L'écran `/dialect-map` mélange données réelles et maquette : la liste « Couverture
par zone » vient de `GET /api/regions`, mais la carte dessinée (halos, points,
pin « Vous » sur Yatenga), la carte détail (« Mooré de Yatenga · 180 clips ·
Urgent · ×3 pts · B2B Premium ») et le titre (« — Mooré ») sont codés en dur.
Les onglets « Vue nationale / Mon empreinte » n'ont aucun effet.

## Design

1. **Table de coordonnées régionales** (constante Flutter) : les 8 régions du
   backend (`CONFIG.regions`) → `(x, y)` dans l'espace 350×218 du painter.
   Région inconnue = absente de la carte, jamais d'erreur.
2. **Painter alimenté** : `_BurkinaMapPainter` reçoit la couverture ; rayon et
   intensité des halos ∝ clips (normalisés par le max), couleur selon la même
   échelle que la liste (jaune < 10 %, orange < 30 %, bleu-gris sinon).
3. **Pin « Vous »** : positionné sur `DialectPrefs.region` via la table ;
   sans région connue, ni pin ni entrée « Vous » dans la légende.
4. **Carte détail** = zone la plus sous-représentée (min `coveragePct`) :
   titre région, sous-titre « Zone {zone} · Burkina Faso », clips réels,
   « Urgent » si < 10 % sinon « À renforcer », bonus ×3 / ×2 pts aligné sur
   `rarityMult` backend. Le badge « B2B Premium » statique disparaît.
5. **Nettoyage** : titre « Couverture par zone » sans suffixe langue (le
   backend ne filtre pas par langue) ; onglets retirés.
6. **Tests** : `RegionsApi` injectable dans l'écran ; widget test avec API
   mockée (liste rendue, détail = zone la plus rare, pin selon le profil,
   onglets absents).

Aucun changement backend : `/api/regions` fournit déjà tout.
