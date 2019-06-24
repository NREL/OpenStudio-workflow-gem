# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
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

require 'openstudio/workflow_json'

# Local file based workflow
module OpenStudio
  module Workflow
    module InputAdapter
      class Local
        def initialize(osw_path = './workflow.osw')
          @osw_abs_path = File.absolute_path(osw_path, Dir.pwd)

          @workflow = nil
          if File.exist? @osw_abs_path
            @workflow = ::JSON.parse(File.read(@osw_abs_path), symbolize_names: true)
          end
          
          begin
            # configure the OSW with paths for loaded extension gems
            @workflow = OpenStudio::Workflow::Extension.configure_osw(@workflow)
          rescue NameError => e
          end
          
          @workflow_json = nil
          @run_options = nil
          if @workflow
            begin
              # Create a temporary WorkflowJSON, will not be same one used in registry during simulation
              @workflow_json = OpenStudio::WorkflowJSON.new(JSON.fast_generate(workflow))
              @workflow_json.setOswDir(osw_dir)
            rescue NameError => e
              @workflow_json = WorkflowJSON_Shim.new(workflow, osw_dir)
            end
            
            begin 
              @run_options = @workflow_json.runOptions
            rescue
            end
          end
        end

        # Get the OSW file from the local filesystem
        #
        def workflow
          raise "Could not read workflow from #{@osw_abs_path}" if @workflow.nil?
          @workflow
        end

        # Get the OSW path
        #
        def osw_path
          @osw_abs_path
        end

        # Get the OSW dir
        #
        def osw_dir
          File.dirname(@osw_abs_path)
        end

        # Get the run dir
        #
        def run_dir
          result = File.join(osw_dir, 'run')
          if @workflow_json
            begin
              result = @workflow_json.absoluteRunDir.to_s
            rescue
            end
          end
          result
        end
        
        def output_adapter(user_options, default, logger)
          
          # user option trumps all others
          return user_options[:output_adapter] if user_options[:output_adapter]
          
          # try to read from OSW
          if @run_options && !@run_options.empty?
            custom_adapter = @run_options.get.customOutputAdapter
            if !custom_adapter.empty?
              begin
                custom_file_name = custom_adapter.get.customFileName
                class_name = custom_adapter.get.className
                options = ::JSON.parse(custom_adapter.get.options, :symbolize_names => true)
                
                # merge with user options, user options will replace options loaded from OSW
                options.merge!(user_options)
                  
                # stick output_directory in options
                options[:output_directory] = run_dir
                
                p = @workflow_json.findFile(custom_file_name)
                if !p.empty?
                  load(p.get.to_s)
                  output_adapter = eval("#{class_name}.new(options)")
                  return output_adapter
                else
                  log_message = "Failed to load custom adapter file '#{custom_file_name}'"
                  logger.error log_message
                  raise log_message
                end
              rescue
                log_message = "Failed to load custom adapter '#{class_name}' from file '#{custom_file_name}'"
                logger.error log_message
                raise log_message
              end
            end
          end
        
          return default
        end
        
        def jobs(user_options, default, logger)
          
          # user option trumps all others
          return user_options[:jobs] if user_options[:jobs]

          # try to read from OSW
          begin
            #log_message = "Reading custom job states from OSW is not currently supported'"
            #logger.info log_message
          rescue
          end
        
          return default
        end
        
        def debug(user_options, default)
          
          # user option trumps all others
          return user_options[:debug] if user_options[:debug]
          
          # try to read from OSW
          if @run_options && !@run_options.empty?
            return @run_options.get.debug
          end
        
          return default
        end
        
        def fast(user_options, default)
        
          # user option trumps all others
          return user_options[:fast] if user_options[:fast]
          
          # try to read from OSW
          if @run_options && !@run_options.empty?
            if @run_options.get.respond_to?(:fast)
              return @run_options.get.fast
            else
              if @workflow[:run_options]
                return @workflow[:run_options][:fast]
              end
            end
          end
          
          return default
        end
        
        def preserve_run_dir(user_options, default)
          
          # user option trumps all others
          return user_options[:preserve_run_dir] if user_options[:preserve_run_dir]
          
          # try to read from OSW
          if @run_options && !@run_options.empty?
            return @run_options.get.preserveRunDir
          end
        
          return default
        end
        
        def skip_expand_objects(user_options, default)
          
          # user option trumps all others
          return user_options[:skip_expand_objects] if user_options[:skip_expand_objects]
           
          # try to read from OSW
          if @run_options && !@run_options.empty?
            if @run_options.get.respond_to?(:skipExpandObjects)
              return @run_options.get.skipExpandObjects
            else
              if @workflow[:run_options]
                return @workflow[:run_options][:skip_expand_objects]
              end
            end
          end
        
          return default
        end
        
        def skip_energyplus_preprocess(user_options, default)
          
          # user option trumps all others
          return user_options[:skip_energyplus_preprocess] if user_options[:skip_energyplus_preprocess]
          
          # try to read from OSW
          if @run_options && !@run_options.empty?
            if @run_options.get.respond_to?(:skipEnergyPlusPreprocess)
              return @run_options.get.skipEnergyPlusPreprocess
            else
              if @workflow[:run_options]
                return @workflow[:run_options][:skip_energyplus_preprocess]
              end
            end
          end
        
          return default
        end
        
        def cleanup(user_options, default)
          
          # user option trumps all others
          return user_options[:cleanup] if user_options[:cleanup]
          
          # try to read from OSW
          if @run_options && !@run_options.empty?
            return @run_options.get.cleanup
          end
        
          return default
        end
        
        def energyplus_path(user_options, default)
          
          # user option trumps all others
          return user_options[:energyplus_path] if user_options[:energyplus_path]
        
          return default
        end
        
        def profile(user_options, default)
          
          # user option trumps all others
          return user_options[:profile] if user_options[:profile]
        
          return default
        end   
        
        def verify_osw(user_options, default)
          
          # user option trumps all others
          return user_options[:verify_osw] if user_options[:verify_osw]
        
          return default
        end   
        
        def weather_file(user_options, default)
          
          # user option trumps all others
          return user_options[:weather_file] if user_options[:weather_file]
          
          # try to read from OSW
          if !@workflow_json.weatherFile.empty?
            return @workflow_json.weatherFile.get.to_s
          end
        
          return default
        end
        
        # Get the associated OSD (datapoint) file from the local filesystem
        #
        def datapoint
          # DLM: should this come from the OSW?  the osd id and checksum are specified there.
          osd_abs_path = File.join(osw_dir, 'datapoint.osd')
          result = nil
          if File.exist? osd_abs_path
            result = ::JSON.parse(File.read(osd_abs_path), symbolize_names: true)
          end
          return result
        end

        # Get the associated OSA (analysis) definition from the local filesystem
        #
        def analysis
          # DLM: should this come from the OSW?  the osd id and checksum are specified there.
          osa_abs_path = File.join(osw_dir, '../analysis.json')
          result = nil
          if File.exist? osa_abs_path
            result = ::JSON.parse(File.read(osa_abs_path), symbolize_names: true)
          end
          return result
        end
        
      end
    end
  end
end
