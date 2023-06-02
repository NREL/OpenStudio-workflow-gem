# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Run the initialization job to validate the directory and initialize the adapters.
class RunTranslation < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util/model'
  include OpenStudio::Workflow::Util::Model

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # skip if halted
    if @registry[:runner].halted
      @logger.info 'Workflow halted, skipping OSM to IDF translation'
      @registry.register(:model_idf) { OpenStudio::Workspace.new } # This allows model arguments to still be calculated
      return nil
    end

    # Ensure that the run directory is created
    FileUtils.mkdir_p(@registry[:run_dir])

    # Copy in the weather file defined in the registry, or alternately in the options
    if @registry[:wf]
      @logger.info "Weather file for EnergyPlus simulation is #{@registry[:wf]}"
      FileUtils.copy(@registry[:wf], "#{@registry[:run_dir]}/in.epw")
      @registry.register(:wf) { "#{@registry[:run_dir]}/in.epw" }
    else
      @logger.warn "EPW file not found or not sent to #{self.class}"
    end

    # Translate the OSM to an IDF
    @logger.info 'Beginning the translation to IDF'
    @registry[:time_logger]&.start('Translating to EnergyPlus')
    model_idf = translate_to_energyplus @registry[:model], @logger
    @registry[:time_logger]&.stop('Translating to EnergyPlus')
    @registry.register(:model_idf) { model_idf }
    @logger.info 'Successfully translated to IDF'

    # Save the generated IDF file if the :debug option is true
    return nil unless @options[:debug]

    @registry[:time_logger]&.start('Saving IDF')
    idf_name = save_idf(@registry[:model_idf], @registry[:root_dir])
    @registry[:time_logger]&.stop('Saving IDF')
    @logger.debug "Saved IDF as #{idf_name}"

    nil
  end
end
