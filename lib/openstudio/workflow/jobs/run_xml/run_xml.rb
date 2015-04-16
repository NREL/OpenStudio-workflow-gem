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

require 'libxml'

# This actually belongs as another class that gets added as a state dynamically
class RunXml
  # RunXml
  def initialize(directory, logger, time_logger, adapter, options = {})
    defaults = { use_monthly_reports: false, analysis_root_path: '.', xml_library_file: 'xml_runner.rb' }
    @options = defaults.merge(options)
    @directory = directory
    # TODO: there is a base number of arguments that each job will need including @run_directory. abstract it out.
    @run_directory = "#{@directory}/run"
    @adapter = adapter
    @results = {}
    @logger = logger
    @time_logger = time_logger
    @logger.info "#{self.class} passed the following options #{@options}"

    # initialize instance variables that are needed in the perform section
    @weather_filename = nil
    @weather_directory = File.expand_path(File.join(@options[:analysis_root_path], 'weather'))
    @logger.info "Weather directory is: #{@weather_directory}"
    @model_xml = nil
    @model = nil
    @model_idf = nil
    @analysis_json = nil
    # TODO: rename datapoint_json to just datapoint
    @datapoint_json = nil
    @output_attributes = {}
    @report_measures = []
    @measure_type_lookup = {
      openstudio_measure: 'RubyMeasure',
      energyplus_measure: 'EnergyPlusMeasure',
      reporting_measure: 'ReportingMeasure'
    }
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info "Current directory is #{@directory}"

    @logger.info 'Retrieving datapoint and problem'
    @datapoint_json = @adapter.get_datapoint(@directory, @options)
    @analysis_json = @adapter.get_problem(@directory, @options)

    if @analysis_json && @analysis_json[:analysis]
      @model_xml = load_xml_model
      @weather_filename = load_weather_file

      begin
        apply_xml_measures
      rescue => e
        log_message = "Exception during 'apply_xml_measure' with #{e.message}, #{e.backtrace.join("\n")}"
        raise log_message
      end

      # @logger.debug "XML measure output attributes JSON is #{@output_attributes}"
      File.open("#{@run_directory}/measure_attributes_xml.json", 'w') do |f|
        f << JSON.pretty_generate(@output_attributes)
      end
    end

    create_osm_from_xml

    @results
  end

  private

  def load_xml_model
    model = nil
    @logger.info 'Loading seed model'

    if @analysis_json[:analysis][:seed]
      @logger.info "Seed model is #{@analysis_json[:analysis][:seed]}"
      if @analysis_json[:analysis][:seed][:path]

        # assume that the seed model has been placed in the directory
        baseline_model_path = File.expand_path(
          File.join(@options[:analysis_root_path], @analysis_json[:analysis][:seed][:path]))

        if File.exist? baseline_model_path
          @logger.info "Reading in baseline model #{baseline_model_path}"
          model = LibXML::XML::Document.file(baseline_model_path)
          fail 'XML model is nil' if model.nil?

          model.save("#{@run_directory}/original.xml")
        else
          fail "Seed model '#{baseline_model_path}' did not exist"
        end
      else
        fail 'No seed model path in JSON defined'
      end
    else
      fail 'No seed model block'
    end

    model
  end

  # Save the weather file to the instance variable. This can change later after measures run.
  def load_weather_file
    weather_filename = nil
    if @analysis_json[:analysis][:weather_file]
      if @analysis_json[:analysis][:weather_file][:path]
        # This last(4) needs to be cleaned up.  Why don't we know the path of the file?
        # assume that the seed model has been placed in the directory
        weather_filename = File.expand_path(
          File.join(@options[:analysis_root_path], @analysis_json[:analysis][:weather_file][:path]))
        unless File.exist?(weather_filename)
          @logger.warn "Could not find weather file for simulation #{weather_filename}. Will continue because may change"
        end

      else
        fail 'No weather file path defined'
      end
    else
      fail 'No weather file block defined'
    end

    weather_filename
  end

  def create_osm_from_xml
    # Save the final state of the XML file
    xml_filename = "#{@run_directory}/final.xml"
    @model_xml.save(xml_filename)

    @logger.info 'Starting XML to OSM translation'
    begin
      # set the lib path first -- very specific for this application right now
      @space_lib_path = File.expand_path("#{File.dirname(@options[:xml_library_file])}/space_types")
      require @options[:xml_library_file]

      @logger.info "The weather file is #{@weather_filename}"

      osxt = Main.new(@weather_directory, @space_lib_path)
      # def process(as_xml, ideal_loads=false, optimized_model=false, return_objects=false)
      osm, idf, new_xml, building_name, weather_file = osxt.process(@model_xml.to_s, false, false, true)
      # return [model, idf_model, zones_xml, building_name, weather_file]
    rescue => e
      log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      raise log_message
    end

    if osm
      osm_filename = "#{@run_directory}/xml_out.osm"
      File.open(osm_filename, 'w') { |f| f << osm }

      @logger.info 'Finished XML to OSM translation'
    else
      fail 'No OSM model output from XML translation'
    end

    @results[:osm_filename] = File.expand_path(osm_filename)
    @results[:xml_filename] = File.expand_path(xml_filename)
    @results[:weather_filename] = File.expand_path(File.join(@weather_directory, @weather_filename))
  end

  def apply_xml_measures
    # iterate over the workflow and grab the measures
    if @analysis_json[:analysis][:problem] && @analysis_json[:analysis][:problem][:workflow]
      @analysis_json[:analysis][:problem][:workflow].each do |wf|
        if wf[:measure_type] == 'XmlMeasure'
          # need to map the variables to the XML classes
          measure_path = wf[:measure_definition_directory]
          measure_name = wf[:measure_definition_class_name]

          @logger.info "XML Measure path is #{measure_path}"
          @logger.info "XML Measure name is #{measure_name}"

          @logger.info "Loading measure in relative path #{measure_path}"
          measure_file_path = File.expand_path(
            File.join(@options[:analysis_root_path], measure_path, 'measure.rb'))
          fail "Measure file does not exist #{measure_name} in #{measure_file_path}" unless File.exist? measure_file_path

          require measure_file_path
          measure = Object.const_get(measure_name).new

          @logger.info "iterate over arguments for workflow item #{wf[:name]}"

          # The Argument hash in the workflow json file looks like the following
          # {
          #    "display_name": "Set XPath",
          #    "machine_name": "set_xpath",
          #    "name": "xpath",
          #    "value": "/building/blocks/block/envelope/surfaces/window/layout/wwr",
          #    "uuid": "440dcce0-7663-0131-41f1-14109fdf0b37",
          #    "version_uuid": "440e4bd0-7663-0131-41f2-14109fdf0b37"
          # }
          args = {}
          if wf[:arguments]
            wf[:arguments].each do |wf_arg|
              if wf_arg[:value]
                @logger.info "Setting argument value '#{wf_arg[:name]}' to '#{wf_arg[:value]}'"
                # Note that these measures have symbolized hash keys and not strings.  I really want indifferential access here!
                args[wf_arg[:name].to_sym] = wf_arg[:value]
              end
            end
          end

          @logger.info "iterate over variables for workflow item '#{wf[:name]}'"
          if wf[:variables]
            wf[:variables].each do |wf_var|
              # Argument hash in workflow looks like the following
              # argument: {
              #     display_name: "Window-To-Wall Ratio",
              #     display_name_short: "Window-To-Wall Ratio",
              #     name: "value",
              #     value_type: "double",
              #     uuid: "27909cb0-f8c9-0131-9b05-14109fdf0b37"
              # },
              variable_uuid = wf_var[:uuid].to_sym # this is what the variable value is set to
              if wf_var[:argument]
                variable_name = wf_var[:argument][:name]

                # Get the value from the data point json that was set via R / Problem Formulation
                if @datapoint_json[:data_point]
                  if @datapoint_json[:data_point][:set_variable_values]
                    unless @datapoint_json[:data_point][:set_variable_values][variable_uuid].nil?
                      @logger.info "Setting variable '#{variable_name}' to '#{@datapoint_json[:data_point][:set_variable_values][variable_uuid]}'"

                      args[wf_var[:argument][:name].to_sym] = @datapoint_json[:data_point][:set_variable_values][variable_uuid]
                      args["#{wf_var[:argument][:name]}_machine_name".to_sym] = wf_var[:argument][:display_name].snake_case
                      args["#{wf_var[:argument][:name]}_type".to_sym] = wf_var[:value_type] if wf_var[:value_type]
                      @logger.info "Setting the machine name for argument '#{wf_var[:argument][:name]}' to '#{args["#{wf_var[:argument][:name]}_machine_name".to_sym]}'"

                      # Catch a very specific case where the weather file has to be changed
                      if wf[:name] == 'location'
                        @logger.warn "VERY SPECIFIC case to change the location to #{@datapoint_json[:data_point][:set_variable_values][variable_uuid]}"
                        @weather_filename = @datapoint_json[:data_point][:set_variable_values][variable_uuid]
                      end
                    else
                      fail "[ERROR] Value for variable '#{variable_name}:#{variable_uuid}' not set in datapoint object"
                    end
                  else
                    fail 'No block for set_variable_values in data point record'
                  end
                else
                  fail 'No block for data_point in data_point record'
                end
              end
            end
          end

          # Run the XML Measure
          xml_changed = measure.run(@model_xml, nil, args)

          # save the JSON with the changed values
          # the measure has to implement the "results_to_json" method
          @output_attributes[wf[:name].to_sym] = measure.variable_values
          measure.results_to_json("#{@run_directory}/#{wf[:name]}_results.json")

          @logger.info "Finished applying measure workflow #{wf[:name]} with change flag set to '#{xml_changed}'"
        end
      end
    end
  end
end
