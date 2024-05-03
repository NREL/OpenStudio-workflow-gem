#!/usr/bin/env ruby

ruby_regex = /^#.\*{79}.*#.\*{79}$/m
erb_regex = /^<%.*#.\*{79}.*#.\*{79}.%>$/m
js_regex = %r{^/\* @preserve.*Copyright.*#.\*/}m

ruby_header_text = <<~EOT
  # *******************************************************************************
  # OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
  # See also https://openstudio.net/license
  # *******************************************************************************
EOT
ruby_header_text.strip!

erb_header_text = <<~EOT
  <%
  # *******************************************************************************
  # OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
  # See also https://openstudio.net/license
  # *******************************************************************************
  %>
EOT
erb_header_text.strip!

js_header_text = <<~EOT
  /* @preserve
   * OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC. reserved.
   * See also https://openstudio.net/license
  */
EOT
js_header_text.strip!

paths = [
  { glob: 'lib/**/*.rb', license: ruby_header_text, regex: ruby_regex },
  { glob: 'spec/openstudio/workflow/*.rb', license: ruby_header_text, regex: ruby_regex },
  { glob: 'spec/openstudio/workflow/*.rb', license: ruby_header_text, regex: ruby_regex },

  # single files
  { glob: 'spec/list_registry_options.rb', license: ruby_header_text, regex: ruby_regex },
  { glob: 'spec/spec_helper.rb', license: ruby_header_text, regex: ruby_regex }
]

paths.each do |path|
  Dir[path[:glob]].each do |file|
    puts "Updating license in file #{file}"

    f = File.read(file)
    if f =~ path[:regex]
      puts '  License found -- updating'
      File.open(file, 'w') { |write| write << f.gsub(path[:regex], path[:license]) }
    else
      puts '  No license found -- adding'
      if f =~ /#!/
        puts '  CANNOT add license to file automatically, add it manually and it will update automatically in the future'
        next
      end
      File.open(file, 'w') { |write| write << f.insert(0, "#{path[:license]}\n\n") }
    end
  end
end
