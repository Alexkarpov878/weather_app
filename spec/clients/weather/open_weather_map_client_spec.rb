require 'rails_helper'

describe Clients::Weather::OpenWeatherMapClient do
  subject(:client) { described_class.new }

  before do
    allow(Rails.application.credentials).to receive(:weather_api_keys).and_return({ open_weather_map: 'SecretKey' })
  end

  describe '#forecast' do
    context 'with a valid location', vcr: { cassette_name: 'open_weather_map_valid_location' } do
      let(:location) { Location.new(latitude: 37.7749, longitude: -122.4194, zip_code: '94103') }

      it 'returns a Forecast object for a valid location' do
        result = client.forecast(location: location)
        expect(result).to be_a(Service::Success)

        forecast = result.data
        expect(forecast).to be_a(Forecast)
        expect(forecast.current_temperature).to eq("12.12° C")
        expect(forecast.high_temperature).to eq("13.84° C")
        expect(forecast.low_temperature).to eq("10.96° C")
        expect(forecast.fetched_at).to be_present
      end
    end

    context 'with an invalid location', vcr: { cassette_name: 'open_weather_map_invalid_location' } do
      let(:location) { Location.new(latitude: 1000, longitude: -1000, zip_code: '00000') }

      it 'returns a failure result with invalid input error' do
        result = client.forecast(location: location)
        expect(result).to be_a(Service::Failure)
        expect(result.error.message).to eq("wrong latitude")
        expect(result.error.status_code).to eq(400)
      end
    end

    context 'with an missing location' do
      let(:location) { nil }

      it 'returns a failure result with invalid input error' do
        result = client.forecast(location: location)
        expect(result).to be_a(Service::Failure)
        expect(result.error).to be_a(Errors::InvalidInputError)
        expect(result.error.message).to eq('Location is missing')
      end
    end

    context 'with an invalid api key', vcr: { cassette_name: 'open_weather_map_invalid_api_key' } do
      before do
        allow(Rails.application.credentials).to receive(:weather_api_keys).and_return({ open_weather_map: 'Fake' })
      end

      let(:location) { Location.new(latitude: 0, longitude: 0, zip_code: '00000') }

      it 'returns a failure result with invalid input error' do
        result = client.forecast(location: location)
        expect(result).to be_a(Service::Failure)
        expect(result.error).to be_a(Errors::ExternalApiError)
        expect(result.error.message).to eq('Invalid API key. Please see https://openweathermap.org/faq#error401 for more info.')
      end
    end
  end
end
