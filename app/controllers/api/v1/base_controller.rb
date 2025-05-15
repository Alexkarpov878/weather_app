module Api
  module V1
    class BaseController < ActionController::API
      EXCEPTION_CONFIG = {
        Errors::InvalidInputError => { status: :unprocessable_entity, log_prefix: "Client Input/Validation Error" },
        Errors::ValidationError => { status: :unprocessable_entity, log_prefix: "Client Input/Validation Error" },
        Errors::NotFoundError => { status: :not_found, log_prefix: "Resource Not Found" },
        Errors::ExternalApiError => { status: :service_unavailable, log_prefix: "External Service Error", message_prefix: "An external service error occurred." },
        Errors::NetworkError => { status: :service_unavailable, log_prefix: "External Service Network Error", message_prefix: "A network communication error occurred with an external service." },
        Errors::ApplicationError => { status: :internal_server_error, log_prefix: "Unhandled Application Error", message_prefix: "An unexpected application error occurred." },
        StandardError => { status: :internal_server_error, log_prefix: "Critical Unhandled StandardError", message_prefix: "An unexpected system error occurred. Please try again later." }
      }.freeze

      EXCEPTION_CONFIG.each do |exception_class, config|
        rescue_from exception_class do |exception|
          handle_exception(exception, config)
        end
      end

      private

      def handle_exception(exception, config)
        log_exception(exception, config[:log_prefix])
        render_error(
          status: exception.status_code || config[:status],
          message: build_error_message(exception, config[:message_prefix])
        )
      end

      def render_error(status:, message: nil)
        http_status = Rack::Utils.status_code(status)
        error = {
          status: http_status,
          message: message || Rack::Utils::HTTP_STATUS_CODES[http_status] || "An error occurred"
        }
        render json: { errors: [ error ] }, status: http_status
      end

      def log_exception(exception, title_prefix)
        details = build_log_details(exception)
        Rails.logger.error "#{title_prefix} in API V1 | #{details.map { |k, v| "#{k}: #{v}" }.join(' | ')}"
        log_backtrace(exception) if Rails.env.development?
      end

      def build_log_details(exception)
        base_details = {
          "Type" => exception.class.name,
          "Message" => exception.message
        }

        base_details.merge!(exception_details(exception)).compact
      end

      def exception_details(exception)
        details = {}
        details["Status Code Rendered"] = exception.status_code if exception.respond_to?(:status_code)
        details["Field"] = exception.field if exception.respond_to?(:field) && exception.field.present?
        details["Reason"] = exception.reason if exception.respond_to?(:reason) && exception.reason.present?
        details["Service Name"] = exception.service_name if exception.respond_to?(:service_name)
        details["Semantic Status Code"] = exception.status_code if exception.respond_to?(:status_code)
        details["Original HTTP Status"] = exception.original_http_status if exception.respond_to?(:original_http_status)
        details["Response Body Preview"] = exception.response_body&.to_s&.truncate(250) if exception.respond_to?(:response_body)
        details["Original Network Error"] = "#{exception.original_error.class} - #{exception.original_error.message}" if exception.is_a?(Errors::NetworkError) && exception.original_error
        details
      end

      def build_error_message(exception, prefix = nil)
        prefix ? "#{prefix} #{exception.message}" : exception.message
      end

      def log_backtrace(exception, level: :error, count: 10)
        return unless exception.backtrace&.any?
        klass_name = exception.is_a?(Errors::ApplicationError) ? exception.class.name : "StandardError (#{exception.class.name})"
        Rails.logger.send(level, "Backtrace for #{klass_name}:")
        Rails.logger.send(level, exception.backtrace.first(count).join("\n"))
      end
    end
  end
end
