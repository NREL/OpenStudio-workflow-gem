# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require_relative 'local'
require 'socket'

# Local file based workflow
module OpenStudio
  module Workflow
    module OutputAdapter
      class Socket < Local
        def initialize(options = {})
          super
          raise 'The required :port option was not passed to the socket output adapter' unless options[:port]

          @socket = TCPSocket.open 'localhost', options[:port]
        end

        def communicate_started
          super
          @socket.write("Started\n")
        end

        def communicate_complete
          super
          @socket.write("Complete\n")
        end

        def communicate_failure
          super
          @socket.write("Failure\n")
        end

        def communicate_objective_function(objectives, options = {})
          super
        end

        def communicate_transition(message, type, options = {})
          super
          @socket.write("#{message}\n")
        end

        def communicate_energyplus_stdout(line, options = {})
          super
          @socket.write(line)
        end

        def communicate_measure_result(result, options = {})
          super

          step_result = result.stepResult
          initial_condition = result.stepInitialCondition
          final_condition = result.stepFinalCondition
          errors = result.stepErrors
          warnings = result.stepWarnings
          infos = result.stepInfo

          # Mirrors WorkflowStepResult::string
          tab = '  '
          @socket.write("#{tab}Result: #{step_result.get.valueName}\n") if !step_result.empty?
          @socket.write("#{tab}Initial Condition: #{initial_condition.get}\n") if !initial_condition.empty?
          @socket.write("#{tab}Final Condition: #{final_condition.get}\n") if !final_condition.empty?
          errors.each { |error| @socket.write("#{tab}Error: #{error}\n") }
          warnings.each { |warning| @socket.write("#{tab}Warn: #{warning}\n") }
          infos.each { |info| @socket.write("#{tab}Info: #{info}\n") }
        end
      end
    end
  end
end
