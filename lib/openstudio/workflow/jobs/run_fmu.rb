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

# This class runs the EnergyPlus simulation
class RunFmu < OpenStudio::Workflow::Job
  #require 'openstudio/workflow/util/energyplus'
  #include OpenStudio::Workflow::Util::EnergyPlus
  #require 'pycall/import'
  #include PyCall::Import

  def initialize(input_adapter, output_adapter, registry, options = {})
    super
  end

  def perform
    @logger.debug "Calling #{__method__} in the #{self.class} class"
    
    # skip if halted
    halted = @registry[:runner].halted
    @logger.info 'Workflow halted, skipping the FMU simulation' if halted
    return nil if halted

    # Checks and configuration
    raise 'No run_dir specified in the registry' unless @registry[:run_dir]
    #ep_path = @options[:energyplus_path] ? @options[:energyplus_path] : nil
    #@logger.warn "Using EnergyPlus path specified in options #{ep_path}" if ep_path

    @logger.info 'Starting the FMU simulation'
    @registry[:time_logger].start('Running FMU') if @registry[:time_logger]
    #call_energyplus(@registry[:run_dir], ep_path, @output_adapter, @logger, @registry[:workflow_json])

    result = `python --version`
    @logger.debug "python --version: #{result}"
    @logger.debug "python3 --version: #{result}"
    result = `/usr/local/JModelica/bin/jm_python.sh --version`
    @logger.debug "/usr/local/JModelica/bin/jm_python.sh --version : #{result}"
    #result = `printenv`
    #@logger.debug "printenv: #{result}"
    #result = ENV.sort
    #@logger.debug "ruby env: #{result}"
    result = `python3 -c 'import os; print(os.environ); print(os.getcwd())'`
    @logger.debug "python3 ENV: #{result}"

    path = File.dirname(__FILE__)
    files = Dir.entries(path)
    @logger.debug "run_fmu.rb file path: #{files}"
    @logger.debug "run_fmu.rb file path: #{File.dirname(__FILE__)}"

    @registry.register(:model_name) {"HelloWorld"}
    @registry.register(:mo_file) {"#{@registry[:lib_dir]}/mo/HelloWorld.mo"}
    @registry.register(:fmu_file) {"#{@registry[:lib_dir]}/mo/HelloWorld.fmu"}
    @registry.register(:ssp_file) {"#{@registry[:lib_dir]}/mo/dc_tool.ssp"}
    
    lib_dir = @registry[:lib_dir]
    @logger.debug "lib_dir: #{lib_dir}"
    run_dir = @registry[:run_dir]
    @logger.debug "run_dir: #{run_dir}"
   
    #result = `python3 -c "import os; os.chdir('#{run_dir}')"`
    #@logger.debug "python3 os.chdir(): #{result}"
    
    model_name = @registry[:model_name]
    mo_file = @registry[:mo_file]
    fmu_file = @registry[:fmu_file]
    ssp_file = @registry[:ssp_file]
    
    python_log = File.join(@registry[:osw_dir],'oscli_python.log')
    
    #cmd = "python #{path}/run_fmu.py #{mo_file} #{model_name}"
    #cmd = "python #{path}/run_fmu.py #{fmu_file}"
    #cmd = "python3 #{path}/run_ssp.py #{ssp_file} #{run_dir}"
	cmd = "python3 #{lib_dir}/mo/run_ssp2.py #{ssp_file} #{run_dir}"
    @logger.info "Running workflow using cmd: #{cmd} and writing log to: #{python_log}"

    pid = Process.spawn(cmd, [:err, :out] => [python_log, 'w'])
    # timeout the process if it doesn't return in 4 hours
    Timeout.timeout(14400) do
      Process.wait(pid)
    end
    if python_log
      @logger.info "Oscli PYTHON output: #{File.read(python_log)}"
    end
    
    @registry[:time_logger].stop('Running FMU') if @registry[:time_logger]
    @logger.info 'Completed the FMU simulation'

    #sql_path = File.join(@registry[:run_dir], 'eplusout.sql')
    #@registry.register(:sql) { sql_path } if File.exist? sql_path
    #@logger.warn "Unable to find sql file at #{sql_path}" unless @registry[:sql]

    nil
  end
end
