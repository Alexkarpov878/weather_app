module Clients
  module Geocoders
    class GoogleClient < BaseClient
      BASE_URL = "https://maps.googleapis.com/maps/api/geocode/json".freeze
      CACHE_EXPIRATION = 24.hours #  Geocoder cache (Not weather)

      def initialize(**kwargs)
        super(**kwargs.merge(api_key: Rails.application.credentials.geocoder_api_keys[:google_api_key]))
        @service_name = "GoogleGeocoder"
      end

      def geocode(address:)
        return Service::Failure.new(error: Errors::InvalidInputError.new("Address cannot be blank")) if address.blank?

        if (cached_data = cache_store.read(cache_key(address)))
          return Service::Success.new(data: Location.new(cached_data))
        end

        result = make_request(
          method: :get,
          url: BASE_URL,
          params: { address: address, key: api_key }
        )

        if result.success?
          location_data = parse_response(result.data)
          if location_data
            cache_store.write(cache_key(address), location_data, expires_in: CACHE_EXPIRATION)
            Service::Success.new(data: Location.new(location_data))
          else
            Failure.new(error: Errors::NotFoundError.new("No match found for address: #{address}"))
          end
        else
          result
        end
      end

      private

      def cache_key(address)
        "geocode/google/#{Digest::SHA1.hexdigest(address.downcase.strip)}"
      end

      def parse_response(body)
        return nil if body["status"] != "OK" || body["results"].empty?

        result = body["results"].first
        {
          latitude: result.dig("geometry", "location", "lat"),
          longitude: result.dig("geometry", "location", "lng"),
          zip_code: result["address_components"].find { |c| c["types"].include?("postal_code") }&.dig("long_name"),
          city: result["address_components"].find { |c| c["types"].include?("locality") }&.dig("long_name"),
          state_code: result["address_components"].find { |c| c["types"].include?("administrative_area_level_1") }&.dig("short_name"),
          country: result["address_components"].find { |c| c["types"].include?("country") }&.dig("short_name"),
          full_address: result["formatted_address"]
        }
      rescue JSON::ParserError => e
        log_error(e, stage: "JSON Parsing", data_preview: body.truncate(100))
        raise Errors::ExternalApiError.new("Failed to parse API response JSON", service_name: service_name)
      end
    end
  end
end
