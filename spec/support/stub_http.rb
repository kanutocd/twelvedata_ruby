# frozen_string_literal: true

module TwelvedataRuby::StubHttp
  MIME_TYPES = {
    json: "application/json; charset=utf-8",
    csv: "text/csv",
    plain: "text/plain",
  }.freeze

  def mock_request(request, **opts)
    stub_http_request(request.http_verb, opts[:full_url] || request.full_url)
  end

  def stub_http_fetch(request, **opts)
    mock_request(request, full_url: opts[:full_url]).and_return(
      response_options(
        request,
        http_status: opts[:http_status] || 200,
        fixture_name: error_klass_fixture(opts[:error_code], opts[:error_klass_name]) || request.name,
        content_type_format: opts[:format] || request.query_params[:format],
      ),
    )
  end

  def stub_request(relative_url="invalido-na-pahina", http_verb=:get, params={})
    OpenStruct.new(
      http_verb: http_verb,
      build: [http_verb, relative_url, params: params],
      :"valid?" => true,
      full_url: "#{TwelvedataRuby::Client.origin[:origin]}/#{relative_url}",
    )
  end

  private

  def error_klass_fixture(error_code, klass_name=nil)
    klass_name ||= TwelvedataRuby::ResponseError.error_code_klass(error_code)
    (klass_name[0].downcase + klass_name[1, klass_name.length - 1])
      .gsub(/([A-Z])/) {|s| "_#{s.downcase}" } if klass_name
  end

  def response_options(req, http_status:, fixture_name:, content_type_format:)
    options = {
      status: http_status,
      body: load_fixture(fixture_name, content_type_format),
      headers: {"Content-Type" => MIME_TYPES[content_type_format]},
    }
    if content_type_format == :csv
      options[:headers].merge!(
        "Content-Disposition" => "attachment; filename=\"#{req.query_params[:filename] || "12data_#{req.name}.csv"}\"",
      )
    end
    options
  end
end
