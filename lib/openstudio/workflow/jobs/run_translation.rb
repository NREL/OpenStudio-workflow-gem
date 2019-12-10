# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
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

# Run the initialization job to validate the directory and initialize the adapters.
class RunTranslation < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util/model'
  include OpenStudio::Workflow::Util::Model

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"
    
    # skip if halted
    if @registry[:runner].halted
      @logger.info 'Workflow halted, skipping OSM to IDF translation'
      @registry.register(:model_idf) { OpenStudio::Workspace.new } # This allows model arguments to still be calculated
      return nil
    end

    # Ensure that the run directory is created
    FileUtils.mkdir_p(@registry[:run_dir])

    # Copy in the weather file defined in the registry, or alternately in the options
    if @registry[:wf]
      @logger.info "Weather file for EnergyPlus simulation is #{@registry[:wf]}"
      FileUtils.copy(@registry[:wf], "#{@registry[:run_dir]}/in.epw")
      @registry.register(:wf) { "#{@registry[:run_dir]}/in.epw" }
    else
      @logger.warn "EPW file not found or not sent to #{self.class}"
    end
    
    # Translate the OSM to an IDF
    @logger.info 'Beginning the translation to IDF'
    @registry[:time_logger].start('Translating to EnergyPlus') if @registry[:time_logger]
    model_idf = translate_to_energyplus @registry[:model], @logger
    @registry[:time_logger].stop('Translating to EnergyPlus') if @registry[:time_logger]
    @registry.register(:model_idf) { model_idf }
    @logger.info 'Successfully translated to IDF'

    # Save the generated IDF file if the :debug option is true
    return nil unless @options[:debug]
    @registry[:time_logger].start('Saving IDF') if @registry[:time_logger]
    idf_name = save_idf(@registry[:model_idf], @registry[:root_dir])
    @registry[:time_logger].stop('Saving IDF') if @registry[:time_logger]
    @logger.debug "Saved IDF as #{idf_name}"

    nil
  end
end
