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

  require_relative '../util'
  include OpenStudio::Workflow::Util

  def initialize(adapter, registry, options = {})
    super
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info 'RunPostProcess Retrieving datapoint and problem'

    begin
      # Do something because
      translate_csv_to_json @registry[:root_dir]

      # Run Standard Reports
      standard_report_dir = OpenStudio::BCLMeasure.standardReportMeasure.directory.to_s
      measure_dir_name = File.basename(standard_report_dir)
      step = {measure_dir_name: measure_dir_name}
      step_options = {measure_search_array: File.absolute_path(File.join(standard_report_dir, '..'))}
      logger.info 'Running packaged Standard Reports measures'
      begin
        apply_measure(@registry, step, step_options)
      rescue => e
        logger.warn "Error applying Standard Reports measure. Failed with #{e.message}, #{e.backtrace.join("\n")} \n Continuing."
      end

      # Run Calibration Reports
      logger.info "Found #{@model.getUtilityBills.length} utility bills"
      if @model.getUtilityBills.length > 0
        calibration_report_dir = OpenStudio::BCLMeasure.calibrationReportMeasure.directory.to_s
        measure_dir_name = File.basename(calibration_report_dir)
        workflow_item = {
            display_name: 'Calibration Reports',
            measure_definition_directory: File.expand_path(File.join(OpenStudio::BCLMeasure.calibrationReportMeasure.directory.to_s, 'measure.rb')),
            measure_definition_class_name: 'CalibrationReports',
            measure_type: 'CalibrationReports',
            name: 'calibration_reports'
        }
        step = {measure_dir_name: measure_dir_name}
        step_options = {measure_search_array: File.absolute_path(File.join(calibration_report_dir, '..'))}
        logger.info 'Running packaged Calibration Reports measures'
        begin
          apply_measure(@registry, step, step_options)
        rescue => e
          logger.warn "Error applying Calibration Reports measure. Failed with #{e.message}, #{e.backtrace.join("\n")} \n Continuing."
        end
      end

      logger.info 'Finished Running Packaged Measures'

      # Apply reporting measures
      logger.info 'Beginning to execute OpenStudio measures.'
      OpenStudio::Workflow::Util::Measure.apply_measures(:reporting, @registry, options)
      logger.info('Finished applying OpenStudio measures.')

      # Writing reporting measure attributes json
      logger.info 'Saving reporting measures output attributes JSON'
      File.open("#{@registry[:run_dir]}/reporting_measure_attributes.json", 'w') do |f|
        f << JSON.pretty_generate(@registry[:output_attributes])
      end

      # Run somthing else
      results, objective_functions = PostProcess::run_extract_inputs_and_outputs @registry[:run_dir]

      # Write out the obj function file
      logger.info "Objective Function JSON is #{objective_functions}"
      obj_fun_file = "#{@registry[:directory]}/objectives.json"
      FileUtils.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
      File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(objective_functions) }

    rescue => e
      fail "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
    end

    results
  end
end
