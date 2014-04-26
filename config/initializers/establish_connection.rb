ActiveRecord::Base.default_timezone = :local
ActiveRecord::Base.establish_connection(Settings.web)
