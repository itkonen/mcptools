# Protocol version negotiation
#
# The MCP spec requires the server to negotiate a protocol version with the
# client during initialization. The client sends its preferred version;
# if the server supports it, the server echoes it back. Otherwise, the server
# responds with the latest version it supports and the client may disconnect.
#
# Adding a new supported version:
#   1. Append the version string to `supported_protocol_versions` below.
#   2. If the new version introduces behavioural changes, use
#      `protocol_version_gte()` / `protocol_version_lt()` guards in the
#      relevant code paths rather than duplicating implementations.

#' Supported MCP protocol versions, from oldest to newest.
#' @noRd
supported_protocol_versions <- c(
  "2024-11-05",
  "2025-03-26",
  "2025-06-18",
  "2025-11-25"
)

#' The latest protocol version supported by this server.
#' @noRd
latest_protocol_version <- supported_protocol_versions[
  length(supported_protocol_versions)
]

#' Negotiate a protocol version with a client.
#'
#' Implements the MCP version negotiation: if the client's requested version
#' is supported, return it; otherwise return the server's latest version.
#'
#' @param client_version Character scalar; the `protocolVersion` from the
#'   client's `initialize` request.
#' @return The negotiated version string.
#' @noRd
negotiate_protocol_version <- function(client_version) {
  if (client_version %in% supported_protocol_versions) {
    client_version
  } else {
    latest_protocol_version
  }
}

# -- Per-client version tracking -----------------------------------------------
#
# stdio: one client at a time -> store in `the$negotiated_protocol_version`.
# HTTP:  multiple clients     -> store in `the$http_protocol_versions`,
#        a named list keyed by mcp session id.

#' Store the negotiated version for the current stdio client.
#' @noRd
set_stdio_protocol_version <- function(version) {
  the$negotiated_protocol_version <- version
}

#' Retrieve the negotiated version for the current stdio client.
#' @noRd
get_stdio_protocol_version <- function() {
  the$negotiated_protocol_version %||% latest_protocol_version
}

#' Store the negotiated version for an HTTP session.
#' @param session_id Character scalar identifying the HTTP session.
#' @param version    Negotiated protocol version.
#' @noRd
set_http_protocol_version <- function(session_id, version) {
  if (is.null(the$http_protocol_versions)) {
    the$http_protocol_versions <- list()
  }
  the$http_protocol_versions[[session_id]] <- version
}

#' Retrieve the negotiated version for an HTTP session.
#' @param session_id Character scalar identifying the HTTP session.
#' @return The negotiated version, or `NULL` if not yet initialized.
#' @noRd
get_http_protocol_version <- function(session_id) {
  the$http_protocol_versions[[session_id]]
}

#' Validate the `MCP-Protocol-Version` header on an HTTP request.
#'
#' Per the spec: "the client MUST include the MCP-Protocol-Version header on
#' all subsequent requests to the MCP server."
#'
#' @param req The Rook request environment.
#' @return `TRUE` if the header is valid (matches a supported version),
#'   or if the request is an `initialize` (where the header is not expected).
#'   Returns a list with HTTP error response otherwise.
#' @noRd
validate_protocol_version_header <- function(req) {
  # The header name is transformed by httpuv/Rook: HTTP_MCP_PROTOCOL_VERSION
  header_version <- req$HTTP_MCP_PROTOCOL_VERSION

  if (is.null(header_version)) {
    return(list(
      status = 400L,
      headers = list("Content-Type" = "application/json"),
      body = to_json(list(
        jsonrpc = "2.0",
        error = list(
          code = -32600,
          message = "Missing required MCP-Protocol-Version header",
          data = list(supported = supported_protocol_versions)
        )
      ))
    ))
  }

  if (!header_version %in% supported_protocol_versions) {
    return(list(
      status = 400L,
      headers = list("Content-Type" = "application/json"),
      body = to_json(list(
        jsonrpc = "2.0",
        error = list(
          code = -32600,
          message = "Unsupported protocol version in MCP-Protocol-Version header",
          data = list(
            supported = supported_protocol_versions,
            requested = header_version
          )
        )
      ))
    ))
  }

  TRUE
}

#' Compare the negotiated version against a reference version.
#'
#' Useful for version-gating behaviour, e.g.:
#' ```
#' if (protocol_version_gte(version, "2025-06-18")) {
#'   # use new behaviour
#' }
#' ```
#'
#' @param version   Character scalar; the negotiated version.
#' @param reference Character scalar; the version to compare against.
#' @return `TRUE` if `version >= reference` in chronological order.
#' @noRd
protocol_version_gte <- function(version, reference) {
  version >= reference
}

#' @rdname protocol_version_gte
#' @noRd
protocol_version_lt <- function(version, reference) {
  version < reference
}

#' Validate the `Mcp-Session-Id` header on an HTTP request.
#'
#' Per the spec (from 2025-03-26): the server MAY assign a session ID during
#' initialization. If it does, the client MUST include `Mcp-Session-Id` on all
#' subsequent requests. A missing header should return 400 Bad Request; an
#' unknown/expired session ID should return 404 Not Found.
#'
#' @param req The Rook request environment.
#' @return `TRUE` if the session ID is valid (maps to a known session).
#'   Returns a list with an HTTP error response otherwise.
#' @noRd
validate_session_id_header <- function(req) {
  # httpuv/Rook transforms the header to HTTP_MCP_SESSION_ID
  session_id <- req$HTTP_MCP_SESSION_ID

  if (is.null(session_id)) {
    return(list(
      status = 400L,
      headers = list("Content-Type" = "application/json"),
      body = to_json(list(
        jsonrpc = "2.0",
        error = list(
          code = -32600,
          message = "Missing required Mcp-Session-Id header"
        )
      ))
    ))
  }

  if (is.null(get_http_protocol_version(session_id))) {
    return(list(
      status = 404L,
      headers = list("Content-Type" = "application/json"),
      body = to_json(list(
        jsonrpc = "2.0",
        error = list(
          code = -32600,
          message = "Unknown or expired session ID"
        )
      ))
    ))
  }

  TRUE
}
