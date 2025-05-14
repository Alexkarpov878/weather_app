module Clients
  class BaseClient
    include Service

    NETWORK_ERRORS = [
      Faraday::TimeoutError,
      Faraday::ConnectionFailed
    ].freeze

    DEFAULT_OPEN_TIMEOUT = 2
    DEFAULT_READ_TIMEOUT = 5

    attr_reader :api_key, :http_client, :service_name

    def initialize(api_key: nil, http_client: default_http_client, service_name: self.class.name.demodulize)
      @api_key = api_key
      @http_client = http_client || default_http_client
      @service_name = service_name
    end

    protected

    def make_request(method:, url:, params: {}, body: nil, headers: {})
      response = execute_http_request(method, url, params, body, headers)
      process_http_response(response, url)
    rescue *NETWORK_ERRORS => e
      handle_network_error(e, url)
    rescue Faraday::ClientError => e
      handle_client_error(e, url)
    rescue StandardError => e
      handle_unexpected_error(e, "HTTP Request Execution", url: url, method: method)
    end

    def handle_client_error(error, url)
      log_error(error, stage: "HTTP Request", url: url)
      Failure.new(error: Errors::ExternalApiError.new(
        "API request failed",
        service_name: @service_name,
        status_code: error.response&.dig(:status),
        response_body: error.response&.dig(:body)
      ))
    end

    def default_http_client
      Faraday.new do |f|
        f.request :json
        f.response :json
        f.response :logger, Rails.logger
        f.adapter Faraday.default_adapter

        f.options.timeout = DEFAULT_READ_TIMEOUT
        f.options.open_timeout = DEFAULT_OPEN_TIMEOUT

        f.headers["Accept"] = "application/json"
        f.headers["Content-Type"] = "application/json"
      end
    end

    def log_error(error, stage:, **context)
      Rails.logger.error(
        "Error in #{self.class.name} during [#{stage}]: #{error.class} - #{error&.message} | Context: #{context&.inspect}\n#{error&.backtrace&.join("\n")}"
      )
    end

    protected

    def cache_store
      Rails.cache
    end

    private

    def execute_http_request(method, url, params, body, headers)
      @http_client.run_request(method.downcase.to_sym, url, body, headers) do |req|
        req.params.update(params) if params.any?
      end
    end

    def process_http_response(response, url)
      if response.success?
        Success.new(data: response.body)
      else
        fail_with_external_api_error(response, url)
      end
    end

    def fail_with_external_api_error(response, url, status: 400, message: nil)
      message = message || response&.body&.dig("message")
      error = Errors::ExternalApiError.new(
        "API request failed with status #{response.status}",
        service_name: @service_name,
        status_code: response&.status,
        response_body: response&.body,
        message:
      )

      log_error(
        error,
        stage: "HTTP Response Processing",
        url: url,
        status: response&.status,
        headers: response&.headers,
        body: response&.body,
        message:
      )
      Failure.new(error:)
    end

    def handle_network_error(error, url)
      log_error(error, stage: "Network Communication", url: url)
      Failure.new(error: Errors::NetworkError.new(
        "Network communication error: #{error.message}",
        service_name: @service_name,
        original_error: error
      ))
    end

    def handle_unexpected_error(error, stage, **context)
      log_error(error, stage: stage, **context)
      app_error = error.is_a?(Errors::ApplicationError) ? error : Errors::ApplicationError.new("Unexpected error during #{stage}: #{error.message}")
      Failure.new(error: app_error)
    end
  end
end
