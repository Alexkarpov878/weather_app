class Temperature
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :value, :float
  attribute :unit, :string

  validates :value, presence: true
  validates :unit, inclusion: { in: %w[C F K], message: "must be C, F, or K" }

  def to_s
    "#{value}° #{unit}"
  end
end
