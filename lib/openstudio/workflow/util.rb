module OpenStudio
  module Workflow

    # Hard load utils for the moment
    #
    module Util
      require_relative 'util/measure'
      require_relative 'util/type_casting'
      require_relative 'util/directory'
      require_relative 'util/weather_file'
      require_relative 'util/model'
      require_relative 'util/energyplus'
    end
  end
end
