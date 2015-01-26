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

# module containing the methods to apply measures to a model
# must define the following
#   @logger : where to log information
#   @model : the OpenStudio model on which to apply measures
#   @datapoint_json : the datapoint JSON
#   @anlaysis_json : the analysis JSON
#   @output_attributes : hash to store any output attributes
#   @sql_filename : needed for reporting measures

module OpenStudio
  module Workflow
    module ApplyMeasures
      MEASURE_TYPES = {
        openstudio_measure: 'RubyMeasure',
        energyplus_measure: 'EnergyPlusMeasure',
        reporting_measure: 'ReportingMeasure'
      }

      def apply_arguments(argument_map, argument)
        success = true

        unless argument[:value].nil?
          @logger.info "Setting argument value #{argument[:name]} to #{argument[:value]}"

          v = argument_map[argument[:name]]
          fail "Could not find argument map in measure for '#{argument[:name]}' with value '#{argument[:value]}'" unless v
          value_set = v.setValue(argument[:value])
          fail "Could not set argument #{argument[:name]} of value #{argument[:value]} on model" unless value_set
          argument_map[argument[:name]] = v.clone
        else
          @logger.warn "Value for argument '#{argument[:name]}' not set in argument list therefore will use default"
          # success = false

          # TODO: what is the fail case (success = false?)
        end

        success
      end

      # Apply the variable values to the measure argument map object
      def apply_variables(argument_map, variable)
        success = true

        # save the uuid of the variable
        variable_uuid = variable[:uuid].to_sym
        if variable[:argument]
          variable_name = variable[:argument][:name]

          # Get the value from the data point json that was set via R / Problem Formulation
          if @datapoint_json[:data_point]
            if @datapoint_json[:data_point][:set_variable_values]
              unless @datapoint_json[:data_point][:set_variable_values][variable_uuid].nil?
                @logger.info "Setting variable '#{variable_name}' to #{@datapoint_json[:data_point][:set_variable_values][variable_uuid]}"
                v = argument_map[variable_name]
                fail 'Could not find argument map in measure' unless v
                variable_value = @datapoint_json[:data_point][:set_variable_values][variable_uuid]
                value_set = v.setValue(variable_value)
                fail "Could not set variable '#{variable_name}' of value #{variable_value} on model" unless value_set
                argument_map[variable_name] = v.clone
              else
                fail "[ERROR] Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object"
                # @logger.error "Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object"
                # success = false
              end
            else
              fail 'No block for set_variable_values in data point record'
            end
          else
            fail 'No block for data_point in data_point record'
          end
        else
          fail "Variable '#{variable_name}' is defined but no argument is present"
        end

        success
      end

      def apply_measure(workflow_item)
        @logger.info "Starting #{__method__} for #{workflow_item[:name]}"
        @time_logger.start("Measure:#{workflow_item[:name]}")
        # start_time = ::Time.now
        current_dir = Dir.pwd
        begin
          measure_working_directory = "#{@run_directory}/#{workflow_item[:measure_definition_class_name]}"

          @logger.info "Creating run directory to #{measure_working_directory}"
          FileUtils.mkdir_p measure_working_directory
          Dir.chdir measure_working_directory

          measure_path = workflow_item[:measure_definition_directory]
          measure_name = workflow_item[:measure_definition_class_name]
          @logger.info "Apply measure running in #{Dir.pwd}"

          measure_file_path = nil
          if (Pathname.new measure_path).absolute?
            measure_file_path = measure_path
          else
            measure_file_path = File.expand_path(File.join(@options[:analysis_root_path], measure_path, 'measure.rb'))
          end

          @logger.info "Loading Measure from #{measure_file_path}"
          fail "Measure file does not exist #{measure_name} in #{measure_file_path}" unless File.exist? measure_file_path

          measure = nil
          runner = nil
          result = nil
          begin
            require measure_file_path
            measure = Object.const_get(measure_name).new
            runner = OpenStudio::Ruleset::OSRunner.new
          rescue => e
            log_message = "Error requiring measure #{__FILE__}. Failed with #{e.message}, #{e.backtrace.join("\n")}"
            raise log_message
          end

          arguments = nil

          begin
            if workflow_item[:measure_type] == 'RubyMeasure'
              arguments = measure.arguments(@model)
            elsif workflow_item[:measure_type] == 'EnergyPlusMeasure'
              arguments = measure.arguments(@model)
            elsif workflow_item[:measure_type] == 'ReportingMeasure'
              arguments = measure.arguments
            end

            @logger.info "Extracted the following arguments: #{arguments}"

            # Create argument map and initialize all the arguments
            argument_map = OpenStudio::Ruleset::OSArgumentMap.new
            arguments.each do |v|
              argument_map[v.name] = v.clone
            end
            # @logger.info "Argument map for measure is #{argument_map}"

            @logger.info "Iterating over arguments for workflow item '#{workflow_item[:name]}'"
            if workflow_item[:arguments]
              workflow_item[:arguments].each do |argument|
                success = apply_arguments(argument_map, argument)
                fail 'Could not set arguments' unless success
              end
            end

            @logger.info "Iterating over variables for workflow item '#{workflow_item[:name]}'"
            if workflow_item[:variables]
              workflow_item[:variables].each do |variable|
                success = apply_variables(argument_map, variable)
                fail 'Could not set variables' unless success
              end
            end
          rescue => e
            log_message = "Error assigning argument in measure #{__FILE__}. Failed with #{e.message}, #{e.backtrace.join("\n")}"
            raise log_message
          end

          begin
            @logger.info "Calling measure.run for '#{workflow_item[:name]}'"
            if workflow_item[:measure_type] == 'RubyMeasure'
              measure.run(@model, runner, argument_map)
            elsif workflow_item[:measure_type] == 'EnergyPlusMeasure'
              measure.run(@model_idf, runner, argument_map)
            elsif workflow_item[:measure_type] == 'ReportingMeasure'
              # This is silly, set the last model and last sqlfile instead of passing it into the measure.run method
              runner.setLastOpenStudioModel(@model)
              runner.setLastEnergyPlusSqlFilePath(@sql_filename)

              measure.run(runner, argument_map)
            end
            @logger.info "Finished measure.run for '#{workflow_item[:name]}'"
          rescue => e
            log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
            raise log_message
          end

          begin
            result = runner.result
            @logger.info "Running of measure '#{workflow_item[:name]}' completed. Post-processing measure output"

            @logger.info result.initialCondition.get.logMessage unless result.initialCondition.empty?
            @logger.info result.finalCondition.get.logMessage unless result.finalCondition.empty?

            result.warnings.each { |w| @logger.warn w.logMessage }
            an_error = false
            result.errors.each do |w|
              @logger.error w.logMessage
              an_error = true
            end
            fail "Measure #{measure_name} reported an error, check log" if an_error
            result.info.each { |w| @logger.info w.logMessage }
          rescue => e
            log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
            raise log_message
          end

          begin
            measure_attributes = JSON.parse(OpenStudio.toJSON(result.attributes), symbolize_names: true)
            @output_attributes[workflow_item[:name].to_sym] = measure_attributes[:attributes]
          rescue => e
            log_message = "TODO: #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
            @logger.warn log_message
          end
        rescue => e
          log_message = "#{__FILE__} failed with message #{e.message} in #{e.backtrace.join("\n")}"
          @logger.error log_message
          raise log_message
        ensure
          Dir.chdir current_dir
          @time_logger.stop("Measure:#{workflow_item[:name]}")

          @logger.info "Finished #{__method__} for #{workflow_item[:name]} in #{@time_logger.delta("Measure:#{workflow_item[:name]}")} s"
        end
      end

      def apply_measures(measure_type)
        if @analysis_json[:analysis][:problem] && @analysis_json[:analysis][:problem][:workflow]
          current_dir = Dir.pwd
          begin
            @logger.info "Applying measures for #{MEASURE_TYPES[measure_type]}"
            @analysis_json[:analysis][:problem][:workflow].each do |wf|
              next unless wf[:measure_type] == MEASURE_TYPES[measure_type]

              apply_measure(wf)
            end
          ensure
            Dir.chdir current_dir
          end
        end
      end
    end
  end
end
