# Response to: "Protocol version in stdio messages"

## Problem Statement
"It seem like you expect a protocol version in stdio messages but they aren't in the specification."

## Resolution

After thorough review of the implementation and MCP specification, we confirm:

### The Implementation is Correct ✅

The server does **NOT** expect protocol version in stdio messages (except during initialization), which correctly follows the MCP specification.

### MCP Specification Requirements

#### stdio Transport
Per the MCP specification (transports.md):
- Protocol version is exchanged **ONLY** during the `initialize` request and response
- Subsequent messages are standard JSON-RPC messages **without** protocol version information
- The negotiated version applies for the entire session

#### HTTP Transport  
Per the MCP specification (transports.md, section "Protocol Version Header"):
- Protocol version exchanged during `initialize` (in request body and response)
- Clients **MUST** include `MCP-Protocol-Version` header on **all subsequent requests**
- Required because HTTP is stateless and can support multiple concurrent clients

### Implementation Verification

**stdio handler** (`handle_message_from_client` in R/server.R):
```r
if (data$method == "initialize") {
  client_version <- data$params$protocolVersion  // ← ONLY here
  res <- jsonrpc_response(data$id, capabilities(client_version))
  cat_json(res)
} else if (data$method == "tools/list") {
  // ← No protocol version extraction
  res <- jsonrpc_response(...)
} else if (data$method == "tools/call") {
  // ← No protocol version extraction
  ...
}
```

The function signature confirms this: `handle_message_from_client(line)` has NO `protocol_version` parameter.

**HTTP handler** (`handle_http_request_message` in R/server.R):
```r
handle_http_request_message <- function(data, protocol_version = NULL) {
  // ← Has protocol_version parameter for HTTP
}
```

### Changes Made

While the implementation was already correct, we improved documentation to prevent confusion:

1. **Code comments**: Added explicit note that protocol version handling is HTTP-specific
2. **Function documentation**: Clarified stdio vs HTTP behavior in `@section Protocol Version Support`
3. **Implementation guide** (PROTOCOL_VERSIONS.md): Added section explaining stdio messages don't include version after init
4. **Q&A document** (IMPLEMENTATION_ANSWERS.md): Added prominent explanation of the difference
5. **Test coverage** (test-stdio-version.R): Added test verifying stdio doesn't expect version in messages

### Summary

The implementation correctly follows the MCP specification:
- ✅ stdio: Protocol version ONLY in initialize, NOT in subsequent messages
- ✅ HTTP: Protocol version in initialize + header on all subsequent requests

No code changes were needed - only documentation improvements to clarify the correct behavior.
