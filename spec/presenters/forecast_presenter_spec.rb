require 'rails_helper'

RSpec.describe ForecastPresenter do
  subject(:presenter) { described_class.new(forecast_result) }

  let(:forecast) { instance_double(Forecast, current_temperature: 25, high_temperature: 30, low_temperature: 20) }
  let(:cached) { true }
  let(:forecast_result) { { forecast: forecast, cached: cached } }

  describe '#as_json' do
    let(:expected_json) do
      {
        data: {
          type: "forecast",
          attributes: {
            current_temperature: 25,
            high_temperature: 30,
            low_temperature: 20
          }
        },
        meta: {
          cached: true
        }
      }
    end

    it 'returns properly formatted forecast data with meta information' do
      expect(presenter.as_json).to eq(expected_json)
    end
  end
end
