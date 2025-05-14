class ForecastPresenter
  def initialize(forecast_result)
    @forecast, @cached = forecast_result[:forecast], forecast_result[:cached]
  end

  def as_json
    {
      data: {
        type: "forecast",
        attributes: {
          current_temperature: @forecast.current_temperature,
          high_temperature: @forecast.high_temperature,
          low_temperature: @forecast.low_temperature
        }
      },
      meta: {
        cached: @cached
      }
    }
  end
end
