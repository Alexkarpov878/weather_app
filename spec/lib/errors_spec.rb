require 'rails_helper'

RSpec.describe Errors do
  describe Errors::ApplicationError do
    it 'inherits from StandardError' do
      expect(described_class.superclass).to eq(StandardError)
    end

    it 'sets a custom message' do
      error = described_class.new('Something went wrong')
      expect(error.message).to eq('Something went wrong')
    end
  end

  describe Errors::ExternalApiError do
    let(:error) { described_class.new('API failed', service_name: 'WeatherAPI', status_code: 503, response_body: { error: 'down' }) }

    it 'sets service_name, status_code, and response_body' do
      expect(error.service_name).to eq('WeatherAPI')
      expect(error.status_code).to eq(503)
      expect(error.response_body).to eq({ error: 'down' })
    end

    it 'includes service and status in message' do
      expect(error.message).to eq('[WeatherAPI] (Status: 503) API failed')
    end
  end

  describe Errors::InvalidInputError do
    let(:error) { described_class.new('Bad input', field: 'email', reason: 'invalid format') }

    it 'sets field and reason' do
      expect(error.field).to eq('email')
      expect(error.reason).to eq('invalid format')
    end

    it 'includes field and reason in message' do
      expect(error.message).to eq('Bad input (Field: email) - invalid format')
    end
  end

  describe Errors::NetworkError do
    let(:original_error) { StandardError.new('Connection timed out') }
    let(:error) { described_class.new('Network issue', service_name: 'API', original_error: original_error) }

    it 'sets service_name and original_error' do
      expect(error.service_name).to eq('API')
      expect(error.original_error).to eq(original_error)
    end

    it 'includes original error in message' do
      expect(error.message).to eq('[API] Network issue: Connection timed out')
    end

    it 'preserves original backtrace' do
      original_error.set_backtrace([ 'line1', 'line2' ])
      expect(error.backtrace).to eq([ 'line1', 'line2' ])
    end
  end

  describe Errors::NotFoundError do
    let(:error) { described_class.new('Address not found', service_name: 'DB', status_code: 404) }

    it 'sets service_name and status_code, with nil response_body' do
      expect(error.service_name).to eq('DB')
      expect(error.status_code).to eq(404)
      expect(error.response_body).to be_nil
    end

    it 'includes service and status in message' do
      expect(error.message).to eq('[DB] (Status: 404) Address not found')
    end
  end

  describe Errors::ValidationError do
    let(:error) { described_class.new('Invalid data', field: 'name', reason: 'too short') }

    it 'sets field and reason' do
      expect(error.field).to eq('name')
      expect(error.reason).to eq('too short')
    end

    it 'includes field and reason in message' do
      expect(error.message).to eq('Invalid data (Field: name) - too short')
    end
  end
end
