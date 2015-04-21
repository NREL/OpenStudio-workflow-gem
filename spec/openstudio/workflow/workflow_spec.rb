require 'spec_helper'

describe 'OpenStudio::Workflow' do
  before :all do
    begin
      require 'mongoid'
      require 'mongoid_paperclip'
      require 'delayed_job_mongoid'
      base_path = File.expand_path('spec/files/mongoid')

      puts "Base path for mongoid models is: #{base_path}"

      Dir["#{base_path}/models/*.rb"].each { |f| require f }
      Mongoid.load!("#{base_path}/mongoid.yml", :development)

      # Delete all the records
      DataPoint.delete_all
      Analysis.delete_all

      # TODO: make this a factory!
      # read in the data_point
      dp_json_filename = 'spec/files/local_ex1/datapoint_1.json'
      analysis_filename = 'spec/files/local_ex1/analysis_1.json'
      if File.exist?(dp_json_filename) && File.exist?(analysis_filename)
        dp_json = MultiJson.load(File.read(dp_json_filename), symbolize_keys: true)
        analysis_json = MultiJson.load(File.read(analysis_filename), symbolize_keys: true)
        dp = DataPoint.create(dp_json[:data_point])
        a = Analysis.create(analysis_json[:analysis])
        dp.save!
        a.save!
      end

      # Load in the local_ex2 example as well.
      dp_json_filename = 'spec/files/local_ex2/datapoint_1.json'
      analysis_filename = 'spec/files/local_ex2/analysis_1.json'
      if File.exist?(dp_json_filename) && File.exist?(analysis_filename)
        dp_json = MultiJson.load(File.read(dp_json_filename), symbolize_keys: true)
        analysis_json = MultiJson.load(File.read(analysis_filename), symbolize_keys: true)
        dp = DataPoint.create(dp_json[:data_point])
        a = Analysis.create(analysis_json[:analysis])
        dp.save!
        a.save!
      end

    rescue LoadError
      puts 'No Mongo'
    end
  end

  it 'should run a local file adapter in legacy mode' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/local_ex1'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir
    options = {
      problem_filename: 'analysis_1.json',
      datapoint_filename: 'datapoint_1.json',
      analysis_root_path: 'spec/files/example_models',
      use_monthly_reports: true
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq 'analysis_1.json'
    expect(k.options[:datapoint_filename]).to eq 'datapoint_1.json'
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should run a local file with minimum format' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/local_ex2'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir
    options = {
      problem_filename: 'analysis_1.json',
      datapoint_filename: 'datapoint_1.json',
      analysis_root_path: 'spec/files/example_models',
      use_monthly_reports: true
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq 'analysis_1.json'
    expect(k.options[:datapoint_filename]).to eq 'datapoint_1.json'
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should run a local file as energyplus only' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/local_ep'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    k = OpenStudio::Workflow.run_energyplus 'Local', run_dir

    # copy in an idf and epw file
    FileUtils.copy('spec/files/example_models/seed/seed.idf', run_dir)
    FileUtils.copy('spec/files/example_models/weather/in.epw', run_dir)

    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq nil
    expect(k.options[:datapoint_filename]).to eq nil
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished

    # clean everything up
  end

  it 'should fail to run an invalid energyplus file' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/local_ep_bad'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    k = OpenStudio::Workflow.run_energyplus 'Local', run_dir

    # copy in an idf and epw file
    FileUtils.copy('spec/files/example_models/seed/seed_malformed.idf', run_dir)
    FileUtils.copy('spec/files/example_models/weather/in.epw', run_dir)

    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq nil
    expect(k.options[:datapoint_filename]).to eq nil
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :errored
    expect(k.final_state).to eq :errored
  end

  it 'should fail to run a file that produces utf-8' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/local_ep_iso-8859'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    k = OpenStudio::Workflow.run_energyplus 'Local', run_dir

    # copy in an idf and epw file
    FileUtils.copy('spec/files/example_models/seed/seed_8859-1.idf', run_dir)
    FileUtils.copy('spec/files/example_models/weather/in.epw', run_dir)

    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq nil
    expect(k.options[:datapoint_filename]).to eq nil
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should fail to run energyplus with no weather' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/local_ep_no_weather'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    k = OpenStudio::Workflow.run_energyplus 'Local', run_dir

    # copy in an idf and epw file
    FileUtils.copy('spec/files/example_models/seed/seed.idf', run_dir)
    # FileUtils.copy('spec/files/example_models/weather/in.epw', run_dir)

    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq nil
    expect(k.options[:datapoint_filename]).to eq nil
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :errored
    expect(k.final_message).to match /.*EPW file not found or not sent to RunEnergyplus.*/
  end

  it 'should fail to run energyplus with malformed weather' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/local_ep_malformed_weather'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    k = OpenStudio::Workflow.run_energyplus 'Local', run_dir

    # copy in an idf and epw file
    FileUtils.copy('spec/files/example_models/seed/seed.idf', run_dir)
    FileUtils.copy('spec/files/example_models/weather/in_malformed.epw', run_dir)

    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq nil
    expect(k.options[:datapoint_filename]).to eq nil
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :errored
    expect(k.final_message).to match /.*failed with EnergyPlus Terminated with a Fatal Error*/
  end

  it 'should not find the input file' do
    run_dir = './spec/files/simulations/local_ex1'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    k = OpenStudio::Workflow.load 'Local', run_dir
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to be :errored
    expect(k.final_state).to be :errored
  end

  it 'should create a mongo file adapater and run the verbose format' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/mongo_ex1'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    options = {
      datapoint_id: '4f0b5de0-babf-0131-609d-080027880ca6',
      analysis_root_path: 'spec/files/example_models',
      use_monthly_reports: true,
      adapter_options: {
        mongoid_path: './spec/files/mongoid'
      }
    }
    k = OpenStudio::Workflow.load 'Mongo', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should create a new datapoint based on a list' do
    run_dir = './spec/files/simulations/dynamically_created'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    dp_uuid = 'random_datapoint_uuid'
    options = {
      datapoint_id: dp_uuid,
      analysis_root_path: run_dir,
      adapter_options: {
        mongoid_path: './spec/files/mongoid'
      }
    }
    k = OpenStudio::Workflow.load 'Mongo', "#{run_dir}/#{dp_uuid}", options

    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path("#{run_dir}/#{dp_uuid}")
    expect(File.exist?(k.directory)).to be true

    # TODO: move this into a method to handle the creation
    # if this is mongo adapter, then it will have the models loaded
    dp = DataPoint.find_or_create_by(uuid: dp_uuid)
    expect(dp.save!).to be true
    expect(dp.id).to eq dp_uuid

    # check for logging
    k.logger.info 'Test log message'
    expect(dp.sdp_log_file.last).not_to include 'Test log message'
    dp.reload
    expect(dp.sdp_log_file.last).to include 'Test log message'
  end

  it 'should create a mongo file adapater and run the concise format and write out a building from the measure', mongo: true do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/simulations/mongo_ex3'
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir
    
    options = {
      datapoint_id: 'f348e59a-e1c3-11e3-8b68-0800200c9a66',
      analysis_root_path: 'spec/files/example_models',
      use_monthly_reports: true,
      adapter_options: {
        mongoid_path: './spec/files/mongoid'
      }
    }
    k = OpenStudio::Workflow.load 'Mongo', run_dir, options

    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished

    # First test the database
    if k.adapter.is_a? OpenStudio::Workflow::Adapters::Mongo
      expect(k.adapter.datapoint[:results]).to_not be_nil
      expect(k.adapter.datapoint[:results][:standard_report_legacy]).to_not be_nil
      expect(k.adapter.datapoint[:results][:standard_report_legacy][:total_energy]).to be_within(10).of(321.26)
      expect(k.adapter.datapoint[:results][:standard_report_legacy][:total_source_energy]).to be_within(10).of(865.73)
    end

    # Look at the results in teh job_results hash
    expect(k.job_results).to be_a Hash
    expect(k.job_results[:run_reporting_measures][:lighting_loads_user_customized_name][:lighting_power_reduction_percent]).to be_within(1).of(26.375)
    # expect(k.job_results[:run_postprocess][:standard_report][:total_building_area]).to be_within(1).of(26.375)
    # expect(k.job_results[:run_postprocess][:standard_report][:total_site_energy_eui]).to be_within(10).of(321.26)
    expect(k.job_results[:run_reporting_measures][:standard_report_legacy][:total_energy]).to be_within(10).of(321.26)

    # expect(k.job_results[:run_postprocess][:standard_report][:total_source_energy_eui]).to be_within(10).of(865.73)
    expect(k.job_results[:run_reporting_measures][:standard_report_legacy][:total_source_energy]).to be_within(10).of(865.73)

    expect(File.exist?("#{run_dir}/objectives.json")).to eq true
    expect(File.exist?("#{run_dir}/data_point_#{options[:datapoint_id]}.zip")).to eq true
    expect(File.exist?("#{run_dir}/data_point_#{options[:datapoint_id]}_reports.zip")).to eq true
    objs = JSON.parse(File.read("#{run_dir}/objectives.json"), symbolize_keys: true)
    expect(objs['objective_function_1']).to be_within(10).of(182)
    expect(objs['objective_function_target_1']).to be_within(1).of(1234)
    expect(objs['objective_function_group_2']).to eq(4)
    expect(File.exist?("#{run_dir}/run/RotateBuilding/rotate_building_out.osm")).to eq true
    expect(File.exist?("#{run_dir}/run/StandardReports/report.html")).to eq true
    expect(File.exist?("#{run_dir}/reports/eplustbl.html")).to eq true
    expect(File.exist?("#{run_dir}/reports/standard_reports.html")).to eq true
    expect(Dir.exist?("#{run_dir}/run/SetWindowToWallRatioByFacade")).to eq false

    # Test the measure attribute writing with pipes and periods
    expect(File.exist?("#{run_dir}/run/results.json")).to eq true
    expect(k.job_results[:run_reporting_measures][:rotate_building_relative_to_current_orientation].key?('An Attribute with Spaces'.to_sym)).to eq true
    expect(k.job_results[:run_reporting_measures][:rotate_building_relative_to_current_orientation].key?('Invalid_Period_Measure'.to_sym)).to eq true
    expect(k.job_results[:run_reporting_measures][:rotate_building_relative_to_current_orientation].key?('Invalid_Pipe_Measure'.to_sym)).to eq true
    expect(k.job_results[:run_reporting_measures][:rotate_building_relative_to_current_orientation].key?('Other_Random_Characters_with_dangling'.to_sym)).to eq true
    expect(k.job_results[:run_reporting_measures][:rotate_building_relative_to_current_orientation].key?('Asterisks_Are_Bad_Too'.to_sym)).to eq true
    expect(k.job_results[:run_reporting_measures][:rotate_building_relative_to_current_orientation].key?('Every_Bad_Character_Here_Too'.to_sym)).to eq true
  end
end
