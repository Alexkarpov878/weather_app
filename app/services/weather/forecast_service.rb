module Weather
  class ForecastService
    def self.call(location:, client: Clients::Weather::OpenWeatherMapClient.new)
      raise InvalidInputError, "Invalid location" unless location

      cached = true
      cache_key = "weather:forecast:v1:#{location.zip_code}"

      begin
        forecast = Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
          cached = false
          result = client.forecast(location:)
          return result if result.failure?
          result.data
        end

        Service::Success.new(data: { forecast: forecast, cached: cached })

      rescue StandardError => e
        Rails.logger.error("Unexpected error in ForecastService: #{e.message}")
        Service::Failure.new(error: Errors::ApplicationError.new("An unexpected error occurred"))
      end
    end
  end
end
