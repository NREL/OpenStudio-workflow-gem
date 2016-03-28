require 'spec_helper'

describe 'EnergyPlus Module' do

  it 'should find EnergyPlus' do
    # todo (rhorsey) - How can I test this method?  If I change it to self.find_energyplus in energyplus.rb then other methods break - DLM
    OpenStudio::Workflow::Util::EnergyPlus.find_energyplus
  end

end

