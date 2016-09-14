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

# Prepares the directory for the EnergyPlus simulation
class RunPreprocess < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::EnergyPlus
  include OpenStudio::Workflow::Util::Model
  include OpenStudio::Workflow::Util::Measure

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # Ensure that the directory is created (but it should already be at this point)
    FileUtils.mkdir_p(@registry[:run_dir])

    # Copy in the weather file defined in the registry, or alternately in the options
    if @registry[:wf]
      @logger.info "Weather file for EnergyPlus simulation is #{@registry[:wf]}"
      FileUtils.copy(@registry[:wf], "#{@registry[:run_dir]}/in.epw")
    elsif @options[:simulation_weather_file]
      @logger.warn "Using weather file defined in options: #{@options[:simulation_weather_file]}"
      FileUtils.copy(@options[:simulation_weather_file], "#{@registry[:run_dir]}/in.epw")
    else
      @logger.warn "EPW file not found or not sent to #{self.class}"
    end

    # save the pre-preprocess file
    File.open("#{@registry[:run_dir]}/pre-preprocess.idf", 'w') { |f| f << @registry[:model_idf].to_s }

    # Add any EnergyPlus Output Requests from Reporting Measures
    @logger.info 'Beginning to collect output requests from Reporting measures.'
    @options[:energyplus_output_requests] = true
    apply_measures('ReportingMeasure'.to_MeasureType, @registry, @options)
    @options[:energyplus_output_requests] = nil
    @logger.info('Finished collect output requests from Reporting measures.')

    # Perform pre-processing on in.idf to capture logic in RunManager
    @registry[:time_logger].start('Running EnergyPlus Preprocess') if @registry[:time_logger]
    energyplus_preprocess(@registry[:model_idf])
    @registry[:time_logger].start('Running EnergyPlus Preprocess') if @registry[:time_logger]
    @logger.info 'Finished preprocess job for EnergyPlus simulation'

    # Save the model objects in the registry to the run directory
    if File.exist?("#{@registry[:run_dir]}/in.idf")
      # DLM: why is this here?
      @logger.warn 'IDF (in.idf) already exists in the run directory. Will simulate using this file'
    else
      save_idf(@registry[:model_idf], @registry[:run_dir])
    end

    # Save the generated IDF file if the :debug option is true
    return nil unless @options[:debug]
    @registry[:time_logger].start('Saving IDF') if @registry[:time_logger]
    idf_name = save_idf(@registry[:model_idf], @registry[:root_dir])
    @registry[:time_logger].stop('Saving IDF') if @registry[:time_logger]
    @logger.debug "Saved IDF as #{idf_name}"

    nil
  end
end
