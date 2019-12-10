# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
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

module OpenStudio
  module Workflow
    module Util
      # Manages routine tasks involving OpenStudio::Model or OpenStudio::Workflow objects, such as loading, saving, and
      # translating them.
      #
      module Model
        # Method to create / load an OSM file
        #
        # @param [String] osm_path The full path to an OSM file to load
        # @param [Object] logger An optional logger to use for finding the OSM model
        # @return [Object] The return from this method is a loaded OSM or a failure.
        #
        def load_osm(osm_path, logger)
          logger.info 'Loading OSM model'

          # Load the model and return it
          logger.info "Reading in OSM model #{osm_path}"

          loaded_model = nil
          begin
            translator = OpenStudio::OSVersion::VersionTranslator.new
            loaded_model = translator.loadModel(osm_path)
          rescue
            # TODO: get translator working in embedded.
            # Need to embed idd files
            logger.warn 'OpenStudio VersionTranslator could not be loaded'
            loaded_model = OpenStudio::Model::Model.load(osm_path)
          end
          raise "Failed to load OSM file #{osm_path}" if loaded_model.empty?
          loaded_model.get
        end

        # Method to create / load an IDF file
        #
        # @param [String] idf_path Full path to the IDF
        # @param [Object] logger An optional logger to use for finding the idf model
        # @return [Object] The return from this method is a loaded IDF or a failure.
        #
        def load_idf(idf_path, logger)
          logger.info 'Loading IDF model'

          # Load the IDF into a workspace object and return it
          logger.info "Reading in IDF model #{idf_path}"

          idf = OpenStudio::Workspace.load(idf_path)
          raise "Failed to load IDF file #{idf_path}" if idf.empty?
          idf.get
        end

        # Translates a OpenStudio model object into an OpenStudio IDF object
        #
        # @param [Object] model the OpenStudio::Model instance to translate into an OpenStudio::Workspace object -- see
        #   the OpenStudio SDK for details on the process
        # @return [Object] Returns and OpenStudio::Workspace object
        # @todo (rhorsey) rescue errors here
        #
        def translate_to_energyplus(model, logger = nil)
          logger = ::Logger.new(STDOUT) unless logger
          logger.info 'Translate object to EnergyPlus IDF in preparation for EnergyPlus'
          a = ::Time.now
          # ensure objects exist for reporting purposes
          model.getFacility
          model.getBuilding
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          model_idf = forward_translator.translateModel(model)
          b = ::Time.now
          logger.info "Translate object to EnergyPlus IDF took #{b.to_f - a.to_f}"
          model_idf
        end

        # Saves an OpenStudio model object to file
        #
        # @param [Object] model The OpenStudio::Model instance to save to file
        # @param [String] save_directory Folder to save the model in
        # @param [String] name ('in.osm') Option to define a non-standard name
        # @return [String] OSM file name
        #
        def save_osm(model, save_directory, name = 'in.osm')
          osm_filename = File.join(save_directory.to_s, name.to_s)
          File.open(osm_filename, 'w') do |f| 
            f << model.to_s 
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue
              f.flush
            end
          end
          osm_filename
        end

        # Saves an OpenStudio IDF model object to file
        #
        # @param [Object] model The OpenStudio::Workspace instance to save to file
        # @param [String] save_directory Folder to save the model in
        # @param [String] name ('in.osm') Option to define a non-standard name
        # @return [String] IDF file name
        #
        def save_idf(model_idf, save_directory, name = 'in.idf')
          idf_filename = File.join(save_directory.to_s, name.to_s)
          File.open(idf_filename, 'w') do |f| 
            f << model_idf.to_s 
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue
              f.flush
            end
          end
          idf_filename
        end
      end
    end
  end
end
