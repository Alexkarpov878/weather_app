  class Location
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :latitude, :float
    attribute :longitude, :float
    attribute :zip_code, :string
    attribute :city, :string
    attribute :state_code, :string
    attribute :country, :string
    attribute :full_address, :string

    validates :full_address, presence: true
    validates :zip_code, presence: true

    def to_s
      full_address
    end

    def zip_code=(value)
      normalized_value = value.to_s.gsub(/[^0-9A-Za-z]/, "")
      super(normalized_value)
    end
  end
