# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Clean up the run directory. Currently this class does nothing else, although eventually cleanup should become driven
# and responsive to options
class RunPostprocess < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util/post_process'
  include OpenStudio::Workflow::Util::PostProcess

  def initialize(input_adapter, output_adapter, registry, options = {})
    defaults = {
      cleanup: true
    }
    options = defaults.merge(options)
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # do not skip post_process if halted

    if !@options[:fast]
      @logger.info 'Gathering reports'
      gather_reports(@registry[:run_dir], @registry[:root_dir], @registry[:workflow_json], @logger)
      @logger.info 'Finished gathering reports'
    end

    if @options[:cleanup]
      @logger.info 'Beginning cleanup of the run directory'
      cleanup(@registry[:run_dir], @registry[:root_dir], @logger)
      @logger.info 'Finished cleanup of the run directory'
    else
      @logger.info 'Flag for cleanup in options set to false. Moving to next step.'
    end

    @logger.info 'Finished postprocess'

    nil
  end
end
