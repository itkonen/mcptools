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
  if (is.null(client_version) ||
        !is.character(client_version) ||
        length(client_version) != 1L) {
    latest_protocol_version
  } else if (client_version %in% supported_protocol_versions) {
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
  # ensure we index the internal list with a character key so lookups using the
  # value from HTTP headers (always character) succeed regardless of the type
  # returned by nanonext::random().
  session_key <- as.character(session_id)
  ## TODO: This will grow indefinitely as new sessions are initialized. We should
  ## consider pruning expired sessions after some timeout, but for now this is
  ## simpler than implementing a more complex structure for tracking session state.
  the$http_protocol_versions[[session_key]] <- version
}

#' Retrieve the negotiated version for an HTTP session.
#' @param session_id Character scalar identifying the HTTP session.
#' @return The negotiated version, or `NULL` if not yet initialized.
#' @noRd
get_http_protocol_version <- function(session_id) {
  if (!is.null(session_id)) {
    the$http_protocol_versions[[session_id]]
  }
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

validate_request_headers <- function(session_id,
                                     negotiated_protocol_version,
                                     protocol_version_from_header) {
  if (is.null(session_id)) {
    "Missing required Mcp-Session-Id header"
  } else if (is.null(negotiated_protocol_version)) {
    "Unknown or expired session ID"
  } else if (getOption("mcptools.enforce_protocol_headers", default = FALSE) &&
               protocol_version_gte(negotiated_protocol_version, "2025-06-18")) {
    ## For protocol versions >= 2025-06-18, both headers are required on all requests.
    ## For backwards compatibility, we cannot enforce this for older protocol versions.
    ## Furthermore, mcp-remote does not enforce this rule, so we allow it by default.
    if (!identical(negotiated_protocol_version, protocol_version_from_header)) {
      "MCP-Protocol-Version header does not match negotiated protocol version for this session"
    }
  } else {
    NULL
  }
}
