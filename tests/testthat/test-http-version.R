skip_if(is_fedora())

test_that("HTTP POST validates MCP-Protocol-Version header for non-initialize requests", {
  # Mock a request without the MCP-Protocol-Version header
  req_no_header <- list(
    REQUEST_METHOD = "POST",
    HTTP_ORIGIN = NULL,
    HTTP_MCP_PROTOCOL_VERSION = NULL,
    rook.input = list(
      read = function() {
        charToRaw(jsonlite::toJSON(list(
          jsonrpc = "2.0",
          id = 2,
          method = "tools/list"
        ), auto_unbox = TRUE))
      }
    )
  )
  
  # Should default to 2025-03-26 for backwards compatibility
  response <- handle_http_post(req_no_header)
  expect_equal(response$status, 200L)
  
  # Mock a request with an invalid protocol version
  req_invalid <- list(
    REQUEST_METHOD = "POST",
    HTTP_ORIGIN = NULL,
    HTTP_MCP_PROTOCOL_VERSION = "invalid-version",
    rook.input = list(
      read = function() {
        charToRaw(jsonlite::toJSON(list(
          jsonrpc = "2.0",
          id = 2,
          method = "tools/list"
        ), auto_unbox = TRUE))
      }
    )
  )
  
  response <- handle_http_post(req_invalid)
  expect_equal(response$status, 400L)
  expect_match(response$body, "Invalid or unsupported")
  
  # Mock a request with a valid protocol version
  req_valid <- list(
    REQUEST_METHOD = "POST",
    HTTP_ORIGIN = NULL,
    HTTP_MCP_PROTOCOL_VERSION = "2025-06-18",
    rook.input = list(
      read = function() {
        charToRaw(jsonlite::toJSON(list(
          jsonrpc = "2.0",
          id = 2,
          method = "tools/list"
        ), auto_unbox = TRUE))
      }
    )
  )
  
  response <- handle_http_post(req_valid)
  expect_equal(response$status, 200L)
})

test_that("HTTP POST handles initialize without MCP-Protocol-Version header", {
  # For initialize requests, the version comes from the request body
  req_initialize <- list(
    REQUEST_METHOD = "POST",
    HTTP_ORIGIN = NULL,
    HTTP_MCP_PROTOCOL_VERSION = NULL,
    rook.input = list(
      read = function() {
        charToRaw(jsonlite::toJSON(list(
          jsonrpc = "2.0",
          id = 1,
          method = "initialize",
          params = list(
            protocolVersion = "2024-11-05",
            capabilities = list(),
            clientInfo = list(name = "test", version = "1.0.0")
          )
        ), auto_unbox = TRUE))
      }
    )
  )
  
  response <- handle_http_post(req_initialize)
  expect_equal(response$status, 200L)
  
  # Parse the response to verify version negotiation
  result <- jsonlite::parse_json(response$body)
  expect_equal(result$result$protocolVersion, "2024-11-05")
})

test_that("HTTP POST negotiates version correctly during initialize", {
  # Test with supported version
  req_supported <- list(
    REQUEST_METHOD = "POST",
    HTTP_ORIGIN = NULL,
    HTTP_MCP_PROTOCOL_VERSION = NULL,
    rook.input = list(
      read = function() {
        charToRaw(jsonlite::toJSON(list(
          jsonrpc = "2.0",
          id = 1,
          method = "initialize",
          params = list(
            protocolVersion = "2025-06-18",
            capabilities = list(),
            clientInfo = list(name = "test", version = "1.0.0")
          )
        ), auto_unbox = TRUE))
      }
    )
  )
  
  response <- handle_http_post(req_supported)
  result <- jsonlite::parse_json(response$body)
  expect_equal(result$result$protocolVersion, "2025-06-18")
  
  # Test with unsupported version - should return latest
  req_unsupported <- list(
    REQUEST_METHOD = "POST",
    HTTP_ORIGIN = NULL,
    HTTP_MCP_PROTOCOL_VERSION = NULL,
    rook.input = list(
      read = function() {
        charToRaw(jsonlite::toJSON(list(
          jsonrpc = "2.0",
          id = 1,
          method = "initialize",
          params = list(
            protocolVersion = "1.0.0",
            capabilities = list(),
            clientInfo = list(name = "test", version = "1.0.0")
          )
        ), auto_unbox = TRUE))
      }
    )
  )
  
  response <- handle_http_post(req_unsupported)
  result <- jsonlite::parse_json(response$body)
  expect_equal(result$result$protocolVersion, supported_mcp_versions()[1])
})
