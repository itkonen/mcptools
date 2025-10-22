jsonrpc_response <- function(id, result = NULL, error = NULL) {
  if (!xor(is.null(result), is.null(error))) {
    warning("Either `result` or `error` must be provided, but not both.")
  }

  drop_nulls(list(
    jsonrpc = "2.0",
    id = id,
    result = result,
    error = error
  ))
}

# Create a named list, ensuring that it's a named list, even if empty.
named_list <- function(...) {
  res <- list(...)
  if (length(res) == 0) {
    # A way of creating an empty named list
    res <- list(a = 1)[0]
  }
  res
}

to_json <- function(x, ...) {
  jsonlite::toJSON(x, ..., auto_unbox = TRUE)
}

interactive <- NULL

mcptools_server_log <- function() {
  Sys.getenv("MCPTOOLS_SERVER_LOG", tempfile(fileext = ".txt"))
}

mcptools_client_log <- function() {
  Sys.getenv("MCPTOOLS_CLIENT_LOG", tempfile(fileext = ".txt"))
}

# from rstudio/reticulate
is_unix <- function() {
  identical(.Platform$OS.type, "unix")
}

is_fedora <- function() {
  if (is_unix() && file.exists("/etc/os-release")) {
    os_info <- readLines("/etc/os-release")
    any(grepl("Fedora", os_info))
  } else {
    FALSE
  }
}
