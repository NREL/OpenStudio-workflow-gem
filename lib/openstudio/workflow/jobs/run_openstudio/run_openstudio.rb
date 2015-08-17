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

# TODO: I hear that measures can step on each other if not run in their own directory
class RunOpenstudio
  # Mixin the MeasureApplication module to apply measures
  include OpenStudio::Workflow::ApplyMeasures

  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(directory, logger, time_logger, adapter, workflow_arguments, options = {})
    defaults = { format: 'hash', use_monthly_reports: false, analysis_root_path: '.' }
    @options = defaults.merge(options)
    @directory = directory
    # TODO: there is a base number of arguments that each job will need including @run_directory. abstract it out.
    @run_directory = "#{@directory}/run"
    @adapter = adapter
    @results = {}
    @logger = logger
    @time_logger = time_logger
    @workflow_arguments = workflow_arguments
    @logger.info "#{self.class} passed the following options #{@options}"

    # initialize instance variables that are needed in the perform section
    @model = nil
    @model_idf = nil
    @initial_weather_file = nil
    @weather_file_path = nil
    @analysis_json = nil
    # TODO: rename datapoint_json to just datapoint
    @datapoint_json = nil
    @output_attributes = {}
    @report_measures = []
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info "Current directory is #{@directory}"

    @logger.info 'Retrieving datapoint and problem'
    @datapoint_json = @adapter.get_datapoint(@directory, @options)
    @analysis_json = @adapter.get_problem(@directory, @options)

    if @analysis_json && @analysis_json[:analysis]
      @model = load_seed_model

      load_weather_file

      apply_measures(:openstudio_measure)
      @logger.info("Finished applying OpenStudio measures. Workflow Arguments: #{@@workflow_arguments}")

      @time_logger.start('Translating to EnergyPlus')
      translate_to_energyplus
      @time_logger.stop('Translating to EnergyPlus')

      apply_measures(:energyplus_measure)
      @logger.info("Finished applying EnergyPlus measures. Workflow Arguments: #{@@workflow_arguments}")

      # check if the weather file has changed. This is cheesy for now. Should have a default measure that
      # always sets the weather file so that it can be better controlled
      updated_weather_file = get_weather_file_from_model
      unless updated_weather_file == @initial_weather_file
        # reset the result hash so the future processes know which weather file to run
        @logger.info "Updating the weather file to be '#{updated_weather_file}'"
        if (Pathname.new updated_weather_file).absolute? && (Pathname.new updated_weather_file).exist?
          @results[:weather_filename] = updated_weather_file
        else
          @results[:weather_filename] = "#{@weather_file_path}/#{updated_weather_file}"
        end
      end

      @logger.info 'Saving measure output attributes JSON'
      File.open("#{@run_directory}/measure_attributes.json", 'w') do |f|
        f << JSON.pretty_generate(@output_attributes)
      end
    end

    @time_logger.start('Saving OSM and IDF')
    save_osm_and_idf
    @time_logger.stop('Saving OSM and IDF')

    @results
  end

  private

  def save_osm_and_idf
    # save the data
    osm_filename = "#{@run_directory}/in.osm"
    File.open(osm_filename, 'w') { |f| f << @model.to_s }

    idf_filename = "#{@run_directory}/in.idf"
    File.open(idf_filename, 'w') { |f| f << @model_idf.to_s }

    # TODO: convert this to an OpenStudio method instead of substituting the data as text
    if @options[:use_monthly_reports]
      @logger.info 'Adding monthly reports to EnergyPlus IDF'
      to_append = File.read(File.join(File.dirname(__FILE__), 'monthly_report.idf'))
      File.open(idf_filename, 'a') do |handle|
        handle.puts to_append
      end
    end

    @results[:osm] = File.expand_path(osm_filename)
    @results[:idf] = File.expand_path(idf_filename)
  end

  def load_seed_model
    model = nil
    @logger.info 'Loading seed model'

    baseline_model_path = nil
    # Unique case to use the previous generated OSM as the seed
    if @options[:run_xml] && @options[:run_xml][:osm_filename]
      if File.exist? @options[:run_xml][:osm_filename]
        baseline_model_path = @options[:run_xml][:osm_filename]
      end
    elsif @analysis_json[:analysis][:seed]
      @logger.info "Seed model is #{@analysis_json[:analysis][:seed]}"
      if @analysis_json[:analysis][:seed][:path]

        # assume that the seed model has been placed in the directory
        baseline_model_path = File.expand_path(
          File.join(@options[:analysis_root_path], @analysis_json[:analysis][:seed][:path]))
      else
        fail 'No seed model path in JSON defined'
      end
    else
      # TODO: create a blank model and return
      fail 'No seed model block'
    end

    if baseline_model_path
      if File.exist? baseline_model_path
        @logger.info "Reading in baseline model #{baseline_model_path}"
        translator = OpenStudio::OSVersion::VersionTranslator.new
        model = translator.loadModel(baseline_model_path)
        fail 'OpenStudio model is empty or could not be loaded' if model.empty?
        model = model.get
      else
        fail "Seed model '#{baseline_model_path}' did not exist"
      end
    else
      fail 'No baseline/seed model found'
    end

    model
  end

  # Save the weather file to the instance variable
  def load_weather_file
    @initial_weather_file = get_weather_file_from_model

    weather_filename = nil
    if @options[:run_xml] && @options[:run_xml][:weather_filename]
      if File.exist? @options[:run_xml][:weather_filename]
        weather_filename = @options[:run_xml][:weather_filename]
      end
    elsif @analysis_json[:analysis][:weather_file]
      if @analysis_json[:analysis][:weather_file][:path]
        weather_filename = File.expand_path(
          File.join(@options[:analysis_root_path], @analysis_json[:analysis][:weather_file][:path])
        )
        @weather_file_path = File.dirname(weather_filename)
      else
        fail 'No weather file path defined'
      end
    else
      fail 'No weather file block defined'
    end

    unless File.exist?(weather_filename)
      fail "Could not find weather file for simulation #{weather_filename}"
    end

    @results[:weather_filename] = weather_filename

    weather_filename
  end

  # return the weather file from the model. If the weather file is defined in the model, then
  # it checks the file paths to check if the model exists. This allows for a user to upload a
  # weather file in a measure and then have the measure's path be used for the weather file.
  def get_weather_file_from_model
    wf = nil
    # grab the weather file out of the OSM if it exists
    if @model.weatherFile.empty?
      @logger.info 'No weather file in model'
    else
      p = @model.weatherFile.get.path.get.to_s.gsub('file://', '')
      if File.exist? p
        # use this entire path
        @logger.info "Full path to weather file exists #{p}"
        wf = p
      else
        # this is the weather file from the OSM model
        wf = File.basename(@model.weatherFile.get.path.get.to_s)
      end

      # @logger.info "Initial model weather file is #{wf}" # unless model.weatherFile.empty?
    end

    wf
  end

  # Forward translate to energyplus
  def translate_to_energyplus
    if @model_idf.nil?
      @logger.info 'Translate object to EnergyPlus IDF in Prep for EnergyPlus Measure'
      a = Time.now
      # ensure objects exist for reporting purposes
      @model.getFacility
      @model.getBuilding
      forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
      @model_idf = forward_translator.translateModel(@model)
      b = Time.now
      @logger.info "Translate object to EnergyPlus IDF took #{b.to_f - a.to_f}"
    end
  end
end
