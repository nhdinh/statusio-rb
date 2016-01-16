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

			it 'should not never an error return, the message should be ok' do
				response.should_not be nil
				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'

				response['result'].length.should eq mock_components.length
				response['result'].each_with_index do |component, key|
					component['containers'].length.should eq mock_components[key]['containers'].length
				end
			end

			it 'should be equal with the actual result that get with httparty' do
				actual_response = HTTParty.get(api_url + 'component/list/' + statuspage_id, :headers => api_headers)
				actual_response.code.should eq 200

				response.should eq JSON.parse(actual_response.body)
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

	#   INCIDENT
	describe 'Test incident method' do
		let (:components) { [mock_components[0]] }
		let (:containers) { [components[0]['containers'][0]] }
		let (:payload) { {
			'statuspage_id' => statuspage_id,
			'components' => [components[0]['_id']],
			'containers' => [containers[0]['_id']],
			'incident_name' => 'Database errors',
			'incident_details' => 'Investigating database connection issue',
			'notify_email' => 0,
			'notify_sms' => 1,
			'notify_webhook' => 0,
			'social' => 0,
			'irc' => 0,
			'hipchat' => 0,
			'slack' => 0,
			'current_status' => StatusioClient::STATUS_PARTIAL_SERVICE_DISRUPTION,
			'current_state' => StatusioClient::STATE_INVESTIGATING,
			'all_infrastructure_affected' => '0'
		} }

		let (:notifications) {
			notifications = 0
			notifications += StatusioClient::NOTIFY_EMAIL if payload['notify_email'] != 0
			notifications += StatusioClient::NOTIFY_SMS if payload['notify_sms'] != 0
			notifications += StatusioClient::NOTIFY_WEBHOOK if payload['notify_webhook'] != 0

			return notifications
		}

		# Test incident_list
		describe '#incident_list' do
			let (:response) { statusioclient.incident_list statuspage_id }

			it 'should never return an error' do
				response.should_not be nil
				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'

				response['result']['active_incidents'].should be_an_instance_of Array
				response['result']['resolved_incidents'].should be_an_instance_of Array
			end

			it 'should be equal with the actual result that get with httparty' do
				actual_response = HTTParty.get(api_url + 'incident/list/' + statuspage_id, :headers => api_headers)
				actual_response.code.should eq 200

				response.should eq JSON.parse(actual_response.body)
			end
		end

		# Test incident_create
		describe '#incident_create' do
			let (:response) {
				statusioclient.incident_create statuspage_id,
				                               payload['incident_name'],
				                               payload['incident_details'],
				                               payload['components'],
				                               payload['containers'],
				                               payload['current_status'],
				                               payload['current_state'],
				                               notifications,
				                               payload['all_infrastructure_affected']
			}

			it 'should not be nil' do
				response.should_not eq nil
			end

			it 'should return successfully' do
				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'
			end

			it 'should return with incident_id' do
				response['result'].should_not eq ''
				response['result'].length.should eq 24
			end
		end

		# Test incident_delete
		describe '#incident_delete' do
			let (:incident_list_response) { statusioclient.incident_list statuspage_id }
			let (:incidents) {
				_incidents = {}
				_incidents['active'] = incident_list_response['result']['active_incidents']
				_incidents['resolved'] = incident_list_response['result']['resolved_incidents']
				return _incidents
			}

			it 'should delete all the incidents and return true' do
				incidents.each_value do |igroup|
					if igroup.class == Array and igroup.length != 0
						igroup.each_index do |k|
							@incident_id = igroup[k]['_id']
							response = statusioclient.incident_delete statuspage_id, @incident_id

							response['status']['error'].should eq 'no'
							response['status']['message'].should eq 'Successfully deleted incident'
							response['result'].should eq true
						end
					end
				end
			end
		end

		# Test incident_message
		describe '#incident_message' do
			let (:create_incident_response) {
				statusioclient.incident_create statuspage_id,
				                               payload['incident_name'],
				                               payload['incident_details'],
				                               payload['components'],
				                               payload['containers'],
				                               payload['current_status'],
				                               payload['current_state'],
				                               notifications,
				                               payload['all_infrastructure_affected']
			}

			let (:incident_id) { create_incident_response['result'] }
			let (:incident_list_response) { statusioclient.incident_list statuspage_id }

			# get default message_ids
			let (:message_id) { incident_list_response['result']['active_incidents'][0]['messages'][0]['_id'] }

			it '@message_id that recently created must be available and wel-formed' do
				message_id.should_not eq ''
				message_id.length.should eq 24
			end

			it 'should receive statuspage_id and @message_id as parameters and the result should be eq the result of httparty' do
				response = statusioclient.incident_message statuspage_id, message_id
				actual_response = HTTParty.get(api_url + 'incident/message/' + statuspage_id + '/' + message_id, :headers => api_headers)
				actual_response_body = JSON.parse(actual_response.body)

				actual_response.code.should eq 200
				actual_response_body['status']['message'].should eq 'Get incident message success'
				response.should eq actual_response_body
			end

			after :each do
				statusioclient.incident_delete statuspage_id, @incident_id
			end
		end

		# Test incident_update
		describe '#incident_update' do
			let (:create_incident_response) {
				statusioclient.incident_create statuspage_id,
				                               payload['incident_name'],
				                               payload['incident_details'],
				                               payload['components'],
				                               payload['containers'],
				                               payload['current_status'],
				                               payload['current_state'],
				                               notifications,
				                               payload['all_infrastructure_affected']
			}

			let (:incident_id) { create_incident_response['result'] }

			it 'should receive parameters and update the incident without any error returned' do
				incident_details = 'Incident fixed'
				current_status = StatusioClient::STATUS_OPERATIONAL
				current_state = StatusioClient::STATE_MONITORING
				response = statusioclient.incident_update statuspage_id, incident_id, incident_details, current_status, current_state, StatusioClient::NOTIFY_SMS

				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'
				response['result'].should eq true
			end

			after :each do
				statusioclient.incident_delete statuspage_id, incident_id
			end
		end

		# Test incident_resolve
		describe '#incident_resolve' do
			let (:create_incident_response) {
				statusioclient.incident_create statuspage_id,
				                               payload['incident_name'],
				                               payload['incident_details'],
				                               payload['components'],
				                               payload['containers'],
				                               payload['current_status'],
				                               payload['current_state'],
				                               notifications,
				                               payload['all_infrastructure_affected']
			}

			let (:incident_id) { create_incident_response['result'] }

			it 'should receive parameters and resolve the incident without any error returned' do
				incident_details = 'Incident resolved'
				current_status = StatusioClient::STATUS_OPERATIONAL
				current_state = StatusioClient::STATE_MONITORING
				response = statusioclient.incident_resolve statuspage_id, incident_id, incident_details, current_status, current_state, StatusioClient::NOTIFY_SMS

				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'
				response['result'].should eq true
			end

			after :each do
				statusioclient.incident_delete statuspage_id, incident_id
			end
		end
	end

	# MAINTENANCE

	describe 'Maintenance' do
		let (:components) { [mock_components[0]] }
		let (:containers) { [components[0]['containers'][0]] }

		let (:start_datetime) { Time.now + 60*60*24 }
		let (:end_datetime) { Time.now + 60*60*24 + 60*30 }

		let (:payload) { {
			'maintenance_name' => 'Power source maintenance',
			'maintenance_details' => 'Power source maintenance for all the datacenters',
			'components' => [components[0]['_id']],
			'containers' => [containers[0]['_id']],
			'date_planned_start' => start_datetime.strftime('%m/%d/%Y'),
			'time_planned_start' => start_datetime.strftime('%H:%M'),
			'date_planned_end' => end_datetime.strftime('%m/%d/%Y'),
			'time_planned_end' => end_datetime.strftime('%H:%M'),
			'automation' => '0',
			'all_infrastructure_affected' => '0',
			'maintenance_notify_now' => '0',
			'maintenance_notify_1_hr' => '0',
			'maintenance_notify_24_hr' => '0',
			'maintenance_notify_72_hr' => '0'
		} }


		# Test maintenance_list
		describe '#maintenance_list' do
			let (:response) { statusioclient.maintenance_list statuspage_id }

			it 'should never return an error' do
				response.should_not be nil
				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'

				response['result']['active_maintenances'].should be_an_instance_of Array
				response['result']['upcoming_maintenances'].should be_an_instance_of Array
				response['result']['resolved_maintenances'].should be_an_instance_of Array
			end

			it 'should be equal with the actual result that get with httparty' do
				actual_response = HTTParty.get(api_url + 'maintenance/list/' + statuspage_id, :headers => api_headers)
				actual_response.code.should eq 200

				response.should eq JSON.parse(actual_response.body)
			end
		end

		# Test maintenance_schedule
		describe '#maintenance_schedule' do
			let (:schedule_maintenance_response) {
				statusioclient.maintenance_schedule statuspage_id,
				                                    payload['maintenance_name'],
				                                    payload['maintenance_details'],
				                                    payload['components'],
				                                    payload['containers'],
				                                    payload['date_planned_start'],
				                                    payload['time_planned_start'],
				                                    payload['date_planned_end'],
				                                    payload['time_planned_end'],
				                                    payload['automation'],
				                                    payload['all_infrastructure_affected'],
				                                    payload['maintenance_notify_now'],
				                                    payload['maintenance_notify_1_hr'],
				                                    payload['maintenance_notify_24_hr'],
				                                    payload['maintenance_notify_72_hr']
			}

			it 'should receive @data as parameter and should return an incident_id' do
				schedule_maintenance_response['status']['error'].should eq 'no'
				schedule_maintenance_response['status']['message'].should eq 'OK'
				schedule_maintenance_response['result'].should_not eq ''
				schedule_maintenance_response['result'].length.should eq 24
			end
		end

		# Test maintenance_delete
		describe '#maintenance_delete' do
			let (:maintenance_list_response) { statusioclient.maintenance_list statuspage_id }
			let (:maintenances) {
				_maintenances = {}
				_maintenances['active'] = maintenance_list_response['result']['active_maintenances']
				_maintenances['upcoming'] = maintenance_list_response['result']['upcoming_maintenances']
				_maintenances['resolved'] = maintenance_list_response['result']['resolved_maintenances']

				return _maintenances
			}

			it 'should delete all the maintenances and return true' do
				maintenances.each_value do |mgroup|
					if mgroup.class == Array and mgroup.length != 0
						mgroup.each_index do |k|
							maintenance_id = mgroup[k]['_id']

							response = statusioclient.maintenance_delete statuspage_id, maintenance_id

							response['status']['error'].should eq 'no'
							response['status']['message'].should eq 'Successfully deleted maintenance'
							response['result'].should eq true
						end
					end
				end
			end
		end

		# Test maintenance_start
		describe '#maintenance_start' do
			let (:schedule_maintenance_response) {
				statusioclient.maintenance_schedule statuspage_id,
				                                    payload['maintenance_name'],
				                                    payload['maintenance_details'],
				                                    payload['components'],
				                                    payload['containers'],
				                                    payload['date_planned_start'],
				                                    payload['time_planned_start'],
				                                    payload['date_planned_end'],
				                                    payload['time_planned_end'],
				                                    payload['automation'],
				                                    payload['all_infrastructure_affected'],
				                                    payload['maintenance_notify_now'],
				                                    payload['maintenance_notify_1_hr'],
				                                    payload['maintenance_notify_24_hr'],
				                                    payload['maintenance_notify_72_hr']
			}

			let (:maintenance_id) { schedule_maintenance_response['result'] }

			it 'should receive @maintenance_id and return no error' do
				response = statusioclient.maintenance_start statuspage_id,
				                                            maintenance_id,
				                                            payload['maintenance_name'] + ' : started ' + Time.now.strftime('%d/%m/%Y %H:%M'),
				                                            StatusioClient::NOTIFY_EMAIL

				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'
				response['result'].should eq true
			end

			after :each do
				statusioclient.maintenance_delete statuspage_id, maintenance_id
			end
		end

		# Test maintenance_finish
		describe '#maintenance_finish' do
			let (:schedule_maintenance_response) {
				statusioclient.maintenance_schedule statuspage_id,
				                                    payload['maintenance_name'],
				                                    payload['maintenance_details'],
				                                    payload['components'],
				                                    payload['containers'],
				                                    payload['date_planned_start'],
				                                    payload['time_planned_start'],
				                                    payload['date_planned_end'],
				                                    payload['time_planned_end'],
				                                    payload['automation'],
				                                    payload['all_infrastructure_affected'],
				                                    payload['maintenance_notify_now'],
				                                    payload['maintenance_notify_1_hr'],
				                                    payload['maintenance_notify_24_hr'],
				                                    payload['maintenance_notify_72_hr']
			}

			let (:maintenance_id) { schedule_maintenance_response['result'] }
			let (:start_maintenance_response) {
				statusioclient.maintenance_start statuspage_id,
				                                 maintenance_id,
				                                 payload['maintenance_name'] + ' : started ' + Time.now.strftime('%d/%m/%Y %H:%M'),
				                                 StatusioClient::NOTIFY_EMAIL
			}

			it 'should receive parameters and return no error' do
				response = statusioclient.maintenance_finish statuspage_id,
				                                             maintenance_id,
				                                             'Maintenance finished ' + Time.now.strftime('%d/%m/%Y %H:%M'),
				                                             StatusioClient::NOTIFY_EMAIL

				response['status']['error'].should eq 'no'
				response['status']['message'].should eq 'OK'
				response['result'].should eq true
			end

			after :each do
				statusioclient.maintenance_delete statuspage_id, maintenance_id
			end
		end

		# Test maintenance_message
		describe '#maintenance_message' do
			let (:message_id) {
				maintenance_schedule_response = statusioclient.maintenance_schedule statuspage_id,
				                                                                    payload['maintenance_name'],
				                                                                    payload['maintenance_details'],
				                                                                    payload['components'],
				                                                                    payload['containers'],
				                                                                    payload['date_planned_start'],
				                                                                    payload['time_planned_start'],
				                                                                    payload['date_planned_end'],
				                                                                    payload['time_planned_end'],
				                                                                    payload['automation'],
				                                                                    payload['all_infrastructure_affected'],
				                                                                    payload['maintenance_notify_now'],
				                                                                    payload['maintenance_notify_1_hr'],
				                                                                    payload['maintenance_notify_24_hr'],
				                                                                    payload['maintenance_notify_72_hr']

				maintenance_id = maintenance_schedule_response['result']

				maintenance_list_response = statusioclient.maintenance_list statuspage_id
				upcoming_maintenances = maintenance_list_response['result']['upcoming_maintenances']

				m_id = 0
				upcoming_maintenances.each do |i|
					if i['_id'] == maintenance_id
						m_id = i['messages'][0]['_id']
					end
				end

				return m_id
			}

			let (:maintenance_message_response) { statusioclient.maintenance_message statuspage_id, message_id }


			it 'should return no error and right message' do
				maintenance_message_response['status']['error'].should eq 'no'
				maintenance_message_response['status']['message'].should eq 'Get maintenance message success'
			end

			it 'should be same with httparty result' do
				actual_response = HTTParty.get api_url + 'maintenance/message/' + statuspage_id + '/' + message_id, :headers => api_headers
				maintenance_message_response.should eq JSON.parse(actual_response.body)
			end

			after :each do
				statusioclient.maintenance_delete statuspage_id, maintenance_id
			end
		end
	end
end