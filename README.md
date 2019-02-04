# Bring up infrastructure

`docker-compose up -d`

# Generate historical data

Ensure ruby is installed https://www.ruby-lang.org/en/downloads/

## Install gems
`bundle install --path vendor/path`

## Generate data
`bundle exec ruby load_historical_data.rb`


## Call service

http://localhost:4567/getGender/769c82c0-9202-41fb-b21e-6c9e5ef14c10