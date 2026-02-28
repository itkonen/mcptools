# Multi-Version Protocol Support Implementation

This document explains how the mcptools MCP server has been organized to support multiple protocol versions.

## Overview

The server now supports multiple versions of the Model Context Protocol (MCP) and negotiates the version with clients during initialization, as specified in the MCP specification: https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle

## Supported Versions

Currently supported versions (from latest to oldest):
- `2025-11-25` (latest)
- `2025-06-18`
- `2025-03-26`
- `2024-11-05`

## Architecture

The implementation is organized into the following components:

### 1. Version Negotiation Module (`R/version.R`)

This new file contains all version-related logic:

- **`supported_mcp_versions()`**: Returns a vector of supported protocol versions, ordered from latest to oldest.
  
- **`negotiate_version(client_version)`**: Implements the MCP version negotiation algorithm:
  - If the server supports the client's requested version, it returns that version
  - Otherwise, it returns the latest version the server supports
  
- **`is_supported_version(version)`**: Validates whether a given version string is supported

### 2. Server Initialization (`R/server.R`)

The server has been updated to negotiate versions during initialization:

#### stdio Transport

For stdio transport (the default), version negotiation happens in `handle_message_from_client()`:

```r
if (data$method == "initialize") {
  client_version <- data$params$protocolVersion
  res <- jsonrpc_response(data$id, capabilities(client_version))
  cat_json(res)
}
```

The `capabilities()` function now accepts an optional `client_version` parameter and negotiates the appropriate version.

#### HTTP Transport

For HTTP transport, version negotiation is more complex due to the need to handle multiple simultaneous clients:

1. **During initialization**: In `handle_http_request_message()`, the client version is extracted from the request body and used to negotiate:

```r
if (data$method == "initialize") {
  client_version <- data$params$protocolVersion
  return(jsonrpc_response(data$id, capabilities(client_version)))
}
```

2. **After initialization**: Per the MCP spec, clients must include the `MCP-Protocol-Version` header on all subsequent requests. This is validated in `handle_http_post()`:

```r
# Extract and validate MCP-Protocol-Version header for non-initialize requests
protocol_version <- req$HTTP_MCP_PROTOCOL_VERSION

# For initialize requests, protocol version comes from the request body
# For subsequent requests, it should come from the HTTP header
if (!identical(data$method, "initialize")) {
  # Per spec: if no header, assume 2025-03-26 for backwards compatibility
  if (is.null(protocol_version)) {
    protocol_version <- "2025-03-26"
  }
  
  # Validate the protocol version
  if (!is_supported_version(protocol_version)) {
    return(list(
      status = 400L,
      headers = list("Content-Type" = "application/json"),
      body = to_json(list(
        error = "Invalid or unsupported MCP-Protocol-Version",
        data = list(
          provided = protocol_version,
          supported = supported_mcp_versions()
        )
      ))
    ))
  }
}
```

### 3. Capabilities Function

The `capabilities()` function has been updated to accept an optional `client_version` parameter:

```r
capabilities <- function(client_version = NULL) {
  # Negotiate protocol version with client
  negotiated_version <- if (!is.null(client_version)) {
    negotiate_version(client_version)
  } else {
    # Default to latest if no client version provided
    supported_mcp_versions()[1]
  }
  
  list(
    protocolVersion = negotiated_version,
    # ... rest of capabilities
  )
}
```

## Testing

Comprehensive tests have been added in two files:

### Unit Tests (`tests/testthat/test-version.R`)

- Tests for `supported_mcp_versions()`
- Tests for `negotiate_version()` with supported and unsupported versions
- Tests for `is_supported_version()`
- Tests for `capabilities()` version negotiation

### Integration Tests (`tests/testthat/test-http-version.R`)

- Tests HTTP header validation for `MCP-Protocol-Version`
- Tests backwards compatibility (defaulting to `2025-03-26` when no header is present)
- Tests version negotiation during initialize
- Tests error handling for invalid protocol versions

## Adding Support for New Versions

To add support for a new protocol version:

1. **Update `supported_mcp_versions()` in `R/version.R`**:
   Add the new version string at the beginning of the returned vector (so it's the latest).

2. **Implement version-specific behavior** (if needed):
   If the new version requires different behavior, you can check the negotiated version in relevant functions:
   
   ```r
   if (negotiated_version >= "2026-01-01") {
     # New version-specific behavior
   } else {
     # Backwards compatible behavior
   }
   ```

3. **Update tests**:
   Add test cases for the new version in `test-version.R` and `test-http-version.R`.

4. **Update documentation**:
   Update the "Protocol Version Support" section in the `mcp_server()` documentation.

## Version-Specific Behavior

Currently, all supported versions use the same server behavior. However, the architecture is designed to support version-specific behavior in the future:

- The negotiated version is passed through the call chain and is available to functions that need it
- The `protocol_version` parameter in `handle_http_request_message()` can be used to implement version-specific behavior for different methods
- For stdio transport, you could store the negotiated version in a session variable if needed for later requests

## Backwards Compatibility

The implementation maintains backwards compatibility:

- For stdio transport: The server continues to work with older clients that send older protocol versions
- For HTTP transport: If no `MCP-Protocol-Version` header is present, the server assumes version `2025-03-26` as per the MCP specification
- The server always tries to use the client's requested version if it's supported, ensuring maximum compatibility

## Key Design Decisions

1. **Centralized version management**: All version-related logic is in `R/version.R`, making it easy to add new versions.

2. **Graceful degradation**: If a client requests an unsupported version, the server responds with its latest supported version rather than erroring.

3. **HTTP header validation**: For HTTP transport, the server strictly validates the protocol version header to prevent protocol mismatches.

4. **Backwards compatibility**: The default to `2025-03-26` for missing headers ensures older HTTP clients continue to work.

5. **Minimal changes**: The implementation adds new functionality without breaking existing code or tests.
