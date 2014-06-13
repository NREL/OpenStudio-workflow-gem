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
  def initialize(directory, logger, adapter, options = {})
    defaults = {format: 'hash', use_monthly_reports: false, analysis_root_path: '.'}
    @options = defaults.merge(options)
    @directory = directory
    # TODO: there is a base number of arguments that each job will need including @run_directory. abstract it out.
    @run_directory = "#{@directory}/run"
    @adapter = adapter
    @results = {}
    @logger = logger
    @logger.info "#{self.class} passed the following options #{@options}"

    # initialize instance variables that are needed in the perform section
    @model = nil
    @model_idf = nil
    @analysis_json = nil
    # TODO: rename datapoint_json to just datapoint
    @datapoint_json = nil
    @output_attributes = {}
    @report_measures = []

  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info "Current directory is #{@directory}"

    @logger.info "Retrieving datapoint and problem"
    @datapoint_json = @adapter.get_datapoint(@directory, @options)
    @analysis_json = @adapter.get_problem(@directory, @options)

    if @analysis_json && @analysis_json[:analysis]
      @model = load_seed_model
      load_weather_file

      apply_measures(:openstudio_measure)

      translate_to_energyplus

      apply_measures(:energyplus_measure)

      @logger.info "Measure output attributes JSON is #{@output_attributes}"
      File.open("#{@run_directory}/measure_attributes.json", 'w') {
          |f| f << JSON.pretty_generate(@output_attributes)
      }
    end

    save_osm_and_idf

    @results
  end

  private

  def save_osm_and_idf
    # save the data
    a = Time.now
    osm_filename = "#{@run_directory}/out_raw.osm"
    File.open(osm_filename, 'w') { |f| f << @model.to_s }
    b = Time.now
    @logger.info "Ruby write took #{b.to_f - a.to_f}"

    a = Time.now
    osm_filename = "#{@run_directory}/in.osm"
    @model.save(OpenStudio::Path.new(osm_filename), true)
    b = Time.now
    @logger.info "OpenStudio write took #{b.to_f - a.to_f}"

    # Run EnergyPlus using run energyplus script
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
      fail "No baseline/seed model found"
    end

    model
  end

  # Save the weather file to the instance variable
  def load_weather_file
    weather_filename = nil
    if @options[:run_xml] && @options[:run_xml][:weather_filename]
      if File.exist? @options[:run_xml][:weather_filename]
        weather_filename = @options[:run_xml][:weather_filename]
      end
    elsif @analysis_json[:analysis][:weather_file]
      if @analysis_json[:analysis][:weather_file][:path]
        weather_filename = File.expand_path(
            File.join(@options[:analysis_root_path], @analysis_json[:analysis][:weather_file][:path]))
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
      @logger.info "Translate object to energyplus IDF took #{b.to_f - a.to_f}"
    end
  end
end
