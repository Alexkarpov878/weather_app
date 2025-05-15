require 'rails_helper'

describe Clients::Geocoders::CensusClient do
  subject(:client) { described_class.new }

  describe '#geocode' do
    context 'with a valid address', vcr: { cassette_name: 'census_geocode_valid_address' } do
      subject(:result) { client.geocode(address: address) }

      let(:address) { '1207 Network Centre Dr, Effingham, IL 62401, USA' }
      let(:location) { result.data }

      it_behaves_like 'a geocoding client returning a location successfully'

      it 'sets the correct location attributes' do
        expect(location.zip_code).to eq('62401')
        expect(location.city).to eq('EFFINGHAM')
        expect(location.state_code).to eq('IL')
        expect(location.country).to eq('US')
        expect(location.full_address).to include('1207 NETWORK CENTRE DR')
      end
    end

    context 'with an invalid address', vcr: { cassette_name: 'census_geocode_invalid_address' } do
      let(:address) { '123 Fake Street, Nowhere, XX 00000' }

      it 'returns a failure result with not found error' do
        result = client.geocode(address: address)
        expect(result).to be_a(Service::Failure)
        expect(result.error).to be_a(Errors::NotFoundError)
        expect(result.error.message).to eq('[External Service] (Status: 404) No match found for address: 123 Fake Street, Nowhere, XX 00000')
      end
    end

    context 'when address is blank' do
      let(:blank_address) { "" }

      it_behaves_like 'returns a Failure with InvalidInputError'
    end

    context 'when a network error occurs' do
      let(:address) { '123 Sesame Street' }
      let(:expected_url) { Clients::Geocoders::CensusClient::BASE_URL }

      before do
        faraday_connection = client.http_client
        allow(faraday_connection).to receive(:run_request)
          .and_raise(Faraday::TimeoutError.new("Connection timed out"))
        allow(Rails.logger).to receive(:error)
      end

      it_behaves_like 'returns a Failure with NetworkError and logs'
    end
  end
end
