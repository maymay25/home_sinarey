home_sinarey
=========

kill `cat /tmp/home.pid`

cd /srv/home && bundle exec unicorn -c /srv/home/unicorn.rb -D

kill -USR2 `cat /tmp/home.pid`

