FactoryGirl.define do
  factory :custom_base_variant, class: Spree::Variant do
    price 19.99
    cost_price 17.00
    sku    'LB-BIT-p2-COINBATTERY-v03'
    weight { generate(:random_float) }
    height { generate(:random_float) }
    width  { generate(:random_float) }
    depth  { generate(:random_float) }
    is_master 0
    track_inventory true

    product { |p| p.association(:base_product) }
    option_values { [create(:option_value)] }

    # ensure stock item will be created for this variant
    before(:create) { create(:stock_location) if Spree::StockLocation.count == 0 }

  end
end