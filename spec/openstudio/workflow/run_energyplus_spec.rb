require 'spec_helper'

require 'openstudio/workflow/jobs/run_energyplus/run_energyplus'

describe RunEnergyplus do
  describe 'find_energyplus' do
    before :all do
      @logger = ::Logger.new(STDOUT)
      @e = RunEnergyplus.new(nil, @logger, nil, nil, nil)
    end

    it 'should create an instance' do
      expect(@e).not_to be nil
    end

    it 'should find energyplus by openstudio method' do
      path = OpenStudio.getEnergyPlusDirectory.to_s
      expect(path).not_to be nil
      expect(path =~ //).not_to be nil

      %w(energyplus  EnergyPlus energyplus.exe EnergyPlus.exe).each do |eplus|
        @logger.info "Checking #{eplus}"
        expect(eplus =~ RunEnergyplus::ENERGYPLUS_REGEX).not_to be nil
      end

      %w(energyplus-8.3.0 energyplus.1).each do |eplus|
        @logger.info "Checking #{eplus}"
        expect(eplus =~ RunEnergyplus::ENERGYPLUS_REGEX).to eq nil
      end
    end
  end
end
