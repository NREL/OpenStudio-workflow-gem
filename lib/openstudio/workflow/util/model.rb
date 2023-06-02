# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
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
          rescue StandardError
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
          logger ||= ::Logger.new($stdout)
          logger.info 'Translate object to EnergyPlus IDF in preparation for EnergyPlus'
          a = ::Time.now
          # ensure objects exist for reporting purposes
          model.getFacility
          model.getBuilding
          ft = OpenStudio::EnergyPlus::ForwardTranslator.new

          ft_options = @options[:ft_options]
          if !ft_options.empty?

            msg = "Custom ForwardTranslator options passed:\n"

            ft_options.each do |opt_flag_name, h|
              ft_method = h[:method_name]
              opt_flag = h[:value]

              # Call the FT setter with the value passed in
              ft.method(ft_method).call(opt_flag)

              msg += "* :#{opt_flag_name}=#{opt_flag} => ft.#{ft_method}(#{opt_flag})\n"
            end

            logger.info msg
          end

          model_idf = ft.translateModel(model)
          b = ::Time.now
          logger.info "Translate object to EnergyPlus IDF took #{b.to_f - a.to_f}"
          model_idf
        end

        # Translates an IDF model into an EnergyPlus epJSON object
        #
        # @param [Object] OpenStudio::IdfFile instance to translate into an OpenStudio epJSON object -- see
        #   the OpenStudio SDK for details on the process
        # @return [Object] Returns and OpenStudio::epJSONobject
        #
        def translate_idf_to_epjson(model_idf, logger = nil)
          logger ||= ::Logger.new($stdout)
          logger.info 'Translate IDF to epJSON in preparation for EnergyPlus'
          a = ::Time.now
          model_epjson = OpenStudio::EPJSON.toJSONString(model_idf)
          b = ::Time.now
          logger.info "Translate IDF to EnergyPlus epJSON took #{b.to_f - a.to_f}"

          model_epjson
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
            rescue StandardError
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
            rescue StandardError
              f.flush
            end
          end
          idf_filename
        end

        # Saves an OpenStudio EpJSON model object to file
        #
        # @param [Object] model The OpenStudio::Workspace instance to save to file
        # @param [String] save_directory Folder to save the model in
        # @param [String] name ('in.epJSON') Option to define a non-standard name
        # @return [String] epJSON file name
        #
        def save_epjson(model_epjson, save_directory, name = 'in.epJSON')
          epjson_filename = File.join(save_directory.to_s, name.to_s)
          File.open(epjson_filename, 'w') do |f|
            f << model_epjson.to_s
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue StandardError
              f.flush
            end
          end
          epjson_filename
        end
      end
    end
  end
end
