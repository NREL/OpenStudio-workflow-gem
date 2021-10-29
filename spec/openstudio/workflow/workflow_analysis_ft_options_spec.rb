# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

require_relative './../../spec_helper'
require 'json-schema'

describe 'OSW Integration' do
  it 'should run empty OSW file' do
    osw_path = File.join(__FILE__, './../../../files/empty_seed_osw/empty.osw')
    run_options = {
      debug: true,
      epjson: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run compact OSW file with translator option space_translation' do
    osw_path = File.expand_path('../../files/compact_osw/compact.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {

       debug: true,
       ft_options: {
         runcontrolspecialdays: false,
         ip_tabular_output: false,
         no_lifecyclecosts: false,
         no_sqlite_output: false,
         no_html_output: false,
         no_variable_dictionary: false,
         no_space_translation: false
       }

     }


    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run compact OSW file with translator options no space translation' do
    osw_path = File.expand_path('../../files/compact_osw/compact.osw', __dir__)
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {

      debug: true,
      ft_options: {
        runcontrolspecialdays: false,
        ip_tabular_output: false,
        no_lifecyclecosts: false,
        no_sqlite_output: false,
        no_html_output: false,
        no_variable_dictionary: false,
        no_space_translation: true
      }

    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end
end
