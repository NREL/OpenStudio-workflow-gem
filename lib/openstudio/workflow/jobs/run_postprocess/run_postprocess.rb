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

# Run precanned post processing to extract object functions
# TODO: I hear that measures can step on each other if not run in their own directory

require 'csv'
require 'ostruct'

class RunPostprocess

  # Mixin the MeasureApplication module to apply measures
  include OpenStudio::Workflow::ApplyMeasures

  def initialize(directory, logger, adapter, options = {})
    defaults = {}
    @options = defaults.merge(options)
    @directory = directory
    @run_directory = "#{@directory}/run"
    @adapter = adapter
    @logger = logger
    @results = {}
    @output_attributes = {}

    # TODO: we shouldn't have to keep loading this file if we need it. It should be availabe for any job.
    # TODO: passing in the options everytime is ridiculuous
    @analysis_json = @adapter.get_problem(@directory, @options)

    @logger.info "#{self.class} passed the following options #{@options}"

    @model = load_model @options[:run_openstudio][:osm]

    # TODO: should read the name of the sql output file via the :run_openstudio options hash
    # I want to reiterate that this is cheezy!
    @sql_filename = "#{@run_directory}/eplusout.sql"
    fail "EnergyPlus SQL file did not exist #{@sql_filename}" unless File.exist? @sql_filename

    @objective_functions = {}
  end

  def perform
    @logger.info "Calling #{__method__} in the #{self.class} class"
    @logger.info "RunPostProcess Retrieving datapoint and problem"

    begin
      @datapoint_json = @adapter.get_datapoint(@directory, @options)
      @analysis_json = @adapter.get_problem(@directory, @options)

      if @options[:use_monthly_reports]
        run_monthly_postprocess
      else
        run_standard_postprocess
      end

      translate_csv_to_json

      run_packaged_measures

      if @analysis_json && @analysis_json[:analysis]
        apply_measures(:reporting_measure)
      end

      @logger.info "Saving reporting measures output attributes JSON"
      File.open("#{@run_directory}/reporting_measure_attributes.json", 'w') {
          |f| f << JSON.pretty_generate(@output_attributes)
      }

      run_extract_inputs_and_outputs

      @logger.info "Objective Function JSON is #{@objective_functions}"
      obj_fun_file = "#{@directory}/objectives.json"
      FileUtils.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
      File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(@objective_functions) }

      cleanup
    rescue Exception => e
      log_message = "Runner error #{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
      fail log_message
    end

    @results
  end

  def cleanup
    # move any of the reporting file to the 'reports' directory for serverside access
    eplus_search_path = nil
    FileUtils.mkdir_p "#{@directory}/reports"

    # try to find the energyplus result file
    eplus_html = "#{@run_directory}/eplustbl.htm"
    unless File.exist? eplus_html
      eplus_html = Dir["#{analysis_dir}/*EnergyPlus*/eplustbl.htm"].last || nil
    end

    if eplus_html
      if File.exist? eplus_html
        # do some encoding on the html if possible
        html = File.read(eplus_html)
        html = html.force_encoding('ISO-8859-1').encode('utf-8', replace: nil)
        File.open("#{@directory}/reports/eplustbl.html", 'w') { |f| f << html }
      end
    end

    # Also, find any "report.html" files
    Dir["#{@run_directory}/*/report.html"].each do |report|
      # get the parent directory of the file and snake case it
      # do i need to force encoding on this as well?
      measure_class_name = File.basename(File.dirname(report)).snake_case
      FileUtils.move report, "#{@directory}/reports/#{measure_class_name}.html"
    end

    # Remove empty directories in run folder
    Dir["#{@run_directory}/*"].select { |d| File.directory? d }.select { |d| (Dir.entries(d) - %w[ . .. ]).empty? }.each { |d| Dir.rmdir d }

    paths_to_rm = []
    # paths_to_rm << Pathname.glob("#{@run_directory}/*.osm")
    # paths_to_rm << Pathname.glob("#{@run_directory}/*.idf") # keep the idfs
    # paths_to_rm << Pathname.glob("*.audit")
    # paths_to_rm << Pathname.glob("*.bnd")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.ini")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.eso")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.mtr")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.so")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.epw")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.idd")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.mtd")
    paths_to_rm << Pathname.glob("#{@run_directory}/*.rdd")
    paths_to_rm << Pathname.glob("#{@run_directory}/ExpandObjects")
    paths_to_rm << Pathname.glob("#{@run_directory}/EnergyPlus")
    paths_to_rm << Pathname.glob("#{@run_directory}/packaged_measures")
    paths_to_rm.each { |p| FileUtils.rm_rf(p) }
  end

  def run_extract_inputs_and_outputs
    # For xml, the measure attributes are in the measure_attributes_xml.json file
    # TODO: somehow pass the metadata around on which JSONs to suck into the database
    if File.exist?("#{@run_directory}/measure_attributes_xml.json")
      temp_json = JSON.parse(File.read("#{@run_directory}/measure_attributes_xml.json"), symbolize_names: true)
      @results.merge!(temp_json)
    end

    # Inputs are in the measure_attributes.json file
    if File.exist?("#{@run_directory}/measure_attributes.json")
      temp_json = JSON.parse(File.read("#{@run_directory}/measure_attributes.json"), symbolize_names: true)
      @results.merge!(temp_json)
    end

    # Inputs are in the reporting_measure_attributes.jsonfile
    if File.exist?("#{@run_directory}/reporting_measure_attributes.json")
      temp_json = JSON.parse(File.read("#{@run_directory}/reporting_measure_attributes.json"), symbolize_names: true)
      @results.merge!(temp_json)
    end

    # Initialize the objective function variable
    @objective_functions = {}
    if File.exist?("#{@run_directory}/standard_report_legacy.json")
      @results[:standard_report_legacy] = JSON.parse(File.read("#{@run_directory}/standard_report_legacy.json"), symbolize_names: true)

      @logger.info "Iterating over Analysis JSON Output Variables"
      # Save the objective functions to the object for sending back to the simulation executive

      @analysis_json[:analysis][:output_variables].each do |variable|
        # determine which ones are the objective functions (code smell: todo: use enumerator)
        if variable[:objective_function]
          @logger.info "Looking for objective function #{variable[:name]}"
          # TODO: move this to cleaner logic. Use ostruct?
          if variable[:name].include? '.'
            k, v = variable[:name].split('.')
            if @results[k.to_sym][v.to_sym]
              @objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = @results[k.to_sym][v.to_sym]
              if variable[:objective_function_target]
                @logger.info "Found objective function target for #{variable[:name]}"
                @objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_target].to_f
              end
              if variable[:scaling_factor]
                @logger.info "Found scaling factor for #{variable[:name]}"
                @objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = variable[:scaling_factor].to_f
              end
              if variable[:objective_function_group]
                @logger.info "Found objective function group for #{variable[:name]}"
                @objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_group].to_f
              end
            else
              @logger.warn "No results for objective function #{variable[:name]}"
              @objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = Float::MAX
              @objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = nil
              @objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = nil
              @objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = nil
            end
          else
            # variable name is not nested -- this is for legacy purposes and should be deleted 9/30/2014
            if @results[variable[:name]]
              @objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = @results[k.to_sym][v.to_sym]
              if variable[:objective_function_target]
                @logger.info "Found objective function target for #{variable[:name]}"
                @objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_target].to_f
              end
              if variable[:scaling_factor]
                @logger.info "Found scaling factor for #{variable[:name]}"
                @objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = variable[:scaling_factor].to_f
              end
              if variable[:objective_function_group]
                @logger.info "Found objective function group for #{variable[:name]}"
                @objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_group].to_f
              end
            else
              @logger.warn "No results for objective function #{variable[:name]}"
              @objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = Float::MAX
              @objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = nil
              @objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = nil
              @objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = nil
            end
          end
        end
      end
    end
  end

  private

# Load in the OpenStudio model. It is required for postprocessing
  def load_model(filename)
    model = nil
    @logger.info 'Loading model'

    # TODO: wrap this in an exception block and fail as appropriate
    # assume that the seed model has been placed in the directory
    if File.exist? filename
      @logger.info "Reading in model #{filename}"
      translator = OpenStudio::OSVersion::VersionTranslator.new
      model = translator.loadModel(filename)
      fail 'OpenStudio model is empty or could not be loaded' if model.empty?
      model = model.get
    else
      fail "Model '#{filename}' did not exist"
    end

    model
  end

  # Run the prepackaged measures in the Gem.
  def run_packaged_measures
    # configure the workflow item json to pass
    workflow_item = {
        display_name: 'Standard Reports',
        measure_definition_directory: File.expand_path(File.join(File.dirname(__FILE__), 'packaged_measures', 'StandardReports', 'measure.rb')),
        measure_definition_class_name: "StandardReports",
        measure_type: 'ReportingMeasure',
        name: 'standard_reports'
    }
    @logger.info 'Running packaged reporting measures'

    apply_measure(workflow_item)

    @logger.info 'Finished Running Packaged Measures'
  end

  def translate_csv_to_json
    if File.exist?("#{@run_directory}/eplustbl.csv")
      @logger.info 'Translating EnergyPlus table CSV to JSON file'
      results = {}
      csv = CSV.read("#{@run_directory}/eplustbl.csv")
      csv.transpose.each do |k, v|
        longname = k.gsub(/\(.*\)/, '').strip
        short_name = longname.downcase.gsub(' ', '_')
        units = k.match(/\(.*\)/)[0].gsub('(', '').gsub(')', '')
        results[short_name.to_sym] = v.nil? ? nil : v.to_f
        results["#{short_name}_units".to_sym] = units
        results["#{short_name}_display_name".to_sym] = longname
      end

      @logger.info 'Saving results to json'

      # save out results
      File.open("#{@run_directory}/standard_report_legacy.json", 'w') { |f| f << JSON.pretty_generate(results) }
    end
  end

  # TODO: THis is uglier than the one below! sorry.
  def run_monthly_postprocess
    def sql_query(sql, report_name, query)
      val = nil
      result = sql.execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='#{report_name}' AND #{query}")
      if result.empty?
        @logger.warn "Query for run_monthly_postprocess failed for #{query}"
      else
        begin
          val = result.get
        rescue Exception => e
          @logger.info "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
          val = nil
        end
      end

      val
    end

    def add_element(hash, var_name, value, xpath = nil)
      values_hash = {}
      values_hash['name'] = var_name

      # store correct datatype
      store_val = nil
      if value.nil?
        store_val = nil
      elsif value == 'true'
        store_val = true
      elsif value == 'false'
        store_val = false
      else
        test = value.to_s
        value = test.match('\.').nil? ? Integer(test) : Float(test) rescue test.to_s
        if value.is_a?(Fixnum) || value.is_a?(Float)
          store_val = value.to_f
        else
          store_val = value.to_s
        end
      end
      values_hash['value'] = store_val
      values_hash['xpath'] = xpath unless xpath.nil?

      hash['data']['variables'] << values_hash
    end

    # add results from sql method
    def add_data(sql, query, hdr, area, val)
      row = []
      val = sql_query(sql, 'AnnualBuildingUtilityPerformanceSummary', query) if val.nil?
      row << hdr
      if area.nil?
        row << val
      else
        row << (val * 1000) / area
      end
      row
    end

    # add results from sql method
    def add_data2(sql, query, hdr, area, val)
      row = []
      val = sql_query(sql, 'BUILDING ENERGY PERFORMANCE - ELECTRICITY', query) if val.nil?
      row << hdr
      if area.nil?
        row << val
      else
        row << (val * 1000) / area
      end
      row
    end

    # add results from sql method
    def add_data3(sql, query, hdr, area, val)
      row = []
      val = sql_query(sql, 'BUILDING ENERGY PERFORMANCE - NATURAL GAS', query) if val.nil?
      row << hdr
      if area.nil?
        row << val
      else
        row << (val * 1000) / area
      end
      row
    end

    # add results from sql method
    def add_data4(sql, query, hdr, area, val)
      row = []

      if val.nil?
        val = 0

        ["INTERIORLIGHTS:ELECTRICITY", "EXTERIORLIGHTS:ELECTRICITY", "INTERIOREQUIPMENT:ELECTRICITY", "EXTERIOREQUIPMENT:ELECTRICITY",
         "FANS:ELECTRICITY", "PUMPS:ELECTRICITY", "HEATING:ELECTRICITY", "COOLING:ELECTRICITY", "HEATREJECTION:ELECTRICITY",
         "HUMIDIFIER:ELECTRICITY", "HEATRECOVERY:ELECTRICITY", "WATERSYSTEMS:ELECTRICITY", "COGENERATION:ELECTRICITY", "REFRIGERATION:ELECTRICITY"].each do |end_use|

          tmp_query = query + " AND ColumnName='#{end_use}'"
          tmp_val = sql_query(sql, 'BUILDING ENERGY PERFORMANCE - ELECTRICITY', tmp_query)
          val += tmp_val if not tmp_val.nil?
        end
      end

      row << hdr
      if area.nil?
        row << val
      else
        row << (val * 1000) / area
      end
      row
    end

    # open sql file
    sql_file = OpenStudio::SqlFile.new(@sql_filename)

    # get building area
    bldg_area = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Building Area' AND RowName='Net Conditioned Building Area' AND ColumnName='Area'")
    # populate data array

    tbl_data = []
    tbl_data << add_data(sql_file, "TableName='Site and Source Energy' AND RowName='Total Site Energy' AND ColumnName='Energy Per Conditioned Building Area'", 'Total Energy (MJ/m2)', nil, nil)
    tbl_data << add_data(sql_file, "TableName='Site and Source Energy' AND RowName='Total Source Energy' AND ColumnName='Energy Per Conditioned Building Area'", 'Total Source Energy (MJ/m2)', nil, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Electricity'", 'Total Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Natural Gas'", 'Total Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heating' AND ColumnName='Electricity'", 'Heating Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heating' AND ColumnName='Natural Gas'", 'Heating Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Cooling' AND ColumnName='Electricity'", 'Cooling Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Lighting' AND ColumnName='Electricity'", 'Interior Lighting Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Exterior Lighting' AND ColumnName='Electricity'", 'Exterior Lighting Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Electricity'", 'Interior Equipment Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Natural Gas'", 'Interior Equipment Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Exterior Equipment' AND ColumnName='Electricity'", 'Exterior Equipment Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Fans' AND ColumnName='Electricity'", 'Fans Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Pumps' AND ColumnName='Electricity'", 'Pumps Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heat Rejection' AND ColumnName='Electricity'", 'Heat Rejection Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Humidification' AND ColumnName='Electricity'", 'Humidification Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Electricity'", 'Water Systems Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Natural Gas'", 'Water Systems Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Refrigeration' AND ColumnName='Electricity'", 'Refrigeration Electricity (MJ/m2)', bldg_area, nil)
    htg_hrs = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Heating' AND ColumnName='Facility'")
    clg_hrs = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Cooling' AND ColumnName='Facility'")
    tot_hrs = clg_hrs && htg_hrs ? htg_hrs + clg_hrs : nil
    tbl_data << add_data(sql_file, nil, 'Heating Hours Unmet (hr)', nil, htg_hrs)
    tbl_data << add_data(sql_file, nil, 'Cooling Hours Unmet (hr)', nil, clg_hrs)
    tbl_data << add_data(sql_file, nil, 'Total Hours Unmet (hr)', nil, tot_hrs)
    total_cost = sql_query(sql_file, 'Life-Cycle Cost Report', "TableName='Present Value by Category' AND RowName='Grand Total' AND ColumnName='Present Value'")
    tbl_data << add_data(sql_file, nil, 'Total Life Cycle Cost ($)', nil, total_cost)
    # cooling:electricity
    tbl_data << add_data2(sql_file, "RowName='January' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Jan (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='February' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Feb (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='March' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Mar (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='April' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Apr (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='May' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity May (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='June' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Jun (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='July' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Jul (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='August' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Aug (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='September' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Sep (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='October' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Oct (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='November' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Nov (J)', nil, nil)
    tbl_data << add_data2(sql_file, "RowName='December' AND ColumnName='COOLING:ELECTRICITY'", 'Cooling Electricity Dec (J)', nil, nil)
    # heating:gas
    tbl_data << add_data3(sql_file, "RowName='January' AND ColumnName='HEATING:GAS'", 'Heating Gas Jan (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='February' AND ColumnName='HEATING:GAS'", 'Heating Gas Feb (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='March' AND ColumnName='HEATING:GAS'", 'Heating Gas Mar (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='April' AND ColumnName='HEATING:GAS'", 'Heating Gas Apr (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='May' AND ColumnName='HEATING:GAS'", 'Heating Gas May (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='June' AND ColumnName='HEATING:GAS'", 'Heating Gas Jun (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='July' AND ColumnName='HEATING:GAS'", 'Heating Gas Jul (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='August' AND ColumnName='HEATING:GAS'", 'Heating Gas Aug (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='September' AND ColumnName='HEATING:GAS'", 'Heating Gas Sep (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='October' AND ColumnName='HEATING:GAS'", 'Heating Gas Oct (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='November' AND ColumnName='HEATING:GAS'", 'Heating Gas Nov (J)', nil, nil)
    tbl_data << add_data3(sql_file, "RowName='December' AND ColumnName='HEATING:GAS'", 'Heating Gas Dec (J)', nil, nil)
    # total Electricity
    tbl_data << add_data4(sql_file, "RowName='January'", 'Total Electricity Jan (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='February'", 'Total Electricity Feb (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='March'", 'Total Electricity Mar (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='April'", 'Total Electricity Apr (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='May'", 'Total Electricity May (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='June'", 'Total Electricity Jun (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='July'", 'Total Electricity Jul (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='August'", 'Total Electricity Aug (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='September'", 'Total Electricity Sep (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='October'", 'Total Electricity Oct (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='November'", 'Total Electricity Nov (J)', nil, nil)
    tbl_data << add_data4(sql_file, "RowName='December'", 'Total Electricity Dec (J)', nil, nil) # close SQL file
    sql_file.close
    # transpose data
    tbl_rows = tbl_data.transpose

    @logger.info tbl_rows
    # write electricity data to CSV
    CSV.open("#{@run_directory}/eplustbl.csv", 'wb') do |csv|
      tbl_rows.each do |row|
        csv << row
      end
    end
  end


  # TODO: This is ugly.  Move this out of here entirely and into a reporting measure if we need it at all
  def run_standard_postprocess
    def sql_query(sql, report_name, query)
      val = nil
      result = sql.execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='#{report_name}' AND #{query}")
      if result.empty?
        @logger.warn "Query for run_standard_postprocess failed for #{query}"
      else
        begin
          val = result.get
        rescue Exception => e
          @logger.info "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
          val = nil
        end
      end

      val
    end

    def add_element(hash, var_name, value, xpath = nil)
      values_hash = {}
      values_hash['name'] = var_name

      # store correct datatype
      store_val = nil
      if value.nil?
        store_val = nil
      elsif value == 'true'
        store_val = true
      elsif value == 'false'
        store_val = false
      else
        test = value.to_s
        value = test.match('\.').nil? ? Integer(test) : Float(test) rescue test.to_s
        if value.is_a?(Fixnum) || value.is_a?(Float)
          store_val = value.to_f
        else
          store_val = value.to_s
        end
      end
      values_hash['value'] = store_val
      values_hash['xpath'] = xpath unless xpath.nil?

      hash['data']['variables'] << values_hash
    end

# add results from sql method
    def add_data(sql, query, hdr, area, val)
      row = []
      val = sql_query(sql, 'AnnualBuildingUtilityPerformanceSummary', query) if val.nil?
      row << hdr
      if area.nil?
        row << val
      else
        row << (val * 1000) / area
      end
      row
    end


    # open sql file
    sql_file = OpenStudio::SqlFile.new(@sql_filename)

    # get building area
    bldg_area = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Building Area' AND RowName='Net Conditioned Building Area' AND ColumnName='Area'")
    # populate data array

    tbl_data = []
    tbl_data << add_data(sql_file, "TableName='Site and Source Energy' AND RowName='Total Site Energy' AND ColumnName='Energy Per Conditioned Building Area'", 'Total Energy (MJ/m2)', nil, nil)
    tbl_data << add_data(sql_file, "TableName='Site and Source Energy' AND RowName='Total Source Energy' AND ColumnName='Energy Per Conditioned Building Area'", 'Total Source Energy (MJ/m2)', nil, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Electricity'", 'Total Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Total End Uses' AND ColumnName='Natural Gas'", 'Total Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heating' AND ColumnName='Electricity'", 'Heating Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heating' AND ColumnName='Natural Gas'", 'Heating Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Cooling' AND ColumnName='Electricity'", 'Cooling Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Lighting' AND ColumnName='Electricity'", 'Interior Lighting Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Exterior Lighting' AND ColumnName='Electricity'", 'Exterior Lighting Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Electricity'", 'Interior Equipment Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Interior Equipment' AND ColumnName='Natural Gas'", 'Interior Equipment Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Exterior Equipment' AND ColumnName='Electricity'", 'Exterior Equipment Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Fans' AND ColumnName='Electricity'", 'Fans Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Pumps' AND ColumnName='Electricity'", 'Pumps Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Heat Rejection' AND ColumnName='Electricity'", 'Heat Rejection Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Humidification' AND ColumnName='Electricity'", 'Humidification Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Electricity'", 'Water Systems Electricity (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Water Systems' AND ColumnName='Natural Gas'", 'Water Systems Natural Gas (MJ/m2)', bldg_area, nil)
    tbl_data << add_data(sql_file, "TableName='End Uses' AND RowName='Refrigeration' AND ColumnName='Electricity'", 'Refrigeration Electricity (MJ/m2)', bldg_area, nil)
    htg_hrs = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Heating' AND ColumnName='Facility'")
    clg_hrs = sql_query(sql_file, 'AnnualBuildingUtilityPerformanceSummary', "TableName='Comfort and Setpoint Not Met Summary' AND RowName='Time Setpoint Not Met During Occupied Cooling' AND ColumnName='Facility'")
    tot_hrs = clg_hrs && htg_hrs ? htg_hrs + clg_hrs : nil
    tbl_data << add_data(sql_file, nil, 'Heating Hours Unmet (hr)', nil, htg_hrs)
    tbl_data << add_data(sql_file, nil, 'Cooling Hours Unmet (hr)', nil, clg_hrs)
    tbl_data << add_data(sql_file, nil, 'Total Hours Unmet (hr)', nil, tot_hrs)
    total_cost = sql_query(sql_file, 'Life-Cycle Cost Report', "TableName='Present Value by Category' AND RowName='Grand Total' AND ColumnName='Present Value'")
    tbl_data << add_data(sql_file, nil, 'Total Life Cycle Cost ($)', nil, total_cost)
    # close SQL file
    sql_file.close
    # transpose data
    tbl_rows = tbl_data.transpose

    @logger.info tbl_rows
    # write electricity data to CSV
    CSV.open("#{@run_directory}/eplustbl.csv", 'wb') do |csv|
      tbl_rows.each do |row|
        csv << row
      end
    end

  end

end
