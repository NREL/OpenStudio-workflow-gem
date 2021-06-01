# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

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

    # do not skip initialization if halted

    # Communicate that the workflow has been started
    @logger.debug 'Registering that the workflow has started with the adapter'
    @output_adapter.communicate_started

    # Load various files and set basic directories for the registry
    # DLM: this key is the raw JSON object, it is deprecated and should not be used, use :workflow_json instead
    @registry.register(:workflow) { @input_adapter.workflow }
    raise 'Specified workflow was nil' unless @registry[:workflow]

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
    @logger.debug "The root_dir for the datapoint is #{@registry[:root_dir]}"

    generated_files_dir = "#{@registry[:root_dir]}/generated_files"
    if File.exist?(generated_files_dir)
      @logger.debug "Removing existing generated files directory: #{generated_files_dir}"
      FileUtils.rm_rf(generated_files_dir)
    end
    @logger.debug "Creating generated files directory: #{generated_files_dir}"
    FileUtils.mkdir_p(generated_files_dir)

    # insert the generated files directory in the first spot so all generated ExternalFiles go here
    file_paths = @registry[:workflow_json].filePaths
    @registry[:workflow_json].resetFilePaths
    @registry[:workflow_json].addFilePath(generated_files_dir)
    file_paths.each do |file_path|
      @registry[:workflow_json].addFilePath(file_path)
    end

    reports_dir = "#{@registry[:root_dir]}/reports"
    if File.exist?(reports_dir)
      @logger.debug "Removing existing reports directory: #{reports_dir}"
      FileUtils.rm_rf(reports_dir)
    end

    # create the runner with our WorkflowJSON
    @registry.register(:runner) { WorkflowRunner.new(@registry[:logger], @registry[:workflow_json], @registry[:openstudio_2]) }
    @registry[:runner].setDatapoint(@registry[:datapoint])
    @registry[:runner].setAnalysis(@registry[:analysis])
    @logger.debug 'Initialized runner'

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
        raise "Seed model #{model_path.get} specified in OSW cannot be found"
      end

      model_full_path = model_full_path.get

      if File.extname(model_full_path.to_s) == '.idf'
        @registry.register(:model_idf) { load_idf(model_full_path, @logger) }
        @registry.register(:model) { nil }
      else
        @registry.register(:model) { load_osm(model_full_path, @logger) }
      end
    else
      @registry.register(:model) { OpenStudio::Model::Model.new }

      # add default objects to the model
      begin
        OpenStudio::Model.initializeModelObjects(@registry[:model])
      rescue NameError
        @registry[:model].getBuilding
        @registry[:model].getFacility
        @registry[:model].getSimulationControl
        @registry[:model].getSizingParameters
        @registry[:model].getTimestep
        @registry[:model].getShadowCalculation
        @registry[:model].getHeatBalanceAlgorithm
        @registry[:model].getRunPeriod
        @registry[:model].getLifeCycleCostParameters
      end
    end

    if @registry[:openstudio_2]
      @registry[:model]&.setWorkflowJSON(workflow_json.clone)
    end

    # DLM: TODO, load weather_file from options so it can be overriden by user_options

    # Find the weather file, should it exist and be findable
    @logger.debug 'Getting the initial weather file'
    weather_path = workflow_json.weatherFile
    if weather_path.empty?
      @logger.debug 'No weather file specified in OSW, looking in model'
      if @registry[:model]
        model = @registry[:model]
        unless model.weatherFile.empty?
          weather_path = model.weatherFile.get.path
        end
      end
    end

    unless weather_path.empty?
      weather_path = weather_path.get
      @logger.debug "Searching for weather file #{weather_path}"

      weather_full_path = workflow_json.findFile(weather_path)
      if weather_full_path.empty?
        weather_full_path = workflow_json.findFile(File.basename(weather_path.to_s))
      end

      if weather_full_path.empty?
        raise "Weather file '#{weather_path}' specified but cannot be found"
      end

      weather_full_path = weather_full_path.get

      @registry.register(:wf) { weather_full_path.to_s }

    end
    @logger.warn 'No valid weather file defined in either the osm or osw.' unless @registry[:wf]

    workflow_json.start

    nil
  end
end
