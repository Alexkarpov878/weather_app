class ForecastQueryForm
  include ActiveModel::Model

  attr_accessor :address

  validates :address, presence: true

  def address=(value)
    @address = value.to_s.strip
                   .gsub(/\s+/, " ")
                   .truncate(255)
                   .gsub(/[^0-9a-zA-Z\s,.-]/, "")
  end
end
