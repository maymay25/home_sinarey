
sidekiq_url = "redis://:#{Settings['redis']['password']}@#{Settings['redis']['host']}:#{Settings['redis']['port']}/#{Settings['redis']['db']}"

Sidekiq.configure_server do |config|
  config.redis = { namespace: 'home_sidekiq', size:5, url: sidekiq_url }
end

Sidekiq.configure_client do |config|
  config.redis = { namespace: 'home_sidekiq', size:2, url: sidekiq_url }
end
