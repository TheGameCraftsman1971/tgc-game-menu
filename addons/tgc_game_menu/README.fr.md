# TGC Game Menu

*[English](README.md)*

Un menu principal et un menu de pause pour Godot 4, avec les réglages qu'attendent les
joueurs, réglés depuis une seule ressource.

- **Un menu, deux visages.** Au lancement, le titre du jeu, *Jouer*, *Réglages* et *Quitter
  le jeu*. Pendant une partie, *Pause*, *Reprendre*, *Nouvelle partie*, *Réglages*, *Menu
  principal* et *Quitter le jeu*. *Quitter le jeu* se masque dans une version web.
- **Un sous-menu Réglages** liste les pages ci-dessous. *Retour*, Échap ou le B de la manette
  remontent d'un niveau à la fois — page, sous-menu, racine — et le focus revient au bouton
  qu'on a quitté.
- **Général** : la langue, proposée parmi les traductions **de votre jeu**, chacune nommée
  dans sa propre langue, avec *Celle du système* (qui lit la langue de l'interface du
  navigateur sur le web, pas seulement sa première langue préférée).
- **Affichage** : mode d'affichage (fenêtré, fenêtré agrandi, plein écran), taille de la
  fenêtre (seulement les tailles au format de l'écran qui y tiennent), synchronisation
  verticale, limite d'images par seconde, échelle du rendu 3D, anticrénelage (MSAA), taille de
  l'interface. Chaque ligne peut être masquée. Les valeurs par défaut sont celles des
  réglages de votre projet.
- **Son** : un curseur par bus audio que vous nommez, suivant une courbe perceptive (la
  moitié du curseur donne un quart du gain, environ −12 dB), qui coupe le bus à zéro.
- **Commandes** : une colonne clavier-souris et une colonne manette, deux emplacements
  chacune par défaut, remaniées à l'écran. Remanier le clavier ne touche jamais à la manette.
  Une touche donnée à une action est reprise à celle qui l'avait. La pause garde toujours une
  touche au clavier. Les touches sont nommées comme elles sont **gravées** sur le clavier du
  joueur (Z sur un AZERTY pour la position du W), les boutons de manette pour les deux
  familles de manettes (« A / Croix »).
- **Une confirmation avant de perdre une partie.** Pendant une partie, *Nouvelle partie*,
  *Menu principal* et *Quitter le jeu* demandent d'abord, dans une fenêtre modale dont le
  focus commence sur *Annuler* et ne peut pas s'en échapper. *Quitter le jeu* demande aussi
  depuis le menu principal. Juste après une sauvegarde ou un chargement, il n'y a rien à
  perdre, et rien n'est demandé.
- **La sauvegarde et le chargement, en option** : des pages *Sauvegarder* et *Charger* qui
  listent les emplacements avec leur date et votre résumé, la sauvegarde rapide et le
  chargement rapide sur des raccourcis remaniables (F5, F9), un nombre d'emplacements de
  chaque sorte, *Supprimer* en option. **Votre code fait la sauvegarde** : le menu ne fait que
  l'appeler.
- **Un aperçu en direct dans l'éditeur** (`TgcMenuPreview`) : n'importe quel écran, n'importe
  quelle langue, votre configuration et votre thème, redessiné au fil de vos modifications —
  sans lancer le jeu.
- **Vos propres pages** après les pages intégrées, chacune avec son bouton dans le sous-menu.
- **Des réglages enregistrés à chaque changement et relus sans faire confiance au
  fichier** : types erronés, valeurs hors liste, commandes illisibles, tout retombe sur les
  valeurs par défaut au lieu de planter. Les commandes sont stockées en texte lisible
  (`t:87`, `b:0`, `a:1:+`), jamais en objets sérialisés.
- **La navigation à la manette d'emblée** : `ui_accept` et `ui_cancel` reçoivent A et B
  quand elles n'ont aucun bouton de manette, ce qui est le cas des réglages par défaut de
  Godot.
- Traduit en **anglais, français, allemand et espagnol**.

Aucune dépendance, aucune ressource externe : un thème, une icône, un catalogue CSV.

Nécessite **Godot 4.7** (développé et testé sur 4.7.2).

## Installer

1. Copiez `addons/tgc_game_menu/` dans votre projet (ou installez-le depuis l'Asset Store).
2. *Projet > Paramètres du projet > Plugins* : activez **TGC Game Menu**. Cela enregistre
   les traductions de l'add-on, et déclare une action `game_pause` (Échap, Start) si vous
   n'en avez pas.
3. Ajoutez un nœud **TgcMenuSession** à votre scène principale.

Cela donne déjà un menu qui fonctionne, avec le `default_menu_config.tres` de l'add-on.
Branchez-y ensuite votre jeu :

```gdscript
@onready var _session: TgcMenuSession = $MenuSession
@onready var _game: MyGame = $Game

func _ready() -> void:
	_session.game_started.connect(_game.start)   # « Jouer », « Nouvelle partie »
	_session.game_stopped.connect(_game.stop)    # « Menu principal », « Nouvelle partie », « Quitter le jeu »
```

Votre jeu n'a pas besoin de savoir s'il est en pause : la session met l'arbre en pause.
Veillez donc à ce que les nœuds du jeu soient pausables (le défaut de Godot), et à ce que ce
qui doit continuer pendant la pause (la musique, les sons d'interface) soit en
`PROCESS_MODE_ALWAYS`. Un jeu qui se termine de lui-même appelle `_session.to_main_menu()`.

## Régler : `TgcMenuConfig`

Créez une ressource **TgcMenuConfig** (ou dupliquez `default_menu_config.tres`), modifiez-la
dans l'inspecteur, et donnez-la au `config` de la session. Tout a une valeur par défaut qui
fonctionne.

| Groupe | Champ | Ce qu'il fait |
| --- | --- | --- |
| Menu | `title` | Le titre du menu principal : une clé de traduction ou du texte brut. Vide : le nom du projet. |
| | `start_on_main_menu` | Désactivé : une partie démarre aussitôt, et le menu n'est qu'un menu de pause. |
| | `pause_on_focus_loss` | Met en pause quand la fenêtre perd le focus pendant une partie. |
| | `hide_quit_on_web` | Masque *Quitter le jeu* dans une version web. |
| | `confirm_progress_loss` | Demande avant que *Nouvelle partie*, *Menu principal* et *Quitter le jeu* abandonnent une partie en cours. À désactiver pour un jeu qui sauvegarde en permanence. |
| | `confirm_quit` | *Quitter le jeu* demande même depuis le menu principal, sans partie en cours. |
| | `pause_action` | L'action qui ouvre et ferme le menu de pause (`game_pause`). |
| | `theme` | Le thème du menu. Vide : le thème de votre projet. |
| | `menu_scene` | Votre propre copie de `menu/tgc_game_menu.tscn`, pour redessiner la racine. |
| Pages | `show_*_page` | Masque une page intégrée. Une page qui n'a rien à montrer se masque d'elle-même (Général avec une seule langue, Son sans aucun bus) ; sans aucune page, *Réglages* se masque aussi. |
| | `extra_pages` | Vos propres pages (voir plus bas). |
| Languages | `languages` | Les langues proposées. Vide : celles de vos traductions. |
| Display | `show_*` | Masque une ligne (le MSAA et l'échelle du rendu ne veulent rien dire pour un jeu 2D). |
| | `fps_limits`, `ui_scales`, `min_render_scale` | Les valeurs proposées. `0` image par seconde, c'est *Sans limite*. |
| Sound | `audio_channels` | Un **TgcAudioChannel** par curseur : bus, clé du libellé, volume par défaut. Vide : le volume général seul. |
| Controls | `remappable_actions` | Un **TgcRemappableAction** par ligne, dans l'ordre : action, clé du libellé, `essential`. Vide : l'action de pause seule. |
| | `slots_per_family` | Le nombre de commandes par action et par famille (1 à 4). |
| | `show_gamepad_column` | À désactiver pour un jeu qui ne se joue pas à la manette. |
| | `capture_timeout` | Le nombre de secondes pendant lesquelles la page Commandes attend une commande. |
| | `gamepad_ui_buttons` | Donne à `ui_accept` / `ui_cancel` les boutons A / B quand elles n'en ont pas. |
| Saves | `enable_saves` | *Sauvegarder*, *Charger*, la sauvegarde rapide et le chargement rapide. Désactivé par défaut. |
| | `save_slots` | Les emplacements de la page *Sauvegarder* (0 : sauvegardes rapides seulement). |
| | `quick_save_slots` | Les emplacements que la sauvegarde rapide écrit à tour de rôle : d'abord le vide, puis le plus ancien (0 : pas de sauvegarde rapide). |
| | `allow_delete_saves` | Un bouton *Supprimer* sur chaque sauvegarde, qui demande d'abord. |
| | `quick_save_action`, `quick_load_action` | Les actions des raccourcis, ajoutées à la page Commandes. Créées avec F5 et F9 si votre projet ne les déclare pas. |
| | `show_save_notifications` | Un court message à l'écran après une sauvegarde rapide ou un chargement rapide. |
| Files | `*_file` | Où les réglages sont enregistrés (`user://settings_*.cfg`). |

Les actions remaniables doivent être déclarées dans *Paramètres du projet > Contrôles* (l'Input
Map) : leurs commandes y sont les valeurs par défaut que *Rétablir les commandes d'origine*
ramène.

## Sauvegarder et charger

L'add-on ne sait jamais comment votre jeu est sauvegardé. Activez `enable_saves`, étendez
**TgcSaveProvider**, et donnez-en une instance à la session :

```gdscript
class_name MySaves
extends TgcSaveProvider

func save_game(slot: TgcSaveSlot) -> Error:        # écrire votre état pour slot.id
	...
func load_game(slot: TgcSaveSlot) -> Error:        # le restaurer sur une partie neuve
	...
func delete_save(slot: TgcSaveSlot) -> Error:
	...
func describe(slot: TgcSaveSlot) -> TgcSaveInfo:  # null quand l'emplacement est vide
	return TgcSaveInfo.new(saved_at_unix_time, "Chapitre 3 — Le port")
func can_save() -> bool:                           # facultatif : false pendant une cinématique
	return true
```

```gdscript
_session.saves = MySaves.new(...)
```

- `slot.id` vaut `save_1`, `save_2`… ou `quick_1`, `quick_2`… : utilisez-le comme clé de
  votre stockage.
- **Charger démarre une partie** : la session émet `game_stopped` (si une partie est en
  cours), puis `game_started`, puis appelle `load_game()`. Restaurez votre état sur la partie
  neuve.
- Ce que renvoie `describe()` est affiché tel quel ; tout ce qui n'est pas un `TgcSaveInfo`
  compte comme vide. Gardez-le léger : il est appelé chaque fois qu'une page liste les
  emplacements.
- **Sauvegarder** liste les emplacements normaux ; un emplacement vide sauvegarde aussitôt,
  un plein demande avant d'être écrasé. **Charger** liste toutes les sauvegardes, normales et
  rapides, la plus récente d'abord, et demande avant d'abandonner une partie dont la
  progression est en jeu. **Supprimer** demande toujours.
- **La sauvegarde rapide** (F5) écrit le premier emplacement rapide vide, sinon le plus
  ancien ; **le chargement rapide** (F9) charge la sauvegarde rapide la plus récente. Tous
  deux marchent pendant une partie, menu ouvert ou non, et disent à l'écran ce qui s'est
  passé. Si le jeu a tourné depuis la dernière sauvegarde, le chargement rapide demande
  d'abord : le jeu se fige sous la fenêtre modale seule, et *Annuler* le laisse continuer.
- Une sauvegarde automatique, c'est `session.save_to(slot)`, depuis votre propre code.

Le `demo/demo_saves.gd` de la démo est un fournisseur complet : un petit fichier par
emplacement, relu sans lui faire confiance.

## Aperçu dans l'éditeur

Ouvrez `preview/tgc_menu_preview.tscn`, ou mieux, ajoutez un nœud **TgcMenuPreview** à une
scène à vous, et réglez dans l'inspecteur :

| Champ | |
| --- | --- |
| `config` | Votre `TgcMenuConfig` (vide : celle de l'add-on par défaut). |
| `theme_override` | Un thème à essayer à la place de celui de la configuration. |
| `screen` | Menu principal, menu de pause, Réglages, une page, Sauvegarder, Charger, une confirmation, une notification. |
| `page` | Pour l'écran *Page* : à choisir parmi les pages de la configuration (`general`, `display`, `sound`, `controls`, et les vôtres). |
| `locale` | La langue de l'aperçu, à choisir parmi celles que parlent votre jeu ou l'add-on. |
| `filled_slots` | Le nombre de sauvegardes fictives que montrent les pages Sauvegarder et Charger. |
| `background_color`, `background` | Ce qu'il y a derrière le menu : une couleur, ou une capture de votre jeu. |

Modifiez le thème qu'utilise le menu — celui de la configuration, ou celui de votre projet
(`gui/theme/custom`) — et l'aperçu suit aussitôt ; changez la configuration ou l'écran et il
se redessine en une demi-seconde (le bouton **Redraw** le force). Redimensionnez le nœud pour
voir le menu à une autre résolution.

**L'aperçu ne touche à rien** : aucun fichier lu ni écrit, aucune action de commande créée,
ni la langue de l'éditeur ni celle du jeu changée (il parle au travers d'un domaine de
traduction à lui). Les sauvegardes qu'il montre n'existent pas.

Vos propres pages sont dessinées vivantes si leur script est un script d'outil (`@tool`, avec
un `_ready()` qui ne fait rien de nuisible dans l'éditeur) ; sinon, elles sont montrées telles
que leur scène les dessine. C'est pourquoi les scripts de l'add-on sont tous des scripts
d'outil, et ne font absolument rien dans l'éditeur sans un aperçu pour les piloter : un
`TgcMenuSession` dans une scène que vous ouvrez ne lit aucun fichier et ne touche à rien.

## L'aide de votre jeu lit l'Input Map

N'écrivez jamais le nom des touches à la main : il mentirait au premier remaniement.
Demandez-le à l'add-on :

```gdscript
_help.text = tr("HELP_JUMP") % TgcInputLabels.first_of(&"jump", false)  # true : la manette
```

et refaites-le sur `controls_changed` et sur `NOTIFICATION_TRANSLATION_CHANGED`.

## Votre propre page

Une scène dont la racine étend **TgcMenuPage**, avec un `page_id` unique et un `title` (une
clé de traduction), et dont le bouton *Retour* émet `closed` (pour remonter au sous-menu
Réglages). Listez-la dans `extra_pages` ; son bouton apparaît dans le sous-menu, après ceux
des pages intégrées. La page montre vos réglages et les change ; votre jeu les applique et
les enregistre. Donnez-lui vos réglages une fois la session prête :

```gdscript
(_session.menu().page(&"gameplay") as GameplayPage).bind(_gameplay_settings)
```

Redéfinissez `setup(session)`, `is_relevant()`, `focus_first()` et `leave()` selon vos
besoins.

## Traductions

Les textes de l'add-on sont des clés préfixées `TGC_`, dans `i18n/tgc_game_menu.csv` ; elles
n'entrent jamais en collision avec les vôtres. Les langues proposées au joueur sont **celles
de votre jeu**, jamais celles de l'add-on : un jeu uniquement en anglais ne propose pas le
français parce que son menu se trouve le parler. Un jeu sans aucune traduction garde le menu
dans la langue de repli du projet.

Pour ajouter une langue que parle votre jeu et pas l'add-on : ajoutez-en les clés `TGC_*` à
votre propre catalogue (`TGC_LANGUAGE_SELF` est le nom de la langue dans cette langue), ou
proposez une colonne pour le CSV de l'add-on.

## L'API de la session

| Membre | |
| --- | --- |
| `game_started`, `game_stopped` | Démarrent et arrêtent votre jeu. |
| `paused_changed(paused)` | L'arbre a été mis en pause ou relancé. |
| `controls_changed(bindings)` | Une commande a été remaniée : rafraîchissez votre aide à l'écran. |
| `play()`, `resume()`, `pause()`, `toggle_pause()`, `to_main_menu()`, `quit()` | Ce que font les boutons, pour votre propre code et vos tests. |
| `is_paused()`, `is_in_game()`, `menu()` | |
| `progress_at_risk` | Indique si le jeu a tourné depuis la dernière sauvegarde ou le dernier chargement. La session le tient à jour : faux après une sauvegarde ou un chargement, vrai de nouveau dès que le jeu tourne. Les confirmations n'apparaissent que tant qu'il est vrai. |
| `saves` | Votre `TgcSaveProvider`. |
| `save_to(slot)`, `load_from(slot)`, `delete_save(slot)`, `quick_save()`, `quick_load()` | Ce qu'appellent les pages et les raccourcis ; une sauvegarde automatique appelle `save_to`. |
| `save_slots()`, `quick_slots()`, `existing_saves()`, `describe(slot)`, `can_save()` | |
| `saved(slot)`, `loaded(slot)`, `save_deleted(slot)` | Des signaux. |
| `general`, `display`, `audio`, `bindings` | Les réglages : des objets observables (`changed`) que la session applique et enregistre. |

Pour les tests automatisés qui ne doivent pas toucher aux fichiers du joueur, donnez à la
session une copie de la configuration dont les fichiers sont renommés :
`config.redirected("test_")`, **avant** qu'elle entre dans l'arbre.

## Licence

MIT — voir `LICENSE.txt`. © 2026 Ulric — TheGameCraftsman.
