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

require 'openstudio/workflow/adapters/input_adapter'

# Local file based workflow
module OpenStudio
  module Workflow
    module InputAdapter
      class Local < InputAdapters

        require 'openstudio/workflow/util/directory'
        include OpenStudio::Workflow::Util::Directory

        def initialize(options = {})
          super
        end

        # Get the OSW file from the local filesystem
        #
        def get_workflow(directory)
          defaults = { workflow_filename: 'workflow.osw', format: 'json' }
          options = defaults.merge! self.options

          # how do we log within this file?
          osw_abs_path = File.absolute_path(File.join(directory, options[:workflow_filename]))
          if File.exist? osw_abs_path
            ::JSON.parse(File.read(osw_abs_path), {symbolize_names: true})
          else
            fail "Workflow file does not exist for #{osw_abs_path}"
          end
        end

        # Get the associated OSD (datapoint) file from the local filesystem
        #
        def get_datapoint(directory)
          defaults = { datapoint_filename: 'datapoint.osd', format: 'json' }
          options = defaults.merge! self.options

          osd_abs_path = File.absolute_path(File.join(directory, options[:datapoint_filename]))
          if File.exist? osd_abs_path
            ::JSON.parse(File.read(osd_abs_path), {symbolize_names: true})
          else
            nil
          end
        end

        # Get the associated OSA (analysis) definition from the local filesystem
        #
        def get_analysis(directory)
          defaults = { analysis_filename: 'analysis.osa', format: 'json' }
          options = defaults.merge! self.options

          osa_abs_path = File.absolute_path(File.join(directory, options[:analysis_filename]))
          if File.exist? osa_abs_path
            ::JSON.parse(File.read(osa_abs_path), {symbolize_names: true})
          else
            nil
          end
        end

        # Get the directory that will be used by the run class using the directory util
        #
        def base_directory(directory)
          get_directory(directory)
        end

        # Get the run directory that will be used by the run class using the directory util
        #
        def run_directory(directory)
          workflow_hash = get_workflow(directory)
          get_run_dir(workflow_hash, get_directory(directory))
        end
      end
    end
  end
end
