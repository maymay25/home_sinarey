Encoding.default_internal='utf-8'
Encoding.default_external='utf-8'

require File.expand_path('boot', __dir__)

require 'active_record'

require 'sinarey_support'
require 'sinarey_support/sinatra/html_safe' unless ENV['DEFAULT_ERB']

require "sinatra/multi_route"
require "sinatra/content_for"
require "sinatra/cookies"

#load core
require File.join(Sinarey.core_root, 'config/initializers')
Dir[ File.join(Sinarey.core_root, 'app/models/*.rb') ].each{|file| require file }

require File.join(Sinarey.core_root, 'app/helpers/inet.rb')
require File.join(Sinarey.core_root, 'app/helpers/core_helper.rb')
require File.join(Sinarey.core_root, 'app/helpers/apn_dispatch_helper.rb')
require File.join(Sinarey.core_root, 'app/helpers/search_helper.rb')

require File.expand_path('establish_connection.rb', __dir__)

require File.expand_path('sinarey', __dir__)

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

