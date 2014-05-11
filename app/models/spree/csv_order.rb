class Spree::CsvOrder < ActiveRecord::Base
  require 'csv'


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
    errors = {}
    self.transaction do
      begin
        ::CSV.foreach(open_file,{:headers => true}) do |row|

          next if Spree::Order.where(:number => row["Order Number"]).first
          #order info
          order = Spree::Order.new number: row["Order Number"]
          if row["B2B/B2C"].blank?
            order.customer_group = "B2C"
          else
            order.customer_group = row["B2B/B2C"]
          end
          order.po_number = row["Customer PO Number"]
          order.carrier_account_number = row["Customer Shipping Account"]
          order.sop_code = row["SOP CODE"]
          if row["Gift Wrap"] == "No" || row["Gift Wrap"].blank?
            order.gift_wrap = false
          else
            order.gift_wrap = true
          end
          3.times do |i|
            special_intruction_x = "Special Instruction #{i+1}"
            order.special_instructions << row[special_intruction_x]
          end
          order.through_admin = true
          order.group_shipment = true
          order.from_csv = true
          order.save

          user = Spree.user_class.where(:email => row['Email'])
          # user_group_id = Spree::UserGroup.find_by_name(row["Customer type"]).id if row["Customer type"] != "DRTC:LBT"
          bill_country_id = Spree::Country.find_by_name(row["Billing Country"]).id
          bill_state_id = Spree::State.find_by_name(row["Billing State"]).id
          ship_country_id = Spree::Country.find_by_name(row["Shipping Country"]).id
          ship_state_id = Spree::State.find_by_name(row["Shipping State"]).id
          ship_phone = row['Shipping Phone Extension'].blank? ? "#{row['Shipping Phone']}x#{row['Shipping Phone Extension']}" : row['Shipping Phone']
          bill_phone = row['Billing Phone Extension'].blank? ? "#{row['Billing Phone']}x#{row['Billing Phone Extension']}" : row['Billing Phone']
          user_details = {"email"=> row["Email"], "bill_address_attributes"=>{"firstname"=> row["Billing First Name"],
                                                                             "lastname"=> row["Billing Last Name"],
                                                                             "company"=> row["Order Company Name"],
                                                                             "address1"=> row["Billing Address1"],
                                                                             "address2"=> row["Billing Address2"],
                                                                             "city"=> row["Billing City"], "zipcode"=>row["Billing ZIP"],
                                                                             "country_id"=> bill_country_id, "state_id"=> bill_state_id,
                                                                             "phone"=> bill_phone},
                                                  "ship_address_attributes"=>{"firstname"=> row["Shipping First Name"],
                                                                             "lastname"=> row["Shipping Last Name"],
                                                                             "company"=> row["Order Company Name"],
                                                                             "address1"=> row["Shipping Address1"],
                                                                             "address2"=> row["Shipping Address2"],
                                                                             "city"=> row["Shipping City"], "zipcode"=>row["Shipping ZIP"],
                                                                             "country_id"=> ship_country_id, "state_id"=> ship_state_id,
                                                                             "phone"=> ship_phone },
                                                  "customer_type" => row["Customer type"] }

          #Assing Variants
          ::CSV.foreach(open_file2,{:headers => true}) do |row_clon|
            if row_clon["Order Number"] == row["Order Number"]
              #Create Shippment
              stock_location_id = Spree::StockLocation.find_by_name(row["Stock Location"]).id

              shipments = order.shipments.find_all_by_number(row_clon["Shipment Number"])
              if shipments.blank?
                shipment = order.shipments.create(:number => row_clon['Shipment Number'], :stock_location_id => stock_location_id)
              else
                shipment = shipments.first
              end

              variant = Spree::Variant.find_by_sku(row_clon["SKU"])
              quantity = row_clon["Number of Items"].to_i
              order.contents.add(variant, quantity, nil, shipment)

              if !row_clon['Item Unit Price'].blank? || !row_clon['Discount Level'].blank?
                if !row_clon['Item Unit Price'].blank? && !row_clon['Discount Level'].blank?
                  price = row_clon['Item Unit Price'].to_f * (100 - row_clon['Discount Level'].gsub('%','').to_f)/100
                elsif row_clon['Item Unit Price'].blank?
                  price = order.line_items.last.price * (100 - row_clon['Discount Level'].gsub('%','').to_f)/100
                else
                  price = row_clon['Item Unit Price'].to_f
                end

                ln = order.line_items.last
                ln.price = price
                ln.save
              end

              shipment.refresh_rates
              shipment.custom_name = row_clon['Shipping Method']
              shipment.save!
            end
          end


          #Set customer details
          order.update_attributes(user_details)
          order.associate_user!(user.first) unless user.empty?

          order.save!
          order.refresh_shipment_rates

          current_shipments = {}
          current_custom_names = {}
          order.shipments.each {|s| current_shipments["#{s.number}"] = s.inventory_units.map(&:variant_id).uniq }
          order.shipments.each {|s| current_custom_names["#{s.number}"] = s.custom_name }

          until order.payment?
            order.next
          end

          new_shipments = order.shipments
          current_shipments.each_pair do |key, value|
            new_shipments.each do |new_shipment|
              if value == new_shipment.inventory_units.map(&:variant_id).uniq
                new_shipment.custom_name = current_custom_names[key]
                new_shipment.number = key
                new_shipment.save
              end
            end
          end

          unless row["Tax Exempt"].blank? || row["Tax Exempt"] == "TRUE"
            tax_adjustment = order.adjustments.new
            tax_adjustment.label = "Tax"
            tax_adjustment.source_type = "Spree::TaxRate"
            tax_adjustment.amount = 0
            tax_adjustment.save
          end

          #Assing correct shippiment cost
          ::CSV.foreach(open_file2,{:headers => true}) do |row_clon|
            if row_clon["Order Number"] == row["Order Number"]
              unless row_clon["Shipping Cost"].blank? || row_clon["Shipping Cost"] == "0"
                shipment = order.shipments.find_by_number(row_clon['Shipment Number'])
                if shipment
                    shipment.refresh_rates
                    shipment.save
                    shipment.cost  = row_clon["Shipping Cost"].to_f
                    shipment.save
                end
              end
            end
          end



          unless row["No Charge Code"].blank?
            order.adjustments.tax.destroy_all
            order.line_item_adjustments.where(source_type: 'Spree::TaxRate').destroy_all
            order.update_totals
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

          order.customer_type = row["Customer type"]
          until order.completed?
            order.next!
          end

          order.touch
          order.update!

          orders << order
        end
      rescue => e
        orders = []
        self.error!
        message = ""
        message << e.message
        message << e.backtrace.join("\n")
        errors[:error] = message
        raise ActiveRecord::Rollback
      end
    end
    self.finish! if errors.empty?
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
      ['Order Number', 'Shipment Number', 'Email', 'Billing First Name', 'Billing Last Name',
      'Billing Address1', 'Billing City','Billing ZIP',
      'Billing Country','Billing Phone', 'Shipping Method', 'Shipping First Name',
      'Shipping Last Name', 'Shipping Address1', 'Shipping City',
      'Shipping Country', 'Shipping Phone', 'Shipping ZIP',
      'Payment Method', 'Shipping Method', 'SKU', 'Number of Items',
      'Customer type', 'Stock Location'].each do |header|
        message["row #{$.}"] << "#{header} is blank" if row[header].blank?
        orders_number_list << row["Order Number"]
      end

      if Spree::Order.where(:number => row['Order Number']).first && !row['Order Number'].blank?
        message["row #{$.}"] << "Order Number: #{row['Order Number']} is already taken."
      end

      if Spree::Shipment.where(:number => row['Shipment Number']).first && !row['Shipment Number'].blank?
        message["row #{$.}"] << "Shipment Number: #{row['Shipment Number']} is already taken."
      end
      
      if Spree::Variant.where(:sku => row["SKU"]).blank? && !row['SKU'].blank?
        message["row #{$.}"] << "We couldn't find any Variant with this SKU: #{row['SKU']}."
      end

      ship_country =  Spree::Country.where(:name => row['Shipping Country'])
      message["row #{$.}"] << "we couldn't find this shipping country: #{row['Shipping Country']}" if ship_country.empty?
      if row['Shipping Country'] =~ /^United States$|^Canada$/
        if row['Shipping State'].blank?
           message["row #{$.}"] << "#{row['Shipping State']} is blank"
        else
          ship_state =  Spree::State.where(:name => row['Shipping State'])
          message["row #{$.}"] << "we couldn't find this shipping state: #{row['Shipping State']}" if ship_state.empty?
        end
      end

      bill_country =  Spree::Country.where(:name => row['Billing Country'])
      message["row #{$.}"] << "we couldn't find this billing country: #{row['Billing Country']}" if bill_country.empty?
      if row['Billing Country'] =~ /^United States$|^Canada$/
        if row['Billing State'].blank?
           message["row #{$.}"] << "#{row['Billing State']} is blank"
        else
          bill_state =  Spree::State.where(:name => row['Billing State'])
          message["row #{$.}"] << "we couldn't find this billing state: #{row['Billing State']}" if bill_state.empty?
        end
      end

      ['Billing', 'Shipping'].each do |head|
        if row["#{head} Country"] =~ /^United States$/
          message["row #{$.}"] << "#{head} ZIP: #{row['#{head} ZIP']} has an incorrect format" unless row["#{head} ZIP"] =~ /^\d{5}(-\d{4})?$/
          unless row["#{head} Phone"].blank?
             message["row #{$.}"] << "US #{head} Phone only acepts 10 digits: #{row['#{head} Phone']}" if row["#{head} Phone"].scan(/\d/).count > 10
             message["row #{$.}"] << "#{head} Phone must have a valid US format: #{row['#{head} Phone']}" unless row["#{head} Phone"] =~ /^[-+()\/\s\d]+$/
             unless row["#{head} Phone Extension"].blank?
               message["row #{$.}"] << "#{head} Phone Extension only accepts 9 digits: #{row['#{head} Phone Extension']}" if row["#{head} Phone Extension"].scan(/\d/).count > 9
            end
          end
        else
          unless row["#{head} Phone"].blank?
             message["row #{$.}"] << "#{head} Phone must have a valid US format: #{row['#{head} Phone']}" unless row["#{head} Phone"] =~ /^[-+()\/\s\d]+$/
          end
        end
        unless row["#{head} City"].blank?
          val = row["#{head} City"]
          message["row #{$.}"] << "#{head} City only accepts 20 chars: #{val}" unless val =~ /^[\w\s+]{,20}$/
        end

        ['First Name', 'Last Name', 'Address1'].each do |field|
          value = "#{head} #{field}"
          unless row[value].blank?
            message["row #{$.}"] << "#{value} only aloud 35 chars: #{row[value]}" unless row[value] =~ /^[\w\s+]{,35}$/
          end
        end
      end


      message["row #{$.}"] << "Payment Method must be PO or No Charge" unless row["Payment Method"] =~ /^Purchase Order$|^No Charge$/

      if row["Payment Method"] == "Purchase Order" && row["Purchase Order Number"].blank?
        message["row #{$.}"] << "Purchase Order Number must not be blank"
      end
      if row["Payment Method"] == "No Charge" && row["No Charge Code"].blank?
        message["row #{$.}"] << "No Charge Code must not be blank"
      end

      unless row['Customer type'].blank?
        message["row #{$.}"] << "we couldn't find this user group: #{row['Customer type']}" if !Spree::Order.customer_types.include?(row["Customer type"]) && row["Customer type"] != "DRTC:LBT"
      end

      ['Order Number', 'Shipment Number'].each do |field|
        unless row[field].blank?
          message["row #{$.}"] << "#{field} must be an 4 to 15 alphanumeric value: #{row[field]}" unless row[field] =~ /^[\w+]{4,15}$/
        end
      end

      unless row['Stock Location'].blank?
        stock = Spree::StockLocation.where(:name => row["Stock Location"])
        message["row #{$.}"] << "we couldn't find this stock location: #{row['Stock Location']}" if stock.empty?
      end

      if !row['Item Unit Price'].blank? && !row['Discount Level'].blank?
        message["row #{$.}"] << "WARNING: you're setting a discount level and a item unit price, this may cause unintended consequences and we recommend setting only one."
      end

      self.orders_number = orders_number_list.uniq.count
      unless message["row #{$.}"].empty?
        error_list = message["row #{$.}"].join("<br/>")
        errors_msg << "<b>Order:#{row['Order Number']} row #{$.}:</b><br/> #{error_list}"
      end
    end
    unless errors_msg.empty?
      errors.add :file, errors_msg.join("<br/><br/>")
    end

  end

end
