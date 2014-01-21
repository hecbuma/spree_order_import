module Spree
  module Admin
    class CsvOrdersController < BaseController

      def index
        search = Spree::CsvOrder.accessible_by(current_ability, :index).ransack(params[:q])
        @csv_list = search.result(distinct: true)
        @csv_list = Spree::CsvOrder.page(params[:page] || 1).per(params[:per_page] || Spree::Config[:orders_per_page])
      end

      def create
        @csv_order = Spree::CsvOrder.new file: params[:csv_file], name: params[:csv_file].original_filename
        if @csv_order.save
          message = { notice: "Your orders will be procesed soon, and you will notified by Email."}
          redirect_to :back, flash: { notice: message[:notice], alert: message[:error]}
        else
          render :index
        end
      end


    end
  end
end

