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

# Prepares the directory for the EnergyPlus simulation
class RunPreprocess < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util'
  include OpenStudio::Workflow::Util::EnergyPlus
  include OpenStudio::Workflow::Util::Model
  include OpenStudio::Workflow::Util::Measure

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # halted workflow is handled in apply_measures

    # Ensure that the directory is created (but it should already be at this point)
    FileUtils.mkdir_p(@registry[:run_dir])

    # save the pre-preprocess file
    if !@options[:skip_energyplus_preprocess]
      File.open("#{@registry[:run_dir]}/pre-preprocess.idf", 'w') do |f|
        f << @registry[:model_idf].to_s
        # make sure data is written to the disk one way or the other
        begin
          f.fsync
        rescue StandardError
          f.flush
        end
      end
    end

    # Add any EnergyPlus Output Requests from Reporting Measures
    @logger.info 'Beginning to collect output requests from Reporting measures.'
    energyplus_output_requests = true
    apply_measures('ReportingMeasure'.to_MeasureType, @registry, @options, energyplus_output_requests)
    @logger.info('Finished collect output requests from Reporting measures.')

    # Skip the pre-processor if halted
    halted = @registry[:runner].halted
    @logger.info 'Workflow halted, skipping the EnergyPlus pre-processor' if halted
    return nil if halted

    # Perform pre-processing on in.idf to capture logic in RunManager
    if !@options[:skip_energyplus_preprocess]
      @registry[:time_logger].start('Running EnergyPlus Preprocess') if @registry[:time_logger]
      energyplus_preprocess(@registry[:model_idf], @logger)
      @registry[:time_logger].start('Running EnergyPlus Preprocess') if @registry[:time_logger]
      @logger.info 'Finished preprocess job for EnergyPlus simulation'
    end

    # Save the model objects in the registry to the run directory
    if File.exist?("#{@registry[:run_dir]}/in.idf")
      # DLM: why is this here?
      @logger.warn 'IDF (in.idf) already exists in the run directory. Will simulate using this file'
    else
      save_idf(@registry[:model_idf], @registry[:run_dir])
    end

    # Save the generated IDF file if the :debug option is true
    return nil unless @options[:debug]
    @registry[:time_logger].start('Saving IDF') if @registry[:time_logger]
    idf_name = save_idf(@registry[:model_idf], @registry[:root_dir])
    @registry[:time_logger].stop('Saving IDF') if @registry[:time_logger]
    @logger.debug "Saved IDF as #{idf_name}"

    nil
  end
end
