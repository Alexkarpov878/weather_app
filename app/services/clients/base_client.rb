module Clients
  class BaseClient
    include Service

    NETWORK_ERRORS = [ Faraday::TimeoutError, Faraday::ConnectionFailed ].freeze
    DEFAULT_OPEN_TIMEOUT = 2
    DEFAULT_READ_TIMEOUT = 5
    SENSITIVE_CONTEXT_KEYS = [ :key, "key", :appid, "appid", :api_key, "api_key" ].freeze

    attr_reader :api_key, :http_client, :service_name

    def initialize(api_key: nil, http_client: nil, service_name: nil)
      @api_key = api_key
      @http_client = http_client || default_http_client
      @service_name = service_name || self.class.name.demodulize.gsub(/Client$/, '')
    end

    protected

    def make_request(method:, url:, params: {}, body: nil, headers: {})
      response = perform_request(method, url, params, body, headers)
      process_response(response, url: url, method: method, request_params: params, request_body: body)
    rescue *NETWORK_ERRORS => e
      handle_network_error(e, url: url, method: method, request_params: params, request_body: body)
    rescue Faraday::ClientError => e
      handle_faraday_client_error(e, url: url, method: method, request_params: params, request_body: body)
    rescue JSON::ParserError => e
      handle_json_parsing_error(e, url: url, method: method, response_text: e.message.match(/'(.*?)'/)&.captures&.first, request_params: params, request_body: body)
    rescue StandardError => e
      handle_unexpected_error(e, "HTTP Request Execution", url: url, method: method, request_params: params, request_body: body)
    end

    def check_for_errors_in_successful_response_body(response_body, http_status, request_context = {})
      nil
    end

    private

    def perform_request(method, url, params, body, headers)
      @http_client.run_request(method.downcase.to_sym, url, body, headers) do |req|
        req.params.update(params) if params.present?
      end
    rescue *NETWORK_ERRORS => e
      raise e
    end

    def process_response(response, **context)
      log_communication(response, **context)
      response.success? ? handle_successful_response(response, **context) : handle_error_response(response, **context)
    end

    def handle_successful_response(response, **context)
      error = check_for_errors_in_successful_response_body(response.body, response.status, context)
      if error
        log_error(error, stage: "API Body-Specific Error (HTTP #{response.status})", **context)
        Failure.new(error: error)
      else
        Success.new(data: response.body)
      end
    end

    def handle_error_response(response, **context)
      error = build_error_from_response(response)
      log_error(error, stage: "API Response Error (HTTP #{response.status})", **context)
      Failure.new(error: error)
    end

    def build_error_from_response(response)
      status = response.status
      body = response.body
      message = extract_error_message(body) || "API request failed"
      error_class, prefix = error_class_for_status(status)
      full_message = "#{prefix}: #{message} (HTTP Status: #{status})"

      error_class.new(
        full_message,
        service_name: @service_name,
        status_code: status,
        response_body: body,
        original_http_status: status
      )
    end

    def error_class_for_status(status)
      case status
      when 400 then [ Errors::InvalidInputError, "Bad Request" ]
      when 401 then [ Errors::ExternalApiError, "Unauthorized" ]
      when 403 then [ Errors::ExternalApiError, "Forbidden" ]
      when 404 then [ Errors::NotFoundError, "Resource Not Found" ]
      when 422 then [ Errors::ValidationError, "Unprocessable Entity" ]
      when 429 then [ Errors::ExternalApiError, "Rate Limit Exceeded" ]
      when 500..599 then [ Errors::ExternalApiError, "Server Error" ]
      else [ Errors::ExternalApiError, "External API Error" ]
      end
    end

    def extract_error_message(body)
      case body
      when Hash then body[:message] || body[:error_message] || body[:error] || body[:errors]&.to_s
      when String then body if body.length < 200
      end
    end

    def log_communication(response, url:, method:, request_params: nil, request_body: nil)
      status = response.status
      response_body_preview = filter_sensitive_data(response.body).to_s.truncate(200, omission: "... (truncated)")
      log_parts = [ "API Communication: #{@service_name} | Method: #{method.upcase}", "URL: #{url}" ]
      log_parts << "Params: #{filter_sensitive_data(request_params).inspect}" if request_params.present?
      log_parts << "Request Body: #{filter_sensitive_data(request_body).to_s.truncate(100)}" if request_body.present?
      log_parts << "Status: #{status}" << "Response Body: #{response_body_preview}" if status

      Rails.logger.debug(log_parts.join(" | ")) if response.success? && !check_for_errors_in_successful_response_body(response.body, status, {})
      Rails.logger.info(log_parts.join(" | "))
    end

    def handle_network_error(error, **context)
      log_error(error, stage: "Network Communication Error", **context)
      Failure.new(error: Errors::NetworkError.new(
        "Network error: #{error.message}",
        service_name: @service_name,
        original_error: error
      ))
    end

    def handle_faraday_client_error(error, **context)
      response = error.response
      error = response ? build_error_from_response(OpenStruct.new(status: response[:status], body: response[:body])) :
                        Errors::ExternalApiError.new("Client error: #{error.message}", service_name: @service_name)
      log_error(error, stage: "Faraday Client Error", **context)
      Failure.new(error: error)
    end

    def handle_json_parsing_error(error, response_text:, **context)
      log_error(error, stage: "JSON Parsing Error", response_text_preview: response_text.to_s.truncate(200), **context)
      Failure.new(error: Errors::ExternalApiError.new(
        "Failed to parse API response JSON.",
        service_name: @service_name,
        response_body: "Invalid JSON: #{response_text.to_s.truncate(100)}"
      ))
    end

    def handle_unexpected_error(error, stage, **context)
      app_error = error.is_a?(Errors::ApplicationError) ? error : Errors::ApplicationError.new(
        "Unexpected error during #{stage}: #{error.message}", original_http_status: nil
      )
      app_error.set_backtrace(error.backtrace) unless error.is_a?(Errors::ApplicationError)
      log_error(app_error, stage: "Unexpected Error in #{stage}", **context)
      Failure.new(error: app_error)
    end

    def default_http_client
      Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/, parser_options: { symbolize_names: true }
        f.response :logger, Rails.logger, headers: true, bodies: { request: true, response: true }, log_level: :debug do |logger|
          logger.filter(/(api_key|key|appid=)(\S+)/, '\1[REDACTED]')
          logger.filter(/("Authorization":")(.*?)(")/, '\1[REDACTED]\3')
        end
        f.adapter Faraday.default_adapter
        f.options.timeout = DEFAULT_READ_TIMEOUT
        f.options.open_timeout = DEFAULT_OPEN_TIMEOUT
        f.headers["Accept"] = "application/json"
      end
    end

    def filter_sensitive_data(data)
      case data
      when nil, Numeric, TrueClass, FalseClass
        data
      when String
        begin
          parsed = JSON.parse(data)
          filter_sensitive_data(parsed) # Recursively filter if parsing succeeds
        rescue JSON::ParserError
          data # Return the original string if it’s not valid JSON
        end
      when Hash
        data.each_with_object({}) do |(key, value), hash|
          hash[key] = if SENSITIVE_CONTEXT_KEYS.include?(key.to_s) || SENSITIVE_CONTEXT_KEYS.include?(key.to_sym)
                        "[REDACTED]"
                      else
                        filter_sensitive_data(value)
                      end
        end
      else
        data
      end
    end

    def fetch_from_response(response, key)
      response.fetch(key.to_sym) { response.fetch(key.to_s, nil) }
    end

    def parse_json_string(str)
      str.blank? ? nil : JSON.parse(str, rescue: str)
    end

    def cache_store
      Rails.cache
    end

    def log_error(error, stage:, **context)
      filtered_context = filter_sensitive_data(context.dup)
      backtrace = error.backtrace ? error.backtrace.first(10).join("\n") : "No backtrace available."
      Rails.logger.error(
        "Error in #{self.class.name} (#{@service_name}) during [#{stage}]: #{error.class} - #{error.message} | Context: #{filtered_context.inspect}\nBacktrace:\n#{backtrace}"
      )
    end
  end
end
