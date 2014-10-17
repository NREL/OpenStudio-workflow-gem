$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../../..', 'lib'))
require 'openstudio-workflow.rb'

analysis_root_path = "#{File.dirname(__FILE__)}../../../../files/pat_project/"
analysis_root_path = File.absolute_path(analysis_root_path)

run_dir = "#{File.dirname(__FILE__)}../../../../files/pat_project/"
run_dir = File.absolute_path(run_dir)

options = {
  is_pat: true,
  problem_filename: 'formulation.json',
  datapoint_filename: 'data_point_469b52c3-4aae-4cdd-b580-5c9494eefa11/data_point.json',
  analysis_root_path: analysis_root_path
}
k = OpenStudio::Workflow.load 'Local', run_dir, options
k.run
puts k.final_state