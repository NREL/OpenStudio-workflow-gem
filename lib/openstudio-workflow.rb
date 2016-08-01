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
require 'zip'

require_relative 'openstudio/workflow/version'
require_relative 'openstudio/workflow/multi_delegator'
require_relative 'openstudio/workflow/run'
require_relative 'openstudio/workflow/job'
require_relative 'openstudio/workflow/time_logger'
require_relative 'openstudio/workflow/registry'
require_relative 'openstudio/workflow/util'
require 'openstudio'
require_relative 'openstudio/workflow_runner'


# some core extensions
# @todo (rhorsey) is this really needed? extensions to built in classes are not a great idea, they may conflict with other people's code - DLM
class String
  def to_underscore
    gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
  end
end

module OpenStudio

  module Workflow
    extend self

    # Log the message sent to the logger
    def logger(targets=nil, logger_level = nil)
      @logger ||= Proc.new{ l = ::Logger.new(MultiDelegator.delegate(:write, :close).to(*targets)) ; l.level = logger_level if logger_level ; l }.call
    end

    # Extract an archive to a specific location
    #
    # @param archive_filename [String] Path and name of the file to extract
    # @param destination [String] Path to extract to
    # @param overwrite [Boolean] If true, will overwrite any extracted file that may already exist
    # @todo (rhorsey, macumber) Replace rubyzip with OS zip
    #
    def extract_archive(archive_filename, destination, overwrite = true)
      ::Zip::File.open(archive_filename) do |zf|
        zf.each do |f|
          f_path = File.join(destination, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))

          if File.exist?(f_path) && overwrite
            FileUtils.rm_rf(f_path)
            zf.extract(f, f_path)
          elsif !File.exist? f_path
            zf.extract(f, f_path)
          end
        end
      end
    end

  end
end
