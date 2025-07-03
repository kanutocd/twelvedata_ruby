# frozen_string_literal: true

RSpec.describe TwelvedataRuby::Endpoint do
  describe "constants" do
    describe "DEFAULT_FORMAT" do
      it "is set to :json" do
        expect(described_class::DEFAULT_FORMAT).to eq(:json)
      end
    end

    describe "VALID_FORMATS" do
      it "contains json and csv formats" do
        expect(described_class::VALID_FORMATS).to eq([:json, :csv])
      end

      it "is frozen" do
        expect(described_class::VALID_FORMATS).to be_frozen
      end
    end

    describe "DEFINITIONS" do
      it "is a hash containing endpoint definitions" do
        expect(described_class::DEFINITIONS).to be_a(Hash)
        expect(described_class::DEFINITIONS).to be_frozen
      end

      it "contains expected endpoints" do
        expected_endpoints = %i[
          api_usage stocks forex_pairs cryptocurrencies etf indices exchanges
          cryptocurrency_exchanges technical_indicators symbol_search earliest_timestamp
          time_series quote price eod exchange_rate currency_conversion complex_data
          earnings earnings_calendar
        ]

        expect(described_class::DEFINITIONS.keys).to include(*expected_endpoints)
      end

      it "has consistent structure for all definitions" do
        described_class::DEFINITIONS.each do |name, definition|
          expect(definition).to have_key(:parameters)
          expect(definition).to have_key(:response)
          expect(definition[:parameters]).to have_key(:keys)

          # Check parameters is an array
          expect(definition[:parameters][:keys]).to be_an(Array)
        end
      end
    end
  end

  describe "class methods" do
    describe ".definitions" do
      it "returns enhanced definitions with apikey parameter" do
        definitions = described_class.definitions

        expect(definitions).to be_a(Hash)
        expect(definitions).to be_frozen

        # All endpoints should have apikey in parameters
        definitions.each do |name, definition|
          expect(definition[:parameters][:keys]).to include(:apikey)
          expect(definition[:parameters][:required]).to include(:apikey)
        end
      end

      it "caches the result" do
        first_call = described_class.definitions
        second_call = described_class.definitions

        expect(first_call).to be(second_call)
      end
    end

    describe ".names" do
      it "returns all endpoint names" do
        names = described_class.names

        expect(names).to be_an(Array)
        expect(names).to all(be_a(Symbol))
        expect(names).to include(:quote, :price, :api_usage, :time_series)
      end

      it "caches the result" do
        first_call = described_class.names
        second_call = described_class.names

        expect(first_call).to be(second_call)
      end
    end

    describe ".default_apikey_params" do
      include_context "with valid API key"

      it "returns hash with current client API key" do
        params = described_class.default_apikey_params

        expect(params).to eq({ apikey: TwelvedataRuby::Client.instance.apikey })
      end

      it "updates when client API key changes" do
        old_params = described_class.default_apikey_params

        TwelvedataRuby::Client.instance.apikey = "new-key"
        new_params = described_class.default_apikey_params

        expect(new_params[:apikey]).to eq("new-key")
        expect(new_params[:apikey]).not_to eq(old_params[:apikey])
      end
    end

    describe ".valid_name?" do
      it "returns true for valid endpoint names" do
        expect(described_class.valid_name?(:quote)).to be(true)
        expect(described_class.valid_name?("price")).to be(true)
        expect(described_class.valid_name?(:api_usage)).to be(true)
      end

      it "returns false for invalid endpoint names" do
        expect(described_class.valid_name?(:invalid_endpoint)).to be(false)
        expect(described_class.valid_name?("nonexistent")).to be(false)
        expect(described_class.valid_name?(nil)).to be(false)
      end
    end

    describe ".valid_params?" do
      it "returns true for valid parameters" do
        expect(described_class.valid_params?(:quote, symbol: "AAPL", apikey: "test")).to be(true)
        expect(described_class.valid_params?(:api_usage, apikey: "test")).to be(true)
      end

      it "returns false for missing required parameters" do
        expect(described_class.valid_params?(:quote)).to be(false)
      end

      it "returns false for invalid parameters" do
        expect(described_class.valid_params?(:quote, symbol: "AAPL", invalid: "param", apikey: "test")).to be(false)
      end
    end
  end

  describe "instance methods" do
    subject(:endpoint) { described_class.new(endpoint_name, **params) }
    let(:endpoint_name) { :quote }
    let(:params) { { symbol: "AAPL" } }

    describe "#initialize" do
      it "creates endpoint with name and parameters" do
        expect(endpoint.name).to eq(:quote)
        expect(endpoint.query_params).to include(symbol: "AAPL")
      end

      it "initializes errors as empty hash" do
        expect(endpoint.errors).to eq({})
      end
    end

    describe "#name=" do
      it "converts string to downcased symbol" do
        endpoint.name = "QUOTE"
        expect(endpoint.name).to eq(:quote)

        endpoint.name = "Price"
        expect(endpoint.name).to eq(:price)
      end

      it "validates the name" do
        endpoint.name = :invalid_endpoint
        expect(endpoint.errors[:name]).to be_a(TwelvedataRuby::EndpointNameError)
      end

      it "resets cached data when name changes" do
        original_definition = endpoint.definition
        endpoint.name = :price

        expect(endpoint.definition).not_to be(original_definition)
      end
    end

    describe "#definition" do
      context "with valid endpoint" do
        it "returns endpoint definition" do
          definition = endpoint.definition

          expect(definition).to be_a(Hash)
          expect(definition).to have_key(:parameters)
          expect(definition).to have_key(:response)
        end
      end

      context "with invalid endpoint" do
        let(:endpoint_name) { :invalid }

        it "returns nil" do
          expect(endpoint.definition).to be_nil
        end
      end
    end

    describe "#parameters_keys" do
      context "with valid endpoint" do
        it "returns array of parameter keys" do
          keys = endpoint.parameters_keys

          expect(keys).to be_an(Array)
          expect(keys).to include(:symbol, :apikey)
        end
      end

      context "with CSV format" do
        let(:params) { { symbol: "AAPL", format: :csv } }

        it "includes filename parameter" do
          expect(endpoint.parameters_keys).to include(:filename)
        end
      end

      context "with invalid endpoint" do
        let(:endpoint_name) { :invalid }

        it "returns nil" do
          expect(endpoint.parameters_keys).to be_nil
        end
      end
    end

    describe "#query_params=" do
      it "merges with default API key params" do
        endpoint.query_params = { symbol: "GOOGL", format: :csv }

        expect(endpoint.query_params[:symbol]).to eq("GOOGL")
        expect(endpoint.query_params[:format]).to eq(:csv)
        expect(endpoint.query_params[:apikey]).to eq(TwelvedataRuby::Client.instance.apikey)
      end

      it "normalizes invalid format to default" do
        endpoint.query_params = { symbol: "AAPL", format: :invalid }

        expect(endpoint.query_params[:format]).to eq(described_class::DEFAULT_FORMAT)
      end

      it "removes filename when format is not CSV" do
        endpoint.query_params = { symbol: "AAPL", format: :json, filename: "test.csv" }

        expect(endpoint.query_params).not_to have_key(:filename)
      end

      it "keeps filename when format is CSV" do
        endpoint.query_params = { symbol: "AAPL", format: :csv, filename: "test.csv" }

        expect(endpoint.query_params[:filename]).to eq("test.csv")
      end

      it "compacts nil values" do
        endpoint.query_params = { symbol: "AAPL", invalid: nil, format: :json }

        expect(endpoint.query_params).not_to have_key(:invalid)
      end
    end

    describe "#required_parameters" do
      context "with valid endpoint" do
        it "returns required parameter keys" do
          required = endpoint.required_parameters

          expect(required).to be_an(Array)
          expect(required).to include(:symbol, :apikey)
        end
      end

      context "with endpoint having no required params except apikey" do
        let(:endpoint_name) { :api_usage }

        it "returns only apikey as required" do
          expect(endpoint.required_parameters).to eq([:apikey])
        end
      end

      context "with invalid endpoint" do
        let(:endpoint_name) { :invalid }

        it "returns nil" do
          expect(endpoint.required_parameters).to be_nil
        end
      end
    end

    describe "#valid?" do
      context "with valid endpoint and parameters" do
        it "returns true" do
          expect(endpoint).to be_valid
        end
      end

      context "with invalid endpoint name" do
        let(:endpoint_name) { :invalid }

        it "returns false" do
          expect(endpoint).not_to be_valid
        end
      end

      context "with missing required parameters" do
        let(:params) { {} }

        it "returns false" do
          expect(endpoint).not_to be_valid
        end
      end

      context "with invalid parameters" do
        let(:params) { { symbol: "AAPL", invalid_param: "value" } }

        it "returns false" do
          expect(endpoint).not_to be_valid
        end
      end
    end

    describe "#valid_name?" do
      context "with valid name" do
        it "returns true" do
          expect(endpoint).to be_valid_name
        end
      end

      context "with invalid name" do
        let(:endpoint_name) { :invalid }

        it "returns false" do
          expect(endpoint).not_to be_valid_name
        end
      end
    end

    describe "#valid_query_params?" do
      context "with valid parameters" do
        it "returns true" do
          expect(endpoint).to be_valid_query_params
        end
      end

      context "with missing required parameters" do
        let(:params) { {} }

        it "returns false" do
          expect(endpoint).not_to be_valid_query_params
        end
      end

      context "with invalid parameter keys" do
        let(:params) { { symbol: "AAPL", invalid_param: "value" } }

        it "returns false" do
          expect(endpoint).not_to be_valid_query_params
        end
      end
    end

    describe "#errors" do
      context "with valid endpoint" do
        it "returns empty hash" do
          expect(endpoint.errors).to eq({})
        end
      end

      context "with invalid endpoint name" do
        let(:endpoint_name) { :invalid }

        it "includes name error" do
          expect(endpoint.errors[:name]).to be_a(TwelvedataRuby::EndpointNameError)
        end
      end

      context "with missing required parameters" do
        let(:params) { {} }

        it "includes required parameters error" do
          expect(endpoint.errors[:required_parameters]).to be_a(TwelvedataRuby::EndpointRequiredParametersError)
        end
      end

      context "with invalid parameter keys" do
        let(:params) { { symbol: "AAPL", invalid_param: "value" } }

        it "includes parameter keys error" do
          expect(endpoint.errors[:parameters_keys]).to be_a(TwelvedataRuby::EndpointParametersKeysError)
        end
      end

      it "compacts nil errors" do
        errors = endpoint.errors
        expect(errors.values).not_to include(nil)
      end
    end

    describe "validation scenarios" do
      context "correcting invalid endpoint" do
        let(:endpoint_name) { :invalid }
        let(:params) { {} }

        it "can be corrected step by step" do
          expect(endpoint).not_to be_valid

          endpoint.name = :quote

          expect(endpoint.valid_name?).to eq(true)
          expect(endpoint).not_to be_valid_query_params

          endpoint.query_params = { symbol: "AAPL" }
          expect(endpoint.valid_query_params?).to eq(true)
          expect(endpoint).to be_valid
        end
      end

      context "with complex endpoint" do
        let(:endpoint_name) { :time_series }
        let(:params) { { symbol: "AAPL", interval: "1day", format: :csv, filename: "data.csv" } }

        it "validates complex parameters correctly" do
          expect(endpoint).to be_valid
          expect(endpoint.query_params[:filename]).to eq("data.csv")
          expect(endpoint.parameters_keys).to include(:filename)
        end
      end
    end

    describe "edge cases" do
      context "with nil or empty name" do
        it "handles nil name" do
          endpoint = described_class.new(nil)
          expect(endpoint.name).to eq(:"")
          expect(endpoint).not_to be_valid_name
        end

        it "handles empty string name" do
          endpoint = described_class.new("")
          expect(endpoint.name).to eq(:"")
          expect(endpoint).not_to be_valid_name

        end
      end

      context "with symbol name" do
        let(:endpoint_name) { :"quote" }

        it "handles symbol input correctly" do
          expect(endpoint.name).to eq(:quote)
          expect(endpoint).to be_valid_name
        end
      end

      context "with parameter edge cases" do
        it "handles empty parameters hash" do
          endpoint.query_params = {}
          expect(endpoint.query_params[:apikey]).to eq(TwelvedataRuby::Client.instance.apikey)
        end

        it "handles parameters with string keys" do
          endpoint.query_params = { "symbol" => "AAPL" }
          # Should convert string keys to symbols (this depends on implementation)
          expect(endpoint.query_params).to have_key(:apikey)
        end
      end
    end
  end

  describe "integration with other classes" do
    it "works with Client's default_apikey_params" do
      TwelvedataRuby::Client.instance.apikey = "integration-test-key"
      endpoint = described_class.new(:quote, symbol: "AAPL")

      expect(endpoint.query_params[:apikey]).to eq("integration-test-key")
    end

    it "creates appropriate error objects" do
      endpoint = described_class.new(:invalid, invalid_param: "value")

      errors = endpoint.errors
      expect(errors[:name]).to be_a(TwelvedataRuby::EndpointNameError)
      expect(errors[:name].attributes[:name]).to eq(:invalid)
    end
  end
end
