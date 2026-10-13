class_name Demo
extends Node

## The demonstration's main scene, and the whole integration of TGC Game Menu: a
## [TgcMenuSession] beside the game, and three connections. The session says when a game
## starts, when it stops, and when a control was remapped; the game does the rest.
##
## The demonstration also adds a page of its own to the menu ([DemoGameplayPage], listed in
## `demo_menu_config.tres`), and gives it the game's settings here.

@onready var _session: TgcMenuSession = $MenuSession
@onready var _world: DemoWorld = $World


func _ready() -> void:
	_session.game_started.connect(_world.start)
	_session.game_stopped.connect(_world.stop)
	_session.controls_changed.connect(func(_bindings: TgcControlBindings) -> void: _world.show_help())
	(_session.menu().page(&"gameplay") as DemoGameplayPage).bind(_world.settings)
	# The session has read the player's controls since the world drew its help.
	_world.show_help()


func session() -> TgcMenuSession:
	return _session


func world() -> DemoWorld:
	return _world
