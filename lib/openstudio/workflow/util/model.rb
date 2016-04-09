module OpenStudio
  module Workflow
    module Util

      # Manages routine tasks involving OpenStudio::Model or OpenStudio::Workflow objects, such as loading, saving, and
      # translating them. Currently loading IDFs is not supported, as the version translator needs to be worked into
      # the gem for loading IDFs to be safe
      #
      module Model
        
        require 'logger'

        # Method to create / load an OSM file
        #
        # @param [String] directory The base directory to append all relative directories to
        # @param [String] model The OSM file being searched for. If not the name of the file this parameter should be
        #   the absolute path specifying it's location
        # @param [Array] model_search_array The set of precedence ordered relative directories to search for the wf in.
        #   A typical entry might look like `['files', '../../files']`
        # @param [Object] logger An optional logger to use for finding the OSM model
        # @return [Object] The return from this method is a loaded OSM or a failure. The order of precedence for paths
        #   is as follows: 1 - an absolute path defined in model, 2 - the model_search_array, should it be defined,
        #   joined with the OSM file and appended to the directory, with each entry in the array searched until the osm
        #   model is found, 3 - an empty model if the model value is set to nil
        #
        def load_osm(directory, model, model_search_array = [], logger=nil)
          logger = ::Logger.new(STDOUT) unless logger
          logger.info 'Loading OSM model'
          if model
            osm_path = nil
            if Pathname.new(model).absolute?
              osm_path = model
            else
              model_search_array.each do |model_dir|
                logger.warn "The path #{model_dir} does not exist" unless File.exists? File.join(directory, model_dir)
                next unless File.exists? File.join(directory, model_dir)
                if Dir.entries(File.join(directory, model_dir)).include? File.basename(model)
                  osm_path = File.absolute_path(File.join(directory, model_dir, model))
                  break
                end
              end
            end
            unless osm_path
              logger.warn 'The OSM file was not found on the filesystem'
              return nil
            end
            logger.info "The OSM file with precedence in the file system is #{osm_path}"
            fail 'The OSM file could not be found on the filesystem' unless File.exist? osm_path
          else
            # @todo this is hardcoded, move to constant
            osm_path = File.join(directory, 'files/empty.osm')
            File.open(osm_path, 'a').close
          end

          # Load the model and return it
          logger.info "Reading in OSM model #{osm_path}"
          translator = OpenStudio::OSVersion::VersionTranslator.new
          loaded_model = translator.loadModel(osm_path)
          fail 'OpenStudio model can not be loaded. Please investigate' unless loaded_model.is_initialized
          logger.warn 'OpenStudio model is empty or could not be loaded' if loaded_model.empty?
          loaded_model.get
        end

        # Method to create / load an IDF file
        #
        # @param [String] directory The base directory to append all relative directories to
        # @param [String] model The IDF file being searched for. If not the name of the file this parameter should be
        #   the absolute path specifying it's location
        # @param [Array] model_search_array The set of precedence ordered relative directories to search for the wf in.
        #   A typical entry might look like `['files', '../../files']`
        # @param [Object] logger An optional logger to use for finding the idf model
        # @return [Object] The return from this method is a loaded IDF or a failure. The order of precedence for paths
        #   is as follows: 1 - an absolute path defined in model, 2 - the model_search_array, should it be defined,
        #   joined with the IDF file and appended to the directory, with each entry in the array searched until the IDF
        #   model is found, 3 - an empty model if the model value is set to nil
        #
        def load_idf(directory, idf_model, model_search_array = [], logger=nil)
          logger = ::Logger.new(STDOUT) unless logger
          logger.info 'Loading IDF model'
          if idf_model
            idf_path = nil
            if Pathname.new(idf_model).absolute?
              idf_path = idf_model
            else
              model_search_array.each do |model_dir|
                logger.warn "The path #{model_dir} does not exist" unless File.exists? File.join(directory, model_dir)
                next unless File.exists? File.join(directory, model_dir)
                if Dir.entries(File.join(directory, model_dir)).include? File.basename(idf_model)
                  idf_path = File.absolute_path(File.join(directory, model_dir, idf_model))
                  break
                end
              end
            end
            unless idf_path
              logger.warn 'The IDF file was not found on the filesystem'
              return nil
            end
            logger.info "The IDF file with precedence in the file system is #{idf_path}"
            fail 'The IDF file could not be found on the filesystem' unless File.exist? idf_path
          else
            # @todo this is hardcoded, move to constant
            osm_path = File.join(directory, 'files/empty.idf')
            File.open(osm_path, 'a').close
          end

          # Load the IDF into a workspace object and return it
          logger.info "Reading in IDF model #{idf_path}"
          OpenStudio::Workspace.load(idf_path).get
        end

        # Translates a OpenStudio model object into an OpenStudio IDF object
        #
        # @param [Object] model the OpenStudio::Model instance to translate into an OpenStudio::Workspace object -- see
        #   the OpenStudio SDK for details on the process
        # @return [Object] Returns and OpenStudio::Workspace object
        # @todo (rhorsey) rescue errors here
        #
        def translate_to_energyplus(model, logger=nil)
          logger = ::Logger.new(STDOUT) unless logger
          logger.info 'Translate object to EnergyPlus IDF in Prep for EnergyPlus Measure'
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
          osm_filename = File.join(save_directory, name)
          File.open(osm_filename, 'w') { |f| f << model.to_s }
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
          idf_filename = File.join(save_directory, name)
          File.open(idf_filename, 'w') { |f| f << model_idf.to_s }
          idf_filename
        end
      end
    end
  end
end
