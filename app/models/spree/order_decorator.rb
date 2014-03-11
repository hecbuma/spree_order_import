module Spree
  Order.class_eval do

    attr_accessor :from_csv


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
