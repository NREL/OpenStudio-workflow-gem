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

# Run reporting measures and execute scripts to post-process objective functions and results on the filesystem
class RunReportingMeasures < OpenStudio::Workflow::Job
  require 'csv'
  require 'ostruct'
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::Model
  include OpenStudio::Workflow::Util::Measure
  include OpenStudio::Workflow::Util::PostProcess

  def initialize(input_adapter, output_adapter, registry, options = {})
    defaults = {
      load_simulation_osm: false,
      load_simulation_idf: false,
      load_simulation_sql: false
    }
    options = defaults.merge(options)
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"
    @logger.debug 'RunPostProcess Retrieving datapoint and problem'

    # halted workflow is handled in apply_measures

    # Ensure output_attributes is initialized in the registry
    @registry.register(:output_attributes) { {} } unless @registry[:output_attributes]

    # get OSA[:urbanopt]  #BLB should prob be sent in as cli arg and used in options but for now just do this
    @registry.register(:urbanopt) { false }
    if @registry[:osw_path]
      workflow = nil
      if File.exist? @registry[:osw_path]
        workflow = ::JSON.parse(File.read(@registry[:osw_path]), symbolize_names: true)
        if !workflow.nil? && !workflow[:urbanopt].nil?
          @registry.register(:urbanopt) { workflow[:urbanopt] }
        end
      end
    end

    # Load simulation files as required
    unless @registry[:runner].halted || @registry[:urbanopt]
      if @registry[:model].nil?
        osm_path = File.absolute_path(File.join(@registry[:run_dir], 'in.osm'))
        @logger.debug "Attempting to load #{osm_path}"
        @registry.register(:model) { load_osm('.', osm_path) }
        raise "Unable to load #{osm_path}" unless @registry[:model]

        @logger.debug "Successfully loaded #{osm_path}"
      end
      if @registry[:model_idf].nil?
        idf_path = File.absolute_path(File.join(@registry[:run_dir], 'in.idf'))
        @logger.debug "Attempting to load #{idf_path}"
        @registry.register(:model_idf) { load_idf(idf_path, @logger) }
        raise "Unable to load #{idf_path}" unless @registry[:model_idf]

        @logger.debug "Successfully loaded #{idf_path}"
      end
      if @registry[:sql].nil?
        sql_path = File.absolute_path(File.join(@registry[:run_dir], 'eplusout.sql'))
        if File.exist?(sql_path)
          @registry.register(:sql) { sql_path }
          @logger.debug "Registered the sql filepath as #{@registry[:sql]}"
        end
        # raise "Unable to load #{sql_path}" unless @registry[:sql]
      end
      if @registry[:wf].nil?
        epw_path = File.absolute_path(File.join(@registry[:run_dir], 'in.epw'))
        if File.exist?(epw_path)
          @registry.register(:wf) { epw_path }
          @logger.debug "Registered the wf filepath as #{@registry[:wf]}"
        end
        # raise "Unable to load #{epw_path}" unless @registry[:wf]
      end
    end

    # Apply reporting measures
    @options[:output_adapter] = @output_adapter
    @logger.info 'Beginning to execute Reporting measures.'
    apply_measures('ReportingMeasure'.to_MeasureType, @registry, @options)
    @logger.info('Finished applying Reporting measures.')

    # Send the updated measure_attributes to the output adapter
    @logger.debug 'Communicating measures output attributes to the output adapter'
    @output_adapter.communicate_measure_attributes @registry[:output_attributes]

    # Parse the files generated by the local output adapter
    results, objective_functions = run_extract_inputs_and_outputs @registry[:run_dir], @logger
    @registry.register(:results) { results }

    # Send the objective function results to the output adapter
    @logger.debug "Objective Function JSON is #{objective_functions}"
    @output_adapter.communicate_objective_function objective_functions

    nil
  end
end
