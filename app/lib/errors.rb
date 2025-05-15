module Errors
  class ApplicationError < StandardError
    attr_reader :original_http_status, :status_code

    def initialize(message = "Application Error", original_http_status: nil, status_code: 500)
      super(message)
      @original_http_status = original_http_status
      @status_code = status_code
    end
  end

  class ExternalApiError < ApplicationError
    attr_reader :service_name, :response_body

    def initialize(message = "External API Error", service_name: nil, status_code: nil, response_body: nil, original_http_status: nil)
      @service_name = service_name
      super_status_code = status_code || 503
      super(build_full_message(message, service_name, super_status_code),
            original_http_status: original_http_status,
            status_code: super_status_code)
      @response_body = response_body
    end

    private
    def build_full_message(base_message, service_name, status_code)
      full_message = "[#{service_name || 'External Service'}]"
      full_message += " (Status: #{status_code})" if status_code
      full_message += " #{base_message}"
      full_message
    end
  end

  class InvalidInputError < ApplicationError
    attr_reader :field, :reason

    def initialize(message = "Invalid Input", field: nil, reason: nil, status_code: 400, original_http_status: nil)
      @field = field
      @reason = reason
      super(build_full_message(message, field, reason),
            original_http_status: original_http_status,
            status_code: status_code)
    end

    private
    def build_full_message(base_message, field, reason)
      full_message = "#{base_message}"
      full_message += " (Field: #{field})" if field
      full_message += " - #{reason}" if reason
      full_message
    end
  end

  class NetworkError < ApplicationError
    attr_reader :service_name, :original_error

    def initialize(message = "Network Error", service_name: nil, original_error: nil)
      @service_name = service_name
      @original_error = original_error
      full_message = "[#{service_name || 'External Service'}] #{message}"
      full_message += ": #{original_error.message}" if original_error&.message.present?
      super(full_message, original_http_status: nil, status_code: 503)
      set_backtrace(original_error.backtrace) if original_error&.backtrace.present?
    end
  end

  class NotFoundError < ApplicationError
    attr_reader :service_name, :response_body

    def initialize(message = "Resource Not Found", service_name: nil, status_code: 404, response_body: nil, original_http_status: nil)
      @service_name = service_name
      super(build_full_message(message, service_name, status_code),
            original_http_status: original_http_status,
            status_code: status_code)
      @response_body = response_body
    end

    private
    def build_full_message(base_message, service_name, status_code)
      full_message = "[#{service_name || 'External Service'}]"
      full_message += " (Status: #{status_code})" if status_code
      full_message += " #{base_message}"
      full_message
    end
  end

  class ValidationError < ApplicationError
    attr_reader :field, :reason

    def initialize(message = "Validation Error", field: nil, reason: nil, status_code: 422, original_http_status: nil)
      @field = field
      @reason = reason
      super(build_full_message(message, field, reason),
            original_http_status: original_http_status,
            status_code: status_code)
    end

    private
    def build_full_message(base_message, field, reason)
      full_message = "#{base_message}"
      full_message += " (Field: #{field})" if field
      full_message += " - #{reason}" if reason
      full_message
    end
  end
end
