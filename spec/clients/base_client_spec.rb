require 'rails_helper'

describe Clients::BaseClient do
  subject(:client) { described_class.new(api_key: api_key, http_client: http_client, service_name: service_name) }

  let(:api_key) { 'test_key' }
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:service_name) { 'TestClient' }
  let(:url) { 'https://api.example.com/test' }
  let(:params) { { query: 'value' } }
  let(:headers) { { 'Custom' => 'Header' } }

  describe '#make_request' do
    subject(:make_request) { client.send(:make_request, method: 'GET', url: url, params: params, headers: headers) }

    let(:response) { instance_double(Faraday::Response, success?: success, status: status, body: response_body) }
    let(:request) { instance_double(Faraday::Request) }
    let(:success) { true }
    let(:status) { 200 }
    let(:response_body) { '{"data":"success"}' }

    before do
      allow(http_client).to receive(:run_request).and_yield(request).and_return(response)
      allow(request).to receive(:params).and_return(params)
    end

    context 'when request is successful' do
      it { is_expected.to be_a(Service::Success) }

      it 'returns the response data' do
        expect(make_request.data).to eq(response_body)
      end
    end

    context 'when response is unsuccessful' do
      let(:success) { false }
      let(:status) { 400 }
      let(:response_body) { { message: 'API request failed with status 400', status: '400' }.as_json }

      it "returns a failure" do
        allow(response).to receive(:headers).and_return({})
        expect(make_request).to be_a(Service::Failure)
      end

      it 'returns an external API error' do
        allow(response).to receive(:headers).and_return({})
        error = make_request.error
        expect(error).to be_a(Errors::ExternalApiError)
        expect(error.message).to include('API request failed with status 400')
      end
    end

    context 'when network error occurs' do
      let(:network_error) { Faraday::TimeoutError.new('Timed out') }

      before { allow(http_client).to receive(:run_request).and_raise(network_error) }

      it { is_expected.to be_a(Service::Failure) }

      it 'returns a network error' do
        error = make_request.error
        expect(error).to be_a(Errors::NetworkError)
        expect(error.message).to include('Network communication error: Timed out')
      end
    end

    context 'when unexpected error occurs' do
      let(:unexpected_error) { StandardError.new('Unexpected') }

      before { allow(http_client).to receive(:run_request).and_raise(unexpected_error) }

      it { is_expected.to be_a(Service::Failure) }

      it 'returns an application error' do
        error = make_request.error
        expect(error).to be_a(Errors::ApplicationError)
        expect(error.message).to include('Unexpected error during HTTP Request Execution')
      end
    end
  end

  describe '#log_error' do
    subject(:log_error) { client.send(:log_error, error, stage: 'TestStage', context: context) }

    let(:error) { StandardError.new('Test error') }
    let(:context) { { url: 'example.com', status: 500 } }
    let(:expected_log_message) do
      /Error in Clients::BaseClient during \[TestStage\]: StandardError - Test error | Context: #{context.inspect}/
    end

    it 'logs the error with context' do
      allow(Rails.logger).to receive(:error)
      log_error
      expect(Rails.logger).to have_received(:error).with(expected_log_message)
    end
  end
end
