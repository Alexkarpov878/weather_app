module Errors
  class NetworkError < ApplicationError
    attr_reader :service_name

    def initialize(message = "Network Error", service_name: nil, original_error: nil)
      @service_name = service_name
      full_message = "[#{service_name || 'External Service'}] #{message}"
      full_message += ": #{original_error.message}" if original_error
      super(full_message)
      set_backtrace(original_error.backtrace) if original_error
    end
  end
end
