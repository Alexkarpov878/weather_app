require 'rails_helper'

RSpec.describe ForecastPresenter do
  subject { described_class.new(forecast_result) }

  let(:forecast) { double(current_temperature: 25, high_temperature: 30, low_temperature: 20) }
  let(:cached) { true }
  let(:forecast_result) { { forecast: forecast, cached: cached } }


  describe '#as_json' do
    it 'returns properly formatted forecast data with meta information' do
      expect(subject.as_json).to eq(
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
      )
    end
  end
end
