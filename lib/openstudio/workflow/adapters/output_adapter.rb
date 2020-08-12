# frozen_string_literal: true

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

module OpenStudio
  module Workflow
    # Base class for all output adapters. These methods define the expected return behavior of the adapter instance
    class OutputAdapters
      attr_accessor :options

      def initialize(options = {})
        @options = options
      end

      def communicate_started
        instance.communicate_started
      end

      def communicate_transition(message, type, options = {})
        instance.communicate_transition message, type, options
      end

      def communicate_energyplus_stdout(line, options = {})
        instance.communicate_energyplus_stdout line, options
      end

      def communicate_measure_result(result, options = {})
        instance.communicate_measure_result result, options
      end

      def communicate_measure_attributes(measure_attributes, options = {})
        instance.communicate_measure_attributes measure_attributes, options
      end

      def communicate_objective_function(objectives, options = {})
        instance.communicate_objective_function objectives, options
      end

      def communicate_results(directory, results)
        instance.communicate_results directory, results
      end

      def communicate_complete
        instance.communicate_complete
      end

      def communicate_failure
        instance.communicate_failure
      end

      protected

      # Zip up a folder and it's contents
      def zip_directory(directory, zip_filename, pattern = '*')
        # Submethod for adding the directory to the zip folder.
        def add_directory_to_zip(zip_file, local_directory, root_directory)
          Dir[File.join(local_directory.to_s, '**', '**')].each do |file|
            # remove the base directory from the zip file
            rel_dir = local_directory.sub("#{root_directory}/", '')
            zip_file_to_add = file.gsub(local_directory.to_s, rel_dir.to_s)
            if File.directory?(file)
              zip_file.addDirectory(file, zip_file_to_add)
            else
              zip_file.addFile(file, zip_file_to_add)
            end
          end

          zip_file
        end

        FileUtils.rm_f(zip_filename) if File.exist?(zip_filename)

        zf = OpenStudio::ZipFile.new(zip_filename, false)

        Dir[File.join(directory, pattern)].each do |file|
          if File.directory?(file)
            # skip a few directory that should not be zipped as they are inputs
            if File.basename(file) =~ /seed|measures|weather/
              next
            end

            # skip x-large directory
            if File.size?(file)
              next if File.size?(file) >= 15000000
            end
            add_directory_to_zip(zf, file, directory)
          else
            next if File.extname(file) =~ /\.rb.*/
            next if File.extname(file) =~ /\.zip.*/

            # skip large non-osm/idf files
            if File.size(file)
              if File.size(file) >= 100000000
                next unless File.extname(file) == '.osm' || File.extname(file) == '.idf'
              end
            end

            zip_file_to_add = file.gsub("#{directory}/", '')
            zf.addFile(file, zip_file_to_add)
          end
        end

        zf = nil
        GC.start

        File.chmod(0o664, zip_filename)
      end

      # Main method to zip up the results of the simulation results. This will append the UUID of the data point
      # if it exists. This method will create two zip files. One for the reports and one for the entire data point. The
      # Data Point ZIP will also contain the reports.
      #
      # @param directory [String] The data point directory to zip up.
      # @return nil
      #
      def zip_results(directory)
        # create zip file using a system call
        if Dir.exist?(directory) && File.directory?(directory)
          zip_filename = @datapoint ? "data_point_#{@datapoint.uuid}.zip" : 'data_point.zip'
          zip_filename = File.join(directory, zip_filename)
          #zip_directory directory, zip_filename
          zf = ZipFileGenerator.new(directory, zip_filename)
          zf.write
        end

        # zip up only the reports folder
        report_dir = File.join(directory, 'reports')
        if Dir.exist?(report_dir) && File.directory?(report_dir)
          zip_filename = @datapoint ? "data_point_#{@datapoint.uuid}_reports.zip" : 'data_point_reports.zip'
          zip_filename = File.join(directory, zip_filename)
          #zip_directory directory, zip_filename, 'reports'
          zf = ZipFileGenerator.new(report_dir, zip_filename)
          zf.write
        end
      end

    end
    
    require 'zip'    
    class ZipFileGenerator
      # Initialize with the directory to zip and the location of the output archive.
      def initialize(input_dir, output_file)
        @input_dir = input_dir
        @output_file = output_file
      end

      # Zip the input directory.
      def write
        entries = Dir.entries(@input_dir) - %w[. ..]

        ::Zip::File.open(@output_file, ::Zip::File::CREATE) do |zipfile|
          write_entries entries, '', zipfile
        end
      end

      private

      # A helper method to make the recursion work.
      def write_entries(entries, path, zipfile)
        entries.each do |e|
          zipfile_path = path == '' ? e : File.join(path, e)
          disk_file_path = File.join(@input_dir, zipfile_path)

          if File.directory? disk_file_path
            recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
          else
            put_into_archive(disk_file_path, zipfile, zipfile_path)
          end
        end
      end

      def recursively_deflate_directory(disk_file_path, zipfile, zipfile_path)
        zipfile.mkdir zipfile_path
        subdir = Dir.entries(disk_file_path) - %w[. ..]
        write_entries subdir, zipfile_path, zipfile
      end

      def put_into_archive(disk_file_path, zipfile, zipfile_path)
        zipfile.add(zipfile_path, disk_file_path)
      end
    end
    
  end
end
