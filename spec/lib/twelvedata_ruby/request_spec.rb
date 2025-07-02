# frozen_string_literal: true

RSpec.describe TwelvedataRuby::Request do
  describe "constants" do
    it "defines DEFAULT_HTTP_VERB" do
      expect(described_class::DEFAULT_HTTP_VERB).to eq(:get)
    end
  end

  describe "delegation" do
    subject(:request) { described_class.new(:quote, symbol: "AAPL") }

    it "delegates to endpoint" do
      expect(request).to respond_to(:name)
      expect(request).to respond_to(:valid?)
      expect(request).to respond_to(:query_params)
      expect(request).to respond_to(:errors)
    end

    it "delegates correctly" do
      expect(request.name).to eq(:quote)
      expect(request.query_params).to include(symbol: "AAPL")
      expect(request).to be_valid
    end
  end

  describe "#initialize" do
    context "with valid parameters" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL", format: :json) }

      it "creates endpoint with provided parameters" do
        expect(request.endpoint).to be_a(TwelvedataRuby::Endpoint)
        expect(request.name).to eq(:quote)
        expect(request.query_params[:symbol]).to eq("AAPL")
        expect(request.query_params[:format]).to eq(:json)
      end
    end

    context "with minimal parameters" do
      subject(:request) { described_class.new(:api_usage) }

      it "creates valid request" do
        expect(request.name).to eq(:api_usage)
        expect(request).to be_valid
      end
    end

    context "with invalid parameters" do
      subject(:request) { described_class.new(:quote) } # missing required symbol

      it "creates invalid request" do
        expect(request.name).to eq(:quote)
        expect(request).not_to be_valid
        expect(request.errors).not_to be_empty
      end
    end
  end

  describe "#fetch" do
    include_context "with valid API key"
    subject(:request) { described_class.new(:quote, symbol: "AAPL") }

    before { stub_successful_request(request) }

    it "delegates to client fetch" do
      response = request.fetch

      expect(response).to be_a(TwelvedataRuby::Response)
    end

    it "passes self to client" do
      expect(TwelvedataRuby::Client.instance).to receive(:fetch).with(request).and_call_original

      request.fetch
    end
  end

  describe "#http_verb" do
    context "with valid request" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL") }

      it "returns default HTTP verb" do
        expect(request.http_verb).to eq(:get)
      end
    end

    context "with POST endpoint" do
      subject(:request) do
        described_class.new(
          :complex_data,
          symbols: "AAPL,GOOGL",
          intervals: "1day",
          start_date: "2024-01-01",
          end_date: "2024-01-31"
        )
      end

      it "returns POST verb from endpoint definition" do
        expect(request.http_verb).to eq(:post)
      end
    end

    context "with invalid request" do
      subject(:request) { described_class.new(:invalid_endpoint) }

      it "returns nil" do
        expect(request.http_verb).to be_nil
      end
    end
  end

  describe "#params" do
    context "with valid request" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL", format: :csv) }

      it "returns params hash for HTTP client" do
        params = request.params

        expect(params).to have_key(:params)
        expect(params[:params]).to include(symbol: "AAPL", format: :csv)
      end
    end

    context "with invalid request" do
      subject(:request) { described_class.new(:invalid_endpoint) }

      it "returns nil" do
        expect(request.params).to be_nil
      end
    end
  end

  describe "#relative_url" do
    context "with valid request" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL") }

      it "returns endpoint name as string" do
        expect(request.relative_url).to eq("quote")
      end
    end

    context "with invalid request" do
      subject(:request) { described_class.new(:invalid_endpoint) }

      it "returns nil" do
        expect(request.relative_url).to be_nil
      end
    end
  end

  describe "#full_url" do
    context "with valid request" do
      subject(:request) { described_class.new(:price, symbol: "GOOGL") }

      it "returns complete URL" do
        expected_url = "#{TwelvedataRuby::Client::BASE_URL}/price"
        expect(request.full_url).to eq(expected_url)
      end
    end

    context "with invalid request" do
      subject(:request) { described_class.new(:invalid_endpoint) }

      it "returns nil" do
        expect(request.full_url).to be_nil
      end
    end
  end

  describe "#to_h" do
    context "with valid request" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL", format: :json) }

      it "returns hash representation" do
        hash = request.to_h

        expect(hash).to include(
          http_verb: :get,
          url: "#{TwelvedataRuby::Client::BASE_URL}/quote",
          params: hash_including(symbol: "AAPL", format: :json)
        )
      end
    end

    context "with invalid request" do
      subject(:request) { described_class.new(:invalid_endpoint) }

      it "returns nil" do
        expect(request.to_h).to be_nil
      end
    end
  end

  describe "#to_a" do
    context "with valid request" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL") }

      it "returns array format for HTTPX" do
        array = request.to_a

        expect(array).to be_an(Array)
        expect(array.size).to eq(3)
        expect(array[0]).to eq("GET")
        expect(array[1]).to eq("https://api.twelvedata.com/quote")
        expect(array[2]).to have_key(:params)
      end
    end

    context "with POST request" do
      subject(:request) do
        described_class.new(
          :complex_data,
          symbols: "AAPL",
          intervals: "1day",
          start_date: "2024-01-01",
          end_date: "2024-01-31"
        )
      end

      it "returns array with POST verb" do
        array = request.to_a

        expect(array[0]).to eq("POST")
        expect(array[1]).to eq("https://api.twelvedata.com/complex_data")
      end
    end

    context "with invalid request" do
      subject(:request) { described_class.new(:invalid_endpoint) }

      it "returns nil" do
        expect(request.to_a).to be_nil
      end
    end
  end

  describe "#build" do
    subject(:request) { described_class.new(:quote, symbol: "AAPL") }

    it "is an alias for to_a" do
      expect(request.method(:build)).to eq(request.method(:to_a))
    end
  end

  describe "#to_s" do
    context "with valid request" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL", format: :csv) }

      it "returns human-readable description" do
        description = request.to_s

        expect(description).to include("GET")
        expect(description).to include(request.full_url)
        expect(description).to include("symbol")
        expect(description).to include("AAPL")
      end
    end

    context "with invalid request" do
      subject(:request) { described_class.new(:invalid_endpoint) }

      it "returns invalid request description" do
        description = request.to_s

        expect(description).to include("Invalid request")
        expect(description).to include("invalid_endpoint")
      end
    end
  end

  describe "#inspect" do
    subject(:request) { described_class.new(:quote, symbol: "AAPL", format: :json) }

    it "returns detailed inspection string" do
      inspection = request.inspect

      expect(inspection).to include(described_class.name)
      expect(inspection).to include("endpoint=quote")
      expect(inspection).to include("valid=true")
      expect(inspection).to include("params=")
    end

    it "includes object_id" do
      expect(request.inspect).to include(request.object_id.to_s)
    end
  end

  describe "#==" do
    let(:request1) { described_class.new(:quote, symbol: "AAPL", format: :json) }
    let(:request2) { described_class.new(:quote, symbol: "AAPL", format: :json) }
    let(:request3) { described_class.new(:quote, symbol: "GOOGL", format: :json) }
    let(:request4) { described_class.new(:price, symbol: "AAPL") }

    it "returns true for requests with same endpoint and parameters" do
      expect(request1).to eq(request2)
    end

    it "returns false for requests with different parameters" do
      expect(request1).not_to eq(request3)
    end

    it "returns false for requests with different endpoints" do
      expect(request1).not_to eq(request4)
    end

    it "returns false when comparing with non-Request objects" do
      expect(request1).not_to eq("not a request")
      expect(request1).not_to eq(nil)
    end
  end

  describe "#eql?" do
    let(:request1) { described_class.new(:quote, symbol: "AAPL") }
    let(:request2) { described_class.new(:quote, symbol: "AAPL") }

    it "is an alias for ==" do
      expect(request1.method(:eql?)).to eq(request1.method(:==))
    end

    it "works correctly" do
      expect(request1.eql?(request2)).to be(true)
    end
  end

  describe "#hash" do
    let(:request1) { described_class.new(:quote, symbol: "AAPL", format: :json) }
    let(:request2) { described_class.new(:quote, symbol: "AAPL", format: :json) }
    let(:request3) { described_class.new(:quote, symbol: "GOOGL", format: :json) }

    it "returns same hash for equal requests" do
      expect(request1.hash).to eq(request2.hash)
    end

    it "returns different hash for different requests" do
      expect(request1.hash).not_to eq(request3.hash)
    end

    it "allows requests to be used as hash keys" do
      hash = { request1 => "first", request3 => "second" }

      expect(hash[request2]).to eq("first") # request2 == request1
      expect(hash[request3]).to eq("second")
    end
  end

  describe "validation scenarios" do
    context "with all required parameters" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL") }

      it_behaves_like "a valid request"
    end

    context "with missing required parameters" do
      subject(:request) { described_class.new(:quote) }

      it_behaves_like "an invalid request with missing parameters"
    end

    context "with invalid parameters" do
      subject(:request) { described_class.new(:quote, symbol: "AAPL", invalid_param: "value") }

      it_behaves_like "an invalid request with invalid parameters"
    end

    context "with invalid endpoint" do
      subject(:request) { described_class.new(:nonexistent_endpoint) }

      it_behaves_like "an invalid request with invalid endpoint"
    end
  end

  describe "complex endpoint scenarios" do
    context "with time_series endpoint" do
      subject(:request) do
        described_class.new(
          :time_series,
          symbol: "AAPL",
          interval: "1day",
          format: :csv,
          filename: "apple_data.csv"
        )
      end

      it "handles complex parameters correctly" do
        expect(request).to be_valid
        expect(request.query_params[:filename]).to eq("apple_data.csv")
        expect(request.query_params[:format]).to eq(:csv)
      end
    end

    context "with currency_conversion endpoint" do
      subject(:request) do
        described_class.new(
          :currency_conversion,
          symbol: "USD/EUR",
          amount: 100
        )
      end

      it "handles multiple required parameters" do
        expect(request).to be_valid
        expect(request.query_params[:symbol]).to eq("USD/EUR")
        expect(request.query_params[:amount]).to eq(100)
      end
    end
  end

  describe "integration with endpoint" do
    subject(:request) { described_class.new(:quote, symbol: "AAPL") }

    it "creates proper endpoint instance" do
      expect(request.endpoint).to be_a(TwelvedataRuby::Endpoint)
      expect(request.endpoint.name).to eq(:quote)
    end

    it "endpoint reflects request state" do
      expect(request.endpoint.valid?).to eq(request.valid?)
      expect(request.endpoint.query_params).to eq(request.query_params)
    end
  end
end
