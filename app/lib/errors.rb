module Errors
  class ApplicationError < StandardError; end

  class ExternalApiError < ApplicationError
    attr_reader :service_name, :status_code, :response_body

    def initialize(message = "External API Error", service_name: nil, status_code: nil, response_body: nil)
      @service_name = service_name
      @status_code = status_code
      @response_body = response_body
      full_message = "[#{service_name || 'External Service'}]"
      full_message += " (Status: #{status_code})" if status_code
      full_message += " #{message}"
      super(full_message)
    end
  end

  class InvalidInputError < ApplicationError
    attr_reader :field, :reason

    def initialize(message = "Invalid Input", field: nil, reason: nil)
      @field = field
      @reason = reason
      full_message = "#{message}"
      full_message += " (Field: #{field})" if field
      full_message += " - #{reason}" if reason
      super(full_message)
    end
  end

  class NetworkError < ApplicationError
    attr_reader :service_name, :original_error

    def initialize(message = "Network Error", service_name: nil, original_error: nil)
      @service_name = service_name
      @original_error = original_error
      full_message = "[#{service_name || 'External Service'}] #{message}"
      full_message += ": #{original_error.message}" if original_error
      super(full_message)
      set_backtrace(original_error.backtrace) if original_error
    end
  end

  class NotFoundError < ApplicationError
    attr_reader :service_name, :status_code, :response_body

    def initialize(message = "Resource Not Found", service_name: nil, status_code: 404, response_body: nil)
      @service_name = service_name
      @status_code = status_code
      @response_body = response_body
      full_message = "[#{service_name || 'External Service'}]"
      full_message += " (Status: #{status_code})" if status_code
      full_message += " #{message}"
      super(full_message)
    end
  end

  class ValidationError < ApplicationError
    attr_reader :field, :reason

    def initialize(message = "Validation Error", field: nil, reason: nil)
      @field = field
      @reason = reason
      full_message = "#{message}"
      full_message += " (Field: #{field})" if field
      full_message += " - #{reason}" if reason
      super(full_message)
    end
  end
end
