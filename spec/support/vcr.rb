require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  config.default_cassette_options = { record: :new_episodes }


  if Rails.application.credentials.weather_api_keys&.dig(:open_weather_map)
    config.filter_sensitive_data('<OPEN_WEATHER_MAP_API_KEY>') do
      Rails.application.credentials.weather_api_keys[:open_weather_map]
    end
  end

  if Rails.application.credentials.geocoder_api_keys&.dig(:google_api_key)
    config.filter_sensitive_data('<GOOGLE_GEOCODING_API_KEY>') do
      Rails.application.credentials.geocoder_api_keys[:google_api_key]
    end
  end
end
