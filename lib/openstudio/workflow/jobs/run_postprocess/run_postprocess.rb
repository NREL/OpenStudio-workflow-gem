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

# Run precanned post processing to extract object functions
# TODO: I hear that measures can step on each other if not run in their own directory

require 'csv'
require 'ostruct'

class RunPostprocess
  # Mixin the MeasureApplication module to apply measures
  include OpenStudio::Workflow::ApplyMeasures

  def initialize(directory, logger, time_logger, adapter, workflow_arguments, past_results, options = {})
    defaults = {}
    @options = defaults.merge(options)
    @directory = directory
    @run_directory = "#{@directory}/run"
    @adapter = adapter
    @logger = logger
    @time_logger = time_logger
    @workflow_arguments = workflow_arguments
    @past_results = past_results
    @results = {}
    @output_attributes = {}

    @logger.info "#{self.class} passed the following options #{@options}"
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info 'RunPostProcess Retrieving datapoint and problem'

    begin
      cleanup
    rescue => e
      log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      @logger.error log_message
      # raise log_message
    end

    @results
  end

  def cleanup
    # move any of the reporting file to the 'reports' directory for serverside access
    eplus_search_path = nil
    FileUtils.mkdir_p "#{@directory}/reports"

    # try to find the energyplus result file
    eplus_html = "#{@run_directory}/eplustbl.htm"
    unless File.exist? eplus_html
      eplus_html = Dir["#{@directory}/*EnergyPlus*/eplustbl.htm"].last || nil
    end

    if eplus_html
      if File.exist? eplus_html
        # do some encoding on the html if possible
        html = File.read(eplus_html)
        html = html.force_encoding('ISO-8859-1').encode('utf-8', replace: nil)
        File.open("#{@directory}/reports/eplustbl.html", 'w') { |f| f << html }
      end
    end

    # Also, find any "report*.*" files
    Dir["#{@run_directory}/*/report*.*"].each do |report|
      # get the parent directory of the file and snake case it
      # do i need to force encoding on this as well?
      measure_class_name = File.basename(File.dirname(report)).to_underscore
      file_ext = File.extname(report)
      append_str = File.basename(report, '.*')
      new_file_name = "#{@directory}/reports/#{measure_class_name}_#{append_str}#{file_ext}"
      FileUtils.copy report, new_file_name
    end

    # Remove empty directories in run folder
    Dir["#{@run_directory}/*"].select { |d| File.directory? d }.select { |d| (Dir.entries(d) - %w(. ..)).empty? }.each do |d|
      @logger.info "Removing empty directory #{d}"
      Dir.rmdir d
    end

    paths_to_rm = []
    # paths_to_rm << Pathname.glob("#{@run_directory}/*.osm")
    # paths_to_rm << Pathname.glob("#{@run_directory}/*.idf") # keep the idfs
    # paths_to_rm << Pathname.glob("*.audit")
    # paths_to_rm << Pathname.glob("*.bnd")
    # paths_to_rm << Pathname.glob("#{@run_directory}/*.eso")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.mtr")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.epw")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.mtd")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.rdd")
    paths_to_rm.each { |p| FileUtils.rm_rf(p) }
  end
end
