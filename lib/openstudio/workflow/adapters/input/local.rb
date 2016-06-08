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

require_relative '../../../workflow_json'

# Local file based workflow
module OpenStudio
  module Workflow
    module InputAdapter
      class Local 

        def initialize(osw_path = './workflow.osw')
          @osw_abs_path = File.absolute_path(osw_path, Dir.pwd)
          
          if File.exist? @osw_abs_path
            @workflow = ::JSON.parse(File.read(@osw_abs_path), {symbolize_names: true})
          else
            @workflow = nil
          end          
        end

        # Get the OSW file from the local filesystem
        #
        def workflow
          fail "Could not read workflow from #{@osw_abs_path}" if @workflow.nil?
          @workflow
        end
        
        # Get the OSW path
        #
        def osw_path
          @osw_abs_path
        end
        
        # Get the OSW dir
        #
        def osw_dir
          File.dirname(@osw_abs_path)
        end
        
        # Get the run dir
        #
        def run_dir
          result = File.join(osw_dir, 'run')
          if workflow
            begin
              workflow_json = nil
              begin
                # Create a temporary WorkflowJSON to compute run directory
                workflow_json = OpenStudio::WorkflowJSON.new(JSON.fast_generate(workflow))
                workflow_json.setOswDir(osw_dir)
              rescue Exception => e 
                workflow_json = WorkflowJSON_Shim.new(workflow, osw_dir)
              end
              result = workflow_json.absoluteRunDir.to_s
            rescue
            end
          end
          result
        end
        
        # Get the associated OSD (datapoint) file from the local filesystem
        #
        def datapoint
          # DLM: should this come from the OSW?  the osd id and checksum are specified there.
          osd_abs_path = File.join(osw_dir, 'datapoint.osd')
          if File.exist? osd_abs_path
            ::JSON.parse(File.read(osd_abs_path), {symbolize_names: true})
          else
            nil
          end
        end

        # Get the associated OSA (analysis) definition from the local filesystem
        #
        def analysis
          # DLM: should this come from the OSW?  the osd id and checksum are specified there.
          osa_abs_path = File.join(osw_dir, 'analysis.osa')
          if File.exist? osa_abs_path
            ::JSON.parse(File.read(osa_abs_path), {symbolize_names: true})
          else
            nil
          end
        end

      end
    end
  end
end
