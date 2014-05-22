class CsvOrdersMailer < ActionMailer::Base
  layout 'mailers/fancy_layout'
  default from: "'Team littleBits' <info@littlebits.cc>"

  def notify_admin_email(file, errors)
    @csv_order = file
    @orders = Spree::Order.where(number: file.orders)
    @errors = errors
    subject = "Orders from CSV file: #{@csv_order.name}"
    mail(:to => @csv_order.user.email, :cc => "h.bustillos@heroint.com", :subject => subject)
  end
end


