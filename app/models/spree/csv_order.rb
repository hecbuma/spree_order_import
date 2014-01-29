class Spree::CsvOrder < ActiveRecord::Base
  require 'csv'

  attr_accessible :file, :name, :orders_number, :state, :user_id

  has_attached_file :file

  validate :presence_fields, :on => :create

  if Spree.user_class
    belongs_to :user, class_name: Spree.user_class.to_s
  else
    belongs_to :user
  end

  state_machine :state, :initial => :uploaded do
    event :process do
      transition [:uploaded, :errored] => :processing
    end

    event :error do
      transition :processing => :errored
    end

    event :finish do
      transition :processing => :done
    end
  end

  def start_process
    self.process!
    open_file = open_file2 = File.open file.path
    orders = []
    begin
      ::CSV.foreach(open_file,{:headers => true}) do |row|

        next if Spree::Order.where(:number => row["Order Number"]).first
        #order info
        order = Spree::Order.new number: row["Order Number"]
        order.customer_group = row["B2B/B2C"] unless row["B2B/B2C"].blank?
        order.po_number = row["Customer PO Number"]
        order.carrier_account_number = row["Customer UPS"]
        order.sop_code = row["SOP CODE"]
        order.gift_wrap = true unless row["Gift Wrap"].blank?
        5.times do |i|
          special_intruction_x = "Special Instruction #{i+1}"
          order.special_instructions << row[special_intruction_x]
        end
        order.save

        user = Spree.user_class.where(:email => row['Email'])
        # user_group_id = Spree::UserGroup.find_by_name(row["Customer type"]).id if row["Customer type"] != "DRTC:LBT"
        bill_country_id = Spree::Country.find_by_name(row["Billing Country"]).id
        bill_state_id = Spree::State.find_by_name(row["Billing State"]).id
        ship_country_id = Spree::Country.find_by_name(row["Shipping Country"]).id
        ship_state_id = Spree::State.find_by_name(row["Shipping State"]).id
        user_details = {"email"=> row["Email"], "bill_address_attributes"=>{"firstname"=> row["Order First Name"],
                                                                           "lastname"=> row["Order Last Name"],
                                                                           "company"=> row["Order Company Name"],
                                                                           "address1"=> row["Billing Address1"],
                                                                           "address2"=> row["Billing Address2"],
                                                                           "city"=> row["Billing City"], "zipcode"=>row["Billing ZIP"],
                                                                           "country_id"=> bill_country_id, "state_id"=> bill_state_id,
                                                                           "phone"=> row["Billing Phone"]},
                                                "ship_address_attributes"=>{"firstname"=> row["Order First Name"],
                                                                           "lastname"=> row["Order Last Name"],
                                                                           "company"=> row["Order Company Name"],
                                                                           "address1"=> row["Shipping Address1"],
                                                                           "address2"=> row["Shipping Address2"],
                                                                           "city"=> row["Shipping City"], "zipcode"=>row["Shipping ZIP"],
                                                                           "country_id"=> ship_country_id, "state_id"=> ship_state_id,
                                                                           "phone"=> row["Shipping Phone"]},
                                                "customer_type" => row["Customer type"] }

        #Create Shippment
        stock_location_id = Spree::StockLocation.find_by_name(row["Fulfilled From"]).id
        shipment = order.shipments.create(:number => row['Shipment Number'], :stock_location_id => stock_location_id)

        #Assing Variants
        ::CSV.foreach(open_file2,{:headers => true}) do |row_clon|
          if row_clon["Order Number"] == row["Order Number"]
            variant = Spree::Variant.find_by_sku(row_clon["Sku"])
            quantity = row_clon["Number of Items"].to_i
            order.contents.add(variant, quantity, nil, shipment)
          end
        end

        shipment.refresh_rates
        shipment.save!

        #Set customer details
        order.update_attributes(user_details)
        order.associate_user!(user.first) unless user.empty?

        order.save!
        order.refresh_shipment_rates


        until order.payment?
          order.next
        end

        unless row["Tax"].blank? || row["Tax"] == "0"
          tax_adjustment = order.adjustments.new
          tax_adjustment.label = "Custom Tax"
          tax_adjustment.originator_type = "Spree::TaxRate"
          tax_adjustment.amount = row["Tax"].to_i
          tax_adjustment.save
        end

        unless row["Shipping Cost"].blank? || row["Shipping Cost"] == "0"
          order.adjustments.shipping.first.destroy
          shipping = order.adjustments.new
          shipping.label = "Custom Shipping`"
          shipping.originator_type = "Spree::ShippingMethod"
          shipping.amount = row["Shipping Cost"].to_i
          shipping.save
        end

        order.save

        #set Payment
        payment_method_id = Spree::PaymentMethod.find_by_name(row["Payment Method"]).id

        payment_data = {"amount"=> order.total.to_f, "payment_method_id"=> payment_method_id, 
                   "purchase_order_number"=> row["Purchase Order Number"], 
                   "no_charge_note"=> row["No Charge Note"], 
                   "no_charge_code"=> row["No Charge Code"]}
        payment = order.payments.build(payment_data)

        payment.save

        until order.completed?
          order.next!
        end

        orders << order
      end
    rescue => e
      self.error!
      errors = {error: e.message}
    end
      self.finish! unless errors
      ::CsvOrdersMailer.notify_admin_email(orders, self, errors).deliver
  end


  private
  def presence_fields
    open_file = File.open(file.queued_for_write[:original].path)
    errors_msg = []
    orders_number_list = []
    ::CSV.foreach(open_file, {:headers => true}) do |row|
      message = {}
      message["row #{$.}"] = []
      ['Order Number', 'Email', 'Order First Name', 'Order Last Name',
      'Billing Address1', 'Billing City', 'Billing State', 'Billing ZIP',
      'Billing Country','Billing Phone', 'Shipping Method', 'Shipping First Name',
      'Shipping Last Name', 'Shipping Address1', 'Shipping Address2', 'Shipping City',
      'Shipping State', 'Shipping ZIP', 'Shipping Country', 'Shipping Phone',
      'Payment Method', 'Tax', 'Shipping Cost', 'Sku', 'Item Name', 'Number of Items',
      'Item Unit Price', 'Customer type', 'Fulfilled From'].each do |header|
        message["row #{$.}"] << "#{header} is blank" if row[header].blank?
        orders_number_list << row["Order Number"]
      end

      if Spree::Order.where(:number => row['Order Number']).first && !row['Order Number'].blank?
        message["row #{$.}"] << "Order Number: #{row['Order Number']} is already taken."
      end

      unless Spree::Variant.where(:sku => row["Sku"]).first && !row['Sku'].blank?
        message["row #{$.}"] << "We couldn't find any Variant with this SKU: #{row['SKU']}."
      end

      ship_country =  Spree::Country.where(:name => row['Shipping Country'])
      ship_state =  Spree::State.where(:name => row['Shipping State'])
      bill_country =  Spree::Country.where(:name => row['Billing Country'])
      bill_state =  Spree::State.where(:name => row['Billing State'])

      message["row #{$.}"] << "we couldn't find this shipping state: #{row['Shipping State']}" if ship_country.empty?
      message["row #{$.}"] << "we couldn't find this shipping country: #{row['Shipping Country']}" if ship_state.empty?
      message["row #{$.}"] << "we couldn't find this billing state: #{row['Billing State']}" if bill_state.empty?
      message["row #{$.}"] << "we couldn't find this billing country: #{row['Billing Country']}" if bill_country.empty?

      message["row #{$.}"] << "Payment Method must be PO or No Charge" unless row["Payment Method"] =~ /^Purchase Order$|^No Charge$/

      if row["Payment Method"] == "Purchase Order" && row["Purchase Order Number"].blank?
        message["row #{$.}"] << "Purchase Order Number must not be blank"
      end
      if row["Payment Method"] == "No Charge" && row["No Charge Code"].blank?
        message["row #{$.}"] << "No Charge Code must not be blank"
      end

      unless row['Customer type'].blank?
        user_group = Spree::UserGroup.where(:name => row["Customer type"])
        message["row #{$.}"] << "we couldn't find this user group: #{row['Customer type']}" if user_group.blank? && row["Customer type"] != "DRTC:LBT"
      end


      self.orders_number = orders_number_list.uniq.count
      unless message["row #{$.}"].empty?
        error_list = message["row #{$.}"].join("<br/>")
        errors_msg << "<b>row #{$.}:</b><br/> #{error_list}"
      end
    end
    unless errors_msg.empty?
      errors.add :file, errors_msg.join("<br/><br/>")
    end

  end

end
