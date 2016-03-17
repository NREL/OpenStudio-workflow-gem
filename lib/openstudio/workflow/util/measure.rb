module OpenStudio
  module Workflow
    module Util

      # Handles all interaction with measure objects in the gem. This includes measure.xml and measure.rb files
      #
      module Measure

        require 'rexml/document'
        require_relative '../../workflow_runner'

        MEASURE_CLASSES = {
            openstudio: 'OpenStudio::Ruleset::RubyUserScript',
            energyplus: 'OpenStudio::Ruleset::WorkspaceUserScript',
            reporting: 'OpenStudio::Ruleset::ReportingUserScript'
        }

        # Wrapper method around #apply_measure to allow all measures of a type to be executed
        #
        # @param [String] measure_type Accepts openstudio, energyplus, or reporting as inputs
        # @param [String] directory Location of the datapoint directory to run. This is needed
        #   independent of the adapter that is being used. Note that the simulation will actually run in 'run'
        # @param [Object] adapter An instance of the adapter class
        # @param [String] current_weather_filepath The path which will be used to set the runner and returned to update
        #   the OSW for future measures and the simulation
        # @param [Object] model The model object being used in the measure, either a OSM or IDF
        # @param output_attributes [Hash] The results of previous measure applications which are persisted through the
        #   runner to allow measures to react to previous events in the workflow
        # @param [Hash] options ({}) User-specified options used to override defaults
        # @option options [Array] :measure_search_array An ordered set of measure directories used to search for
        #   step[:measure_dir_name], e.g. ['measures', '../../measures']
        # @option options [Object] :time_logger A special logger used to debug performance issues
        # @option options [Bool] :no_adapter Allows for the apply measure method to be used without an adapter, however
        #   as a result the analysis, workflow, and datapoint hashes are unavailable through the runner for the measure
        # @return [Hash, String] Returns two objects. The first is the (potentially) updated output_attributes hash, and
        #   the second is the (potentially) updated current_weather_filepath
        #
        def apply_measures(measure_type, directory, adapter, current_weather_filepath, model, output_attributes, options = {})
          workflow = adapter.get_workflow
          measure_search_array = options[:measure_search_array]
          measure_search_array ||= ['measures']
          fail "The 'steps' array of the OSW is required." unless workflow[:steps]
          logger.info "Finding measures of type #{measure_type}"
          workflow[:steps].each do |step|
            measure_dir_name = step[:measure_dir_name]
            measure_path = find_measure_dir(directory, measure_dir_name, measure_search_array)
            class_name = measure_class_name(File.absolute_path(File.join(measure_path, 'measure.xml')))
            mrb_path = File.absolute_path(File.join(measure_path, 'measure.rb'))
            measure_type = get_measure_type(mrb_path, class_name)
            if measure_type == MEASURE_CLASSES[measure_type.to_sym]
              logger.info "Found measure #{class_name} in #{mrb_path} of type #{measure_type}. Applying now."
              output_attributes, current_weather_filepath = apply_measure(directory, adapter, current_weather_filepath,
                                                                          model, step, output_attributes, options)
              logger.info 'Moving to the next workflow step.'
            else
              logger.info "Skipping measure #{class_name} in #{mrb_path} of type #{measure_type}"
            end
          end

          return output_attributes, current_weather_filepath

        end

        # Shortcut for finding the measure_dir_name in measure_search_array
        #
        # @param [String] directory base Directory used for relative paths
        # @param [String] measure_dir_name Directory name of the measure, typically from an OSW
        # @param [Array] measure_search_array Ordered set of measure directories used to search for each
        #   step[:measure_dir_name] in, e.g. ['measures', '../../measures']
        # @return [nil, String] The path of the measure is returned as a string, or if the measure_dir_name folder is
        #   not found the value nil is returned
        #
        def find_measure_dir(directory, measure_dir_name, measure_search_array)
          measure_path = nil
          catch :found_dir do
            measure_search_array.each do |measure_dir|
              fail "The path #{measure_dir} does not exist" unless File.exists? File.join(directory, measure_dir)
              if Dir.entries(File.join(directory, measure_dir)).include? measure_dir_name
                measure_path = File.absolute_path(File.join(directory, measure_dir, measure_dir_name))
                throw :found_dir
              end
            end
            measure_path
          end
        end

        # Shortcut for getting the class name of a measure
        #
        # @param [String] mxml_path Path to the measure.xml file to parse
        # @return [String] The class Name of the measure
        #
        def measure_class_name(mxml_path)
          mxml_path = File.new File.join(mxml_path)
          mxml = REXML::Document.new mxml_path
          mxml.elements['*/class_name'].text
        end

        # Shortcut for getting the type of a measure
        #
        # @param [String] mrb_path The absolute path to the measure.rb file of interest
        # @param [String] measure_class The classname of the measure which is used to determine the script's ancestors
        # @return [String] The stringifed ruleset child class which defines what sort of measure is being examined
        #
        def get_measure_type(mrb_path, measure_class)
          begin
            require mrb_path
          rescue
            fail "Unable to require #{mrb_path}. Please ensure this can be required and then retry."
          end
          begin
            measure = Object.const_get(measure_class).new
            measure.class.ancestors[1].to_s
          rescue => e
            # @todo Over time figure out which error classes should get what error messages
            fail "Error. Failed with #{e.message}, #{e.backtrace.join("\n")}"
          end
        end

        # Determine if a given workflow can find and load all measures defined in steps
        #
        # @param [Hash] workflow See the schema for an OSW defined in the spec folder of this repo. Note that this
        #   method requires the OSW to have been loaded with symbolized keys
        # @param [String] directory The directory that will be passed to the apply_measures method
        # @param [Array] measure_search_array (['measures']) Ordered set of measure directories used to search for each
        #   step[:measure_dir_name] in, e.g. ['measures', '../../measures']
        # @return [true] If the method doesn't fail the workflow measures were validated
        #
        def validate_measures(workflow, directory, measure_search_array = ['measures'])
          state = 'openstudio'
          steps = workflow[:steps]
          steps.each_with_index do |step, index|
            begin
              logger.info "Validating step #{index}"

              # Verify the existence of the required files
              measure_dir_name = step[:measure_dir_name]
              measure_path = find_measure_dir(directory, measure_dir_name, measure_search_array)
              fail "Could not find #{measure_dir_name} in #{measure_search_array}." unless measure_path
              folder_contents = Dir.entries measure_path
              fail "No measure.rb file found in #{measure_path}" unless folder_contents.include? 'measure.rb'
              fail "No measure.xml file found in #{measure_path}" unless folder_contents.include? 'measure.xml'

              # Ensure that the measure class_name is retrievable
              mxml_path = File.absolute_path(File.join(measure_path,'measure.xml'))
              class_name = measure_class_name mxml_path
              fail "Unable to find the class_name element in #{mxml_path}" unless class_name
              class_name = class_name.text
              logger.info "Found measure dir #{measure_path} to have a measure class_name of #{class_name}"

              # Attempt to load the measure and verify the class_name
              mrb_path = File.join(measure_path, 'measure.rb')
              measure_type = get_measure_type(mrb_path, class_name)
              logger.info "Successfully initialized an instance of #{class_name} from #{mrb_path} of type #{measure_type}."

              # Ensure that measures are in order, i.e. no OS after E+, E+ or OS after Reporting
              if measure_type.to_s == MEASURE_CLASSES[:openstudio]
                fail "OpenStudio measure #{step['measure_dir_name']} called after transition to EnergyPlus." if state != 'openstudio'
              elsif measure_type.to_s == MEASURE_CLASSES[:energyplus]
                state = 'energyplus' if state == 'openstudio'
                fail "EnergyPlus measure #{step['measure_dir_name']} called after Energyplus simulation." if state == 'reporting'
              elsif measure_type.to_s == MEASURE_CLASSES[:reporting]
                state = 'reporting' if state == 'energyplus'
              else
                fail "Error: Class type of #{class_name} is unrecognized by OpenStudio"
              end

              logger.info "Validated step #{index}"
            end
          end
        end

        # Sets the argument map for argument_map argument pair
        #
        # @param [Object] argument_map See the OpenStudio SDK for a description of the ArgumentMap structure
        # @param [Object] argument See the OpenStudio SDK for a description of the Argument structure
        # @return [Object] Returns an updated ArgumentMap object
        #
        def apply_arguments(argument_map, argument)
          unless argument[:value].nil?
            logger.info "Setting argument value '#{argument[:name]}' to '#{argument[:value]}'"

            v = argument_map[argument[:name]]
            fail "Could not find argument map in measure for '#{argument[:name]}' with value '#{argument[:value]}'" unless v
            value_set = v.setValue(argument[:value])
            fail "Could not set argument '#{argument[:name]}' of value '#{argument[:value]}' on model" unless value_set
            argument_map[argument[:name]] = v.clone
          else
            logger.warn "Value for argument '#{argument[:name]}' not set in argument list therefore will use default"
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
        # @option step [Array] :arguments Ordered name value hashes which define the arguments to the measure, e.g.
        #   [{name: 'has_bool', value: true}, {name: 'cost', value: 3.1}]
        # @param output_attributes [Hash] The results of previous measure applications which are persisted through the
        #   runner to allow measures to react to previous events in the workflow
        # @param [Hash] options ({}) User-specified options used to override defaults
        # @option options [Array] :measure_search_array Ordered set of measure directories used to search for
        #   step[:measure_dir_name], e.g. ['measures', '../../measures']
        # @option options [Object] :time_logger Special logger used to debug performance issues
        # @option options [Bool] :no_adapter Allows for the apply measure method to be used without an adapter, however
        #   as a result the analysis, workflow, and datapoint hashes are unavailable through the runner for the measure
        # @return [Hash, String] Returns two objects. The first is the (potentially) updated output_attributes hash, and
        #   the second is the (potentially) updated current_weather_filepath
        #
        def apply_measure(directory, adapter, current_weather_filepath, model, step, output_attributes, options = {})
          measure_search_array = options[:measure_search_array]
          measure_search_array ||= ['measures']
          measure_dir_name = step[:measure_dir_name]
          if options[:no_adapter]
            analysis, datapoint, workflow = nil
          else
            analysis = adapter.get_analysis(directory, options)
            datapoint = adapter.get_datapoint(directory, options)
            workflow = adapter.get_workflow(directory, options)
          end
          logger.info "Starting #{__method__} for #{step[:measure_dir_name]}"
          options[:time_logger].start("Measure:#{measure_dir_name}") if options[:time_logger]
          current_dir = Dir.pwd

          success = nil
          begin
            measure_wd = find_measure_dir(directory, measure_dir_name, measure_search_array)
            fail "Unable to find measure directory #{measure_dir_name} in #{measure_search_array}" unless measure_wd
            measure_run_dir = File.join(measure_wd, 'run')
            logger.info "Creating run directory in #{measure_wd}"
            FileUtils.mkdir_p measure_run_dir
            Dir.chdir measure_run_dir

            measure_path = File.join(measure_wd, 'measure.rb')
            measure_name = measure_class_name(File.join(measure_wd, 'measure.xml'))
            logger.info "Apply measure running in #{Dir.pwd}"

            measure_path = File.absolute_path(measure_path) unless (Pathname.new measure_path).absolute?
            fail "`measure.rb` file does not exist in #{measure_path}" unless File.exist? measure_path
            logger.info "Loading Measure from #{measure_path}"

            measure = nil
            runner = nil
            result = nil
            begin
              require measure_path
              measure = Object.const_get(measure_name).new
              measure_type = measure.class.ancestors[1]
              fail "Measure #{measure_name} is of type #{measure_type}, which is unknown to the Workflow Gem." unless MEASURE_CLASSES.keys.include? measure_type.to_s
              runner = WorkflowRunner.new(logger, workflow, analysis, datapoint, output_attributes)
              runner.weatherfile_path = current_weather_filepath
            rescue => e
              # @todo (rhorsey) Clean up the error class here.
              log_message = "Error requiring measure #{__FILE__}. Failed with #{e.message}, #{e.backtrace.join("\n")}"
              raise log_message
            end

            arguments = nil

            begin
              # Initialize arguments which may be model dependent
              measure_type.to_s == MEASURE_CLASSES[:reporting] ? arguments = measure.arguments(model) : arguments = measure.arguments

              # Create argument map and initialize all the arguments
              argument_map = OpenStudio::Ruleset::OSArgumentMap.new
              if arguments
                arguments.each do |v|
                  argument_map[v.name] = v.clone
                end
              end

              # Set argument values
              logger.info "Iterating over arguments for workflow item '#{step[:measure_dir_name]}'"
              if step[:arguments]
                step[:arguments].each do |argument|
                  success = apply_arguments(argument_map, argument)
                  fail 'Could not set arguments' unless success
                end
              end
            rescue => e
              log_message = "Error assigning argument in measure #{__FILE__}. Failed with #{e.message}, #{e.backtrace.join("\n")}"
              raise log_message
            end

            begin
              logger.info "Calling measure.run for '#{measure_name}'"
              if measure_type.to_s == MEASURE_CLASSES[:openstudio]
                measure.run(@model, runner, argument_map)
              elsif measure_type.to_s == MEASURE_CLASSES[:energyplus]
                runner.setLastOpenStudioModel(@model)
                measure.run(@model_idf, runner, argument_map)
              else
                runner.setLastOpenStudioModel(@model)
                runner.setLastEnergyPlusWorkspace(@model_idf)
                runner.setLastEnergyPlusSqlFilePath(@sql_filename)
                measure.run(runner, argument_map)
              end
              logger.info "Finished measure.run for '#{measure_name}'"

              # Run garbage collector after every measure to help address race conditions
              GC.start
            rescue => e
              log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
              raise log_message
            end

            begin
              result = runner.result
              current_weather_filepath = runner.weatherfile_path
              logger.info "Running of measure '#{measure_name}' completed. Post-processing measure output"

              fail "Measure #{measure_name} reported an error, check log" if result.errors.size != 0
            rescue => e
              log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
              raise log_message
            end

            begin
              measure_attributes = JSON.parse(OpenStudio.toJSON(result.attributes), symbolize_names: true)
              output_attributes[measure_name.to_sym] = measure_attributes[:attributes]

              # Add an applicability flag to all the measure results
              output_attributes[measure_name.to_sym][:applicable] = result.value.value != -1
            rescue => e
              log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
              logger.error log_message
            end

            return output_attributes, current_weather_filepath

          rescue => e
            log_message = "#{__FILE__} failed with message #{e.message} in #{e.backtrace.join("\n")}"
            logger.error log_message
            raise log_message
          ensure
            Dir.chdir current_dir
            options[:time_logger].stop("Measure:#{measure_dir_name}") if options[:time_logger]

            logger.info "Finished #{__method__} for #{measure_name} in #{@time_logger.delta("Measure:#{measure_name}")} s"
          end
        end
      end
    end
  end
end