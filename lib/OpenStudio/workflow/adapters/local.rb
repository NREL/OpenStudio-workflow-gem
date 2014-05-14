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

        # get the data point from the path
        def get_datapoint(directory, options={})
          defaults = {datapoint_filename: 'datapoint.json', format: 'json'}
          options = defaults.merge(options)

          # how do we log within this file?
          if File.exist? "#{directory}/#{options[:datapoint_filename]}"
            ::MultiJson.load(File.read("#{directory}/#{options[:datapoint_filename]}"), symbolize_names: true)
          else
            fail "Data point file does not exist for #{directory}/#{options[:datapoint_filename]}"
          end
        end

        # TODO: rename this to get_analysis_definintion (or something like that)
        def get_problem(directory_name, options = {})
          defaults = {problem_filename: 'problem.json', format: 'json'}
          options = defaults.merge(options)

          if File.exist? "#{directory_name}/#{options[:problem_filename]}"
            ::MultiJson.load(File.read("#{directory_name}/#{options[:problem_filename]}"), symbolize_names: true)
          else
            fail "Problem file does not exist for #{directory_name}/#{options[:problem_filename]}"
          end
        end

        # log the message via the adapater
        def log_message(message, options = {})
          pp message
          #@logger.info message
        end

        def communicate_started
          pp "i have started"
        end

        # Fot the local adapter send back a handle to a file to append the data. For this adapter
        # the log messages are likely to be the same as the run.log messages.
        # TODO: can we just return a nil for this use case?
        def get_logger(directory)
          @log_file ||= File.open("#{directory}/local_adapter.log", "w")
          @log_file
        end

        def communicate_intermediate_result(h)
          #@communicate_module.communicate_intermediate_result(@communicate_object, h)
        end

        def communicate_results(os_data_point, os_directory)
          #@communicate_module.communicate_results(@communicate_object, os_data_point, os_directory)
        end

        def communicate_results_json(eplus_json, analysis_dir)
          #@communicate_module.communicate_results_json(@communicate_object, eplus_json, analysis_dir)
        end

        def communicate_complete
          #@communicate_module.communicate_complete(@communicate_object)
        end

        # Final state of the simulation. The os_directory is the run directory and may be needed to
        # zip up the results of the simuation.
        def communicate_failure(os_directory)
          #@communicate_module.communicate_failure(@communicate_object, os_directory)
        end

        def reload
          #@communicate_module.reload(@communicate_object)
        end


      end
    end
  end
end
