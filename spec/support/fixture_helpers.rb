# frozen_string_literal: true

# Helper module for loading test fixtures
module FixtureHelpers
  # Load a fixture file for testing
  #
  # @param endpoint_name [String, Symbol] Name of the endpoint
  # @param format [Symbol] Response format (:json, :csv, :plain)
  # @return [String] Fixture content
  def load_fixture(endpoint_name, format = :json)
    fixture_path = File.join(fixtures_dir, "#{endpoint_name}.#{format}")

    return generate_fixture_content(endpoint_name, format) unless File.exist?(fixture_path)

    File.read(fixture_path)
  end

  # Get the fixtures directory path
  #
  # @return [String] Path to fixtures directory
  def fixtures_dir
    @fixtures_dir ||= File.join(File.dirname(__FILE__), "..", "fixtures")
  end

  # Generate fixture content for endpoints that don't have fixture files
  #
  # @param endpoint_name [String, Symbol] Name of the endpoint
  # @param format [Symbol] Response format
  # @return [String] Generated fixture content
  def generate_fixture_content(endpoint_name, format)
    case format
    when :json
      generate_json_fixture(endpoint_name)
    when :csv
      generate_csv_fixture(endpoint_name)
    else
      generate_plain_fixture(endpoint_name)
    end
  end

  private

  def generate_json_fixture(endpoint_name)
    case endpoint_name.to_sym
    when :quote
      {
        symbol: "AAPL",
        name: "Apple Inc",
        exchange: "NASDAQ",
        currency: "USD",
        datetime: "2024-01-15",
        open: "185.00",
        high: "187.50",
        low: "184.20",
        close: "186.75",
        volume: "45678900",
        previous_close: "184.30",
        change: "2.45",
        percent_change: "1.33",
        average_volume: "65432100",
        fifty_two_week: {
          low: "124.17",
          high: "199.62",
          low_change: "62.58",
          high_change: "-12.87",
          low_change_percent: "50.38",
          high_change_percent: "-6.44",
          range: "124.17 - 199.62"
        }
      }.to_json
    when :price
      { price: "186.75" }.to_json
    when :api_usage
      {
        timestamp: "2024-01-15 10:30:00",
        current_usage: 150,
        plan_limit: 800
      }.to_json
    when :time_series
      {
        meta: {
          symbol: "AAPL",
          interval: "1day",
          currency: "USD",
          exchange_timezone: "America/New_York",
          exchange: "NASDAQ",
          type: "Common Stock"
        },
        values: [
          {
            datetime: "2024-01-15",
            open: "185.00",
            high: "187.50",
            low: "184.20",
            close: "186.75",
            volume: "45678900"
          },
          {
            datetime: "2024-01-14",
            open: "183.50",
            high: "185.25",
            low: "182.80",
            close: "184.30",
            volume: "42156800"
          }
        ],
        status: "ok"
      }.to_json
    when /error/
      generate_error_fixture(endpoint_name)
    else
      { message: "Test fixture for #{endpoint_name}" }.to_json
    end
  end

  def generate_csv_fixture(endpoint_name)
    case endpoint_name.to_sym
    when :quote
      [
        "symbol;name;exchange;currency;datetime;open;high;low;close;volume",
        "AAPL;Apple Inc;NASDAQ;USD;2024-01-15;185.00;187.50;184.20;186.75;45678900"
      ].join("\n")
    when :time_series
      [
        "datetime;open;high;low;close;volume",
        "2024-01-15;185.00;187.50;184.20;186.75;45678900",
        "2024-01-14;183.50;185.25;182.80;184.30;42156800"
      ].join("\n")
    when :stocks
      [
        "symbol;name;currency;exchange;country;type",
        "AAPL;Apple Inc;USD;NASDAQ;United States;Common Stock",
        "GOOGL;Alphabet Inc;USD;NASDAQ;United States;Common Stock",
        "MSFT;Microsoft Corporation;USD;NASDAQ;United States;Common Stock"
      ].join("\n")
    else
      "test_column;value\ntest_data;#{endpoint_name}"
    end
  end

  def generate_plain_fixture(_endpoint_name)
    "Plain text response for testing"
  end

  def generate_error_fixture(endpoint_name)
    error_code = extract_error_code(endpoint_name)
    error_message = error_messages[error_code] || "Test error occurred"

    {
      code: error_code,
      message: error_message,
      status: "error"
    }.to_json
  end

  def extract_error_code(endpoint_name)
    case endpoint_name.to_s
    when /400/
      400
    when /401/
      401
    when /403/
      403
    when /404/
      404
    when /429/
      429
    when /500/
      500
    else
      400
    end
  end

  def error_messages
    {
      400 => "Bad Request: Invalid parameters provided",
      401 => "Unauthorized: Invalid API key",
      403 => "Forbidden: Access denied",
      404 => "Not Found: Endpoint or symbol not found",
      429 => "Too Many Requests: Rate limit exceeded",
      500 => "Internal Server Error: Service temporarily unavailable"
    }
  end
end
