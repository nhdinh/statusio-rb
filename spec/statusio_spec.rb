require_relative '../lib/statusio'
require 'rspec'
require 'httparty'

describe StatusioClient do
	let (:api_key) { 'u/sq/L+Mhn0VT0qrKRwN7ehAC2PGqsKa9/tyNFxZfw1MocJluhNItb/1WX6eIkwjK364AOr8PyBotOfvDQMowQ==' }
	let (:api_id) { '60e7436d-672c-4e13-951e-55989ff6a545' }
	let (:statuspage_id) { '56930f131d7e44451b000ae8' }
	let (:api_url) { 'https://api.status.io/v2/' }
	let (:api_headers) {
		{
			'x-api-key' => 'u/sq/L+Mhn0VT0qrKRwN7ehAC2PGqsKa9/tyNFxZfw1MocJluhNItb/1WX6eIkwjK364AOr8PyBotOfvDQMowQ==',
			'x-api-id' => '60e7436d-672c-4e13-951e-55989ff6a545',
			'Content-Type' => 'application/json'
		}
	}

	let (:statusioclient) { StatusioClient.new api_key, api_id }
	let (:mock_components) {
		[{
			 '_id' => '56930f131d7e44451b000af8',
			 'hook_key' => 'xkhzsma0z',
			 'containers' => [{
				                  '_id' => '56930f131d7e44451b000af7',
				                  'name' => 'Primary Data Center',
			                  }],
			 'name' => 'Website',
		 }]
	}

	it 'should success' do
		api_key.should eq 'u/sq/L+Mhn0VT0qrKRwN7ehAC2PGqsKa9/tyNFxZfw1MocJluhNItb/1WX6eIkwjK364AOr8PyBotOfvDQMowQ=='
		statusioclient.should be_an_instance_of StatusioClient
	end

	# Test component_list
	describe 'Testing components method' do
		describe '#component_list' do
			let (:response) { return statusioclient.component_list statuspage_id }

			before do
				VCR.insert_cassette 'component_list_cassette', :record => :new_episodes
			end

			it 'should not never an error return, the message should be ok' do
				response.should_not be nil
				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'

				#@response['result'].length.should eq mock_components.length
				#@response['result'].each_with_index do |component, key|
				#	component['containers'].length.should eq mock_components[key]['containers'].length
				#end
			end

			it 'should be equal with the actual result that get with httparty' do
				actual_response = HTTParty.get(api_url + 'component/list/' + statuspage_id, :headers => api_headers)
				actual_response.code.should eq 200

				response.should eq JSON.parse(actual_response.body)
			end

			after do
				VCR.eject_cassette
			end
		end

		# Test component_status_update
		describe '#component_status_update' do
			before :each do
				@components = [mock_components[0]]
				@containers = [@components[0]['containers'][0]]
				@details = '#Test updating component'
				@current_status = StatusioClient::STATUS_OPERATIONAL
			end

			it 'should update single component and return with "result" equal true with the message' do
				update_response = statusioclient.component_status_update statuspage_id,
				                                                         [@components[0]['_id']],
				                                                         [@containers[0]['_id']],
				                                                         @details,
				                                                         @current_status
				update_response['status']['error'].should eq 'no'
				update_response['status']['message'].should eq 'OK'
				update_response['result'].should eq true

				# TODO: Fix server-side: The result always return true even if @component_id and @container_id are wrong
			end
		end
	end
end