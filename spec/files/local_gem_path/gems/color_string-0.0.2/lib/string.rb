# frozen_string_literal: true

require 'color_string/colorize'

class String
  def color
    ColorString::Colorize.new(self).color
  end
end
