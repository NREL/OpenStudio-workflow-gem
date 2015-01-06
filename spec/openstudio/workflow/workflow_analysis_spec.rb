require 'rspec'
require 'spec_helper'

require 'openstudio-analysis'

describe 'OpenStudio Formulation' do
  it 'should run a local file adapter in legacy mode' do
    a = OpenStudio::Analysis.create('workflow-gem')
    run_dir = 'spec/files/simulations/workflow-gem-1'

    a.seed_model('spec/files/example_models/seed/seed.osm')
    a.weather_file('spec/files/example_models/weather/in.epw')
    FileUtils.mkdir_p run_dir

    a.analysis_type = 'single_run'

    p = 'spec/files/example_models/measures/ReduceLightingLoadsByPercentage'
    m = a.workflow.add_measure_from_path('light_power_reduction', 'Reduce Lights', p)
    # m.argument_value('heating_sch', 'some-string')

    p = 'spec/files/example_models/measures/RotateBuilding'
    m = a.workflow.add_measure_from_path('rotate_building', 'Rotate Building', p)

    # add output variables
    a.add_output(
                     display_name: 'Total Natural Gas',
                     name: 'standard_report_legacy.total_natural_gas',
                     units: 'MJ/m2',
                     objective_function: true
                 )

    a.save "#{run_dir}/analysis.json"
    a.save_static_data_point "#{run_dir}/data_point.json"

    # for local, it uses the rundir as the uuid. When using the analysis gem, the root path if difficult because
    # it requires you to know the relative path to the measure which you already added when constructing the workflow.
    # best to keep the analysis_root_path empty when using the programmatic interface
    options = {
      problem_filename: 'analysis.json',
      datapoint_filename: 'data_point.json',
      analysis_root_path: '',
      use_monthly_reports: true
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
    # run the workflow in the simulation directory

    # d = {
    #     type: 'uniform',
    #     minimum: 5,
    #     maximum: 7,
    #     mean: 6.2
    # }
    # m.make_variable('cooling_sch', 'Change the cooling schedule', d)

    #
    #
    # # for local, it uses the rundir as the uuid
    # run_dir = './spec/files/local_ex1'
    # options = {
    #   problem_filename: 'analysis_1.json',
    #   datapoint_filename: 'datapoint_1.json',
    #   analysis_root_path: 'spec/files/example_models',
    #   use_monthly_reports: true
    # }
    # k = OpenStudio::Workflow.load 'Local', run_dir, options
    # expect(k).to be_instance_of OpenStudio::Workflow::Run
    # expect(k.options[:problem_filename]).to eq 'analysis_1.json'
    # expect(k.options[:datapoint_filename]).to eq 'datapoint_1.json'
    # expect(k.directory).to eq File.expand_path(run_dir)
    # expect(k.run).to eq :finished
    # expect(k.final_state).to eq :finished
  end
end
