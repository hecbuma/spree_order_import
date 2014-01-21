class CreateSpreeCsvOrders < ActiveRecord::Migration
  def change
    create_table :spree_csv_orders do |t|
      t.attachment :file
      t.string :name
      t.string :state
      t.string :orders_number

      t.timestamps
    end
  end
end
