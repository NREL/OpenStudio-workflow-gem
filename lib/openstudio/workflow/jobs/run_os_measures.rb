# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Run any OpenStudio measures contained in the OSW
class RunOpenStudioMeasures < OpenStudio::Workflow::Job
  # Mixin the required util modules
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::Measure
  include OpenStudio::Workflow::Util::Model

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # halted workflow is handled in apply_measures

    # set weather file
    if @registry[:wf] && @registry[:model]
      epwFile = OpenStudio::EpwFile.load(@registry[:wf])
      if !epwFile.empty?
        OpenStudio::Model::WeatherFile.setWeatherFile(@registry[:model], epwFile.get)
      else
        @logger.warn "Could not load weather file from '#{@registry[:wf]}'"
      end
    end

    # Ensure output_attributes is initialized in the registry
    @registry.register(:output_attributes) { {} } unless @registry[:output_attributes]

    # Execute the OpenStudio measures
    @options[:output_adapter] = @output_adapter
    @logger.info 'Beginning to execute OpenStudio measures.'
    apply_measures('ModelMeasure'.to_MeasureType, @registry, @options)
    @logger.info('Finished applying OpenStudio measures.')

    # Send the measure output attributes to the output adapter
    @logger.debug 'Communicating measure output attributes to the output adapter'
    @output_adapter.communicate_measure_attributes @registry[:output_attributes]

    # save the final OSM
    if !@options[:fast]
      save_osm(@registry[:model], @registry[:run_dir])
    end

    # Save the OSM if the :debug option is true
    return nil unless @options[:debug]

    @registry[:time_logger]&.start('Saving OSM')
    osm_name = save_osm(@registry[:model], @registry[:root_dir])
    @registry[:time_logger]&.stop('Saving OSM')
    @logger.debug "Saved model as #{osm_name}"

    nil
  end
end
