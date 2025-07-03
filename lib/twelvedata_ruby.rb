# frozen_string_literal: true

require_relative "twelvedata_ruby/version"
require_relative "twelvedata_ruby/utils"
require_relative "twelvedata_ruby/error"
require_relative "twelvedata_ruby/endpoint"
require_relative "twelvedata_ruby/request"
require_relative "twelvedata_ruby/response"
require_relative "twelvedata_ruby/client"

# TwelvedataRuby provides a Ruby interface for accessing Twelve Data's financial API
#
# @example Basic usage
#   client = TwelvedataRuby.client(apikey: "your-api-key")
#   response = client.quote(symbol: "AAPL")
#   puts response.parsed_body
#
# @example Using environment variable for API key
#   ENV['TWELVEDATA_API_KEY'] = 'your-api-key'
#   client = TwelvedataRuby.client
#   response = client.price(symbol: "GOOGL")
module TwelvedataRuby
  class << self
    # Creates and configures a client instance
    #
    # @param options [Hash] Configuration options
    # @option options [String] :apikey The Twelve Data API key
    # @option options [Integer] :connect_timeout Connection timeout in milliseconds
    # @option options [String] :apikey_env_var_name Environment variable name for API key
    #
    # @return [Client] Configured client instance
    #
    # @example Basic client creation
    #   client = TwelvedataRuby.client(apikey: "your-key")
    #
    # @example With custom timeout
    #   client = TwelvedataRuby.client(
    #     apikey: "your-key",
    #     connect_timeout: 5000
    #   )
    def client(**options)
      client_instance = Client.instance
      client_instance.configure(**options) if options.any?
      client_instance
    end

    # Returns the current version
    #
    # @return [String] Version string
    def version
      VERSION
    end
  end
end
