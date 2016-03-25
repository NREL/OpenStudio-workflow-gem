module OpenStudio
  module Workflow
    module Util

      # Manages routine tasks involving OpenStudio::Model or OpenStudio::Workflow objects, such as loading, saving, and
      # translating them. Currently loading IDFs is not supported, as the version translator needs to be worked into
      # the gem for loading IDFs to be safe
      #
      module Model

        # Method to create / load a seed OSM file
        #
        # @param [String] directory The base directory to append all relative directories to
        # @param [String] model The OSM file being searched for. If not the name of the file this parameter should be
        #   the absolute path specifying it's location
        # @param [Array] model_search_array The set of precedence ordered relative directories to search for the wf in.
        #   A typical entry might look like `['files', '../../files']`
        # @return [Object] The return from this method is a loaded OSM or a failure. The order of precedence for paths
        #   is as follows: 1 - an absolute path defined in model, 2 - the model_search_array, should it be defined,
        #   joined with the OSM file and appended to the directory, with each entry in the array searched until the osm
        #   model is found, 3 - an empty model if the model value is set to nil
        #
        def load_seed_osm(directory, model, model_search_array)
          Workflow.logger.info 'Loading seed model'
          if model
            osm_path = nil
            if Pathname.new(model).absolute?
              osm_path = model
            else
              model_search_array.each do |model_dir|
                fail "The path #{model_dir} does not exist" unless File.exists? File.join(directory, model_dir)
                if Dir.entries(File.join(directory, model_dir)).include? model
                  osm_path = File.absolute_path(File.join(directory, model_dir, model))
                  break
                end
              end
            end
            unless osm_path
              Workflow.logger.warn 'The seed OSM file was not found on the filesystem'
              return nil
            end
            Workflow.logger.info "Seed OSM file with precedence in the file system is #{osm_path}"
            unless File.exist? osm_path
              Workflow.logger.warn 'The seed OSM file could not be found on the filesystem'
              osm_path = false
            end
          else
            # @todo this is hardcoded, move to constant
            osm_path = File.join(directory, 'files/empty.osm')
            File.open(osm_path).close
          end

          # Load the model and return it
          Workflow.logger.info "Reading in seed model #{osm_path}"
          translator = OpenStudio::OSVersion::VersionTranslator.new
          loaded_model = translator.loadModel(osm_path)
          fail 'OpenStudio model can not be loaded. Please investigate' unless loaded_model.is_initialized?
          Workflow.logger.warn 'OpenStudio model is empty or could not be loaded' if loaded_model.empty?
          loaded_model.get
        end

        # Method to create / load a seed IDF file. Not yet implemented
        #
        # @todo (rhorsey) this method needs to be written
        #
        def load_seed_idf
          fail 'Method not yet implemented'
        end

        # Translates a OpenStudio model object into an OpenStudio IDF object
        #
        # @param [Object] model the OpenStudio::Model instance to translate into an OpenStudio::Workspace object -- see
        #   the OpenStudio SDK for details on the process
        # @return [Object] Returns and OpenStudio::Workspace object
        #
        def translate_to_energyplus(model)
          Workflow.logger.info 'Translate object to EnergyPlus IDF in Prep for EnergyPlus Measure'
          a = ::Time.now
          # ensure objects exist for reporting purposes
          model.getFacility
          model.getBuilding
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          model_idf = forward_translator.translateModel(@model)
          b = ::Time.now
          Workflow.logger.info "Translate object to EnergyPlus IDF took #{b.to_f - a.to_f}"
          model_idf
        end

        # Saves an OpenStudio model object to file
        #
        # @param [Object] model The OpenStudio::Model instance to save to file
        # @param [String] save_directory Folder to save the model in
        # @param [String] name ('in.osm') Option to define a non-standard name
        # @return [Void]
        #
        def save_osm(model, save_directory, name = 'in.osm')
          osm_filename = File.join(save_directory, name)
          File.open(osm_filename, 'w') { |f| f << model.to_s }
          Workflow.logger.info "Saved the OSM model as #{osm_filename}"
        end

        # Saves an OpenStudio IDF model object to file
        #
        # @param [Object] model The OpenStudio::Workspace instance to save to file
        # @param [String] save_directory Folder to save the model in
        # @param [String] name ('in.osm') Option to define a non-standard name
        # @return [Void]
        #
        def save_idf(model_idf, save_directory, name = 'in.idf')
          idf_filename = File.join(save_directory, name)
          File.open(idf_filename, 'w') { |f| f << model_idf.to_s }
          Workflow.logger.info "Saved the IDF model as #{idf_filename}"
        end
      end
    end
  end
end
