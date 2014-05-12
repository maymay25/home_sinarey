
def establish_connection!
  ActiveRecord::Base.default_timezone = :local
  ActiveRecord::Base.establish_connection(Settings.web)
end

establish_connection!