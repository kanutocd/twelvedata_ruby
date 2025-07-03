# frozen_string_literal: true

require "csv"
require "json"
require "tempfile"

module TwelvedataRuby
  # Handles API responses from Twelve Data
  class Response
    # CSV column separator used by Twelve Data
    CSV_COL_SEP = ";"

    # Maximum response body size to keep in memory
    BODY_MAX_BYTESIZE = 16_000

    # HTTP status code ranges
    HTTP_STATUSES = {
      http_error: (400..600),
      success: (200..299)
    }.freeze

    # Content type handlers for different response formats
    CONTENT_TYPE_HANDLERS = {
      json: { parser: :parse_json, dumper: :dump_json },
      csv: { parser: :parse_csv, dumper: :dump_csv },
      plain: { parser: :parse_plain, dumper: :to_s }
    }.freeze

    class << self
      # Resolve HTTP response into Response or ResponseError
      #
      # @param http_response [HTTPX::Response] HTTP response from client
      # @param request [Request] Original request object
      # @return [Response, ResponseError] Resolved response or error
      def resolve(http_response, request)
        if success_status?(http_response.status)
          new(http_response: http_response, request: request)
        else
          create_error_from_response(http_response, request)
        end
      rescue StandardError => e
        ResponseError.new(
          message: "Failed to resolve response: #{e.message}",
          request: request,
          original_error: e
        )
      end

      # Get all valid HTTP status codes
      #
      # @return [Array<Integer>] Array of valid status codes
      def valid_status_codes
        @valid_status_codes ||= HTTP_STATUSES.values.flat_map(&:to_a)
      end

      private

      def success_status?(status)
        HTTP_STATUSES[:success].include?(status)
      end

      def create_error_from_response(http_response, request)
        json_data = extract_error_data(http_response)
        error_class = determine_error_class(http_response.status)
        error_class.new(json_data:, request:, status_code: http_response.status, message: json_data[:message])
      end

      def extract_error_data(http_response)
        if http_response.respond_to?(:error) && http_response.error
          {
            message: http_response.error.message,
            code: http_response.error.class.name
          }
        else
          {
            message: http_response.body.to_s,
            code: http_response.status
          }
        end
      rescue StandardError
        { message: "Unknown error", code: http_response.status }
      end

      def determine_error_class(status_code)
        error_class_name = ResponseError.error_class_for_code(status_code, :http) ||
                          ResponseError.error_class_for_code(status_code, :api)

        if error_class_name
          TwelvedataRuby.const_get(error_class_name)
        else
          ResponseError
        end
      end
    end

    attr_reader :http_response, :headers, :body_bytesize, :request

    # Initialize response with HTTP response and request
    #
    # @param http_response [HTTPX::Response] HTTP response object
    # @param request [Request] Original request object
    def initialize(http_response:, request:)
      @http_response = http_response
      @request = request
      @headers = http_response.headers
      @body_bytesize = http_response.body.bytesize
      @parsed_body = nil
    end

    # Get attachment filename from response headers
    #
    # @return [String, nil] Filename if present in headers
    def attachment_filename
      return nil unless headers["content-disposition"]

      @attachment_filename ||= extract_filename_from_headers
    end

    # Get content type from response
    #
    # @return [Symbol, nil] Content type symbol (:json, :csv, :plain)
    def content_type
      @content_type ||= detect_content_type
    end

    # Get parsed response body
    #
    # @return [Hash, CSV::Table, String] Parsed response data
    def parsed_body
      @parsed_body ||= parse_response_body
    end
    alias body parsed_body

    # Get response error if present
    #
    # @return [ResponseError, nil] Error object if response contains an error
    def error
      return nil unless parsed_body.is_a?(Hash) && parsed_body.key?(:code)

      @error ||= create_response_error
    end

    # Get HTTP status code
    #
    # @return [Integer] HTTP status code
    def http_status_code
      http_response.status
    end

    # Get API status code (from response body)
    #
    # @return [Integer] API status code
    def status_code
      @status_code ||= extract_status_code
    end

    # Check if HTTP response was successful
    #
    # @return [Boolean] True if HTTP status indicates success
    def success?
      HTTP_STATUSES[:success].include?(http_status_code)
    end

    # Save response to disk file
    #
    # @param file_path [String] Path to save file (defaults to attachment filename)
    # @return [File, nil] File object if successful, nil otherwise
    def save_to_file(file_path = nil)
      file_path ||= attachment_filename
      return nil unless file_path

      File.open(file_path, "w") do |file|
        file.write(dump_parsed_body)
      end
    rescue StandardError => e
      raise ResponseError.new(
        message: "Failed to save response to file: #{e.message}",
        original_error: e
      )
    end

    # Get dumped (serialized) version of parsed body
    #
    # @return [String] Serialized response body
    def dump_parsed_body
      handler = CONTENT_TYPE_HANDLERS[content_type]
      return parsed_body.to_s unless handler

      send(handler[:dumper])
    end

    # String representation of response
    #
    # @return [String] Response summary
    def to_s
      status_info = "#{http_status_code} (#{success? ? 'success' : 'error'})"
      "Response: #{status_info}, Content-Type: #{content_type}, Size: #{body_bytesize} bytes"
    end

    # Detailed inspection of response
    #
    # @return [String] Detailed response information
    def inspect
      "#<#{self.class.name}:#{object_id} status=#{http_status_code} content_type=#{content_type} " \
      "size=#{body_bytesize} error=#{error ? 'yes' : 'no'}>"
    end

    private

    def extract_filename_from_headers
      disposition = headers["content-disposition"]
      return nil unless disposition

      # Extract filename from Content-Disposition header
      match = disposition.match(/filename="([^"]+)"/)
      match ? match[1] : nil
    end

    def detect_content_type
      content_type_header = headers["content-type"]
      return :plain unless content_type_header

      case content_type_header
      when /json/
        :json
      when /csv/
        :csv
      else
        :plain
      end
    end

    def parse_response_body
      return nil unless http_response.body

      begin
        if body_bytesize < BODY_MAX_BYTESIZE
          parse_body_content(http_response.body.to_s)
        else
          parse_large_body_content
        end
      ensure
        http_response.body.close if http_response.body.respond_to?(:close)
      end
    end

    def parse_body_content(content)
      handler = CONTENT_TYPE_HANDLERS[content_type]
      return content unless handler

      send(handler[:parser], content)
    end

    def parse_large_body_content
      Tempfile.create do |temp_file|
        http_response.body.copy_to(temp_file)
        temp_file.rewind
        parse_body_content(temp_file.read)
      end
    end

    def parse_json(content)
      JSON.parse(content, symbolize_names: true)
    rescue JSON::ParserError => e
      raise ResponseError.new(
        message: "Failed to parse JSON response: #{e.message}",
        original_error: e
      )
    end

    def parse_csv(content)
      CSV.parse(content, headers: true, col_sep: CSV_COL_SEP)
    rescue CSV::MalformedCSVError => e
      raise ResponseError.new(
        message: "Failed to parse CSV response: #{e.message}",
        original_error: e
      )
    end

    def parse_plain(content)
      content.to_s
    end

    def dump_json
      return nil unless parsed_body.is_a?(Hash)

      JSON.dump(parsed_body)
    end

    def dump_csv
      return nil unless parsed_body.is_a?(CSV::Table)

      parsed_body.to_csv(col_sep: CSV_COL_SEP)
    end

    def extract_status_code
      if parsed_body.is_a?(Hash) && parsed_body[:code]
        parsed_body[:code]
      else
        http_status_code
      end
    end

    def create_response_error
      error_class_name = ResponseError.error_class_for_code(status_code)
      error_class = error_class_name ? TwelvedataRuby.const_get(error_class_name) : ResponseError

      error_class.new(
        json_data: parsed_body,
        request: request,
        status_code: status_code,
        message: parsed_body[:message]
      )
    end
  end
end
