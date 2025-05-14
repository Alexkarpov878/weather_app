require 'spec_helper'

describe ForecastQueryForm do
  describe "validations" do
    subject(:form) { described_class.new(address: nil) }

    it "requires an address" do
      expect(form).not_to be_valid
      expect(form.errors[:address]).to include("can't be blank")
    end
  end

  describe "#address=" do
    subject(:form) { described_class }

    it "formats the address correctly" do
      expect(form.new(address: "  123 Main St  ").address).to eq("123 Main St")
      expect(form.new(address: "a" * 300).address.length).to eq(255)
      expect(form.new(address: "123 Main St #@$%^&*()").address).to eq("123 Main St ")
      expect(form.new(address: "123-A Main St., Apt 4, Vancouver").address).to eq("123-A Main St., Apt 4, Vancouver")
    end
  end
end
