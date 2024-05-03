# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'openstudio/workflow/adapters/output_adapter'

# Local file based workflow
module OpenStudio
  module Workflow
    module OutputAdapter
      class Local < OutputAdapters
        def initialize(options = {})
          raise 'The required :output_directory option was not passed to the local output adapter' unless options[:output_directory]

          super
        end

        # Write to the filesystem that the process has started
        #
        def communicate_started
          File.open("#{@options[:output_directory]}/started.job", 'w') do |f|
            f << "Started Workflow #{::Time.now}"
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue StandardError
              f.flush
            end
          end
        end

        # Write to the filesystem that the process has completed
        #
        def communicate_complete
          File.open("#{@options[:output_directory]}/finished.job", 'w') do |f|
            f << "Finished Workflow #{::Time.now}"
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue StandardError
              f.flush
            end
          end
        end

        # Write to the filesystem that the process has failed
        #
        def communicate_failure
          File.open("#{@options[:output_directory]}/failed.job", 'w') do |f|
            f << "Failed Workflow #{::Time.now}"
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue StandardError
              f.flush
            end
          end
        end

        # Do nothing on a state transition
        #
        def communicate_transition(_ = nil, _ = nil, _ = nil); end

        # Do nothing on EnergyPlus stdout
        #
        def communicate_energyplus_stdout(_ = nil, _ = nil); end

        # Do nothing on Measure result
        #
        def communicate_measure_result(_ = nil, _ = nil); end

        # Write the measure attributes to the filesystem
        #
        def communicate_measure_attributes(measure_attributes, _ = nil)
          attributes_file = "#{@options[:output_directory]}/measure_attributes.json"
          FileUtils.rm_f(attributes_file) if File.exist?(attributes_file)
          File.open(attributes_file, 'w') do |f|
            f << JSON.pretty_generate(measure_attributes)
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue StandardError
              f.flush
            end
          end
        end

        # Write the objective function results to the filesystem
        #
        def communicate_objective_function(objectives, _ = nil)
          obj_fun_file = "#{@options[:output_directory]}/objectives.json"
          FileUtils.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
          File.open(obj_fun_file, 'w') do |f|
            f << JSON.pretty_generate(objectives)
            # make sure data is written to the disk one way or the other
            begin
              f.fsync
            rescue StandardError
              f.flush
            end
          end
        end

        # Write the results of the workflow to the filesystem
        #
        def communicate_results(directory, results, skip_zip_results)
          if !skip_zip_results
            zip_results(directory)
          end

          if results.is_a? Hash
            # DLM: don't we want this in the results zip?
            # DLM: deprecate in favor of out.osw
            File.open("#{@options[:output_directory]}/data_point_out.json", 'w') do |f|
              f << JSON.pretty_generate(results)
              # make sure data is written to the disk one way or the other
              begin
                f.fsync
              rescue StandardError
                f.flush
              end
            end
          else
            # puts "Unknown datapoint result type. Please handle #{results.class}"
          end
        end
      end
    end
  end
end
