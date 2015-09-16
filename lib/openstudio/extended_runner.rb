# Extend OS Runner to persist measure information throughout the workflow
class ExtendedRunner < OpenStudio::Ruleset::OSRunner
  # Allow former arguments to be set and read
  # TODO: Consider having the former arguments passed in in initialization, and define as attr_reader
  attr_accessor :former_workflow_arguments
  attr_reader :workflow_arguments

  # Add in @workflow_arguments
  def initialize
    super

    @workflow_arguments = nil
  end

  # Take the OS Argument type and map it correctly to the argument value.
  #     OPENSTUDIO_ENUM( OSArgumentType,
  #     ((Boolean)(Bool)(0))
  #     ((Double)(Double)(1))
  #     ((Quantity)(Quantity)(2))
  #     ((Integer)(Int)(3))
  #     ((String)(String)(4))
  #     ((Choice)(Choice)(5))
  #     ((Path)(Path)(6))
  #     );
  # @param os_argument_name [String] The string of the argument to check
  # @param user_arguments [OSArgumentMap] Map of the arguments to check
  def bad_os_typecasting(os_argument_name, user_arguments)
    out = nil
    user_arguments.each do |arg_name, arg|
      # get the type cast value
      next unless os_argument_name == arg_name

      case arg.type.valueName
        when 'Boolean'
          out = arg.valueAsBool if arg.hasValue
        when 'Double'
          out = arg.valueAsDouble if arg.hasValue
        when 'Quantity'
          warn 'This OpenStudio Argument Type is deprecated'
        when 'Integer'
          out = arg.valueAsInteger if arg.hasValue
        when 'String'
          out = arg.valueAsString if arg.hasValue
        when 'Choice'
          out = arg.valueAsString if arg.hasValue
        when 'Path'
          out = arg.valueAsPath.to_s if arg.hasValue
      end
    end

    out
  end

  # Overloaded argument parsing
  def validateUserArguments(script_arguments, user_arguments)
    @workflow_arguments = {}
    user_arguments.each do |hash|
      value = bad_os_typecasting(hash, user_arguments)
      @workflow_arguments[hash.to_sym] = value if value
    end

    super
  end
end
