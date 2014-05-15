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
    class Adapter

      attr_accessor :options

      def initialize(options={})
        @options = options
        @log = nil
      end

      #class << self
      #attr_reader :problem

      def load(filename, options={})
        instance.load(filename, options)
      end

      def communicate_started(id, options = {})
        instance.communicate_started id
      end

      def get_datapoint(id, options={})
        instance.get_datapoint id, options
      end

      def get_problem(id, options = {})
        instance.get_problem id, options
      end

      def communicate_results(id, results)
        instance.communicate_results id, results
      end

      def communicate_complete(id)
        instance.communicate_complete id
      end

      def communicate_failure(id)
        instance.communicate_failure id
      end

      def get_logger(file)
        instance.get_logger file
      end
    end
  end
end