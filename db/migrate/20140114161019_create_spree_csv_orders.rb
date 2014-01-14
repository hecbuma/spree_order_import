class CreateSpreeCsvOrders < ActiveRecord::Migration
  def change
    create_table :spree_csv_orders do |t|
      t.string :path

      t.timestamps
    end
  end
end
