# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Prepares the directory for the EnergyPlus simulation
class RunPreprocess < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::EnergyPlus
  include OpenStudio::Workflow::Util::Model
  include OpenStudio::Workflow::Util::Measure

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # halted workflow is handled in apply_measures

    # Ensure that the directory is created (but it should already be at this point)
    FileUtils.mkdir_p(@registry[:run_dir])

    # save the pre-preprocess file
    if !@options[:skip_energyplus_preprocess]
      File.open("#{@registry[:run_dir]}/pre-preprocess.idf", 'w') do |f|
        f << @registry[:model_idf].to_s
        # make sure data is written to the disk one way or the other
        begin
          f.fsync
        rescue StandardError
          f.flush
        end
      end
    end

    # Add any EnergyPlus Output Requests from Reporting Measures
    @logger.info 'Beginning to collect output requests from Reporting measures.'
    energyplus_output_requests = true
    apply_measures('ReportingMeasure'.to_MeasureType, @registry, @options, energyplus_output_requests)
    @logger.info('Finished collect output requests from Reporting measures.')

    # Skip the pre-processor if halted
    halted = @registry[:runner].halted
    @logger.info 'Workflow halted, skipping the EnergyPlus pre-processor' if halted
    return nil if halted

    # Perform pre-processing on in.idf to capture logic in RunManager
    if !@options[:skip_energyplus_preprocess]
      @registry[:time_logger]&.start('Running EnergyPlus Preprocess')
      energyplus_preprocess(@registry[:model_idf], @logger)
      @registry[:time_logger]&.start('Running EnergyPlus Preprocess')
      @logger.info 'Finished preprocess job for EnergyPlus simulation'
    end

    # Save the model objects in the registry to the run directory
    if File.exist?("#{@registry[:run_dir]}/in.idf")
      # DLM: why is this here?
      @logger.warn 'IDF (in.idf) already exists in the run directory. Will simulate using this file'
    else
      save_idf(@registry[:model_idf], @registry[:run_dir])
    end

    # Save the generated IDF file if the :debug option is true
    return nil unless @options[:debug]

    @registry[:time_logger]&.start('Saving IDF')
    idf_name = save_idf(@registry[:model_idf], @registry[:root_dir])
    @registry[:time_logger]&.stop('Saving IDF')
    @logger.debug "Saved IDF as #{idf_name}"

    nil
  end
end
