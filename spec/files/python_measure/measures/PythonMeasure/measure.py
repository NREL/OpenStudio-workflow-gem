import openstudio
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
    def arguments(model):
        """
        define what happens when the measure is run
        """
        args = openstudio.measure.OSArgumentVector()
        
        example_arg = openstudio.measure.OSArgument.makeStringArgument('example_arg', True)
        example_arg.setDisplayName('example argument')
        example_arg.setDescription('This is a placeholder for an argument')
        example_arg.setDefaultValue('default_value')
        args.append(example_arg)
        
        return args
    def run(model, runner, user_arguments):
        """
        define what happens when the measure is run
        """
        super(model, runner, user_arguments)
        # runner = openstudio.measure.OSRunner(openstudio.openstudioutilities.openstudioutilitiesfiletypes.WorkflowJSON())
        #
        print(openstudio.openStudioLongVersion())
        return true