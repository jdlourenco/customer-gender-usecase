require 'sinatra'
require 'elasticsearch'

GENDER_INDEX = 'pagegender-read'

set :bind, '0.0.0.0'

es_client = Elasticsearch::Client.new host: ENV['ES_HOST'] || 'localhost'

get '/getGender/:clientId' do
	gender = get_gender es_client, params['clientId']

	content_type :json
	gender.to_json
end

def get_gender es_client, clientId
	last_gender_visited = get_last_gender_visited    es_client, clientId
	top_gender          = get_top_gender             es_client, clientId
	top_gender_7h       = get_top_gender_time_window es_client, clientId
	
	{
		clientId: clientId,
		details: {
			last_gender_visited: last_gender_visited,
			top_gender:          top_gender,
			top_gender_7h:       top_gender_7h
		}
	}
end

def get_last_gender_visited es_client, clientId
	res = es_client.search index: GENDER_INDEX, size: 1, body: {
		sort: [
			{ "ts": "desc" }
		],
		query: {
			term: {
				"clientId": clientId
			}
		}
	}

	first_hit = res['hits']['hits'].first

	if first_hit
		first_hit['_source']['pageGender']
	else
		nil
	end
end

def get_top_gender es_client, clientId
	res = es_client.search index: GENDER_INDEX, size: 0, body: {
		query: {
			term: {
				"clientId": clientId
			}
		},
		aggs: {
			genders: {
				terms: { field: "pageGender" }
			}
		}
	}

	if res['aggregations']['genders']['buckets'].any?
		get_max_gender_counts res['aggregations']['genders']['buckets']
	else
		nil
	end
end

def get_top_gender_time_window es_client, clientId, time_window = '7d'
	res = es_client.search index: GENDER_INDEX, size: 0, body: {
		query: {
			bool: {
				must: [
					{
						term: {
							"clientId": clientId
						}
					},
					{
						range: {
							"ts": {
								gte: "now-#{time_window}"
							}
						}
					}
				]
			}
		},
		aggs: {
			genders: {
				terms: { field: "pageGender" }
			}
		}
	}

	if res['aggregations']['genders']['buckets'].any?
		get_max_gender_counts res['aggregations']['genders']['buckets']
	else
		nil
	end
end

def get_max_gender_counts buckets
	buckets.sort_by {|bucket| -bucket['doc_count']}.first['key']
end
