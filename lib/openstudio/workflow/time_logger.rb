# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# Class to store run times in a useful structure. Data are stored in a hash based on a the channel name
# There is no concept of multi-levels. The onus is on the user to make sure that they don't add a value to the
# logger that may be a level.
class TimeLogger
  attr_reader :channels

  def initialize
    @logger = []
    @channels = {}
  end

  # name of the moniker that you are tracking. If the name is already in use, then it restarts the timer.
  def start(channel)
    # warning -- "will reset timer for #{moniker}" if @monikers.key? moniker
    s = ::Time.now
    @channels[channel] = { start_time_str: s.to_s, start_time: s.to_f }
  end

  def stop(channel)
    end_time = ::Time.now.to_f
    @logger << {
      channel: channel,
      start_time: @channels[channel][:start_time],
      start_time_str: @channels[channel][:start_time_str],
      end_time: end_time,
      delta: end_time - @channels[channel][:start_time]
    }

    # remove the channel
    @channels.delete(channel) if @channels.key? channel
  end

  def stop_all
    @channels.each_key do |channel|
      stop(channel)
    end
  end

  # return the entire report
  def report
    @logger
  end

  # this will report all the values for all the channels with this name.
  def delta(channel)
    @logger.map { |k| { channel.to_s => k[:delta] } if k[:channel] == channel }.compact
  end

  # save the data to a file. This will overwrite the file if it already exists
  def save(filename)
    File.open(filename, 'w') do |f| 
      f << JSON.pretty_generate(@logger)
      # make sure data is written to the disk one way or the other
      begin
        f.fsync
      rescue
        f.flush
      end
    end
  end
end
