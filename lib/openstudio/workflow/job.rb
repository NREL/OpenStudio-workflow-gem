module OpenStudio
  module Workflow
    class Job
      def initialize(directory, time_logger, adapter, workflow_arguments, options = {})
        defaults ||= {}
        @options = defaults.merge(options)
        @directory = directory
        @adapter = adapter
        @logger = logger
        @time_logger = time_logger
        @workflow_arguments = workflow_arguments
        @results = {}

        logger.info "#{self.class} passed the following options #{@options}"
      end
    end

    def self.new_class(current_state, directory, logger, time_logger, adapter, workflow_arguments, options = {})
      new_job = Object.const_get(current_state).new(directory, logger, time_logger, adapter, workflow_arguments, options)
      return new_job
    end
  end
end
