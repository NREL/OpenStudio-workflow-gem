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

require_relative '../output_adapter'

# Local file based workflow
module OpenStudio
  module Workflow
    module Adapters
      class Local < OutputAdapter
        def initialize(options = {})
          defaults = {
            log_results: false,
            log_measure_attributes: false,
            log_objective_function: false,
            zip_results: false,
            transition_types: %i{state measure}
          }
          options = defaults.merge(options)
          @adapter_logger = ::Logger.new(STDOUT)
          @adapter_logger.level = ::Logger.INFO
          super
        end

        # Report that the workflow has started
        #
        def communicate_started
          @adapter_logger.info "Started Workflow #{::Time.now}"
        end

        # Report that the workflow has completed
        #
        def communicate_complete
          @adapter_logger.info "Finished Workflow #{::Time.now}"
        end

        # Report that the workflow has hit a transition
        #
        def communicate_transition(message, type, _=nil)
          return unless @options[:transition_types].include type
          @adapter_logger.info "Transition of type #{type.to_s} with message #{message}"
        end

        # Report out the measure attributes if the :log_measure_attributes option is set to true
        #
        def communicate_measure_attributes(measure_attributes, _=nil)
          return unless @options[:log_measure_attributes]
          if measure_attributes.is_a? Hash
            @adapter_logger.info JSON.pretty_generate(measure_attributes)
          else
            @adapter_logger.error "Unknown measure attribute type. Please handle #{measure_attributes.class}"
          end
        end

        # Report out the object function results if the :log_object_function option is set to true
        #
        def communicate_objective_function(objectives, _=nil)
          return unless @options[:log_objective_function]
          if objectives.is_a? Hash
            @adapter_logger.info JSON.pretty_generate(objectives)
          else
            @adapter_logger.error "Unknown objective function type. Please handle #{objectives.class}"
          end
        end

        # Report that the workflow has erred
        #
        def communicate_failure
          @adapter_logger.info "Failed Workflow #{::Time.now}"
        end

        # Report out the results if the :log_results option is set to true and zip results if the :zip_results option is
        #   set to true
        #
        def communicate_results(directory, results)
          zip_results(directory) if @options[:zip_results]

          return unless @options[:log_results]
          if results.is_a? Hash
            @adapter_logger.info JSON.pretty_generate(results)
          else
            @adapter_logger.error "Unknown datapoint result type. Please handle #{results.class}"
          end
        end
      end
    end
  end
end
