module OpenStudio
  module Workflow
    module Util

      # Handles all interaction with measure objects in the gem. This includes measure.xml and measure.rb files
      #
      module Measure

        # Wrapper method around #apply_measure to allow all measures of a type to be executed
        #
        # @param [String] measure_type Accepts OpenStudio::MeasureType argument
        # @param [Object] registry Hash access to objects
        # @param [Hash] options ({}) User-specified options used to override defaults
        # @option options [Object] :time_logger A special logger used to debug performance issues
        # @option options [Object] :output_adapter An output adapter to register measure transitions to
        # @return [Void]
        #
        def apply_measures(measure_type, registry, options = {})
        
          # DLM: time_logger is in the registry but docs say it is in options?
          registry[:time_logger].start "#{measure_type.valueName}:apply_measures" if registry[:time_logger]

          logger = registry[:logger]
          workflow_json = registry[:workflow_json]
          
          workflow_steps = workflow_json.workflowSteps
          fail "The 'steps' array of the OSW is required." unless workflow_steps
          
          logger.debug "Finding measures of type #{measure_type.valueName}"
          workflow_steps.each do |step|
            measure_dir_name = step.measureDirName

            measure_dir = workflow_json.findMeasure(measure_dir_name)
            fail "Cannot find #{measure_dir_name}" if measure_dir.empty?
            measure_dir = measure_dir.get
            
            measure = OpenStudio::BCLMeasure.load(measure_dir)
            fail "Cannot load measure at #{measure_dir}" if measure.empty?
            measure = measure.get
            
            class_name = measure.className
            measure_instance_type = measure.measureType
            if measure_instance_type == measure_type
              logger.info "Found measure #{class_name} of type #{measure_type.valueName}. Applying now."
              
              # DLM: why is output_adapter in options instead of registry?
              options[:output_adapter].communicate_transition("Applying #{class_name}", :measure) if options[:output_adapter]
              apply_measure(registry, step, options)
              options[:output_adapter].communicate_transition("Applied #{class_name}", :measure) if options[:output_adapter]
              logger.info 'Moving to the next workflow step.'
            else
              logger.debug "Skipping measure #{class_name} of type #{measure_type.valueName}"
            end
          end
          
          registry[:time_logger].stop "#{measure_type.valueName}:apply_measures" if registry[:time_logger]
        end

        # Determine if a given workflow can find and load all measures defined in steps
        #
        # @param [Hash] workflow See the schema for an OSW defined in the spec folder of this repo. Note that this
        #   method requires the OSW to have been loaded with symbolized keys
        # @param [String] directory The directory that will be passed to the find_measure_dir method
        # @return [true] If the method doesn't fail the workflow measures were validated
        #
        def validate_measures(registry, logger)
        
          logger = registry[:logger] if logger.nil?
          workflow_json = registry[:workflow_json]
          
          state = 'ModelMeasure'.to_MeasureType
          steps = workflow_json.workflowSteps
          steps.each_with_index do |step, index|
            begin
              logger.debug "Validating step #{index}"

              # Verify the existence of the required files
              measure_dir_name = step.measureDirName

              measure_dir = workflow_json.findMeasure(measure_dir_name)
              fail "Cannot find #{measure_dir_name}" if measure_dir.empty?
              measure_dir = measure_dir.get
              
              measure = OpenStudio::BCLMeasure.load(measure_dir)
              fail "Cannot load measure at #{measure_dir}" if measure.empty?
              measure = measure.get
              
              class_name = measure.className
              measure_instance_type = measure.measureType

              # Ensure that measures are in order, i.e. no OS after E+, E+ or OS after Reporting
              if measure_instance_type == 'ModelMeasure'.to_MeasureType
                fail "OpenStudio measure #{measure_dir} called after transition to EnergyPlus." if state != 'ModelMeasure'.to_MeasureType
              elsif measure_instance_type == "EnergyPlusMeasure".to_MeasureType
                state = 'EnergyPlusMeasure'.to_MeasureType if state == 'ModelMeasure'.to_MeasureType
                fail "EnergyPlus measure #{measure_dir} called after Energyplus simulation." if state == 'ReportingMeasure'.to_MeasureType
              elsif measure_instance_type == 'ReportingMeasure'.to_MeasureType
                state = 'ReportingMeasure'.to_MeasureType if state == 'EnergyPlusMeasure'.to_MeasureType
              else
                fail "Error: MeasureType #{measure_instance_type.valueName} of measure #{measure_dir} is not supported"
              end

              logger.debug "Validated step #{index}"
            end
          end
        end

        # Sets the argument map for argument_map argument pair
        #
        # @param [Object] argument_map See the OpenStudio SDK for a description of the OSArgumentMap structure
        # @param [Object] argument_name, user defined argument name
        # @param [Object] argument_value, user defined argument value
        # @param [Object] logger, logger object 
        # @return [Object] Returns an updated ArgumentMap object
        #
        def apply_arguments(argument_map, argument_name, argument_value, logger)
          unless argument_value.nil?
            logger.info "Setting argument value '#{argument_name}' to '#{argument_value}'"

            v = argument_map[argument_name.to_s]
            fail "Could not find argument '#{argument_name}' in argument_map" unless v
            value_set = v.setValue(argument_value)
            fail "Could not set argument '#{argument_name}' to value '#{argument_value}'" unless value_set
            argument_map[argument_name.to_s] = v.clone
          else
            logger.warn "Value for argument '#{argument_name}' not set in argument list therefore will use default"
          end
        end

        # Method to allow for a single measure of any type to be run
        #
        # @param [String] directory Location of the datapoint directory to run. This is needed
        #   independent of the adapter that is being used. Note that the simulation will actually run in 'run'
        # @param [Object] adapter An instance of the adapter class
        # @param [String] current_weather_filepath The path which will be used to set the runner and returned to update
        #   the OSW for future measures and the simulation
        # @param [Object] model The model object being used in the measure, either a OSM or IDF
        # @param [Hash] step Definition of the to be run by the workflow
        # @option step [String] :measure_dir_name The name of the directory which contains the measure files
        # @option step [Object] :arguments name value hash which defines the arguments to the measure, e.g.
        #   {has_bool: true, cost: 3.1}
        # @param output_attributes [Hash] The results of previous measure applications which are persisted through the
        #   runner to allow measures to react to previous events in the workflow
        # @param [Hash] options ({}) User-specified options used to override defaults
        # @option options [Array] :measure_search_array Ordered set of measure directories used to search for
        #   step[:measure_dir_name], e.g. ['measures', '../../measures']
        # @option options [Object] :time_logger Special logger used to debug performance issues
        # @return [Hash, String] Returns two objects. The first is the (potentially) updated output_attributes hash, and
        #   the second is the (potentially) updated current_weather_filepath
        #
        def apply_measure(registry, step, options = {})

          logger = registry[:logger]
          runner = registry[:runner]
          workflow_json = registry[:workflow_json]
          measure_dir_name = step.measureDirName
     
          run_dir = registry[:run_dir]
          fail 'No run directory set in the registry' unless run_dir
          
          output_attributes = registry[:output_attributes]
          
          # todo: get weather file from appropriate location 
          @wf = registry[:wf]
          @model = registry[:model]
          @model_idf = registry[:model_idf]
          @sql_filename = registry[:sql]
          
          if runner.openstudio_2
            # we have OS 2.X capabilties
            runner.setLastOpenStudioModel(@model) if @model
            #runner.setLastOpenStudioModelPath(const openstudio::path& lastOpenStudioModelPath); #DLM - deprecate?
            runner.setLastEnergyPlusWorkspace(@model_idf) if @model_idf
            #runner.setLastEnergyPlusWorkspacePath(const openstudio::path& lastEnergyPlusWorkspacePath); #DLM - deprecate?
            runner.setLastEnergyPlusSqlFilePath(@sql_filename) if @sql_filename
            runner.setLastEpwFilePath(@wf) if @wf
          else
            # we have OS 1.X
            runner.setLastOpenStudioModel(@model) if @model
            #runner.setLastOpenStudioModelPath(const openstudio::path& lastOpenStudioModelPath); #DLM - deprecate?
            runner.setLastEnergyPlusWorkspace(@model_idf) if @model_idf
            #runner.setLastEnergyPlusWorkspacePath(const openstudio::path& lastEnergyPlusWorkspacePath); #DLM - deprecate?
            runner.setLastEnergyPlusSqlFilePath(@sql_filename) if @sql_filename
            runner.setLastEpwFilePath(@wf) if @wf
          end
              
          logger.debug "Starting #{__method__} for #{measure_dir_name}"
          registry[:time_logger].start("Measure:#{measure_dir_name}") if registry[:time_logger]
          current_dir = Dir.pwd

          success = nil
          begin
          
            measure_dir = workflow_json.findMeasure(measure_dir_name)
            fail "Cannot find #{measure_dir_name}" if measure_dir.empty?
            measure_dir = measure_dir.get
            
            measure = OpenStudio::BCLMeasure.load(measure_dir)
            fail "Cannot load measure at #{measure_dir}" if measure.empty?
            measure = measure.get
            
            step_index = step.index
            runner_index = runner.currentStep
            fail "step_index #{step_index} does not match runner_index #{runner_index}" if step_index != runner_index

            measure_run_dir = File.join(run_dir, "#{step_index}_#{measure_dir_name}")
            logger.debug "Creating run directory for measure in #{measure_run_dir}"
            FileUtils.mkdir_p measure_run_dir
            Dir.chdir measure_run_dir
            
            logger.debug "Apply measure running in #{Dir.pwd}"

            class_name = measure.className
            measure_type = measure.measureType
            
            measure_path = measure.primaryRubyScriptPath
            fail "Measure does not have a primary ruby script specified" if measure_path.empty?
            measure_path = measure_path.get
            fail "#{measure_path} file does not exist" unless File.exist?(measure_path.to_s)
            
            logger.debug "Loading Measure from #{measure_path}"

            measure_object = nil
            result = nil
            begin
              load measure_path.to_s
              measure_object = Object.const_get(class_name).new
            rescue => e
              # @todo (rhorsey) Clean up the error class here.
              log_message = "Error requiring measure #{__FILE__}. Failed with #{e.message}, #{e.backtrace.join("\n")}"
              raise log_message
            end

            arguments = nil
            skip_measure = false
            begin

              # Initialize arguments which may be model dependent, don't allow arguments method access to real model in case it changes something
              if measure_type == 'ModelMeasure'.to_MeasureType
                arguments = measure_object.arguments(@model.clone(true).to_Model)
              elsif measure_type == 'EnergyPlusMeasure'.to_MeasureType
                arguments = measure_object.arguments(@model_idf.clone(true))
              else measure_type == 'ReportingMeasure'.to_MeasureType
                arguments = measure_object.arguments
              end

              # Create argument map and initialize all the arguments
              argument_map = OpenStudio::Ruleset::OSArgumentMap.new
              if arguments
                arguments.each do |v|
                  argument_map[v.name] = v.clone
                end
              end

              # Set argument values
              logger.debug "Iterating over arguments for workflow item '#{measure_dir_name}'"
              if runner.openstudio_2
                # TODO
                fail "Not implemented"
              else
                step.arguments.each_pair do |argument_name, argument_value|
                  if argument_name == '__SKIP__'
                    if argument_value
                      skip_measure = true
                    end
                  else
                    success = apply_arguments(argument_map, argument_name, argument_value, logger)
                    fail 'Could not set arguments' unless success
                  end
                end
              end
  
            rescue => e
              log_message = "Error assigning argument in measure #{__FILE__}. Failed with #{e.message}, #{e.backtrace.join("\n")}"
              raise log_message
            end

            if !skip_measure
              begin
                logger.debug "Calling measure.run for '#{measure_dir_name}'"
                if measure_type == 'ModelMeasure'.to_MeasureType
                  measure_object.run(@model, runner, argument_map)
                elsif measure_type == 'EnergyPlusMeasure'.to_MeasureType
                  measure_object.run(@model_idf, runner, argument_map)
                elsif measure_type == 'ReportingMeasure'.to_MeasureType
                  measure_object.run(runner, argument_map)
                end
                logger.debug "Finished measure.run for '#{measure_dir_name}'"

                # Run garbage collector after every measure to help address race conditions
                GC.start
              rescue => e
                log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
                raise log_message
              end

              begin
                result = runner.result
                fail "Measure #{measure_name} reported an error, check log" if result.errors.size != 0
                logger.debug "Running of measure '#{measure_dir_name}' completed. Post-processing measure output"
                
                # TODO: fix this
                #unless @wf == runner.weatherfile_path
                #  logger.debug "Updating the weather file to be '#{runner.weatherfile_path}'"
                #  registry.register(:wf) { runner.weatherfile_path }
                #end

                # @todo add note about why reasignment and not eval
                registry.register(:model) { @model }
                registry.register(:model_idf) { @model_idf }
                registry.register(:sql) { @sql }
                
                runner.incrementStep

              rescue => e
                log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
                raise log_message
              end

              # TODO: figure out what this is used for, should be able to get this from runner.previousResults
              #begin
              #  measure_attributes = JSON.parse(OpenStudio.toJSON(result.attributes), symbolize_names: true)
              #  output_attributes[measure_name.to_sym] = measure_attributes[:attributes]
              #
              #  # Add an applicability flag to all the measure results
              #  output_attributes[measure_name.to_sym][:applicable] = result.value.value != -1
              #  registry.register(:output_attributes) { output_attributes }
              #rescue => e
              #  log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
              #  logger.error log_message
              #end
              
            end
            
          rescue => e
            log_message = "#{__FILE__} failed with message #{e.message} in #{e.backtrace.join("\n")}"
            logger.error log_message
            raise log_message
          ensure
            Dir.chdir current_dir
            registry[:time_logger].stop("Measure:#{measure_dir_name}") if registry[:time_logger]

            logger.info "Finished #{__method__} for #{measure_dir_name} in #{@registry[:time_logger].delta("Measure:#{measure_dir_name}")} s"
          end
        end
      end
    end
  end
end
