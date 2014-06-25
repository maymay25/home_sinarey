def new_thrift_clients!
  $counter_client = Stat::Count::Client::ThriftStatCountClient.new(Settings.thrift.counter_service)

  $discover_client = ThriftClient.new(Settings.thrift.discover_service)

  $feed_client = ThriftClient.new(Settings.thrift.feed)

  $login_client = ThriftClient.new(Settings.thrift.login_service)

  $recommend2_client = ThriftClient.new(Settings.thrift.recommend2_service)

  $remote_profile_client = ThriftClient.new(Settings.thrift.remote_profile_service)

  $stat_user_track_client = ThriftClient.new(Settings.thrift.stat_user_track_service)

  $sync_set_client = ThriftClient.new(Settings.thrift.sync_set_service)

  $wordfilter_client = ThriftClient.new(Settings.thrift.wordfilter_service)

  $recommend_client = ThriftClient.new(Settings.thrift.recommend_service)

  $backend_client = ThriftClient.new(Settings.thrift.backend_service)

  $profile_client = ThriftClient.new(Settings.thrift.profile_service)
end

new_thrift_clients!