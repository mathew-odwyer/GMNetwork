/// @description Represents an error that is thrown when a `Struct.Server` fails to be created.
/// @param {String} message The message that describes the error.
/// @param {Struct|Undefined} inner_error The inner error that was thrown (if any).
/// @remarks This error is usualyl thrown because the socket cannot bind to the provided port.
function ServerCreationError(message, inner_error = undefined) : Error(message, inner_error) constructor
{
}