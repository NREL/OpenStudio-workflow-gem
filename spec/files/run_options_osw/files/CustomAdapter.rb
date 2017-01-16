require 'rest-client'
require 'base64'
require 'logger'

openstudio_dir = ARGV[0]
$:.unshift(openstudio_dir)
if /win/.match(RUBY_PLATFORM) or /mingw/.match(RUBY_PLATFORM)
  ENV['PATH'] = openstudio_dir + ";" + ENV['PATH']
else
  ENV['PATH'] = openstudio_dir + ":" + ENV['PATH']
end

require 'openstudio'
require 'openstudio-workflow'
require 'openstudio/workflow/adapters/output_adapter'

$logger = Logger.new(STDOUT)
$logger.level = Logger::ERROR
#$logger.level = Logger::WARN
#$logger.level = Logger::DEBUG

OpenStudio::Logger.instance.standardOutLogger.enable
OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)
#OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Debug)

debug = false


osw_path = ARGV[1]
osw_dir = File.dirname(osw_path)

city_db_url = ARGV[2]

datapoint_id = ARGV[3]

project_id = ARGV[4]

# Run workflow.osw
run_options = Hash.new
run_options[:debug] = debug
run_options[:preserve_run_dir] = true # because we are running in .

if city_db_url && datapoint_id && project_id

  # Custom Output Adapter
  module OpenStudio
    module Workflow
      module OutputAdapter
        class CityDB < OutputAdapters
          def initialize(options = {})
            fail 'The required :output_directory option was not passed to the local output adapter' unless options[:output_directory]
            fail 'The required :url option was not passed to the local output adapter' unless options[:url]
            @url = options[:url]
            @user_name = 'test@nrel.gov'
            @user_pwd = 'testing123'
            super
          end
          
          def send_status(status)

            datapoint = {}
            datapoint[:id] = @options[:datapoint_id]
            datapoint[:status] = status

            params = {}
            params[:project_id] = @options[:project_id]
            params[:datapoint] = datapoint

            request = RestClient::Resource.new("#{@url}/api/datapoint", user: @user_name, password: @user_pwd)
            
            begin
              response = request.post(params, content_type: :json, accept: :json)
            rescue => e
              puts "Bad response #{e.response}"
              puts e.message
              return false
            end
          
            return true
          end
          
          def send_file(path)
            if !File.exists?(path)
              puts "send_file cannot open file '#{path}'"
              return false
            end

            the_file = ''
            File.open(path, 'rb') do |file|
              the_file = Base64.strict_encode64(file.read)
            end
            
            if the_file.empty?
              the_file = Base64.strict_encode64("\n")
            end
    
            file_data = {}
            file_data[:file_name] = File.basename(path)
            file_data[:file] = the_file

            params = {}
            params[:datapoint_id] = @options[:datapoint_id]
            params[:file_data] = file_data
            
            puts "sending file '#{path}'"
            visible_params = Marshal.load(Marshal.dump(params))
            visible_params[:file_data].delete(:file)
            puts visible_params

            request = RestClient::Resource.new("#{@url}/api/datapoint_file", user: @user_name, password: @user_pwd)
            
            begin
              response = request.post(params, content_type: :json, accept: :json)            
            rescue => e
              puts "Bad response #{e.response}"
              puts e.message
              return false
            end
            
            return true
          end

          # Write that the process has started
          def communicate_started
            File.open("#{@options[:output_directory]}/started.job", 'w') { |f| f << "Started Workflow #{::Time.now} #{@options}" }
            fail 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
            send_status("Started")
          end

          # Write that the process has completed
          def communicate_complete
            File.open("#{@options[:output_directory]}/finished.job", 'w') { |f| f << "Finished Workflow #{::Time.now} #{@options}" }
            fail 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
            send_status("Complete")
            send_file("#{@options[:output_directory]}/run.log")
            Dir.glob("#{@options[:output_directory]}/../reports/*").each { |f| send_file(f) }
          end

          # Write that the process has failed
          def communicate_failure
            File.open("#{@options[:output_directory]}/failed.job", 'w') { |f| f << "Failed Workflow #{::Time.now} #{@options}" }
            fail 'Missing required options' unless @options[:url] && @options[:datapoint_id] && @options[:project_id]
            send_status("Failed")
            send_file("#{@options[:output_directory]}/run.log")
            Dir.glob("#{@options[:output_directory]}/../reports/*").each { |f| send_file(f) }
          end

          # Do nothing on a state transition
          def communicate_transition(_=nil, _=nil) 
          end
          
          # Do nothing on E+ std out
          def communicate_energyplus_stdout(_=nil, _=nil) 
          end

          # Write the measure attributes to the filesystem
          def communicate_measure_attributes(measure_attributes, _=nil)
            #File.open("#{@options[:output_directory]}/measure_attributes.json", 'w') do |f|
            #  f << JSON.pretty_generate(measure_attributes)
            #end
          end

          # Write the objective function results to the filesystem
          def communicate_objective_function(objectives, _=nil)
            #obj_fun_file = "#{@options[:output_directory]}/objectives.json"
            #FileUtils.rm_f(obj_fun_file) if File.exist?(obj_fun_file)
            #File.open(obj_fun_file, 'w') { |f| f << JSON.pretty_generate(objectives) }
          end

          # Write the results of the workflow to the filesystem
          def communicate_results(directory, results)
            zip_results(directory)

            #if results.is_a? Hash
            #  File.open("#{@options[:output_directory]}/data_point_out.json", 'w') { |f| f << JSON.pretty_generate(results) }
            #else
            #  puts "Unknown datapoint result type. Please handle #{results.class}"
            #end
          end
        end
      end
    end
  end

  output_options = {output_directory: File.join(osw_dir, '.'), url: city_db_url, datapoint_id: datapoint_id, project_id: project_id}
  output_adapter = OpenStudio::Workflow::OutputAdapter::CityDB.new(output_options)
  
  run_options[:output_adapter] = output_adapter
end

# do the run
k = OpenStudio::Workflow::Run.new(osw_path, run_options)
final_state = k.run