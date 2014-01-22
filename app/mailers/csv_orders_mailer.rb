class CsvOrdersMailer < ActionMailer::Base
  default from: "'Team littleBits' <info@littlebits.cc>"

  def notify_admin_email(orders, file, errors)
    @csv_order = file
    @orders = orders
    @errors = errors
    subject = "Orders from CSV file: #{@csv_order.name}"
    mail(:to => "webops@littlebits.cc", :cc => "h.bustillos@heroint.com", :subject => subject)
  end
end


