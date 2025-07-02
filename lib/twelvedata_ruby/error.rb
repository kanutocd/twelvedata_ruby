# frozen_string_literal: true

module TwelvedataRuby
  # Base error class for all TwelvedataRuby errors
  class Error < StandardError
    # Default error messages for different error types
    DEFAULT_MESSAGES = {
      "EndpointError" => "Endpoint is not valid: %{invalid}",
      "EndpointNameError" => "`%{invalid}` is not a valid endpoint. Valid endpoints: %{valid_names}",
      "EndpointParametersKeysError" => "Invalid parameters: %{invalid}. Valid parameters for `%{name}`: %{parameters}",
      "EndpointRequiredParametersError" => "Missing required parameters: %{invalid}. Required for `%{name}`: %{required}",
      "ResponseError" => "Response error occurred",
      "ConfigurationError" => "Configuration error: %{message}",
      "NetworkError" => "Network error: %{message}"
    }.freeze

    attr_reader :attributes, :original_error

    # Initialize error with message and attributes
    #
    # @param message [String, nil] Custom error message
    # @param attributes [Hash] Error attributes for interpolation
    # @param original_error [Exception, nil] Original exception that caused this error
    def initialize(message: nil, attributes: {}, original_error: nil)
      @attributes = attributes
      @original_error = original_error

      error_message = message || format_default_message
      super(error_message)
    end

    private

    def format_default_message
      template = DEFAULT_MESSAGES[Utils.demodulize(self.class.name)]
      return "An error occurred" unless template

      format(template, **attributes)
    rescue KeyError => e
      "Error message template missing key: #{e.key}"
    end
  end

  # Configuration-related errors
  class ConfigurationError < Error; end

  # Network-related errors
  class NetworkError < Error; end

  # Base class for endpoint-related errors
  class EndpointError < Error
    def initialize(endpoint:, invalid:, **options)
      attributes = {
        name: endpoint.name,
        invalid: invalid,
        valid_names: endpoint.class.names.join(", "),
        parameters: endpoint&.parameters_keys&.join(", "),
        required: endpoint&.required_parameters&.join(", ")
      }

      super(attributes: attributes, **options)
    end
  end

  # Error for invalid endpoint names
  class EndpointNameError < EndpointError; end

  # Error for invalid endpoint parameters
  class EndpointParametersKeysError < EndpointError; end

  # Error for missing required parameters
  class EndpointRequiredParametersError < EndpointError; end

  # Base class for API response errors
  class ResponseError < Error
    # Mapping of API error codes to specific error classes
    API_ERROR_CODES = {
      400 => "BadRequestResponseError",
      401 => "UnauthorizedResponseError",
      403 => "ForbiddenResponseError",
      404 => "NotFoundResponseError",
      414 => "ParameterTooLongResponseError",
      429 => "TooManyRequestsResponseError",
      500 => "InternalServerResponseError"
    }.freeze

    # Mapping of HTTP error codes to specific error classes
    HTTP_ERROR_CODES = {
      404 => "PageNotFoundResponseError"
    }.freeze

    class << self
      # Find appropriate error class for given code and type
      #
      # @param code [Integer] Error code
      # @param error_type [Symbol] Type of error (:api or :http)
      # @return [String, nil] Error class name
      def error_class_for_code(code, error_type = :api)
        case error_type
        when :api
          API_ERROR_CODES[code]
        when :http
          HTTP_ERROR_CODES[code]
        end
      end
    end

    attr_reader :json_data, :status_code, :request

    # Initialize response error
    #
    # @param json_data [Hash] JSON response data
    # @param request [Request] Original request object
    # @param status_code [Integer] HTTP/API status code
    # @param message [String, nil] Custom error message
    def initialize(json_data: {}, request: nil, status_code: nil, message: nil, **options)
      @json_data = json_data.is_a?(Hash) ? json_data : {}
      @status_code = status_code || @json_data[:code]
      @request = request

      error_message = message || @json_data[:message] || "Response error occurred"
      super(message: error_message, **options)
    end
  end

  # Specific API error classes
  class BadRequestResponseError < ResponseError; end
  class UnauthorizedResponseError < ResponseError; end
  class ForbiddenResponseError < ResponseError; end
  class NotFoundResponseError < ResponseError; end
  class ParameterTooLongResponseError < ResponseError; end
  class TooManyRequestsResponseError < ResponseError; end
  class InternalServerResponseError < ResponseError; end

  # HTTP-specific error classes
  class PageNotFoundResponseError < ResponseError; end
end
