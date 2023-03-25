# Godot Solana Client
Connect your games to the Solana blockchain. Access the Solana [JSON RPC API](https://docs.solana.com/api/http) from your Godot game. The plugin is written for Godot version 4 and up. It is currently not in the godot asset library.

# Installation
Download the latest release and place the addons folder in the res:// root. The plugin will load when your project is reloaded. The plugin must be enabled in your project settings under the plugins tab.

<p align="center">
<img src="https://raw.githubusercontent.com/Virus-Axel/godot-solana-client/nomerge/screenshots/screenshots/enable_plugin.png"  width="70%" height="70%">
</p>

# Usage
Add a node of type SolanaClient.
<p align="center">
<img src="https://raw.githubusercontent.com/Virus-Axel/godot-solana-client/nomerge/screenshots/screenshots/add_node.png"  width="70%" height="70%">
</p>

You can set the client behavior such as cluster URL, commitment level and minimum context slot. You can also set if your calls will be synchronous or asynchronous.

<p align="center">
<img src="https://raw.githubusercontent.com/Virus-Axel/godot-solana-client/nomerge/screenshots/screenshots/properties.png"  width="60%" height="60%">
</p>

## Synchronous calls

The default value is to use synchronous calls. The methods should then be called with the await keyword as follows
```
var result = await $solana_client_node.get_latest_blockhash()
```

## Asynchronous calls
If you prefer to use asynchronous calls you can get the request responce through signals. A basic example could be
```
var blockhash_request_id = 0

func basic_get_blockhash_example():
    blockhash_request_id = $solana_client_node.unique_id
    $solana_client_node.rpc_response.connect(Callable(self, "handle_response"))
    $solana_client_node.get_latest_blockhash()

func handle_response(id, value):
    if id == blockhash_request_id:
        print("Latest blockhash is:", value)
```

## Signals
There are two signals in the SolanaClient node apart from the inherited signals.

<p align="center">
<img src="https://raw.githubusercontent.com/Virus-Axel/godot-solana-client/nomerge/screenshots/screenshots/signals.png"  width="60%" height="60%">
</p>

There is an error signal and a rpc_response signal. The rpc_response signal would only be used when dealing with asynchronous calls as shown in the example. It will pass the request ID that was passed with the request. The unique ID class property will increment by one by each request and can be used to keep track the requests and responses.

## Error Handling
The error signal can be used to get error information. The signal passes an error Identifier and a short description of the error. A list of possible errors can be found here: [GRPC status codes](https://github.com/grpc/grpc/blob/master/doc/statuscodes.md).

When using synchronous calls the return values can also indicate errors. When an error occurred, the methods will return null. For asynchronous calls the return values will always be null.
