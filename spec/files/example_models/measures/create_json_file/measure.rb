# start the measure
class CreateJsonFile < OpenStudio::Ruleset::ModelUserScript
  # define the name that a user will see
  def name
    'Create JSON File'
  end

  # define the arguments that the user will input
  def arguments(_model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    j = {
        example: {
            int: 123,
            float: 123.4,
            string: '123.45',
            boolean: true
        }
    }

    # read in template
    file_to_save = './report.json'
    File.open(file_to_save, 'w') { |f| f << JSON.pretty_generate(j) }


    # read in template
    file_to_save = './report_2.json'
    File.open(file_to_save, 'w') { |f| f << JSON.pretty_generate(j) }



    # should save the file, but won't end up in report directory
    file_to_save = './nothing.json'
    File.open(file_to_save, 'w') { |f| f << JSON.pretty_generate(j) }
    true
  end
end

# this allows the measure to be used by the application
CreateJsonFile.new.registerWithApplication
