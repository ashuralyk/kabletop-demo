extends Node2D

onready var tween = $"../Tween"

func _ready():
	set_card("res://assets/cards/card.tscn")
	
func set_card(path):
	if self.get_child_count() > 0:
		self.get_child(0).free()
	var card = load(path).instance()
	card.get_node("frame").connect("card_spell", self, "card_spelled")
	self.add_child(card)
	
func card_spelled(card):
	card.get_node("frame").reset()
	card.scale = Vector2(1.4, 1.4)
	card.modulate = Color("00ffffff")
	tween.interpolate_property(
		card, "scale", card.scale, Vector2.ONE, 0.3
	)
	tween.interpolate_property(
		card, "modulate", card.modulate, Color("ffffffff"), 0.3
	)
	tween.start()
