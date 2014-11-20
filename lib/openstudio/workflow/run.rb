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

# Run Class for OpenStudio workflow.  The data are passed in via the adapter
module OpenStudio
  module Workflow
    class Run
      attr_accessor :logger

      attr_reader :options
      attr_reader :adapter
      attr_reader :directory
      attr_reader :run_directory
      attr_reader :final_state
      attr_reader :final_message
      attr_reader :job_results

      # load the transitions
      def self.default_transition
        [
            {from: :queued, to: :preflight},
            {from: :preflight, to: :openstudio},
            {from: :openstudio, to: :energyplus},
            {from: :energyplus, to: :reporting_measures},
            {from: :reporting_measures, to: :postprocess},
            {from: :postprocess, to: :finished}
        ]
      end

      # The default states for the workflow.  Note that the states of :queued of :finished need
      # to exist for all cases.
      def self.default_states
        warn "[Deprecation Warning] explicitly specifying states will no longer be required in 0.3.0. Method #{__method__}"
        [
            {state: :queued, options: {initial: true}},
            {state: :preflight, options: {after_enter: :run_preflight}},
            {state: :openstudio, options: {after_enter: :run_openstudio}}, # TODO: this should be run_openstudio_measures and run_energyplus_measures
            {state: :energyplus, options: {after_enter: :run_energyplus}},
            {state: :reporting_measures, options: {after_enter: :run_reporting_measures}},
            {state: :postprocess, options: {after_enter: :run_postprocess}},
            {state: :finished},
            {state: :errored}
        ]
      end

      # transitions for pat job
      def self.pat_transition
        [
            {from: :queued, to: :preflight},
            {from: :preflight, to: :runmanager},
            {from: :runmanager, to: :postprocess},
            {from: :postprocess, to: :finished}
        ]
      end

      # states for pat job
      def self.pat_states
        warn "[Deprecation Warning] explicitly specifying states will no longer be required in 0.3.0. Method #{__method__}"
        [
            {state: :queued, options: {initial: true}},
            {state: :preflight, options: {after_enter: :run_preflight}},
            {state: :runmanager, options: {after_enter: :run_runmanager}},
            {state: :postprocess, options: {after_enter: :run_postprocess}},
            {state: :finished},
            {state: :errored}
        ]
      end

      # initialize a new run class
      #
      # @param adapter an instance of the adapter class
      # @param directory location of the datapoint directory to run. This is needed
      #        independent of the adapter that is being used. Note that the simulation will actually run in 'run'
      # @param options that are sent to the adapters
      def initialize(adapter, directory, options = {})
        @adapter = adapter
        @final_message = ''
        @current_state = nil
        @transitions = {}
        @directory = directory
        # TODO: run directory is a convention right now. Move to a configuration item
        @run_directory = "#{@directory}/run"

        defaults = nil
        if options[:is_pat]
          defaults = {
              transitions: OpenStudio::Workflow::Run.pat_transition,
              states: OpenStudio::Workflow::Run.pat_states,
              jobs: {}
          }
        else
          defaults = {
              transitions: OpenStudio::Workflow::Run.default_transition,
              states: OpenStudio::Workflow::Run.default_states,
              jobs: {}
          }
        end
        @options = defaults.merge(options)

        @job_results = {}

        # By default blow away the entire run directory every time and recreate it
        FileUtils.rm_rf(@run_directory) if File.exist?(@run_directory)
        FileUtils.mkdir_p(@run_directory)

        # There is a namespace conflict when OpenStudio is loaded: be careful!
        log_file = File.open("#{@run_directory}/run.log", 'a')

        l = @adapter.get_logger @directory, @options
        if l
          @logger = ::Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, log_file, l)
        else
          @logger = ::Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, log_file)
        end

        @logger.info "Initializing directory #{@directory} for simulation with options #{@options}"
        @logger.info "OpenStudio loaded: '#{$openstudio_gem}'"

        # load the state machine
        machine
      end

      # run the simulations.
      # TODO: add a catch if any job fails; TODO: make a block method to provide feedback
      def run
        @logger.info "Starting workflow in #{@directory}"
        begin
          while @current_state != :finished && @current_state != :errored
            sleep 2
            step
          end

          @logger.info 'Finished workflow - communicating results and zipping files'

          # TODO: this should be a job that handles the use case with a :guard on if @job_results[:run_postprocess]
          # or @job_results[:run_reporting_measures]
          # these are the results that need to be sent back to adapter
          if @job_results[:run_runmanager]
            @logger.info 'Sending the run_runmananger results back to the adapter'
            @adapter.communicate_results @directory, @job_results[:run_runmanager]
          elsif @job_results[:run_reporting_measures]
            @logger.info 'Sending the reporting measuers results back to the adapter'
            @adapter.communicate_results @directory, @job_results[:run_reporting_measures]
          end
        ensure
          if @current_state == :errored
            @adapter.communicate_failure @directory
          else
            @adapter.communicate_complete @directory
          end

          @logger.info 'Workflow complete'

          # TODO: define the outputs and figure out how to show it correctory
          obj_function_array ||= ['NA']

          # Print the objective functions to the screen even though the file is being used right now
          # Note as well that we can't guarantee that the csv format will be in the right order
          puts obj_function_array.join(',')
        end

        @current_state
      end

      # Step through the states, if there is an error (e.g. exception) then go to error
      def step(*args)
        begin
          next_state

          send("run_#{@current_state}")
        rescue => e
          step_error("#{e.message}:#{e.backtrace.join("\n")}")
        end
      end

      # call back for when there is an exception running any of the state transitions
      def step_error(*args)
        # Make sure to set the instance variable @error to true in order to stop the :step
        # event from being fired.
        @final_message = "Found error in state '#{@current_state}' with message #{args}}"
        @logger.error @final_message

        # transition to an error state
        @current_state = :errored
      end

      # TODO: these methods needs to be dynamic or inherited
      # run energplus
      def run_energyplus
        @logger.info "Running #{__method__}"
        klass = get_run_class(__method__)

        @job_results[__method__.to_sym] = klass.perform
      end

      # run openstudio to create the model and apply the measures
      def run_openstudio
        @logger.info "Running #{__method__}"
        klass = get_run_class(__method__)

        # TODO: save the resulting filenames to an array
        @job_results[__method__.to_sym] = klass.perform
      end

      # run a pat file using runmanager
      def run_runmanager
        @logger.info "Running #{__method__}"
        klass = get_run_class(__method__)

        # TODO: save the resulting filenames to an array
        @job_results[__method__.to_sym] = klass.perform
      end

      # run reporting measures
      def run_reporting_measures
        @logger.info "Running #{__method__}"
        klass = get_run_class(__method__)

        # TODO: save the resulting filenames to an array
        @job_results[__method__.to_sym] = klass.perform
      end

      def run_postprocess
        @logger.info "Running #{__method__}"
        klass = get_run_class(__method__)

        @job_results[__method__.to_sym] = klass.perform
      end

      # preconfigured run method for preflight. This configures the input directories and sets everything
      # up for running the simulations.
      def run_preflight
        @logger.info "Running #{__method__}"
        klass = get_run_class(__method__)

        @job_results[__method__.to_sym] = klass.perform
      end

      def run_xml
        @logger.info "Running #{__method__}"
        klass = get_run_class(__method__)

        @job_results[__method__.to_sym] = klass.perform
        @logger.info @job_results
      end

      # last method that is called.
      def run_finished
        @logger.info "Running #{__method__}"

        @current_state
      end
      alias_method :final_state, :run_finished

      private

      # Create a state machine from the predefined transitions methods.  This will initialize in the :queued state
      # and then load in the transitions from the @options hash
      def machine
        @logger.info 'Initializing state machine'
        @current_state = :queued

        @transitions = @options[:transitions]
      end

      def next_state
        @logger.info "Current state: '#{@current_state}'"
        ns = @transitions.select{ |h| h[:from] == @current_state}.first[:to]
        @logger.info "Next state will be: '#{ns}'"

        # Set the next state before calling the method
        @current_state = ns

        # do not return anything, the step method uses the @current_state variable to call run_#{next_state}
      end

      # Get any options that may have been sent into the class defining the workflow step
      def get_job_options
        result = {}
        # if @options[:jobs].has_key?(@current_state)
        # logger.info "Retrieving job options from the @options array for #{state.current_state}"
        #  result = @options[:jobs][@current_state]
        # end

        # result

        # TODO fix this so that it gets the base config options plus its job options. Need to
        # also merge in all the former job results.
        @options.merge(@job_results)
      end

      def get_run_class(from_method)
        require_relative "jobs/#{from_method}/#{from_method}"
        klass_name = from_method.to_s.split('_').map(&:capitalize) * ''
        @logger.info "Getting method for state transition '#{from_method}'"
        klass = Object.const_get(klass_name).new(@directory, @logger, @adapter, get_job_options)
        klass
      end
    end
  end
end
