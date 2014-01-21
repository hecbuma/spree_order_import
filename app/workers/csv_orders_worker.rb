class CsvOrdersWorker
  include Sidekiq::Worker

  def perform(csv_order_id)
    csv_order = Spree::CsvOrder.find(csv_order_id)
    csv_order.start_process
  end
end
