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

# WorkflowJSON_Shim provides a shim interface to the WorkflowJSON class in OpenStudio 2.X when running in OpenStudio 1.X
class WorkflowJSON_Shim
  
  def initialize(workflow, osw_dir)
    @workflow = workflow
    @osw_dir = osw_dir
  end
  
  # std::string string(bool includeHash=true) const;
  def string
    JSON::fast_generate(@workflow)
  end

  # Returns the absolute path to the directory this workflow was loaded from or saved to.  Returns current working dir for new WorkflowJSON.
  # openstudio::path oswDir() const;
  def oswDir
    @osw_dir
  end

  # Returns the root directory, default value is '.'. Evaluated relative to oswDir if not absolute.
  # openstudio::path rootDir() const;
  # openstudio::path absoluteRootDir() const;
  def rootDir
    if @workflow[:root_dir]
      @workflow[:root_dir]
    else
      @osw_dir
    end
  end
  
  def absoluteRootDir
    File.absolute_path(rootDir, @osw_dir)
  end
  
  # Returns the run directory, default value is './run'. Evaluated relative to rootDir if not absolute. 
  #openstudio::path runDir() const;
  #openstudio::path absoluteRunDir() const;
  def runDir
    if @workflow[:run_directory]
      @workflow[:run_directory]
    else
      './run'
    end
  end
  
  def absoluteRunDir
    File.absolute_path(runDir, rootDir)
  end
  
  # Returns the paths that will be searched in order for files, default value is './files/'. Evaluated relative to rootDir if not absolute. 
  # std::vector<openstudio::path> filePaths() const;
  # std::vector<openstudio::path> absoluteFilePaths() const;
  def filePaths
    OpenStudio::PathVector.new
    
    #file_paths: %w{files weather ../../files ../../weather ./}
  end
  
  def absoluteFilePaths
    OpenStudio::PathVector.new
  end

  # Attempts to find a file by name, searches through filePaths in order and returns first match. 
  # boost::optional<openstudio::path> findFile(const openstudio::path& file);
  # boost::optional<openstudio::path> findFile(const std::string& fileName);
  def findFile(file)
    OpenStudio::OptionalPath.new
  end

  # Returns the paths that will be searched in order for measures, default value is './measures/'. Evaluated relative to rootDir if not absolute. 
  # std::vector<openstudio::path> measurePaths() const;
  # std::vector<openstudio::path> absoluteMeasurePaths() const;
  def measurePaths
    OpenStudio::PathVector.new
    
    #measure_paths: %w{measures ../../measures ./},
  end
  
  def absoluteMeasurePaths
    OpenStudio::PathVector.new
  end
  
  # Attempts to find a measure by name, searches through measurePaths in order and returns first match. */
  # boost::optional<openstudio::path> findMeasure(const openstudio::path& measureDir);
  # boost::optional<openstudio::path> findMeasure(const std::string& measureDirName);
  def findMeasure
    OpenStudio::OptionalPath.new
  end

  # Returns the seed file path. Evaluated relative to filePaths if not absolute. */
  # boost::optional<openstudio::path> seedFile() const;
  def seedFile
    OpenStudio::OptionalPath.new
  end

  # Returns the weather file path. Evaluated relative to filePaths if not absolute. */
  # boost::optional<openstudio::path> weatherFile() const;
  def weatherFile
    OpenStudio::OptionalPath.new
  end
  
  # Returns the workflow steps. */
  # std::vector<WorkflowStep> workflowSteps() const;
  def workflowSteps
    []
  end
  
end
