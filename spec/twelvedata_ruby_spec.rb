# frozen_string_literal: true

RSpec.describe TwelvedataRuby do
  describe "VERSION" do
    it "has a version number" do
      expect(TwelvedataRuby::VERSION).to be_a(String)
      expect(TwelvedataRuby::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "matches the expected version" do
      expect(TwelvedataRuby::VERSION).to eq("0.4.0")
    end
  end

  describe ".version" do
    it "returns the current version" do
      expect(described_class.version).to eq(TwelvedataRuby::VERSION)
    end
  end

  describe ".client" do
    subject(:client_method) { described_class.client(**options) }
    let(:options) { {} }

    it "returns a Client instance" do
      expect(client_method).to be_a(TwelvedataRuby::Client)
    end

    it "returns the singleton instance" do
      expect(client_method).to be(TwelvedataRuby::Client.instance)
    end

    context "with no options" do
      it "returns client with default configuration" do
        expect(client_method.connect_timeout).to eq(TwelvedataRuby::Client::DEFAULT_CONNECT_TIMEOUT)
        expect(client_method.apikey_env_var_name).to eq(TwelvedataRuby::Client::APIKEY_ENV_NAME)
      end
    end

    context "with configuration options" do
      let(:options) do
        {
          apikey: "custom-api-key",
          connect_timeout: 5000,
          apikey_env_var_name: "CUSTOM_API_KEY",
        }
      end

      it "configures the client with provided options" do
        expect(client_method.apikey).to eq("custom-api-key")
        expect(client_method.connect_timeout).to eq(5000)
        expect(client_method.apikey_env_var_name).to eq("CUSTOM_API_KEY")
      end

      it "maintains singleton behavior" do
        first_call = described_class.client(**options)
        second_call = described_class.client

        expect(first_call).to be(second_call)
        expect(second_call.apikey).to eq("custom-api-key")
      end
    end

    context "with partial options" do
      let(:options) { { connect_timeout: 3000 } }

      it "only updates specified options" do
        original_apikey = TwelvedataRuby::Client.instance.apikey

        expect(client_method.connect_timeout).to eq(3000)
        expect(client_method.apikey).to eq(original_apikey)
      end
    end

    context "chaining with API calls" do
      include_context "with valid API key"
      let(:options) { { apikey: "test-key" } }

      before do
        request = TwelvedataRuby::Request.new(:quote, symbol: "AAPL")
        stub_successful_request(request)
      end

      it "allows method chaining" do
        expect do
          stub_request(:get, /#{TwelvedataRuby::Client::BASE_URL}\/quote/)
            .with(query: { symbol: "AAPL", apikey: "test-key", format: "json" })

          response = described_class.client(**options).quote(symbol: "AAPL")
          expect(response).to be_a(TwelvedataRuby::Response)
        end.not_to raise_error
      end
    end

    context "thread safety" do
      let(:options) { { apikey: "thread-test-key" } }

      it "maintains singleton behavior across threads" do
        clients = []
        threads = 10.times.map do |i|
          Thread.new do
            sleep(0.01 * i) # Stagger threads slightly
            clients << described_class.client(apikey: "thread-#{i}")
          end
        end

        threads.each(&:join)

        # All clients should be the same instance
        expect(clients.uniq.size).to eq(1)

        # The last configured API key should be set
        expect(clients.first.apikey).to start_with("thread-")
      end
    end


  end

  describe "module structure" do
    # rubocop:disable RSpec/MultipleExpectations
    it "has all expected classes" do
      expect(defined?(TwelvedataRuby::Client)).to be_truthy
      expect(defined?(TwelvedataRuby::Request)).to be_truthy
      expect(defined?(TwelvedataRuby::Response)).to be_truthy
      expect(defined?(TwelvedataRuby::Endpoint)).to be_truthy
      expect(defined?(TwelvedataRuby::Error)).to be_truthy
      expect(defined?(TwelvedataRuby::Utils)).to be_truthy
    end# rubocop:enable RSpec/MultipleExpectations

    it "has all expected error classes" do
      expect(defined?(TwelvedataRuby::EndpointError)).to be_truthy
      expect(defined?(TwelvedataRuby::ResponseError)).to be_truthy
      expect(defined?(TwelvedataRuby::ConfigurationError)).to be_truthy
      expect(defined?(TwelvedataRuby::NetworkError)).to be_truthy
    end
  end

  describe "integration" do
    include_context "with valid API key"

    before do
      request = TwelvedataRuby::Request.new(:api_usage)
      stub_successful_request(request)
    end

    it "provides a working end-to-end API" do
      client = described_class.client
      response = client.api_usage

      expect(response).to be_a(TwelvedataRuby::Response)
      expect(response).to be_success
      expect(response.parsed_body).to be_a(Hash)
    end
  end
end
