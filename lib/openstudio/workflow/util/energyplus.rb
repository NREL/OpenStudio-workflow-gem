# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
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
      # The methods needed to run simulations using EnergyPlus are stored here. See the run_simulation class for
      #   implementation details.
      module EnergyPlus
        require 'openstudio/workflow/util/io'
        include OpenStudio::Workflow::Util::IO
        require 'openstudio/workflow/util/model'
        include OpenStudio::Workflow::Util::Model
        ENERGYPLUS_REGEX = /^energyplus\D{0,4}$/i.freeze
        EXPAND_OBJECTS_REGEX = /^expandobjects\D{0,4}$/i.freeze

        # Find the installation directory of EnergyPlus linked to the OpenStudio version being used
        #
        # @return [String] Returns the path to EnergyPlus
        #
        def find_energyplus
          path = OpenStudio.getEnergyPlusDirectory.to_s
          raise 'Unable to find the EnergyPlus executable' unless File.exist? path

          path
        end

        # Does something
        #
        # @param [String] run_directory Directory to run the EnergyPlus simulation in
        # @param [Array] energyplus_files Array of files containing the EnergyPlus and ExpandObjects EXEs
        # @return [Void]
        #
        def clean_directory(run_directory, energyplus_files, logger)
          logger.info 'Removing any copied EnergyPlus files'
          energyplus_files.each do |file|
            if File.exist? file
              FileUtils.rm_f file
            end
          end

          paths_to_rm = []
          paths_to_rm << "#{run_directory}/packaged_measures"
          paths_to_rm << "#{run_directory}/Energy+.ini"
          paths_to_rm.each { |p| FileUtils.rm_rf(p) if File.exist?(p) }
        end

        # Prepare the directory to run EnergyPlus
        #
        # @param [String] run_directory Directory to copy the required EnergyPlus files to
        # @param [Object] logger Logger object
        # @param [String] energyplus_path Path to the EnergyPlus EXE
        # @return [Array, file, file] Returns an array of strings of EnergyPlus files copied to the run_directory, the
        # ExpandObjects EXE file, and EnergyPlus EXE file
        #
        def prepare_energyplus_dir(run_directory, logger, energyplus_path = nil)
          logger.info "Copying EnergyPlus files to run directory: #{run_directory}"
          energyplus_path ||= find_energyplus
          logger.info "EnergyPlus path is #{energyplus_path}"
          energyplus_files = []
          energyplus_exe, expand_objects_exe = nil
          Dir["#{energyplus_path}/*"].each do |file|
            next if File.directory? file

            # copy idd, ini and epJSON schema files
            if File.extname(file).downcase =~ /.idd|.ini|.epjson/
              dest_file = "#{run_directory}/#{File.basename(file)}"
              energyplus_files << dest_file
              FileUtils.copy file, dest_file
            end

            energyplus_exe = file if File.basename(file) =~ ENERGYPLUS_REGEX
            expand_objects_exe = file if File.basename(file) =~ EXPAND_OBJECTS_REGEX
          end

          raise "Could not find EnergyPlus executable in #{energyplus_path}" unless energyplus_exe
          raise "Could not find ExpandObjects executable in #{energyplus_path}" unless expand_objects_exe

          logger.info "EnergyPlus executable path is #{energyplus_exe}"
          logger.info "ExpandObjects executable path is #{expand_objects_exe}"

          return energyplus_files, energyplus_exe, expand_objects_exe
        end

        # Configures and executes the EnergyPlus simulation and checks to see if the simulation was successful
        #
        # @param [String] run_directory Directory to execute the EnergyPlus simulation in. It is assumed that this
        #   directory already has the IDF and weather file in it
        # @param [String] energyplus_path (nil) Optional path to override the default path associated with the
        #   OpenStudio package being used
        # @param [Object] output_adapter (nil) Optional output adapter to update
        # @param [Object] logger (nil) Optional logger, will log to STDOUT if none provided
        # @return [Void]
        #
        def call_energyplus(run_directory, energyplus_path = nil, output_adapter = nil, logger = nil, workflow_json = nil)
          logger ||= ::Logger.new($stdout) unless logger

          current_dir = Dir.pwd
          energyplus_path ||= find_energyplus
          logger.info "EnergyPlus path is #{energyplus_path}"

          energyplus_files, energyplus_exe, expand_objects_exe = prepare_energyplus_dir(run_directory, logger, energyplus_path)

          Dir.chdir(run_directory)
          logger.info "Starting simulation in run directory: #{Dir.pwd}"

          if !@options[:skip_expand_objects]
            command = popen_command("\"#{expand_objects_exe}\"")
            logger.info "Running command '#{command}'"
            File.open('stdout-expandobject', 'w') do |file|
              ::IO.popen(command) do |io|
                while (line = io.gets)
                  file << line
                end
              end
            end

            # Check if expand objects did anything
            if File.exist? 'expanded.idf'
              FileUtils.mv('in.idf', 'pre-expand.idf', force: true) if File.exist?('in.idf')
              FileUtils.mv('expanded.idf', 'in.idf', force: true)
            end
          end

          # Translate the IDF to an epJSON if @options[:epjson] is true
          # Ideally, this would be done sooner in the workflow process but many processes
          # manipulate the model_idf, some which are ep_measures that may not work with json
          # and ExpandObjects does not currently support epjson anyway to that still needs to run
          # before this can be changed.
          if @options[:epjson]
            @logger.info 'Beginning the translation to epJSON'
            @registry[:time_logger]&.start('Translating to EnergyPlus epJSON')
            idf_final = load_idf("#{run_directory}/in.idf", @logger)
            model_epjson = translate_idf_to_epjson idf_final, @logger
            @registry[:time_logger]&.stop('Translating to EnergyPlus')
            @logger.info 'Successfully translated to epJSON'
            @registry[:time_logger]&.start('Saving epJSON')
            epjson_name = save_epjson(model_epjson, run_directory)
            @registry[:time_logger]&.stop('Saving epJSON')
            @logger.debug "Saved epJSON as #{epjson_name}"
          end

          # Run using epJSON if @options[:epjson] true, otherwise use IDF
          if @options[:epjson]
            command = popen_command("\"#{energyplus_exe}\" in.epJSON 2>&1")
            logger.info "Running command '#{command}'"
            File.open('stdout-energyplus', 'w') do |file|
              ::IO.popen(command) do |io|
                while (line = io.gets)
                  file << line
                  output_adapter&.communicate_energyplus_stdout(line)
                end
              end
            end
            r = $?
          else
            command = popen_command("\"#{energyplus_exe}\" 2>&1")
            logger.info "Running command '#{command}'"
            File.open('stdout-energyplus', 'w') do |file|
              ::IO.popen(command) do |io|
                while (line = io.gets)
                  file << line
                  output_adapter&.communicate_energyplus_stdout(line)
                end
              end
            end
            r = $?
          end

          logger.info "EnergyPlus returned '#{r}'"
          unless r.to_i.zero?
            logger.warn 'EnergyPlus returned a non-zero exit code. Check the stdout-energyplus log.'
          end

          if File.exist? 'eplusout.err'
            eplus_err = File.read('eplusout.err').force_encoding('ISO-8859-1').encode('utf-8', replace: nil)

            if workflow_json
              begin
                if !@options[:fast]
                  workflow_json.setEplusoutErr(eplus_err)
                end
              rescue StandardError => e
                # older versions of OpenStudio did not have the setEplusoutErr method
              end
            end

            if eplus_err =~ /EnergyPlus Terminated--Fatal Error Detected/
              raise 'EnergyPlus Terminated with a Fatal Error. Check eplusout.err log.'
            end
          end

          if File.exist? 'eplusout.end'
            f = File.read('eplusout.end').force_encoding('ISO-8859-1').encode('utf-8', replace: nil)
            warnings_count = f[/(\d*).Warning/, 1]
            error_count = f[/(\d*).Severe.Errors/, 1]
            logger.info "EnergyPlus finished with #{warnings_count} warnings and #{error_count} severe errors"
            if f =~ /EnergyPlus Terminated--Fatal Error Detected/
              raise 'EnergyPlus Terminated with a Fatal Error. Check eplusout.err log.'
            end
          else
            raise 'EnergyPlus failed and did not create an eplusout.end file. Check the stdout-energyplus log.'
          end
        rescue StandardError => e
          log_message = "#{__FILE__} failed with #{e.message}, #{e.backtrace.join("\n")}"
          logger.error log_message
          raise log_message
        ensure
          logger.info "Ensuring 'clean' directory"
          clean_directory(run_directory, energyplus_files, logger)

          Dir.chdir(current_dir)
          logger.info 'EnergyPlus Completed'
        end

        # Run this code before running EnergyPlus to make sure the reporting variables are setup correctly
        #
        # @param [Object] idf The IDF Workspace to be simulated
        # @return [Void]
        #
        def energyplus_preprocess(idf, logger)
          logger.info 'Running EnergyPlus Preprocess'

          new_objects = []

          needs_sqlobj = idf.getObjectsByType('Output:SQLite'.to_IddObjectType).empty?

          if needs_sqlobj
            # just add this, we don't allow this type in add_energyplus_output_request
            logger.info 'Adding SQL Output to IDF'
            object = OpenStudio::IdfObject.load('Output:SQLite,SimpleAndTabular;').get
            idf.addObject(object)
          end

          # merge in monthly reports
          EnergyPlus.monthly_report_idf_text.split(/^\s*$/).each do |object|
            object = object.strip
            next if object.empty?

            new_objects << object
          end

          # These are needed for the calibration report
          new_objects << 'Output:Meter:MeterFileOnly,NaturalGas:Facility,Daily;'
          new_objects << 'Output:Meter:MeterFileOnly,Electricity:Facility,Timestep;'
          new_objects << 'Output:Meter:MeterFileOnly,Electricity:Facility,Daily;'

          # Always add in the timestep facility meters
          new_objects << 'Output:Meter,Electricity:Facility,Timestep;'
          new_objects << 'Output:Meter,NaturalGas:Facility,Timestep;'
          new_objects << 'Output:Meter,DistrictCooling:Facility,Timestep;'
          new_objects << 'Output:Meter,DistrictHeating:Facility,Timestep;'

          new_objects.each do |obj|
            object = OpenStudio::IdfObject.load(obj).get
            OpenStudio::Workflow::Util::EnergyPlus.add_energyplus_output_request(idf, object)
          end

          logger.info 'Finished EnergyPlus Preprocess'
        end

        # examines object and determines whether or not to add it to the workspace
        def self.add_energyplus_output_request(workspace, idf_object)
          num_added = 0
          idd_object = idf_object.iddObject

          allowed_objects = []
          allowed_objects << 'Output:Surfaces:List'
          allowed_objects << 'Output:Surfaces:Drawing'
          allowed_objects << 'Output:Schedules'
          allowed_objects << 'Output:Constructions'
          allowed_objects << 'Output:Table:TimeBins'
          allowed_objects << 'Output:Table:Monthly'
          allowed_objects << 'Output:Variable'
          allowed_objects << 'Output:Meter'
          allowed_objects << 'Output:Meter:MeterFileOnly'
          allowed_objects << 'Output:Meter:Cumulative'
          allowed_objects << 'Output:Meter:Cumulative:MeterFileOnly'
          allowed_objects << 'Meter:Custom'
          allowed_objects << 'Meter:CustomDecrement'
          allowed_objects << 'EnergyManagementSystem:OutputVariable'

          if allowed_objects.include?(idd_object.name) && !check_for_object(workspace, idf_object, idd_object.type)
            workspace.addObject(idf_object)
            num_added += 1
          end

          allowed_unique_objects = []
          # allowed_unique_objects << "Output:EnergyManagementSystem" # TODO: have to merge
          # allowed_unique_objects << "OutputControl:SurfaceColorScheme" # TODO: have to merge
          allowed_unique_objects << 'Output:Table:SummaryReports' # TODO: have to merge
          # OutputControl:Table:Style # not allowed
          # OutputControl:ReportingTolerances # not allowed
          # Output:SQLite # not allowed

          if allowed_unique_objects.include?(idf_object.iddObject.name) && (idf_object.iddObject.name == 'Output:Table:SummaryReports')
            summary_reports = workspace.getObjectsByType(idf_object.iddObject.type)
            if summary_reports.empty?
              workspace.addObject(idf_object)
              num_added += 1
            else
              merge_output_table_summary_reports(summary_reports[0], idf_object)
            end
          end

          return num_added
        end

        # check to see if we have an exact match for this object already
        def self.check_for_object(workspace, idf_object, idd_object_type)
          workspace.getObjectsByType(idd_object_type).each do |object|
            # all of these objects fields are data fields
            if idf_object.dataFieldsEqual(object)
              return true
            end
          end
          return false
        end

        # merge all summary reports that are not in the current workspace
        def self.merge_output_table_summary_reports(current_object, new_object)
          current_fields = []
          current_object.extensibleGroups.each do |current_extensible_group|
            current_fields << current_extensible_group.getString(0).to_s
          end

          fields_to_add = []
          new_object.extensibleGroups.each do |new_extensible_group|
            field = new_extensible_group.getString(0).to_s
            unless current_fields.include?(field)
              current_fields << field
              fields_to_add << field
            end
          end

          unless fields_to_add.empty?
            fields_to_add.each do |field|
              values = OpenStudio::StringVector.new
              values << field
              current_object.pushExtensibleGroup(values)
            end
            return true
          end

          return false
        end

        def self.monthly_report_idf_text
          <<~HEREDOC
            Output:Table:Monthly,
              Building Energy Performance - Electricity,  !- Name
                2,                       !- Digits After Decimal
                InteriorLights:Electricity,  !- Variable or Meter 1 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 1
                ExteriorLights:Electricity,  !- Variable or Meter 2 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 2
                InteriorEquipment:Electricity,  !- Variable or Meter 3 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 3
                ExteriorEquipment:Electricity,  !- Variable or Meter 4 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 4
                Fans:Electricity,        !- Variable or Meter 5 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 5
                Pumps:Electricity,       !- Variable or Meter 6 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 6
                Heating:Electricity,     !- Variable or Meter 7 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 7
                Cooling:Electricity,     !- Variable or Meter 8 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 8
                HeatRejection:Electricity,  !- Variable or Meter 9 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 9
                Humidifier:Electricity,  !- Variable or Meter 10 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 10
                HeatRecovery:Electricity,!- Variable or Meter 11 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 11
                WaterSystems:Electricity,!- Variable or Meter 12 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 12
                Cogeneration:Electricity,!- Variable or Meter 13 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 13
                Refrigeration:Electricity,!- Variable or Meter 14 Name
                SumOrAverage;            !- Aggregation Type for Variable or Meter 14

            Output:Table:Monthly,
              Building Energy Performance - Natural Gas,  !- Name
                2,                       !- Digits After Decimal
                InteriorEquipment:NaturalGas,   !- Variable or Meter 1 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 1
                ExteriorEquipment:NaturalGas,   !- Variable or Meter 2 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 2
                Heating:NaturalGas,             !- Variable or Meter 3 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 3
                Cooling:NaturalGas,             !- Variable or Meter 4 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 4
                WaterSystems:NaturalGas,        !- Variable or Meter 5 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 5
                Cogeneration:NaturalGas,        !- Variable or Meter 6 Name
                SumOrAverage;            !- Aggregation Type for Variable or Meter 6

            Output:Table:Monthly,
              Building Energy Performance - District Heating,  !- Name
                2,                       !- Digits After Decimal
                InteriorLights:DistrictHeating,  !- Variable or Meter 1 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 1
                ExteriorLights:DistrictHeating,  !- Variable or Meter 2 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 2
                InteriorEquipment:DistrictHeating,  !- Variable or Meter 3 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 3
                ExteriorEquipment:DistrictHeating,  !- Variable or Meter 4 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 4
                Fans:DistrictHeating,        !- Variable or Meter 5 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 5
                Pumps:DistrictHeating,       !- Variable or Meter 6 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 6
                Heating:DistrictHeating,     !- Variable or Meter 7 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 7
                Cooling:DistrictHeating,     !- Variable or Meter 8 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 8
                HeatRejection:DistrictHeating,  !- Variable or Meter 9 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 9
                Humidifier:DistrictHeating,  !- Variable or Meter 10 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 10
                HeatRecovery:DistrictHeating,!- Variable or Meter 11 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 11
                WaterSystems:DistrictHeating,!- Variable or Meter 12 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 12
                Cogeneration:DistrictHeating,!- Variable or Meter 13 Name
                SumOrAverage;            !- Aggregation Type for Variable or Meter 13

            Output:Table:Monthly,
              Building Energy Performance - District Cooling,  !- Name
                2,                       !- Digits After Decimal
                InteriorLights:DistrictCooling,  !- Variable or Meter 1 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 1
                ExteriorLights:DistrictCooling,  !- Variable or Meter 2 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 2
                InteriorEquipment:DistrictCooling,  !- Variable or Meter 3 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 3
                ExteriorEquipment:DistrictCooling,  !- Variable or Meter 4 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 4
                Fans:DistrictCooling,        !- Variable or Meter 5 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 5
                Pumps:DistrictCooling,       !- Variable or Meter 6 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 6
                Heating:DistrictCooling,     !- Variable or Meter 7 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 7
                Cooling:DistrictCooling,     !- Variable or Meter 8 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 8
                HeatRejection:DistrictCooling,  !- Variable or Meter 9 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 9
                Humidifier:DistrictCooling,  !- Variable or Meter 10 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 10
                HeatRecovery:DistrictCooling,!- Variable or Meter 11 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 11
                WaterSystems:DistrictCooling,!- Variable or Meter 12 Name
                SumOrAverage,            !- Aggregation Type for Variable or Meter 12
                Cogeneration:DistrictCooling,!- Variable or Meter 13 Name
                SumOrAverage;            !- Aggregation Type for Variable or Meter 13

            Output:Table:Monthly,
              Building Energy Performance - Electricity Peak Demand,  !- Name
                2,                       !- Digits After Decimal
                Electricity:Facility,  !- Variable or Meter 1 Name
                Maximum,            !- Aggregation Type for Variable or Meter 1
                InteriorLights:Electricity,  !- Variable or Meter 1 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 1
                ExteriorLights:Electricity,  !- Variable or Meter 2 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 2
                InteriorEquipment:Electricity,  !- Variable or Meter 3 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 3
                ExteriorEquipment:Electricity,  !- Variable or Meter 4 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 4
                Fans:Electricity,        !- Variable or Meter 5 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 5
                Pumps:Electricity,       !- Variable or Meter 6 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 6
                Heating:Electricity,     !- Variable or Meter 7 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 7
                Cooling:Electricity,     !- Variable or Meter 8 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 8
                HeatRejection:Electricity,  !- Variable or Meter 9 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 9
                Humidifier:Electricity,  !- Variable or Meter 10 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 10
                HeatRecovery:Electricity,!- Variable or Meter 11 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 11
                WaterSystems:Electricity,!- Variable or Meter 12 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 12
                Cogeneration:Electricity,!- Variable or Meter 13 Name
                ValueWhenMaximumOrMinimum;            !- Aggregation Type for Variable or Meter 13

            Output:Table:Monthly,
              Building Energy Performance - Natural Gas Peak Demand,  !- Name
                2,                       !- Digits After Decimal
                NaturalGas:Facility,  !- Variable or Meter 1 Name
                Maximum,            !- Aggregation Type for Variable or Meter 1
                InteriorEquipment:NaturalGas,   !- Variable or Meter 1 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 1
                ExteriorEquipment:NaturalGas,   !- Variable or Meter 2 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 2
                Heating:NaturalGas,             !- Variable or Meter 3 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 3
                Cooling:NaturalGas,             !- Variable or Meter 4 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 4
                WaterSystems:NaturalGas,        !- Variable or Meter 5 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 5
                Cogeneration:NaturalGas,        !- Variable or Meter 6 Name
                ValueWhenMaximumOrMinimum;            !- Aggregation Type for Variable or Meter 6

            Output:Table:Monthly,
              Building Energy Performance - District Heating Peak Demand,  !- Name
                2,                       !- Digits After Decimal
                DistrictHeating:Facility,  !- Variable or Meter 1 Name
                Maximum,            !- Aggregation Type for Variable or Meter 1
                InteriorLights:DistrictHeating,  !- Variable or Meter 1 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 1
                ExteriorLights:DistrictHeating,  !- Variable or Meter 2 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 2
                InteriorEquipment:DistrictHeating,  !- Variable or Meter 3 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 3
                ExteriorEquipment:DistrictHeating,  !- Variable or Meter 4 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 4
                Fans:DistrictHeating,        !- Variable or Meter 5 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 5
                Pumps:DistrictHeating,       !- Variable or Meter 6 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 6
                Heating:DistrictHeating,     !- Variable or Meter 7 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 7
                Cooling:DistrictHeating,     !- Variable or Meter 8 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 8
                HeatRejection:DistrictHeating,  !- Variable or Meter 9 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 9
                Humidifier:DistrictHeating,  !- Variable or Meter 10 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 10
                HeatRecovery:DistrictHeating,!- Variable or Meter 11 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 11
                WaterSystems:DistrictHeating,!- Variable or Meter 12 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 12
                Cogeneration:DistrictHeating,!- Variable or Meter 13 Name
                ValueWhenMaximumOrMinimum;            !- Aggregation Type for Variable or Meter 13

            Output:Table:Monthly,
              Building Energy Performance - District Cooling Peak Demand,  !- Name
                2,                       !- Digits After Decimal
                DistrictCooling:Facility,  !- Variable or Meter 1 Name
                Maximum,            !- Aggregation Type for Variable or Meter 1
                InteriorLights:DistrictCooling,  !- Variable or Meter 1 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 1
                ExteriorLights:DistrictCooling,  !- Variable or Meter 2 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 2
                InteriorEquipment:DistrictCooling,  !- Variable or Meter 3 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 3
                ExteriorEquipment:DistrictCooling,  !- Variable or Meter 4 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 4
                Fans:DistrictCooling,        !- Variable or Meter 5 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 5
                Pumps:DistrictCooling,       !- Variable or Meter 6 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 6
                Heating:DistrictCooling,     !- Variable or Meter 7 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 7
                Cooling:DistrictCooling,     !- Variable or Meter 8 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 8
                HeatRejection:DistrictCooling,  !- Variable or Meter 9 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 9
                Humidifier:DistrictCooling,  !- Variable or Meter 10 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 10
                HeatRecovery:DistrictCooling,!- Variable or Meter 11 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 11
                WaterSystems:DistrictCooling,!- Variable or Meter 12 Name
                ValueWhenMaximumOrMinimum,            !- Aggregation Type for Variable or Meter 12
                Cogeneration:DistrictCooling,!- Variable or Meter 13 Name
                ValueWhenMaximumOrMinimum;            !- Aggregation Type for Variable or Meter 13
          HEREDOC
        end
      end
    end
  end
end
