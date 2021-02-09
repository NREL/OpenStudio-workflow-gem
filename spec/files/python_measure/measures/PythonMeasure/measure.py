import openstudio
import typing

class PythonMeasureName(openstudio.measure.PythonMeasure):

    def name(self):
        """
        Return the human readable name.
        Measure name should be the title case of the class name.
        """
        return "PythonMeasureName"

    def description(self):
        """
        human readable description
        """
        return "DESCRIPTION_TEXT"

    def modeler_description(self):
        """
        human readable description of modeling approach
        """
        return "MODELER_DESCRIPTION_TEXT"

    def arguments(self, model: typing.Optional[openstudio.model.Model]=None):
        """
        define what happens when the measure is run
        """
        args = openstudio.measure.OSArgumentVector()

        example_arg = openstudio.measure.OSArgument.makeStringArgument('space_name', True)
        example_arg.setDisplayName('New space name')
        example_arg.setDescription('This name will be used as the name of the new space.')
        example_arg.setDefaultValue('default_space_name')
        args.append(example_arg)

        return args

    def run(self,
            model: openstudio.model.Model,
            runner: openstudio.measure.OSRunner,
            user_arguments: openstudio.measure.OSArgumentMap):
        """
        define what happens when the measure is run
        """
        print("Hello!")
        print(f"runner: {runner}")
        print(f"runner.workflow(): {runner.workflow()}")
        print(f"model: {model}")
        super().run(model, runner, user_arguments)
        print(f"super().run() runner.workflow(): {runner.workflow()}")
        print("Hello again!")
        if not(runner.validateUserArguments(self.arguments(model),
                                            user_arguments)):
            return False

        print("Hello x2")
        # assign the user inputs to variables
        space_name = runner.getStringArgumentValue('space_name',
                                                   user_arguments)

        # check the example_arg for reasonableness
        if not space_name:
            runner.registerError('Empty space name was entered.')
            return False

        print("Hello x3")
        # report initial condition of model
        n_ori = len(model.getSpaces())
        print("Hello x4")
        print(f"The building started with {n_ori} spaces.")
        runner.registerInitialCondition(
            f"The building started with {n_ori} spaces."
        )
        print("Hello x5")
        # add a new space to the model
        new_space = openstudio.model.Space(model)
        new_space.setName(space_name)

        # echo the new space's name back to the user
        runner.registerInfo(f"Space {new_space.nameString()} was added.")

        # report final condition of model
        runner.registerFinalCondition(
            f"The building finished with {len(model.getSpaces())} spaces."
        )

        print("end of measure")
        print(openstudio.openStudioLongVersion())
        return True
