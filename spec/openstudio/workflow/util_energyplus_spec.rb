# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require_relative './../../spec_helper'
include OpenStudio::Workflow::Util::EnergyPlus

describe 'EnergyPlus Module' do
  it 'should find EnergyPlus' do
    energyplus_dir = find_energyplus
    expect(energyplus_dir).to be_instance_of String
    expect(File.exist?(energyplus_dir)).to eq true
  end
end
