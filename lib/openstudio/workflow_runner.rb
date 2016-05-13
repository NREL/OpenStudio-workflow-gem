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

require_relative 'workflow_json'

# Extend OS Runner to persist measure information throughout the workflow
# Provide shims to support OpenStudio 2.X functionality in OpenStudio 1.X
class WorkflowRunner < OpenStudio::Ruleset::OSRunner

  def initialize(multi_logger, workflow, osw_dir)
    @multi_logger = multi_logger
    @workflow_json = nil
    @openstudio_2 = false

    begin
      # OpenStudio 2.X
      @workflow_json = OpenStudio::WorkflowJSON.new(JSON.fast_generate(workflow))
      @workflow_json.setOswDir(osw_dir)
      @openstudio_2 = true
      @multi_logger.info "WorkflowJSON available"
      super(@workflow_json)
    rescue Exception => e 
      # OpenStudio 1.X
      @multi_logger.warn e.message
      @multi_logger.info "WorkflowJSON unavailable"
      @workflow = workflow
      @workflow_json = WorkflowJSON_Shim.new(workflow, osw_dir)
      @current_step = 0
      @previous_results = OpenStudio::Ruleset::OSResultVector.new
      @units_preference = "SI"
      @language_preference = "EN"
      super()
    end
  end
  
  def openstudio_2
    @openstudio_2
  end
  
  # Returns the workflow currently being run. New in OS 2.0. 
  # WorkflowJSON workflow() const;
  def workflow
    if @openstudio_2
      super
    else
      @workflow_json
    end
  end

  # Returns the current step in the workflow being run, indexing starts at 0. New in OS 2.0. 
  # unsigned currentStep() const;
  def currentStep
    if @openstudio_2
      super
    else
      @current_step
    end
  end

  # Returns results from the previous steps that were run. New in OS 2.0.
  # std::vector<OSResult> previousResults() const;
  def previousResults
    if @openstudio_2
      super
    else
      @previous_results
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
  
  # incrementing step copies result to previous results
  # void incrementStep();
  def incrementStep
    if @openstudio_2
      super
    else
      @previous_results << self.result
      @current_step += 1
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
end
