/// @description Provides a JSON-RPC 2.0 server-side protocol handler for a `Struct.Server`.
/// @param {Struct.Server} server The server instance to provide JSON-RPC 2.0 protocol.
function JsonRpcServerProtocol(server) constructor
{
	/// @type {Struct.Logger}
	/// @description The logger.
	static _logger = new Logger(nameof(JsonRpcServerProtocol));
	
	/// @type {Struct.Server}
	/// @description The server instance.
	_server = server;
	
	/// @type {Id.DsMap}
	/// @description The request/promise to requset handler map.
	_request_to_handler_map = ds_map_create();
	
	/// @description Registers a JSON-RPC 2.0 request handler.
	/// @param {String} procedure The procedure (or 'method') the register.
	/// @param {Function} callback The function to execute when the method is received.
	register = function(procedure, callback)
	{
		_logger.log(log_type.debug, $"Registering JSON-RPC 2.0 Request Handler for '{procedure}'...");
		_request_to_handler_map[? procedure] = callback;
	}
	
	/// @description Sends a JSON-RPC 2.0 notification to the specified `connection`.
	/// @param {Struct.ClientConnection} connection The connection to receive the notification.
	/// @param {String} procedure The procedure to send to the `connection`.
	/// @param {Struct} params The parameters of the procedure to send to the `connection`
	notify = function(connection, procedure, params)
	{
		var payload = {
			jsonrpc: "2.0",
			method: procedure,
			params: params,
		};
		
		connection.send(payload);
	}
	
	/// @description Broadcasts a JSON-RPC 2.0 notification to all connections.
	/// @param {String} procedure The procedure to broadcast.
	/// @param {Struct} params The parameters of the procedure to broadcast.
	broadcast = function(procedure, params)
	{
		var payload = {
			jsonrpc: "2.0",
			method: procedure,
			params: params,
		};
		
		_server.broadcast(payload);
	}
	
	/// @description Handles an incoming `payload` from the specified `socket`.
	/// @param {Id.Socket} socket The socket identifier that sent the `payload`.
	/// @param {String} payload The payload sent by the `socket`.
	handle_message = function(socket, payload)
	{
		var message = undefined;
		var connection = _server.get_connection(socket);
		
		if (is_undefined(connection))
		{
			return;
		}
		
		try
		{
			message = json_parse(payload);
		}
		catch (ex)
		{
			connection.send({
				jsonrpc: "2.0",
				error: {
					id: undefined,
					code: -32700,
					message: "Parse Error",
				},
			});
			
			return;
		}
		
		var jsonrpc = struct_get(message, "jsonrpc");
        var rpc_id = struct_get(message, "id");
		
		var procedure = struct_get(message, "method");
        var params = struct_get(message, "params");
		
		var is_request = !is_undefined(rpc_id);
		
		if (is_undefined(jsonrpc) || jsonrpc != "2.0" ||
			is_undefined(procedure) || !is_string(procedure))
        {
			connection.send({
				jsonrpc: "2.0",
				id: rpc_id,
				error: {
					code: -32600,
					message: "Invalid Request",
				},
			});
			
			return;
        }
		
		var handler = _request_to_handler_map[? procedure];

		if (is_undefined(handler))
		{
			if (is_request)
			{
				connection.send({
					jsonrpc: "2.0",
					id: rpc_id,
					error: {
						code: -32601,
						message: "Method Not Found",
					},
				});
			}
			
			return;
		}
		
		try
		{
			// TODO: Test this notify, broadcast, connection and rpc_id
			var result = method({self, connection, rpc_id}, handler)(params);
			
			if (!is_instanceof(result, Promise))
			{
				if (is_request)
				{
					connection.send({
						jsonrpc: "2.0",
						id: rpc_id,
						result: result,
					});
				}
			}
			else
			{
				if (is_request)
				{
					result
						// TODO: Test this notify, broadcast, connection and rpc_id
						.next(method({self, connection, rpc_id}, function(value) {
							connection.send({
								jsonrpc: "2.0",
								id: rpc_id,
								result: value,
							});
						}))
						// TODO: Test this notify, broadcast, connection and rpc_id
						.fail(method({self, connection, rpc_id}, function(error) {
							if (!is_instanceof(error, RpcError))
							{
								_logger.log(log_type.error, $"Internal server error: {error}");
					
								connection.send({
									jsonrpc: "2.0",
									id: rpc_id,
									error: {
										code: -32603,
										message: "Internal Error",
									},
								});
					
								return;
							}
				
							connection.send({
								jsonrpc: "2.0",
								id: rpc_id,
								error: {
									code: -32000,
									message: instanceof(error),
									data: error,
								},
							});
						}));
				}
			}
		}
		catch (ex)
		{
			if (is_request)
			{
				if (!is_instanceof(ex, RpcError))
				{
					_logger.log(log_type.error, $"Internal server error: {ex.message}");
					
					connection.send({
						jsonrpc: "2.0",
						id: rpc_id,
						error: {
							code: -32603,
							message: "Internal Error",
						},
					});
					
					return;
				}
				
				connection.send({
					jsonrpc: "2.0",
					id: rpc_id,
					error: {
						code: -32000,
						message: instanceof(ex),
						data: ex,
					},
				});
			}
		}
	}
	
	/// @description Cleanup resources.
	cleanup = function()
	{
		ds_map_destroy(_request_to_handler_map);
	}
}