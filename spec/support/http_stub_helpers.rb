# frozen_string_literal: true

require "ostruct"

# Helper module for stubbing HTTP requests in tests
module HttpStubHelpers
  # MIME type mappings for different response formats
  MIME_TYPES = {
    json: "application/json; charset=utf-8",
    csv: "text/csv; charset=utf-8",
    plain: "text/plain; charset=utf-8",
  }.freeze

  # Stub a successful API request
  #
  # @param request [TwelvedataRuby::Request] Request object to stub
  # @param options [Hash] Stubbing options
  # @option options [Integer] :status HTTP status code (default: 200)
  # @option options [Symbol] :format Response format (default: from request)
  # @option options [String] :fixture_name Custom fixture name
  # @option options [String] :body Custom response body
  # @return [WebMock::RequestStub] WebMock stub
  def stub_successful_request(request, **options)
    stub_request_with_response(request, status: 200, **options)
  end

  # Stub an API request with error response
  #
  # @param request [TwelvedataRuby::Request] Request object to stub
  # @param error_code [Integer] Error code to simulate
  # @param options [Hash] Additional stubbing options
  # @return [WebMock::RequestStub] WebMock stub
  def stub_error_request(request, error_code, **options)
    fixture_name = error_fixture_name(error_code)
    stub_request_with_response(
      request,
      status: 200, # API returns 200 with error in body
      fixture_name: fixture_name,
      **options,
    )
  end

  # Stub an HTTP error (non-200 status)
  #
  # @param request [TwelvedataRuby::Request] Request object to stub
  # @param status_code [Integer] HTTP status code
  # @param options [Hash] Additional stubbing options
  # @return [WebMock::RequestStub] WebMock stub
  def stub_http_error(request, status_code, **options)
    stub_request_with_response(
      request,
      status: status_code,
      format: :plain,
      body: "HTTP #{status_code} Error",
      **options,
    )
  end

  # Stub a network timeout error
  #
  # @param request [TwelvedataRuby::Request] Request object to stub
  # @return [WebMock::RequestStub] WebMock stub
  def stub_timeout_error(request)
    stub_failure(request).to_timeout
  end

  # Stub a network connection error
  #
  # @param request [TwelvedataRuby::Request] Request object to stub
  # @return [WebMock::RequestStub] WebMock stub
  def stub_connection_error(request)
    stub_failure(request).to_raise(HTTPX::ConnectionError.new("Connection failed"))
  end

  # Create a mock request object for testing
  #
  # @param endpoint_name [Symbol] Endpoint name
  # @param params [Hash] Request parameters
  # @return [OpenStruct] Mock request object
  def mock_request(endpoint_name, **params)
    OpenStruct.new(
      name: endpoint_name,
      http_verb: :get,
      full_url: "#{TwelvedataRuby::Client::BASE_URL}/#{endpoint_name}",
      relative_url: endpoint_name.to_s,
      query_params: { apikey: "test-key" }.merge(params),
      params: { params: { apikey: "test-key" }.merge(params) },
      valid?: true,
      build: [:get, endpoint_name.to_s, { params: { apikey: "test-key" }.merge(params) }],
    )
  end

  # Stub multiple requests at once
  #
  # @param requests [Array<TwelvedataRuby::Request>] Array of requests to stub
  # @param options [Hash] Options to apply to all stubs
  def stub_multiple_requests(requests, **options)
    requests.map { |request| stub_successful_request(request, **options) }
  end

  # Create a WebMock stub that matches any request to the API
  #
  # @param options [Hash] Response options
  # @return [WebMock::RequestStub] WebMock stub
  def stub_any_api_request(**options)
    stub_request(:any, /#{Regexp.escape(TwelvedataRuby::Client::BASE_URL)}/)
      .to_return(default_response_options.merge(options))
  end

  private

  def stub_failure(request)
    stub_request(request.http_verb, request.full_url)
      .with(query: request.query_params, headers: { "User-Agent" => "httpx.rb/#{HTTPX::VERSION}", "Accept" => "*/*", 
"Accept-Encoding" => "gzip, deflate" })
  end

  def stub_request_with_response(request, **options)
    response_options = build_response_options(request, **options)
    stub_request(request.http_verb, request.full_url)
      .with(query: request.query_params)
      .to_return(response_options)
  end

  def build_response_options(request, **options)
    status = options[:status] || 200
    format = options[:format] || request.query_params[:format] || :json
    fixture_name = options[:fixture_name] || request.name
    custom_body = options[:body]

    response_options = {
      status: status,
      headers: build_response_headers(format, request, options),
      body: custom_body || load_fixture(fixture_name, format),
    }

    response_options
  end

  def build_response_headers(format, request, options)
    headers = {
      "Content-Type" => MIME_TYPES[format],
      "X-API-Version" => "1.0",
    }

    # Add Content-Disposition header for CSV responses
    if format == :csv
      filename = request.query_params[:filename] || "12data_#{request.name}.csv"
      headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
    end

    # Add custom headers if provided
    headers.merge!(options[:headers]) if options[:headers]

    headers
  end

  def error_fixture_name(error_code)
    case error_code
    when 400
      "bad_request_response_error"
    when 401
      "unauthorized_response_error"
    when 403
      "forbidden_response_error"
    when 404
      "not_found_response_error"
    when 429
      "too_many_requests_response_error"
    when 500
      "internal_server_response_error"
    else
      "generic_error"
    end
  end

  def default_response_options
    {
      status: 200,
      headers: { "Content-Type" => MIME_TYPES[:json] },
      body: { message: "Default test response" }.to_json,
    }
  end
end
