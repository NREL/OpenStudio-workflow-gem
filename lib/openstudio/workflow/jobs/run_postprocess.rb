# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
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

# Clean up the run directory. Currently this class does nothing else, although eventually cleanup should become driven
# and responsive to options
class RunPostprocess < OpenStudio::Workflow::Job
  require 'openstudio/workflow/util/post_process'
  include OpenStudio::Workflow::Util::PostProcess

  def initialize(input_adapter, output_adapter, registry, options = {})
    defaults = {
      cleanup: true
    }
    options = defaults.merge(options)
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"

    # do not skip post_process if halted
    
    if !@options[:fast]
      @logger.info 'Gathering reports'
      gather_reports(@registry[:run_dir], @registry[:root_dir], @registry[:workflow_json], @logger)
      @logger.info 'Finished gathering reports'
    end

    if @options[:cleanup]
      @logger.info 'Beginning cleanup of the run directory'
      cleanup(@registry[:run_dir], @registry[:root_dir], @logger)
      @logger.info 'Finished cleanup of the run directory'
    else
      @logger.info 'Flag for cleanup in options set to false. Moving to next step.'
    end

    @logger.info 'Finished postprocess'

    nil
  end
end
