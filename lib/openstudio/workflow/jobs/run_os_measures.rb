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

# Run any OpenStudio measures contained in the OSW
class RunOpenStudioMeasures < OpenStudio::Workflow::Job

  # Mixin the required util modules
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::Measure
  include OpenStudio::Workflow::Util::Model

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"

    # Ensure output_attributes is initialized in the registry
    @registry.register(:output_attributes) { {} } unless @registry[:output_attributes]

    # Execute the OpenStudio measures
    @options[:output_adapter] = @output_adapter
    @logger.info 'Beginning to execute OpenStudio measures.'
    apply_measures(:openstudio, @registry, @options)
    @logger.info('Finished applying OpenStudio measures.')

    # Send the measure output attributes to the output adapter
    @logger.info 'Communicating measure output attributes to the output adapter'
    @output_adapter.communicate_measure_attributes @registry[:output_attributes]

    # Save the OSM if the :debug option is true
    return nil unless @options[:debug]
    @registry[:time_logger].start('Saving OSM') if @registry[:time_logger]
    osm_name = save_osm(@registry[:model], @registry[:root_dir])
    @registry[:time_logger].stop('Saving OSM') if @registry[:time_logger]
    @logger.info "Saved model as #{osm_name}"

    nil
  end
end
