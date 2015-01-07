Spree::ShippingMethod.class_eval do
  validates :unique_identifier, uniqueness: true
end
