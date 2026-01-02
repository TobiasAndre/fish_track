RUNTIME=ruby
VERSION=recommended
MEMORY=1024
SUBDOMAIN=fish_track
START=/bin/bash -c "chmod 700 ./db/certs && chmod 600 ./db/certs/private_key.key && bundle exec rails assets:precompile && bundle exec rails db:migrate && bundle exec rails s -b 0.0.0.0 -p ${PORT:-3000}"