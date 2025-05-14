module Api
  module V1
    class BaseController < ActionController::API
      rescue_from Errors::InvalidInputError, Errors::ValidationError do |exception|
        render_error(
          status: :unprocessable_entity,
          message: exception.message
        )
      end

      rescue_from Errors::NotFoundError do |exception|
        render_error(
          status: :not_found,
          message: exception.message
        )
      end

      rescue_from Errors::ExternalApiError do |exception|
        log_external_api_error(exception)
        render_error(
          status: :service_unavailable,
          message: "An external service error."
        )
      end

      rescue_from Errors::ApplicationError do |exception|
        log_application_error(exception, title_prefix: "Application Error")
        render_error(
          status: :internal_server_error,
          message: "An unexpected application error occurred."
        )
      end

      private

      def render_error(status:, message: nil)
        error_object = {
          status: status,
          message: message
        }

        render json: { errors: [ error_object ] }, status: status
      end

      def log_external_api_error(exception)
        details = {
          "Type" => exception&.class,
          "Message" => exception&.message,
          "Service Name" => exception&.service_name,
          "Status Code" => exception&.status_code,
          "Response Body" => exception.respond_to?(:response_body) ? exception&.response_body&.to_s&.truncate(200) : nil,
          "OriginalError" => exception.respond_to?(:original_error) ? "#{exception.original_error.class} - #{exception.original_error.message}" : nil
        }.compact

        Rails.logger.error "External Service Error in Forecasts API V1 | #{details.map { |k, v| "#{k}: #{v}" }.join(' | ')}"
        Rails.logger.error exception.backtrace.first(10).join("\n") if exception.backtrace.present?
      end

      def log_application_error(exception, title_prefix: "Error")
        Rails.logger.error "#{title_prefix} in API V1: #{exception.class} - #{exception.message}"
        Rails.logger.error exception.backtrace.first(15).join("\n") if exception.backtrace.present?
      end
    end
  end
end
