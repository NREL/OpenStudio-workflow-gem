# insert your copyright here

import pytest
import openstudio
import pathlib
from measure import PythonMeasureName


class TestPythonMeasureName:

    def test_number_of_arguments_and_argument_names(self):
        """
        Test that the arguments are what we expect
        """
        # create an instance of the measure
        measure = PythonMeasureName()

        # make an empty model
        model = openstudio.model.Model()

        # get arguments and test that they are what we are expecting
        arguments = measure.arguments(model)
        assert arguments.size() == 1
        assert arguments[0].name() == 'space_name'

    def test_optional_model_for_arguments(self):
        """
        Tests that passing model to arguments() is optional
        """
        # create an instance of the measure
        measure = PythonMeasureName()

        # Ruby allows **not** passing model to the method, so test that
        arguments = measure.arguments()
        assert arguments.size() == 1
        assert arguments[0].name() == 'space_name'

    def test_good_argument_values(self):
        """
        Test running the measure with appropriate arguments, and that the
        measure runs fine and with expected results
        """

        # create an instance of the measure
        measure = PythonMeasureName()

        # create runner with empty OSW
        osw = openstudio.WorkflowJSON()
        runner = openstudio.measure.OSRunner(osw)

        # load the test model
        # translator = openstudio.osversion.VersionTranslator()
        # path = openstudio.toPath(
        #     str(pathlib.Path(__file__).parent.absolute()
        #         / "examle_model.osm"))
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
        # If the argument has a default that you want to use,
        # you don't need it in the dict
        args_dict = {}
        args_dict['space_name'] = 'New Space'
        # using defaults values from measure.py for other arguments

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

        num_spaces_final = len(model.getSpaces())

        # show the output
        # show_output(result)
        print(f"results: {result}")

        # assert that it ran correctly
        assert result.value().valueName() == 'Success'
        assert len(result.info()) == 1
        assert len(result.warnings()) == 0

        assert result.info()[0].logMessage() == "Space New Space was added."

        assert num_spaces_final == num_spaces_seed + 1

        # save the model to test output directory
        output_file_path = openstudio.toPath(
            str(pathlib.Path(__file__).parent.absolute()
                / "output" / "test_output.osm"))
        model.save(output_file_path, True)
