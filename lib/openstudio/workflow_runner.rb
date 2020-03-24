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

require_relative 'workflow_json'

# Extend OS Runner to persist measure information throughout the workflow
# Provide shims to support OpenStudio 2.X functionality in OpenStudio 1.X
class WorkflowRunner < OpenStudio::Ruleset::OSRunner
  def initialize(multi_logger, workflow_json, openstudio_2)
    @multi_logger = multi_logger
    @workflow_json = workflow_json
    @openstudio_2 = openstudio_2
    @datapoint = nil
    @analysis = nil
    @halted = false
    @use_os_halted = OpenStudio::Ruleset::OSRunner.method_defined?(:halted)

    begin
      # OpenStudio 2.X
      super(@workflow_json)
    rescue Exception => e
      # OpenStudio 1.X
      @workflow = workflow_json
      @units_preference = 'SI'
      @language_preference = 'EN'
      super()
    end
  end

  def timeString
    ::Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
  end

  attr_reader :datapoint

  def setDatapoint(datapoint)
    @datapoint = datapoint
  end

  attr_reader :analysis

  def setAnalysis(analysis)
    @analysis = analysis
  end

  # Returns the workflow currently being run. New in OS 2.0.
  # WorkflowJSON workflow() const;
  def workflow
    if @openstudio_2
      super
    else
      @workflow
    end
  end

  # Returns preferred unit system, either 'IP' or 'SI'. New in OS 2.0. */
  # std::string unitsPreference() const;
  def unitsPreference
    if @openstudio_2
      super
    else
      @units_preference
    end
  end

  # Returns preferred language, e.g. 'en' or 'fr'. New in OS 2.0. */
  # std::string languagePreference() const;
  def languagePreference
    if @openstudio_2
      super
    else
      @language_preference
    end
  end

  # called right when each measure is run
  # only called in OpenStudio 1.X
  # virtual void prepareForUserScriptRun(const UserScript& userScript);
  def prepareForUserScriptRun(userScript)
    if @openstudio_2
      prepareForMeasureRun(userScript)
    else
      current_step = @workflow.currentStep

      unless current_step.empty?
        current_step.get.step[:result] = {}
        current_step.get.step[:result][:started_at] = timeString
      end

      # TODO: capture std out and err

      # TODO: get initial list of files

      super
    end
  end

  def result
    if @openstudio_2
      super
    else
      os_result = super

      current_step = @workflow.currentStep

      if current_step.empty?
        raise 'Cannot find current_step'
      end
      current_step = current_step.get

      if current_step.step[:result].nil?
        # skipped, prepareForUserScriptRun was not called
        current_step.step[:result] = {}
        current_step.step[:result][:started_at] = timeString
        current_step.step[:result][:step_result] = 'Skip'
      else
        current_step.step[:result][:step_result] = os_result.value.valueName
      end

      current_step.step[:result][:completed_at] = timeString

      # TODO: restore stdout and stderr

      # TODO: check for created files

      current_step.step[:result][:step_errors] = []
      os_result.errors.each do |error|
        current_step.step[:result][:step_errors] << error.logMessage
      end

      current_step.step[:result][:step_warnings] = []
      os_result.warnings.each do |warning|
        current_step.step[:result][:step_warnings] << warning.logMessage
      end

      current_step.step[:result][:step_info] = []
      os_result.info.each do |info|
        current_step.step[:result][:step_info] << info.logMessage
      end

      unless os_result.initialCondition.empty?
        current_step.step[:result][:initial_condition] = os_result.initialCondition.get.logMessage
        current_step.step[:result][:step_initial_condition] = os_result.initialCondition.get.logMessage
      end

      unless os_result.finalCondition.empty?
        current_step.step[:result][:final_condition] = os_result.finalCondition.get.logMessage
        current_step.step[:result][:step_final_condition] = os_result.finalCondition.get.logMessage
      end

      current_step.step[:result][:step_values] = []
      os_result.attributes.each do |attribute|
        result = nil
        if attribute.valueType == 'Boolean'.to_AttributeValueType
          result = { name: attribute.name, value: attribute.valueAsBoolean, type: 'Boolean' }
        elsif attribute.valueType == 'Double'.to_AttributeValueType
          result = { name: attribute.name, value: attribute.valueAsDouble, type: 'Double' }
        elsif attribute.valueType == 'Integer'.to_AttributeValueType
          result = { name: attribute.name, value: attribute.valueAsInteger, type: 'Integer' }
        elsif attribute.valueType == 'Unsigned'.to_AttributeValueType
          result = { name: attribute.name, value: attribute.valueAsUnsigned, type: 'Integer' }
        elsif attribute.valueType == 'String'.to_AttributeValueType
          result = { name: attribute.name, value: attribute.valueAsString, type: 'String' }
        end

        current_step.step[:result][:step_values] << result unless result.nil?
      end

      return WorkflowStepResult_Shim.new(current_step.step[:result])
    end
  end

  # incrementing step copies result to previous results
  # void incrementStep();
  def incrementStep
    if @openstudio_2
      super
    else
      # compute result
      current_result = result

      @workflow.incrementStep
    end
  end

  # Overload registerInfo
  def registerInfo(message)
    super
    @multi_logger.info message
  end

  # Overload registerInfo
  def registerWarning(message)
    super
    @multi_logger.warn message
  end

  # Overload registerError
  def registerError(message)
    super
    @multi_logger.error message
  end

  # Overload registerInitialCondition
  def registerInitialCondition(message)
    super
    @multi_logger.info message
  end

  # Overload registerFinalCondition
  def registerFinalCondition(message)
    super
    @multi_logger.info message
  end

  # Overload haltSimulation
  def haltWorkflow(completed_status)
    if @use_os_halted
      super
    else
      @halted = true
      @workflow_json.setCompletedStatus(completed_status)
    end
  end

  # Overload halted
  def halted
    return @halted unless @use_os_halted
    super
  end
end
