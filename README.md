# TwelvedataRuby

[![Gem Version](https://badge.fury.io/rb/twelvedata_ruby.svg)](https://badge.fury.io/rb/twelvedata_ruby)
[![CI](https://github.com/kanutocd/twelvedata_ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/kanutocd/twelvedata_ruby/actions/workflows/ci.yml)
[![Release](https://github.com/kanutocd/twelvedata_ruby/actions/workflows/release.yml/badge.svg)](https://github.com/kanutocd/twelvedata_ruby/actions/workflows/release.yml)

A modern Ruby client library for accessing [Twelve Data's](https://twelvedata.com) comprehensive financial API. Get real-time and historical data for stocks, forex, cryptocurrencies, ETFs, indices, and more.

## Features

- 🚀 **Modern Ruby** - Requires Ruby 3.0+, follows modern Ruby practices
- 📈 **Comprehensive API Coverage** - All Twelve Data endpoints supported
- 🔒 **Type Safety** - Strong parameter validation and error handling
- 📊 **Multiple Formats** - JSON and CSV response formats
- 🧪 **Well Tested** - 100% test coverage
- 🔧 **Developer Friendly** - Excellent error messages and debugging support
- ⚡ **High Performance** - Built on HTTPX for concurrent requests

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'twelvedata_ruby'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install twelvedata_ruby
```

## Quick Start

### 1. Get Your API Key

Sign up for a free API key at [Twelve Data](https://twelvedata.com/pricing).

### 2. Basic Usage

```ruby
require 'twelvedata_ruby'

# Option 1: Configure with API key directly
client = TwelvedataRuby.client(apikey: "your-api-key-here")

# Option 2: Use environment variable (recommended)
ENV['TWELVEDATA_API_KEY'] = 'your-api-key-here'
client = TwelvedataRuby.client

# Get a stock quote
response = client.quote(symbol: "AAPL")
puts response.parsed_body
# => {
#   symbol: "AAPL",
#   name: "Apple Inc",
#   exchange: "NASDAQ",
#   currency: "USD",
#   datetime: "2024-01-15",
#   open: "185.00",
#   high: "187.50",
#   low: "184.20",
#   close: "186.75",
#   volume: "45678900",
#   ...
# }
```

## API Reference

### Stock Market Data

```ruby
# Real-time quote
client.quote(symbol: "AAPL")
client.quote(symbol: "GOOGL", exchange: "NASDAQ")

# Current price only
client.price(symbol: "TSLA")

# Historical time series data
client.time_series(
  symbol: "AAPL",
  interval: "1day",
  start_date: "2024-01-01",
  end_date: "2024-01-31"
)

# End of day prices
client.eod(symbol: "MSFT")

# Search for symbols
client.symbol_search(symbol: "Apple")
```

### Forex & Currency

```ruby
# Exchange rates
client.exchange_rate(symbol: "USD/EUR")

# Currency conversion
client.currency_conversion(symbol: "USD/EUR", amount: 100)

# Available forex pairs
client.forex_pairs
```

### Cryptocurrency

```ruby
# Crypto quotes
client.quote(symbol: "BTC/USD")

# Available cryptocurrencies
client.cryptocurrencies

# Crypto exchanges
client.cryptocurrency_exchanges
```

### Market Reference Data

```ruby
# Available stocks
client.stocks(exchange: "NASDAQ")

# ETF information
client.etf

# Market indices
client.indices

# Stock exchanges
client.exchanges

# Technical indicators
client.technical_indicators
```

### Account & Usage

```ruby
# Check API usage
usage = client.api_usage
puts "Current usage: #{usage.parsed_body[:current_usage]}/#{usage.parsed_body[:plan_limit]}"
```

## Advanced Usage

### Response Formats

```ruby
# JSON response (default)
response = client.quote(symbol: "AAPL", format: :json)
data = response.parsed_body # Hash

# CSV response
response = client.quote(symbol: "AAPL", format: :csv)
table = response.parsed_body # CSV::Table

# Save CSV to file
response = client.time_series(
  symbol: "AAPL",
  interval: "1day",
  format: :csv,
  filename: "apple_daily.csv"
)
response.save_to_file("./data/apple_data.csv")
```

### Error Handling

```ruby
response = client.quote(symbol: "INVALID")

if response.error
  case response.error
  when TwelvedataRuby::UnauthorizedResponseError
    puts "Invalid API key"
  when TwelvedataRuby::NotFoundResponseError
    puts "Symbol not found"
  when TwelvedataRuby::TooManyRequestsResponseError
    puts "Rate limit exceeded"
  else
    puts "Error: #{response.error.message}"
  end
else
  puts response.parsed_body
end
```

### Configuration Options

```ruby
client = TwelvedataRuby.client(
  apikey: "your-api-key",
  connect_timeout: 5000,  # milliseconds
  apikey_env_var_name: "CUSTOM_API_KEY_VAR"
)

# Update configuration later
client.configure(connect_timeout: 10000)

# Or set individual options
client.apikey = "new-api-key"
client.connect_timeout = 3000
```

### Concurrent Requests

```ruby
# Create multiple requests
requests = [
  TwelvedataRuby::Request.new(:quote, symbol: "AAPL"),
  TwelvedataRuby::Request.new(:quote, symbol: "GOOGL"),
  TwelvedataRuby::Request.new(:quote, symbol: "MSFT")
]

# Send them concurrently
responses = TwelvedataRuby::Client.request(requests)
responses.each_with_index do |http_response, index|
  response = TwelvedataRuby::Response.resolve(http_response, requests[index])
  puts "#{requests[index].query_params[:symbol]}: #{response.parsed_body[:close]}"
end
```

### Complex Data Queries

```ruby
# POST request for complex data
response = client.complex_data(
  symbols: "AAPL,GOOGL,MSFT",
  intervals: "1day,1week",
  start_date: "2024-01-01",
  end_date: "2024-01-31",
  methods: "time_series"
)
```

## Response Objects

### Response Methods

```ruby
response = client.quote(symbol: "AAPL")

# Response status
response.success?           # => true/false
response.http_status_code   # => 200
response.status_code        # => API status code

# Content information
response.content_type       # => :json, :csv, :plain
response.body_bytesize      # => response size in bytes

# Parsed data
response.parsed_body        # => Hash, CSV::Table, or String
response.body              # => alias for parsed_body

# Error information
response.error             # => nil or ResponseError instance

# File operations
response.attachment_filename  # => "filename.csv" if present
response.save_to_file("path/to/file.csv")
response.dump_parsed_body     # => serialized content

# Debugging
response.to_s              # => human-readable summary
response.inspect           # => detailed inspection
```

### Error Types

```ruby
# Base error types
TwelvedataRuby::Error                    # Base error class
TwelvedataRuby::ConfigurationError       # Configuration issues
TwelvedataRuby::NetworkError            # Network connectivity issues

# API endpoint errors
TwelvedataRuby::EndpointError           # Invalid endpoint usage
TwelvedataRuby::EndpointNameError       # Invalid endpoint name
TwelvedataRuby::EndpointParametersKeysError     # Invalid parameters
TwelvedataRuby::EndpointRequiredParametersError # Missing required parameters

# API response errors
TwelvedataRuby::ResponseError           # Base response error
TwelvedataRuby::BadRequestResponseError         # 400 errors
TwelvedataRuby::UnauthorizedResponseError       # 401 errors
TwelvedataRuby::ForbiddenResponseError          # 403 errors
TwelvedataRuby::NotFoundResponseError           # 404 errors
TwelvedataRuby::TooManyRequestsResponseError    # 429 errors
TwelvedataRuby::InternalServerResponseError     # 500 errors
```

## Available Endpoints

| Endpoint                   | Method | Required Parameters                              | Description                |
| -------------------------- | ------ | ------------------------------------------------ | -------------------------- |
| `quote`                    | GET    | `symbol`                                         | Real-time stock quote      |
| `price`                    | GET    | `symbol`                                         | Current stock price        |
| `time_series`              | GET    | `symbol`, `interval`                             | Historical price data      |
| `eod`                      | GET    | `symbol`                                         | End of day price           |
| `exchange_rate`            | GET    | `symbol`                                         | Forex exchange rate        |
| `currency_conversion`      | GET    | `symbol`, `amount`                               | Currency conversion        |
| `symbol_search`            | GET    | `symbol`                                         | Search for symbols         |
| `earliest_timestamp`       | GET    | `symbol`, `interval`                             | Earliest available data    |
| `api_usage`                | GET    | -                                                | API usage statistics       |
| `stocks`                   | GET    | -                                                | Available stocks           |
| `forex_pairs`              | GET    | -                                                | Available forex pairs      |
| `cryptocurrencies`         | GET    | -                                                | Available cryptocurrencies |
| `etf`                      | GET    | -                                                | Available ETFs             |
| `indices`                  | GET    | -                                                | Available indices          |
| `exchanges`                | GET    | -                                                | Available exchanges        |
| `cryptocurrency_exchanges` | GET    | -                                                | Available crypto exchanges |
| `technical_indicators`     | GET    | -                                                | Available indicators       |
| `earnings`                 | GET    | `symbol`                                         | Earnings data              |
| `earnings_calendar`        | GET    | -                                                | Earnings calendar          |
| `complex_data`             | POST   | `symbols`, `intervals`, `start_date`, `end_date` | Complex data queries       |

For complete parameter documentation, visit [Twelve Data's API documentation](https://twelvedata.com/docs).

## Development

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/lib/twelvedata_ruby/client_spec.rb

# Run with profile information
PROFILE=true bundle exec rspec
```

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -A

# Generate documentation
bundle exec yard doc
```

### Debugging

```ruby
# Enable debugging output
require 'pry'

client = TwelvedataRuby.client(apikey: "your-key")
response = client.quote(symbol: "AAPL")

# Debug response
binding.pry

# Inspect request details
puts response.request.to_h
puts response.request.full_url
puts response.request.query_params
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Run the test suite (`bundle exec rspec`)
5. Run RuboCop (`bundle exec rubocop`)
6. Commit your changes (`git commit -am 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Release Process

### For Maintainers

This gem uses automated releases via GitHub Actions. See [Release Process Documentation](docs/RELEASE_PROCESS.md) for complete details.
TODO: add RELEASE_PROCESS.md file

#### Quick Release Guide

```bash
# 1. Prepare release
bin/release prepare --version 0.4.1

# 2. Push changes
git push origin main

# 3. Create GitHub release with tag v0.4.1
# → Automatic publication to RubyGems.org via GitHub Actions
```

#### Release Helper Commands

```bash
# Check if ready for release
bin/release check

# Auto-bump version
bin/release bump --type patch    # 0.4.0 → 0.4.1
bin/release bump --type minor    # 0.4.0 → 0.5.0
bin/release bump --type major    # 0.4.0 → 1.0.0

# Dry run (test without changes)
bin/release prepare --version 0.4.1 --dry-run
```

#### GitHub Workflows

- **CI**: Runs tests, linting, and security scans on every push/PR
- **Release**: Automatically publishes to RubyGems.org when GitHub release is created
- **Documentation**: Updates GitHub Pages with latest API docs

#### Manual Release (Advanced)

```bash
# Trigger release workflow manually
gh workflow run release.yml \
  --field version=0.4.1 \
  --field dry_run=false
```

## License

This gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Code of Conduct

Everyone interacting in the TwelvedataRuby project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## Support

- 📖 [API Documentation](https://kanutocd.github.io/twelvedata_ruby/doc/) (TODO)
- 🐛 [Issue Tracker](https://github.com/kanutocd/twelvedata_ruby/issues)
- 💬 [Discussions](https://github.com/kanutocd/twelvedata_ruby/discussions)
- 📧 Email: kenneth.c.demanawa@gmail.com

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Notice

This is not an official Twelve Data Ruby library. The author of this gem is not affiliated with Twelve Data in any way, shape or form. Twelve Data APIs and data are Copyright © 2024 Twelve Data Pte. Ltd.

---

**Made with ❤️ by the Ruby community**
