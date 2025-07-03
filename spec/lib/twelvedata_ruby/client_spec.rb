# frozen_string_literal: true

RSpec.describe TwelvedataRuby::Client do
  describe "constants" do
    it "defines expected constants" do
      expect(described_class::APIKEY_ENV_NAME).to eq("TWELVEDATA_API_KEY")
      expect(described_class::DEFAULT_CONNECT_TIMEOUT).to eq(120)
      expect(described_class::BASE_URL).to eq("https://api.twelvedata.com")
    end
  end

  describe "singleton behavior" do
    it "includes Singleton module" do
      expect(described_class.ancestors).to include(Singleton)
    end

    it "returns the same instance" do
      first_instance = described_class.instance
      second_instance = described_class.instance

      expect(first_instance).to be(second_instance)
    end

    it "cannot be instantiated with new" do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  describe "class methods" do
    describe ".request" do
      let(:mocked_request) { mock_request(:quote, symbol: "AAPL") }
      let(:mocked_requests) { [mocked_request, mock_request(:price, symbol: "GOOGL")] }

      before do
        stub_successful_request(mocked_request)
        stub_multiple_requests(mocked_requests)
      end

      context "with single request" do
        it "makes HTTP request and returns response" do
          response = described_class.request(mocked_request)

          expect(response).to respond_to(:status)
          expect(response).to respond_to(:body)
        end

        it "uses correct HTTP options" do
          expect(HTTPX).to receive(:with).with(hash_including(origin: described_class::BASE_URL))
                                         .and_call_original

          described_class.request(mocked_request)
        end
      end

      context "with multiple requests" do
        it "handles array of requests" do
          responses = described_class.request(mocked_requests)

          expect(responses).to be_an(Array)
          expect(responses.size).to eq(2)
        end
      end

      context "with custom options" do
        it "merges custom options with defaults" do
          custom_options = { timeout: { read_timeout: 30 } }

          expect(HTTPX).to receive(:with).with(hash_including(custom_options))
                                         .and_call_original

          described_class.request(mocked_request, **custom_options)
        end
      end
    end

    describe ".build_requests" do
      let(:mock_request1) { mock_request(:quote, symbol: "AAPL") }
      let(:mock_request2) { mock_request(:price, symbol: "GOOGL") }

      it "builds single request" do
        result = described_class.build_requests(mock_request1)

        expect(result).to eq([mock_request1.build])
      end

      it "builds multiple requests" do
        result = described_class.build_requests([mock_request1, mock_request2])

        expect(result).to eq([mock_request1.build, mock_request2.build])
      end
    end

    describe ".http_options" do
      it "returns correct HTTP options" do
        options = described_class.http_options

        expect(options).to include(
          origin: described_class::BASE_URL,
          timeout: { connect_timeout: described_class.instance.connect_timeout }
        )
      end

      it "updates when instance timeout changes" do
        original_options = described_class.http_options

        described_class.instance.connect_timeout = 200
        new_options = described_class.http_options

        expect(new_options[:timeout][:connect_timeout]).to eq(200)
        expect(new_options[:timeout][:connect_timeout]).not_to eq(original_options[:timeout][:connect_timeout])
      end
    end
  end

  describe "instance methods" do
    subject(:client) { described_class.instance }

    describe "#initialize" do
      it "initializes with default configuration" do
        expect(client.configuration).to be_a(Hash)
        expect(client.connect_timeout).to eq(described_class::DEFAULT_CONNECT_TIMEOUT)
      end

      it "initializes endpoint methods tracking" do
        expect(client.instance_variable_get(:@endpoint_methods_defined)).to be_a(Set)
      end
    end

    describe "#configure" do
      let(:options) { { apikey: "new-key", connect_timeout: 300 } }

      it "updates configuration with provided options" do
        client.configure(**options)

        expect(client.apikey).to eq("new-key")
        expect(client.connect_timeout).to eq(300)
      end

      it "returns self for method chaining" do
        result = client.configure(**options)
        expect(result).to be(client)
      end

      it "merges with existing configuration" do
        client.configure(apikey: "first-key")
        client.configure(connect_timeout: 500)

        expect(client.apikey).to eq("first-key")
        expect(client.connect_timeout).to eq(500)
      end
    end

    describe "#apikey" do
      context "when apikey is set in configuration" do
        before { client.configure(apikey: "config-key") }

        it "returns configured apikey" do
          expect(client.apikey).to eq("config-key")
        end
      end

      context "when apikey is not configured" do
        include_context "with valid API key"

        before { client.configure(apikey: nil) }

        it "returns apikey from environment" do
          expect(client.apikey).to eq(ENV[client.apikey_env_var_name])
        end
      end

      context "when apikey is empty string" do
        before { client.configure(apikey: "") }

        it "falls back to environment variable" do
          expect(client.apikey).to eq(ENV[client.apikey_env_var_name])
        end
      end
    end

    describe "#apikey=" do
      it "sets the apikey in configuration" do
        client.apikey = "setter-key"
        expect(client.configuration[:apikey]).to eq("setter-key")
        expect(client.apikey).to eq("setter-key")
      end
    end

    describe "#connect_timeout" do
      it "returns default timeout initially" do
        expect(client.connect_timeout).to eq(described_class::DEFAULT_CONNECT_TIMEOUT)
      end

      it "returns configured timeout" do
        client.configure(connect_timeout: 250)
        expect(client.connect_timeout).to eq(250)
      end
    end

    describe "#connect_timeout=" do
      it "sets timeout from integer" do
        client.connect_timeout = 400
        expect(client.connect_timeout).to eq(400)
      end

      it "sets timeout from string" do
        client.connect_timeout = "500"
        expect(client.connect_timeout).to eq(500)
      end

      it "uses default for invalid input" do
        client.connect_timeout = "invalid"
        expect(client.connect_timeout).to eq(described_class::DEFAULT_CONNECT_TIMEOUT)
      end
    end

    describe "#apikey_env_var_name" do
      it "returns default environment variable name" do
        expect(client.apikey_env_var_name).to eq(described_class::APIKEY_ENV_NAME)
      end

      it "returns configured environment variable name" do
        client.configure(apikey_env_var_name: "custom_api_key")
        expect(client.apikey_env_var_name).to eq("CUSTOM_API_KEY")
      end
    end

    describe "#apikey_env_var_name=" do
      it "sets and uppercases environment variable name" do
        client.apikey_env_var_name = "my_custom_key"
        expect(client.apikey_env_var_name).to eq("MY_CUSTOM_KEY")
        expect(client.configuration[:apikey_env_var_name]).to eq("MY_CUSTOM_KEY")
      end
    end

    describe "#fetch" do
      let(:request) { TwelvedataRuby::Request.new(:quote, symbol: "AAPL") }

      context "with nil request" do
        it "returns nil" do
          expect(client.fetch(nil)).to be_nil
        end
      end

      context "with valid request" do
        before { stub_successful_request(request) }

        it "makes HTTP request and returns Response" do
          response = client.fetch(request)

          expect(response).to be_a(TwelvedataRuby::Response)
        end

        it "includes request in response" do
          response = client.fetch(request)
          expect(response.request).to be(request)
        end
      end

      context "with invalid request" do
        let(:invalid_request) { TwelvedataRuby::Request.new(:quote) } # missing symbol

        it "returns hash with errors" do
          result = client.fetch(invalid_request)

          expect(result).to be_a(Hash)
          expect(result).to have_key(:errors)
        end
      end

      context "with network error" do
        let(:mocked_request) { mock_request(:quote, symbol: "AAPL") }
        before { stub_connection_error(mocked_request) }

        it "returns NetworkError" do
          result = client.fetch(mocked_request)

          expect(result).to be_a(TwelvedataRuby::NetworkError)
          expect(result.message).to include("Network error occurred")
        end
      end

      context "with timeout error" do
        let(:mocked_request) { mock_request(:quote, symbol: "AAPL") }
        before { stub_timeout_error(mocked_request) }

        it "returns NetworkError" do
          expect(client.fetch(mocked_request)).to be_a(TwelvedataRuby::NetworkError)
        end
      end

      context "with unexpected error" do
        before do
          allow(described_class).to receive(:request).and_raise(StandardError, "Unexpected error")
        end

        it "returns ResponseError" do
          result = client.fetch(request)

          expect(result).to be_a(TwelvedataRuby::ResponseError)
          expect(result.message).to include("Unexpected error")
        end
      end
    end

    describe "#method_missing" do
      context "with valid endpoint names" do
        include_context "with valid API key"

        it "defines and calls endpoint method for quote" do
          request = TwelvedataRuby::Request.new(:quote, symbol: "AAPL")
          stub_successful_request(request)

          expect(client.respond_to?(:quote)).to be(true)

          response = client.quote(symbol: "AAPL")

          expect(client).to respond_to(:quote)
          expect(response).to be_a(TwelvedataRuby::Response)
        end

        it "defines and calls endpoint method for price" do
          request = TwelvedataRuby::Request.new(:price, symbol: "GOOGL")
          stub_successful_request(request)

          response = client.price(symbol: "GOOGL")

          expect(client).to respond_to(:price)
          expect(response).to be_a(TwelvedataRuby::Response)
        end

        it "defines and calls endpoint method for api_usage" do
          request = TwelvedataRuby::Request.new(:api_usage)
          stub_successful_request(request)

          response = client.api_usage

          expect(client).to respond_to(:api_usage)
          expect(response).to be_a(TwelvedataRuby::Response)
        end

        it "does not redefine already defined methods" do
          request = TwelvedataRuby::Request.new(:quote, symbol: "AAPL")
          stub_successful_request(request)

          # First call defines the method
          client.quote(symbol: "AAPL")
          original_method = client.method(:quote)

          # Second call should use the same method
          client.quote(symbol: "AAPL")
          expect(client.method(:quote)).to eq(original_method)
        end
      end

      context "with invalid endpoint names" do
        it "raises NoMethodError for invalid endpoints" do
          expect { client.invalid_endpoint_name }.to raise_error(NoMethodError)
        end

        it "raises NoMethodError for undefined methods" do
          expect { client.some_random_method }.to raise_error(NoMethodError)
        end
      end

      context "with parameters" do
        include_context "with valid API key"

        it "passes parameters to the request" do
          request = TwelvedataRuby::Request.new(:quote, symbol: "MSFT", format: :csv)
          stub_successful_request(request)

          response = client.quote(symbol: "MSFT", format: :csv)

          expect(response).to be_a(TwelvedataRuby::Response)
        end

        it "handles invalid parameters" do
          response = client.quote(symbol: "AAPL", invalid_param: "value")

          expect(response).to be_a(Hash)
          expect(response).to have_key(:errors)
        end
      end
    end

    describe "#respond_to_missing?" do
      it "returns true for valid endpoint names" do
        expect(client).to respond_to(:quote)
        expect(client).to respond_to(:price)
        expect(client).to respond_to(:api_usage)
      end

      it "returns false for invalid endpoint names" do
        expect(client).not_to respond_to(:invalid_endpoint)
        expect(client).not_to respond_to(:nonexistent_method)
      end

      it "respects include_all parameter" do
        expect(client.respond_to?(:quote, true)).to be(true)
        expect(client.respond_to?(:invalid_endpoint, true)).to be(false)
      end
    end

    describe "endpoint method caching" do
      include_context "with valid API key"

      it "tracks defined endpoint methods" do
        request = TwelvedataRuby::Request.new(:quote, symbol: "AAPL")
        stub_successful_request(request)

        defined_methods = client.instance_variable_get(:@endpoint_methods_defined)
        expect(defined_methods).not_to include(:quote)

        client.quote(symbol: "AAPL")
        defined_methods = client.instance_variable_get(:@endpoint_methods_defined)
        expect(defined_methods).to include(:quote)
      end
    end
  end

  describe "integration scenarios" do
    include_context "with valid API key"
    subject(:client) { described_class.instance }

    describe "complete API workflow" do
      before do
        quote_request = TwelvedataRuby::Request.new(:quote, symbol: "AAPL")
        price_request = TwelvedataRuby::Request.new(:price, symbol: "AAPL")

        stub_successful_request(quote_request)
        stub_successful_request(price_request)
      end

      it "supports chained API calls" do
        quote_response = client.quote(symbol: "AAPL")
        price_response = client.price(symbol: "AAPL")

        expect(quote_response).to be_a(TwelvedataRuby::Response)
        expect(price_response).to be_a(TwelvedataRuby::Response)
        expect(quote_response).to be_success
        expect(price_response).to be_success
      end
    end

    describe "error handling scenarios" do
      it "handles API errors gracefully" do
        request = TwelvedataRuby::Request.new(:quote, symbol: "INVALID")
        stub_error_request(request, 404)

        response = client.quote(symbol: "INVALID")

        expect(response).to be_a(TwelvedataRuby::Response)
        expect(response.error).to be_a(TwelvedataRuby::ResponseError)
      end

      it "handles network errors gracefully" do
        request = TwelvedataRuby::Request.new(:quote, symbol: "AAPL")
        stub_connection_error(request)

        result = client.quote(symbol: "AAPL")

        expect(result).to be_a(TwelvedataRuby::NetworkError)
      end
    end

    describe "configuration persistence" do
      it "maintains configuration across method calls" do
        client.configure(apikey: "persistent-key", connect_timeout: 500)

        request = TwelvedataRuby::Request.new(:api_usage)
        stub_successful_request(request)

        client.api_usage

        expect(client.apikey).to eq("persistent-key")
        expect(client.connect_timeout).to eq(500)
      end
    end
  end

  describe "thread safety" do
    include_context "with valid API key"

    it "maintains singleton behavior across threads" do
      clients = []

      threads = 5.times.map do |i|
        Thread.new do
          clients << described_class.instance
          clients.last.configure(apikey: "thread-#{i}")
        end
      end

      threads.each(&:join)

      # All should be the same instance
      expect(clients.uniq.size).to eq(1)

      # Configuration should be from the last thread
      expect(clients.first.apikey).to match(/thread-\d/)
    end
  end
end
