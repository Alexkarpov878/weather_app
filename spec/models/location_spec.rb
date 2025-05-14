require 'rails_helper'

describe Location do
  subject(:location) { described_class.new(attributes) }

  let(:attributes) do
    {
      latitude: 37.33182,
      longitude: -122.03118,
      zip_code: '95014',
      city: 'Cupertino',
      state_code: 'CA',
      country: 'US',
      full_address: '1 Infinite Loop, Cupertino, CA 95014'
    }
  end

  describe '#valid?' do
    it 'is valid with full_address and zip_code' do
      expect(location).to be_valid
    end

    it 'is invalid without a full_address' do
      attributes.delete(:full_address)
      expect(location).not_to be_valid
    end

    it 'is invalid without a zip_code' do
      attributes.delete(:zip_code)
      expect(location).not_to be_valid
    end
  end

  describe '#zip_code' do
    it 'returns the zip code' do
      expect(location.zip_code).to eq('95014')
    end

    it 'returns alphabetic characters' do
      attributes[:zip_code] = '950~14-123 4'
      expect(location.zip_code).to eq('950141234')
    end
  end
end
