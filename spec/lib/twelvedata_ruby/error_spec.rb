# frozen_string_literal: true

RSpec.describe TwelvedataRuby::Error do
  describe "inheritance hierarchy" do
    it "inherits from StandardError" do
      expect(described_class).to be < StandardError
    end

    it "has correct subclass relationships" do
      expect(TwelvedataRuby::ConfigurationError).to be < described_class
      expect(TwelvedataRuby::NetworkError).to be < described_class
      expect(TwelvedataRuby::EndpointError).to be < described_class
      expect(TwelvedataRuby::ResponseError).to be < described_class
    end
  end

  describe "#initialize" do
    context "with default message" do
      subject(:error) { described_class.new }

      it "creates error with default message" do
        expect(error.message).to eq("An error occurred")
      end

      it "has empty attributes" do
        expect(error.attributes).to eq({})
      end

      it "has no original error" do
        expect(error.original_error).to be_nil
      end
    end

    context "with custom message" do
      subject(:error) { described_class.new(message: "Custom error occurred") }

      it "uses provided message" do
        expect(error.message).to eq("Custom error occurred")
      end
    end

    context "with attributes" do
      subject(:error) do
        described_class.new(attributes: { name: "test", value: 123 })
      end

      it "stores attributes" do
        expect(error.attributes).to eq({ name: "test", value: 123 })
      end
    end

    context "with original error" do
      let(:original) { StandardError.new("Original error") }
      subject(:error) { described_class.new(original_error: original) }

      it "stores original error" do
        expect(error.original_error).to be(original)
      end
    end
  end

  describe "DEFAULT_MESSAGES" do
    it "contains messages for all error types" do
      expected_keys = %w[
        EndpointError EndpointNameError EndpointParametersKeysError
        EndpointRequiredParametersError ResponseError ConfigurationError NetworkError
      ]

      expect(described_class::DEFAULT_MESSAGES.keys).to include(*expected_keys)
    end

    it "has properly formatted message templates" do
      described_class::DEFAULT_MESSAGES.each_value do |template|
        expect(template).to be_a(String)
        expect(template).not_to be_empty
      end
    end
  end

  describe "message formatting" do
    let(:error_class) do
      Class.new(described_class) do
        def self.name
          "TwelvedataRuby::TestError"
        end
      end
    end

    before do
      stub_const("TwelvedataRuby::Error::DEFAULT_MESSAGES", {
        "TestError" => "Test error with %{name} and %{value}",
      })
    end

    it "formats message with attributes" do
      error = error_class.new(attributes: { name: "test", value: 42 })
      expect(error.message).to eq("Test error with test and 42")
    end

    it "handles missing template gracefully" do
      undefined_error_class = Class.new(described_class) do
        def self.name
          "TwelvedataRuby::UndefinedError"
        end
      end

      error = undefined_error_class.new
      expect(error.message).to eq("An error occurred")
    end

    it "handles missing keys in template" do
      error = error_class.new(attributes: { name: "test" })
      expect(error.message).to start_with("Error message template missing key:")
    end
  end
end

RSpec.describe TwelvedataRuby::ConfigurationError do
  it "inherits from base Error class" do
    expect(described_class).to be < TwelvedataRuby::Error
  end

  it "can be created with configuration-specific messages" do
    error = described_class.new(
      message: "Invalid API key configuration",
      attributes: { key: "invalid_key" },
    )

    expect(error.message).to eq("Invalid API key configuration")
    expect(error.attributes[:key]).to eq("invalid_key")
  end
end

RSpec.describe TwelvedataRuby::NetworkError do
  it "inherits from base Error class" do
    expect(described_class).to be < TwelvedataRuby::Error
  end

  it "can store original network exceptions" do
    original_error = HTTPX::ConnectionError.new("Connection failed")
    error = described_class.new(
      message: "Network request failed",
      original_error: original_error,
    )

    expect(error.original_error).to be(original_error)
    expect(error.message).to eq("Network request failed")
  end
end

RSpec.describe TwelvedataRuby::EndpointError do
  let(:endpoint) do
    double("Endpoint",
           name: :test_endpoint,
           class: double("EndpointClass", names: [:valid1, :valid2]),
           parameters_keys: [:param1, :param2],
           required_parameters: [:param1],
    )
  end

  describe "#initialize" do
    subject(:error) do
      described_class.new(endpoint: endpoint, invalid: "invalid_value")
    end

    it "formats attributes from endpoint information" do
      expect(error.attributes).to include(
        name: :test_endpoint,
        invalid: "invalid_value",
        valid_names: "valid1, valid2",
        parameters: "param1, param2",
        required: "param1",
      )
    end

    it "uses formatted default message" do
      expect(error.message).to include("invalid_value")
      expect(error.message).to include("not valid")
    end
  end

  context "with nil endpoint attributes" do
    let(:endpoint) do
      double("Endpoint",
             name: :test_endpoint,
             class: double("EndpointClass", names: []),
             parameters_keys: nil,
             required_parameters: nil,
      )
    end

    it "handles nil values gracefully" do
      error = described_class.new(endpoint: endpoint, invalid: "test")
      expect(error.attributes[:parameters]).to eq(nil)
      expect(error.attributes[:required]).to eq(nil)
    end
  end
end

RSpec.describe TwelvedataRuby::EndpointNameError do
  it "inherits from EndpointError" do
    expect(described_class).to be < TwelvedataRuby::EndpointError
  end
end

RSpec.describe TwelvedataRuby::EndpointParametersKeysError do
  it "inherits from EndpointError" do
    expect(described_class).to be < TwelvedataRuby::EndpointError
  end
end

RSpec.describe TwelvedataRuby::EndpointRequiredParametersError do
  it "inherits from EndpointError" do
    expect(described_class).to be < TwelvedataRuby::EndpointError
  end
end

RSpec.describe TwelvedataRuby::ResponseError do
  describe "error code mappings" do
    it "has correct API error code mappings" do
      expect(described_class::API_ERROR_CODES).to include(
        400 => "BadRequestResponseError",
        401 => "UnauthorizedResponseError",
        403 => "ForbiddenResponseError",
        404 => "NotFoundResponseError",
        429 => "TooManyRequestsResponseError",
        500 => "InternalServerResponseError",
      )
    end

    it "has correct HTTP error code mappings" do
      expect(described_class::HTTP_ERROR_CODES).to include(
        404 => "PageNotFoundResponseError",
      )
    end
  end

  describe ".error_class_for_code" do
    it "returns API error class for known codes" do
      expect(described_class.error_class_for_code(401, :api)).to eq("UnauthorizedResponseError")
      expect(described_class.error_class_for_code(404, :api)).to eq("NotFoundResponseError")
    end

    it "returns HTTP error class for known codes" do
      expect(described_class.error_class_for_code(404, :http)).to eq("PageNotFoundResponseError")
    end

    it "returns nil for unknown codes" do
      expect(described_class.error_class_for_code(999, :api)).to be_nil
      expect(described_class.error_class_for_code(999, :http)).to be_nil
    end

    it "defaults to API error type" do
      expect(described_class.error_class_for_code(401)).to eq("UnauthorizedResponseError")
    end
  end

  describe "#initialize" do
    let(:request) { double("Request") }

    context "with minimal parameters" do
      subject(:error) { described_class.new }

      it "creates error with defaults" do
        expect(error.json_data).to eq({})
        expect(error.status_code).to be_nil
        expect(error.request).to be_nil
        expect(error.message).to eq("Response error occurred")
      end
    end

    context "with full parameters" do
      let(:json_data) { { code: 401, message: "Unauthorized access" } }

      subject(:error) do
        described_class.new(
          json_data: json_data,
          request: request,
          status_code: 401,
          message: "Custom error message",
        )
      end

      it "stores all provided data" do
        expect(error.json_data).to eq(json_data)
        expect(error.status_code).to eq(401)
        expect(error.request).to be(request)
        expect(error.message).to eq("Custom error message")
      end
    end

    context "with status code in json_data" do
      let(:json_data) { { code: 403, message: "Forbidden" } }

      subject(:error) { described_class.new(json_data: json_data) }

      it "extracts status code from json_data" do
        expect(error.status_code).to eq(403)
      end

      it "uses message from json_data" do
        expect(error.message).to eq("Forbidden")
      end
    end

    context "with non-hash json_data" do
      subject(:error) { described_class.new(json_data: "invalid json") }

      it "converts to empty hash" do
        expect(error.json_data).to eq({})
      end
    end
  end
end

# Test specific response error classes
[
  TwelvedataRuby::BadRequestResponseError,
  TwelvedataRuby::UnauthorizedResponseError,
  TwelvedataRuby::ForbiddenResponseError,
  TwelvedataRuby::NotFoundResponseError,
  TwelvedataRuby::ParameterTooLongResponseError,
  TwelvedataRuby::TooManyRequestsResponseError,
  TwelvedataRuby::InternalServerResponseError,
  TwelvedataRuby::PageNotFoundResponseError,
].each do |error_class|
  RSpec.describe error_class do
    it "inherits from ResponseError" do
      expect(error_class).to be < TwelvedataRuby::ResponseError
    end

    it "can be instantiated with response data" do
      error = error_class.new(
        json_data: { code: 400, message: "Test error" },
        status_code: 400,
      )

      expect(error).to be_a(error_class)
      expect(error.status_code).to eq(400)
    end
  end
end
