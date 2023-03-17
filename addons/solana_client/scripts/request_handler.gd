@tool
extends HTTPRequest
class_name SolanaClient

const HTTP_HEADERS: PackedStringArray = ["Content-Type: application/json", "Accept-Encoding: json"]
const MAX_GODOT_INT: int = 9223372036854775807

@export var url: String = "https://api.testnet.solana.com"

var unique_id: int = 0

signal error(error_code: String, error_description: String)

# Called when the node enters the scene tree for the first time.
func _ready():
	var random_number: PackedInt64Array = rand_from_seed(Time.get_unix_time_from_system())
	unique_id = random_number[0]
	print(await get_block_height())
	print(await get_balance("6WEPfubN443TJ4tr8z2SsP8f3o1eXRzn4Wv2X2ykY4JX"))
	print(await get_account_info("6WEPfubN443TJ4tr8z2SsP8f3o1eXRzn4Wv2X2ykY4JX"))


func parse_response_data(data: Array) -> Variant:
	if data.is_empty():
		emit_signal("error", "INTERNAL", "HTTP response data is invalid.")
	
	# Check HTTP status code
	elif data[1] == 0:
		emit_signal("error", "NO_RESPONSE", "No response from a server at " + url)
	
	# TODO: Fix this when done testing
	elif data[1] != 200:
		print(data[1])
		assert(false)
		
		emit_signal("error", "HTTP_ERROR", "An unknown error ocurred.")

	# Check for RPC error response code
	elif data[0] == 1:
		emit_signal("error", "CANCELLED", "Request was cancelled unexpectedly.")
	elif data[0] == 2:
		emit_signal("error", "UNKNOWN", "An unknown error occured on server side.")
	elif data[0] == 3:
		emit_signal("error", "INVALID_ARGUMENT", "An argument is invalid, report this bug on https://github.com/Virus-Axel/godot-solana")
	elif data[0] == 4:
		emit_signal("error", "INVALID_ARGUMENT", "The deadline expired before the operation could complete.")
	elif data[0] == 5:
		emit_signal("error", "NOT_FOUND", "A requested entity was not found.")
	elif data[0] == 6:
		emit_signal("error", "ALREADY_EXISTS", "An entity could not be created because it already exists.")
	elif data[0] == 7:
		emit_signal("error", "PERMISSION_DENIED", "You do not have permission to execute the specified operation.")
	elif data[0] == 8:
		emit_signal("error", "RESOURCE_EXHAUSTED", "Some resource has been exhausted.")
	elif data[0] == 9:
		emit_signal("error", "FAILED_PRECONDITION", "The operation was rejected because the system is not in a state required for the operation's execution.")
	elif data[0] == 10:
		emit_signal("error", "ABORTED", "The requested operation was aborted.")
	elif data[0] == 11:
		emit_signal("error", "OUT_OF_RANGE", "The operation was attempted past the valid range.")
	elif data[0] == 12:
		emit_signal("error", "UNIMPLEMENTED", "The operation is not implemented or is not supported/enabled in this service.")
	elif data[0] == 13:
		emit_signal("error", "INTERNAL", "Service has experienced an internal error.")
	elif data[0] == 14:
		emit_signal("error", "UNAVAILABLE", "The service is currently unavailable.")
	elif data[0] == 15:
		emit_signal("error", "DATA_LOSS", "Unrecoverable data loss or corruption.")
	elif data[0] == 16:
		emit_signal("error", "UNAUTHENTICATED", "The request does not have valid authentication credentials for the operation.")
	elif data[0] != 0:
		emit_signal("error", "INVALID_ARGUMENT", "An argument is invalid, report this bug on https://github.com/Virus-Axel/godot-solana")
	
	# Response codes are good	
	else:
		var response_body: PackedByteArray = data[3]
		
		var json = JSON.new()
		json.parse(response_body.get_string_from_utf8())
		
		var response_data: Dictionary = json.get_data()
		
		# Validate response data
		if not response_data.has("result"):
			emit_signal("error", "INTERNAL", "Unexpected response data.")
		if typeof(response_data['result']) != TYPE_DICTIONARY:
			return response_data['result']
		if not response_data['result'].has("value"):
			return response_data['result']
		else:
			return response_data['result']['value']

	# Error paths end up here, return empty Dictionary
	return {}


func send_rpc_request(method: String, params: Array) -> Variant:
	var body = create_request_body(method, params)
	
	var error = request(url, HTTP_HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		
	return parse_response_data(await request_completed)


func create_request_body(method: String, params: Array) -> String:
	var dict := {
		"id": unique_id,
		"jsonrpc": "2.0",
		"method": method,
		"params": params,
	}
	var body: String = JSON.new().stringify(dict)
	return body


func get_account_info(account: String, commitment: String = "finalized", data_offset: int = 0, data_length: int = MAX_GODOT_INT) -> Dictionary:
	var config := {
		"encoding": "base64",
		"commitment": commitment,
	}
	if data_offset != 0 or data_length != MAX_GODOT_INT:
		config.merge({"dataSlice": {"offset": data_offset, "length": data_length}})
	
	return await send_rpc_request("getAccountInfo", [account, config])


func get_balance(account: String, commitment: String = "finalized") -> float:
	var config = {
		"commitment": commitment
	}
	return await send_rpc_request("getBalance", [account, config])


func get_block_height(commitment: String = "finalized") -> int:
	var config = {
		"commitment": commitment
	}
	return await send_rpc_request("getBlockHeight", [config])


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	print(json.get_data())

