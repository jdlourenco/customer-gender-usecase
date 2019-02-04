require 'securerandom'

require 'elasticsearch'

CONNECT_RETRIES     = 10
CONNECT_RETRY_DELAY = 10
MAX_BULK_SIZE       = 1_000
INDEX_PREFIX        = 'pagegender'

NCLIENTS            = 25_000
MAX_HITS_PER_CLIENT = 10
NDAYS               = 30

GENDERS = %w{M F}

def connect_es
	es_client = nil

	CONNECT_RETRIES.times do |i|
		puts "Attempting to connect to elasticsearch cluster..."
		begin
			es_client = Elasticsearch::Client.new log: true
			es_client.cluster.health
		rescue Exception => ex
			puts "elasticsearch cluster is still booting retrying in #{CONNECT_RETRY_DELAY}s..."
			sleep CONNECT_RETRY_DELAY
			next
		end

		break
	end

	es_client
end

def put_template es_client

	es_client.indices.put_template name: 'pagegender', body: {
		index_patterns: ["pagegender-*"],
  	settings: {
    	number_of_shards: 3
  	},
  	aliases: {
    	"pagegender-read": {}
    },
  	mappings: {
    	_doc: {
      	_source: {
        	enabled: true
      	},
      	properties: {
	        pageGender: {
	          type: "keyword"
	        },
	        clientId: {
	          type: "keyword"
	        },
	        ts: {
	          type: "date"
	        }
	      }
	    }
	  }
	}
end

es_client = connect_es
put_template es_client



bulk    = []

NDAYS.times do |i|

	ts_date = (Date.today - i).to_time

	client_id = nil
	NCLIENTS.times do |i|

		client_id = client_id ? SecureRandom.uuid : '769c82c0-9202-41fb-b21e-6c9e5ef14c10'

		puts client_id

		rand(0..MAX_HITS_PER_CLIENT).times do |hit|
			doc = {
				index: {
					_index: "#{INDEX_PREFIX}-#{ts_date.strftime("%Y.%m.%d")}",
					_type:  '_doc',
					data: {
						pageGender: GENDERS.sample,
						clientId:   client_id,
						ts:         (ts_date + rand(24*60*60)).strftime("%Y-%m-%dT%H:%M:%S.%LZ")
					}
				}
			}

			bulk << doc

			if bulk.size == MAX_BULK_SIZE
				es_client.bulk body: bulk

				bulk = []
			end

		end
	end
end

if bulk.any?
	es_client.bulk body: bulk

	bulk = []
end
