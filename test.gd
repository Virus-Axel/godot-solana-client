extends Control


var passes: int = 0
var fails: int = 0

func unit_test(did_pass, function):
	var pass_or_fail = "F: "
	if did_pass:
		passes += 1
		pass_or_fail = "P: "
	else:
		fails += 1
	print(pass_or_fail, function)


# Called when the node enters the scene tree for the first time.
func _ready():
	await test_synchronous_function_calls()
	await test_asynchronous_function_calls()
	
	
	print("\nSummary:")
	print("FAILED: ", fails)
	print("PASSED: ", passes)
	

func test_synchronous_function_calls():
	# Set up
	var client := $SolanaClient
	client.synchronous = true
	
	# Test some functions
	unit_test(await client.get_block_height() != null, "synchronous get_block_height")
	unit_test(await client.get_latest_blockhash() != null, "synchronous get_latest_blockhash")
	unit_test(await client.get_block_time(187801019) != null, "synchronous get_block_time")
	


func test_asynchronous_function_calls():
	# Set up
	var client := $SolanaClient
	client.synchronous = false
	
	# Test some functions
	unit_test(await client.get_block_height() == null, "asynchronous get_block_height send")
	unit_test((await client.rpc_response)[1] != null, "asynchronous get_block_height response")

	unit_test(await client.get_latest_blockhash() == null, "asynchronous get_latest_blockhash send")
	unit_test((await client.rpc_response)[1] != null, "asynchronous get_latest_blockhash response")

	unit_test(await client.get_block_time(187801019) == null, "asynchronous get_block_time send")
	unit_test((await client.rpc_response)[1] != null, "asynchronous get_block_time response")


func error(error_code, error_description):
	print("F: ", error_code, " - ", error_description)
	fails += 1
	
