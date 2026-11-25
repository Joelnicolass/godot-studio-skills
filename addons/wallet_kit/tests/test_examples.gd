extends "res://addons/wallet_kit/tests/wallet_test.gd"

## The minimal example plays as a person would: harvest, see food lost at its limit, build with gold covering.


func test_minimal_runs() -> void:
	var scene := (load("res://addons/wallet_kit/examples/minimal/minimal.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var wallet := scene.get_node(^"%Wallet") as Wallet
	var harvest := scene.get_node(^"%Harvest") as Button
	var build := scene.get_node(^"%Build") as Button
	var amounts := scene.get_node(^"%Amounts") as Label
	var log_label := scene.get_node(^"%Log") as Label
	check(amounts.text.contains("food 2/2") and build.disabled, "starts with 2 food, cannot build: %s" % amounts.text)
	harvest.pressed.emit()
	check(log_label.text.contains("1 food lost"), "food at its limit is lost: %s" % log_label.text)
	check(wallet.amount(&"wood") == 2 and wallet.amount(&"ore") == 1 and not build.disabled, "can build now")
	build.pressed.emit()
	check(wallet.amount(&"wood") == 0 and wallet.amount(&"ore") == 0 and wallet.amount(&"gold") == 1, "paid in kind")
	wallet.add({&"wood": 2})
	build.pressed.emit()
	check(wallet.amount(&"gold") == 0 and log_label.text.contains("gold"), "gold covered the ore: %s" % log_label.text)
	check(build.disabled, "nothing left to build with")
	scene.queue_free()
	await tree.process_frame
