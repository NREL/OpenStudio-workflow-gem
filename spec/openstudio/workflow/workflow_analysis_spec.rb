require_relative './../../spec_helper'
require 'json-schema'

def get_schema(allow_optionals = true)
  schema = nil
  schema_path = File.dirname(__FILE__) + '/../../schema/osw.json'
  expect(File.exists?(schema_path)).to be true
  File.open(schema_path) do |f|
    schema = JSON.parse(f.read, {:symbolize_names => true})
  end
  expect(schema).to_not be_nil
  
  schema[:definitions].each_value do |definition|
    definition[:additionalProperties] = allow_optionals
  end
  
  schema
end

def get_osw(path)
  osw = nil
  osw_path = File.dirname(__FILE__) + '/../../files/' + path
  expect(File.exists?(osw_path)).to be true
  File.open(osw_path) do |f|
    osw = JSON.parse(f.read, {:symbolize_names => true})
  end
  expect(osw).to_not be_nil
  
  osw
end

def validate_osw(path, allow_optionals = true)
  schema = get_schema(allow_optionals)
  osw = get_osw(path)

  errors = JSON::Validator.fully_validate(schema, osw)
  expect(errors.empty?).to eq(true), "OSW '#{path}' is not valid, #{errors}"
end

describe 'OSW Schema' do
  it 'should be a valid OSW file' do
    validate_osw('compact_osw/compact.osw', true)
    validate_osw('extended_osw/example/workflows/extended.osw', true)
  end

  # @todo (rhorsey) make another schema which has a measure load the seed model to allow for testing a no-opt OSW
  it 'should be a strictly valid OSW file' do
    validate_osw('compact_osw/compact.osw', true)
    validate_osw('extended_osw/example/workflows/extended.osw', true)
  end
end

describe 'OSW Integration' do
  it 'should run compact OSW file' do
    # for local, it uses the rundir as the uuid. When using the analysis gem, the root path is difficult because
    # it requires you to know the relative path to the measure which you already added when constructing the workflow.
    # best to keep the analysis_root_path empty when using the programmatic interface and rely on unzipping the data
    # to the run directory
    adapter_options = {
        workflow_filename: File.join('compact.osw')
    }
    adapter = OpenStudio::Workflow.load_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/compact_osw')
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
    adapter = OpenStudio::Workflow.load_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/extended_osw/example/workflows')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run an alternate path OSW file' do
    adapter_options = {
        workflow_filename: 'in.osw'
    }
    adapter = OpenStudio::Workflow.load_adapter 'local', adapter_options
    relative_osw = File.join(__FILE__, './../../../files/alternate_paths/osw_and_stuff')
    run_options = {
        debug: true
    }
    k = OpenStudio::Workflow::Run.new adapter, relative_osw, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end
end
