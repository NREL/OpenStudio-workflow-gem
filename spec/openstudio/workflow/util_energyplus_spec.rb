require 'spec_helper'

describe 'EnergyPlus Module' do

  it 'should find EnergyPlus' do
    OpenStudio::Workflow::Util::EnergyPlus::find_energyplus
  end

end

