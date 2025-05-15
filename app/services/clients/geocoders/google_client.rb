module Clients
  module Geocoders
    class GoogleClient < BaseClient
      BASE_URL = "https://maps.googleapis.com/maps/api/geocode/json".freeze
      CACHE_EXPIRATION = 24.hours
      CACHE_KEY_PREFIX = "geocode/google/".freeze

      BODY_STATUS_TO_ERROR_MAP = {
        "ZERO_RESULTS" => { error_class: Errors::NotFoundError, semantic_status: 404, message_prefix: "No match found" },
        "REQUEST_DENIED" => { error_class: Errors::ExternalApiError, semantic_status: 401, message_prefix: "Request denied by API" },
        "INVALID_REQUEST" => { error_class: Errors::InvalidInputError, semantic_status: 400, message_prefix: "Invalid request parameters" },
        "OVER_QUERY_LIMIT" => { error_class: Errors::ExternalApiError, semantic_status: 429, message_prefix: "API rate limit exceeded" },
        "UNKNOWN_ERROR" => { error_class: Errors::ExternalApiError, semantic_status: 500, message_prefix: "Unknown server error from API" }
      }.freeze

      def initialize(**kwargs)
        google_api_key_value = kwargs.delete(:api_key) || Rails.application.credentials.geocoder_api_keys&.dig(:google_api_key)
        super(**kwargs.merge(api_key: google_api_key_value, service_name: "GoogleGeocoder"))
      end

      def geocode(address:)
        return Service::Failure.new(error: Errors::InvalidInputError.new("Address cannot be blank")) if address.blank?
        cached_data_hash = fetch_cached_location_hash(address)
        return Service::Success.new(data: Location.new(cached_data_hash)) if cached_data_hash

        result = make_request(
          method: :get,
          url: BASE_URL,
          params: { address: address, key: api_key }
        )
        return result if result.failure?

        location_data_hash = parse_successful_response_body(result.data, address)
        if location_data_hash&.dig(:latitude) && location_data_hash&.dig(:longitude)
          cache_store.write(cache_key(address), location_data_hash, expires_in: CACHE_EXPIRATION)
          Service::Success.new(data: Location.new(location_data_hash))
        else
          failure_error = Errors::NotFoundError.new(
            "Successfully fetched from Google but no usable location data found for address: #{address}",
            service_name: @service_name,
            status_code: 404,
            response_body: result.data,
            original_http_status: 200
          )
          log_error(failure_error, stage: "Post-Success Parsing Failure", address: address, api_response_body: result.data)
          Service::Failure.new(error: failure_error)
        end
      end

      protected

      def check_for_errors_in_successful_response_body(response_body, http_status, request_context = {})
        return nil unless response_body.is_a?(Hash)

        status = fetch_from_response(response_body, 'status')&.to_s&.upcase
        return nil if status == "OK"

        common_error_params = {
          service_name: @service_name,
          response_body: response_body,
          original_http_status: http_status
        }

        error_details = BODY_STATUS_TO_ERROR_MAP[status]
        if error_details
          message = build_error_message(error_details, response_body, request_context, status)
          error_details[:error_class].new(message, **common_error_params, status_code: error_details[:semantic_status])
        else
          error_message_text = fetch_from_response(response_body, 'error_message') || "No specific error message provided by API."
          full_message = "Unknown Google API error in response body (API Status: #{status}, HTTP Status: #{http_status}): #{error_message_text}"
          Errors::ExternalApiError.new(full_message, **common_error_params, status_code: http_status)
        end
      end

      private

      def parse_successful_response_body(body_data, original_address)
        return nil if body_data.blank?
        results_array = body_data[:results] || body_data["results"]
        return nil if results_array.blank?
        result = results_array.first
        return nil unless result

        lat = result.dig(:geometry, :location, :lat)
        lng = result.dig(:geometry, :location, :lng)
        return nil if lat.nil? || lng.nil?

        address_components_array = result[:address_components] || result["address_components"]
        zip_code_comp = address_components_array&.find { |c| (c[:types] || c["types"])&.include?("postal_code") }
        city_comp = address_components_array&.find { |c| (c[:types] || c["types"])&.include?("locality") }
        state_comp = address_components_array&.find { |c| (c[:types] || c["types"])&.include?("administrative_area_level_1") }
        country_comp = address_components_array&.find { |c| (c[:types] || c["types"])&.include?("country") }
        formatted_address_val = result[:formatted_address] || result["formatted_address"]

        {
          latitude: lat,
          longitude: lng,
          zip_code: zip_code_comp&.dig(:long_name) || zip_code_comp&.dig("long_name"),
          city: city_comp&.dig(:long_name) || city_comp&.dig("long_name"),
          state_code: state_comp&.dig(:short_name) || state_comp&.dig("short_name"),
          country: country_comp&.dig(:short_name) || country_comp&.dig("short_name"),
          full_address: formatted_address_val || original_address
        }.compact
      end

      def fetch_cached_location_hash(address)
        cached_data = cache_store.read(cache_key(address))
        cached_data.is_a?(Hash) ? cached_data : nil
      end

      def cache_key(address)
        "#{CACHE_KEY_PREFIX}#{Digest::SHA1.hexdigest(address.downcase.strip)}"
      end

      def build_error_message(error_details, response_body, request_context, status)
        base_message = fetch_from_response(response_body, 'error_message') || error_details[:message_prefix]
        if status == "ZERO_RESULTS" && (address = request_context.dig(:params, :address))
          "#{base_message}: #{address}"
        else
          base_message
        end
      end
    end
  end
end
