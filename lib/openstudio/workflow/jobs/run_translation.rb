######################################################################
#  Copyright (c) 2008-2014, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

# Run the initialization job to validate the directory and initialize the adapters.
class RunTranslation < OpenStudio::Workflow::Job

  require_relative '../util/model'
  include OpenStudio::Workflow::Util::Model

  def initialize(adapter, registry, options = {})
    super
  end

  def perform
    Workflow.logger.info "Calling #{__method__} in the #{self.class} class"

    Workflow.logger.info 'Begining the translation to IDF'
    @registry[:time_logger].start('Translating to EnergyPlus') if @registry[:time_logger]
    model_idf = translate_to_energyplus @registry[:model]
    @registry.register(:model_idf) { model_idf }
    @registry[:time_logger].stop('Translating to EnergyPlus') if @registry[:time_logger]
    Workflow.logger.info 'Sucesfully translated to IDF'

    # return the results back to the caller -- always
    results = {}
  end
end
