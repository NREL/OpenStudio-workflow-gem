# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# Run any Python measures contained in the OSW
class RunPythonMeasures < OpenStudio::Workflow::Job
  # Mixin the required util modules
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::Measure
  include OpenStudio::Workflow::Util::Model

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # halted workflow is handled in apply_measures

    # set weather file
    if @registry[:wf] && @registry[:model]
      epwFile = OpenStudio::EpwFile.load(@registry[:wf])
      if !epwFile.empty?
        OpenStudio::Model::WeatherFile.setWeatherFile(@registry[:model], epwFile.get)
      else
        @logger.warn "Could not load weather file from '#{@registry[:wf]}'"
      end
    end

    # Ensure output_attributes is initialized in the registry
    @registry.register(:output_attributes) { {} } unless @registry[:output_attributes]

    # Execute the Python measures
    @options[:output_adapter] = @output_adapter
    @logger.info 'Beginning to execute Python measures.'
    apply_measures('ModelMeasure'.to_MeasureType, @registry, @options)
    @logger.info('Finished applying Python measures.')

    # Send the measure output attributes to the output adapter
    @logger.debug 'Communicating measure output attributes to the output adapter'
    @output_adapter.communicate_measure_attributes @registry[:output_attributes]

    # save the final OSM
    if !@options[:fast]
      save_osm(@registry[:model], @registry[:run_dir])
    end

    # Save the OSM if the :debug option is true
    return nil unless @options[:debug]

    @registry[:time_logger]&.start('Saving OSM')
    osm_name = save_osm(@registry[:model], @registry[:root_dir])
    @registry[:time_logger]&.stop('Saving OSM')
    @logger.debug "Saved model as #{osm_name}"

    nil
  end
end
