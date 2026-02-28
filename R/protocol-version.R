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
