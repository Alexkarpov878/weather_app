module Api
  module V1
    class ForecastsController < Api::V1::BaseController
      def show
        form = ForecastQueryForm.new(address: params[:address])
        if form.invalid?
          render_error(status: :unprocessable_entity, message: form.errors.full_messages.join(", "))
          return
        end

        geocoding_result = Geocoding::GeocodeService.call(*form.address)
        if geocoding_result.failure?
          render_error(status: geocoding_result.error&.status_code, message: geocoding_result.error&.message)
          return
        end

        forecast_result = Weather::ForecastService.call(location: geocoding_result.data)
        if forecast_result.failure?
          render_error(status: :bad_request, message: forecast_result.error&.message)
          return
        end

        render json: ForecastPresenter.new(forecast_result.data).as_json, status: :ok
      end
    end
  end
end
