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

# WorkflowStepResult_Shim provides a shim interface to the WorkflowStepResult class in OpenStudio 2.X when running in OpenStudio 1.X
class WorkflowStepResult_Shim
  
  def initialize()
  end
  
  def index
    @index
  end

end


# WorkflowStep_Shim provides a shim interface to the WorkflowStep class in OpenStudio 2.X when running in OpenStudio 1.X
class WorkflowStep_Shim
  
  def initialize(step)
    @step = step
  end
  
  # std::string measureDirName() const;
  def measureDirName
    @step[:measure_dir_name]
  end
    
  #std::map<std::string, Variant> arguments() const;
  def arguments
    # TODO: match C++
    @step[:arguments]
  end
end

class Optional_Shim
  def initialize(obj)
    @obj = obj
  end
  
  def empty?
    @obj.nil?
  end
  
  def is_initialized
    !@obj.nil?
  end  
  
  def get
    fail "Uninitialize" if @obj.nil?
    @obj
  end  
end

# WorkflowJSON_Shim provides a shim interface to the WorkflowJSON class in OpenStudio 2.X when running in OpenStudio 1.X
class WorkflowJSON_Shim
  
  def initialize(workflow, osw_dir)
    @workflow = workflow
    @osw_dir = osw_dir
    @current_step_index = 0
  end
  
  # std::string string(bool includeHash=true) const;
  def string
    JSON::fast_generate(@workflow)
  end

  # Returns the absolute path to the directory this workflow was loaded from or saved to.  Returns current working dir for new WorkflowJSON.
  # openstudio::path oswDir() const;
  def oswDir
    OpenStudio::toPath(@osw_dir)
  end
  
  def saveAs(path)
    File.open(path.to_s, 'w') do |file|
      file << JSON::pretty_generate(@workflow)
    end
  end
  
  # Sets the started at time.
  def start
    @workflow[:started_at] = Time.now.utc
  end
  
  # Get the current step index.
  def currentStepIndex
    @current_step_index
  end

  # Get the current step.
  # boost::optional<WorkflowStep> currentStep() const;
  def currentStep
    steps = @workflow[:steps]
    
    step = nil
    if @current_step_index < steps.size
      step = WorkflowStep_Shim.new(steps[@current_step_index])
    end
    return Optional_Shim.new(step)
  end

  # Increments current step, returns true if there is another step. 
  # bool incrementStep();
  def incrementStep
    @current_step_index += 1
    # todo
    return true
  end

  # Returns the root directory, default value is '.'. Evaluated relative to oswDir if not absolute.
  # openstudio::path rootDir() const;
  # openstudio::path absoluteRootDir() const;
  def rootDir
    if @workflow[:root_dir]
      OpenStudio::toPath(@workflow[:root_dir])
    else
      OpenStudio::toPath(@osw_dir)
    end
  end
  
  def absoluteRootDir
    OpenStudio::toPath(File.absolute_path(rootDir.to_s, @osw_dir.to_s))
  end
  
  # Returns the run directory, default value is './run'. Evaluated relative to rootDir if not absolute. 
  #openstudio::path runDir() const;
  #openstudio::path absoluteRunDir() const;
  def runDir
    if @workflow[:run_directory]
      OpenStudio::toPath(@workflow[:run_directory])
    else
      OpenStudio::toPath('./run')
    end
  end
  
  def absoluteRunDir
    OpenStudio::toPath(File.absolute_path(runDir.to_s, rootDir.to_s))
  end
  
  def outPath
    if @workflow[:out_name]
      OpenStudio::toPath(@workflow[:out_name])
    else
      OpenStudio::toPath('./out.osw')
    end  
  end
  
  def absoluteOutPath
    OpenStudio::toPath(File.absolute_path(outPath.to_s, oswDir.to_s))
  end
  
  # Returns the paths that will be searched in order for files, default value is './files/'. Evaluated relative to rootDir if not absolute. 
  # std::vector<openstudio::path> filePaths() const;
  # std::vector<openstudio::path> absoluteFilePaths() const;
  def filePaths
    result = OpenStudio::PathVector.new
    if @workflow[:file_paths]
      @workflow[:file_paths].each do |file_path|
        result << OpenStudio::toPath(file_path)
      end
    else
      result << OpenStudio::toPath("./files")
      result << OpenStudio::toPath("./weather")
      result << OpenStudio::toPath("../../files")
      result << OpenStudio::toPath("../../weather")
      result << OpenStudio::toPath("./")
    end
    result
  end
  
  def absoluteFilePaths
    result = OpenStudio::PathVector.new
    filePaths.each do |file_path|
      result << OpenStudio::toPath(File.absolute_path(file_path.to_s, rootDir.to_s))
    end
    result
  end

  # Attempts to find a file by name, searches through filePaths in order and returns first match. 
  # boost::optional<openstudio::path> findFile(const openstudio::path& file);
  # boost::optional<openstudio::path> findFile(const std::string& fileName);
  def findFile(file)
    absoluteFilePaths.each do |file_path|
      result = File.join(file_path.to_s, file.to_s)
      if File.exists?(result)
        return OpenStudio::OptionalPath.new(OpenStudio::toPath(result))
      end
    end
    OpenStudio::OptionalPath.new
  end

  # Returns the paths that will be searched in order for measures, default value is './measures/'. Evaluated relative to rootDir if not absolute. 
  # std::vector<openstudio::path> measurePaths() const;
  # std::vector<openstudio::path> absoluteMeasurePaths() const;
  def measurePaths
    result = OpenStudio::PathVector.new
    if @workflow[:measure_paths]
      @workflow[:measure_paths].each do |measure_path|
        result << OpenStudio::toPath(measure_path)
      end
    else
      result << OpenStudio::toPath("./measures")
      result << OpenStudio::toPath("../../measures")
      result << OpenStudio::toPath("./")
    end
    result
  end
  
  def absoluteMeasurePaths
    result = OpenStudio::PathVector.new
    measurePaths.each do |measure_path|
      result << OpenStudio::toPath(File.absolute_path(measure_path.to_s, rootDir.to_s))
    end
    result
  end
  
  # Attempts to find a measure by name, searches through measurePaths in order and returns first match. */
  # boost::optional<openstudio::path> findMeasure(const openstudio::path& measureDir);
  # boost::optional<openstudio::path> findMeasure(const std::string& measureDirName);
  def findMeasure(measureDir)
    absoluteMeasurePaths.each do |measure_path|
      result = File.join(measure_path.to_s, measureDir.to_s)
      if File.exists?(result)
        return OpenStudio::OptionalPath.new(OpenStudio::toPath(result))
      end
    end
    OpenStudio::OptionalPath.new
  end

  # Returns the seed file path. Evaluated relative to filePaths if not absolute. 
  # boost::optional<openstudio::path> seedFile() const;
  def seedFile
    result = OpenStudio::OptionalPath.new
    if @workflow[:seed_file]
      result = OpenStudio::OptionalPath.new(OpenStudio::toPath(@workflow[:seed_file]))
    end
    result
  end

  # Returns the weather file path. Evaluated relative to filePaths if not absolute. 
  # boost::optional<openstudio::path> weatherFile() const;
  def weatherFile
    result = OpenStudio::OptionalPath.new
    if @workflow[:weather_file]
      result = OpenStudio::OptionalPath.new(OpenStudio::toPath(@workflow[:weather_file]))
    end
    result
  end
  
  # Returns the workflow steps. */
  # std::vector<WorkflowStep> workflowSteps() const;
  def workflowSteps
    result = []
    @workflow[:steps].each do |step|
      result << WorkflowStep_Shim.new(step)
    end
    result
  end
  
  def setCompletedStatus(status)
    # todo
  end
  
end
