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

# Run Prelight job to prepare the directory for simulations.
class RunPreflight
  def initialize(directory, logger, time_logger, adapter, workflow_arguments, options = {})
    defaults = {}
    @options = defaults.merge(options)
    @directory = directory
    @adapter = adapter
    @logger = logger
    @time_logger = time_logger
    @workflow_arguments = workflow_arguments
    @results = {}
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"

    @adapter.communicate_started @directory, @options

    # At the moment this does nothing.

    # return the results back to the caller -- always
    @results
  end
end
