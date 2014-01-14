class Spree::CsvOrder < ActiveRecord::Base
  attr_accessible :path


  def self.validate(file)
    begin
      open_file = File.open file
      CSV.foreach(open_file, {:headers => true, :header_converters => :symbol}) do |csv_obj|
        
      end
    rescue => e
      errors = {error: e.message}
    end
      message = errors ? errors : {notice: "Successfully imported"}
  end

  
end
