
sidekiq_url = "redis://:#{Settings['redis']['password']}@#{Settings['redis']['host']}:#{Settings['redis']['port']}/#{Settings['redis']['db']}"
Sidekiq.configure_server do |config|
  config.redis = { :namespace => 'sidekiq', :url => sidekiq_url }
end
Sidekiq.configure_client do |config|
  config.redis = { :namespace => 'sidekiq', :url => sidekiq_url }
end
