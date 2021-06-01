# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

require_relative 'registry'
require_relative 'adapters/input/local'
require_relative 'adapters/output/local'

require 'logger'
require 'pathname'

# Run Class for OpenStudio workflow.  All comments here need some love, as well as the code itself
module OpenStudio
  module Workflow
    class Run
      attr_accessor :registry

      attr_reader :options, :input_adapter, :output_adapter, :final_message, :job_results, :current_state

      # Define the default set of jobs. Note that the states of :queued of :finished need to exist for all job arrays.
      #
      def self.default_jobs
        [
          { state: :queued, next_state: :initialization, options: { initial: true } },
          { state: :initialization, next_state: :os_measures, job: :RunInitialization,
            file: 'openstudio/workflow/jobs/run_initialization', options: {} },
          { state: :os_measures, next_state: :translator, job: :RunOpenStudioMeasures,
            file: 'openstudio/workflow/jobs/run_os_measures.rb', options: {} },
          { state: :translator, next_state: :ep_measures, job: :RunTranslation,
            file: 'openstudio/workflow/jobs/run_translation.rb', options: {} },
          { state: :ep_measures, next_state: :preprocess, job: :RunEnergyPlusMeasures,
            file: 'openstudio/workflow/jobs/run_ep_measures.rb', options: {} },
          { state: :preprocess, next_state: :simulation, job: :RunPreprocess,
            file: 'openstudio/workflow/jobs/run_preprocess.rb', options: {} },
          { state: :simulation, next_state: :reporting_measures, job: :RunEnergyPlus,
            file: 'openstudio/workflow/jobs/run_energyplus.rb', options: {} },
          { state: :reporting_measures, next_state: :postprocess, job: :RunReportingMeasures,
            file: 'openstudio/workflow/jobs/run_reporting_measures.rb', options: {} },
          { state: :postprocess, next_state: :finished, job: :RunPostprocess,
            file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
          { state: :finished },
          { state: :errored }
        ]
      end

      # Initialize a new run class
      #
      # @param [String] osw_path the path to the OSW file to run. It is highly recommended that this be an absolute
      #   path, however if not it will be made absolute relative to the current working directory
      # @param [Hash] user_options ({}) A set of user-specified options that are used to override default behaviors.
      # @option user_options [Hash] :cleanup Remove unneccessary files during post processing, overrides OSW option if set, defaults to true
      # @option user_options [Hash] :debug Print debugging messages, overrides OSW option if set, defaults to false
      # @option user_options [Hash] :energyplus_path Specifies path to energyplus executable, defaults to empty
      # @option user_options [Hash] :fast Speeds up workflow by skipping steps not needed for running simulations, defaults to false
      # @option user_options [Hash] :skip_zip_results Skips creating the data_point.zip file. Setting to `true` can cause issues with workflows expecting .zip files to signal completion (e.g., OpenStudio Analysis Framework), defaults to false
      # @option user_options [Hash] :jobs Simulation workflow, overrides jobs in OSW if set, defaults to default_jobs
      # @option user_options [Hash] :output_adapter Output adapter to use, overrides output adapter in OSW if set, defaults to local adapter
      # @option user_options [Hash] :preserve_run_dir Prevents run directory from being cleaned prior to run, overrides OSW option if set, defaults to false - DLM, Deprecate
      # @option user_options [Hash] :profile Produce additional output for profiling simulations, defaults to false
      # @option user_options [Hash] :skip_energyplus_preprocess Does not add add default output requests to EnergyPlus input if true, requests from reporting measures are added in either case, defaults to false
      # @option user_options [Hash] :skip_expand_objects Skips the call to the EnergyPlus ExpandObjects program, defaults to false
      # @option user_options [Hash] :targets Log targets to write to, defaults to standard out and run.log
      # @option user_options [Hash] :verify_osw Check OSW for correctness, defaults to true
      # @option user_options [Hash] :weather_file Initial weather file to load, overrides OSW option if set, defaults to empty
      def initialize(osw_path, user_options = {})
        # DLM - what is final_message?
        @final_message = ''
        @current_state = nil
        @options = {}

        # Registry is a large hash of objects that are populated during the run, the number of objects in the registry should be reduced over time, especially if the functionality can be added to the WorkflowJSON class
        # - analysis - the current OSA parsed as a Ruby Hash
        # - datapoint - the current OSD parsed as a Ruby Hash
        # - log_targets - IO devices that are being logged to
        # - logger - general logger
        # - model - the current OpenStudio Model object, updated after each step
        # - model_idf - the current EnergyPlus Workspace object, updated after each step
        # - openstudio_2 - true if we are running in OpenStudio 2.X environment
        # - osw_path - the path the OSW was loaded from as a string
        # - osw_dir - the directory the OSW was loaded from as a string
        # - output_attributes - added during simulation time
        # - results - objective function values
        # - root_dir - the root directory in the OSW as a string
        # - run_dir - the run directory for the simulation as a string
        # - runner - the current OSRunner object
        # - sql - the path to the current EnergyPlus SQL file as a string
        # - time_logger - logger for doing profiling - time to run each step will be captured in OSResult, deprecate
        # - wf - the path to the current weather file as a string, updated after each step
        # - workflow - the current OSW parsed as a Ruby Hash
        # - workflow_json - the current WorkflowJSON object
        @registry = Registry.new

        openstudio_2 = false
        begin
          # OpenStudio 2.X test
          OpenStudio::WorkflowJSON.new
          openstudio_2 = true
        rescue NameError => e
        end
        @registry.register(:openstudio_2) { openstudio_2 }

        # get the input osw
        @input_adapter = OpenStudio::Workflow::InputAdapter::Local.new(osw_path)

        # DLM: need to check that we have correct permissions to all these paths
        @registry.register(:osw_path) { Pathname.new(@input_adapter.osw_path).realpath }
        @registry.register(:osw_dir) { Pathname.new(@input_adapter.osw_dir).realpath }
        @registry.register(:run_dir) { Pathname.new(@input_adapter.run_dir).cleanpath } # run dir might not yet exist, calling realpath will throw

        # get info to set up logging first in case of failures later
        @options[:debug] = @input_adapter.debug(user_options, false)
        @options[:preserve_run_dir] = @input_adapter.preserve_run_dir(user_options, false)
        @options[:skip_expand_objects] = @input_adapter.skip_expand_objects(user_options, false)
        @options[:skip_energyplus_preprocess] = @input_adapter.skip_energyplus_preprocess(user_options, false)
        @options[:profile] = @input_adapter.profile(user_options, false)

        # if running in osw dir, force preserve run dir
        if @registry[:osw_dir] == @registry[:run_dir]
          # force preserving the run directory
          @options[:preserve_run_dir] = true
        end

        # By default blow away the entire run directory every time and recreate it
        if !@options[:preserve_run_dir] && File.exist?(@registry[:run_dir])
          # logger is not initialized yet (it needs run dir to exist for log)
          puts "Removing existing run directory #{@registry[:run_dir]}" if @options[:debug]

          # DLM: this is dangerous, we are calling rm_rf on a user entered directory, need to check this first
          # TODO: Echoing Dan's comment
          FileUtils.rm_rf(@registry[:run_dir])
        end
        FileUtils.mkdir_p(@registry[:run_dir])

        # set up logging after cleaning run dir
        if user_options[:targets]
          @options[:targets] = user_options[:targets]
        else
          # don't create these files unless we want to use them
          # DLM: TODO, make sure that run.log will be closed later
          @options[:targets] = [$stdout, File.open(File.join(@registry[:run_dir], 'run.log'), 'a')]
        end

        @registry.register(:log_targets) { @options[:targets] }
        @registry.register(:time_logger) { TimeLogger.new } if @options[:profile]

        # Initialize the MultiDelegator logger
        logger_level = @options[:debug] ? ::Logger::DEBUG : ::Logger::WARN
        @logger = ::Logger.new(MultiDelegator.delegate(:write, :close).to(*@options[:targets])) # * is the splat operator
        @logger.level = logger_level
        @registry.register(:logger) { @logger }

        @logger.info "openstudio_2 = #{@registry[:openstudio_2]}"

        # get the output adapter
        default_output_adapter = OpenStudio::Workflow::OutputAdapter::Local.new(output_directory: @input_adapter.run_dir)
        @output_adapter = @input_adapter.output_adapter(user_options, default_output_adapter, @logger)

        # get the jobs
        default_jobs = OpenStudio::Workflow::Run.default_jobs
        @jobs = @input_adapter.jobs(user_options, default_jobs, @logger)

        # get other run options out of user_options and into permanent options
        @options[:cleanup] = @input_adapter.cleanup(user_options, true)
        @options[:energyplus_path] = @input_adapter.energyplus_path(user_options, nil)
        @options[:verify_osw] = @input_adapter.verify_osw(user_options, true)
        @options[:weather_file] = @input_adapter.weather_file(user_options, nil)
        @options[:fast] = @input_adapter.fast(user_options, false)
        @options[:skip_zip_results] = @input_adapter.skip_zip_results(user_options, false)

        openstudio_dir = 'unknown'
        begin
          openstudio_dir = $OpenStudio_Dir
          if openstudio_dir.nil?
            openstudio_dir = OpenStudio.getOpenStudioModuleDirectory.to_s
          end
        rescue StandardError
        end
        @logger.info "openstudio_dir = #{openstudio_dir}"

        @logger.info "Initializing directory #{@registry[:run_dir]} for simulation with options #{@options}"

        # Define the state and transitions
        @current_state = :queued
      end

      # execute the workflow defined in the state object
      #
      # @todo add a catch if any job fails
      # @todo make a block method to provide feedback
      def run
        @logger.info "Starting workflow in #{@registry[:run_dir]}"
        begin
          next_state
          while @current_state != :finished && @current_state != :errored
            # sleep 2
            step
          end

          if !@options[:fast]
            @logger.info 'Finished workflow - communicating results and zipping files'
            @output_adapter.communicate_results(@registry[:run_dir], @registry[:results], @options[:skip_zip_results])
          end
        rescue StandardError => e
          @logger.info "Error occurred during running with #{e.message}"
        ensure
          @logger.info 'Workflow complete'

          # If we let the :reporting_measures step fail to continue with
          # postprocess, we still want to report and error
          if @final_message != ''
            @current_state = :errored
          end

          if @current_state == :errored
            @registry[:workflow_json]&.setCompletedStatus('Fail')
          else
            # completed status will already be set if workflow was halted
            if @registry[:workflow_json].completedStatus.empty?
              @registry[:workflow_json].setCompletedStatus('Success')
            else
              @current_state = :errored if @registry[:workflow_json].completedStatus.get == 'Fail'
            end
          end

          # save all files before calling output adapter
          @registry[:log_targets].each(&:flush)

          # save workflow with results
          if @registry[:workflow_json] && !@options[:fast]
            out_path = @registry[:workflow_json].absoluteOutPath
            @registry[:workflow_json].saveAs(out_path)
          end

          # Write out the TimeLogger to the filesystem
          @registry[:time_logger]&.save(File.join(@registry[:run_dir], 'profile.json'))

          if @current_state == :errored
            @output_adapter.communicate_failure
          else
            @output_adapter.communicate_complete
          end
        end

        @current_state
      end

      # Step through the states, if there is an error (e.g. exception) then go to error
      #
      def step
        step_instance = @jobs.find { |h| h[:state] == @current_state }
        require step_instance[:file]
        klass = OpenStudio::Workflow.new_class(step_instance[:job], @input_adapter, @output_adapter, @registry, @options)
        @output_adapter.communicate_transition("Starting state #{@current_state}", :state)
        state_return = klass.perform
        if state_return
          @output_adapter.communicate_transition("Returned from state #{@current_state} with message #{state_return}", :state)
        else
          @output_adapter.communicate_transition("Returned from state #{@current_state}", :state)
        end
        next_state
      rescue StandardError => e
        step_error("#{e.message}:#{e.backtrace.join("\n")}")
      end

      # Error handling for when there is an exception running any of the state transitions
      #
      def step_error(*args)
        # Make sure to set the instance variable @error to true in order to stop the :step
        # event from being fired.

        # Allow continuing anyways if it fails in reporting measures
        if @current_state == :reporting_measures
          @final_message = "Found error in state '#{@current_state}' with message #{args}}"
          @logger.error @final_message

          next_state
        else
          @final_message = "Found error in state '#{@current_state}' with message #{args}}"
          @logger.error @final_message

          # transition to an error state
          @current_state = :errored
        end
      end

      # Return the finished state and exit
      #
      def run_finished(_, _, _)
        logger.info "Running #{__method__}"

        @current_state
      end

      private

      # Advance the @current_state to the next state
      #
      def next_state
        @logger.info "Current state: '#{@current_state}'"
        ns = @jobs.find { |h| h[:state] == @current_state }[:next_state]
        @logger.info "Next state will be: '#{ns}'"
        @current_state = ns
      end
    end
  end
end
