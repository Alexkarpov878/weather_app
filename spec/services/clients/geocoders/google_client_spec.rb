require 'rails_helper'

RSpec.describe Clients::Geocoders::GoogleClient do
  subject(:client) { described_class.new }

  let(:valid_address) { "1 Infinite Loop, Cupertino, CA 95014" }
  let(:cache_key) { "#{described_class::CACHE_KEY_PREFIX}#{Digest::SHA1.hexdigest(valid_address.downcase.strip)}" }
  let(:http_client) { instance_double(Faraday::Connection) }

  before do
    allow(Rails.cache).to receive(:read).and_return(nil)
    allow(Rails.cache).to receive(:write)
    allow(Rails.logger).to receive(:error)
  end

  describe "#initialize" do
    before { allow(Rails.application.credentials).to receive(:geocoder_api_keys).and_return({ google_api_key: "SecretKey" }) }

    it "uses the default API key from credentials" do
      expect(client.api_key).to eq("SecretKey")
    end

    it "allows overriding the API key" do
      custom_client = described_class.new(api_key: "CustomKey")
      expect(custom_client.api_key).to eq("CustomKey")
    end

    it "sets the service name to GoogleGeocoder" do
      expect(client.service_name).to eq("GoogleGeocoder")
    end
  end

  describe "#geocode" do
    subject(:result) { client.geocode(address: address) }

    context "with a valid address" do
      let(:address) { valid_address }

      it "returns a successful Location object", vcr: { cassette_name: "services/clients/geocoders/google/valid_address" } do
        expect(result).to be_success
        expect(result.data).to be_a(Location)
        expect(result.data.latitude).to be_within(0.01).of(37.331686)
        expect(result.data.longitude).to be_within(0.01).of(-122.030656)
        expect(result.data.city).to eq("Cupertino")
        expect(result.data.zip_code).to eq("95014")
      end

      it "caches the location data", vcr: { cassette_name: "services/clients/geocoders/google/valid_address" } do
        result
        expect(Rails.cache).to have_received(:write).with(cache_key, hash_including(latitude: Float, longitude: Float), expires_in: 24.hours)
      end
    end

    context "with a cached address" do
      let(:address) { valid_address }
      let(:cached_location) { { latitude: 37.331686, longitude: -122.030656, city: "Cupertino", zip_code: "95014" } }
      let(:client) { described_class.new(http_client: http_client) }

      before do
        allow(Rails.cache).to receive(:read).with(cache_key).and_return(cached_location)
        allow(http_client).to receive(:run_request)
      end

      it "returns the cached Location without hitting the API" do
        expect(result).to be_success
        expect(result.data.latitude).to eq(37.331686)
        expect(http_client).not_to have_received(:run_request)
      end
    end

    context "with an invalid address" do
      let(:address) { "123 Fake Street, Nowhere, XX 00000" }

      it "returns a NotFoundError", vcr: { cassette_name: "services/clients/geocoders/google/invalid_address" } do
        expect(result).to be_failure
        expect(result.error).to be_a(Errors::NotFoundError)
        expect(result.error.message).to match(/No match found/)
      end
    end

    context "with a blank address" do
      let(:address) { "" }

      it "returns an InvalidInputError" do
        expect(result).to be_failure
        expect(result.error).to be_a(Errors::InvalidInputError)
        expect(result.error.message).to match(/blank/)
      end
    end

    describe '#geocode' do
      context "with a network timeout" do
        let(:valid_address) { '123 Main St' }
        let(:http_client) { instance_double(Faraday::Connection) }
        let(:client) { described_class.new(http_client: http_client) }
        let(:result) { client.geocode(address: valid_address) }

        before do
          allow(http_client).to receive(:run_request).and_raise(Faraday::TimeoutError.new("Timed out"))
          allow(Rails.logger).to receive(:error)
        end

        it "returns a NetworkError and logs the issue" do
          expect(result).to be_failure
          expect(result.error).to be_a(Errors::NetworkError)
          expect(Rails.logger).to have_received(:error)
        end
      end
    end

    context "with an invalid API key" do
      let(:address) { valid_address }

      before do
        allow(Rails.application.credentials).to receive(:geocoder_api_keys).and_return({ google_api_key: "InvalidKey" })
      end

      it "returns an ExternalApiError", vcr: { cassette_name: "services/clients/geocoders/google/invalid_api_key" } do
        expect(result).to be_failure
        expect(result.error).to be_a(Errors::ExternalApiError)
        expect(result.error.message).to match("[GoogleGeocoder] (Status: 401) The provided API key is invalid. ")
      end
    end
  end
end
