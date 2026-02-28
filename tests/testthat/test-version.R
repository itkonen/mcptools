test_that("supported_mcp_versions returns expected versions", {
  versions <- supported_mcp_versions()
  
  expect_type(versions, "character")
  expect_true(length(versions) >= 4)
  
  # Check all required versions are present
  expect_true("2024-11-05" %in% versions)
  expect_true("2025-03-26" %in% versions)
  expect_true("2025-06-18" %in% versions)
  expect_true("2025-11-25" %in% versions)
  
  # Latest version should be first
  expect_equal(versions[1], "2025-11-25")
})

test_that("negotiate_version returns client version if supported", {
  # Server supports these versions, client requests one we support
  expect_equal(negotiate_version("2025-06-18"), "2025-06-18")
  expect_equal(negotiate_version("2024-11-05"), "2024-11-05")
  expect_equal(negotiate_version("2025-03-26"), "2025-03-26")
  expect_equal(negotiate_version("2025-11-25"), "2025-11-25")
})

test_that("negotiate_version returns latest version if client version unsupported", {
  # Client requests unsupported version, should get latest we support
  latest <- supported_mcp_versions()[1]
  
  expect_equal(negotiate_version("1.0.0"), latest)
  expect_equal(negotiate_version("2023-01-01"), latest)
  expect_equal(negotiate_version("2099-12-31"), latest)
})

test_that("is_supported_version correctly validates versions", {
  # Supported versions
  expect_true(is_supported_version("2024-11-05"))
  expect_true(is_supported_version("2025-03-26"))
  expect_true(is_supported_version("2025-06-18"))
  expect_true(is_supported_version("2025-11-25"))
  
  # Unsupported versions
  expect_false(is_supported_version("1.0.0"))
  expect_false(is_supported_version("2023-01-01"))
  expect_false(is_supported_version("invalid"))
  expect_false(is_supported_version(""))
})

test_that("capabilities returns negotiated version", {
  # Test with supported client version
  caps <- capabilities("2025-06-18")
  expect_equal(caps$protocolVersion, "2025-06-18")
  
  caps <- capabilities("2024-11-05")
  expect_equal(caps$protocolVersion, "2024-11-05")
  
  # Test with unsupported client version - should get latest
  caps <- capabilities("1.0.0")
  expect_equal(caps$protocolVersion, supported_mcp_versions()[1])
  
  # Test with NULL - should get latest
  caps <- capabilities(NULL)
  expect_equal(caps$protocolVersion, supported_mcp_versions()[1])
})
