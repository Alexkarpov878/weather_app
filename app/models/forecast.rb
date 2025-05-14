class Forecast
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :current_temperature, :string
  attribute :high_temperature, :string
  attribute :low_temperature, :string
  attribute :conditions, :string
  attribute :fetched_at, :datetime

  validates :current_temperature, presence: true
end
