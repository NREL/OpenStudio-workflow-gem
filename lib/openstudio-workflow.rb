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

require 'aasm'
require 'pp'
require 'multi_json'
require 'colored'
require 'fileutils'
require 'json' # needed for a single pretty generate call
require 'pathname'

begin
  require 'facter'
rescue LoadError => e
  puts 'Could not load Facter. Will not be able to save the IP address to the log'.red
end

require 'openstudio/workflow/version'
require 'openstudio/workflow/multi_delegator'
require 'openstudio/workflow/run'
require 'openstudio/workflow/jobs/lib/apply_measures'

begin
  require 'openstudio'
  $openstudio_gem = true
rescue LoadError => e
  $openstudio_gem = false
  puts 'OpenStudio did not load, but most functionality is still available. Will try to continue...'.red
end

# some core extensions
class String
  def snake_case
    self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
  end
end

module OpenStudio
  module Workflow
    extend self

    # Create a new workflow instance using the defined adapter and UUID
    def load(adapter_name, run_directory, options={})
      defaults = {adapter_options: {}}
      options = defaults.merge(options)

      # Convert various paths to absolute paths
      if options[:adapter_options] && options[:adapter_options][:mongoid_path] &&
          (Pathname.new options[:adapter_options][:mongoid_path]).absolute? == false
        options[:adapter_options][:mongoid_path] = File.expand_path options[:adapter_options][:mongoid_path]
      end
      if options[:analysis_root_path] &&
          (Pathname.new options[:analysis_root_path]).absolute? == false
        options[:analysis_root_path] = File.expand_path options[:analysis_root_path]
      end
      unless (Pathname.new run_directory).absolute?
        # relateive to wherever you are running the script
        run_directory = File.expand_path run_directory
      end
      adapter = load_adapter adapter_name, options[:adapter_options]
      run_klass = OpenStudio::Workflow::Run.new(adapter, run_directory, options)
      # return the run class
      run_klass
    end

    private

    def load_adapter(name, adapter_options={})
      require "openstudio/workflow/adapters/#{name.downcase}"
      klass_name = name.to_s.split('_').map(&:capitalize) * ''
      #pp "#{klass_name} is the adapter class name"
      klass = OpenStudio::Workflow::Adapters.const_get(klass_name).new(adapter_options)
      klass
    end
  end
end
