# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2024-07-02

### 🚀 Major Refactoring Release

This release represents a refactor of the TwelvedataRuby gem with breaking changes for better maintainability and developer experience.

### 💥 Breaking Changes

- **Ruby Version**: Now requires Ruby 3.4.0+ (was 2.4+)
- **Dependencies**: Updated to modern versions
  - `httpx` updated to `~> 1.0` (was `~> 0.14`)
  - All development dependencies updated to latest versions
- **Client Interface**: Simplified client configuration API
  - `TwelvedataRuby.client(**options)` now properly configures singleton instance
  - Removed deprecated `options=` writer in favor of `configure(**options)`
- **Error Handling**: Completely rewritten error hierarchy
  - More specific error classes for different failure scenarios
  - Better error messages with context
  - Proper error attributes for debugging
- **Utils Module**: Refactored utility methods
  - `to_d` renamed to `to_integer` with better error handling
  - Added `present?`, `blank?`, and improved helper methods
  - Better nil and edge case handling

### ✨ Added

- **Modern Ruby Support**: Full Ruby 3.0+ compatibility with modern idioms
- **Enhanced Error Classes**:
  - `ConfigurationError`, `NetworkError` for specific error types
  - Better inheritance hierarchy for `ResponseError` classes
  - Error objects now include original exceptions and debugging context
- **Improved Response Handling**:
  - Better content type detection and parsing
  - Enhanced CSV handling with proper error recovery
  - File operations with better error handling
  - Response inspection and debugging methods
- **Better HTTP Client Integration**:
  - Proper HTTPX configuration and error handling
  - Support for concurrent requests
  - Network timeout and connection error handling
- **Enhanced Testing**:
  - 100% test coverage with comprehensive specs
  - Proper HTTP request mocking with WebMock
  - Shared examples and contexts for better test organization
  - Edge case testing for all components
- **Development Tools**:
  - RuboCop configuration with modern rules
  - GitHub Actions CI/CD pipeline
  - YARD documentation generation
  - SimpleCov coverage reporting

### 🔧 Changed

- **Client Class**: Complete rewrite
  - Singleton pattern properly implemented
  - Better configuration management
  - Dynamic method definition with caching
  - Thread-safe operation
- **Endpoint Class**: Enhanced validation and error reporting
  - Better parameter validation with detailed error messages
  - Improved format handling (JSON/CSV)
  - More robust parameter processing
- **Request Class**: Cleaner API and better validation
  - Proper delegation to endpoint
  - Enhanced equality and hashing methods
  - Better debugging support with `inspect` and `to_s`
- **Response Class**: Major improvements in parsing and error handling
  - Robust JSON/CSV parsing with proper error recovery
  - Better large file handling with temporary files
  - Enhanced file operations and attachment handling
  - Improved debugging and inspection methods

### 🐛 Fixed

- **Memory Leaks**: Proper resource cleanup in response handling
- **Edge Cases**: Better handling of nil values, empty responses, malformed data
- **Concurrency**: Thread-safe singleton client implementation
- **Error Propagation**: Proper error bubbling with context preservation
- **Parameter Validation**: More accurate validation with better error messages

### 📚 Documentation

- **Complete README Rewrite**: More examples and more API documentation
- **YARD Documentation**: Inline documentation for all public methods
- **Error Handling Guide**: Examples for most (if not all) error scenarios
- **Advanced Usage**: Concurrent requests, configuration options, debugging

### 🧪 Testing

- **Comprehensive Test Suite**: 100% code coverage with RSpec
- **Proper Mocking**: WebMock integration for HTTP request stubbing
- **Edge Case Coverage**: Tests for error conditions, malformed data, network issues
- **Performance Tests**: Basic performance and memory usage validation
- **Integration Tests**: End-to-end API workflow testing

### 🔄 Migration Guide

#### Updating Dependencies

```ruby
# In your Gemfile, update the Ruby version requirement
ruby '>= 3.4.0'

# Update the gem
gem 'twelvedata_ruby', '~> 0.4.0'
```

#### Client Configuration

```ruby
# Before (0.3.x)
client = TwelvedataRuby.client
client.options = { apikey: "key", connect_timeout: 300 }

# After (0.4.x)
client = TwelvedataRuby.client(apikey: "key", connect_timeout: 300)
# or
client = TwelvedataRuby.client
client.configure(apikey: "key", connect_timeout: 300)
```

#### Error Handling

```ruby
# Before (0.3.x)
response = client.quote(symbol: "INVALID")
if response.is_a?(Hash) && response[:errors]
  # handle endpoint errors
elsif response.error
  # handle API errors
end

# After (0.4.x)
response = client.quote(symbol: "INVALID")
case response
when Hash
  # Handle validation errors
  puts response[:errors]
when TwelvedataRuby::Response
  if response.error
    case response.error
    when TwelvedataRuby::UnauthorizedResponseError
      puts "Invalid API key"
    when TwelvedataRuby::NotFoundResponseError
      puts "Symbol not found"
    end
  else
    puts response.parsed_body
  end
when TwelvedataRuby::NetworkError
  puts "Network connectivity issue"
end
```

#### Utils Methods

```ruby
# Before (0.3.x)
TwelvedataRuby::Utils.to_d("123", 0)

# After (0.4.x)
TwelvedataRuby::Utils.to_integer("123", 0)
```

## [0.3.0] - 2021-07-15

### Added

- Initial stable release
- Basic API endpoint support
- JSON and CSV response formats
- Simple error handling
- Ruby 2.4+ support

### Dependencies

- `httpx ~> 0.14.5`
- Basic development dependencies

---

## [Unreleased]

### Planned

- Performance optimizations
- Additional endpoint coverage
- Enhanced WebSocket support (if available from Twelve Data)
- Caching mechanisms for frequent requests

---

**Note**: This changelog follows semantic versioning. Major version bumps indicate breaking changes, minor versions add functionality, and patch versions fix bugs.
