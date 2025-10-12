function JsonRpcClientProtocol(client) constructor
{
	/// @type {Struct.Client}
	/// @description The client.
	_client = client;
	
	/// @type {Id.DsMap}
	/// @description The command/request to handler map.
	_command_to_handler_map = ds_map_create();
	
	/// @description Registers a JSON-RPC 2.0 notification handler.
	/// @param {String} procedure The procedure to register.
	/// @param {Function} callback The callback to execute when the notification arrives.
	register = function(procedure, callback)
	{
		_command_to_handler_map[? procedure] = callback;
	}
	
	/// @description Sends a JSON-RPC 2.0 notification to the server.
	/// @param {String} procedure The procedure to send to the server.
	/// @param {Struct} params To the parameteres of the procedure to send to the server.
	notify = function(procedure, params)
	{
		var payload = {
			jsonrpc: "2.0",
			method: procedure,
			params: params,
		};
		
		_client.send(payload);
	}
	
	/// @description Sends a JSON-RPC 2.0 request to the server.
	/// @param {String} procedure The procedure to send to the server.
	/// @param {Struct} params To the parameteres of the procedure to send to the server.
	call = function(procedure, params)
	{
		static rpc_id = 0;
		rpc_id++;
		
		var promise = new Promise();
		
		var payload = {
			jsonrpc: "2.0",
			id: rpc_id,
			method: procedure,
			params: params,
		};
		
		_client.send(payload);
		_command_to_handler_map[? rpc_id] = promise;
		
		return promise;
	}
	
	/// @description Handles an incoming `payload` from the server.
	/// @param {String} payload The payload sent to the client.
	handle_message = function(payload)
	{
		var message = undefined;
		
		try
		{
			message = json_parse(payload);
		}
		catch (ex)
		{
			show_debug_message("Error: Received malformed JSON from server.");
			return;
		}
		
		var jsonrpc = struct_get(message, "jsonrpc");
		var rpc_id = struct_get(message, "id");
		
		if (is_undefined(jsonrpc) || jsonrpc != "2.0")
        {
            show_debug_message("Error: Received message with invalid/missing jsonrpc field; ignoring.");
            return;
        }
		
		if (!is_undefined(rpc_id))
		{
			var promise = _command_to_handler_map[? rpc_id];
			
			if (is_undefined(promise))
			{
				show_debug_message($"Error: Failed to locate request handler for ID: '{rpc_id}'");
				return;
			}
			
			ds_map_delete(_command_to_handler_map, rpc_id);
			
			if (is_instanceof(promise, Promise))
			{
				var result = struct_get(message, "result");
				var error = struct_get(message, "error");
				
				if (!is_undefined(result))
				{
					// TODO: Test this notify, call, etc.
					method(self, promise.resolve)(result);
				}
				else if (!is_undefined(error))
				{
					// TODO: Test this notify, call, etc.
					method(self, promise.reject)(error);
				}
			}
		}
		else
		{
			var procedure = struct_get(message, "method");
	        var params = struct_get(message, "params");
		
			if (!is_undefined(procedure))
			{
				var handler = _command_to_handler_map[? procedure];
			
				if (is_undefined(handler))
				{
					show_debug_message($"Error: Failed to locate handler for procedure: '{procedure}'");
					return;
				}
			
				// TODO: Test this notify, call, etc.
				method(self, handler)(params);
			}	
		}
	}
	
	/// @description Cleanup resources.
	cleanup = function()
	{
		ds_map_destroy(_command_to_handler_map);
	}
}