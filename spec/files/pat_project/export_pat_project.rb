require 'openstudio'
require 'fileutils'

project = OpenStudio::AnalysisDriver::SimpleProject.open('E:\test\CloudTest').get
zip = project.zipFileForCloud
FileUtils.cp(zip.to_s, 'project.zip')

analysis = project.analysis

data_points = analysis.dataPoints
puts "data_points=#{data_points}"
data_points.each do |data_point|
  puts data_point
  data_point.saveJSON("data_point_#{OpenStudio.removeBraces(data_point.uuid)}.json", true)
end
