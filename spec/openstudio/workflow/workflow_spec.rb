require 'rspec'
require 'spec_helper'

describe 'OpenStudio::Workflow' do
  before :all do

  end

  it 'create a local file adapater' do
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
    expect(k.run).to eq true
  end

  it 'should not find the input file' do
    run_dir = './spec/files/local_ex1'
    k = OpenStudio::Workflow.load 'Local', run_dir
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect{k.run}.to raise_error "Problem file does not exist for ./spec/files/local_ex1/problem.json"
  end
end