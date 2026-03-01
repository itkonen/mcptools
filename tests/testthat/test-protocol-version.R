skip_if(is_fedora())

# -- negotiate_protocol_version ------------------------------------------------

test_that("negotiate_protocol_version returns client version when supported", {
  expect_equal(negotiate_protocol_version("2024-11-05"), "2024-11-05")
  expect_equal(negotiate_protocol_version("2025-03-26"), "2025-03-26")
  expect_equal(negotiate_protocol_version("2025-06-18"), "2025-06-18")
  expect_equal(negotiate_protocol_version("2025-11-25"), "2025-11-25")
})

test_that("negotiate_protocol_version returns latest for unsupported version", {
  expect_equal(
    negotiate_protocol_version("2099-01-01"),
    latest_protocol_version
  )
  expect_equal(
    negotiate_protocol_version("not-a-version"),
    latest_protocol_version
  )
})

# -- per-transport version storage ---------------------------------------------

test_that("stdio protocol version storage works", {
  withr::defer(the$negotiated_protocol_version <- NULL)

  set_stdio_protocol_version("2025-03-26")
  expect_equal(get_stdio_protocol_version(), "2025-03-26")
})

test_that("get_stdio_protocol_version defaults to latest when unset", {
  withr::defer(the$negotiated_protocol_version <- NULL)

  the$negotiated_protocol_version <- NULL
  expect_equal(get_stdio_protocol_version(), latest_protocol_version)
})

test_that("http protocol version storage works per-session", {
  withr::defer(the$http_protocol_versions <- NULL)

  set_http_protocol_version("session-a", "2024-11-05")
  set_http_protocol_version("session-b", "2025-06-18")

  expect_equal(get_http_protocol_version("session-a"), "2024-11-05")
  expect_equal(get_http_protocol_version("session-b"), "2025-06-18")
  expect_null(get_http_protocol_version("session-c"))
})

# -- version comparison helpers ------------------------------------------------

test_that("protocol_version_gte works", {
  expect_true(protocol_version_gte("2025-06-18", "2025-03-26"))
  expect_true(protocol_version_gte("2025-06-18", "2025-06-18"))
  expect_false(protocol_version_gte("2024-11-05", "2025-03-26"))
})

test_that("protocol_version_lt works", {
  expect_true(protocol_version_lt("2024-11-05", "2025-03-26"))
  expect_false(protocol_version_lt("2025-06-18", "2025-06-18"))
  expect_false(protocol_version_lt("2025-11-25", "2025-03-26"))
})

# -- capabilities --------------------------------------------------------------

test_that("capabilities uses supplied protocol version", {
  res <- capabilities("2025-11-25")
  expect_equal(res$protocolVersion, "2025-11-25")

  res <- capabilities("2024-11-05")
  expect_equal(res$protocolVersion, "2024-11-05")
})

test_that("capabilities defaults to latest protocol version", {
  res <- capabilities()
  expect_equal(res$protocolVersion, latest_protocol_version)
})

test_that("capabilities includes proper instructions", {
  res <- capabilities("2025-03-26")
  expect_true(
    is.null(res$instructions) ||
      (is.character(res$instructions) && length(res$instructions) == 1L)
  )
})

test_that("capabilities always includes required fields", {
  for (version in supported_protocol_versions) {
    res <- capabilities(version)
    expect_true(!is.null(res$protocolVersion))
    expect_true(!is.null(res$capabilities))
    expect_true(!is.null(res$serverInfo))
    expect_true(!is.null(res$capabilities$tools))
    expect_equal(res$serverInfo$name, "R mcptools server")
  }
})

# -- validate_protocol_version_header -----------------------------------------

test_that("validate_protocol_version_header accepts supported versions", {
  for (version in supported_protocol_versions) {
    req <- list(HTTP_MCP_PROTOCOL_VERSION = version)
    expect_true(validate_protocol_version_header(req))
  }
})

test_that("validate_protocol_version_header rejects missing header", {
  req <- list()
  result <- validate_protocol_version_header(req)
  expect_false(isTRUE(result))
  expect_equal(result$status, 400L)
})

test_that("validate_protocol_version_header rejects unsupported version", {
  req <- list(HTTP_MCP_PROTOCOL_VERSION = "2099-01-01")
  result <- validate_protocol_version_header(req)
  expect_false(isTRUE(result))
  expect_equal(result$status, 400L)
})

# -- validate_session_id_header ------------------------------------------------

test_that("validate_session_id_header accepts known session", {
  withr::defer(the$http_protocol_versions <- NULL)

  set_http_protocol_version("test-session-abc", "2025-06-18")

  req <- list(HTTP_MCP_SESSION_ID = "test-session-abc")
  expect_true(validate_session_id_header(req))
})

test_that("validate_session_id_header rejects missing header", {
  req <- list()
  result <- validate_session_id_header(req)
  expect_false(isTRUE(result))
  expect_equal(result$status, 400L)
})

test_that("validate_session_id_header rejects unknown session", {
  withr::defer(the$http_protocol_versions <- NULL)

  req <- list(HTTP_MCP_SESSION_ID = "nonexistent-session")
  result <- validate_session_id_header(req)
  expect_false(isTRUE(result))
  expect_equal(result$status, 404L)
})

# -- version-gated header enforcement in handle_http_post ----------------------
# These tests verify the server's permissive behaviour: session ID and protocol
# version headers are only *required* for protocol versions >= 2025-06-18.

test_that("handle_http_post enforces headers for >= 2025-06-18 sessions", {
  withr::defer(the$http_protocol_versions <- NULL)

  set_http_protocol_version("session-new", "2025-06-18")

  # Valid session ID but missing MCP-Protocol-Version → 400
  req_no_version <- list(
    REQUEST_METHOD = "POST",
    HTTP_MCP_SESSION_ID = "session-new",
    rook.input = list(read = function() {
      charToRaw('{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
    })
  )
  result <- handle_http_post(req_no_version)
  expect_equal(result$status, 400L)
})

test_that("handle_http_post is permissive for < 2025-06-18 sessions", {
  withr::defer(the$http_protocol_versions <- NULL)
  withr::defer(the$server_tools <- NULL)
  the$sessions_enabled <- FALSE
  set_server_tools(list(ellmer::tool(
    function() "hello", "A test tool", name = "test_tool"
  )), session_tools = FALSE)

  set_http_protocol_version("session-old", "2024-11-05")

  # Request with valid old-version session ID, no protocol version header → OK
  req <- list(
    REQUEST_METHOD = "POST",
    HTTP_MCP_SESSION_ID = "session-old",
    rook.input = list(read = function() {
      charToRaw('{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
    })
  )
  result <- handle_http_post(req)
  expect_equal(result$status, 200L)
})

test_that("handle_http_post allows requests with no session header for old clients", {
  withr::defer(the$http_protocol_versions <- NULL)
  withr::defer(the$server_tools <- NULL)
  the$sessions_enabled <- FALSE
  set_server_tools(list(ellmer::tool(
    function() "hello", "A test tool", name = "test_tool"
  )), session_tools = FALSE)

  # No Mcp-Session-Id header at all (old client that never got one) → OK
  req <- list(
    REQUEST_METHOD = "POST",
    rook.input = list(read = function() {
      charToRaw('{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
    })
  )
  result <- handle_http_post(req)
  expect_equal(result$status, 200L)
})

test_that("handle_http_post rejects unknown session ID regardless of version", {
  withr::defer(the$http_protocol_versions <- NULL)

  # A session ID that doesn't map to anything → 404
  req <- list(
    REQUEST_METHOD = "POST",
    HTTP_MCP_SESSION_ID = "totally-bogus",
    rook.input = list(read = function() {
      charToRaw('{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
    })
  )
  result <- handle_http_post(req)
  expect_equal(result$status, 404L)
})

test_that("handle_http_post notification path is permissive for old versions", {
  withr::defer(the$http_protocol_versions <- NULL)

  set_http_protocol_version("session-old-notif", "2025-03-26")

  # Notification with old-version session ID, no protocol version → 202

  req <- list(
    REQUEST_METHOD = "POST",
    HTTP_MCP_SESSION_ID = "session-old-notif",
    rook.input = list(read = function() {
      charToRaw('{"jsonrpc":"2.0","method":"some/notification"}')
    })
  )
  result <- handle_http_post(req)
  expect_equal(result$status, 202L)
})

test_that("handle_http_post notification path enforces headers for >= 2025-06-18", {
  withr::defer(the$http_protocol_versions <- NULL)

  set_http_protocol_version("session-new-notif", "2025-06-18")

  # Notification without session ID header for a >= 2025-06-18 session
  # The server can't know the version without the session ID, so it lets it

  # through (permissive when no session ID is present)
  req_no_header <- list(
    REQUEST_METHOD = "POST",
    rook.input = list(read = function() {
      charToRaw('{"jsonrpc":"2.0","method":"some/notification"}')
    })
  )
  result <- handle_http_post(req_no_header)
  expect_equal(result$status, 202L)
})
