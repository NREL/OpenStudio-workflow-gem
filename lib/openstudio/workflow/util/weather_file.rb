module OpenStudio
  module Workflow
    module Util

      # The current precedence rules for weather files are defined in this module. Best practice is to only use the
      #  #get_weather_file method, as it will be forward compatible
      #
      module WeatherFile

        # Returns the weather file with precedence, and fail if it is not found or the path invalid
        #
        # @param [Hash] workflow The OSW hash to parse, see #get_weather_file_from_osw
        # @param [Object] model The OpenStudio::Model object to parse, see #get_weather_file_from_osm
        # @return [String] The weather file with precedence
        #
        def get_weather_file(workflow, model)
          wf = get_weather_file_from_osw(workflow)
          wf = get_weather_file_from_osm(model) if wf == nil
          fail 'The weatherfile could not be found on the filesystem. Please see the log for details' unless wf
          wf
        end

        # Returns the weather file from the model. If the weather file is defined in the model, then
        # it checks the file paths to check if the model exists. This allows for a user to upload a
        # weather file in a measure and then have the measure's path be used for the weather file.
        #
        # @todo (rhorsey) verify the description of this method, as it seems suspect
        # @param [Object] model The OpenStudio::Model object to retrieve the weather file from
        # @return [nil,false, String] If the result is nil the weather file was not defined in the model, if the result
        #   is false the weather file was set but could not be found on the filesystem, if a string the weather file was
        #   defined and it's existence verified
        #
        def get_weather_file_from_osm(model)
          wf = nil
          # grab the weather file out of the OSM if it exists
          if model.weatherFile.empty?
            logger.warn 'No weather file defined in the model'
          else
            p = model.weatherFile.get.path.get.to_s.gsub('file://', '')
            if File.exist? p
              wf = File.absolute_path(p)
            else
              # this is the weather file from the OSM model
              wf = File.absolute_path(@model.weatherFile.get.path.get.to_s)
            end
            logger.info "The weather file path found in the model object: #{wf}"
            unless File.exist? wf
              logger.warn 'The weather file could not be found on the filesystem.'
              wf = false
            end
          end
          wf
        end

        # Returns the weather file defined in the OSW
        #
        # @param [Hash] workflow The OSW hash to parse for the weather file. The order of precedence for paths is as
        #   follows: 1 - an absolute path defined in :weather file, 2 - the :files_path, should it be defined, joined
        #   with the weather file, 3 - the :root_path, should it be defined, joined with the weather file, 4 - the
        #   current run directory joined with the weather file
        # @return [nil, false, String] If the result is nil the weather file was not defined in the workflow, if the
        #   result is false the weather file was set but could not be found on the filesystem, if a string the
        #   weather file was defined and it's existence verified
        #
        def get_weather_file_from_osw(workflow)
          wf = nil
          # get the weather file out of the OSW if it exists
          if workflow[:weather_file]
            wf = workflow[:weather_file]
            if Pathname.new(workflow).absolute?
            elsif workflow[:files_dir]
              wf = File.join(workflow[:files_dir], wf)
            elsif workflow[:root_dir]
              wf = File.join(workflow[:root_dir], wf)
            else
              wf = File.join(Dir.pwd, wf)
            end
            logger.info "Weather file with precedence in the OSW is #{wf}"
            unless File.exist? wf
              logger.warn 'The weather file could not be found on the filesystem.'
              wf = false
            end
          else
            logger.warn 'No weather file defined in the workflow'
          end
          wf
        end
      end
    end
  end
end
