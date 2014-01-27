class AddUserToCsvOrders < ActiveRecord::Migration
  def change
    add_column :spree_csv_orders, :user_id, :integer
  end
end
