# insert your copyright here

import pytest
import openstudio
import pathlib
from measure import PythonMeasureName

class TestPythonMeasureName:
  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names(self):
    # create an instance of the measure
    measure = PythonMeasureName()

    # make an empty model
    model = openstudio.model.Model()

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert arguments.size() == 1
    assert arguments[0].name() == 'space_name'


  def test_good_argument_values(self):
    # create an instance of the measure
    measure = PythonMeasureName()

    # create runner with empty OSW
    osw = openstudio.WorkflowJSON()
    runner = openstudio.measure.OSRunner(osw)

    # load the test model
    # translator = openstudio.osversion.VersionTranslator()
    # path = pathlib.Path(__file__).parent.absolute() / "examle_model.osm"
    # model = translator.loadModel(path)
    # assert(model.is_initialized())
    # model = model.get()

    model = openstudio.model.Model()

    # store the number of spaces in the seed model
    num_spaces_seed = len(model.getSpaces())

    # get arguments
    arguments = measure.arguments(model)
    argument_map = openstudio.measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_dict = {}
    args_dict['space_name'] = 'New Space'
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    for arg in arguments:
        temp_arg_var = arg.clone()
        if arg.name() in args_dict:
            assert(temp_arg_var.setValue(args_dict[arg.name()]))
        argument_map[arg.name()] = temp_arg_var

    print("run measure:")

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result()

    # show the output
    # show_output(result)
    print(f"results: {result}")

    # assert that it ran correctly
    assert result.value().valueName() == 'Success'
    assert len(result.info()) == 1
    assert len(result.warnings()) == 0

    assert result.info()[0].logMessage() == "Space New Space was added."

    # save the model to test output directory
    #output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    #model.save(output_file_path, true)
