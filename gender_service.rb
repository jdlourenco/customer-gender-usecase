require 'sinatra'
require 'elasticsearch'

GENDER_INDEX = 'pagegender-read'

set :bind, '0.0.0.0'

es_client = Elasticsearch::Client.new host: ENV['ES_HOST'] || 'localhost'

get '/getGender/:clientId' do
	begin
		gender = get_gender es_client, params['clientId']
	rescue Exception => ex
		status 404
		body "#{params['clientId']} not found}"
	end

	content_type :json
	gender.to_json
end

WHEIGHTS = {
	last_gender_visited: 1.0,
	top_gender:          2.0,
	top_gender_7d:       3.0
}

def get_gender es_client, clientId
	last_gender_visited = get_last_gender_visited    es_client, clientId
	top_gender          = get_top_gender             es_client, clientId
	top_gender_7d       = get_top_gender_time_window es_client, clientId

	raise Exception.new unless last_gender_visited and top_gender and top_gender_7d

	gender = ([
		(last_gender_visited == 'M' ? 0 : 1) * WHEIGHTS[:last_gender_visited],
		(top_gender          == 'M' ? 0 : 1) * WHEIGHTS[:top_gender],
		(top_gender_7d       == 'M' ? 0 : 1) * WHEIGHTS[:top_gender_7d]
	].sum / WHEIGHTS.values.sum).round == 0 ? 'M' : 'F'
	
	{
		clientId: clientId,
		gender: gender,
		details: {
			last_gender_visited: last_gender_visited,
			top_gender:          top_gender,
			top_gender_7d:       top_gender_7d
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
