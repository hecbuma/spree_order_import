module Spree
  Order.class_eval do
    include Checkout

    def create_proposed_shipments
      unless from_csv
        super
      end
    end

  end
end