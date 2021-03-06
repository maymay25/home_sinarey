Encoding.default_internal='utf-8'
Encoding.default_external='utf-8'

require File.expand_path('boot', __dir__)

require 'sinarey_support'
require 'sinarey_support/sinatra/html_safe'

require "sinatra/multi_route"
require "sinatra/content_for"
require "sinatra/cookies"

#load core
require File.join(Sinarey.core_root, 'config/settings.rb')
require File.join(Sinarey.core_root, 'config/initializers')

require File.join(Sinarey.core_root, 'app/helpers/inet.rb')
require File.join(Sinarey.core_root, 'app/helpers/core_helper.rb')
require File.join(Sinarey.core_root, 'app/helpers/apn_dispatch_helper.rb')
require File.join(Sinarey.core_root, 'app/helpers/search_helper.rb')


require File.expand_path('sinarey', __dir__)

#initializers里的 xunch 依赖 activerecord 的连接，否则会报错，所以这里优先establish_connection
require File.expand_path('establish_connection.rb', __dir__)

requires = Dir[File.expand_path('initializers/*.rb', __dir__)]

['models','helpers','controllers','routes'].each do |path|
  requires += Dir[File.expand_path("../app/#{path}/*.rb", __dir__)]
end

requires.each do |file|
  require file
end

require 'sinarey/router'
HomeRouter = Sinarey::Router.new do
  mount MainRoute
  mount ExploreRoute
  mount CenterRoute
  mount TracksRoute
  mount AlbumsRoute
  mount MsgcenterRoute
  mount TagsRoute
  mount FollowRoute
  mount PersonalSettingsRoute
  mount DelayedUploadTasksRoute
  mount WelcomeRoute
  mount XposterRoute
  notfound NotFoundRoute
end

