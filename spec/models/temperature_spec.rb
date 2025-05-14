require 'rails_helper'

describe Temperature do
  subject(:temperature) { described_class.new(attributes) }

  let(:attributes) do
    {
      value: 37.0,
      unit: "C"
    }
  end

  describe '#valid?' do
    it 'is valid with unit and value' do
      expect(temperature).to be_valid
    end

    it 'is invalid without a unit' do
      attributes.delete(:unit)
      expect(temperature).not_to be_valid
    end

    it 'is invalid without a value' do
      attributes.delete(:value)
      expect(temperature).not_to be_valid
    end
  end

  describe '#to_s' do
    it 'returns the temperature as a string' do
      expect(temperature.to_s).to eq("37.0° C")
    end
  end
end
