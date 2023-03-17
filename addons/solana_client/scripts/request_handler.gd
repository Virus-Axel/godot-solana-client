@tool
extends HTTPRequest
class_name SolanaClient

@export var unique_id: int = 0

signal connection_lost


# Called when the node enters the scene tree for the first time.
func _ready():
	var random_number: PackedInt64Array = rand_from_seed(Time.get_unix_time_from_system())
	unique_id = random_number[0]
	print(bs64.decode("aGVsbG9hYWFoZWxsb2FhYWhlbGxvYWFhaGVsbG9hYWFoZWxsb2FhYWhlbGxvYWFhaGVsbG9hYWFoZWxsb2FhYWhlbGxvYWFhaGVsbG9hYWFoZWxsb2FhYWhlbGxvYWFhaGVsbG9hYWFoZWxsb2FhYWhlbGxvYWFhaGVsbG9hYWFoZWxsb2FhYQ=="))
	pass # Replace with function body.


func create_request_body(method, params):
	var dict := {
		"id": unique_id,
		"jsonrpc": "2.0",
		"method": method,
		"params": params,
	}
	var body: String = JSON.new().stringify(dict)

func get_account_info():
	pass

func get_balance(account: String):
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
