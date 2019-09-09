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
    result = `/usr/local/JModelica/bin/jm_python.sh --version`
    @logger.debug "/usr/local/JModelica/bin/jm_python.sh --version : #{result}"
    result = `printenv`
    @logger.debug "printenv: #{result}"
    result = ENV.sort
    @logger.debug "ruby env: #{result}"
    result = `python -c 'import os; print os.environ'`
    @logger.debug "python ENV: #{result}"

    path = File.dirname(__FILE__)
    files = Dir.entries(path)
    @logger.debug "run_fmu.rm file path: #{files}"
    @logger.debug "run_fmu.rm file path: #{File.dirname(__FILE__)}"
    @logger.debug "test output"
    #os = PyCall.import_module('os')
    #result = os.getcwd()
    #@logger.debug "result: #{result}"

    #matplotlib = PyCall.import_module('matplotlib')
    #matplotlib.use('Agg')

    #pyimport 'pyfmi', as: :pyfmi
    #pyimport 'pylab', as: :pylab
    #pyfrom 'pyfmi.examples', import: :fmi_bouncing_ball
    #result = fmi_bouncing_ball.run_demo()
    #@logger.debug "result: #{result}"

    #pyfrom 'pymodelica', import: :compile_fmu
    #pyfrom 'pyfmi', import: :load_fmu
    #model_name = "HelloWorld"
    #mo_file = "/home/ubuntu/Projects/OpenStudio-workflow-gem-fmu/lib/openstudio/workflow/jobs/HelloWorld.mo"
    #my_fmu = compile_fmu(model_name, mo_file)
    #hello_world = load_fmu(my_fmu)
    #res = hello_world.simulate(start_time=0,final_time=5)
    result = `python #{path}/run_fmu.py`
    @logger.debug "python run_fmu.py: #{result}"
    #fig = pylab.figure()
    #pylab.clf()
    #pylab.plot(res["time"],res["x"])
    #pylab.show()
    
    @registry[:time_logger].stop('Running FMU') if @registry[:time_logger]
    @logger.info 'Completed the FMU simulation'

    #sql_path = File.join(@registry[:run_dir], 'eplusout.sql')
    #@registry.register(:sql) { sql_path } if File.exist? sql_path
    #@logger.warn "Unable to find sql file at #{sql_path}" unless @registry[:sql]

    nil
  end
end
