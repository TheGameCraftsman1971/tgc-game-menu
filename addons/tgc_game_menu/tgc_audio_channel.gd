@tool
class_name TgcAudioChannel
extends Resource

## One volume slider of the Sound page: a bus, its caption, its starting volume.
##
## The volume is the bus's, and nothing else: a sound plays on its bus and never needs to
## know the player's settings.

## The bus, as named in the project's audio bus layout.
@export var bus: StringName = &"Master"
## The caption's translation key. The add-on's catalogue has `TGC_VOLUME_MASTER`,
## `TGC_VOLUME_EFFECTS`, `TGC_VOLUME_MUSIC`, `TGC_VOLUME_VOICE` and `TGC_VOLUME_AMBIENCE`.
@export var label := "TGC_VOLUME_MASTER"
## The volume before the player changes it, and after "Reset".
@export_range(0.0, 1.0, 0.05) var default_volume := 1.0
