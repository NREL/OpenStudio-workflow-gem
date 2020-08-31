# frozen_string_literal: true

require '/home/julien/Software/Others/OS-build/Products/ruby/openstudio.so'

failures = []
Dir.glob(File.join(File.dirname(__FILE__), '*/**/*.osm')).each do |path|
  puts path
  vt = OpenStudio::OSVersion::VersionTranslator.new
  m = vt.loadModel(path)
  if m.is_initialized
    m.get.save(path, true)
  else
    failures << path
  end
end

if !failures.empty?
  puts
  puts 'Failures:'
  puts failures.join("\n")
end
