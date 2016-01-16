require_relative '../lib/statusio'
require 'rspec'

describe StatusioClient do
	let (:api_key) { return 'u/sq/L+Mhn0VT0qrKRwN7ehAC2PGqsKa9/tyNFxZfw1MocJluhNItb/1WX6eIkwjK364AOr8PyBotOfvDQMowQ==' }
	let (:api_id) { return '60e7436d-672c-4e13-951e-55989ff6a545' }
	let (:statuspage_id) { return '56930f131d7e44451b000ae8' }
	let (:api_url) { return 'https://api.status.io/v2/' }
	let (:headers) {
		return {
				'x-api-key' => api_key,
				'x-api-id' => api_id,
				'Content-Type' => 'application/json'
		}
	}

	let (:statusioclient) { return StatusioClient.new api_key, api_id }

	it 'should success' do
		api_key.should eq 'u/sq/L+Mhn0VT0qrKRwN7ehAC2PGqsKa9/tyNFxZfw1MocJluhNItb/1WX6eIkwjK364AOr8PyBotOfvDQMowQ=='
		statusioclient.should be_an_instance_of StatusioClient
	end


	# Test component_list
	describe '#component_list' do
		let (:statusioclient) { return StatusioClient.new api_key, api_id }
		let (:component_list) { return statusioclient.component_list statuspage_id }

		before do
			VCR.insert_cassette 'get_component_list', :record => :new_episodes
		end

		after do
			VCR.eject_cassette
		end

		it 'must have result' do
			component_list['status']['error'].should eq 'no'
			component_list['status']['message'].should eq 'OK'
		end
	end
end