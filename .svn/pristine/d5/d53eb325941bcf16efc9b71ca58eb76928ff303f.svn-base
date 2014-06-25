

require "test/unit"
require "rack/test"

require File.expand_path('../config/application',__dir__)


class CachePerformanceTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    HomeRouter
  end

  def test_cache_performance

    #redis可能需要预热
    CMSREDIS.get(:abc)
    CMSREDIS.get(:abc)
    CMSREDIS.get(:abc)
    CMSREDIS.get(:abc)
    CMSREDIS.get(:abc)

    puts "\n"
    puts "test cache_file"
    t0 = Time.now
    get "/cache/file"
    t1 = Time.now
    puts (t1-t0)*1000.0

    puts "test cache_nil"
    t0 = Time.now
    get "/cache/nil"
    t1 = Time.now
    puts (t1-t0)*1000.0

    puts "test cache_redis"
    t0 = Time.now
    get "/cache/redis"
    t1 = Time.now
    puts (t1-t0)*1000.0


    puts "test redis get"
    t0 = Time.now
    CMSREDIS.get(:home_sinarey_cache)
    t1 = Time.now
    puts (t1-t0)*1000.0

    assert_equal 0, 0
  end

end