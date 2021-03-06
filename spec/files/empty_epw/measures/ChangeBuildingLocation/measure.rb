# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
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

# Authors : Nicholas Long, David Goldwasser
# Simple measure to load the EPW file and DDY file

class ChangeBuildingLocation < OpenStudio::Measure::ModelMeasure

  Dir[File.dirname(__FILE__) + '/resources/*.rb'].each { |file| require file }

  # resource file modules
  include OsLib_HelperMethods

  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    'ChangeBuildingLocation'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    weather_file_name = OpenStudio::Measure::OSArgument.makeStringArgument('weather_file_name', true)
    weather_file_name.setDisplayName('Weather File Name')
    weather_file_name.setDescription('Name of the weather file to change to. This is the filename with the extension (e.g. NewWeather.epw). Optionally this can inclucde the full file path, but for most use cases should just be file name.')
    args << weather_file_name

    # make choice argument for climate zone
    choices = OpenStudio::StringVector.new
    choices << 'Lookup From Stat File'
    choices << 'ASHRAE 169-2006-1A'
    choices << 'ASHRAE 169-2006-1B'
    choices << 'ASHRAE 169-2006-2A'
    choices << 'ASHRAE 169-2006-2B'
    choices << 'ASHRAE 169-2006-3A'
    choices << 'ASHRAE 169-2006-3B'
    choices << 'ASHRAE 169-2006-3C'
    choices << 'ASHRAE 169-2006-4A'
    choices << 'ASHRAE 169-2006-4B'
    choices << 'ASHRAE 169-2006-4C'
    choices << 'ASHRAE 169-2006-5A'
    choices << 'ASHRAE 169-2006-5B'
    choices << 'ASHRAE 169-2006-5C'
    choices << 'ASHRAE 169-2006-6A'
    choices << 'ASHRAE 169-2006-6B'
    choices << 'ASHRAE 169-2006-7'
    choices << 'ASHRAE 169-2006-8'
    choices << 'T24-CEC1'
    choices << 'T24-CEC2'
    choices << 'T24-CEC3'
    choices << 'T24-CEC4'
    choices << 'T24-CEC5'
    choices << 'T24-CEC6'
    choices << 'T24-CEC7'
    choices << 'T24-CEC8'
    choices << 'T24-CEC9'
    choices << 'T24-CEC10'
    choices << 'T24-CEC11'
    choices << 'T24-CEC12'
    choices << 'T24-CEC13'
    choices << 'T24-CEC14'
    choices << 'T24-CEC15'
    choices << 'T24-CEC16'
    climate_zone = OpenStudio::Measure::OSArgument.makeChoiceArgument('climate_zone', choices, true)
    climate_zone.setDisplayName('Climate Zone.')
    climate_zone.setDefaultValue('Lookup From Stat File')
    args << climate_zone

    args
  end

  # Define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments(model))
    if !args then return false end

    # create initial condition
    if model.getWeatherFile.city != ''
      runner.registerInitialCondition("The initial weather file is #{model.getWeatherFile.city} and the model has #{model.getDesignDays.size} design day objects")
    else
      runner.registerInitialCondition("No weather file is set. The model has #{model.getDesignDays.size} design day objects")
    end

    # find weather file, checking both the location specified in the osw
    # and the path used by ComStock meta-measure
    wf_name = args['weather_file_name']
    comstock_weather_file = File.absolute_path(File.join(Dir.pwd, '../../files', wf_name))
    osw_weather_file = runner.workflow.findFile(wf_name)
    if File.file? comstock_weather_file
      weather_file = comstock_weather_file
    elsif osw_weather_file.is_initialized
      weather_file = osw_weather_file.get.to_s
    else
      runner.registerError("Did not find #{wf_name} in paths described in OSW file or in default ComStock workflow location of #{comstock_weather_file}.")
      return false
    end

    # Parse the EPW manually because OpenStudio can't handle multiyear weather files (or DATA PERIODS with YEARS)
    epw_file = OpenStudio::Weather::Epw.load(weather_file)

    weather_file = model.getWeatherFile
    weather_file.setCity(epw_file.city)
    weather_file.setStateProvinceRegion(epw_file.state)
    weather_file.setCountry(epw_file.country)
    weather_file.setDataSource(epw_file.data_type)
    weather_file.setWMONumber(epw_file.wmo.to_s)
    weather_file.setLatitude(epw_file.lat)
    weather_file.setLongitude(epw_file.lon)
    weather_file.setTimeZone(epw_file.gmt)
    weather_file.setElevation(epw_file.elevation)
    weather_file.setString(10, "file:///#{epw_file.filename}")

    weather_name = "#{epw_file.city}_#{epw_file.state}_#{epw_file.country}"
    weather_lat = epw_file.lat
    weather_lon = epw_file.lon
    weather_time = epw_file.gmt
    weather_elev = epw_file.elevation

    # Add or update site data
    site = model.getSite
    site.setName(weather_name)
    site.setLatitude(weather_lat)
    site.setLongitude(weather_lon)
    site.setTimeZone(weather_time)
    site.setElevation(weather_elev)

    runner.registerInfo("city is #{epw_file.city}. State is #{epw_file.state}")

    # Warn if no design days were added
    if model.getDesignDays.size.zero?
      runner.registerWarning("No design days were added to the model.")
    end

    # Set climate zone
    climateZones = model.getClimateZones
    if args['climate_zone'] == 'Lookup From Stat File'

      # get climate zone from stat file
      text = nil
      File.open(stat_file) do |f|
        text = f.read.force_encoding('iso-8859-1')
      end

      # Get Climate zone.
      # - Climate type "3B" (ASHRAE Standard 196-2006 Climate Zone)**
      # - Climate type "6A" (ASHRAE Standards 90.1-2004 and 90.2-2004 Climate Zone)**
      regex = /Climate type \"(.*?)\" \(ASHRAE Standards?(.*)\)\*\*/
      match_data = text.match(regex)
      if match_data.nil?
        runner.registerWarning("Can't find ASHRAE climate zone in stat file.")
      else
        args['climate_zone'] = match_data[1].to_s.strip
      end

    end
    # set climate zone
    climateZones.clear
    if args['climate_zone'].include?('CEC')
      climateZones.setClimateZone('CEC', args['climate_zone'].gsub('T24-CEC', ''))
      runner.registerInfo("Setting Climate Zone to #{climateZones.getClimateZones('CEC').first.value}")
    else
      climateZones.setClimateZone('ASHRAE', args['climate_zone'].gsub('ASHRAE 169-2006-', ''))
      runner.registerInfo("Setting Climate Zone to #{climateZones.getClimateZones('ASHRAE').first.value}")
    end

    # add final condition
    runner.registerFinalCondition("The final weather file is #{model.getWeatherFile.city} and the model has #{model.getDesignDays.size} design day objects.")

    true
  end
end

# This allows the measure to be use by the application
ChangeBuildingLocation.new.registerWithApplication
