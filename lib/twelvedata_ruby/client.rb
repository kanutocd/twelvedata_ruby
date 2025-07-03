# frozen_string_literal: true

require "httpx"
require "singleton"

module TwelvedataRuby
  # HTTP client for making requests to the Twelve Data API
  class Client
    include Singleton

    # Default environment variable name for API key
    APIKEY_ENV_NAME = "TWELVEDATA_API_KEY"

    # Default connection timeout in milliseconds
    DEFAULT_CONNECT_TIMEOUT = 120

    # Base URL for the Twelve Data API
    BASE_URL = "https://api.twelvedata.com"

    class << self
      # Make HTTP requests using HTTPX
      #
      # @param request_objects [Request, Array<Request>] Request object(s) to send
      # @param options [Hash] Additional HTTPX options
      # @return [HTTPX::Response, Array<HTTPX::Response>] HTTP response(s)
      def request(request_objects, **options)
        requests = build_requests(request_objects)
        http_client = HTTPX.with(http_options.merge(options))

        http_client.request(requests)
      end

      # Build HTTP requests from Request objects
      #
      # @param requests [Request, Array<Request>] Request object(s)
      # @return [Array] Array of HTTP request specs
      def build_requests(requests)
        Utils.to_array(requests).map(&:build)
      end

      # Get HTTP client options
      #
      # @return [Hash] HTTPX options
      def http_options
        {
          origin: BASE_URL,
          timeout: { connect_timeout: instance.connect_timeout }
        }
      end
    end

    attr_reader :configuration

    def initialize
      @configuration = {}
      @endpoint_methods_defined = Set.new
      reset_configuration
    end

    # Configure the client with new options
    #
    # @param options [Hash] Configuration options
    # @option options [String] :apikey API key for authentication
    # @option options [Integer] :connect_timeout Connection timeout in milliseconds
    # @option options [String] :apikey_env_var_name Environment variable name for API key
    # @return [self] Returns self for method chaining
    def configure(**options)
      @configuration.merge!(options)
      self
    end

    # Get the current API key
    #
    # @return [String, nil] Current API key
    def apikey
      Utils.empty_to_nil(@configuration[:apikey]) || ENV[apikey_env_var_name]
    end

    # Set the API key
    #
    # @param apikey [String] New API key
    # @return [String] The API key that was set
    def apikey=(apikey)
      @configuration[:apikey] = apikey
    end

    # Get the connection timeout
    #
    # @return [Integer] Connection timeout in milliseconds
    def connect_timeout
      parse_timeout(@configuration[:connect_timeout])
    end

    # Set the connection timeout
    #
    # @param timeout [Integer, String] New timeout value
    # @return [Integer] The timeout that was set
    def connect_timeout=(timeout)
      @configuration[:connect_timeout] = parse_timeout(timeout)
    end

    # Get the environment variable name for the API key
    #
    # @return [String] Environment variable name
    def apikey_env_var_name
      (@configuration[:apikey_env_var_name] || APIKEY_ENV_NAME).upcase
    end

    # Set the environment variable name for the API key
    #
    # @param var_name [String] New environment variable name
    # @return [String] The variable name that was set (uppercased)
    def apikey_env_var_name=(var_name)
      @configuration[:apikey_env_var_name] = var_name.upcase
    end

    # Fetch data from an API endpoint
    #
    # @param request [Request] Request object to send
    # @return [Response, Hash, ResponseError] Response or error information
    def fetch(request)
      return nil unless request

      if request.valid?
        http_response = self.class.request(request)
        raise HTTPX::Error, "HTTP request failed" if http_response.error && http_response.response.nil?

        Response.resolve(http_response, request)
      else
        { errors: request.errors }
      end
    rescue StandardError => e
      handle_fetch_error(e, request)
    end

    # Handle method calls for API endpoints
    #
    # @param endpoint_name [String, Symbol] API endpoint name
    # @param endpoint_params [Hash] Parameters for the endpoint
    # @return [Response, Hash, ResponseError] API response or error
    def method_missing(endpoint_name, **endpoint_params, &block)
      if Endpoint.valid_name?(endpoint_name)
        define_endpoint_method(endpoint_name)
        send(endpoint_name, **endpoint_params)
      else
        super
      end
    end

    # Check if client responds to endpoint methods
    #
    # @param endpoint_name [String, Symbol] Method name to check
    # @param include_all [Boolean] Include private methods in check
    # @return [Boolean] True if client responds to the method
    def respond_to_missing?(endpoint_name, include_all = false)
      Endpoint.valid_name?(endpoint_name) || super
    end

    private

    def reset_configuration
      @configuration = {
        connect_timeout: DEFAULT_CONNECT_TIMEOUT
      }
    end

    def parse_timeout(value)
      Utils.to_integer(value, DEFAULT_CONNECT_TIMEOUT)
    end

    def handle_fetch_error(error, request)
      case error
      when HTTPX::Error
        NetworkError.new(
          message: "Network error occurred: #{error.message}",
          original_error: error
        )
      else
        ResponseError.new(
          message: "Unexpected error: #{error.message}",
          request: request,
          original_error: error
        )
      end
    end

    def define_endpoint_method(endpoint_name)
      return if @endpoint_methods_defined.include?(endpoint_name)

      define_singleton_method(endpoint_name) do |**params|
        @endpoint_methods_defined.add(endpoint_name)
        request = Request.new(endpoint_name, **params)
        fetch(request)
      end
    end
  end
end
