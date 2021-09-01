extends Area2D

onready var special = $"../cards/special"
onready var custom = $"../cards/custom"
onready var controller = $"/root/controller"
onready var settlement = controller.get_node("settlement")

var ID_ONE = 1
var ID_TWO = 2
var EVENT_QUEUE = []

var MY_ID = 0
var OPPOSITE_ID = 0

func _ready():
	special.connect("special_card_spelled", self, "on_special_card_spelled")
	custom.connect("custom_card_spelled", self, "on_custom_card_spelled")
	Sdk.connect("disconnect", self, "_on_sdk_disconnect")
	Sdk.connect("lua_events", self, "_on_sdk_lua_events")
	Sdk.connect("p2p_message_reply", self, "_on_sdk_p2p_message_reply")
	
	controller.player_id = Sdk.get_player_id()
	if controller.player_id == ID_ONE:
		controller.opposite_id = ID_TWO
	else:
		controller.opposite_id = ID_ONE
	controller.set_player_role(controller.player_id, Config.player_hero)
	controller.set_player_hp(ID_ONE, 30)
	controller.set_player_hp(ID_TWO, 30)
	Config.game_ready = true
	Sdk.reply_p2p_message("start_game", funcref(self, "_on_p2p_start_game"))
	Sdk.send_p2p_message("game_ready", {})
	
func _process(_delta):
	if !EVENT_QUEUE.empty():
		for event in EVENT_QUEUE:
			match event.call_func:
				"run": Sdk.run(event.code, event.close_round)
				"close_game": Sdk.close_game(event.winner, event.callback)
				"p2p": Sdk.send_p2p_message(event.message, event.value)
		EVENT_QUEUE = []
	
func on_special_card_spelled(_card):
	assert(controller.acting_player_id == controller.player_id)
	run("game:spell_card(0)")

func on_custom_card_spelled(card):
	assert(controller.acting_player_id == controller.player_id)
	var offset = 0
	for child in card.get_parent().get_children():
		offset += 1
		if child == card:
			break
	run("game:spell_card(%d)" % offset)

func run(code):
	EVENT_QUEUE.push_back({
		call_func = "run",
		code = code,
		close_round = false
	})
	
func switch_round():
	EVENT_QUEUE.push_back({
		call_func = "run",
		code = "game:switch_round()",
		close_round = true
	})
	
func game_over(winner):
	settlement.winner = winner
	controller.set_battle_result(
		controller.acting_player_id, funcref(settlement, "show_settlement")
	)

func _on_sdk_lua_events(events):
	for params in events:
		var event = params[0]
		var player_id = params[1]
		match event:
			"draw":
				var card_hash = params[2]
				controller.add_player_card(player_id, card_hash)
			"damage":
				var hp = params[2]
				var effect = params[3]
				controller.set_player_hp(player_id, hp, true)
				controller.damage_player(player_id, effect, true)
			"heal":
				var hp = params[2]
				controller.set_player_hp(player_id, hp, true)
				controller.heal_player(player_id, true)
			"empower", "cost":
				var energy = params[2]
				controller.set_player_energy(player_id, energy, true)
			"strip":
				var buffs = params[2]
				print("strip buffs = ", buffs)
			"buff":
				var id = params[2]
				var offset = params[3]
				var life = params[4]
				if offset <= 0:
					controller.add_player_buff(player_id, id, life, true)
				else:
					controller.update_player_buff(player_id, offset - 1, life)
			"spell_end":
				var card_offset = params[2] - 1
				var hash_code = params[3]
				controller.apply_change(player_id, card_offset, hash_code)
			"new_round":
				var current_round = params[2]
				controller.set_acting_player(player_id)
				controller.set_round(current_round)
			"game_over":
				EVENT_QUEUE.push_back({
					call_func = "close_game",
					winner = player_id,
					callback = funcref(self, "game_over")
				})
			_:
				assert(false, "unknown event " + event)

func _on_sdk_disconnect():
	print("connection down")
	
func _on_sdk_p2p_message_reply(message, parameters):
	match message:
		"game_ready":
			if controller.player_id == ID_ONE:
				if parameters["ready"]:
					on_opposite_ready()
				else:
					Config.opposite_ready_func = funcref(self, "on_opposite_ready")
		"start_game":
			controller.get_node("wait").hide()
			Config.opposite_hero = parameters["role"]
			assert(Config.opposite_hero > 0)
			controller.set_player_role(
				controller.opposite_id, Config.opposite_hero
			)
			run("game = Tabletop.new(%d, %d)" % [
				Config.player_hero, Config.opposite_hero
			])

func _on_p2p_start_game(parameters):
	controller.get_node("wait").hide()
	Config.opposite_hero = parameters["role"]
	controller.set_player_role(
		controller.opposite_id, Config.opposite_hero
	)
	return {
		"role": Config.player_hero
	}

func on_opposite_ready():
	EVENT_QUEUE.push_back({
		call_func = "p2p",
		message = "start_game",
		value = {
			"role": Config.player_hero
		}
	})
