require 'spec_helper'

require 'openstudio-analysis'

describe 'OpenStudio Formulation' do
  it 'should run a local file adapter in legacy mode' do
    a = OpenStudio::Analysis.create('workflow-gem')
    run_dir = 'spec/files/simulations/workflow-gem-1'

    a.seed_model = 'spec/files/example_models/seed/seed.osm'
    a.weather_file = 'spec/files/example_models/weather/in.epw'
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
    a.save_zip "#{run_dir}/analysis.zip"

    OpenStudio::Workflow.extract_archive("#{run_dir}/analysis.zip", run_dir)

    # for local, it uses the rundir as the uuid. When using the analysis gem, the root path is difficult because
    # it requires you to know the relative path to the measure which you already added when constructing the workflow.
    # best to keep the analysis_root_path empty when using the programmatic interface and rely on unzipping the data
    # to the run directory
    options = {
      problem_filename: 'analysis.json',
      datapoint_filename: 'data_point.json',
      analysis_root_path: run_dir,
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should report an json file' do
    a = OpenStudio::Analysis.create('workflow-gem')
    run_dir = 'spec/files/simulations/workflow-gem-2'

    a.seed_model = 'spec/files/example_models/seed/seed.osm'
    a.weather_file = 'spec/files/example_models/weather/in.epw'

    a.analysis_type = 'single_run'

    p = 'spec/files/example_models/measures/create_json_file'
    m = a.workflow.add_measure_from_path('create_json_file', 'JSON Data', p)
    # m.argument_value('heating_sch', 'some-string')

    # add output variables
    a.add_output(
      display_name: 'Total Natural Gas',
      name: 'standard_report_legacy.total_natural_gas',
      units: 'MJ/m2',
      objective_function: true
    )

    a.save "#{run_dir}/analysis.json"
    a.save_static_data_point "#{run_dir}/data_point.json"
    a.save_zip "#{run_dir}/analysis.zip"

    OpenStudio::Workflow.extract_archive("#{run_dir}/analysis.zip", run_dir)

    options = {
      problem_filename: 'analysis.json',
      datapoint_filename: 'data_point.json',
      analysis_root_path: run_dir,
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished

    json_file = "#{run_dir}/reports/create_json_file_report.json"
    expect(File.exist?(json_file)).to eq true
    json = JSON.parse(File.read(json_file), symbolize_names: true)
    expect(json[:example][:int]).to eq 123
    expect(json[:example][:boolean]).to eq true

    json_file = "#{run_dir}/reports/create_json_file_report_2.json"
    expect(File.exist?(json_file)).to eq true

    json_file = "#{run_dir}/reports/create_json_file_nothing.json"
    expect(File.exist?(json_file)).to eq false
    json_file = "#{run_dir}/run/CreateJsonFile/nothing.json"
    expect(File.exist?(json_file)).to eq true
  end
end
