require 'spec_helper'

describe Spree::CsvOrder do

  context "validate file" do
    let!(:varinat) {create(:custom_base_variant)}
    let(:file) {File.open("./spec/csv_order_files/fields-validation.csv")}
    let(:csv_order) {Spree::CsvOrder.new(file: file, name: 'errors', user_id: "1")}

    before do
      eu = Spree::Country.create(:name => 'United States', :iso_name => 'EU')
      ca = Spree::Country.create(:name => 'Canada', :iso_name => 'CA')
      alberta = Spree::State.new(:name => 'Alberta')
      alberta.country = ca
      california = Spree::State.new(:name => 'California')
      california.country = eu
      Spree::StockLocation.create(:name => 'PCH')
      csv_order.save
    end

    it "should validate Order number" do
      csv_order.errors.messages[:file].first.should include("Order Number must be an 4 to 15 alphanumeric value: R12")
      csv_order.errors.messages[:file].first.should include("Order Number must be an 4 to 15 alphanumeric value: R12345678901234567")
    end
    it "should validate Email presence" do
      csv_order.errors.messages[:file].first.should include("Email is blank")
    end
    it "should validate Billing first name presence" do
      csv_order.errors.messages[:file].first.should include("Billing First Name is blank")
    end
    it "should validate Billing Last Name presence" do
      csv_order.errors.messages[:file].first.should include("Billing Last Name is blank")
    end
    it "should validate Billing Address1 presence" do
      csv_order.errors.messages[:file].first.should include("Billing Address1 is blank")
    end
    it "should validate Billing City presence" do
      csv_order.errors.messages[:file].first.should include("Billing City is blank")
    end
    it "should validate Shipping Method presence" do
      csv_order.errors.messages[:file].first.should include("Shipping Method is blank")
    end
    it "should validate Shipping First Name presence" do
      csv_order.errors.messages[:file].first.should include("Shipping First Name is blank")
    end
    it "should validate Shipping Last Name presence" do
      csv_order.errors.messages[:file].first.should include("Shipping Last Name is blank")
    end
    it "should validate Shipping Address1 presence" do
      csv_order.errors.messages[:file].first.should include("Shipping Address1 is blank")
    end
    it "should validate Shipping City presence" do
      csv_order.errors.messages[:file].first.should include("Shipping City is blank")
    end
    it "should validate Shipping ZIP presence" do
      csv_order.errors.messages[:file].first.should include("Shipping ZIP is blank")
    end
    it "should validate SKU presence" do
      csv_order.errors.messages[:file].first.should include("SKU is blank")
    end
    it "should validate Number of Items presence" do
      csv_order.errors.messages[:file].first.should include("Number of Items is blank")
    end
    it "should validate Customer types presence" do
      csv_order.errors.messages[:file].first.should include("Customer type is blank")
    end
    it "should validate Stock Location presence" do
      csv_order.errors.messages[:file].first.should include("Stock Location is blank")
    end
    it "should validate Shipping Country should be valid" do
      csv_order.errors.messages[:file].first.should include("we couldn't find this shipping country: Mexico")
    end
    it "should validate Billing Country should be valid" do
      csv_order.errors.messages[:file].first.should include("we couldn't find this billing country: Mexico")
    end
    it "should validate Payment method should be valid" do
      csv_order.errors.messages[:file].first.should include("Payment Method must be PO or No Charge<")
    end
    it "should validate Shipment Number integrity" do
      csv_order.errors.messages[:file].first.should include("Shipment Number must be an 4 to 15 alphanumeric value: H12")
    end
    it "should validate Shipment Number integrity" do
      csv_order.errors.messages[:file].first.should include("Shipment Number must be an 4 to 15 alphanumeric value: H12345678901234567")
    end
    it "should validate SKU actually exists" do
      csv_order.errors.messages[:file].first.should include("We couldn't find any Variant with this SKU: 650-0121.")
    end
    it "should validate Billing City length" do
      csv_order.errors.messages[:file].first.should include("Billing City only accepts 20 chars: Glendale again I need to check the length of this fields")
    end
    it "should validate Billing last name length" do
      csv_order.errors.messages[:file].first.should include("Billing Last Name only aloud 35 chars: Houghtonsuperlongnamewithsomeextrachars")
    end
    it "should validate Billing address1 length" do
      csv_order.errors.messages[:file].first.should include("Billing Address1 only aloud 35 chars: 1101 Flower Street again I need to check the length of this fields")
    end
    it "should validate Shipping City length" do
      csv_order.errors.messages[:file].first.should include("Shipping City only accepts 20 chars: Edmonton long edmonton just 20 chars aloud")
    end
    it "should validate Shipping First Name length" do
      csv_order.errors.messages[:file].first.should include("Shipping First Name only aloud 35 chars: Hector again I need a super long field validation just to be sure this is correct")
    end
    it "should validate Shipping Last Name length" do
      csv_order.errors.messages[:file].first.should include("Shipping Last Name only aloud 35 chars: Bustillos again I need a super long field validation just to be sure this is correct")
    end
    it "should validate Shipping Address1 length" do
      csv_order.errors.messages[:file].first.should include("Shipping Address1 only aloud 35 chars: 1101 Flower Street this damm long again and it should be shorter")
    end
    it "should validate No Charge Code presence " do
      csv_order.errors.messages[:file].first.should include("No Charge Code must not be blank")
    end
    it "should validate Customer Type actually exits" do
      csv_order.errors.messages[:file].first.should include("we couldn't find this user group: LTB:WHLS")
    end
    it "should validate Stock Location actually exits" do
      csv_order.errors.messages[:file].first.should include("we couldn't find this stock location: NYC")
    end
    it "should validate that item price and discount level can't be setted at the same time" do
      csv_order.errors.messages[:file].first.should include("WARNING: you're setting a discount level and a item unit price, this may cause unintended consequences and we recommend setting only one.")
    end
    it "should check a valid sku" do
      csv_order.errors.messages[:file].first.should_not include('LB-BIT-p2-COINBATTERY-v03')
    end

  end

  context "create orders form CSV file" do

    it "should create 5 different orders"
    it "should maange gifr wrap correctly"
    it "should set custom shipping cost correctly"
    it "should be able to set multiple shipments for the same order"

  end

end