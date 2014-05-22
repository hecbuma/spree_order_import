class OrderWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :bulkorders, :retry => false, :backtrace => true


  def perform(csv_order_id, order)
    csv_order = Spree::CsvOrder.find(csv_order_id)
    csv_order.process_order(order)
  end
end
