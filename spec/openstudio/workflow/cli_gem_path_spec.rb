require_relative './../../spec_helper'

#describe 'Load the correct gems' do
#
#  it 'should find the `color_text` gem in the local_gem_exec workflow measure' do
#
#    lib_file = File.absolute_path(File.join(__FILE__, '../../../../lib'))
#    cli_file = File.absolute_path(File.join(__FILE__, '../../../../bin/openstudio_cli'))
#    test_gem_path = File.absolute_path(File.join(__FILE__, '../../../files/local_gem_path'))
#    workflow_file = File.absolute_path(File.join(__FILE__, '../../../files/local_gem_exec_osw/workflow.osw'))
#    res = system "ruby -I #{lib_file} #{cli_file} --gem_path #{test_gem_path} run -w #{workflow_file} -m --verbose"
#
#    expect(res).to eq true
#  end
#end