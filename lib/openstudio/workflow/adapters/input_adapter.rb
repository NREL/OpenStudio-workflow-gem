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

# Adapter class to decide where to obtain instructions to run the simulation workflow
module OpenStudio
  module Workflow

    # Base class for input adapters. These methods define the expected interface for different input adapters
    class InputAdapters
      attr_accessor :options

      def initialize(options = {})
        @options = options
        @log = nil
        @datapoint = nil
      end

      def get_workflow(id)
        instance.get_workflow id
      end

      def get_datapoint(id)
        instance.get_datapoint id
      end

      def get_problem(id)
        instance.get_problem id
      end

      def base_directory(id)
        instance.base_directory id
      end

      def run_directory(id)
        instance.run_directory id
      end
    end
  end
end
