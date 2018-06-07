# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
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

require 'spec_helper'

describe TimeLogger do
  describe 'single value' do
    before :all do
      @t = TimeLogger.new
    end

    it 'should create an instance' do
      expect(@t).not_to be nil
    end

    it 'should log time' do
      @t.start('test')
      expect(@t.channels['test']).not_to eq nil

      sleep 1
      @t.stop('test')

      expect(@t.channels['test']).to eq nil
    end

    it 'should report time' do
      expect(@t.delta('test').first.key?('test')).to eq true
      time_hash = @t.delta('test').first
      puts time_hash
      expect(time_hash['test']).to be_within(0.1).of(1)
    end
  end

  describe 'multiple values' do
    before :all do
      @t = TimeLogger.new
    end

    it 'should log multiple times' do
      @t.start('log channel with spaces')
      sleep 1
      @t.start('second_channel')
      @t.start('third channel')
      sleep 1
      @t.stop_all

      r = @t.report
      expect(r).to be_an Array
      expect(r.first[:delta]).to be_within(0.1).of(2)
      expect(r.last[:delta]).to be_within(0.1).of(1)
      puts @t.report

      expect(@t.delta('log channel with spaces')).to be_a Array
      expect(@t.delta('log channel with spaces').size).to eq 1
      expect(@t.delta('log channel with spaces').first.values.first).to be_within(0.1).of(2)
    end
  end
end
