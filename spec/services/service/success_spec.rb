require 'rails_helper'

describe Service::Success do
  subject(:success_result) { described_class.new(data: success_data) }

  let(:success_data) { { message: "Operation successful", value: 123 } }

  it "initializes with data" do
    expect(success_result.data).to eq(success_data)
  end

  describe "#success?" do
    it "returns true" do
      expect(success_result.success?).to be true
    end
  end

  describe "#failure?" do
    it "returns false" do
      expect(success_result.failure?).to be false
    end
  end

  describe "#data" do
    it "returns the initialized data" do
      expect(success_result.data).to eq(success_data)
    end
  end
end
