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

require 'fileutils'
require 'json'
require 'pathname'

require_relative 'openstudio/workflow/version'
require_relative 'openstudio/workflow/multi_delegator'
require_relative 'openstudio/workflow/run'
require_relative 'openstudio/workflow/job'
require_relative 'openstudio/workflow/time_logger'
require_relative 'openstudio/workflow/registry'
require_relative 'openstudio/workflow/util'
require 'openstudio'
require_relative 'openstudio/workflow_runner'

module OpenStudio
  module Workflow
    extend self

    # Extract an archive to a specific location
    #
    # @param archive_filename [String] Path and name of the file to extract
    # @param destination [String] Path to extract to
    # @param overwrite [Boolean] If true, will overwrite any extracted file that may already exist
    #
    def extract_archive(archive_filename, destination, overwrite = true)
      zf = OpenStudio::UnzipFile.new(archive_filename)
      zf.extractAllFiles(destination)
    end
  end
end
