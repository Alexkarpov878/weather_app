require 'rails_helper'

describe Forecast do
  subject(:forecast) { described_class.new(attributes) }

  let(:attributes) do
    {
      current_temperature: '24°C',
      high_temperature: '28°C',
      low_temperature: '18°C',
      conditions: 'Sunny',
      fetched_at: Time.current
    }
  end

  describe '#valid?' do
    it 'is valid with a current_temperature' do
      expect(forecast).to be_valid
    end

    it 'is invalid without a current_temperature' do
      attributes.delete(:current_temperature)
      expect(forecast).not_to be_valid
      expect(forecast.errors[:current_temperature]).to include("can't be blank")
    end
  end
end
