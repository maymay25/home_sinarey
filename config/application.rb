Encoding.default_internal='utf-8'
Encoding.default_external='utf-8'

require File.expand_path('boot', __dir__)

require File.expand_path('sinarey', __dir__)

requires = Dir[File.expand_path('initializers/*.rb', __dir__)]
['app/models','app/helpers','app/controllers','app/routes'].each do |path|
  requires += Dir[File.expand_path("../#{path}/*.rb", __dir__)]
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
  notfound NotFoundRoute
end

