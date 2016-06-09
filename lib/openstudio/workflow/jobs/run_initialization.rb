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
    
    @registry.register(:datapoint) { @input_adapter.datapoint }
    @logger.debug 'Found associated OSD file' if @registry[:datapoint]
    
    @registry.register(:analysis) { @input_adapter.analysis }
    @logger.debug 'Found associated OSA file' if @registry[:analysis]
    
    # create the real WorkflowJSON here, we will be able to edit this during the run
    if @registry[:openstudio_2]
      workflow_json = OpenStudio::WorkflowJSON.new(JSON.fast_generate(@registry[:workflow]))
      workflow_json.setOswDir(@registry[:osw_dir])
    else
      workflow_json = WorkflowJSON_Shim.new(@registry[:workflow], @registry[:osw_dir])
    end
    @registry.register(:workflow_json) { workflow_json }
    
    @registry.register(:root_dir) { workflow_json.absoluteRootDir }
    @logger.debug "The root_dir for the analysis is #{@registry[:root_dir]}"
    
    # create the runner with our WorkflowJSON
    @registry.register(:runner) { WorkflowRunner.new(@registry[:logger], @registry[:workflow_json], @registry[:openstudio_2]) }
    @logger.debug 'Initialized runner'

    workflow_json.start
    
    # Validate the OSW measures if the flag is set to true, (the default state)
    if @options[:verify_osw]
      @logger.info 'Attempting to validate the measure workflow'
      validate_measures(@registry, @logger)
      @logger.info 'Validated the measure workflow'
    end

    # Load or create the seed OSM object
    @logger.debug 'Finding and loading the seed file'
    model_path = workflow_json.seedFile
    if !model_path.empty?
    
      model_full_path = workflow_json.findFile(model_path.get)
      if model_full_path.empty?
        fail "Seed model #{model_path.get} specified in OSW cannot be found"
      end
      model_full_path = model_full_path.get
      
      if File.extname(model_full_path.to_s) == '.idf'
        @registry.register(:model_idf) { load_idf(model_full_path, @logger) }
        @registry.register(:model) { nil }
      else
        @registry.register(:model) { load_osm(model_full_path, @logger) }
      end
    else
      @registry.register(:model) { OpenStudio::Model::Model.new() }
    end

    # Find the weather file, should it exist and be findable
    @logger.debug 'Getting the initial weather file'
    weather_path = workflow_json.weatherFile
    if weather_path.empty?
      @logger.debug 'No weather file specified in OSW, looking in model'
      if @registry[:model]
        model = @registry[:model]
        if !model.weatherFile.empty?
          weather_path = model.weatherFile.get.path
        end
      end
    end
    
    if !weather_path.empty?
      weather_path = weather_path.get
      @logger.debug 'Searching for weather file #{weather_path}'
      
      weather_full_path = workflow_json.findFile(weather_path)
      if weather_full_path.empty?
        weather_full_path = workflow_json.findFile(File.basename(weather_path.to_s))
      end
      
      if weather_full_path.empty?
        fail "Weather file #{weather_path} specified but cannot be found"
      end
      weather_full_path = weather_full_path.get
      
      @registry.register(:wf) {weather_full_path.to_s}
    end
    @logger.warn 'No valid weather file defined in either the osm or osw.' unless @registry[:wf]

    nil
  end
end
