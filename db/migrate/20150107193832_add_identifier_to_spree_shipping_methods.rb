class AddIdentifierToSpreeShippingMethods < ActiveRecord::Migration
  def change
    add_column :spree_shipping_methods, :unique_identifier, :string
  end
end
