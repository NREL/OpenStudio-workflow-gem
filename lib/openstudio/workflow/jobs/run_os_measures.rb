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

class RunOpenstudio < OpenStudio::Workflow::Job

  # Mixin the required util modules
  require_relative '../util/measure'
  require_relative '../util/model'
  require_relative '../util/weather_file'

  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(directory, time_logger, adapter, workflow_arguments, options = {})
    defaults = { format: 'hash', analysis_root_path: '.' }
    super
    @results = {}

    # initialize instance variables that are needed in the perform section
    @model = nil
    @initial_weather_file = nil
    @weather_file_path = nil
    @analysis = nil
    @datapoint = nil
    @workflow = nil
    @output_attributes = {}
    @report_measures = []
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info "Current directory is #{@directory}"

    @logger.info 'Retrieving workflow'
    @workflow = @adapter.get_workflow(@directory, @options)
    @workflow['root_dir'] ? @root_dir = @workflow['root_dir'] : @root_dir = '.'
    @datapoint = @adapter.get_datapoint(@directory, @options)
    @analysis = @adapter.get_analysis(@directory, @options)
    @logger.info 'Found associated OSA file' if @analysis
    @logger.info 'Found associated OSD file' if @datapoint

    fail 'Specified workflow was nil' unless @workflow
    @model = load_seed_model

    @logger.info 'Getting the initial weather file'
    @initial_weather_file = get_weather_file_from_osw(@workflow, @logger)
    unless @initial_weather_file
      @initial_weather_file = get_weather_file_from_osm(@model, @logger)
      @logger.warn 'No valid weather file defined in either the osm or osw.' unless @initial_weather_file
    end

    @logger.info 'Beginning to execute OpenStudio measures.'
    apply_measures(:openstudio_measure)
    @logger.info('Finished applying OpenStudio measures.')

    save_osm(@model, @root_dir, @logger)

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

    @time_logger.start('Saving OSM and IDF')
    save_osm_and_idf
    @time_logger.stop('Saving OSM and IDF')

    @results
  end
end
