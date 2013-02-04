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
  
Sometimes when dealing with Asterisk AGI, a generic AGIMenu object can come in handy. Thats where the aptly named AGIMenu object comes into play. With AGIMenu, you can configure a menu of options based on a yaml configuration or a hash. For example:

  AGIMenu.sounds_dir = 'agimenu-test/sounds/'
  hash = {:introduction=>["welcome", "instructions"],
    :conclusion=>"what-is-your-choice",
    :timeout=>17,
    :choices=>
    [{:dtmf=>"*", :audio=>["to-go-back", "press", "digits/star"]},
      {:dtmf=>1, :audio=>["press", "digits/1", "for-option-1"]},
      {:dtmf=>2, :audio=>["press", "digits/2", "for-option-2"]},
      {:dtmf=>"#", :audio=>["or", "press", "digits/pound", "to-repeat"]}]}

  menu = AGIMenu.new(hash)
  menu.play(:agi => AGI.new())
  
This results in Asterisk using sounds in it's agimenu-test/sounds directory to play a menu which accepts the DTMF *, 1, 2, or #. It will first play the introduction sound files 'welcome' and 'instructions', then play the menu sound files 'to-go-back' 'press' 'digits/star' 'press' 'digits/1' 'for-option-1' 'press 'digits/2' 'for-option-2' 'or' 'press' 'digits/pound' 'to-repeat', and then play the conslusion sound file 'what-is-your-choice' and then wait 17 seconds.

You could hand AGIMenu.new() a filename, a file, a yaml oject, a hash, or nothing at all.  You can then modify the menu with the classes various methods.
=end

require 'yaml'
require 'AGI'

class AGIMenu
  @@sounds_dir = ''
  attr_accessor :title
  attr_reader :params
  def initialize(input=nil)
    @title = 'AGIMenu:' + self.object_id.to_s
    @sounds = Hash.new
    @order = []
    @introduction = []
    @conclusion = []
    @default_timeout = 600
    @params=input
    configure(input)
  end
  def add(digit, sound)
    if @order.include?(digit.to_s) then
      raise AGIMenuFailure.new("Duplicate Digit entry (#{digit.to_s}) in AGIMenu: '#{@title}'")      
    elsif digit.to_s =~ /[0-9#*]/
      @sounds[digit.to_s] = [ sound ].flatten
      @order.push(digit.to_s)
    else
      raise AGIMenuFailure.new("Invalid Digit entry (#{digit.to_s}) in AGIMenu: '#{@title}'")      
    end
  end
  def digits
    @order
  end
  alias :dtmf :digits
  alias :order :digits
  def timeout=(timeout)
    @default_timeout = timeout.to_i
  end
  def timeout
    @default_timeout
  end
  def introduction=(introduction)
    @introduction = [ introduction ].flatten
  end
  def introduction
    @introduction
  end
  def conclusion=(conclusion)
    @conclusion = [ conclusion ].flatten
  end
  def conclusion
    @conclusion
  end
  def reorder(new_order, force=false)
    new_order.collect!{ |dtmf| dtmf.to_s }
    if @order.sort != new_order.sort
      raise AGIMenuFailure.new("New and old order are incompatible in AGIMenu: '#{@title}'") unless force
    end
    @order = new_order
  end

  def play(conf={})
    defaults = {:introduction => true, :conclusion => true, :timeout => @default_timeout}
    conf = defaults.merge(conf)
    unless conf[:agi].respond_to?(:background) and conf[:agi].respond_to?(:wait_for_digit)
      raise ArgumentError, ":agi required, must be an AsteriskAGI for AGIMenu.play in AGIMenu: '#{@title}'"
    end
    digits = @order.join()
    audio = []
    case
    when conf[:introduction].class == TrueClass 
      audio << add_introduction 
    when conf[:introduction]
      audio << add_introduction(conf[:introduction])
    end
    audio << add_body
    audio << add_conclusion if conf[:conclusion]
    result = conf[:agi].background(audio.flatten, "'#{digits}'")
    return result unless result.nil?
    return result if conf[:timeout].nil?
    return handle_timeout(conf[:agi], conf[:timeout].to_i)
  end
  alias :background :play
  alias :execute :play

  def AGIMenu.sounds_dir=(dir)
    @@sounds_dir = dir
  end
  def AGIMenu.sounds_dir
    @@sounds_dir
  end
  
  private
  def handle_timeout(agi, timeout)
    begin
      start = Time.now.to_i
      result = agi.wait_for_digit(timeout*1000)
      if self.dtmf.include?(result.data.to_s)
        return result
      else
        raise AGIMenuFailure.new("Invalid DTMF Supplied #{result.data.to_s} in AGIMenu: '#{@title}'")
      end
    rescue AGITimeoutError
      return nil
    rescue AGIMenuFailure => err
      retry if timeout == -1
      elapsed = Time.now.to_i - start.to_i
      timeout = timeout - elapsed
      return nil if timeout <= 0
      retry
    end
  end

  def add_introduction(introduction=[])
    audio = []
    introduction = @introduction if introduction.empty?
    [introduction].flatten.each { |i| audio << "#{@@sounds_dir}#{i}" }
    return audio
  end
  
  def add_body
    audio = []
    @order.each do 
      |i|
      begin
        @sounds[i].each { |sound| audio << "#{@@sounds_dir}#{sound}" }
      rescue NoMethodError => err
        raise AGIMenuFailure.new("Invalid Order forced, #{i} an invalid choice in AGIMenu: '#{@title}'")
        puts "Caught #{err.class}: #{err} - #{err.message}"
      end
    end
    return audio
  end
  def add_conclusion
    audio = []
    @conclusion.flatten.each { |i| audio << "#{@@sounds_dir}#{i}" }
    return audio
  end
  def configure(input)
    if input.respond_to?(:read)
      config = YAML::load( input )
    elsif input.respond_to?(:to_hash)
      config = input
    elsif input.respond_to?(:to_s) and File.exists?(input.to_s) and File.readable?(input.to_s)
      config = File.open( input.to_s ) { |f| YAML::load( f ) }
    end
    if config.respond_to?(:to_hash)
      @params = config
      if config.has_key?(:introduction)
        @introduction = [config[:introduction]].flatten
      end
      if config.has_key?(:conclusion)
        @conclusion = [config[:conclusion]].flatten
      end
      if config.has_key?(:timeout)
        @default_timeout = config[:timeout]
      end
      if config.has_key?(:choices)
        config[:choices].each { |choice| add(choice[:dtmf], choice[:audio]) }
      end
      if config.has_key?(:title)
        @title = config[:title]
      end
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