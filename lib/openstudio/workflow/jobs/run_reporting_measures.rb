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

# Run precanned post processing to extract object functions
require 'csv'
require 'ostruct'

class RunReportingMeasures < OpenStudio::Workflow::Job
  # Mixin the MeasureApplication module to apply measures
  require_relative '../util/measure'

  def initialize(directory, time_logger, adapter, workflow_arguments, options = {})
    super
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info 'RunPostProcess Retrieving datapoint and problem'

    begin
      @datapoint_json = @adapter.get_datapoint(@directory, @options)
      @analysis_json = @adapter.get_problem(@directory, @options)

      @time_logger.start('Running standard post process')
      run_monthly_postprocess
      @time_logger.stop('Running standard post process')

      translate_csv_to_json

      # configure the workflow item json to pass
      workflow_item = {
          display_name: 'Standard Reports',
          measure_definition_directory: File.expand_path(File.join(OpenStudio::BCLMeasure.standardReportMeasure.directory.to_s, 'measure.rb')),
          measure_definition_class_name: 'OpenStudioResults',
          measure_type: 'ReportingMeasure',
          name: 'standard_reports'
      }
      logger.info 'Running packaged Standard Reports measures'
      begin
        apply_measure(workflow_item)
      rescue => e
        logger.warn "Error applying Standard Reports measure. Failed with #{e.message}, #{e.backtrace.join("\n")} \n Continuing."
      end

      logger.info "Found #{@model.getUtilityBills.length} utility bills"
      if @model.getUtilityBills.length > 0
        workflow_item = {
            display_name: 'Calibration Reports',
            measure_definition_directory: File.expand_path(File.join(OpenStudio::BCLMeasure.calibrationReportMeasure.directory.to_s, 'measure.rb')),
            measure_definition_class_name: 'CalibrationReports',
            measure_type: 'CalibrationReports',
            name: 'calibration_reports'
        }
        logger.info 'Running packaged Calibration Reports measures'
        apply_measure(workflow_item)
      end

      logger.info 'Finished Running Packaged Measures'

      if @analysis_json && @analysis_json[:analysis]
        apply_measures(:reporting_measure)
      end

      @logger.info 'Saving reporting measures output attributes JSON'
      File.open("#{@run_directory}/reporting_measure_attributes.json", 'w') do |f|
        f << JSON.pretty_generate(@output_attributes)
      end

      run_extract_inputs_and_outputs

      @logger.info "Objective Function JSON is #{@objective_functions}"
      obj_fun_file = "#{@directory}/objectives.json"
      FileUtils.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
      File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(@objective_functions) }

    rescue => e
      log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      raise log_message
    end

    @results
  end
end
