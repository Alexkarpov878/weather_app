require 'rails_helper'

# Testable subclass for hook and service_name testing
class TestableClient < Clients::BaseClient
  attr_accessor :should_hook_error, :hook_error_object

  def check_for_errors_in_successful_response_body(response_body, http_status, _request_context = {})
    @should_hook_error ? @hook_error_object : nil
  end
end

describe Clients::BaseClient do
  subject(:client) { TestableClient.new(api_key: api_key, http_client: http_client, service_name: service_name) }

  let(:api_key) { 'test_key' }
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:service_name) { 'TestService' }
  let(:url) { 'https://api.example.com/test' }
  let(:params) { { query: 'value' } }
  let(:headers) { { 'Authorization' => 'secret' } }
  let(:request) { instance_double(Faraday::Request) }
  let(:successful_response) { instance_double(Faraday::Response, success?: true, status: 200, body: { data: 'success' }, headers: {}) }

  before do
    allow(http_client).to receive(:run_request).and_yield(request).and_return(successful_response)
    allow(request).to receive(:params).and_return(params)
    allow(Rails.logger).to receive(:debug).and_call_original
    allow(Rails.logger).to receive(:info).and_call_original
    allow(Rails.logger).to receive(:error).and_call_original
  end

  shared_examples 'handles error' do |error_type, error_class, log_stage|
    it "returns Failure with #{error_class}" do
      expect(result).to be_failure
      expect(result.error).to be_a(error_class)
    end

    it "logs error with stage '#{log_stage}'" do
      result
      expect(Rails.logger).to have_received(:error).with(/#{log_stage}/)
    end
  end

  describe '#initialize' do
    it 'sets defaults' do
      client = described_class.new
      expect(client.http_client).to be_a(Faraday::Connection)
      expect(client.service_name).to eq('Base')
    end
  end

  describe '#make_request' do
    subject(:make_request) { client.send(:make_request, method: :get, url: url, params: params, headers: headers) }

    context 'when successful' do
      it 'returns Success with data' do
        expect(make_request).to be_success
        expect(make_request.data).to eq({ data: 'success' })
      end

      it 'logs debug communication' do
        make_request
        expect(Rails.logger).to have_received(:debug).with(/API Communication: #{service_name}/)
      end
    end

    context 'when body has errors (hook)' do
      before do
        client.should_hook_error = true
        client.hook_error_object = Errors::ExternalApiError.new('Body error', service_name: service_name, status_code: 422)
      end

      it_behaves_like 'handles error', 'body-specific', Errors::ExternalApiError, 'API Body-Specific Error' do
        let(:result) { make_request }
      end
    end

    context 'when non-2xx response' do
      let(:error_response) { instance_double(Faraday::Response, success?: false, status: 404, body: { message: 'Not found' }, headers: {}) }

      before { allow(http_client).to receive(:run_request).and_return(error_response) }

      it_behaves_like 'handles error', 'non-2xx', Errors::NotFoundError, 'API Response Error' do
        let(:result) { make_request }
      end
    end

    context 'when network error' do
      before { allow(http_client).to receive(:run_request).and_raise(Faraday::TimeoutError.new('Timeout')) }

      it_behaves_like 'handles error', 'network', Errors::NetworkError, 'Network Communication Error' do
        let(:result) { make_request }
      end
    end
  end

  describe '#filter_sensitive_data' do
    it 'redacts sensitive keys in hash' do
      data = { api_key: 'secret', appid: 'hidden', safe: 'ok' }
      expect(client.send(:filter_sensitive_data, data)).to eq({ api_key: '[REDACTED]', appid: '[REDACTED]', safe: 'ok' })
    end
  end
end
