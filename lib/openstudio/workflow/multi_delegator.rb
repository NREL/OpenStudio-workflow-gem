# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'logger'

class Logger
  def format_message(severity, datetime, _progname, msg)
    format("[%s %s] %s\n", datetime.strftime('%H:%M:%S.%6N'), severity, msg)
  end
end

# Class to allow multiple logging paths
class MultiDelegator
  def initialize(*targets)
    @targets = targets
  end

  def self.delegate(*methods)
    methods.each do |m|
      define_method(m) do |*args|
        @targets.map { |t| t.send(m, *args) }
      end
    end
    self
  end

  class <<self
    alias to new
  end
end
