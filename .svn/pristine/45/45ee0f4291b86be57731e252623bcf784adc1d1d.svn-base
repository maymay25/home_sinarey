
def establish_connection!
  ActiveRecord::Base.default_timezone = :local
  ActiveRecord::Base.establish_connection(Settings.web)
  # if ENV['RACK_ENV']='development'
  #   ActiveRecord::Base.logger = Logger.new(STDOUT)
  # end
end

establish_connection!