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

class RunOpenstudio < OpenStudio::Workflow::Job

  # Mixin the required util modules
  require_relative '../util/measure'
  require_relative '../util/model'
  require_relative '../util/weather_file'

  # Initialize
  # param directory: base directory where the simulation files are prepared
  # param logger: logger object in which to write log messages
  def initialize(adapter, registry, options = {})
    defaults = { format: 'hash', analysis_root_path: '.' }
    super
    @results = {}
  end

  def perform
    logger.info "Calling #{__method__} in the #{self.class} class"
    logger.info "Current directory is #{@directory}"

    logger.info 'Beginning to execute OpenStudio measures.'
    OpenStudio::Workflow::Util::Measure.apply_measures(:openstudio, @registry, options)
    logger.info('Finished applying OpenStudio measures.')

    logger.info 'Saving measure output attributes JSON'
    File.open("#{@registry[:run_dir]}/measure_attributes.json", 'w') do |f|
      f << JSON.pretty_generate(@registry[:output_attributes])
    end

    @registry[:time_logger].start('Saving OSM') if @registry[:time_logger]
    OpenStudio::Workflow::Util::Model.save_osm(@registry[:model], @registry[:root_dir])
    @registry[:time_logger].stop('Saving OSM') if @registry[:time_logger]

    @results
  end
end
