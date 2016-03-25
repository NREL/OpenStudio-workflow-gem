module OpenStudio
  module Workflow
    class Job
      def initialize(adapter, registry, options = {})
        defaults ||= {debug: false}
        @options = defaults.merge(options)
        @adapter = adapter
        @registry = registry
        @results = {}

        logger.info "#{self.class} passed the following options #{@options}"
        logger.info "#{self.class} passed the following registry #{@registry.to_hash}" if @options[:debug]
      end
    end

    def self.new_class(current_state, adapter, registry, options = {})
      new_job = Object.const_get(current_state).new(adapter, registry, options)
      return new_job
    end
  end
end
