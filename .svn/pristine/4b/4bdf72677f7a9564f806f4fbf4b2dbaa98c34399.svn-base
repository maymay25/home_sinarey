# http://unicorn.bogomips.org/examples/unicorn.conf.rb

worker_processes 2

app = 'home'

# listen "/tmp/#{app}.ting.sock", :backlog => 64
listen 9059, tcp_nopush: true

timeout 30

app_root = File.expand_path('../..',__FILE__)

working_directory app_root

pid "/tmp/#{app}.pid"

stderr_path "#{@dir}log/unicorn.#{app}.log"
stdout_path "#{@dir}log/unicorn.#{app}.log"

preload_app true
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true

before_fork do |server, worker|

  defined?(ActiveRecord::Base) and 
    ActiveRecord::Base.connection.disconnect!

  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
  
  sleep 1
end

after_fork do |server, worker|

  defined?(REDIS) and
    REDIS.client.reconnect

  defined?(SidekiqRedis) and
    SidekiqRedis.client.reconnect

  defined?(RICKREDIS) and
    RICKREDIS.client.reconnect

  defined?(CMSREDIS) and
    CMSREDIS.client.reconnect

  new_bunny!
  new_thrift_clients!

  establish_connection!
  new_xunch!
end
