require 'yaml'
require 'logger'

$worker_nr ||= ''

p $worker_nr

module Sinarey

  @root = File.expand_path('..', __dir__)
  @env = ENV['RACK_ENV'] || 'development'
  
  @secret = File.open(@root+'/config/secret').readline.chomp
  @dblogger = ::Logger.new(@root+"/log/db/#{@env}#{$worker_nr}.log",'daily')
  @logger = ::Logger.new(@root+"/log/#{@env}#{$worker_nr}.log",'daily')
  @logger.level = Logger::INFO
  @core_root = File.open(File.join(@root, '/config/core.root')).readline.chomp

  @session_key = 'rack.session'

  class << self
    attr_reader :root,:secret,:logger,:dblogger,:session_key,:core_root
    attr_accessor :env
  end
  
end


require 'bundler'

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

Bundler.require(:default, Sinarey.env)

