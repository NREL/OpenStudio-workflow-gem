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

class RunEnergyplus

  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(directory, logger, adapter, options = {})
    
    energyplus_path = nil
    if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
      energyplus_path = 'C:/EnergyPlus-8-1-0'
    else
      energyplus_path ='/usr/local/EnergyPlus-8-1-0'
    end
    
    defaults = {
      energyplus_path: energyplus_path
    }
    @options = defaults.merge(options)

    # TODO: use openstudio tool finder for this
    @directory = directory
    @run_directory = "#{@directory}/run"
    @adapter = adapter
    @logger = logger
    @results = {}

    @logger.info "#{self.class} passed the following options #{@options}"
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info "Current directory is #{@directory}"

    # Ensure that the directory is created (but it should already be at this point)
    FileUtils.mkdir_p(@run_directory)

    # verify that the OSM, IDF, and the Weather files are in the run directory as the 'in.*' format
    if @options[:run_openstudio][:weather_filename] && File.exist?(@options[:run_openstudio][:weather_filename])
      # verify that it is named in.epw
      unless File.basename(@options[:run_openstudio][:weather_filename]).downcase == 'in.idf'
        FileUtils.copy(@options[:run_openstudio][:weather_filename], "#{@run_directory}/in.epw")
      end
    else
      fail "EPW file not found or not sent to #{self.class}"
    end

    # Need to check the in.idf and in.osm
    #FileUtils.copy(options[:osm], "#{@run_directory}/in.osm")
    #FileUtils.copy(options[:idf], "#{@run_directory}/in.idf")

    # can't create symlinks because the /vagrant mount is actually a windows mount
    @logger.info "Copying EnergyPlus files to run directory: #{@run_directory}"
    FileUtils.copy("#{@options[:energyplus_path]}/libbcvtb.so", "#{@run_directory}/libbcvtb.so")
    FileUtils.copy("#{@options[:energyplus_path]}/libepexpat.so", "#{@run_directory}/libepexpat.so")
    FileUtils.copy("#{@options[:energyplus_path]}/libepfmiimport.so", "#{@run_directory}/libepfmiimport.so")
    FileUtils.copy("#{@options[:energyplus_path]}/libDElight.so", "#{@run_directory}/libDElight.so")
    FileUtils.copy("#{@options[:energyplus_path]}/libDElight.so", "#{@run_directory}/libDElight.so")
    FileUtils.copy("#{@options[:energyplus_path]}/ExpandObjects", "#{@run_directory}/ExpandObjects")
    FileUtils.copy("#{@options[:energyplus_path]}/EnergyPlus", "#{@run_directory}/EnergyPlus")
    FileUtils.copy("#{@options[:energyplus_path]}/Energy+.idd", "#{@run_directory}/Energy+.idd")

    @results = call_energyplus

    @results
  end

  private

  def call_energyplus
    begin
      current_dir = Dir.pwd
      Dir.chdir(@run_directory)
      @logger.info "Starting simulation in run directory: #{Dir.pwd}"

      File.open('stdout-expandobject', 'w') do |file|
        IO.popen('./ExpandObjects') do |io|
          while (line = io.gets)
            file << line
          end
        end
      end

      # Check if expand objects did anythying
      if File.exist? 'expanded.idf'
        FileUtils.mv('in.idf', 'pre-expand.idf', force: true) if File.exist?('in.idf')
        FileUtils.mv('expanded.idf', 'in.idf', force: true)
      end

      # create stdout
      File.open('stdout-energyplus', 'w') do |file|
        IO.popen('./EnergyPlus') do |io|
          while (line = io.gets)
            file << line
          end
        end
      end

    rescue Exception => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      @logger.error log_message
    ensure
      Dir.chdir(current_dir)
      @logger.info 'EnergyPlus Completed'
    end

    # TODO: get list of all the files that are generated and return
    {}
  end
end
