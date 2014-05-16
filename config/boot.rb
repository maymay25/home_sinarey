require 'yaml'
require 'logger'

module Sinarey

  @root = File.expand_path('..', __dir__)
  @env = ENV['RACK_ENV'] || 'development'

  if @env=='production'
    @secret = File.open(@root+'/config/production/secret').readline.chomp
    @core_root = File.open(File.join(@root, '/config/production/core.root')).readline.chomp
  else
    @secret = File.open(@root+'/config/secret').readline.chomp
    @core_root = File.open(File.join(@root, '/config/core.root')).readline.chomp
  end
  @session_key = 'rack.session'

  class << self
    attr_reader :root,:secret,:session_key,:core_root
    attr_accessor :env
  end
  
end


require 'bundler'

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

Bundler.require(:default, Sinarey.env)

