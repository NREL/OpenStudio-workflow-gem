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

# Run the initialization job to run validations and initializations
# @todo include util submodules specifically
class RunInitialization < OpenStudio::Workflow::Job

  require_relative '../util'
  include OpenStudio::Workflow::Util

  def initialize(adapter, registry, options = {})
    defaults = {
        verify_osw: true,
        measure_paths: ['measures', '../../measures'],
        file_paths: ['files', 'weather', '../../files', '../../weather'],

    }
    super
  end

  # This method starts the adapter and verifies the OSW if the options contain verify_osw
  def perform
    Workflow.logger.info "Calling #{__method__} in the #{self.class} class"

    # Start the adapter
    # @todo (rhorsey) Figure out how to deprecate this
    Workflow.logger.info 'Starting communication with the adapter'
    @adapter.communicate_started @registry[:directory], @options

    # Load various files and set basic directories for the registry
    @registry.register(:workflow) { @adapter.get_workflow(@registry[:directory], @options) }
    Workflow.logger.info 'Retrieved the workflow from the adapter'
    fail 'Specified workflow was nil' unless @registry[:workflow]
    @registry.register(:root_dir) { Directory::get_root_dir @registry[:workflow] }
    Workflow.logger.info "The root_dir for the analysis is #{@registry[:root_dir]}"
    @registry.register(:datapoint) { @adapter.get_datapoint(@registry[:directory], @options) }
    Workflow.logger.info 'Found associated OSD file' if @registry[:datapoint]
    @registry.register(:analysis) { @adapter.get_analysis(@registry[:directory], @options) }
    Workflow.logger.info 'Found associated OSA file' if @registry[:analysis]

    # Validate the OSW measures if the flag is set to true, (the default state)
    if @options[:verify_osw]
      Workflow.logger.info 'Attempting to validate the measure workflow'
      Measure.validate_measures(@registry[:workflow], @registry[:root_dir])
    end

    # Load or create the seed OSM object
    Workflow.logger.info 'Finding and loading the seed OSM file'
    osm_name = @registry[:workflow][:seed_osm] ? @registry[:workflow][:seed_osm] : nil
    if @registry[:workflow][:file_paths]
      file_search_paths = @registry[:workflow][:files_paths].concat @options[:file_paths]
    else
      file_search_paths = @options[:files_paths]
    end
    @registry.register(:model) { Model.load_seed_osm(@registry[:root_dir], osm_name, file_search_paths) }

    # Load the weather file, should it exist and be findable
    Workflow.logger.info 'Getting the initial weather file'
    @registry[:workflow][:weather_file] ? wf = @registry[:workflow][:weather_file] : wf = nil
    @registry.register(:wf) { WeatherFile.get_weather_file(@registry[:root_dir], wf, file_search_paths, model) }
    Workflow.logger.warn 'No valid weather file defined in either the osm or osw.' unless @registry[:wf]

    # return the results back to the caller -- always
    results = {}
  end
end
