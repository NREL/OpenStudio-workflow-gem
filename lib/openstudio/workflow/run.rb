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

require_relative 'registry'
require_relative 'adapters/input/local'
require_relative 'adapters/output/local'

require 'logger'

# Run Class for OpenStudio workflow.  All comments here need some love, as well as the code itself
module OpenStudio
  module Workflow
    class Run

      attr_accessor :registry

      attr_reader :options
      attr_reader :input_adapter
      attr_reader :output_adapter
      attr_reader :final_message 
      attr_reader :job_results

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
            file: 'openstudio/workflow/jobs/run_preprocess.rb' , options: {} },
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
      # @param [Hash] options ({}) A set of user-specified options that are used to override default behaviors. Some
      #   sort of definitive documentation is needed for this hash
      # @option options [Hash] :transitions Non-default transitions set (see Run#default_transition)
      # @option options [Hash] :states Non-default states set (see Run#default_states)
      # @option options [Hash] :jobs ???
      # @todo (rhorsey) establish definitive documentation on all option parameters
      #
      def initialize(osw_path, options = {})
        
        # DLM - what is final_message?
        @final_message = ''
        @current_state = nil
        
        # Registry is a large hash of objects that are populated during the run, the number of objects in the registry should be reduced over time
        # - openstudio_2 - true if we are running in OpenStudio 2.X environment
        # - logger - general logger - this is already a module constant, deprecate
        # - time_logger - logger for doing profiling - time to run each step will be captured in OSResult, deprecate
        # - workflow - the current OSW parsed as a Ruby Hash
        # - workflow_json - the current WorkflowJSON object
        # - osw_dir - the directory the OSW was loaded from as a string
        # - root_dir - the root directory in the OSW as a string
        # - run_dir - the run directory for the simulation as a string
        # - datapoint - the current OSD parsed as a Ruby Hash
        # - analysis - the current OSA parsed as a Ruby Hash
        # - runner - the current OSRunner object
        # - model - the current OpenStudio Model object, updated after each step
        # - model_idf - the current EnergyPlus Workspace object, updated after each step
        # - wf - the path to the current weather file as a string, updated after each step
        # - output_attributes - ? - deprecate
        # - sql - the path to the current EnergyPlus SQL file as a string
        @registry = Registry.new
        
        openstudio_2 = false
        begin
          # OpenStudio 2.X test
          OpenStudio::WorkflowJSON.new()
          openstudio_2 = true
        rescue NameError => e 
        end
        @registry.register(:openstudio_2) { openstudio_2 }
        
        # get the input osw
        @input_adapter = OpenStudio::Workflow::InputAdapter::Local.new(osw_path)

        # create the output adapter
        if options[:output_adapter]
          @output_adapter = options[:output_adapter]
        else
          @output_adapter = OpenStudio::Workflow::OutputAdapter::Local.new({output_directory: @input_adapter.run_dir})
        end
        
        @registry.register(:osw_path) { @input_adapter.osw_path }
        @registry.register(:osw_dir) { @input_adapter.osw_dir }
        @registry.register(:run_dir) { @input_adapter.run_dir }
        
        # DLM: need to check that we have correct permissions to all these paths
        
        # By default blow away the entire run directory every time and recreate it
        if !options[:preserve_run_dir]
          
          if File.exist?(@registry[:run_dir])
            # logger is not initialized yet (it needs run dir to exist for log)
            puts "Removing existing run directory #{@registry[:run_dir]}" if options[:debug]
          
            # DLM: this is dangerous, we are calling rm_rf on a user entered directory, need to check this first
            FileUtils.rm_rf(@registry[:run_dir])
          end
        end
        FileUtils.mkdir_p(@registry[:run_dir])
        
        defaults = {
          jobs: OpenStudio::Workflow::Run.default_jobs,
          targets: [STDOUT, File.open(File.join(@registry[:run_dir], 'run.log'), 'a')],
          preserve_run_dir: false,
          debug: false,
          profile: true
        }
        @options = defaults.merge(options)
 
        @registry.register(:time_logger) { TimeLogger.new } if @options[:profile]

        # Initialize the MultiDelegator logger
        logger_level = @options[:debug] ? ::Logger::DEBUG : ::Logger::WARN
        Workflow.logger(@options[:targets], logger_level)
        @registry.register(:logger) { Workflow.logger }
        
        Workflow.logger.info "openstudio_2 = #{@registry[:openstudio_2]}"
        
        Workflow.logger.info "Initializing directory #{@registry[:run_dir]} for simulation with options #{@options}"
         
        # Define the state and transitions
        @current_state = :queued
        @jobs = @options[:jobs]
      end

      # execute the workflow defined in the state object
      #
      # @todo add a catch if any job fails
      # @todo make a block method to provide feedback
      def run
        Workflow.logger.info "Starting workflow in #{@registry[:run_dir]}"
        begin
          next_state
          while @current_state != :finished && @current_state != :errored
            sleep 2
            step
          end

          Workflow.logger.info 'Finished workflow - communicating results and zipping files'
        ensure
          if @current_state == :errored
            @output_adapter.communicate_failure
          else
            @output_adapter.communicate_complete
          end

          Workflow.logger.info 'Workflow complete'

          # Write out the TimeLogger to the filesystem
          @registry[:time_logger].save(File.join(@registry[:run_dir], 'profile.json')) if @registry[:time_logger]
          
          # save workflow with results
          @registry[:workflow_json].setCompletedStatus('Success')
          
          out_path = @registry[:workflow_json].absoluteOutPath
          @registry[:workflow_json].saveAs(out_path)

        end

        @current_state
      end

      # Step through the states, if there is an error (e.g. exception) then go to error
      #
      def step
        step_instance = @jobs.find { |h| h[:state] == @current_state }
        require step_instance[:file]
        klass = OpenStudio::Workflow.new_class(step_instance[:job], @input_adapter, @output_adapter, @registry, options)
        @output_adapter.communicate_transition("Starting state #{@current_state}", :state)
        state_return = klass.perform
        if state_return
          @output_adapter.communicate_transition("Returned from state #{@current_state} with message #{state_return}", :state)
        else
          @output_adapter.communicate_transition("Returned from state #{@current_state}", :state)
        end
        next_state
      rescue => e
        step_error("#{e.message}:#{e.backtrace.join("\n")}")
      end

      # Error handling for when there is an exception running any of the state transitions
      #
      def step_error(*args)
        # Make sure to set the instance variable @error to true in order to stop the :step
        # event from being fired.
        @final_message = "Found error in state '#{@current_state}' with message #{args}}"
        Workflow.logger.error @final_message

        @registry[:workflow_json].setCompletedStatus('Fail')
        
        # transition to an error state
        @current_state = :errored
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
        Workflow.logger.info "Current state: '#{@current_state}'"
        ns = @jobs.find { |h| h[:state] == @current_state }[:next_state]
        Workflow.logger.info "Next state will be: '#{ns}'"
        @current_state = ns
      end
    end
  end
end
