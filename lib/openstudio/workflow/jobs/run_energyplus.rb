# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# This class runs the EnergyPlus simulation
class RunEnergyPlus < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util/energyplus'
  include OpenStudio::Workflow::Util::EnergyPlus

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # skip if halted
    halted = @registry[:runner].halted
    @logger.info 'Workflow halted, skipping the EnergyPlus simulation' if halted
    return nil if halted

    # Checks and configuration
    raise 'No run_dir specified in the registry' unless @registry[:run_dir]

    ep_path = @options[:energyplus_path] || nil
    @logger.warn "Using EnergyPlus path specified in options #{ep_path}" if ep_path

    @logger.info 'Starting the EnergyPlus simulation'
    @registry[:time_logger]&.start('Running EnergyPlus')
    call_energyplus(@registry[:run_dir], ep_path, @output_adapter, @logger, @registry[:workflow_json])
    @registry[:time_logger]&.stop('Running EnergyPlus')
    @logger.info 'Completed the EnergyPlus simulation'

    sql_path = File.join(@registry[:run_dir], 'eplusout.sql')
    @registry.register(:sql) { sql_path } if File.exist? sql_path
    @logger.warn "Unable to find sql file at #{sql_path}" unless @registry[:sql]

    nil
  end
end
