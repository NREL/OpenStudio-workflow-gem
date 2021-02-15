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

def get_schema(allow_optionals = true)
  schema = nil
  schema_path = File.dirname(__FILE__) + '/../../schema/osw.json'
  expect(File.exist?(schema_path)).to be true
  File.open(schema_path) do |f|
    schema = JSON.parse(f.read, symbolize_names: true)
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
  expect(File.exist?(osw_path)).to be true
  File.open(osw_path) do |f|
    osw = JSON.parse(f.read, symbolize_names: true)
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
