require 'json'

class StaticPressureResetEms < OpenStudio::Ruleset::WorkspaceUserScript
  def name
    return "StaticPressureResetEms"
  end

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure", true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure
    return args
  end

  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    runner.registerValue("energyplus_user_script", true)

    runner.registerAsNotApplicable("No Airloops are appropriate for this measure")
    return false

    # this will never be called
    runner.registerValue("energyplus_user_post_valid", true)

    return true
  end
end

StaticPressureResetEms.new.registerWithApplication