# frozen_string_literal: true

RSpec.describe TwelvedataRuby::Response do
  describe "constants" do
    it "defines expected constants" do
      expect(described_class::CSV_COL_SEP).to eq(";")
      expect(described_class::BODY_MAX_BYTESIZE).to eq(16_000)
    end

    it "defines HTTP status ranges" do
      expect(described_class::HTTP_STATUSES[:success]).to eq(200..299)
      expect(described_class::HTTP_STATUSES[:http_error]).to eq(400..600)
    end

    it "defines content type handlers" do
      handlers = described_class::CONTENT_TYPE_HANDLERS

      expect(handlers).to have_key(:json)
      expect(handlers).to have_key(:csv)
      expect(handlers).to have_key(:plain)

      handlers.each_value do |handler|
        expect(handler).to have_key(:parser)
        expect(handler).to have_key(:dumper)
      end
    end
  end

  describe "class methods" do
    let(:request) { TwelvedataRuby::Request.new(:quote, symbol: "AAPL") }

    describe ".resolve" do
      context "with successful HTTP response" do
        let(:http_response) do
          double("HTTPResponse",
            status: 200,
            headers: { "content-type" => "application/json" },
            body: double("Body", bytesize: 100, to_s: '{"symbol":"AAPL"}', close: nil)
          )
        end

        it "returns Response instance" do
          response = described_class.resolve(http_response, request)
          expect(response).to be_a(described_class)
        end

        it "includes request and http_response" do
          response = described_class.resolve(http_response, request)
          expect(response.request).to be(request)
          expect(response.http_response).to be(http_response)
        end
      end

      context "with HTTP error status" do
        let(:http_response) do
          double("HTTPResponse",
            status: 404,
            headers: { "content-type" => "text/plain" },
            body: double("Body", to_s: "Not Found"),
            error: nil
          )
        end

        it "returns ResponseError" do
          result = described_class.resolve(http_response, request)
          expect(result).to be_a(TwelvedataRuby::ResponseError)
        end

        it "includes request and status information" do
          result = described_class.resolve(http_response, request)
          expect(result.request).to be(request)
          expect(result.status_code).to eq(404)
        end
      end

      context "with HTTP response containing error object" do
        let(:error_object) { double("Error", message: "Connection failed", class: StandardError) }
        let(:http_response) do
          double("HTTPResponse",
            status: 500,
            error: error_object,
            body: double("Body", to_s: "Server Error")
          )
        end

        it "extracts error information" do
          result = described_class.resolve(http_response, request)
          expect(result).to be_a(TwelvedataRuby::ResponseError)
          expect(result.json_data[:message]).to eq("Connection failed")
        end
      end

      context "with resolution error" do
        let(:http_response) do
          double("HTTPResponse", status: 200)
        end

        before do
          allow(described_class).to receive(:new).and_raise(StandardError, "Parse error")
        end

        it "returns ResponseError with parse error information" do
          result = described_class.resolve(http_response, request)
          expect(result).to be_a(TwelvedataRuby::ResponseError)
          expect(result.message).to include("Failed to resolve response")
        end
      end
    end

    describe ".valid_status_codes" do
      it "returns array of all valid status codes" do
        codes = described_class.valid_status_codes

        expect(codes).to be_an(Array)
        expect(codes).to include(200, 201, 404, 500)
        expect(codes.size).to be > 300 # Should include all codes in ranges
      end

      it "caches the result" do
        first_call = described_class.valid_status_codes
        second_call = described_class.valid_status_codes

        expect(first_call).to be(second_call)
      end
    end
  end

  describe "instance methods" do
    let(:request) { TwelvedataRuby::Request.new(:quote, symbol: "AAPL") }
    let(:headers) { { "content-type" => "application/json; charset=utf-8" } }
    let(:body_content) { '{"symbol":"AAPL","price":"150.00"}' }
    let(:http_response) do
      double("HTTPResponse",
        status: 200,
        headers: headers,
        body: double("Body",
          bytesize: body_content.bytesize,
          to_s: body_content,
          close: nil,
          closed?: false
        )
      )
    end

    subject(:response) { described_class.new(http_response: http_response, request: request) }

    describe "#initialize" do
      it "initializes with http_response and request" do
        expect(response.http_response).to be(http_response)
        expect(response.request).to be(request)
        expect(response.headers).to eq(headers)
        expect(response.body_bytesize).to eq(body_content.bytesize)
      end
    end

    describe "#content_type" do
      context "with JSON content type" do
        it "detects JSON content type" do
          expect(response.content_type).to eq(:json)
        end
      end

      context "with CSV content type" do
        let(:headers) { { "content-type" => "text/csv; charset=utf-8" } }

        it "detects CSV content type" do
          expect(response.content_type).to eq(:csv)
        end
      end

      context "with plain text content type" do
        let(:headers) { { "content-type" => "text/plain" } }

        it "detects plain content type" do
          expect(response.content_type).to eq(:plain)
        end
      end

      context "with unknown content type" do
        let(:headers) { { "content-type" => "application/xml" } }

        it "defaults to plain content type" do
          expect(response.content_type).to eq(:plain)
        end
      end

      context "without content type header" do
        let(:headers) { {} }

        it "defaults to plain content type" do
          expect(response.content_type).to eq(:plain)
        end
      end
    end

    describe "#parsed_body" do
      context "with JSON response" do
        it "parses JSON content" do
          parsed = response.parsed_body

          expect(parsed).to be_a(Hash)
          expect(parsed[:symbol]).to eq("AAPL")
          expect(parsed[:price]).to eq("150.00")
        end

        it "caches parsed result" do
          first_call = response.parsed_body
          second_call = response.parsed_body

          expect(first_call).to be(second_call)
        end
      end

      context "with CSV response" do
        let(:headers) { { "content-type" => "text/csv" } }
        let(:body_content) { "symbol;price\nAAPL;150.00\nGOOGL;2500.00" }

        it "parses CSV content" do
          parsed = response.parsed_body

          expect(parsed).to be_a(CSV::Table)
          expect(parsed.length).to eq(2)
          expect(parsed[0]["symbol"]).to eq("AAPL")
        end
      end

      context "with plain text response" do
        let(:headers) { { "content-type" => "text/plain" } }
        let(:body_content) { "Plain text response" }

        it "returns content as string" do
          parsed = response.parsed_body

          expect(parsed).to eq("Plain text response")
        end
      end

      context "with large response body" do
        let(:large_content) { '{"content": "' + 'x' * (described_class::BODY_MAX_BYTESIZE + 1000) + '"}' }
        let(:body_content) { large_content }
        let(:http_response) do
          double("HTTPResponse",
            status: 200,
            headers: headers,
            body: double("Body",
              bytesize: large_content.bytesize,
              close: nil,
              closed?: false,
              copy_to: ->(file) { file.write(large_content) }
            )
          )
        end

        it "handles large responses using temporary file" do
          allow(Tempfile).to receive(:create).and_yield(StringIO.new(large_content))

          parsed = response.parsed_body
          expect(parsed).to be_a(Hash) # Should parse the oversized content as JSON
        end
      end

      context "with malformed JSON" do
        let(:body_content) { '{"invalid": json}' }

        it "raises ResponseError" do
          expect { response.parsed_body }.to raise_error(TwelvedataRuby::ResponseError, /Failed to parse JSON/)
        end
      end

      context "with malformed CSV" do
        let(:headers) { { "content-type" => "text/csv" } }
        let(:body_content) { "unclosed\"quote,field" }

        it "raises ResponseError" do
          expect { response.parsed_body }.to raise_error(TwelvedataRuby::ResponseError, /Failed to parse CSV/)
        end
      end
    end

    describe "#attachment_filename" do
      context "without Content-Disposition header" do
        it "returns nil" do
          expect(response.attachment_filename).to be_nil
        end
      end

      context "with Content-Disposition header" do
        let(:headers) do
          {
            "content-type" => "text/csv",
            "content-disposition" => 'attachment; filename="data.csv"'
          }
        end

        it "extracts filename" do
          expect(response.attachment_filename).to eq("data.csv")
        end

        it "caches extracted filename" do
          first_call = response.attachment_filename
          second_call = response.attachment_filename

          expect(first_call).to be(second_call)
        end
      end

      context "with malformed Content-Disposition header" do
        let(:headers) do
          {
            "content-type" => "text/csv",
            "content-disposition" => 'attachment; filename=data.csv' # No quotes
          }
        end

        it "returns nil for malformed header" do
          expect(response.attachment_filename).to be_nil
        end
      end
    end

    describe "#error" do
      context "with successful response" do
        it "returns nil" do
          expect(response.error).to be_nil
        end
      end

      context "with API error in response body" do
        let(:body_content) { '{"code":401,"message":"Unauthorized access"}' }

        it "creates appropriate error object" do
          error = response.error

          expect(error).to be_a(TwelvedataRuby::UnauthorizedResponseError)
          expect(error.status_code).to eq(401)
          expect(error.message).to eq("Unauthorized access")
        end

        it "caches error object" do
          first_call = response.error
          second_call = response.error

          expect(first_call).to be(second_call)
        end
      end

      context "with unknown error code" do
        let(:body_content) { '{"code":999,"message":"Unknown error"}' }

        it "creates generic ResponseError" do
          error = response.error

          expect(error).to be_a(TwelvedataRuby::ResponseError)
          expect(error.status_code).to eq(999)
        end
      end
    end

    describe "#status_code" do
      context "with API error code in body" do
        let(:body_content) { '{"code":404,"message":"Not found"}' }

        it "returns API status code from body" do
          expect(response.status_code).to eq(404)
        end
      end

      context "without API error code" do
        it "returns HTTP status code" do
          expect(response.status_code).to eq(200)
        end
      end
    end

    describe "#http_status_code" do
      it "returns HTTP response status" do
        expect(response.http_status_code).to eq(200)
      end
    end

    describe "#success?" do
      context "with successful HTTP status" do
        it "returns true" do
          expect(response).to be_success
        end
      end

      context "with error HTTP status" do
        let(:http_response) do
          double("HTTPResponse",
            status: 404,
            headers: headers,
            body: double("Body", bytesize: 10, to_s: "Not Found", close: nil, closed?: false)
          )
        end

        it "returns false" do
          expect(response).not_to be_success
        end
      end
    end

    describe "#dump_parsed_body" do
      context "with JSON response" do
        it "dumps parsed body back to JSON" do
          dumped = response.dump_parsed_body

          expect(dumped).to be_a(String)
          parsed_dumped = JSON.parse(dumped, symbolize_names: true)
          expect(parsed_dumped).to eq(response.parsed_body)
        end
      end

      context "with CSV response" do
        let(:headers) { { "content-type" => "text/csv" } }
        let(:body_content) { "symbol;price\nAAPL;150.00" }

        it "dumps parsed body back to CSV" do
          dumped = response.dump_parsed_body

          expect(dumped).to be_a(String)
          expect(dumped).to include(described_class::CSV_COL_SEP)
        end
      end

      context "with plain text response" do
        let(:headers) { { "content-type" => "text/plain" } }
        let(:body_content) { "Plain text content" }

        it "returns content as string" do
          dumped = response.dump_parsed_body
          expect(dumped).to eq("Response: 200 (success), Content-Type: plain, Size: 18 bytes")
        end
      end
    end

    describe "#save_to_file" do
      let(:temp_file) { Tempfile.new("data.csv") }
      let(:file_path) { temp_file.path }

      after { temp_file&.unlink }

      context "with valid file path" do
        it "saves response to file" do
          response.save_to_file(file_path)

          content = File.read(file_path)
          expect(content).to include("AAPL")
        end

        it "returns the file size" do
          result = response.save_to_file(file_path)
          expect(result).to be_a(Integer)
        end
      end

      context "with attachment filename" do
        let(:headers) do
          {
            "content-type" => "text/csv",
            "content-disposition" => 'attachment; filename="data.csv"'
          }
        end

        it "uses attachment filename when no path provided" do
          headers["content-type"] = "text/plain"
          # Mock File.open to avoid actual file creation
          expect(File).to receive(:open).with("data.csv", "w").and_yield(temp_file)



          response.save_to_file
        end
      end

      context "without file path or attachment filename" do
        it "returns nil" do
          expect(response.save_to_file).to be_nil
        end
      end

      context "with file write error" do
        let(:temp_file) { nil }
        it "raises ResponseError" do
          allow(File).to receive(:open).and_raise(StandardError, "Write failed")

          expect { response.save_to_file("data.csv") }
            .to raise_error(TwelvedataRuby::ResponseError, /Failed to save response to file/)
        end
      end
    end

    describe "#to_s" do
      it "returns human-readable response summary" do
        summary = response.to_s

        expect(summary).to include("Response:")
        expect(summary).to include("200")
        expect(summary).to include("success")
        expect(summary).to include("Content-Type: json")
        expect(summary).to include("Size:")
      end

      context "with error response" do
        let(:http_response) do
          double("HTTPResponse",
            status: 404,
            headers: headers,
            body: double("Body", bytesize: 10, to_s: "Not Found", close: nil, closed?: false)
          )
        end

        it "shows error status" do
          summary = response.to_s
          expect(summary).to include("404")
          expect(summary).to include("error")
        end
      end
    end

    describe "#inspect" do
      it "returns detailed response information" do
        inspection = response.inspect

        expect(inspection).to include(described_class.name)
        expect(inspection).to include("status=200")
        expect(inspection).to include("content_type=json")
        expect(inspection).to include("error=no")
        expect(inspection).to include(response.object_id.to_s)
      end

      context "with error response" do
        let(:body_content) { '{"code":401,"message":"Unauthorized"}' }

        it "shows error presence" do
          inspection = response.inspect
          expect(inspection).to include("error=yes")
        end
      end
    end
  end

  describe "integration scenarios" do
    include_context "with valid API key"
    let(:request) { TwelvedataRuby::Request.new(:quote, symbol: "AAPL") }

    before { stub_successful_request(request) }

    it "works end-to-end with successful API call" do
      http_response = TwelvedataRuby::Client.request(request)
      response = described_class.resolve(http_response, request)

      expect(response).to be_a(described_class)
      expect(response).to be_success
      expect(response.parsed_body).to be_a(Hash)
    end

    it "handles CSV responses correctly" do
      csv_request = TwelvedataRuby::Request.new(:quote, symbol: "AAPL", format: :csv)
      stub_successful_request(csv_request)

      http_response = TwelvedataRuby::Client.request(csv_request)
      response = described_class.resolve(http_response, request)

      expect(response.content_type).to eq(:csv)
    end
  end

  describe "error handling scenarios" do
    let(:request) { TwelvedataRuby::Request.new(:quote, symbol: "INVALID") }

    context "with API error response" do
      before { stub_error_request(request, 404) }

      it "creates response with error" do
        http_response = TwelvedataRuby::Client.request(request)
        response = described_class.resolve(http_response, request)

        expect(response).to be_a(described_class)
        expect(response.error).to be_a(TwelvedataRuby::ResponseError)
      end
    end

    context "with HTTP error status" do
      before { stub_http_error(request, 500) }

      it "creates ResponseError directly" do
        http_response = TwelvedataRuby::Client.request(request)
        result = described_class.resolve(http_response, request)

        expect(result).to be_a(TwelvedataRuby::ResponseError)
        expect(result.status_code).to eq(500)
      end
    end
  end
end
