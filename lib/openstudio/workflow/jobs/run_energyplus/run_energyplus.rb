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

# Force the MakeMakefile logger write file output to null.
module MakeMakefile::Logging
  @logfile = File::NULL
end


class RunEnergyplus
  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(directory, logger, time_logger, adapter, options = {})
    @logger = logger

    energyplus_path = find_energyplus
    defaults = {
      energyplus_path: energyplus_path
    }
    @options = defaults.merge(options)

    # TODO: use openstudio tool finder for this
    @directory = directory
    @run_directory = "#{@directory}/run"
    @adapter = adapter
    @time_logger = time_logger
    @results = {}

    @logger.info "#{self.class} passed the following options #{@options}"
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

    @time_logger.start('Running EnergyPlus')
    @results = call_energyplus
    @time_logger.stop('Running EnergyPlus')

    @results
  end

  private

  # Look for the location of EnergyPlus
  def find_energyplus
    if ENV['ENERGYPLUSDIR']
      return ENV['ENERGYPLUSDIR']
    elsif ENV['RUBYLIB'] =~ /OpenStudio/
      path = ENV['RUBYLIB'].split(':')
      path = File.dirname(path.find{|p| p =~ /OpenStudio/})
      # Grab the version out of the openstudio path
      path += '/sharedresources/EnergyPlus-8-2-0'
      @logger.info "found EnergyPlus path of #{path}"
      return path
    else
      if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
        energyplus_path = 'C:/EnergyPlus-8-2-0'
      else
        energyplus_path = '/usr/local/EnergyPlus-8-2-0'
      end

    end
  end

  def prepare_energyplus_dir
    def copy_if_exists(from, to_dir)
      @logger.info "Copying #{from} to #{to_dir}"
      FileUtils.copy(from, "#{to_dir}/#{File.basename(from)}") if File.exists?(from)
    end

    @logger.info "Copying EnergyPlus files to run directory: #{@run_directory}"
    copy_if_exists("#{@options[:energyplus_path]}/libbcvtb.so", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/libbcvtb.dylib", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/libepexpat.so", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/libepexpat.dylib", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/libepfmiimport.so", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/libepfmiimport.dylib", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/ExpandObjects", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/EnergyPlus", @run_directory)
    copy_if_exists("#{@options[:energyplus_path]}/Energy+.idd", @run_directory)
  end

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
        IO.popen('./EnergyPlus + 2>&1') do |io|
          while (line = io.gets)
            file << line
          end
        end
      end
      r = $?

      @logger.info "EnergyPlus returned '#{r}'"

      paths_to_rm = []
      paths_to_rm << Pathname.glob("#{@run_directory}/*.ini")
      paths_to_rm << Pathname.glob("#{@run_directory}/*.so")
      paths_to_rm << Pathname.glob("#{@run_directory}/*.idd")
      paths_to_rm << Pathname.glob("#{@run_directory}/ExpandObjects")
      paths_to_rm << Pathname.glob("#{@run_directory}/EnergyPlus")
      paths_to_rm << Pathname.glob("#{@run_directory}/packaged_measures")
      paths_to_rm.each { |p| FileUtils.rm_rf(p) }

      unless r == 0
        @logger.warn 'EnergyPlus returned a non-zero exit code. Check the stdout-energyplus log.'
      end

      if File.exist? 'eplusout.end'
        f = File.read('eplusout.end').force_encoding('ISO-8859-1').encode('utf-8', replace: nil)
        warnings_count = f[/(\d*).Warning/, 1]
        error_count = f[/(\d*).Severe.Errors/, 1]
        @logger.info "EnergyPlus finished with #{warnings_count} warnings and #{error_count} severe errors"
        if f =~ /EnergyPlus Terminated--Fatal Error Detected/
          fail 'EnergyPlus Terminated with a Fatal Error. Check eplusout.err log.'
        end
      else
        fail 'EnergyPlus failed and did not create an eplusout.end file. Check the stdout-energyplus log.'
      end

      if File.exist? 'eplusout.err'
        eplus_err = File.read('eplusout.err').force_encoding('ISO-8859-1').encode('utf-8', replace: nil)
        if eplus_err =~ /EnergyPlus Terminated--Fatal Error Detected/
          fail 'EnergyPlus Terminated with a Fatal Error. Check eplusout.err log.'
        end
      end
    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      @logger.error log_message
      raise log_message
    ensure
      Dir.chdir(current_dir)
      @logger.info 'EnergyPlus Completed'
    end

    # TODO: get list of all the files that are generated and return
    {}
  end
end
