
#!/usr/bin/env rake
# 默认是development环境，可以通过修改RACK_ENV的值改变环境，如:
# RACK_ENV=production rake db:test

require File.expand_path('config/boot', __dir__)

namespace :db do

  require 'active_record'

  task(:environment) do
    environment = Sinarey.env
    @dbconfig = Sinarey.dbyml[environment]
  end

  desc "create the database"
  task(:create => :environment) do
    dbconfig = @dbconfig.dup.merge('database'=>nil)
    ActiveRecord::Base.establish_connection(dbconfig)
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Base.connection.create_database @dbconfig['database'],encoding:'utf8'
  end

  desc "Migrate the database"
  task(:migrate => :environment) do
    ActiveRecord::Base.establish_connection(@dbconfig)
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate("db/migrate")
  end

end