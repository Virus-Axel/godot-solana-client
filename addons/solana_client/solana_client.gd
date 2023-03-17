@tool
extends EditorPlugin

func _enter_tree():
	preload("res://addons/solana_client/scripts/bs64.gd")
	add_custom_type("SolanaClient", "HTTPRequest", preload("res://addons/solana_client/scripts/request_handler.gd"), preload("res://addons/solana_client/icon.png"))


func _exit_tree():
	remove_custom_type("SolanaClient")
