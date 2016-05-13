require_relative './../../spec_helper'
require 'json-schema'

describe 'OSW Integration' do

  it 'should run empty OSW file' do
    osw_path = File.join(__FILE__, './../../../files/empty_seed_osw/empty.osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
  
  it 'should run compact OSW file' do
    osw_path = File.join(__FILE__, './../../../files/compact_osw/compact.osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
  
  it 'should run an extended OSW file' do
    osw_path = File.join(__FILE__, './../../../files/extended_osw/example/workflows/extended.osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run an alternate path OSW file' do
    osw_path = File.join(__FILE__, './../../../files/alternate_paths/osw_and_stuff/in.osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
  
  it 'should run OSW file with skips' do
    osw_path = File.join(__FILE__, './../../../files/skip_osw/skip.osw')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
end
