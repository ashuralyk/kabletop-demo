extends Node2D

onready var born   = $born_point.position
onready var anchor = $anchor
onready var tween  = $"../Tween"
onready var parent = get_parent()

var width = 1140
var step = 200
var running = false

signal custom_card_spelled

var cards_pool = []

func add_card(card_hash):
	var card = parent.get_card(card_hash)
	cards_pool.push_back(card)
	if running == false:
		run()

func next():
	running = false
	run()

func _ready():
# warning-ignore:return_value_discarded
	tween.connect("tween_all_completed", self, "next")

func run():
	if cards_pool.empty():
		return
	var card = load("res://assets/cards/card.tscn").instance()
	card.set_info(cards_pool.pop_front())
	card.connect("card_spell", self, "card_spelled")
	card.position = born
	anchor.add_child(card)
	sort_out(0.3)
	running = true

func sort_out(interval):
	var valid_children = []
	for node in anchor.get_children():
		if !node.is_queued_for_deletion():
			valid_children.push_back(node)
	var step_num = valid_children.size() - 1
	for i in valid_children.size():
		var x = (width - step_num * step) / 2 + i * step
		var card = valid_children[i]
		tween.interpolate_property(
			card, "position",
			card.position, Vector2(x, 0), interval,
			Tween.TRANS_LINEAR, Tween.EASE_IN_OUT
		)
	tween.connect("tween_all_completed", self, "sorted")
	tween.start()

func sorted():
	for card in anchor.get_children():
		card.update_origin_global_position()
	tween.disconnect("tween_all_completed", self, "sorted")

func card_spelled(card):
	var energy = get_node("/root/controller/panel/player_energy")
	if energy.try_cost_energy(card.info.cost):
		card.queue_free()
		sort_out(0.15)
		emit_signal("custom_card_spelled", card)
	else:
		card.reset()
		card.scale = Vector2(1.4, 1.4)
		card.modulate = Color("00ffffff")
		tween.interpolate_property(
			card, "scale", card.scale, Vector2.ONE, 0.3
		)
		tween.interpolate_property(
			card, "modulate", card.modulate, Color("ffffffff"), 0.3
		)
		tween.start()
		# 弹出错误提示
