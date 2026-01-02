RUNTIME=ruby
VERSION=recommended
MEMORY=1024
SUBDOMAIN=fish_track
START=bundle exec rails db:migrate && rails server -b 0.0.0.0 -p $PORT