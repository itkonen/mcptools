# Version negotiation for MCP protocol

#' Supported MCP protocol versions
#'
#' Returns a character vector of supported MCP protocol versions,
#' ordered from latest to oldest.
#'
#' @return A character vector of supported protocol versions
#' @keywords internal
supported_mcp_versions <- function() {
  c(
    "2025-11-25",
    "2025-06-18",
    "2025-03-26",
    "2024-11-05"
  )
}

#' Negotiate protocol version with client
#'
#' According to the MCP spec, if the server supports the client's requested
#' version, it returns that version. Otherwise, it returns the latest version
#' the server supports.
#'
#' @param client_version The protocol version requested by the client
#' @return The negotiated protocol version
#' @keywords internal
negotiate_version <- function(client_version) {
  supported <- supported_mcp_versions()
  
  # If we support the client's version, use it
  if (client_version %in% supported) {
    return(client_version)
  }
  
  # Otherwise, return the latest version we support
  return(supported[1])
}

#' Validate protocol version
#'
#' Checks if a protocol version is valid and supported.
#'
#' @param version The protocol version to validate
#' @return TRUE if the version is supported, FALSE otherwise
#' @keywords internal
is_supported_version <- function(version) {
  version %in% supported_mcp_versions()
}
