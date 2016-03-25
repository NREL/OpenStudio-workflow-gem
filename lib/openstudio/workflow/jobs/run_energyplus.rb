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

class RunEnergyPlus < OpenStudio::Workflow::Job

  require_relative '../util/energyplus'
  include OpenStudio::Workflow::Util::EnergyPlus

  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(adapter, registry, options = {})
    super
  end

  def perform
    Workflow.logger.info "Calling #{__method__} in the #{self.class} class"

    #Checks and configuration
    fail 'No run_dir specified in the registry' unless @registry[:run_dir]
    @options[:energyplus_path] ? ep_path = @options[:energyplus_path] : ep_path = nil
    Workflow.logger.warn "Using EnergyPlus path specified in options #{ep_path}" if ep_path

    @registry[:time_logger].start('Running EnergyPlus') if @registry[:time_logger]
    results = call_energyplus(@registry[:run_dir], ep_path)
    @registry[:time_logger].stop('Running EnergyPlus') if @registry[:time_logger]

    results
  end
end
