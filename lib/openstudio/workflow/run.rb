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
      include AASM

      attr_accessor :logger

      attr_reader :options
      attr_reader :adapter
      attr_reader :directory
      attr_reader :run_directory
      attr_reader :final_state
      attr_reader :job_results


      # Create a nice name for the state object instead of aasm
      alias state aasm

      # load the transitions
      def self.default_transition
        # TODO: replace these with dynamic states from a config file of some sort
        [
            {from: :queued, to: :preflight},
            {from: :preflight, to: :openstudio},
            {from: :openstudio, to: :energyplus},
            {from: :energyplus, to: :postprocess},
            {from: :postprocess, to: :finished},
        ]
      end

      # The default states for the workflow.  Note that the states of :queued of :finished need
      # to exist for all cases.
      def self.default_states
        # TODO: replace this with some sort of dynamic store
        [
            {state: :queued, :options => {initial: true}},
            {state: :preflight, :options => {after_enter: :run_preflight}},
            {state: :openstudio, :options => {after_enter: :run_openstudio}},
            {state: :energyplus, :options => {after_enter: :run_energyplus}},
            {state: :postprocess, :options => {after_enter: :run_postprocess}},
            {state: :finished},
            {state: :errored}
        ]
      end

      # initialize a new run class
      #
      # @param adapter an instance of the adapter class
      # @param directory location of the datapoint directory to run. This is needed
      #        independent of the adapter that is being used. Note that the simulation will actually run in 'run'
      def initialize(adapter, directory, options = {})
        @adapter = adapter
        @directory = directory
        # TODO: run directory is a convention right now. Move to a configuration item
        @run_directory = "#{@directory}/run"

        defaults = {
            transitions: OpenStudio::Workflow::Run.default_transition,
            states: OpenStudio::Workflow::Run.default_states,
            jobs: {}
        }
        @options = defaults.merge(options)

        @error = false

        @job_results = {}

        # By default blow away the entire run directory every time and recreate it
        FileUtils.rm_rf(@run_directory) if File.exist?(@run_directory)
        FileUtils.mkdir_p(@run_directory)

        # There is a namespace conflict when OpenStudio is loaded: be careful!
        log_file = File.open("#{@run_directory}/run.log", "a")

        l = @adapter.get_logger @directory, @options
        if l
          @logger = ::Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, log_file, l)
        else
          @logger = ::Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, log_file)
        end

        @logger.info "Initializing directory #{@directory} for simulation with options #{@options}"

        super()

        # load the state machine
        machine
      end

      # run the simulations.
      # TODO: add a catch if any job fails; TODO: make a block method to provide feedback
      def run
        @logger.info "Starting workflow in #{@directory}"
        begin
          while self.state.current_state != :finished && !@error
            self.step
          end

          @logger.info 'Finished workflow - communicating results and zipping files'

          # TODO: this should be a job that handles the use case with a :guard on if @job_results[:run_postprocess]
          if @job_results[:run_postprocess]
            # these are the results that need to be sent back to adapter
            @logger.info "Sending the results back to the adapter"
            #@logger.info "Sending communicate_results the following options #{@job_results}"
            @adapter.communicate_results @directory, @job_results[:run_postprocess]
          end
        ensure
          if @error
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

        state.current_state
      end

      # call back for when there is an exception running any of the state transitions
      def step_error(*args)
        # Make sure to set the instance variable @error to true in order to stop the :step
        # event from being fired.
        @error = true
        @logger.error "Found error in state '#{aasm.current_state}' with message #{args}}"

        # Call the error_out event to transition to the :errored state
        error_out
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

      def final_state
        state.current_state
      end

      private

      # Create a state machine from the predefined transitions methods.  This loads in
      # a single event of :step which steps through the transitions defined in the Hash in default_transitions
      # and calls the actions defined in the states in the Hash of default_states
      def machine
        @logger.info "Initializing state machine"
        @options[:states].each do |s|
          s[:options] ? o = s[:options] : o = {}
          OpenStudio::Workflow::Run.aasm.states << AASM::State.new(s[:state], self.class, o)
        end
        OpenStudio::Workflow::Run.aasm.initial_state(:queued)

        # Create a new event and add in the transitions
        new_event = OpenStudio::Workflow::Run.aasm.event(:step)
        event = OpenStudio::Workflow::Run.aasm.events[:step]

        # TODO: make a config option to not go to the error state. Useful to not error-state when testing
        event.options[:error] = 'step_error'
        @options[:transitions].each do |t|
          event.transitions(t)
        end

        # Add in special event to error_out the state machine
        new_event = OpenStudio::Workflow::Run.aasm.event(:error_out)
        event = OpenStudio::Workflow::Run.aasm.events[:error_out]
        event.transitions(:to => :errored)
      end

      # Get any options that may have been sent into the class defining the workflow step
      def get_job_options
        result = {}
        #if @options[:jobs].has_key?(state.current_state)
        #logger.info "Retrieving job options from the @options array for #{state.current_state}"
        #  result = @options[:jobs][state.current_state]
        #end

        #result

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