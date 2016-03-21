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

class RunEnergyplus < OpenStudio::Workflow::Job

  require_relative '../util/energyplus'
  include OpenStudio::Workflow::Util::EnergyPlus

  def initialize(adapter, registry, options = {})
    super
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info "Current directory is #{@directory}"

    # Ensure that the directory is created (but it should already be at this point)
    FileUtils.mkdir_p(@run_directory)

    # if the weather file is already in the directory, then just use that weather file
    weather_file_name = nil
    weather_files = Dir["#{@directory}/*.epw"]
    if weather_files.size > 1
      @logger.info 'Multiple weather files in the directory. Will rely on the weather file name in the openstudio model'
    elsif weather_files.size == 1
      weather_file_name = weather_files.first
    end

    # verify that the OSM, IDF, and the Weather files are in the run directory as the 'in.*' format
    if !weather_file_name &&
       @options[:run_openstudio] &&
       @options[:run_openstudio][:weather_filename] &&
       File.exist?(@options[:run_openstudio][:weather_filename])
      weather_file_name = @options[:run_openstudio][:weather_filename]
    end

    if weather_file_name
      # verify that it is named in.epw
      @logger.info "Weather file for EnergyPlus simulation is #{weather_file_name}"
      FileUtils.copy(weather_file_name, "#{@run_directory}/in.epw")
    else
      fail "EPW file not found or not sent to #{self.class}"
    end

    # check if the run folder has an IDF. If not then check if the parent folder does.
    idf_file_name = nil
    if File.exist?("#{@run_directory}/in.idf")
      @logger.info 'IDF (in.idf) already exists in the run directory'
    else
      # glob for idf at the directory level
      idfs = Dir["#{@directory}/*.idf"]
      if idfs.size > 1
        @logger.info 'Multiple IDF files in the directory. Cannot continue'
      elsif idfs.size == 1
        idf_file_name = idfs.first
      end
    end

    # Need to check the in.idf and in.osm
    # FileUtils.copy(options[:osm], "#{@run_directory}/in.osm")
    if idf_file_name
      FileUtils.copy(idf_file_name, "#{@run_directory}/in.idf")
    end

    # can't create symlinks because the /vagrant mount is actually a windows mount
    @time_logger.start('Copying EnergyPlus files')
    prepare_energyplus_dir
    @time_logger.stop('Copying EnergyPlus files')

    @time_logger.start('Running EnergyPlus Preprocess Script')
    energyplus_preprocess("#{@run_directory}/in.idf")
    @time_logger.start('Running EnergyPlus Preprocess Script')


    @results
  end
end
