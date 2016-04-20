require_relative './../../spec_helper'
require 'json-schema'

describe 'OSW Integration' do
  it 'should run empty OSW file' do
    adapter_options = {
        workflow_filename: 'empty.osw',
        output_directory: File.absolute_path(File.join(__FILE__, './../../../files/empty_seed_osw/run'))
    }
    input_adapter = OpenStudio::Workflow.load_input_adapter 'local', adapter_options
    output_adapter = OpenStudio::Workflow.load_output_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/empty_seed_osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new input_adapter, output_adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
  
  it 'should run compact OSW file' do
    adapter_options = {
        workflow_filename: 'compact.osw',
        output_directory: File.absolute_path(File.join(__FILE__, './../../../files/compact_osw/run'))
    }
    input_adapter = OpenStudio::Workflow.load_input_adapter 'local', adapter_options
    output_adapter = OpenStudio::Workflow.load_output_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/compact_osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new input_adapter, output_adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
  
  it 'should run an extended OSW file' do
    adapter_options = {
        workflow_filename: 'extended.osw',
        output_directory: File.absolute_path(File.join(__FILE__, './../../../files/extended_osw/example/run'))
    }
    input_adapter = OpenStudio::Workflow.load_input_adapter 'local', adapter_options
    output_adapter = OpenStudio::Workflow.load_output_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/extended_osw/example/workflows')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new input_adapter, output_adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run an alternate path OSW file' do
    adapter_options = {
        workflow_filename: 'in.osw',
        output_directory: File.absolute_path(File.join(__FILE__, './../../../files/alternate_paths/osw_and_stuff/run'))
    }
    input_adapter = OpenStudio::Workflow.load_input_adapter 'local', adapter_options
    output_adapter = OpenStudio::Workflow.load_output_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/alternate_paths/osw_and_stuff')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new input_adapter, output_adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
  
  it 'should run OSW file with skips' do
    adapter_options = {
        workflow_filename: 'skip.osw',
        output_directory: File.absolute_path(File.join(__FILE__, './../../../files/skip_osw/run'))
    }
    input_adapter = OpenStudio::Workflow.load_input_adapter 'local', adapter_options
    output_adapter = OpenStudio::Workflow.load_output_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/skip_osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new input_adapter, output_adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
end
