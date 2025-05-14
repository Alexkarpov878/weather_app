module Errors
  class ExternalApiError < ApplicationError
    attr_reader :service_name, :status_code, :response_body, :message, :summary

    def initialize(summary = "External API Error", service_name: nil, status_code: nil, response_body: nil, message: nil)
      @service_name = service_name
      @status_code = status_code
      @response_body = response_body
      @message = message

      @summary = "[#{service_name || 'External Service'}]"
      @summary += " (Status: #{status_code})" if status_code
      @summary += " #{message}" if message
      super(@summary)
    end
  end
end
