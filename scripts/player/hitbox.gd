extends Area3D
## Хитбокс игрока: голова / тело / ноги.
## Урон зависит от зоны. Хитбокс — дочерний узел модели,
## поэтому вращается вместе с телом (важно для spinbot/anti-aim).

enum Zone { HEAD, BODY, LEGS }

@export var zone: Zone = Zone.BODY

## Игрок-владелец (устанавливается при спавне)
var owner_player: Node = null

func get_damage_multiplier() -> float:
	match zone:
		Zone.HEAD:
			return 4.0
		Zone.BODY:
			return 1.0
		Zone.LEGS:
			return 0.6
	return 1.0

func get_zone_name() -> String:
	match zone:
		Zone.HEAD:
			return "head"
		Zone.BODY:
			return "body"
		Zone.LEGS:
			return "legs"
	return "body"
