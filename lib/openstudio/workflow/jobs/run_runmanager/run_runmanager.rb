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

require 'openstudio'

# TODO: I hear that measures can step on each other if not run in their own directory
class RunRunmanager
  # Mixin the MeasureApplication module to apply measures
  include OpenStudio::Workflow::ApplyMeasures

  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(directory, logger, adapter, options = {})
    energyplus_path = nil
    if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
      energyplus_path = 'C:/EnergyPlus-8-1-0'
    else
      energyplus_path = '/usr/local/EnergyPlus-8-1-0'
    end

    defaults = {
        analysis_root_path: '.',
        energyplus_path: energyplus_path
    }
    @options = defaults.merge(options)

    @analysis_root_path = OpenStudio::Path.new(options[:analysis_root_path])
    @directory = OpenStudio::Path.new(directory)
    # TODO: there is a base number of arguments that each job will need including @run_directory. abstract it out.
    @run_directory = @directory / OpenStudio::Path.new('run')
    @adapter = adapter
    @results = {}
    @logger = logger
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

    begin

      @logger.info 'Retrieving datapoint and problem'
      @datapoint_json = @adapter.get_datapoint(@directory.to_s, @options)
      @analysis_json = @adapter.get_problem(@directory.to_s, @options)

      @logger.info "@datapoint_json = #{@datapoint_json}"
      @logger.info "@analysis_json = #{@analysis_json}"
      @logger.info "@datapoint_json[:openstudio_version] = #{@datapoint_json[:openstudio_version]}"
      @logger.info "@analysis_json[:openstudio_version] = #{@analysis_json[:openstudio_version]}"
      @logger.info "@analysis_json[:analysis] = #{@analysis_json[:analysis]}"
      @logger.info "@analysis_json[:analysis][:openstudio_version] = #{@analysis_json[:analysis][:openstudio_version]}"

      #@results[:weather_filename]
      #File.open("#{@run_directory}/measure_attributes.json", 'w') do
      #    |f| f << JSON.pretty_generate(@output_attributes)
      #end

      if @analysis_json && @datapoint_json

        if @analysis_json[:openstudio_version].nil?
          if @analysis_json[:analysis] && @analysis_json[:analysis][:openstudio_version]
            @analysis_json[:openstudio_version] = @analysis_json[:analysis][:openstudio_version]
          end
        end

        if @datapoint_json[:openstudio_version].nil?
          if @analysis_json[:analysis] && @analysis_json[:analysis][:openstudio_version]
            @datapoint_json[:openstudio_version] = @analysis_json[:analysis][:openstudio_version]
          end
        end

        # set up log file
        logSink = OpenStudio::FileLogSink.new(@run_directory / OpenStudio::Path.new('openstudio.log'))
        #logSink.setLogLevel(OpenStudio::Debug)
        logSink.setLogLevel(OpenStudio::Trace)
        OpenStudio::Logger.instance.standardOutLogger.disable

        @logger.info 'Parsing Analysis JSON input'

        # load problem formulation
        loadResult = OpenStudio::Analysis.loadJSON(JSON.pretty_generate(@analysis_json))
        if loadResult.analysisObject.empty?
          loadResult.errors.each { |error|
            @logger.warn error.logMessage # DLM: is this right?
          }
          fail 'Unable to load analysis json.'
        end

        @logger.info 'Get Analysis From OpenStudio'
        analysis = loadResult.analysisObject.get.to_Analysis.get

        # fix up paths
        @logger.info 'Fix Paths'
        analysis.updateInputPathData(loadResult.projectDir, @analysis_root_path)

        # save for reference only
        analysis_options = OpenStudio::Analysis::AnalysisSerializationOptions.new(@analysis_root_path)
        analysis.saveJSON(@run_directory / OpenStudio::Path.new('formulation_final.json'), analysis_options, true)

        @logger.info 'Parsing DataPoint JSON input'

        # load data point to run
        loadResult = OpenStudio::Analysis.loadJSON(JSON.pretty_generate(@datapoint_json))
        if loadResult.analysisObject.empty?
          loadResult.errors.each { |error|
            @logger.warn error.logMessage
          }
          fail 'Unable to load data point json.'
        end
        data_point = loadResult.analysisObject.get.to_DataPoint.get
        analysis.addDataPoint(data_point) # also hooks up real copy of problem

        @logger.info 'Creating RunManager'

        # create a RunManager
        run_manager_path = @run_directory / OpenStudio::Path.new('run.db')
        run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_path, true, false, false)

        # have problem create the workflow
        @logger.info 'Creating Workflow'
        workflow = analysis.problem.createWorkflow(data_point, OpenStudio::Path.new($OpenStudio_Dir))
        params = OpenStudio::Runmanager::JobParams.new
        params.append('cleanoutfiles', 'standard')
        workflow.add(params)

        tools = OpenStudio::Runmanager::ConfigOptions.makeTools(OpenStudio::Path.new(@options[:energyplus_path]),
                                                                OpenStudio::Path.new,
                                                                OpenStudio::Path.new,
                                                                $OpenStudio_RubyExeDir,
                                                                OpenStudio::Path.new)
        workflow.add(tools)
        # DLM: Elaine somehow we need to add info to data point to avoid this error:
        # [openstudio.analysis.AnalysisObject] <1> The json string cannot be parsed as an
        # OpenStudio analysis framework json file, because Unable to find ToolInfo object
        # at expected location.

        # queue the RunManager job
        @logger.info 'Queue RunManager Job'
        url_search_paths = OpenStudio::URLSearchPathVector.new
        weather_file_path = OpenStudio::Path.new
        if analysis.weatherFile
          weather_file_path = analysis.weatherFile.get.path
        end
        job = workflow.create(@run_directory, analysis.seed.path, weather_file_path, url_search_paths)
        OpenStudio::Runmanager::JobFactory.optimizeJobTree(job)
        analysis.setDataPointRunInformation(data_point, job, OpenStudio::PathVector.new)
        run_manager.enqueue(job, false)

        @logger.info 'Waiting for simulation to finish'

        if false
          # Get some introspection on what the current running job is. For now just
          # look at the directories that are being generated
          job_dirs = []
          while run_manager.workPending
            sleep 1
            OpenStudio::Application.instance.processEvents

            # check if there are any new folders that were creates
            temp_dirs = Dir[File.join(@run_directory.to_s, '*/')].map { |d| d.split('/').pop }.sort
            if (temp_dirs + job_dirs).uniq != job_dirs
              @logger.info "#{(temp_dirs - job_dirs).join(",")}"
              job_dirs = temp_dirs
            end
          end
        else
          run_manager.waitForFinished
        end

        @logger.info 'Simulation finished'

        # use the completed job to populate data_point with results
        @logger.info 'Updating OpenStudio DataPoint object'
        analysis.problem.updateDataPoint(data_point, job)

        @logger.info data_point

        @results = { pat_data_point: ::MultiJson.load(data_point.toJSON, symbolize_names: true) }

        # Savet this to the directory for debugging purposes
        File.open("#{@run_directory}/data_point_result.json", 'w') { |f| f << MultiJson.dump(@results, pretty: true) }

        fail 'Simulation Failed' if data_point.failed
      else
        fail 'Could not find analysis_json and datapoint_json'
      end

    rescue => e
      log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      fail log_message
    end

    @results
  end

end
