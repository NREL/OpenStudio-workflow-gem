module OpenStudio
  module Workflow
    module Util

      # Manages routine tasks involving OpenStudio::Model or OpenStudio::Workflow objects, such as loading, saving, and
      #   translating them. Currently loading IDFs is not supported, as the version translator needs to be worked into
      #   the gem for loading IDFs to be safe
      #
      module Model

        # Method to create / load a seed OSM file
        #
        # @param [String] directory Directory to find the osm_path from, or to use as the base directory to create
        #   directory/files/empty.osm in
        # @param [String] osm_path (nil) Path to find an OSM to load if not nil. If relative, the directory is used as
        #   the base, however if the path is absolute the directory will be disregarded
        # @return [Object] An OpenStudio::Model object
        #
        def load_seed_osm(directory, osm_path = nil)
          logger.info 'Loading seed model'

          # Get and validate the model path or create a model called empty.osm
          if osm_path
            logger.info "Seed model is #{osm_path}"
            # The osm_path is relative to the directory if realtive
            Pathname.new(osm_path).absolute? ? model_path = osm_path : model_path = File.join(directory, osm_path)
            fail "The seed model file could not be found at #{model_path}" unless File.exist? model_path
          else
            model_path = File.join(directory, 'files/empty.osm')
            File.open(model_path).close
          end

          # Load the model and return it
          logger.info "Reading in baseline model #{model_path}"
          translator = OpenStudio::OSVersion::VersionTranslator.new
          model = translator.loadModel(model_path)
          fail 'OpenStudio model is empty or could not be loaded' if model.empty?
          model.get
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
          logger.info 'Translate object to EnergyPlus IDF in Prep for EnergyPlus Measure'
          a = ::Time.now
          # ensure objects exist for reporting purposes
          model.getFacility
          model.getBuilding
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          model_idf = forward_translator.translateModel(@model)
          b = ::Time.now
          logger.info "Translate object to EnergyPlus IDF took #{b.to_f - a.to_f}"
          model_idf
        end

        # Saves an OpenStudio model object to file
        #
        # @param [Object] model The OpenStudio::Model instance to save to file
        # @param [String] directory Folder to save the model in
        # @param [String] name ('in.osm') Option to define a non-standard name
        # @return [Void]
        #
        def save_osm(model, directory, name = 'in.osm')
          osm_filename = File.join(directory, name)
          File.open(osm_filename, 'w') { |f| f << model.to_s }
          logger.info "Saved the OSM model as #{osm_filename}"
        end

        # Saves an OpenStudio IDF model object to file
        #
        # @param [Object] model The OpenStudio::Workspace instance to save to file
        # @param [String] directory Folder to save the model in
        # @param [String] name ('in.osm') Option to define a non-standard name
        # @return [Void]
        #
        def save_idf(model_idf, directory, name = 'in.idf')
          idf_filename = File.join(directory, name)
          File.open(idf_filename, 'w') { |f| f << model_idf.to_s }
          logger.info "Saved the IDF model as #{idf_filename}"
        end
      end
    end
  end
end
