class CsvOrdersMailer < ActionMailer::Base
  layout 'mailers/base'
  default from: "'Team littleBits' <info@littlebits.cc>"

  def notify_admin_email(orders, file)
    @csv_order = file
    @orders = orders
    subject = "Orders from CSV file: #{@csv_order.name}"
    mail(:to => "webops@littlebits.cc", :subject => subject)
  end
end


