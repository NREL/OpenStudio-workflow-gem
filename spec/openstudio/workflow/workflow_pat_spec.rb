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

      # Delete all the zip files before running this test
      Dir['spec/files/pat_project/**/*.zip'].each { |f| FileUtils.rm_f f }
      Dir['spec/files/mongo_pat1/**/*.zip'].each { |f| FileUtils.rm_f f }

      # read in the pat data_point
      dp_json_filename = 'spec/files/pat_project/data_point_d85b5ffa-b8f0-4bc1-b8af-da6df0da4267/data_point.json'
      analysis_filename = 'spec/files/pat_project/formulation.json'
      if File.exist?(dp_json_filename) && File.exist?(analysis_filename)
        dp_json = MultiJson.load(File.read(dp_json_filename), symbolize_keys: true)
        analysis_json = MultiJson.load(File.read(analysis_filename), symbolize_keys: true)
        dp = DataPoint.create(dp_json[:data_point])
        a = Analysis.create(analysis_json[:analysis])
        dp.save!
        a.save!
      else
        fail 'could not find data to populate database'
      end
    rescue LoadError
      puts 'No Mongo'
    end
  end

  skip 'should run a local file with pat format' do
    data_files = './spec/files/pat_project/data_point_469b52c3-4aae-4cdd-b580-5c9494eefa11'

    run_dir = "#{ENV['SIMULATION_RUN_DIR']}/pat/data_point_469b52c3-4aae-4cdd-b580-5c9494eefa11"
    FileUtils.rm_rf run_dir if Dir.exist? run_dir
    FileUtils.mkdir_p run_dir

    # copy over the test file to the run directory
    FileUtils.cp_r(Dir["#{data_files}/*"], run_dir)

    # for local, it uses the rundir as the uuid
    options = {
      is_pat: true,
      problem_filename: '../formulation.json',
      datapoint_filename: 'data_point.json',
      analysis_root_path: 'spec/files/pat_project'
    }
    k = OpenStudio::Workflow.load 'Local', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.options[:problem_filename]).to eq '../formulation.json'
    expect(k.options[:datapoint_filename]).to eq 'data_point.json'
    expect(k.directory).to eq File.expand_path(run_dir)

    # load in the data_point_out.json and check to make sure that it found energyplus
    expect(File.exist?("#{run_dir}/data_point_out.json")).to eq true

    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished

    f = File.read("#{run_dir}/data_point_out.json")
    expect(f =~ /Unable to find valid executable while creating local process/).to eq nil

    expect(File.exist?("#{run_dir}/data_point.zip")).to eq true
    expect(File.exist?("#{run_dir}/data_point_reports.zip")).to eq true
  end

  skip 'should create a mongo file adapater and run the verbose format' do
    run_dir = "#{ENV['SIMULATION_RUN_DIR']}/mongo_pat1"
    dp = 'd85b5ffa-b8f0-4bc1-b8af-da6df0da4267'
    options = {
      is_pat: true,
      datapoint_id: dp,
      analysis_root_path: 'spec/files/pat_project',
      adapter_options: {
        mongoid_path: './spec/files/mongoid'
      }
    }
    k = OpenStudio::Workflow.load 'Mongo', run_dir, options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.directory).to eq File.expand_path(run_dir)

    expect(k.run).to eq :finished
    expect(k.final_state).to eq :finished

    # load in the data_point_out.json and check to make sure that it found energyplus
    expect(File.exist?("#{run_dir}/data_point_out.json")).to eq true

    f = File.read("#{run_dir}/data_point_out.json")
    expect(f =~ /Unable to find valid executable while creating local process/).to eq nil

    expect(File.exist?("#{run_dir}/data_point_#{dp}.zip")).to eq true
    expect(File.exist?("#{run_dir}/data_point_#{dp}_reports.zip")).to eq true
  end
end
