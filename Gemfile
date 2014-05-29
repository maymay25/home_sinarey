source 'http://ruby.taobao.org/'
source 'http://ruby.ximalaya.com/'

gem 'thin'

if RUBY_PLATFORM =~ /mingw/
  gem 'redis', '3.0.6'
else
  gem 'unicorn'
  gem 'hiredis', '~> 0.4.0'
  gem "redis", '>= 2.2.0', require: %w[ redis redis/connection/hiredis ]
end

gem 'sinarey'
gem 'sinarey_support',require: []

gem 'sinatra-contrib'

gem 'timerizer'

gem 'settingslogic'
gem 'oj'
gem "sanitize"

gem 'bunny' 

gem 'feed', '>= 0.0.2'

gem 'hessian2'

gem 'idservice_client'

gem 'will_paginate', '~> 3.0'

gem 'mysql2'

gem 'passport_thrift_client', '0.1.1'

gem 'profile_thrift_client', '0.0.1'

gem 'core_async', '1.0.0'

gem 'yajl-ruby', require: 'yajl'


gem 'thrift', '~> 0.9.0'

gem 'thrift-client'

gem 'stat-analysis-query', '0.0.7'

gem 'stat-count-client', '>=0.0.6'

gem 'wordfilter_client', '>=0.0.2'

gem 'xunch', '>=0.0.6'

#rake tasks
gem 'rake'
gem 'activerecord', '~> 3.2', require: []