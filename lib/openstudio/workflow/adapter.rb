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

# Adapter class to decide where to obtain instructions to run the simulation workflow
module OpenStudio
  module Workflow
    class Adapter
      attr_accessor :options

      def initialize(options = {})
        @options = options
        @log = nil
        @datapoint = nil
      end

      # class << self
      # attr_reader :problem

      def load(filename, options = {})
        instance.load(filename, options)
      end

      def communicate_started(id, _options = {})
        instance.communicate_started id
      end

      def get_datapoint(id, options = {})
        instance.get_datapoint id, options
      end

      def get_problem(id, options = {})
        instance.get_problem id, options
      end

      def communicate_results(id, results)
        instance.communicate_results id, results
      end

      def communicate_complete(id)
        instance.communicate_complete id
      end

      def communicate_failure(id)
        instance.communicate_failure id
      end

      def get_logger(file, options = {})
        instance.get_logger file, options
      end

      protected

      # Zip up a folder and it's contents
      def zip_directory(directory, zip_filename)
        # Submethod for adding the directory to the zip folder.
        def add_directory_to_zip(zip_file, local_directory, root_directory)
          Dir[File.join("#{local_directory}", '**', '**')].each do |file|
            # remove the base directory from the zip file
            rel_dir = local_directory.sub("#{root_directory}/", '')
            zip_file_to_add = file.gsub("#{local_directory}", "#{rel_dir}/")
            zip_file.add(zip_file_to_add, file)
          end

          zip_file
        end

        FileUtils.rm_f(zip_filename) if File.exist?(zip_filename)

        Zip.default_compression = Zlib::BEST_COMPRESSION
        Zip::File.open(zip_filename, Zip::File::CREATE) do |zf|
          Dir[File.join(directory, '*')].each do |file|
            if File.directory?(file)
              # skip a few directory that should not be zipped as they are inputs
              if File.basename(file) =~ /seed|measures|weather/
                next
              end
              add_directory_to_zip(zf, file, directory)
            else
              next if File.extname(file) =~ /\.rb.*/
              next if File.extname(file) =~ /\.zip.*/

              zip_file_to_add = file.gsub("#{directory}/", '')
              zf.add(zip_file_to_add, file)
            end
          end
        end

        File.chmod(0664, zip_filename)
      end

      # Main method to zip up the results of the simulation results. This will append the UUID of the data point
      # if it exists. This method will create two zip files. One for the reports and one for the entire data point. The
      # Data Point ZIP will also contain the reports.
      #
      # @param directory [String] The data point directory to zip up.
      # @return nil
      def zip_results(directory)
        # create zip file using a system call
        # @logger.info "Zipping up data point #{analysis_dir}"
        if Dir.exist?(directory) && File.directory?(directory)
          zip_filename = @datapoint ? "data_point_#{@datapoint.uuid}.zip" : 'data_point.zip'
          zip_filename = File.join(directory, zip_filename)
          zip_directory directory, zip_filename
        end

        # zip up only the reports folder

        actual_report_dir = File.join(directory, 'reports')
        # @logger.info "Zipping up Analysis Reports Directory #{report_dir}/reports"
        if Dir.exist?(actual_report_dir) && File.directory?(actual_report_dir)
          #### This is cheesy, but create another directory level for the reports so that it zips up correctly (with the reports folder at the root)
          tmp_report_dir = File.join(directory, 'zip_me')
          FileUtils.mkdir_p tmp_report_dir
          FileUtils.move actual_report_dir, tmp_report_dir, force: true

          zip_filename = @datapoint ? "data_point_#{@datapoint.uuid}_reports.zip" : 'data_point_reports.zip'
          zip_filename = File.join(directory, zip_filename)
          zip_directory tmp_report_dir, zip_filename

          # move back
          FileUtils.move tmp_report_dir, actual_report_dir, force: true
        end

      end
    end
  end
end
