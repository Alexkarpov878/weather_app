module Errors
  class ExternalApiError < ApplicationError
    attr_reader :service_name, :status_code, :response_body

    def initialize(message = "External API Error", service_name: nil, status_code: nil, response_body: nil)
      @service_name = service_name
      @status_code = status_code
      @response_body = response_body
      full_message = "[#{service_name || 'External Service'}] #{message}"
      full_message += " (Status: #{status_code})" if status_code
      super(full_message)
    end
  end
end
