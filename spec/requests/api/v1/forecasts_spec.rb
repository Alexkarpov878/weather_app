require 'spec_helper'

describe 'Forecasts API', type: :request do
  describe 'GET /api/v1/forecast' do
    subject(:make_request) { get '/api/v1/forecast', params: params }

    let(:params) { { address: '1 Infinite Loop, Cupertino, California' } }
    let(:expected_response) do
      {
        'data' => {
          'type' => 'forecast',
          'attributes' => {
            'current_temperature' => "15.42° C",
            'high_temperature' => "17.05° C",
            'low_temperature' => "13.53° C"
          }
        },
        'meta' => {
          'cached' => false
        }
      }
    end

    context 'with valid parameters', vcr: { cassette_name: 'valid_forecast_api_response' } do
      before { make_request }

      it 'returns forecast data with a 200 status' do
        expect(response.parsed_body).to match(expected_response)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
