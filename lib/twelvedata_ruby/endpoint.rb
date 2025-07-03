# frozen_string_literal: true

module TwelvedataRuby
  # Handles endpoint definitions, validation, and parameter management
  class Endpoint
    DEFAULT_FORMAT = :json
    VALID_FORMATS = [DEFAULT_FORMAT, :csv].freeze

    # Complete endpoint definitions with parameters and response structure
    DEFINITIONS = {
      api_usage: {
        parameters: { keys: %i[format] },
        response: { keys: %i[timestamp current_usage plan_limit] }
      },
      stocks: {
        parameters: { keys: %i[symbol exchange country type format] },
        response: { data_keys: %i[symbol name currency exchange country type], collection: :data }
      },
      forex_pairs: {
        parameters: { keys: %i[symbol currency_base currency_quote format] },
        response: { data_keys: %i[symbol currency_group currency_base currency_quote], collection: :data }
      },
      cryptocurrencies: {
        parameters: { keys: %i[symbol exchange currency_base currency_quote format] },
        response: { data_keys: %i[symbol available_exchanges currency_base currency_quote], collection: :data }
      },
      etf: {
        parameters: { keys: %i[symbol format] },
        response: { data_keys: %i[symbol name currency exchange], collection: :data }
      },
      indices: {
        parameters: { keys: %i[symbol country format] },
        response: { data_keys: %i[symbol name country currency], collection: :data }
      },
      exchanges: {
        parameters: { keys: %i[type name code country format] },
        response: { data_keys: %i[name country code timezone], collection: :data }
      },
      cryptocurrency_exchanges: {
        parameters: { keys: %i[name format] },
        response: { data_keys: %i[name], collection: :data }
      },
      technical_indicators: {
        parameters: { keys: [] },
        response: { keys: %i[enable full_name description type overlay parameters output_values tinting] }
      },
      symbol_search: {
        parameters: { keys: %i[symbol outputsize], required: %i[symbol] },
        response: {
          data_keys: %i[symbol instrument_name exchange exchange_timezone instrument_type country],
          collection: :data
        }
      },
      earliest_timestamp: {
        parameters: { keys: %i[symbol interval exchange] },
        response: { keys: %i[datetime unix_time] }
      },
      time_series: {
        parameters: {
          keys: %i[
            symbol interval exchange country type outputsize format dp order timezone
            start_date end_date previous_close
          ],
          required: %i[symbol interval]
        },
        response: {
          value_keys: %i[datetime open high low close volume],
          collection: :values,
          meta_keys: %i[symbol interval currency exchange_timezone exchange type]
        }
      },
      quote: {
        parameters: {
          keys: %i[symbol interval exchange country volume_time_period type format],
          required: %i[symbol]
        },
        response: {
          keys: %i[
            symbol name exchange currency datetime open high low close volume
            previous_close change percent_change average_volume fifty_two_week
          ]
        }
      },
      price: {
        parameters: { keys: %i[symbol exchange country type format], required: %i[symbol] },
        response: { keys: %i[price] }
      },
      eod: {
        parameters: { keys: %i[symbol exchange country type prepost dp], required: %i[symbol] },
        response: { keys: %i[symbol exchange currency datetime close] }
      },
      exchange_rate: {
        parameters: { keys: %i[symbol format precision timezone], required: %i[symbol] },
        response: { keys: %i[symbol rate timestamp] }
      },
      currency_conversion: {
        parameters: { keys: %i[symbol amount format precision timezone], required: %i[symbol amount] },
        response: { keys: %i[symbol rate amount timestamp] }
      },
      complex_data: {
        parameters: {
          keys: %i[symbols intervals start_date end_date dp order timezone methods name],
          required: %i[symbols intervals start_date end_date]
        },
        response: { keys: %i[data status] },
        http_verb: :post
      },
      earnings: {
        parameters: { keys: %i[symbol exchange country type period outputsize format], required: %i[symbol] },
        response: { keys: %i[date time eps_estimate eps_actual difference surprise_prc] }
      },
      earnings_calendar: {
        parameters: { keys: %i[format] },
        response: {
          keys: %i[
            symbol name currency exchange country time eps_estimate eps_actual difference surprise_prc
          ]
        }
      }
    }.freeze

    class << self
      # Get processed endpoint definitions with apikey parameter added
      #
      # @return [Hash] Complete endpoint definitions
      def definitions
        @definitions ||= build_definitions
      end

      # Get all valid endpoint names
      #
      # @return [Array<Symbol>] Array of endpoint names
      def names
        @names ||= definitions.keys
      end

      # Get default API key parameters
      #
      # @return [Hash] Default parameters including API key
      def default_apikey_params
        { apikey: Client.instance.apikey }
      end

      # Validate endpoint name
      #
      # @param name [Symbol, String] Endpoint name to validate
      # @return [Boolean] True if valid endpoint name
      def valid_name?(name)
        names.include?(name&.to_sym)
      end

      # Validate endpoint parameters
      #
      # @param name [Symbol, String] Endpoint name
      # @param params [Hash] Parameters to validate
      # @return [Boolean] True if parameters are valid
      def valid_params?(name, **params)
        new(name, **params).valid?
      end

      private

      def build_definitions
        DEFINITIONS.transform_values do |definition|
          enhanced_params = definition[:parameters].dup
          enhanced_params[:keys] = enhanced_params[:keys] + [:apikey]
          enhanced_params[:required] = (enhanced_params[:required] || []) + [:apikey]

          definition.merge(parameters: enhanced_params)
        end.freeze
      end
    end

    attr_reader :name, :query_params

    # Initialize endpoint with name and parameters
    #
    # @param name [Symbol, String] Endpoint name
    # @param query_params [Hash] Query parameters
    def initialize(name, **query_params)
      @errors = {}
      self.name = name
      self.query_params = query_params
    end

    # Get endpoint definition
    #
    # @return [Hash, nil] Endpoint definition hash
    def definition
      @definition ||= self.class.definitions[name]
    end

    # Get validation errors
    #
    # @return [Hash] Hash of validation errors
    def errors
      @errors.compact
    end

    # Set endpoint name with validation
    #
    # @param name [Symbol, String] Endpoint name
    def name=(name)
      reset_cached_data
      @name = name.to_s.downcase.to_sym
      validate_name
    end

    # Get parameter definition
    #
    # @return [Hash, nil] Parameter definition
    def parameters
      definition&.dig(:parameters)
    end

    # Get parameter keys including format-specific ones
    #
    # @return [Array<Symbol>, nil] Array of valid parameter keys
    def parameters_keys
      return nil unless parameters

      keys = parameters[:keys].dup
      keys << :filename if csv_format_with_filename?
      keys
    end

    # Get query parameter keys
    #
    # @return [Array<Symbol>] Array of current query parameter keys
    def query_params_keys
      query_params.keys
    end

    # Set query parameters with validation and processing
    #
    # @param query_params [Hash] Query parameters to set
    def query_params=(query_params)
      reset_cached_data
      processed_params = process_query_params(query_params)
      @query_params = self.class.default_apikey_params.merge(processed_params.compact)
      validate_query_params
    end

    # Get required parameter keys
    #
    # @return [Array<Symbol>, nil] Array of required parameter keys
    def required_parameters
      parameters&.dig(:required)
    end

    # Check if endpoint and parameters are valid
    #
    # @return [Boolean] True if valid
    def valid?
      valid_name? && valid_query_params?
    end

    # Check if name is valid
    #
    # @return [Boolean] True if name is valid
    def valid_name?
      errors[:name].nil?
    end

    # Check if query parameters are valid
    #
    # @return [Boolean] True if query parameters are valid
    def valid_query_params?
      errors[:parameters_keys].nil? && errors[:required_parameters].nil?
    end

    private

    def reset_cached_data
      @definition = nil
    end

    def csv_format_with_filename?
      parameters&.dig(:keys)&.include?(:format) && query_params&.dig(:format) == :csv
    end

    def process_query_params(params)
      processed = params.dup

      # Normalize format parameter
      if parameters_keys&.include?(:format)
        processed[:format] = normalize_format(processed[:format])
      end

      # Remove filename if not CSV format
      if processed[:filename] && processed[:format] != :csv
        processed.delete(:filename)
      end

      processed
    end

    def normalize_format(format)
      VALID_FORMATS.include?(format) ? format : DEFAULT_FORMAT
    end

    def validate_name
      (@errors.delete(:name) || true) and return if self.class.valid_name?(name)

      invalid_name = name.nil? || name.to_s.empty? ? "blank name" : name
      @errors[:name] = create_error(:name, invalid_name, EndpointNameError)
    end

    def validate_query_params
      return unless valid_name? && parameters_keys

      validate_required_parameters
      validate_parameter_keys
    end

    def validate_required_parameters
      missing = required_parameters - query_params_keys
      return if missing.empty?

      @errors[:required_parameters] = create_error(:required_parameters, missing, EndpointRequiredParametersError)
    end

    def validate_parameter_keys
      invalid = query_params_keys - parameters_keys
      return if invalid.empty?

      @errors[:parameters_keys] = create_error(:parameters_keys, invalid, EndpointParametersKeysError)
    end

    def create_error(attr_name, invalid_values, error_class)
      error_class.new(endpoint: self, invalid: invalid_values)
    end
  end
end
