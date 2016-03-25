require 'spec_helper'

describe String do
  it 'should snake case' do
    expect('RunManager'.to_underscore).to eq 'run_manager'
    expect('CreateJsonFile'.to_underscore).to eq 'create_json_file'
    expect('CreateJSONFile'.to_underscore).to eq 'create_json_file'
  end
end
