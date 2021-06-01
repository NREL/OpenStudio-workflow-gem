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
      require 'openstudio/workflow/util/measure'
      require 'csv'

      # This module serves as a wrapper around various post-processing tasks used to manage outputs
      # @todo (rhorsey) ummmm. So some of this is pretty ugly. Since @dmacumber had ideas about this maybe he can figure
      #   out what to do about it all
      # @todo (nlong) the output adapter restructure will frack up the extraction method royally
      #
      module PostProcess
        # This method loads a sql file into OpenStudio and returns it
        #
        # @param [String] sql_file Absolute path to the sql file to be loaded
        # @return [Object, nil] The OpenStudio::SqlFile object, or nil if it could not be found
        #
        def load_sql_file(sql_file)
          return nil unless File.exist? sql_file

          OpenStudio::SqlFile.new(@sql_filename)
        end

        # This method parses all sorts of stuff which something needs
        #
        # @param [String] run_dir The directory that the simulation was run in
        # @return [Hash, Hash] results and objective_function (which may be empty) are returned
        # @todo (rhorsey) fix the description
        #
        def run_extract_inputs_and_outputs(run_dir, logger)
          # For xml, the measure attributes are in the measure_attributes_xml.json file
          # TODO: somehow pass the metadata around on which JSONs to suck into the database
          results = {}
          # Inputs are in the measure_attributes.json file
          if File.exist? "#{run_dir}/measure_attributes.json"
            h = JSON.parse(File.read("#{run_dir}/measure_attributes.json"), symbolize_names: true)
            h = rename_hash_keys(h, logger)
            results.merge! h
          end

          logger.info 'Saving the result hash to file'
          File.open("#{run_dir}/results.json", 'w') do |f|
            f << JSON.pretty_generate(results)
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue StandardError
              f.flush
            end
          end

          objective_functions = {}
          if @registry[:analysis]
            logger.info 'Iterating over Analysis JSON Output Variables'
            # Save the objective functions to the object for sending back to the simulation executive
            analysis_json = @registry[:analysis]
            if analysis_json[:analysis] && analysis_json[:analysis][:output_variables]
              analysis_json[:analysis][:output_variables].each do |variable|
                # determine which ones are the objective functions (code smell: todo: use enumerator)
                if variable[:objective_function]
                  logger.info "Looking for objective function #{variable[:name]}"
                  # TODO: move this to cleaner logic. Use ostruct?
                  k, v = variable[:name].split('.')

                  # look for the objective function key and make sure that it is not nil. False is an okay obj function.
                  if results.key?(k.to_sym) && !results[k.to_sym][v.to_sym].nil?
                    objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = results[k.to_sym][v.to_sym]
                    if variable[:objective_function_target]
                      logger.info "Found objective function target for #{variable[:name]}"
                      objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_target].to_f
                    end
                    if variable[:scaling_factor]
                      logger.info "Found scaling factor for #{variable[:name]}"
                      objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = variable[:scaling_factor].to_f
                    end
                    if variable[:objective_function_group]
                      logger.info "Found objective function group for #{variable[:name]}"
                      objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = variable[:objective_function_group].to_f
                    end
                  else
                    logger.warn "No results for objective function #{variable[:name]}"
                    objective_functions["objective_function_#{variable[:objective_function_index] + 1}"] = Float::MAX
                    objective_functions["objective_function_target_#{variable[:objective_function_index] + 1}"] = nil
                    objective_functions["scaling_factor_#{variable[:objective_function_index] + 1}"] = nil
                    objective_functions["objective_function_group_#{variable[:objective_function_index] + 1}"] = nil
                  end
                end
              end
            end
          end

          return results, objective_functions
        end

        # Remove any invalid characters in the measure attribute keys. Periods and Pipes are the most problematic
        #   because mongo does not allow hash keys with periods, and the pipes are used in the map/reduce method that
        #   was written to speed up the data write in openstudio-server. Also remove any trailing underscores and spaces
        #
        # @param [Hash] hash Any hash with potentially problematic characters
        # @param [Logger] logger Logger to write to
        #
        def rename_hash_keys(hash, logger)
          # @todo should we log the name changes?
          regex = %r{[|!@#$%^&*()\{\}\\\[\];:'",<.>/?+=]+}

          rename_keys = lambda do |h|
            if h.is_a?(Hash)
              h.each_key do |key|
                if key.to_s =~ regex
                  logger.warn "Renaming result key '#{key}' to remove invalid characters"
                end
              end
              Hash[h.map { |k, v| [k.to_s.gsub(regex, '_').squeeze('_').gsub(/[_\s]+$/, '').chomp.to_sym, rename_keys[v]] }]
            else
              h
            end
          end

          rename_keys[hash]
        end

        # Save reports to a common directory
        #
        # @param [String] run_dir
        # @param [String] directory
        # @param [String] logger
        #
        def gather_reports(run_dir, directory, workflow_json, logger)
          logger.info run_dir
          logger.info directory

          FileUtils.mkdir_p "#{directory}/reports"

          # try to find the energyplus result file
          eplus_html = "#{run_dir}/eplustbl.htm"
          if File.exist? eplus_html
            # do some encoding on the html if possible
            html = File.read(eplus_html)
            html = html.force_encoding('ISO-8859-1').encode('utf-8', replace: nil)
            logger.info "Saving EnergyPlus HTML report to #{directory}/reports/eplustbl.html"
            File.open("#{directory}/reports/eplustbl.html", 'w') do |f|
              f << html
              # make sure data is written to the disk one way or the other
              begin
                f.fsync
              rescue StandardError
                f.flush
              end
            end
          end

          # Also, find any "report*.*" files
          Dir["#{run_dir}/*/report*.*"].each do |report|
            # HRH: This is a temporary work-around to support PAT 2.1 pretty names AND the CLI while we roll a WorkflowJSON solution
            measure_dir_name = File.dirname(report).split(File::SEPARATOR).last.gsub(/[0-9][0-9][0-9]_/, '')
            measure_xml_path = File.absolute_path(File.join(File.dirname(report), '../../..', 'measures',
                                                            measure_dir_name, 'measure.xml'))
            logger.info "measure_xml_path: #{measure_xml_path}"
            if File.exist? measure_xml_path
              # REXML is slow, so we lazy load only as needed
              require 'rexml/document'
              measure_xml = REXML::Document.new File.read(measure_xml_path)
              measure_class_name = OpenStudio.toUnderscoreCase(measure_xml.root.elements['class_name'].text)
            else
              measure_class_name = OpenStudio.toUnderscoreCase(measure_dir_name)
            end
            file_ext = File.extname(report)
            append_str = File.basename(report, '.*')
            new_file_name = "#{directory}/reports/#{measure_class_name}_#{append_str}#{file_ext}"
            logger.info "Saving report #{report} to #{new_file_name}"
            FileUtils.copy report, new_file_name
          end

          # Remove empty directories in run folder
          Dir["#{run_dir}/*"].select { |d| File.directory? d }.select { |d| (Dir.entries(d) - ['.', '..']).empty? }.each do |d|
            logger.info "Removing empty directory #{d}"
            Dir.rmdir d
          end
        end

        # A general post-processing step which could be made significantly more modular
        #
        # @param [String] run_dir
        #
        def cleanup(run_dir, directory, logger)
          paths_to_rm = []
          # paths_to_rm << Pathname.glob("#{run_dir}/*.osm")
          # paths_to_rm << Pathname.glob("#{run_dir}/*.idf") # keep the idfs
          # paths_to_rm << Pathname.glob("*.audit")
          # paths_to_rm << Pathname.glob("*.bnd")
          # paths_to_rm << Pathname.glob("#{run_dir}/*.eso")
          paths_to_rm << Pathname.glob("#{run_dir}/*.mtr")
          paths_to_rm << Pathname.glob("#{run_dir}/*.epw")
          # paths_to_rm << Pathname.glob("#{run_dir}/*.mtd")
          # paths_to_rm << Pathname.glob("#{run_dir}/*.rdd")
          paths_to_rm.each { |p| FileUtils.rm_rf(p) }
        end
      end
    end
  end
end
