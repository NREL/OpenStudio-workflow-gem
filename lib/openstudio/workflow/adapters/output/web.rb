# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require_relative 'local'

# Local file based workflow
module OpenStudio
  module Workflow
    module OutputAdapter
      class Web < Local
        def initialize(options = {})
          super
          raise 'The required :url option was not passed to the web output adapter' unless options[:url]
        end

        def communicate_objective_function(objectives, options = {})
          super
        end

        def communicate_transition(message, type, options = {})
          super
        end

        def communicate_energyplus_stdout(line, options = {})
          super
        end

        def communicate_measure_result(result, options = {})
          super
        end
      end
    end
  end
end
