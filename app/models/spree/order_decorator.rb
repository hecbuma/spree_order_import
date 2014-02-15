module Spree
  Order.class_eval do

    attr_accessor :from_csv

    def create_proposed_shipments
      unless from_csv
        super
      end
    end

    def deliver_order_confirmation_email
      unless from_csv
        begin
          OrderMailer.confirm_email(self.id).deliver
          rescue Exception => e
            logger.error("#{e.class.name}: #{e.message}")
            logger.error(e.backtrace * "\n")
        end
      end
    end

  end
end
