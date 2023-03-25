@tool
@icon("res://addons/solana_client/icon.png")

extends HTTPRequest


const HTTP_HEADERS: PackedStringArray = ["Content-Type: application/json", "Accept-Encoding: json"]
const MAX_GODOT_INT: int = 9223372036854775807


@export var unique_id: int = 0
var commitment: String = "finalized"

@export var synchronous := true:
	set(value):
		synchronous = value
		toggle_connect_response()

@export var enable_minimum_context_slot := false:
	set(value):
		enable_minimum_context_slot = value
		notify_property_list_changed()


var minimum_context_slot: int = 0
var url: String = "https://api.testnet.solana.com"


signal error(error_code: String, error_description: String)
signal rpc_response(request_id: int, value: Variant)

func _get_property_list():
	var property_usage = PROPERTY_USAGE_NO_EDITOR

	if enable_minimum_context_slot:
		property_usage = PROPERTY_USAGE_DEFAULT

	return [
	{
		"name": "commitment",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "processed,confirmed,finalized"
	},
	{
		"name": "url",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM_SUGGESTION,
		"hint_string": "https://api.testnet.solana.com,https://api.devnet.solana.com,https://api.mainnet.solana.com,http://localhost:8899"
	},
	{
		"name": "minimum_context_slot",
		"type": TYPE_INT,
		"usage": property_usage,
		"hint": PROPERTY_HINT_INT_IS_OBJECTID,
	}]

# Called when the node enters the scene tree for the first time.
func _ready():
	var random_number: PackedInt64Array = rand_from_seed(Time.get_unix_time_from_system())
	unique_id = random_number[0]
	#print(await get_block_height())
	#print(await get_balance("6WEPfubN443TJ4tr8z2SsP8f3o1eXRzn4Wv2X2ykY4JX"))
	#print(await get_account_info("6WEPfubN443TJ4tr8z2SsP8f3o1eXRzn4Wv2X2ykY4JX"))
	#print(await get_block_production("finalized", "", 186173845, 186173846))
	#print(await get_block_commitment(7))
	#print(await get_blocks(124091904, 124091904 + 100))
	#print(await get_blocks_with_limit(799279, 200))
	#print(await get_block_time(146295254))
	#print(await get_cluster_nodes())
	#print(await get_epoch_info())


func increment_unique_id():
	if unique_id == MAX_GODOT_INT:
		unique_id = 0
	else:
		unique_id += 1


func toggle_connect_response():
	if synchronous:
		request_completed.disconnect(Callable(self, "handle_asynchronous_response"))
	else:
		request_completed.connect(Callable(self, "handle_asynchronous_response"))

func parse_response_data(data: Array) -> Variant:
	if data.is_empty():
		emit_signal("error", "INTERNAL", "HTTP response data is invalid.")
	
	# Check HTTP status code
	elif data[1] == 0:
		emit_signal("error", "NO_RESPONSE", "No response from a server at " + url)
	
	elif data[1] != 200:
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
		if response_data.has("error"):
			emit_signal("error", "INTERNAL", response_data['error']['message'])
		elif not response_data.has("result"):
			emit_signal("error", "INTERNAL", "Unexpected response data.")
		elif typeof(response_data['result']) != TYPE_DICTIONARY:
			emit_signal("rpc_response", response_data['id'], response_data['result'])
			return response_data['result']
		elif not response_data['result'].has("value"):
			emit_signal("rpc_response", response_data['id'], response_data['result'])
			return response_data['result']
		else:
			emit_signal("rpc_response", response_data['id'], response_data['result']['value'])
			return response_data['result']['value']

	# Error paths end up here, return empty Dictionary
	return null


func send_rpc_request(method: String, params: Array) -> Variant:
	var body: String = create_request_body(method, params)

	var error = request(url, HTTP_HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
	
	increment_unique_id()
	
	if synchronous:
		return parse_response_data(await request_completed)
	else:
		return null


func create_request_body(method: String, params: Array) -> String:
	var dict: Dictionary = {
		"id": unique_id,
		"jsonrpc": "2.0",
		"method": method,
		"params": params,
	}
	var body: String = JSON.new().stringify(dict)
	
	return body


func get_account_info(account: String, data_offset: int = 0, data_length: int = MAX_GODOT_INT) -> Variant:
	var config: Dictionary = {
		"encoding": "base64",
		"commitment": commitment,
	}
	if data_offset != 0 or data_length != MAX_GODOT_INT:
		config.merge({"dataSlice": {"offset": data_offset, "length": data_length}})
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	
	return await send_rpc_request("getAccountInfo", [account, config])


func get_balance(account: String) -> Variant:
	var config: Dictionary = {
		"commitment": commitment
	}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	return await send_rpc_request("getBalance", [account, config])


func get_block_height() -> Variant:
	var config: Dictionary = {
		"commitment": commitment
	}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})

	return await send_rpc_request("getBlockHeight", [config])


func get_block_production(identity: String = "", first_slot: int = 0, last_slot: int = -1) -> Variant:
	var config: Dictionary = {
		"commitment": commitment
	}
	if not identity.is_empty():
		config.merge({"identity": identity})
	if last_slot != -1:
		config.merge({"range": {
			"firstSlot": first_slot,
			"lastSlot": last_slot,
		}})
	elif first_slot != 0:
		config.merge({"firstSlot": first_slot})
	
	return await send_rpc_request("getBlockProduction", [config])


func get_block_commitment(block_number: int) -> Variant:
	return await send_rpc_request("getBlockCommitment", [block_number])


func get_blocks(start_block: int, end_block: int = -1):
	var config: Array = [start_block]
	if end_block != -1:
		config.push_back(end_block)
	config.push_back({"commitment": commitment,})

	return await send_rpc_request("getBlocks", config)


func get_blocks_with_limit(start_block: int, limit: int = -1):
	var config: Array = [start_block]
	if limit != -1:
		config.push_back(limit)
	config.push_back({"commitment": commitment,})

	return await send_rpc_request("getBlocksWithLimit", config)


func get_block_time(block_number: int) -> Variant:
	return await send_rpc_request("getBlockTime", [block_number])


func get_cluster_nodes() -> Variant:
	return await send_rpc_request("getClusterNodes", [])


func get_epoch_info() -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	return await send_rpc_request("getEpochInfo", [config])


func get_epoch_schedule() -> Variant:
	return await send_rpc_request("getEpochSchedule", [])


func get_fee_for_message(message: String, is_message_encoded := true) -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	if not is_message_encoded:
		return await send_rpc_request("getFeeForMessage", [bs64.encode(message.to_utf8_buffer())])
	else:
		return await send_rpc_request("getFeeForMessage", [message])


func get_first_available_block() -> Variant:
	return await send_rpc_request("getFirstAvailableBlock", [])


func get_genesis_hash() -> Variant:
	return await send_rpc_request("getGenesisHash", [])


func get_health() -> Variant:
	return await send_rpc_request("getHealth", [])


func get_highest_snapshot_slot() -> Variant:
	return await send_rpc_request("getHighestSnapshotSlot", [])


func get_identity() -> Variant:
	return await send_rpc_request("getIdentity", [])


func get_inflation_governor() -> Variant:
	return await send_rpc_request("getInflationGovernor", [{"commitment": commitment}])


func get_inflation_rate() -> Variant:
	return await send_rpc_request("getInflationRate", [])
	

func get_inflation_reward(query_addresses: Array = [], epoch: int = -1) -> Variant:
	var config: Dictionary = {
		"commitment": commitment
	}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	if epoch != -1:
		config.merge({"epoch": epoch})

	if query_addresses.is_empty():
		return await send_rpc_request("getInflationReward", [config])
	else:
		return await send_rpc_request("getInflationReward", [query_addresses, config])


func get_largest_accounts(filter: String = "") -> Variant:
	var config: Dictionary = {
		"commitment": commitment
	}
	if filter != "":
		config.merge({"filter": filter})

	return await send_rpc_request("getLargestAccounts", [config])


func get_latest_blockhash() -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	return await send_rpc_request("getLatestBlockhash", [config])


func get_leader_schedule(identity: String = "", slot: int = -1) -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if identity != "":
		config.merge({"identity": identity})
	
	if slot == -1:
		return await send_rpc_request("getLeaderSchedule", [config])
	else:
		return await send_rpc_request("getLeaderSchedule", [slot, config])


func get_max_retransmit_slot() -> Variant:
	return await send_rpc_request("getMaxRetransmitSlot", [])
	

func get_max_shred_insert_slot() -> Variant:
	return await send_rpc_request("getMaxShredInsertSlot", [])


func get_minimum_balance_for_rent_exemption(size: int = -1) -> Variant:
	if size != -1:
		return await send_rpc_request("getMinimumBalanceForRentExemption", [size, {"commitment": commitment}])
	else:
		return await send_rpc_request("getMinimumBalanceForRentExemption", [{"commitment": commitment}])


func get_multiple_accounts(accounts: Array = [], offset: int = 0, length: int = MAX_GODOT_INT) -> Variant:
	var config: Dictionary = {
		"commitment": commitment,
		"encoding": "base64",
	}
	
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	if length != MAX_GODOT_INT or offset != 0:
		config.merge({"dataSlice": {"offset": offset, "length": length}})

	if accounts.is_empty():
		return await send_rpc_request("getMultipleAccounts", [config])
	else:
		return await send_rpc_request("getMultipleAccounts", [accounts, config])


func get_program_accounts(program_id: String, filters: Array = [], offset: int = 0, length: int = MAX_GODOT_INT) -> Variant:
	var config: Dictionary = {
		"commitment": commitment,
		"encoding": "base64",
	}
	
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	if length != MAX_GODOT_INT or offset != 0:
		config.merge({"dataSlice": {"offset": offset, "length": length}})
	if filters:
		config.merge({"filters": filters})
		
	return await send_rpc_request("getProgramAccounts", [config])


func get_recent_performance_samples(limit: int) -> Variant:
	return await send_rpc_request("getRecentPerformanceSamples", [limit])


func get_recent_prioritization_fees(account_addresses: Array = []) -> Variant:
	if account_addresses:
		return await send_rpc_request("getRecentPrioritizationFees", [account_addresses])
	else:
		return await send_rpc_request("getRecentPrioritizationFees", [])


func get_signatures_for_address(account: String, limit: int = 1000, before: String = "", until: String = "") -> Variant:
	var config: Dictionary = {
		"commitment": commitment,
		"limit": limit,
	}
	
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	if not before.is_empty():
		config.merge({"before": before})
	if not until.is_empty():
		config.merge({"until": until})
		
	return await send_rpc_request("getSignaturesForAddress", [account, config])


func get_signature_statuses(signatures: Array = [], search_transaction_history := false) -> Variant:
	if signatures:
		return await send_rpc_request("getSignatureStatuses", [signatures, {"searchTransactionHistory": search_transaction_history}])
	else:
		return await send_rpc_request("getSignatureStatuses", [{"searchTransactionHistory": search_transaction_history}])


func get_slot() -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	return await send_rpc_request("getSlot", [config])


func get_slot_leader() -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	return await send_rpc_request("getSlotLeader", [config])


func get_slot_leaders(start_slot: int = -1, limit: int = 10) -> Variant:
	if start_slot != -1:
		return await send_rpc_request("getSlotLeaders", [])
	else:
		return await send_rpc_request("getSlotLeaders", [start_slot, limit])


func get_stake_activation(stake_account: String, epoch: int = -1) -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	if epoch != -1:
		config.merge({"epoch": epoch})
		
	return await send_rpc_request("getStakeActivation", [stake_account, config])


func get_stake_minimum_delegation() -> Variant:
	return await send_rpc_request("getStakeMinimumDelegation", [{"commitment": commitment}])


func get_supply(signatures: Array = [], exclude_non_circulating_accounts_list := false) -> Variant:
	return await send_rpc_request("getSupply", [{"excludeNonCirculatingAccountsList": exclude_non_circulating_accounts_list}])


func get_token_account_balance(token_account: String) -> Variant:
	return await send_rpc_request("getTokenAccountBalance", [token_account, {"commitment": commitment}])


func get_token_accounts_by_delegate(deligate_account: String, mint_account: String = "", program_id: String = "", offset: int = 0, length: int = MAX_GODOT_INT) -> Variant:
	var arg1: Dictionary = {}
	var arg2: Dictionary = {
		"commitment": commitment,
		"encoding": "base64",
	}

	if enable_minimum_context_slot:
		arg2.merge({"minContextSlot": minimum_context_slot})
	if not mint_account.is_empty():
		arg1 = {"mint": mint_account}
	if not program_id.is_empty():
		arg1.merge({"programId": program_id})
	if length != MAX_GODOT_INT or offset != 0:
		arg2.merge({"dataSlice": {"offset": offset, "length": length}})
		
	return await send_rpc_request("getTokenAccountsByDelegate", [deligate_account, arg1, arg2])


func get_token_accounts_by_owner(owner_account: String, mint_account: String = "", program_id: String = "", offset: int = 0, length: int = MAX_GODOT_INT) -> Variant:
	var arg1: Dictionary = {}
	var arg2: Dictionary = {
		"commitment": commitment,
		"encoding": "base64",
	}

	if enable_minimum_context_slot:
		arg2.merge({"minContextSlot": minimum_context_slot})
	if not mint_account.is_empty():
		arg1 = {"mint": mint_account}
	if not program_id.is_empty():
		arg1.merge({"programId": program_id})
	if length != MAX_GODOT_INT or offset != 0:
		arg2.merge({"dataSlice": {"offset": offset, "length": length}})
		
	return await send_rpc_request("getTokenAccountsByOwner", [owner, arg1, arg2])


func get_token_largest_accounts(token_mint: String) -> Variant:
	return await send_rpc_request("getTokenLargestAccounts", [token_mint, {"commitment": commitment}])


func get_token_supply(token_mint: String) -> Variant:
	return await send_rpc_request("getTokenSupply", [token_mint, {"commitment": commitment}])


func get_transaction(token_mint: String, max_supported_transaction_version: int = -1) -> Variant:
	if max_supported_transaction_version != -1:
		return await send_rpc_request("getTransaction", [token_mint, {"commitment": commitment, "maxSupportedTransactionVersion": max_supported_transaction_version}])
	else:
		return await send_rpc_request("getTransaction", [token_mint, {"commitment": commitment}])


func get_transaction_count() -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	return await send_rpc_request("getTransactionCount", [config])


func get_version() -> Variant:
	return await send_rpc_request("getVersion", [])


func get_vote_accounts(vote_pubkey: String = "", keep_unstaked_delinquents = false, delinquent_slot_distance = -1) -> Variant:
	var config = {
		"commitment": commitment,
		"keepUnstakedDelinquents": keep_unstaked_delinquents,
	}
	if not vote_pubkey.is_empty():
		config.merge({"votePubkey": vote_pubkey})
	if delinquent_slot_distance != -1:
		config.merge({"delinquentSlotDistance": delinquent_slot_distance})
		
	return await send_rpc_request("getVoteAccounts", [config])


func is_blockhash_valid() -> Variant:
	var config: Dictionary = {"commitment": commitment}
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
		
	return await send_rpc_request("isBlockhashValid", [config])


func minimum_ledger_slot() -> Variant:
	return await send_rpc_request("minimumLedgerSlot", [])


func request_airdrop(account: String, amount: int) -> Variant:
	return await send_rpc_request("requestAirdrop", [account, amount, {"commitment": commitment}])


func send_transaction(transaction: String, encoded := true, skip_preflight := false, preflight_commitment: String = "finalized", max_retries: int = -1) -> Variant:
	var config = {
		"commitment": commitment,
		"encoding": "base64",
		"skipPreflight": skip_preflight,
		"preflight_commitment": preflight_commitment,
	}
	
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	if max_retries != -1:
		config.merge({"maxRetries": max_retries})
		
	var encoded_transaction: String = transaction
	if not encoded:
		encoded_transaction = bs64.encode(transaction.to_utf8_buffer())
		
	return await send_rpc_request("sendTransaction", [encoded_transaction, config])


func simulate_transaction(transaction: String, encoded := true, sig_verify := false, replace_recent_blockhash := false, return_accounts: Array = []) -> Variant:
	var config: Dictionary = {
		"commitment": commitment,
		"sigVerify": sig_verify,
		"replaceRecentBlockhash": replace_recent_blockhash,
		"encoding": "base64",
	}
	
	if enable_minimum_context_slot:
		config.merge({"minContextSlot": minimum_context_slot})
	if return_accounts:
		config.merge({
			"accounts": {
				"addresses": return_accounts,
				"encoding": "base64",
			}
		})
	
	return await send_rpc_request("simulateTransaction", [transaction, config])


func set_commitment(new_commitment: String) -> void:
	commitment = new_commitment


func get_commitment() -> String:
	return commitment


func handle_asynchronous_response(result, response_code, headers, body) -> void:
	parse_response_data([result, response_code, headers, body])


func create_filter(offset: int = -1, match_data: String = "", encoded: bool = true, data_size: int = -1):
	var ret: Dictionary = {}
	
	if offset != -1:
		var encoded_data = match_data
		if not encoded:
			encoded_data = bs64.encode(match_data.to_utf8_buffer())
		ret.merge({"memcmp": {
			"offset": offset,
			"bytes": encoded_data,
			"encoding": "base64",
		}})
	
	if data_size != -1:
		ret.merge({"dataSize": data_size})
	
	return ret
