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
  
The AGI object can be used to interact with an Asterisk. It can be used within the AGIServer framework, or independantly. Simply instantiate an AGI object and pass it input and output IO objects. Asterisk extensions can exec an agi script (in asterisk parlance, agi or deadagi), in which case you'll want to use stdin and stdout, or asterisk extensions can connect to a daemonized agi server (in asterisk parlance, fagi) and you'd want to use a tcp socket.
  
  agi = AGI.new(:input => STDIN, :output => STDOUT)
  agi.init
  agi.answer
  agi.hangup
  
Note, all agi instances will be uninitialized. The initialization process of an agi channel must be performed before any other interaction with the channel can be accomplished.
=end

#AGI is the Asterisk Gateway Interface, an interface for adding functionality to asterisk. This class implements an object that knows the AGI language and can therefore serve as a bridge between ruby and Asterisk. It can interact with any IO object it's given, so can be used in a sockets based FastAGI or a simple STDIN/STDOUT based Fork-Exec'd AGI. Please see {The Voip Info Asterisk AGI site}[http://www.voip-info.org/wiki-Asterisk+AGI] for more details.
require 'AGIExceptions.rb'
require 'AGIResponse.rb'
require 'logger'

#AGI is the Asterisk Gateway Interface, an interface for adding functionality to asterisk. This class implements an object that knows the AGI language and can therefore serve as a bridge between ruby and Asterisk. It can interact with any IO object it's given, so can be used in a sockets based FastAGI or a simple STDIN/STDOUT based Fork-Exec'd AGI. Please see {The Voip Info Asterisk AGI site}[http://www.voip-info.org/wiki-Asterisk+AGI] for more details.
class AGI
# Channel Parameters, populated by init
  attr_reader :channel_params
# Additional AGI parameters provided to new
  attr_reader :init_params
#Creates an AGI Object based on the provided Parameter Hash.
#* :input sets the IO object to use for AGI inbound communication from Asterisk, Defaults to STDIN.
#* :output sets the IO object to use for AGI outbound communication to Asterisk, Defaults to STDOUT:
#* :logger sets the Logger object to use for logging. Defaults to Logger.new(STDERR).
#
#Please note, everything else provided in the hash is available in the resulting object's init_params accessor.
  def initialize(params={})
    @input = params[:input]   || STDIN
    @output = params[:output] || STDOUT
    @logger = params[:logger] || Logger.new(STDERR)
    @init_params = params # To store other options for user
    @channel_params = {}
    @last_response  = nil
    @initialized = false
  end
  
#Causes Asterisk to answer the channel.
#
#Returns an AGIResponse object.
  def answer
    response = AGIResponse.new
    command_str = "ANSWER"
    begin      
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response
  end


#Signals Asterisk to stream the given audio file(s) to the channel. If digits are provided, allows the user to terminate the audio transmission by supplying DTMF. This differs from stream file because it does not accept an offset, and accepts an Array of sound files to play. It actually uses multiple calls to stream_file to accomplish this task.
#
#Please see stream_file for Returns, as this is a wrapper for that method
  def background(audio, digits='')
      result = nil
      if audio.class == Array then
        audio.each do |file|
          begin
            result = stream_file(file, digits)
          rescue AGITimeoutError, AGICommandError, AGIHangupError, AGIChannelError
            raise
          end          
          return result unless result.success?
          return result if result.data
        end
        return result
      elsif audio.class == String then
        begin
          result = stream_file(audio, digits)
        rescue AGITimeoutError, AGICommandError, AGIHangupError, AGIChannelError
          raise
        end
      end
    end

#Is a combination of asterisks background functionality and say_digits. It says the designated digit_string. If digits are provided, allows the user to terminate the audio transmission by supplying DTMF.  Allows an optional directory which contains digit-audio. (1.gsm, 2.gsm, ...)
#
#Please see background for returns, as this is a wrapper for that method
  def background_digits(digit_string, digits='', path='digits')
    audio = []
    digit_string.to_s.scan(/./m) { |digit| audio << "#{path}/#{digit}" }
    begin
      response = background(audio, digits)
    rescue Exception
      raise
    end
    return response
  end
  alias_method :background_say_digits, :background_digits

#Queries Asterisk for the status of the named channel. If no channel is named, defaults to the current channel.
#
#Returns an AGIResponse object with data signifying the status of the channel:
#- 0, 'DOWN, UNAVAILABLE', Channel is down and available 
#- 1, 'DOWN, RESERVED', Channel is down, but reserved 
#- 2, 'OFF HOOK', Channel is off hook 
#- 3, 'DIGITS DIALED', Digits (or equivalent) have been dialed 
#- 4, 'LINE RINGING', Line is ringing 
#- 5, 'REMOTE RINGING', Remote end is ringing 
#- 6, 'UP', Line is up 
#- 7, 'BUSY', Line is busy
  def channel_status(channel=nil)
    response = AGIResponse.new
    if channel.nil? then
      command_str = "CHANNEL STATUS"
    else
      command_str = "CHANNEL STATUS #{channel}"
    end
    begin      
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    else
      response.success = true
    end
    if response.native == 0 then
      response.data = "DOWN, AVAILABLE"
    elsif response.native == 1 then
      response.data = "DOWN, RESERVED"
    elsif response.native == 2 then
      response.data = "OFF HOOK"
    elsif response.native == 3 then
      response.data = "DIGITS DIALED"
    elsif response.native == 4 then
      response.data = "LINE RINGING"
    elsif response.native == 5 then
      response.data = "REMOTE RINGING"
    elsif response.native == 6 then
      response.data = "UP"
    elsif response.native == 7 then
      response.data = "BUSY"
    end
    return response
  end

#Signals Asterisk to stream the given audio file to the channel starting at an optional offset until either the entire file has been streamed or the user provides one of a set of DTMF digits. Unlike stream_file, this allows the user on the channel to control playback using a fast-forward key, a rewind key, and a pause key.
#
#Returns an AGIResponse including the DTMF digit provided by the channel.
  def control_stream_file(file, digits='""', skipms=3000, ffchar='*', rewchar='#', pausechar=nil)
    response = AGIResponse.new
    if pausechar.nil?
      command_str = "CONTROL STREAM FILE file digits skipms ffchar rewchar"
    else
      command_str = "CONTROL STREAM FILE file digits skipms ffchar rewchar pausechar"  
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end

#Signals Asterisk to delete the appropriate ASTDB database key/value.
#
#Returns an AGIResponse object
  def database_del(family, key)
    response = AGIResponse.new
    command_str = "DATABASE DEL #{family} #{key}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1 then
      response.success = true
    end
    return response
  end

#Signals Asterisk to delete the appropriate ASTDB database key/value family.
#
#Returns an AGIResponse object
  def database_deltree(family, keytree=nil)
    response = AGIResponse.new
    if keytree.nil? then
      command_str = "DATABASE DELTREE #{family}"
    else
      command_str = "DATABASE DELTREE #{family} #{keytree}"
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1 then
      response.success = true
    end
    return response
  end

#Signals Asterisk to return the appropriate ASTDB database key's value
#
#Returns an AGIResponse object with data including the value of the requested database key
  def database_get(family, key)
    response = AGIResponse.new
    command_str = "DATABASE GET #{family} #{key}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1 then
      response.success = true
      response.data = parse_response
    end
    return response
  end

#Signals Asterisk to insert the given value into the ASTDB database
#
#Returns an AGIResponse
  def database_put(family, key, value)
    response = AGIResponse.new
    command_str = "DATABASE PUT #{family} #{key} #{value}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end    
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1 then
      response.success = true
    end
    return response
  end
  
#Signals Asterisk to execute the given Asterisk Application by sending the command "EXEC" to Asterisk using the AGI
#
#Returns an AGIResponse.
#
#Please note, the success? method to this AGIResponse indicates success of the EXEC command, not the underlying Asterisk Application. If Asterisk provides data in it's standard format, it will be included as data in the AGIResponse object. If it does not, the native asterisk response will be.
  def exec(string)
    response = AGIResponse.new
    command_str = "EXEC #{string}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -2 then
      raise AGICommandError.new(@last_response, "Application Not Found in (#{command_str})")
    elsif response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    else
      response.success = true
      response.data = parse_response
      response.data ||= response.native
    end
    return response
  end
  
#Signals Asterisk to collect DTMF digits from the channel while playing an audio file. Optionally accepts a timeout option (in seconds) and a maximum number of digits to collect.
#
#Returns an AGIResponse with data available which denotes the DTMF digits provided by the channel.
  def get_data(file, timeout=nil, max_digits=nil)
    response = AGIResponse.new
    if timeout.nil? then
      command_str = "GET DATA #{file}"
    elsif max_digits.nil? then
      command_str = "GET DATA #{file} #{(timeout.to_i * 1000)}"
    else
      command_str = "GET DATA #{file} #{(timeout.to_i * 1000)} #{max_digits}"
    end
    begin      
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response,"Channel Failure in #{command_str}")
    else
      response.success = true
      response.data = response.native
    end
    return response
  end

#Signals Asterisk to return the contents of the requested (complex) channel variable
#
#Returns an AGIResponse with the variable's value
  def get_full_variable(variablename, channel=nil)
    response = AGIResponse.new
    if channel.nil?
      command_str = "GET FULL VARIABLE #{variablename}"
    else
      command_str = "GET FULL VARIABLE #{variablename} #{channel}"
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1
      response.success = true
      response.data = parse_response
    end
    return response
  end

#Signals Asterisk to stream the given audio file to the channel starting at an optional offset until either the entire file has been streamed or the user provides one of a set of DTMF digits. Unlike stream_file, this accepts a timeout option.
#
#Returns an AGIResponse including the DTMF digit provided by the channel.
  def get_option(file, digits='""', timeout=0)
    response = AGIResponse.new
    command_str = "GET OPTION #{file} #{digits} #{(timeout.to_i * 1000)}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end


#Signals Asterisk to return the contents of the requested channel variable
#
#Returns an AGIResponse with the variable's value
  def get_variable(variablename)
    response = AGIResponse.new
    command_str = "GET VARIABLE #{variablename}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1
      response.success = true
      response.data = parse_response
    end
    return response
  end

#Signals Asterisk to hangup the requested channel. If no channel is provided, defaults to the current channel.
#
#Returns an AGIResponse. 
  def hangup(channel=nil)
    response = AGIResponse.new
    if channel.nil? then
      command_str = "HANGUP"
    else
      command_str = "HANGUP #{channel}"
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1
      response.success = true
    end
    return response
  end
  
#Initializes the channel by getting all variables provided by Asterisk as it initiates the connection. These values are then stored in the instance variable @channel_params, a Hash object. While initializing the channel, the IO object(s) provided to new as :input and :output are set to operate synchronously.
#
#Note, a channel can only be initialized once. If the AGI is being initialized a second time, this will throw an AGIInitializeError. If this is desired functionality, please see the reinit method.
  def init
    if @initialized
      raise AGIInitializeError.new(nil, "Tried to init previously initialized channel. If this is desired, use reinit()")      
    end
    begin
      @input.sync = true
      @output.sync = true
      while( line = @input.gets.chomp )
        if line =~ %r{^\s*$} then
          break
        elsif line =~ %r{^agi_(\w+)\:\s+(.+)$} then
          if @channel_params.has_key?($1) then
            @logger.warn{"AGI Got Duplicate Channel Parameter for #{$1} (was \"#{@channel_params[$1]}\" reset to \"#{$2})\""}
          end
          @channel_params[$1] = $2          
          @logger.debug{"AGI Got Channel Parameter #{$1} = #{$2}"}
        end
      end
    rescue NoMethodError => error
      if error.to_s =~ %r{chomp} then
        raise AGIHangupError.new(nil, "Channel Hungup during init")
      else
        raise
      end
    end
    @initialized = true
  end  
  
#Signals Asterisk to ... do nothing
#
#Returns an AGIResponse. (just in case you want to make sure asterisk successfully didnt do anything. Don't ask me, I just implement them)
  def noop(string=nil)
    response = AGIResponse.new
    if string.nil? then
      command_str = "NOOP"
    else
      command_str = "NOOP #{string}"
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    else
      response.success = true
    end
    return response
  end

#Signals Asterisk to query the channel to request a single text character from the channel
#
#Returns an AGIResponse including the character received.
  def receive_char(timeout=0)
    response = AGIResponse.new
    command_str = "RECEIVE CHAR #{(timeout.to_i * 1000)}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      raise AGICommandError.new(@last_response, "Channel doesn't support TEXT in (#{command_str})")
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end

#Signals Asterisk to query the channel to provide audio data to record into a file. Asterisk will record until certain digits are provided as DTMF, or the operation times out, or silence is detected for a second timeout. Can optionally cause asterisk to send a beep to the channel to signal the user the intention of recording sound. By default, there is no timeout,no silence detection, and no beep.
#
#Returns an AGIResponse. 
  def record_file(filename, format, digits, timeout=-1, beep=false, silence=nil)
    beep_str = ''
    if ( beep == true ) then
      beep_str = "BEEP"
    end
    silence_str = ''
    unless silence.nil?
      silence_str = "s=#{silence}"
    end
    response = AGIResponse.new
    command_str = "RECORD FILE #{filename} #{format} #{digits} #{(timeout.to_i * 1000)} #{beep_str} #{silence_str}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native > 0
      response.success = true
      response.data = response.native.chr
    else
      response.success = true
    end
    return response
  end
  
  
#Initializes the channel by getting all variables provided by Asterisk as it initiates the connection. These values are then stored in the instance variable @channel_params, a Hash object. While initializing the channel, the IO object(s) provided to new as :input and :output are set to operate synchronously.
#
#Note, unlike the init method, this can be called on an AGI object multiple times. Realize, however, that each time you do, the channel will have to provide a set of initialization data, and all previously stored channel parameters will be forgotten.
  def reinit
    @initialized = false
    @channel_params = {}
    @last_response  = nil
    init    
  end
 
#Signals Asterisk to announce the string provided as a series of characters If digits are provided as well, will allow the user to terminate the announcement if one of the digits are provided by DTMF.
#
#Returns an AGIResponse including the DTMF digit provided by the channel.
  def say_alpha(string, digits='""')
    response = AGIResponse.new
    command_str = "SAY ALPHA '#{string}' #{digits}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end
 
#Signals Asterisk to announce the given date. If digits are provided as well, will allow the user to terminate the announcement if one of the digits are provided by DTMF. Can accept either a Time object or an integer designation of the number of seconds since 00:00:00 January 1, 1970, Coordinated Universal Time (UTC). Defaults to now.
#
#Returns an AGIResponse including the DTMF digit provided by the channel, if any are.
  def say_date(time=Time.now, digits='""')
    response = AGIResponse.new
    command_str = "SAY DATE #{time.to_i} #{digits}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end

#Signals Asterisk to announce the given date and time. If digits are provided as well, will allow the user to terminate the announcement if one of the digits are provided by DTMF. Can accept either a Time object or an integer designation of the number of seconds since 00:00:00 January 1, 1970, Coordinated Universal Time (UTC). Defaults to now.
#
#Returns an AGIResponse including the DTMF digit provided by the channel, if any are.
  def say_datetime(time=Time.now, digits='""', format="ABdY", timezone=nil)
    response = AGIResponse.new
    if timezone.nil?
      command_str = "SAY DATETIME #{time.to_i} #{digits} #{format}"
    else
      command_str = "SAY DATETIME #{time.to_i} #{digits} #{format} #{timezone}"
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end

#Signals Asterisk to announce the number provided as a series of digits. If digits are provided as well, will allow the user to terminate the announcement if one of the digits are provided by DTMF.
#
#Returns an AGIResponse including the DTMF digit provided by the channel.
  def say_digits(number, digits='""')
    response = AGIResponse.new
    command_str = "SAY DIGITS #{number} #{digits}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end

#Signals Asterisk to announce the number provided as a single number. If digits are provided as well, will allow the user to terminate the announcement if one of the digits are provided by DTMF.
#
#Returns an AGIResponse including the DTMF digit provided by the channel.
  def say_number(number, digits='""')
    response = AGIResponse.new
    command_str = "SAY NUMBER #{number} #{digits}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end
  
#Signals Asterisk to announce the string provided as a series of characters. If digits are provided as well, will allow the user to terminate the announcement if one of the digits are provided by DTMF.
#
#Returns an AGIResponse including the DTMF digit provided by the channel.
  def say_phonetic(string, digits='""')
    response = AGIResponse.new
    command_str = "SAY PHONETIC '#{string}' #{digits}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end

#Signals Asterisk to announce the given time. If digits are provided as well, will allow the user to terminate the announcement if one of the digits are provided by DTMF. Can accept either a Time object or an integer designation of the number of seconds since 00:00:00 January 1, 1970, Coordinated Universal Time (UTC). Defaults to now.
#
#Returns an AGIResponse including the DTMF digit provided by the channel, if any are.
  def say_time(time=Time.now, digits='""')
    response = AGIResponse.new
    command_str = "SAY TIME #{time.to_i} #{digits}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end
  
#Signals Asterisk to transfer an image across the channel.
#
#Returns an AGIResponse. 
#
#Please note, at present Asterisk returns the same value to the AGI if the image is sent and if the channel does not support image transmission. The AGIResponse, therefore, reflects the same. AGIResponse.success? will be true for both successful transmission and for channel-doesn't support.
  def send_image(image)
    response = AGIResponse.new
    command_str = "SEND IMAGE #{image}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response
  end

#Signals Asterisk to transfer text across the channel.
#
#Returns an AGIResponse. 
#
#Please note, at present Asterisk returns the same value to the AGI if the text is sent and if the channel does not support text transmission. The AGIResponse, therefore, reflects the same. AGIResponse.success? will be true for both successful transmission and for channel-doesn't support.
  def send_text(text)
    response = AGIResponse.new
    command_str = "SEND TEXT '#{text}'"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response
  end

#Signals Asterisk to hangup the channel after a given amount of time has elapsed.
#
#Returns an AGIResponse.
  def set_autohangup(time)
    response = AGIResponse.new
    command_str = "SET AUTOHANGUP #{time}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response
  end
  
#Signals Asterisk to set the callerid on the channel.
#
#Returns an AGIResponse.
  def set_callerid(callerid)
    response = AGIResponse.new
    command_str = "SET CALLERID #{callerid}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1
      response.success = true
    end
    return response
  end
  
#Signals Asterisk to set the context for the channel upon AGI completion.
#
#Returns an AGIResponse.
  def set_context(context)
    response = AGIResponse.new
    command_str = "SET CONTEXT #{context}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response    
  end
  
#Signals Asterisk to set the extension for the channel upon AGI completion.
#
#Returns an AGIResponse.
  def set_extension(extension)
    response = AGIResponse.new
    command_str = "SET EXTENSION #{extension}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response    
  end

#Signals Asterisk to enable or disable music-on-hold for the channel. If music_class is provided, it will select music from the apropriate music class, if it is not provided, asterisk will use music from the default class. The toggle option can either be 'on' or 'off'.
#
#Returns an AGIResponse.
  def set_music(toggle, music_class=nil)
    unless ( toggle == 'on' || toggle == 'off')
      raise ArgumentError, "Argument 1 must be 'on' or 'off' to set music"
    end
    response = AGIResponse.new
    if music_class.nil? then
      command_str = "SET MUSIC #{toggle}"
    else
      command_str = "SET MUSIC #{toggle} #{music_class}"
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response    
  end
  
#Signals Asterisk to set the priority for the channel upon AGI completion.
#
#Returns an AGIResponse.
  def set_priority(priority)
    response = AGIResponse.new
    command_str = "SET PRIORITY #{priority}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    end
    return response    
  end

#Signals Asterisk to set the contents of the requested channel variable.
#
#Returns an AGIResponse
  def set_variable(variable, value)
    response = AGIResponse.new
    command_str = "SET VARIABLE #{variable} #{value}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1
      response.success = true
    end
    return response
  end
  
#Signals Asterisk to stream the given audio file to the channel starting at an optional offset until either the entire file has been streamed or the user provides one of a set of DTMF digits.
#
#Returns an AGIResponse including the DTMF digit provided by the channel.
  def stream_file(file, digits='', offset=nil)
    digits.gsub!(/['"]/, '')
    response = AGIResponse.new
    if offset.nil? then
      command_str = "STREAM FILE #{file} '#{digits}'"
    else
      command_Str = "STREAM FILE #{file} ''#{digits}' #{offset}"
    end
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end

#Signals Asterisk to enable or disable tdd mode for the channel
#
#Returns an AGIResponse.
  def tdd_mode(toggle)
    unless ( toggle == 'on' || toggle == 'off')
      raise ArgumentError, "Argument 1 must be 'on' or 'off' to set tdd mode"
    end
    command_str = "TDD MODE #{toggle}"
    response = AGIResponse.new
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      raise AGIChannelError.new(@last_response, "Channel is not TDD-Capable")
    elsif response.native == 1
      response.success = true
    end
    return response
  end  
  
#Signals Asterisk to log the given message using the given log level to asterisk's verbose log.
#
#Returns an AGIResponse.
  def verbose(message, level)
    response = AGIResponse.new
    command_str = "VERBOSE #{message} #{level}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 1
      response.success = true
    end
    return response
  end
  
#Signals Asterisk to collect a single DTMF digit from the channel while waiting for an optional timeout.
#
#Returns an AGIResponse with data available which denotes the DTMF digits provided by the channel.
  def wait_for_digit(timeout=-1)
    response = AGIResponse.new
    command_str = "WAIT FOR DIGIT #{timeout}"
    begin
      response.native = execute(command_str)
    rescue AGITimeoutError, AGICommandError, AGIHangupError
      raise
    end
    if response.native == -1 then
      raise AGIChannelError.new(@last_response, "Channel Failure in (#{command_str})")
    elsif response.native == 0
      response.success = true
    else
      response.success = true
      response.data = response.native.chr
    end
    return response
  end
  
  private
  def execute(command_str)
    @last_response = nil
    _execcommand(command_str)
    begin
      result = _readresponse()
      response = _checkresult(result)
    rescue AGIHangupError => error
      @logger.warn{"Received AGI Hangup Error in command (#{command_str}): #{error.to_s}"}
      raise
    rescue AGICommandError => error      
      @logger.warn{"Received AGI Command Error in command (#{command_str}): #{error.to_s}"}
      raise
    rescue AGITimeoutError => error
      @logger.warn{"Received AGI Timeout Error in command (#{command_str}): #{error.to_s}"}
      raise
    else
      return response
    end
  end
  
  def _execcommand(command_str)
    # returns nothing, merely sends a command string to asterisk
    @logger.debug{"AGI Sent to Asterisk: #{command_str}"}
    @output.print("#{command_str}\n")
    return nil
  end
  
  def _readresponse
    # returns the data returned by asterisk
    begin
      response = @input.gets.chomp
    rescue NoMethodError
      # NoMethodError here implies chomp called on nil result of gets, 
      # reraise as Hangup
      raise AGIHangupError.new(nil, "Channel Hungup during command execution")
    rescue Errno::ECONNRESET
      raise AGIHangupError.new(nil, "Channel Hungup during command execution")
    else
      @logger.debug{"AGI Received from Asterisk: #{response}"}
    end
    return response
  end
  
  def _checkresult(response)
    # returns what will be interpreted as asterisks native response
    if response.nil? then
      return false
    end
    @last_response = response.chomp
    if ( response =~ %r{^200} && response =~ %r{result=(0[\d*#]+)}i ) then
      return $1.to_s
    elsif ( response =~ %r{^200} && response =~ %r{result=(-?[\d*#]+)}i ) then
      return $1.to_i
    elsif ( response =~ %r{^200} && response =~ %r{\(timeout\)} ) then
      raise AGITimeoutError.new(@last_response, "Timed out waiting for response from User")
    else
      raise AGICommandError.new(@last_response, "Invalid or nil response from Asterisk: \"#{response}\"")
    end
  end
  
  def parse_response
    if @last_response =~ %r{\((.*)\)} then
      return $1
    else
      return nil
    end
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