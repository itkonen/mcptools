# Answers to Problem Statement Questions

This document answers the specific questions posed in the problem statement about implementing multi-version protocol support.

## Question 1: What needs to be changed to implement other versions?

To add support for a new protocol version, you need to:

### 1. Update the supported versions list
In `R/version.R`, update the `supported_mcp_versions()` function:

```r
supported_mcp_versions <- function() {
  c(
    "2026-XX-XX",      # <- Add new version at the top (latest first)
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05"
  )
}
```

### 2. Implement version-specific behavior (if needed)
If the new version requires different server behavior:

```r
# Example: In a function that handles requests
if (negotiated_version >= "2026-XX-XX") {
  # New version-specific behavior
  handle_new_feature()
} else {
  # Backwards compatible behavior
  handle_old_way()
}
```

### 3. Update tests
Add test cases for the new version in:
- `tests/testthat/test-version.R` - Unit tests
- `tests/testthat/test-http-version.R` - Integration tests

### 4. Update documentation
- Update the "Protocol Version Support" section in `R/server.R`
- Add entry to `NEWS.md`
- Update `PROTOCOL_VERSIONS.md` if there are architecture changes

That's it! The version negotiation logic will automatically handle the new version.

## Question 2: How should the code be organized to support multiple protocol versions?

The code has been organized with the following architecture:

### Separation of Concerns

1. **Version Management Module** (`R/version.R`)
   - All version-related logic in one place
   - Easy to update when adding new versions
   - Clean API with three functions:
     - `supported_mcp_versions()` - source of truth for supported versions
     - `negotiate_version()` - implements negotiation algorithm
     - `is_supported_version()` - validation helper

2. **Server Initialization** (`R/server.R`)
   - Version negotiation happens during the `initialize` method
   - For stdio: Extracts client version from request body
   - For HTTP: Extracts from request body during init, from header afterwards
   - Uses the version negotiation module for all version logic

3. **Protocol Version Tracking**
   - For stdio: Single client, version negotiated once during init
   - For HTTP: Multiple clients possible, version tracked per-request via header
   - The `protocol_version` parameter is passed through the call chain for version-specific behavior

### Key Design Principles

1. **Centralized version management**: Single source of truth in `supported_mcp_versions()`

2. **Per-specification implementation**: Follows MCP spec exactly:
   - Server uses client's version if supported
   - Otherwise returns latest supported version
   - HTTP clients must send `MCP-Protocol-Version` header

3. **Backwards compatibility**: 
   - Defaults to `2025-03-26` for missing HTTP headers (per spec)
   - Older clients continue to work

4. **Extensibility**: 
   - Adding new versions is simple and safe
   - Version-specific behavior can be added anywhere negotiated version is available

5. **Minimal changes**: 
   - Existing functionality unchanged
   - New code isolated in dedicated module
   - Non-breaking changes to existing functions

## Question 3: How does the server support multiple clients in HTTP?

The implementation supports multiple HTTP clients as follows:

### Per-Request Version Handling

1. **Session Management**: Each HTTP client negotiates its own protocol version during initialization

2. **Version Header**: After initialization, clients include `MCP-Protocol-Version` header on every request:
   ```
   MCP-Protocol-Version: 2025-06-18
   ```

3. **Header Validation**: The server validates this header on each request:
   ```r
   # In handle_http_post()
   protocol_version <- req$HTTP_MCP_PROTOCOL_VERSION
   
   if (!is_supported_version(protocol_version)) {
     return(list(status = 400L, ...))
   }
   ```

4. **Stateless Processing**: Each request is processed according to its version header, allowing:
   - Client A using version 2024-11-05
   - Client B using version 2025-06-18
   - Both clients working simultaneously

### Example Flow

```
Client A (2024-11-05):
  POST /mcp with body: {"method": "initialize", "params": {"protocolVersion": "2024-11-05"}}
  → Server responds: {"result": {"protocolVersion": "2024-11-05", ...}}
  
  POST /mcp with header: MCP-Protocol-Version: 2024-11-05
  → Server processes with version 2024-11-05 semantics

Client B (2025-06-18):
  POST /mcp with body: {"method": "initialize", "params": {"protocolVersion": "2025-06-18"}}
  → Server responds: {"result": {"protocolVersion": "2025-06-18", ...}}
  
  POST /mcp with header: MCP-Protocol-Version: 2025-06-18
  → Server processes with version 2025-06-18 semantics
```

### Backwards Compatibility

For clients that don't send the header (older clients):
```r
if (is.null(protocol_version)) {
  protocol_version <- "2025-03-26"  # Per MCP spec
}
```

This allows older HTTP clients to continue working while newer clients can use the latest protocol features.

## Complete Implementation

The implementation is fully functional and includes:

- ✅ Version negotiation during initialization (stdio and HTTP)
- ✅ HTTP header validation for `MCP-Protocol-Version`
- ✅ Support for 4 protocol versions (2024-11-05 through 2025-11-25)
- ✅ Multiple simultaneous HTTP clients with different versions
- ✅ Backwards compatibility
- ✅ Comprehensive test coverage
- ✅ Complete documentation

All code follows the MCP specification at:
https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle
