source "https://rubygems.org"

gem "rails", "~> 8.0.2"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "faraday"

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
end

group :test do
  gem "vcr"
  gem "webmock"
end

group :development do
  gem "web-console"
  gem "rubocop-rails-omakase", "~> 1.1.0", require: false
  gem "rspec-rails", "~> 8.0", require: false

  gem "rubocop", "~> 1.75", require: false
  gem "rubocop-rails", "~> 2.31", require: false
  gem "rubocop-rspec", "~> 3.6.0", require: false
  gem "rubocop-performance", "~> 1.25.0", require: false

  gem "guard", require: false
  gem "guard-rspec", require: false
  gem "guard-rubocop", require: false
end

gem "tzinfo-data", platforms: %i[ windows jruby ]
