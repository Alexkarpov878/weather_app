module Clients
  module Geocoders
    class CensusClient < BaseClient
      BASE_URL = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress".freeze

      def initialize(**kwargs)
        super(service_name: "CensusGeocoder", **kwargs)
      end

      def geocode(address:)
        return Failure.new(error: Errors::InvalidInputError.new("Address cannot be blank")) if address.blank?

        cache_key = "geocode/census/#{Digest::SHA1.hexdigest(address.downcase.strip)}"

        # TODO: Extract caching logic and cache the full API response instead of just the location
        if (cached_data = cache_store.read(cache_key))
          return Success.new(data: Location.new(cached_data))
        end

        result = make_request(
          method: :get,
          url: BASE_URL,
          params: {
            address: address,
            benchmark: "Public_AR_Current",
            format: "json"
          }
        )

        if result.success?
          location_data = parse_response(result.data)
          if location_data
            cache_store.write(cache_key, location_data, expires_in: 24.hours)
            Success.new(data: Location.new(location_data))
          else
            Failure.new(error: Errors::NotFoundError.new("No match found for address: #{address}"))
          end
        else
          result # Propagate failure
        end
      end

      private

      def parse_response(body)
        match = body.dig("result", "addressMatches", 0)
        return nil unless match

        {
          latitude: match.dig("coordinates", "y"),
          longitude: match.dig("coordinates", "x"),
          zip_code: match.dig("addressComponents", "zip"),
          city: match.dig("addressComponents", "city"),
          state_code: match.dig("addressComponents", "state"),
          country: "US",  # Census is US-specific
          full_address: match["matchedAddress"]
        }
      rescue JSON::ParserError => e
        log_error(e, stage: "JSON Parsing", data_preview: body.truncate(100))
        raise Errors::ExternalApiError.new("Failed to parse API response JSON", service_name: service_name)
      end
    end
  end
end
