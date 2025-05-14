require 'rails_helper'

describe Clients::Geocoders::GoogleClient do
  subject(:client) { described_class.new }

  before do
    allow(Rails.application.credentials).to receive(:geocoder_api_keys).and_return({ google_api_key: 'SecretKey' })
  end

  describe '#geocode' do
    subject(:result) { client.geocode(address: address) }

    let(:address) { '1 Infinite Loop, Cupertino, CA 95014' }

    context 'with a valid address', vcr: { cassette_name: 'google_geocode_valid_address' } do
      let(:address) { '1 Infinite Loop, Cupertino, CA 95014' }

      let(:location) { result.data }

      it_behaves_like 'a geocoding client returning a location successfully'

      it 'returns a Location object for a valid address' do
        expect(location.zip_code).to eq('95014')
        expect(location.city).to eq('Cupertino')
        expect(location.state_code).to eq('CA')
        expect(location.country).to eq('US')
        expect(location.full_address).to include('Infinite Loop 1, 1 Infinite Loop, Cupertino, CA 95014, USA')
      end
    end

    context 'with an invalid address', vcr: { cassette_name: 'google_geocode_invalid_address' } do
      let(:address) { '123 Fake Street, Nowhere, XX 00000' }

      it 'returns a failure result with not found error' do
        result = client.geocode(address: address)
        expect(result).to be_a(Service::Failure)
        expect(result.error).to be_a(Errors::NotFoundError)
        expect(result.error.message).to eq('[External Service] (Status: 404) No match found for address')
      end
    end

    context 'when address is blank' do
      let(:blank_address) { "" }

      it_behaves_like 'returns a Failure with InvalidInputError'
    end

    context 'when a network error occurs' do
      let(:address) { '123 Sesame Street' }
      let(:expected_url) { Clients::Geocoders::GoogleClient::BASE_URL }

      before do
        faraday_connection = client.http_client
        allow(faraday_connection).to receive(:run_request)
          .and_raise(Faraday::TimeoutError.new("Connection timed out"))
        allow(Rails.logger).to receive(:error)
      end

      it_behaves_like 'returns a Failure with NetworkError and logs'
    end

    context 'when the API key is invalid', vcr: { cassette_name: 'google_geocode_invalid_api_key' } do
      before do
        allow(Rails.application.credentials).to receive(:geocoder_api_keys).and_return({ google_api_key: 'Fake' })
      end

      it "returns a failure result with ExternalApiError" do
        expect(result).to be_a(Service::Failure)
        expect(result.error).to be_a(Errors::ExternalApiError)
        expect(result.error.message).to include('Request denied by API')
      end
    end
  end
end
