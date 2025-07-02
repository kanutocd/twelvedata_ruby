# frozen_string_literal: true

require "forwardable"

module TwelvedataRuby
  # Represents an API request to Twelve Data
  class Request
    extend Forwardable

    # Default HTTP method for API requests
    DEFAULT_HTTP_VERB = :get

    def_delegators :endpoint, :name, :valid?, :query_params, :errors

    attr_reader :endpoint

    # Initialize a new request
    #
    # @param name [Symbol, String] Endpoint name
    # @param query_params [Hash] Query parameters for the request
    def initialize(name, **query_params)
      @endpoint = Endpoint.new(name, **query_params)
    end

    # Send the request using the client
    #
    # @return [Response, Hash, ResponseError] Response or error information
    def fetch
      Client.instance.fetch(self)
    end

    # Get the HTTP verb for this request
    #
    # @return [Symbol, nil] HTTP verb or nil if invalid
    def http_verb
      return nil unless valid?

      endpoint.definition[:http_verb] || DEFAULT_HTTP_VERB
    end

    # Get request parameters formatted for HTTP client
    #
    # @return [Hash, nil] Parameters hash or nil if invalid
    def params
      return nil unless valid?

      { params: endpoint.query_params }
    end

    # Get the relative URL path for this request
    #
    # @return [String, nil] URL path or nil if invalid
    def relative_url
      return nil unless valid?

      name.to_s
    end

    # Get the complete URL for this request
    #
    # @return [String, nil] Full URL or nil if invalid
    def full_url
      return nil unless valid?

      "#{Client::BASE_URL}/#{relative_url}"
    end

    # Convert request to hash representation
    #
    # @return [Hash, nil] Request as hash or nil if invalid
    def to_h
      return nil unless valid?

      {
        http_verb: http_verb,
        url: full_url,
        params: query_params
      }
    end

    # Convert request to array format for HTTPX
    #
    # @return [Array, nil] Request as array or nil if invalid
    def to_a
      return nil unless valid?

      [http_verb.to_s.upcase, full_url, params]
    end
    alias build to_a

    # String representation of the request
    #
    # @return [String] Human-readable request description
    def to_s
      if valid?
        "#{http_verb.to_s.upcase} #{full_url} with params: #{query_params}"
      else
        "Invalid request for endpoint: #{name}"
      end
    end

    # Detailed inspection of the request
    #
    # @return [String] Detailed request information
    def inspect
      "#<#{self.class.name}:#{object_id} endpoint=#{name} valid=#{valid?} params=#{query_params.keys}>"
    end

    # Check equality with another request
    #
    # @param other [Request] Request to compare with
    # @return [Boolean] True if requests are equivalent
    def ==(other)
      return false unless other.is_a?(self.class)

      name == other.name && query_params == other.query_params
    end
    alias eql? ==

    # Generate hash code for request
    #
    # @return [Integer] Hash code
    def hash
      [name, query_params].hash
    end
  end
end
