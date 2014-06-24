require 'rspec'
require 'spec_helper'

describe 'OpenStudio::Workflow' do
  before :all do

    begin
      require 'mongoid'
      require 'mongoid_paperclip'
      require 'delayed_job_mongoid'
      base_path = File.expand_path('spec/files/mongoid')

      puts "Base path for mongoid models is: #{base_path}"

      Dir["#{base_path}/models/*.rb"].each { |f| puts f; require f }
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
      puts "No Mongo"
    end

  end

  it 'should run a local file adapater in legacy mode' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/local_ex1'
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
    expect(k.directory).to eq  File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should run a local file with minimum format' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/local_ex2'
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

  it 'should not find the input file' do
    run_dir = './spec/files/local_ex1'
    k = OpenStudio::Workflow.load 'Local', run_dir
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to be :errored
    expect(k.final_state).to be :errored
  end

  it 'should create a mongo file adapater and run the verbose format' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/mongo_ex1'
    options = {
        datapoint_id: '4f0b5de0-babf-0131-609d-080027880ca6',
        analysis_root_path: 'spec/files/example_models',
        use_monthly_reports: true,
        adapter_options: {
            mongoid_path: './spec/files/mongoid',
        }
    }
    k = OpenStudio::Workflow.load 'Mongo', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq  File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should create a mongo file adapater and run the concise format', mongo: true do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/mongo_ex3'
    options = {
        datapoint_id: 'f348e59a-e1c3-11e3-8b68-0800200c9a66',
        analysis_root_path: 'spec/files/example_models',
        use_monthly_reports: true,
        adapter_options: {
            mongoid_path: './spec/files/mongoid',
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
      expect(k.adapter.datapoint[:results][:standard_report_legacy][:total_energy]).to be_within(10).of(321.26)
      expect(k.adapter.datapoint[:results][:standard_report_legacy][:total_source_energy]).to be_within(10).of(865.73)
    end

    # Look at the results in teh job_results hash
    expect(k.job_results).to be_a Hash
    expect(k.job_results[:run_postprocess][:lighting_loads_user_customized_name][:lighting_power_reduction_percent]).to be_within(1).of(26.375)
    # expect(k.job_results[:run_postprocess][:standard_report][:total_building_area]).to be_within(1).of(26.375)
    #expect(k.job_results[:run_postprocess][:standard_report][:total_site_energy_eui]).to be_within(10).of(321.26)
    expect(k.job_results[:run_postprocess][:standard_report_legacy][:total_energy]).to be_within(10).of(321.26)

    #expect(k.job_results[:run_postprocess][:standard_report][:total_source_energy_eui]).to be_within(10).of(865.73)
    expect(k.job_results[:run_postprocess][:standard_report_legacy][:total_source_energy]).to be_within(10).of(865.73)

    expect(File.exist?("#{run_dir}/objectives.json")).to eq true
    expect(File.exist?("#{run_dir}/data_point_#{options[:datapoint_id]}.zip")).to eq true
    objs = JSON.parse(File.read("#{run_dir}/objectives.json"), :symbolize_keys => true)
    expect(objs['objective_function_1']).to be_within(10).of(182)
    expect(objs['objective_function_target_1']).to be_within(1).of(1234)
    expect(objs['objective_function_group_2']).to eq(4)
    expect(File.exist?("#{run_dir}/run/RotateBuilding/rotate_building_out.osm")).to eq true
    expect(File.exist?("#{run_dir}/run/StandardReports/report.html")).to eq false
    expect(File.exist?("#{run_dir}/reports/eplustbl.html")).to eq true
    expect(File.exist?("#{run_dir}/reports/standard_reports.html")).to eq true
  end

  # it 'should add a new state and transition' do
  #   transitions = OpenStudio::Workflow::Run.default_transition
  #   transitions[1][:to] = :xml
  #   transitions.insert(2, {from: :xml, to: :openstudio})
  #
  #   states = OpenStudio::Workflow::Run.default_states
  #   states.insert(2, {:state => :xml, :options => {:after_enter => :run_xml}})
  #   options = {
  #       transitions: transitions,
  #       states: states,
  #       analysis_root_path: '../assetscore-openstudio/PNNL_Multi_Block_OS_Console/test_measures',
  #       xml_library_file: '../assetscore-openstudio/PNNL_Multi_Block_OS_Console/main'
  #   }
  #   pp options
  #   run_dir = './spec/files/mongo_xml1'
  #   k = OpenStudio::Workflow.load 'Local', run_dir, options
  #   expect(k).to be_instance_of OpenStudio::Workflow::Run
  #   expect(k.directory).to eq run_dir
  #   expect(k.run).to eq :finished
  #   expect(k.final_state).to eq :finished
  # end

  it 'should add a new state and transition with geometry manipulation' do
    transitions = OpenStudio::Workflow::Run.default_transition
    transitions[1][:to] = :xml
    transitions.insert(2, {from: :xml, to: :openstudio})

    states = OpenStudio::Workflow::Run.default_states
    states.insert(2, {:state => :xml, :options => {:after_enter => :run_xml}})
    options = {
        transitions: transitions,
        states: states,
        analysis_root_path: '../assetscore-openstudio/PNNL_Multi_Block_OS_Console/test_measures',
        xml_library_file: '../assetscore-openstudio/PNNL_Multi_Block_OS_Console/main'
    }
    pp options
    run_dir = './spec/files/mongo_xml2'
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path(run_dir)
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should create a new datapoint based on a list' do
    run_dir = './spec/files/dynamically_created'
    dp_uuid = "random_datapoint_uuid"
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
    expect(File.exist?(k.directory)).to be_true

    # TODO: move this into a method to handle the creation
    # if this is mongo adapter, then it will have the models loaded
    dp = DataPoint.find_or_create_by(uuid: dp_uuid)
    expect(dp.save!).to be_true
    expect(dp.id).to eq dp_uuid

    # check for logging
    k.logger.info "Test log message"
    expect(dp.sdp_log_file.last).not_to include "Test log message"
    dp.reload
    expect(dp.sdp_log_file.last).to include "Test log message"
  end
end