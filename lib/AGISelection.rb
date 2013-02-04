=begin rdoc
  Copyright (c) 2007, Vonage Holdings

  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

        * Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
        * Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
        * Neither the name of Vonage Holdings nor the names of its       
  contributors may be used to endorse or promote products derived from this
  software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.

  Author: Michael Komitee <mkomitee@gmail.com>

AGISelection can be used to get a string of digits from an asterisk channel. You configure it similarly to an AGIMenu, but it takes a max_digits paramater and only accepts a single audio file. AGIMenu only accepts a single dtmf digit, whereas AGISelection can accept multiple digits. It would be used to have a user input a PIN or a telephone number or something similar.

  agi = AGI.new()
  yaml_hash = {:audio => 'tt-monkeys', :max_digits => 4}
  foo = AGISelection.new(yaml_hash)
  foo.read(:agi => AGI.new())

=end

#AGISelection implements the AGI function get_data via an externally configurable YAML file
require 'yaml'
require 'AGI'
#AGISelection implements the AGI function get_data via an externally configurable YAML file
class AGISelection
  @@sounds_dir = nil
# :audio The name of the file that you wish to play
  attr_accessor :audio 
  attr_reader :params
#Creates an AGISelection Object based on the provided YAML Hash.
#* :audio The name of the file that you wish to play
#* :default_timeout set to 600 seconds. This can be overridden by passing a :timeout paramerter in your YAML hash
#* :max_digits no maximum (nil) by default
  def initialize(input=nil)
    @audio = nil
    @default_timeout = 600
    @max_digits = nil
    @params = input
    configure(input)
  end

#Configure all the basic variables that AGISelection needs
#* :audio The name of the file that you wish to play
#* :default_timeout set to 600 seconds. This can be overridden by passing a :timeout paramerter in your YAML hash
#* :max_digits no maximum (nil) by default
  def configure(input)
    if input.respond_to?('read')
      config = YAML::load(input)
    elsif input.respond_to?(:to_hash)
      config = input
      elsif input.respond_to?(:to_s) and File.exists?(input.to_s) and File.readable?(input.to_s)
      config = File.open( input.to_s ) { |f| YAML::load( f ) }
    end
    if config.respond_to?(:to_hash)
      @params = config
      @audio = config[:audio]
      @default_timeout = config[:timeout] || @default_timeout
      @max_digits = config[:max_digits] || @max_digits
    end
  end
  
#Read returns the result of executing agi.get_data()
#You must pass an AGI object as a parameter in your YAML hash
#For example:
# require 'AGI'
# require 'AGISelection'
#
# agi = AGI.new({})
# # Initialize the AGI or bad things will happen
# agi.init()
# yaml_hash = {:audio => 'tt-monkeys', :max_digits => 4}
# foo = AGISelection.new(yaml_hash)
# # Override the Audio file from the YAML hash
# foo.audio = 'somethingelse'
# foo.read(:agi => agi)
  def read(conf={:timeout => @default_timeout, :max_digits => @max_digits})
    if !conf[:agi].respond_to?(:get_data)
      raise ArgumentError, "agi required, must be an AsteriskAGI"
    elsif @audio.nil?
      raise ArgumentError, "You must supply an audio file"
    end
    conf[:timeout] = @default_timeout unless conf.has_key?(:timeout)
    conf[:max_digits] = @max_digits unless conf.has_key?(:max_digits)
    agi = conf[:agi]
    if @@sounds_dir then
      audio = @@sounds_dir + '/' + @audio
    else
      audio = @audio
    end
    begin
      result = agi.get_data(audio, conf[:timeout], conf[:max_digits])
    rescue AGITimeoutError
      nil
    end
  end
  
  alias :execute :read
  alias :get :read
  alias :get_data :read
  
  def AGISelection.sounds_dir=(sounds_dir)
    @@sounds_dir = sounds_dir
  end
end


=begin
  Copyright (c) 2007, Vonage Holdings

  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

        * Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
        * Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
        * Neither the name of Vonage Holdings nor the names of its       
  contributors may be used to endorse or promote products derived from this
  software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
=end