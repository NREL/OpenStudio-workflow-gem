# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

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
    module_function

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
