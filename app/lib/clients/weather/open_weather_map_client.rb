module Clients
  module Weather
    class OpenWeatherMapClient < BaseClient
      include Service

      API_URL = "https://api.openweathermap.org/data/2.5/weather".freeze
      DEFAULT_UNITS = "metric".freeze

      def initialize(**kwargs)
        super(**kwargs.merge(api_key: Rails.application.credentials.weather_api_keys[:open_weather_map]))
        @service_name = "OpenWeatherMapClient"
        @units = DEFAULT_UNITS
      end

      def forecast(location:)
        return Failure.new(error: Errors::InvalidInputError.new("Location is missing")) if location.blank?

        result = make_request(
          method: :get,
          url:    API_URL,
          params: {
            lat:   location.latitude,
            lon:   location.longitude,
            appid: api_key,
            units: @units
          }
        )

        return result unless result.success?

        build_forecast(result.data)
      end

      private

      def build_forecast(response)
        main = response.fetch("main", {})
        weather = response.fetch("weather", []).first || {}

        forecast = Forecast.new(
          current_temperature: Temperature.new(
            value: main.fetch("temp"),
            unit:  unit_symbol
          ),
          high_temperature: Temperature.new(
            value: main.fetch("temp_max"),
            unit:  unit_symbol
          ),
          low_temperature: Temperature.new(
            value: main.fetch("temp_min"),
            unit:  unit_symbol
          ),
          conditions: weather.fetch("description"),
          fetched_at: Time.at(response.fetch("dt")).utc,
        )

        if forecast.valid?
          Success.new(data: forecast)
        else
          Failure.new(error: Errors::ValidationError.new(forecast.errors.full_messages.join(", ")))
        end
      end

      def unit_symbol
        @units == "metric" ? "C" : "F"
      end
    end
  end
end
