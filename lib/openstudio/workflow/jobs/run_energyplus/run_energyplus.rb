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
  ENERGYPLUS_REGEX = /^energyplus\D{0,4}$/i
  EXPAND_OBJECTS_REGEX = /^expandobjects\D{0,4}$/i

  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(directory, logger, time_logger, adapter, workflow_arguments, past_results, options = {})
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
    @workflow_arguments = workflow_arguments
    @past_results = past_results
    @results = {}

    # container for storing the energyplus files there were copied into the local directory. These will be
    # removed at the end of the simulation.
    @energyplus_files = []
    @energyplus_exe = nil
    @expand_objects_exe = nil

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

    @time_logger.start('Running EnergyPlus Preprocess Script')
    energyplus_preprocess("#{@run_directory}/in.idf")
    @time_logger.start('Running EnergyPlus Preprocess Script')

    @time_logger.start('Running EnergyPlus')
    @results = call_energyplus
    @time_logger.stop('Running EnergyPlus')

    @results
  end

  private

  def find_energyplus
    if ENV['ENERGYPLUSDIR']
      return ENV['ENERGYPLUSDIR']
      # TODO: check if method exists! first
    elsif OpenStudio.respond_to? :getEnergyPlusDirectory
      return OpenStudio.getEnergyPlusDirectory.to_s
    elsif ENV['RUBYLIB'] =~ /OpenStudio/
      warn 'Finding EnergyPlus by RUBYLIB parsing will not be supported in the near future. Use either ENERGYPLUSDIR'\
           'env variable or a newer OpenStudio version that has the getEnergyPlusDirectory method'
      path = ENV['RUBYLIB'].split(':')
      path = File.dirname(path.find { |p| p =~ /OpenStudio/ })
      # Grab the version out of the openstudio path
      path += '/sharedresources/EnergyPlus-8-3-0'

      return path
    else
      if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
        return 'C:/EnergyPlus-8-3-0'
      else
        return '/usr/local/EnergyPlus-8-3-0'
      end
    end
  end

  def clean_directory
    @logger.info 'Removing any copied EnergyPlus files'
    @energyplus_files.each do |file|
      if File.exist? file
        FileUtils.rm_f file
      end
    end

    paths_to_rm = []
    paths_to_rm << "#{@run_directory}/packaged_measures"
    paths_to_rm << "#{@run_directory}/Energy+.ini"
    paths_to_rm.each { |p| FileUtils.rm_rf(p) if File.exist?(p) }
  end

  # Prepare the directory to run EnergyPlus. In EnergyPlus < 8.2, we have to copy all the files into the directory.
  #
  # @return [Boolean] Returns true is there is more than one file copied
  def prepare_energyplus_dir
    @logger.info "Copying EnergyPlus files to run directory: #{@run_directory}"
    Dir["#{@options[:energyplus_path]}/*"].each do |file|
      next if File.directory? file
      next if File.extname(file).downcase =~ /.pdf|.app|.html|.gif|.txt|.xlsx/

      dest_file = "#{@run_directory}/#{File.basename(file)}"
      @energyplus_files << dest_file

      @energyplus_exe = File.basename(dest_file) if File.basename(dest_file) =~ ENERGYPLUS_REGEX
      @expand_objects_exe = File.basename(dest_file) if File.basename(dest_file) =~ EXPAND_OBJECTS_REGEX
      FileUtils.copy file, dest_file
    end

    fail "Could not find EnergyPlus executable in #{@options[:energyplus_path]}" unless @energyplus_exe
    fail "Could not find ExpandObjects executable in #{@options[:energyplus_path]}" unless @expand_objects_exe

    @energyplus_files.size > 0
  end

  def call_energyplus
    begin
      current_dir = Dir.pwd
      Dir.chdir(@run_directory)
      @logger.info "Starting simulation in run directory: #{Dir.pwd}"

      File.open('stdout-expandobject', 'w') do |file|
        IO.popen("./#{@expand_objects_exe}") do |io|
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
        IO.popen("./#{@energyplus_exe} 2>&1") do |io|
          while (line = io.gets)
            file << line
          end
        end
      end
      r = $?

      @logger.info "EnergyPlus returned '#{r}'"
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
      @logger.info "Ensuring 'clean' directory"
      clean_directory

      Dir.chdir(current_dir)
      @logger.info 'EnergyPlus Completed'
    end

    {}
  end

  # Run this code before running energyplus to make sure the reporting variables are setup correctly
  def energyplus_preprocess(idf_filename)
    @logger.info 'Running EnergyPlus Preprocess'

    fail "Could not find IDF file in run directory (#{idf_filename})" unless File.exist? idf_filename

    new_objects = []
    needs_monthlyoutput = false

    idf = OpenStudio::IdfFile.load(idf_filename).get
    # save the pre-preprocess file
    File.open("#{File.dirname(idf_filename)}/pre-preprocess.idf", 'w') { |f| f << idf.to_s }

    needs_sqlobj = idf.getObjectsByType('Output:SQLite'.to_IddObjectType).empty?

    needs_monthlyoutput = idf.getObjectsByName('Building Energy Performance - Natural Gas').empty? ||
                          idf.getObjectsByName('Building Energy Performance - Electricity').empty? ||
                          idf.getObjectsByName('Building Energy Performance - District Heating').empty? ||
                          idf.getObjectsByName('Building Energy Performance - District Cooling').empty?

    # this is a workaround for issue #1699 -- remove when 1699 is closed.
    new_objects << 'Output:Variable,*,Zone Air Temperature,Hourly;'
    new_objects << 'Output:Variable,*,Zone Air Relative Humidity,Daily;'
    new_objects << 'Output:Variable,*,Site Outdoor Air Drybulb Temperature,Monthly;'
    new_objects << 'Output:Variable,*,Site Outdoor Air Wetbulb Temperature,Timestep;'

    if needs_sqlobj
      @logger.info 'Adding SQL Output to IDF'
      new_objects << '
        Output:SQLite,
        SimpleAndTabular;         ! Option Type
        '
    end

    if needs_monthlyoutput
      monthly_report_idf = File.join(File.dirname(__FILE__), 'monthly_report.idf')
      idf_file = OpenStudio::IdfFile.load(File.read(monthly_report_idf), 'EnergyPlus'.to_IddFileType).get
      idf.addObjects(idf_file.objects)
    end

    # These are supposedly needed for the calibration report
    new_objects << 'Output:Meter:MeterFileOnly,Gas:Facility,Daily;'
    new_objects << 'Output:Meter:MeterFileOnly,Electricity:Facility,Timestep;'
    new_objects << 'Output:Meter:MeterFileOnly,Electricity:Facility,Daily;'

    # Always add in the timestep facility meters
    new_objects << 'Output:Meter,Electricity:Facility,Timestep;'
    new_objects << 'Output:Meter,Gas:Facility,Timestep;'
    new_objects << 'Output:Meter,DistrictCooling:Facility,Timestep;'
    new_objects << 'Output:Meter,DistrictHeating:Facility,Timestep;'

    new_objects.each do |obj|
      object = OpenStudio::IdfObject.load(obj).get
      idf.addObject(object)
    end

    # save the file
    File.open(idf_filename, 'w') { |f| f << idf.to_s }

    @logger.info 'Finished EnergyPlus Preprocess'
  end
end
