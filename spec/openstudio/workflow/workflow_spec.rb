require 'rspec'
require 'spec_helper'

describe 'OpenStudio::Workflow' do
  before :all do
  
    begin
      require 'mongoid'
      require 'mongoid_paperclip'
      require 'delayed_job_mongoid'
      base_path = "#{File.expand_path(File.join(File.dirname(__FILE__), '../../../lib/OpenStudio/workflow/adapters/mongo'))}"

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
      puts "No Mongo"
    end

  end

  it 'should run a local file adapater in legacy mode' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/local_ex1'
    options = {
        problem_filename: 'analysis_1.json',
        datapoint_filename: 'datapoint_1.json',
        measures_root_path: '../example_models',
        use_monthly_reports: true
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq 'analysis_1.json'
    expect(k.options[:datapoint_filename]).to eq 'datapoint_1.json'
    expect(k.directory).to eq run_dir
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should run a local file with minimum format' do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/local_ex2'
    options = {
        problem_filename: 'analysis_1.json',
        datapoint_filename: 'datapoint_1.json',
        measures_root_path: '../example_models',
        use_monthly_reports: true
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq 'analysis_1.json'
    expect(k.options[:datapoint_filename]).to eq 'datapoint_1.json'
    expect(k.directory).to eq run_dir
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
        measures_root_path: '../example_models',
        use_monthly_reports: true
    }
    k = OpenStudio::Workflow.load 'Mongo', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq run_dir
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should create a mongo file adapater and run the concise format', mongo: true do
    # for local, it uses the rundir as the uuid
    run_dir = './spec/files/mongo_ex3'
    options = {
        datapoint_id: 'f348e59a-e1c3-11e3-8b68-0800200c9a66',
        measures_root_path: '../example_models',
        use_monthly_reports: true
    }
    k = OpenStudio::Workflow.load 'Mongo', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq run_dir
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end

  it 'should add a new state and transition' do
    transitions = OpenStudio::Workflow::Run.default_transition
    transitions[1][:to] = :xml
    transitions.insert(2, {from: :xml, to: :openstudio})

    states = OpenStudio::Workflow::Run.default_states
    states.insert(2, {:state => :xml, :options => {:after_enter => :run_xml}})
    options = {transitions: transitions,
               states: states,
               measures_root_path: '.'}
    run_dir = './spec/files/mongo_xml1'
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq run_dir
    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished
  end
end