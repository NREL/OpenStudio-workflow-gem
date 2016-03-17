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

# Run the initialization job to run validations and initializations
class RunInit < OpenStudio::Workflow::Job

  require_relative '../util/measure'

  def initialize(directory, time_logger, adapter, workflow_arguments, options = {})
    super
  end

  # This method starts the adapter and verifies the OSW if the options contain verify_osw
  # @todo See about moving the workflow and root_dir into the initialize
  def perform
    logger.info "Calling #{__method__} in the #{self.class} class"

    @adapter.communicate_started @directory, @options

    if @options[:verify_osw]
      @workflow = @adapter.get_workflow @directory, @options
      @workflow['root_dir'] ? @root_dir = @workflow['root_dir'] : @root_dir = '.'
      validate_measures(@workflow, @root_dir, @logger)
    end

    # return the results back to the caller -- always
    @results
  end
end
