# Bring up infrastructure

`docker-compose up -d`

# Generate historical data

Ensure ruby is installed https://www.ruby-lang.org/en/downloads/

Install gems:
`bundle install --path vendor/path`

Generate data:
`bundle exec ruby load_historical_data.rb`