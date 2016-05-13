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
class RunInitialization < OpenStudio::Workflow::Job

  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::WeatherFile
  include OpenStudio::Workflow::Util::Model
  include OpenStudio::Workflow::Util::Measure

  def initialize(input_adapter, output_adapter, registry, options = {})
    defaults = {
        verify_osw: true
    }
    options = defaults.merge(options)
    super
  end

  def perform
    # DLM: why are there multiple loggers running around?  there is one in the registry can we just use that?
    @logger.info "Calling #{__method__} in the #{self.class} class"

    # Communicate that the workflow has been started
    @logger.debug 'Registering that the workflow has started with the adapter'
    @output_adapter.communicate_started

    # Load various files and set basic directories for the registry
    @registry.register(:workflow) { @input_adapter.workflow }
    fail 'Specified workflow was nil' unless @registry[:workflow]
    @logger.debug 'Retrieved the workflow from the adapter'
    
    @registry.register(:osw_dir) { @input_adapter.osw_dir }
    @logger.debug "osw_dir is #{@registry[:osw_dir]}"
    
    @registry.register(:runner) { WorkflowRunner.new(@registry[:logger], @registry[:workflow], @registry[:osw_dir]) }
    @logger.debug 'Initialized runner'
    
    @registry.register(:workflow_json) { @registry[:runner].workflow }
    @logger.debug "Initialized workflow_json of class #{@registry[:workflow_json].class}"
    
    @registry.register(:root_dir) { @registry[:workflow_json].absoluteRootDir }
    @logger.debug "The root_dir for the analysis is #{@registry[:root_dir]}"
    
    @registry.register(:datapoint) { @input_adapter.datapoint }
    @logger.debug 'Found associated OSD file' if @registry[:datapoint]
    
    @registry.register(:analysis) { @input_adapter.analysis }
    @logger.debug 'Found associated OSA file' if @registry[:analysis]
    
    # TODO: should not need these, use workflow_json.findMeasure instead
    @registry.register(:measure_paths) { @registry[:workflow][:measure_paths] } if @registry[:workflow][:measure_paths]
    @logger.debug "Set measure_paths array in the registry to #{@registry[:measure_paths]}" if @registry[:measure_paths]
    
    # TODO: should not need these, use workflow_json.findFile instead
    @registry.register(:file_paths) { @registry[:workflow][:file_paths] } if @registry[:workflow][:file_paths]
    @logger.debug "Set measure_paths array in the registry to #{@registry[:file_paths]}" if @registry[:file_paths]

    # Validate the OSW measures if the flag is set to true, (the default state)
    if @options[:verify_osw]
      @logger.info 'Attempting to validate the measure workflow'
      validate_measures(@registry, @logger)
      @logger.info 'Validated the measure workflow'
    end

    # Load or create the seed OSM object
    # TODO: use workflow_json.findFile instead
    @logger.debug 'Finding and loading the seed file'
    model_name = @registry[:workflow][:seed_file] ? @registry[:workflow][:seed_file] : nil
    if @registry[:file_paths]
      file_search_paths = @registry[:file_paths].concat @options[:file_paths]
    else
      file_search_paths = @options[:file_paths]
    end
    if model_name
      if File.extname(model_name) == '.idf'
        @registry.register(:model_idf) { load_idf(@registry[:root_dir], model_name, file_search_paths, @logger) }
        @registry.register(:model) { load_osm(@registry[:root_dir], nil, file_search_paths, @logger) }
      else
        @registry.register(:model) { load_osm(@registry[:root_dir], model_name, file_search_paths, @logger) }
      end
    else
      @registry.register(:model) { OpenStudio::Model::Model.new() }
    end

    # Load the weather file, should it exist and be findable
    # TODO: use workflow_json.findFile instead
    @logger.debug 'Getting the initial weather file'
    @registry[:workflow][:weather_file] ? wf = @registry[:workflow][:weather_file] : wf = nil
    @registry.register(:wf) { get_weather_file(@registry[:root_dir], wf, file_search_paths, @registry[:model], @logger) }
    @logger.warn 'No valid weather file defined in either the osm or osw.' unless @registry[:wf]

    nil
  end
end
