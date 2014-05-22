class AddOrdersListsToSpreeCsvOrders < ActiveRecord::Migration
  def change
    add_column :spree_csv_orders, :orders, :text
    add_column :spree_csv_orders, :completed, :text
    add_column :spree_csv_orders, :failed, :text
  end
end
