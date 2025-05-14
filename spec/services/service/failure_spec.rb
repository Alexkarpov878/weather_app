require 'rails_helper'

describe Service::Failure do
  subject(:failure_result) { described_class.new(error: failure_error) }

  let(:failure_error) { StandardError.new("Something broke") }
  let(:custom_app_error) { Errors::ValidationError.new("Input invalid") }


  it "initializes with an error" do
    expect(failure_result.error).to eq(failure_error)
  end

  it "initializes with a custom ApplicationError subclass" do
    custom_failure = described_class.new(error: custom_app_error)
    expect(custom_failure.error).to eq(custom_app_error)
  end

  describe "#success?" do
    it "returns false" do
      expect(failure_result.success?).to be false
    end
  end

  describe "#failure?" do
    it "returns true" do
      expect(failure_result.failure?).to be true
    end
  end

  describe "#error" do
    it "returns the initialized error" do
      expect(failure_result.error).to eq(failure_error)
    end
  end
end
