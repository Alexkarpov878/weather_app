module Clients
  module Geocoders
    # Geocodes addresses using the Google Maps Geocoding API, returning a Location object.
    class GoogleClient < BaseClient
      BASE_URL = "https://maps.googleapis.com/maps/api/geocode/json".freeze
      CACHE_EXPIRATION = 24.hours
      CACHE_KEY_PREFIX = "geocode/google/".freeze

      STATUS_ERRORS = {
        "ZERO_RESULTS" => { status: 404, message: "No match found for address" },
        "REQUEST_DENIED" => { status: 401, message: "Request denied by API" },
        "INVALID_REQUEST" => { status: 400, message: "Invalid request parameters" },
        "OVER_QUERY_LIMIT" => { status: 429, message: "API rate limit exceeded" }
      }.freeze

      def initialize(**kwargs)
        super(**kwargs.merge(api_key: Rails.application.credentials.geocoder_api_keys[:google_api_key]))
        @service_name = "GoogleGeocoder"
      end

      def geocode(address:)
        return Service::Failure.new(error: Errors::InvalidInputError.new("Address cannot be blank")) if address.blank?

        cached_location = fetch_cached_location(address)
        return Service::Success.new(data: cached_location) if cached_location

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
            Service::Failure.new(error: Errors::NotFoundError.new("No match found for address: #{address}"))
          end
        else
          Service::Failure.new(error: result.error || Errors::ExternalApiError.new("Geocoding failed", service_name: @service_name))
        end
      end

      private

      def process_http_response(response, url)
        if response.success?
          body = response.body
          if body["status"] == "OK"
            Service::Success.new(data: body)
          else
            error = STATUS_ERRORS[body["status"]] || { status: 400, message: body["error_message"] || "Unknown API error" }
            fail_with_external_api_error(response, url, status: error[:status], message: error[:message])
          end
        else
          fail_with_external_api_error(response, url)
        end
      end

      def fetch_cached_location(address)
        cached_data = cache_store.read(cache_key(address))
        Location.new(cached_data) if cached_data
      end

      def cache_key(address)
        "#{CACHE_KEY_PREFIX}#{Digest::SHA1.hexdigest(address.downcase.strip)}"
      end

      def parse_response(body)
        return nil if body["status"] != "OK" || body["results"].empty?

        result = body["results"].first
        address_components = result["address_components"].each_with_object({}) do |component, hash|
          type = component["types"].first
          hash[type] = component["long_name"] if type
        end

        {
          latitude: result.dig("geometry", "location", "lat"),
          longitude: result.dig("geometry", "location", "lng"),
          zip_code: result["address_components"].find { |c| c["types"].include?("postal_code") }&.dig("long_name"),
          city: result["address_components"].find { |c| c["types"].include?("locality") }&.dig("long_name"),
          state_code: result["address_components"].find { |c| c["types"].include?("administrative_area_level_1") }&.dig("short_name"),
          country: result["address_components"].find { |c| c["types"].include?("country") }&.dig("short_name"),
          full_address: result["formatted_address"]
        }
      end
    end
  end
end
