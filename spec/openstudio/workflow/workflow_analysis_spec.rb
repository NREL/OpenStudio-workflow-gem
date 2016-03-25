require 'spec_helper'

describe 'OSW Integration' do
  it 'should run compact OSW file' do
    # for local, it uses the rundir as the uuid. When using the analysis gem, the root path is difficult because
    # it requires you to know the relative path to the measure which you already added when constructing the workflow.
    # best to keep the analysis_root_path empty when using the programmatic interface and rely on unzipping the data
    # to the run directory
    adapter_options = {
        workflow_filename: 'compact.osw'
    }
    adapter = OpenStudio::Workflow.load_adapter 'local', options[adapter_options]
    relative_osw = './../../files/compact_osw'
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run an extended OSW file' do
    adapter_options = {
        workflow_filename: 'extended.osw'
    }
    adapter = OpenStudio::Workflow.load_adapter 'local', options[adapter_options]
    relative_osw = './../../files/extended_osw/example/workflows'
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
end
