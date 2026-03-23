RUNTIME=ruby
VERSION=recommended
MEMORY=1024
SUBDOMAIN=fish_track
START=/bin/bash -c "chmod 700 ./db/certs && chmod 600 ./db/certs/private_key.key && rm -f /application/tmp/pids/server.pid && bundle exec rails assets:precompile && bundle exec rails db:migrate && bundle exec rails s -b 0.0.0.0 -p ${PORT:-3000}"
SQUARE_BLOB_UPLOAD_URL=https://public-blob.squarecloud.dev
SQUARECLOUD_API_KEY=85652c0fe619b746ea4ea0bafcc00da17d8601f4-14768d1db5d2d323945f9234abc7d646252fffb4f44f619691c29ef002fb52cb
