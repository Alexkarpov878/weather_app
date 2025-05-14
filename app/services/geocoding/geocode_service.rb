module Geocoding
  class GeocodeService
    def self.call(address, client: Clients::Geocoders::GoogleClient.new)
      return Service::Failure.new(error: Errors::InvalidInputError.new("Address cannot be blank.")) if address.blank?

      begin
        client.geocode(address: address)
      rescue StandardError => e
        Rails.logger.error("Unexpected error in GeocodeService: #{e.message}")
        Service::Failure.new(error: Errors::ApplicationError.new("An unexpected error occurred: #{e.message}"))
      end
    end
  end
end
