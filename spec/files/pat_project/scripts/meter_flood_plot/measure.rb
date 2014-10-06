require 'erb'
require 'json'

#start the measure
class MeterFloodPlot < OpenStudio::Ruleset::ReportingUserScript
  
  # define the name that a user will see
  def name
    return "Meter Flood Plot"
  end
  
  # define the description that a user will see
  def description
    return "This measures generates a flood plot of the requested meter."
  end
  
  # define the description that a modeler will see
  def modeler_description
    return "This measure can create a flood plot of any Output:Meter with hourly frequency."
  end
  
  #define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    os_version = OpenStudio::VersionString.new(OpenStudio::openStudioVersion())

    # make an argument for the meter name
    meter_name = OpenStudio::Ruleset::OSArgument::makeStringArgument("meter_name",true)
    meter_name.setDisplayName("Meter Name")
    if os_version >= OpenStudio::VersionString.new("1.4.3")
      meter_name.setDescription("Available meter names may be found in the .mdd file produced by EnergyPlus.")
    end
    meter_name.setDefaultValue("Electricity:Facility") 
    args << meter_name
   
    return args
  end 
  
  # request an output
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)
    
    result = OpenStudio::IdfObjectVector.new
    
    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(), user_arguments)
      return result
    end
    
    meter_name = runner.getStringArgumentValue("meter_name", user_arguments)

    request = OpenStudio::IdfObject.load("Output:Meter,#{meter_name},Hourly;").get
    result << request
    
    return result
  end
  
  def neat_numbers(number, roundto = 2) # round to zero or two decimals
    if roundto.to_f > 0
      number = sprintf "%.#{roundto}f", number
    else
      number = number.round
    end
    # regex to add commas
    number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1,").reverse
  end 
    
  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)
    
    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    #assign the user inputs to variables
    meter_name = runner.getStringArgumentValue("meter_name", user_arguments)

    # check the meter_name for reasonableness
    if meter_name == ""
      runner.registerError("No meter name was entered.")
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get
    
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get
    
    if !sqlFile.connectionOpen
      runner.registerError("Cannot open last sql file.")
      return false
    end
    
    model.setSqlFile(sqlFile)

    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sqlFile.availableEnvPeriods.each do |env_pd|
      runner.registerInfo("Hi #{env_pd}.")
      env_type = sqlFile.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new("WeatherRunPeriod")
          ann_env_pd = env_pd
        end
      end
    end
    
    #reporting final condition
    runner.registerInitialCondition("Gathering data from EnergyPlus SQL file and OSM model.")
    
    # array to store values, to find out min and max
    value_array = []
    
    # get units timeseries is in
    units = []
    
    # variable used in the plotting file
    output_hourly_plr = []

    # only try to get the annual timeseries if an annual simulation was run
    if ann_env_pd

      # get desired variable
      key_value =  "" # when used should be in all caps. In this case I'm using a meter vs. an output variable, and it doesn't have a key
      time_step = "Hourly" # "Zone Timestep", "Hourly", "HVAC System Timestep"
      output_timeseries = sqlFile.timeSeries(ann_env_pd, time_step, meter_name, key_value) # key value would go at the end if we used it.
                                      
      # check to see if timeseries exists                                      
      if output_timeseries.empty? 
        # reporting measures should register as not applicable on failure so other reports can still run
        runner.registerAsNotApplicable("Did not find hourly variable named #{meter_name}.  Cannot produce the requested plot.")
        return true
      else
        units = output_timeseries.get.units
        
        # loop through timeseries and move the data from an OpenStudio timeseries to a normal Ruby array (vector)
        output_timeseries = output_timeseries.get.values
        for i in 0..(output_timeseries.size - 1)
          output_hourly_plr << {value: output_timeseries[i], hour: i%24, day:(i/24).round }
          value_array <<  output_timeseries[i]
        end #end of for i in 0..(output_timeseries.size - 1)

        # store min and max values
        min_value = value_array.min
        max_value = value_array.max

        #add in data to represent scale
        scale_step_key = (max_value-min_value)/24
        for i in 0..23
          for j in 0..6
            output_hourly_plr << {value: min_value + (i*scale_step_key), hour: i, day:372+j}
          end
        end
      end
      
    else
      # reporting measures should register as not applicable on failure so other reports can still run
      runner.registerAsNotApplicable("An annual simulation was not run.  Cannot get annual timeseries data")
      return true
    end

    output_hourly_plr = JSON.generate(output_hourly_plr)
    
    value_range = [{low: min_value, high: max_value}]
    value_range = JSON.generate(value_range)

    display_units = units
    if units == "J"
      si = true # change si to false to get ip units
      if si
        scale_min = OpenStudio::convert(min_value,"J","GJ").get
        scale_max = OpenStudio::convert(max_value,"J","GJ").get
        scale_step = (scale_max-scale_min)/7
        display_units = "GJ"
      else
        scale_min = OpenStudio::convert(min_value,"J","kWh").get
        scale_max = OpenStudio::convert(max_value,"J","kWh").get
        scale_step = (scale_max-scale_min)/7
        display_units = "kWh"
      end
    end
    
    color_scale_values = []
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*0)} (#{display_units})"}
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*1)} (#{display_units})"}
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*2)} (#{display_units})"}
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*3)} (#{display_units})"}
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*4)} (#{display_units})"}
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*5)} (#{display_units})"}
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*6)} (#{display_units})"}
    color_scale_values << {value: "#{neat_numbers(scale_min + scale_step*7)} (#{display_units})"}
    color_scale_values = JSON.generate(color_scale_values)
    
    if key_value == ""
      plot_title = "#{meter_name}"
    else
      plot_title = "#{meter_name}, #{key_value}"
    end

    runner.registerInfo("Minimum value in dataset is #{neat_numbers(OpenStudio::convert(min_value,units,display_units))} (#{display_units}).")
    runner.registerInfo("Maximum value in dataset is #{neat_numbers(OpenStudio::convert(max_value,units,display_units))} (#{display_units}).")

    web_asset_path = OpenStudio::getSharedResourcesPath() / OpenStudio::Path.new("web_assets")

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.in"
    if File.exist?(html_in_path)
        html_in_path = html_in_path
    else
        html_in_path = "#{File.dirname(__FILE__)}/report.html.in"
    end
    html_in = ""
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = "./report.html"
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other      
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    #closing the sql file
    sqlFile.close()

    #reporting final condition
    runner.registerFinalCondition("Generated #{html_out_path}.")
    
    return true
 
  end 

end 

#this allows the measure to be use by the application
MeterFloodPlot.new.registerWithApplication