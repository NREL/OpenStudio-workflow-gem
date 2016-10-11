require_relative './../../spec_helper'
require 'json-schema'

describe 'OSW Integration' do
  it 'should run empty OSW file' do
    osw_path = File.join(__FILE__, './../../../files/empty_seed_osw/empty.osw')
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run compact OSW file' do
    osw_path = File.join(__FILE__, './../../../files/compact_osw/compact.osw')
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run an extended OSW file' do
    osw_path = File.join(__FILE__, './../../../files/extended_osw/example/workflows/extended.osw')
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run an alternate path OSW file' do
    osw_path = File.join(__FILE__, './../../../files/alternate_paths/osw_and_stuff/in.osw')
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run OSW file with skips' do
    osw_path = File.join(__FILE__, './../../../files/skip_osw/skip.osw')
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run OSW file with handle arguments' do
    osw_path = File.join(__FILE__, './../../../files/handle_args_osw/handle_args.osw')
    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished
  end

  it 'should run OSW with output requests file' do
    osw_path = File.join(__FILE__, './../../../files/output_request_osw/output_request.osw')
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end

    idf_out_path = osw_path.gsub(File.basename(osw_path), 'in.idf')

    expect(File.exist?(idf_out_path)).to eq true

    workspace = OpenStudio::Workspace.load(idf_out_path)
    expect(workspace.empty?).to eq false

    workspace = workspace.get

    targets = {}
    targets['Electricity:Facility'] = false
    targets['Gas:Facility'] = false
    targets['District Cooling Chilled Water Rate'] = false
    targets['District Cooling Mass Flow Rate'] = false
    targets['District Cooling Inlet Temperature'] = false
    targets['District Cooling Outlet Temperature'] = false
    targets['District Heating Hot Water Rate'] = false
    targets['District Heating Mass Flow Rate'] = false
    targets['District Heating Inlet Temperature'] = false
    targets['District Heating Outlet Temperature'] = false

    workspace.getObjectsByType('Output:Variable'.to_IddObjectType).each do |object|
      name = object.getString(1)
      expect(name.empty?).to eq false
      name = name.get
      targets[name] = true
    end

    targets.each_key do |key|
      expect(targets[key]).to eq true
    end
  end

  it 'should run OSW file with web adapter' do
    require 'openstudio/workflow/adapters/output/web'

    osw_path = File.join(__FILE__, './../../../files/web_osw/web.osw')
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    output_adapter = OpenStudio::Workflow::OutputAdapter::Web.new(output_directory: run_dir, url: 'http://www.example.com')

    run_options = {
      debug: true,
      output_adapter: output_adapter
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run OSW file with socket adapter' do
    require 'openstudio/workflow/adapters/output/socket'

    osw_path = File.join(__FILE__, './../../../files/socket_osw/socket.osw')
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    port = 2000
    content = ''

    server = TCPServer.open(port)
    t = Thread.new do
      while client == server.accept
        while line == client.gets
          content += line
        end
      end
    end

    output_adapter = OpenStudio::Workflow::OutputAdapter::Socket.new(output_directory: run_dir, port: port)

    run_options = {
      debug: true,
      output_adapter: output_adapter
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true
    
    Thread.kill(t)

    expect(content).to match(/Starting state initialization/)
    expect(content).to match(/Processing Data Dictionary/)
    expect(content).to match(/Writing final SQL reports/)

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run OSW file with no epw file' do
    osw_path = File.join(__FILE__, './../../../files/no_epw_file_osw/no_epw_file.osw')
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end

  it 'should run OSW file in measure only mode' do
    osw_path = File.join(__FILE__, './../../../files/measures_only_osw/measures_only.osw')
    osw_out_path = osw_path.gsub(File.basename(osw_path), 'out.osw')
    run_dir = File.join(File.dirname(osw_path), 'run')

    FileUtils.rm_rf(osw_out_path) if File.exist?(osw_out_path)
    expect(File.exist?(osw_out_path)).to eq false

    run_options = {
      debug: true
    }
    run_options[:jobs] = [
      { state: :queued, next_state: :initialization, options: { initial: true } },
      { state: :initialization, next_state: :os_measures, job: :RunInitialization,
        file: 'openstudio/workflow/jobs/run_initialization.rb', options: {} },
      { state: :os_measures, next_state: :translator, job: :RunOpenStudioMeasures,
        file: 'openstudio/workflow/jobs/run_os_measures.rb', options: {} },
      { state: :translator, next_state: :ep_measures, job: :RunTranslation,
        file: 'openstudio/workflow/jobs/run_translation.rb', options: {} },
      { state: :ep_measures, next_state: :finished, job: :RunEnergyPlusMeasures,
        file: 'openstudio/workflow/jobs/run_ep_measures.rb', options: {} },
      { state: :postprocess, next_state: :finished, job: :RunPostprocess,
        file: 'openstudio/workflow/jobs/run_postprocess.rb', options: {} },
      { state: :finished },
      { state: :errored }
    ]
    k = OpenStudio::Workflow::Run.new osw_path, run_options
    expect(k).to be_instance_of OpenStudio::Workflow::Run
    expect(k.run).to eq :finished

    expect(File.exist?(osw_out_path)).to eq true

    osw_out = nil
    File.open(osw_out_path, 'r') do |file|
      osw_out = JSON.parse(file.read, symbolize_names: true)
    end

    expect(osw_out).to be_instance_of Hash
    expect(osw_out[:completed_status]).to eq 'Success'
    expect(osw_out[:steps]).to be_instance_of Array
    expect(osw_out[:steps].size).to be > 0
    osw_out[:steps].each do |step|
      expect(step[:result]).to_not be_nil
    end
  end
end
