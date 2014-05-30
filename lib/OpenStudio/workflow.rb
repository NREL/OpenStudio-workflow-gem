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

begin
  require 'facter'
rescue LoadError => e
  puts 'Could not load Facter. Will not be able to save the IP address to the log'.red
end

require_relative 'workflow/version'
require_relative 'workflow/multi_delegator'
require_relative 'workflow/run'

begin
  require 'openstudio'
  $openstudio_gem = true
rescue LoadError => e
  $openstudio_gem = false
  puts 'OpenStudio did not load, but most functionality is still available. Will try to continue...'.red
end

module OpenStudio
  module Workflow
    extend self

    # Create a new workflow instance using the defined adapter and UUID
    def load(adapter_name, run_directory, options={})
      defaults = {adapter_options: {}}
      options = defaults.merge(options)
      adapter = load_adapter adapter_name, options[:adapter_options]
      run_klass = OpenStudio::Workflow::Run.new(adapter, run_directory, options)
      # return the run class
      run_klass
    end

    private

    def load_adapter(name, adapter_options={})
      require_relative "workflow/adapters/#{name.downcase}"
      klass_name = name.to_s.split('_').map(&:capitalize) * ''
      #pp "#{klass_name} is the adapter class name"
      klass = OpenStudio::Workflow::Adapters.const_get(klass_name).new(adapter_options)
      klass
    end
  end
end
