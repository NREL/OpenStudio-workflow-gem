######################################################################
#  Copyright (c) 2008-2014, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

require_relative '../adapter'

module OpenStudio
  module Workflow
    module Adapters
      class MongoLog
        def initialize(datapoint_model)
          @dp = datapoint_model
          @dp.sdp_log_file ||= []
        end

        def write(msg)
          @dp.sdp_log_file << msg.gsub('\n', '')
          @dp.save!
        end
      end

      class Mongo < Adapter
        attr_reader :datapoint

        def initialize(options={})
          super

          require 'mongoid'
          require 'mongoid_paperclip'
          require 'delayed_job_mongoid'
          base_path = @options[:mongoid_path] ? @options[:mongoid_path] : "#{File.dirname(__FILE__)}/mongo"

          Dir["#{base_path}/models/*.rb"].each { |f| require f }
          Mongoid.load!("#{base_path}/mongoid.yml", :development)

          @datapoint = nil
        end

        # Tell the system that the process has started
        def communicate_started(directory, options={})
          # Watch out for namespace conflicts (::Time is okay but Time is OpenStudio::Time)
          File.open("#{directory}/started.job", 'w') { |f| f << "Started Workflow #{::Time.now}" }

          @datapoint ||= get_datapoint_model(options[:datapoint_id])
          @datapoint.status = 'started'
          @datapoint.status_message = ''
          @datapoint.run_start_time = ::Time.now


          # TODO: use a different method to determine if this is an amazon account
          # TODO: use the ComputeNode model to pull out the information so that we can reuse the methods
          # Determine what the IP address is of the worker node and save in the data point
          require 'socket'
          if Socket.gethostname =~ /os-.*/
            # Maybe use this in the future: /sbin/ifconfig eth1|grep inet|head -1|sed 's/\:/ /'|awk '{print $3}'
            # Must be on vagrant and just use the hostname to do a lookup
            map = {
                'os-server' => '192.168.33.10',
                'os-worker-1' => '192.168.33.11',
                'os-worker-2' => '192.168.33.12'
            }
            @datapoint.ip_address = map[Socket.gethostname]
            @datapoint.internal_ip_address = @datapoint.ip_address

            # TODO: add back in the instance id
          elsif Socket.gethostname =~ /instance-data.ec2.internal.*/i
            # On amazon, you have to hit an API to determine the IP address because
            # of the internal/external ip addresses

            # NL: add the suppress
            public_ip_address = `curl -sL http://169.254.169.254/latest/meta-data/public-ipv4`
            internal_ip_address = `curl -sL http://169.254.169.254/latest/meta-data/local-ipv4`
            # instance_information = `curl -sL http://169.254.169.254/latest/meta-data/instance-id`
            # instance_information = `curl -sL http://169.254.169.254/latest/meta-data/ami-id`
            @datapoint.ip_address = public_ip_address
            @datapoint.internal_ip_address = internal_ip_address
            # @datapoint.server_information = instance_information
          else
            if Gem.loaded_specs["facter"]
              # TODO: add hostname via the facter gem (and anything else?)
              @datapoint.ip_address = Facter.fact(:ipaddress).value
              @datapoint.internal_ip_address = Facter.fact(:hostname).value
            end
          end

          @datapoint.save!
        end

        # Get the data point from the path
        def get_datapoint(directory, options={})
          # TODO : make this a conditional on when to create one vs when to error out.
          # keep @datapoint as the model instance
          @datapoint = DataPoint.find_or_create_by(uuid: options[:datapoint_id])

          # convert to JSON for the workflow - and rearrange the version (fix THIS)
          datapoint_hash = {}
          unless @datapoint.nil?
            datapoint_hash[:data_point] = @datapoint.as_document.to_hash
            # TODO: Can i remove this openstudio_version stuff?
            #datapoint_hash[:openstudio_version] = datapoint_hash[:openstudio_version]

            # TODO: need to figure out how to get symbols from mongo.
            datapoint_hash = MultiJson.load(MultiJson.dump(datapoint_hash, pretty: true), symbolize_keys: true)
          else
            fail "Could not find datapoint"
          end

          datapoint_hash
        end

        # TODO: cleanup these options.  Make them part of the class. They are just unwieldly here.
        def get_problem(directory, options = {})
          defaults = {format: 'json'}
          options = defaults.merge(options)

          get_datapoint(directory, options) unless @datapoint

          if @datapoint
            analysis = @datapoint.analysis.as_document.to_hash
          else
            fail "Cannot retrieve problem because datapoint was nil"
          end

          analysis_hash = {}
          if analysis
            analysis_hash[:analysis] = analysis
            analysis_hash[:openstudio_version] = analysis[:openstudio_version]

            # TODO: need to figure out how to get symbols from mongo.
            analysis_hash = MultiJson.load(MultiJson.dump(analysis_hash, pretty: true), symbolize_keys: true)
          end
          analysis_hash
        end

        def communicate_intermediate_result(directory)
          # noop
        end

        def communicate_complete(directory)
          @datapoint.run_end_time = ::Time.now
          @datapoint.status = 'completed'
          @datapoint.status_message = 'completed normal'
          @datapoint.save!
        end

        # Final state of the simulation. The os_directory is the run directory and may be needed to
        # zip up the results of the simuation.
        def communicate_failure(directory)
          # zip up the folder even on datapoint failures
          if directory && File.exist?(directory)
            zip_results(directory)
          end

          @datapoint.run_end_time = ::Time.now
          @datapoint.status = 'completed'
          @datapoint.status_message = 'datapoint failure'
          @datapoint.save!
        end

        def communicate_results(directory, results)
          zip_results(directory, 'workflow')

          #@logger.info 'Saving EnergyPlus JSON file'
          if results
            @datapoint.results ? @datapoint.results.merge!(results) : @datapoint.results = results
          end
          result = @datapoint.save! # redundant because next method calls save too.

          if result
            #@logger.info 'Successfully saved result to database'
          else
            #@logger.error 'ERROR saving result to database'
          end
        end

        # TODO: can this be deprecated in favor a checking the class?
        def communicate_results_json(eplus_json, analysis_dir)
          # noop
        end

        # TODO: not needed anymore i think...
        def reload
          # noop
        end

        # TODO: Implement the writing to the mongo_db for logging
        def get_logger(directory, options={})
          # get the datapoint object
          get_datapoint(directory, options) unless @datapoint
          @log = OpenStudio::Workflow::Adapters::MongoLog.new(@datapoint)
          @log
        end

        private

        def get_datapoint_model(uuid)
          # TODO : make this a conditional on when to create one vs when to error out.
          # keep @datapoint as the model instance
          DataPoint.find_or_create_by(uuid: uuid)
        end

        # TODO: this uses a system call to zip results at the moment
        def zip_results(analysis_dir, analysis_type = 'workflow')
          # create zip file using a system call
          #@logger.info "Zipping up Analysis Directory #{analysis_dir}"
          if File.directory? analysis_dir
            Dir.chdir(analysis_dir)
            `zip -9 -r --exclude=*.rb* data_point_#{@datapoint.uuid}.zip .`
          end

          # zip up only the reports folder
          report_dir = "#{analysis_dir}"
          #@logger.info "Zipping up Analysis Reports Directory #{report_dir}/reports"
          if File.directory? report_dir
            Dir.chdir(report_dir)
            `zip -r data_point_#{@datapoint.uuid}_reports.zip reports`
          end
          Dir.chdir(current_dir)
        end
      end
    end
  end
end