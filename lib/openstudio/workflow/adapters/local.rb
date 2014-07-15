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

# Local file based workflow
module OpenStudio
  module Workflow
    module Adapters
      class Local < Adapter
        def initialize(options = {})
          super
        end

        # Tell the system that the process has started
        def communicate_started(directory, _options = {})
          # Watch out for namespace conflicts (::Time is okay but Time is OpenStudio::Time)
          File.open("#{directory}/started.job", 'w') { |f| f << "Started Workflow #{::Time.now}" }
        end

        # Get the data point from the path
        def get_datapoint(directory, options = {})
          defaults = { datapoint_filename: 'datapoint.json', format: 'json' }
          options = defaults.merge(options)

          # how do we log within this file?
          if File.exist? "#{directory}/#{options[:datapoint_filename]}"
            ::MultiJson.load(File.read("#{directory}/#{options[:datapoint_filename]}"), symbolize_names: true)
          else
            fail "Data point file does not exist for #{directory}/#{options[:datapoint_filename]}"
          end
        end

        # Get the Problem/Analysis definition from the local file
        # TODO: rename this to get_analysis_definintion (or something like that)
        def get_problem(directory, options = {})
          defaults = { problem_filename: 'problem.json', format: 'json' }
          options = defaults.merge(options)

          if File.exist? "#{directory}/#{options[:problem_filename]}"
            ::MultiJson.load(File.read("#{directory}/#{options[:problem_filename]}"), symbolize_names: true)
          else
            fail "Problem file does not exist for #{directory}/#{options[:problem_filename]}"
          end
        end

        def communicate_intermediate_result(_directory)
          # noop
        end

        def communicate_complete(directory)
          File.open("#{directory}/finished.job", 'w') { |f| f << "Finished Workflow #{::Time.now}" }
        end

        # Final state of the simulation. The os_directory is the run directory and may be needed to
        # zip up the results of the simuation.
        def communicate_failure(directory)
          File.open("#{directory}/failed.job", 'w') { |f| f << "Failed Workflow #{::Time.now}" }
          # @communicate_module.communicate_failure(@communicate_object, os_directory)
        end

        def communicate_results(directory, results)
          if results.is_a? Hash
            File.open("#{directory}/datapoint_out.json", 'w') { |f| f << JSON.pretty_generate(results) }
          else
            pp "Unknown datapoint result type. Please handle #{results.class}"
            # data_point_json_path = OpenStudio::Path.new(run_dir) / OpenStudio::Path.new('data_point_out.json')
            # os_data_point.saveJSON(data_point_json_path, true)
          end
          # end
        end

        # TODO: can this be deprecated in favor a checking the class?
        def communicate_results_json(_eplus_json, _analysis_dir)
          # noop
        end

        def reload
          # noop
        end

        # For the local adapter send back a handle to a file to append the data. For this adapter
        # the log messages are likely to be the same as the run.log messages.
        # TODO: do we really want two local logs from the Local adapter? One is in the run dir and the other is in the root
        def get_logger(directory, _options = {})
          @log ||= File.open("#{directory}/local_adapter.log", 'w')
          @log
        end
      end
    end
  end
end
