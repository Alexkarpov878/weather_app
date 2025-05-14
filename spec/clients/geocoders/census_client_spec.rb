require 'rails_helper'

describe Clients::Geocoders::CensusClient do
  subject(:client) { described_class.new }

  describe '#geocode' do
    context 'with a valid address', vcr: { cassette_name: 'census_geocode_valid_address' } do
      subject(:result) { client.geocode(address: address) }

      let(:address) { '1207 Network Centre Dr, Effingham, IL 62401, USA' }
      let(:location) { result.data }


      it 'returns a Location object' do
        expect(result).to be_a(Service::Success)
        expect(result.data).to be_a(Location)
      end

      it 'sets the correct location attributes' do
        expect(location.latitude).to be_a(Float)
        expect(location.longitude).to be_a(Float)
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
        expect(result.error.message).to eq('No match found for address: 123 Fake Street, Nowhere, XX 00000')
      end
    end

    context 'when address is blank' do
      let(:blank_address) { "" }

      it 'returns a Failure with InvalidInputError' do
        result = client.geocode(address: blank_address)
        expect(result).to be_failure
        expect(result.error).to be_a(Errors::InvalidInputError)
        expect(result.error.message).to eq("Address cannot be blank")
      end

      it 'does not attempt an API call' do
        expect { client.geocode(address: blank_address) }.not_to raise_error
      end
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

      it 'returns a Failure with NetworkError' do
        result = client.geocode(address: address)
        expect(result).to be_failure
        expect(result.error).to be_a(Errors::NetworkError)
        expect(result.error.message).to include("Network communication error: Connection timed out")
      end

      it 'logs the network communication error' do
        client.geocode(address: address)
        expect(Rails.logger).to have_received(:error).with(
          include("Error in Clients::Geocoders::CensusClient during [Network Communication]")
            .and(include("Faraday::TimeoutError - Connection timed out"))
            .and(include("#{Clients::Geocoders::CensusClient::BASE_URL}"))
        )
      end
    end
  end
end
