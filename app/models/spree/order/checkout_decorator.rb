module Spree
  Order.class_eval do
    include Checkout

    alias_method :original_create_proposed_shipments, :create_proposed_shipments

    def create_proposed_shipments
      unless from_csv
        original_create_proposed_shipments
      end
    end

  end
end