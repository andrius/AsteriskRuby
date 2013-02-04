#!/usr/local/bin/ruby -wKU -I ../../lib
## Copyright (c) 2007, Vonage Holdings
##
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
##      * Redistributions of source code must retain the above copyright
## notice, this list of conditions and the following disclaimer.
##      * Redistributions in binary form must reproduce the above copyright
## notice, this list of conditions and the following disclaimer in the
## documentation and/or other materials provided with the distribution.
##      * Neither the name of Vonage Holdings nor the names of its       
## contributors may be used to endorse or promote products derived from this
## software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
## LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##
## Author: Michael Komitee


require 'test/unit'
require 'stringio'
require 'AGI'

class TestAGI < Test::Unit::TestCase

  def test_response
    agi = get_dummy_agi(['200 result=012345','200 result=0','200 result=12345','200 result=1 (hello)'])
    lzresponse = agi.get_data('audiofile')
    oresponse = agi.get_data('audiofile')
    iresponse = agi.get_data('audiofile')
    sresponse = agi.get_variable('foo')
    assert_equal('012345', lzresponse)
    assert_equal(0, oresponse)
    assert_equal(12345, iresponse.to_i)
    assert_equal('hello', sresponse.to_str)
    assert(sresponse =~ /el/)
    assert_nil(sresponse =~ 12)
    assert(!sresponse.nil?)
    assert_equal(12346, iresponse + 1)
    assert_equal(12344, iresponse - 1)
    assert_equal(0, iresponse * 0)
    assert_raise(ZeroDivisionError) { iresponse / 0 }
    assert_equal(12345**2, iresponse **2 )
    assert_equal(12345%2, iresponse%2)
  end
  def test_timeout
    agi = get_dummy_agi(['200 result=(timeout)'])
    assert_raise(AGITimeoutError) { agi.stream_file('myfile') }
  end
  def test_init
    agi = get_dummy_agi
    params = agi.channel_params
    assert_equal('agi://localhost:4573/sample/1/?foo=bar', agi.channel_params['request'])
    assert_equal('en', agi.channel_params['language'])
    assert_equal('"SIPPhone" <1234>', agi.channel_params['callerid'])
    assert_equal('ruby-agi', agi.channel_params['context'])
    assert_equal('s', agi.channel_params['extension'])
    assert_equal('2', agi.channel_params['priority'])
    assert_equal('agi://localhost:4573/sample/1/?foo=bar', params['request'])
    assert_equal('en', params['language'])
    assert_equal('"SIPPhone" <1234>', params['callerid'])
    assert_equal('ruby-agi', params['context'])
    assert_equal('s', params['extension'])
    assert_equal('2', params['priority'])
    assert_raise(AGIInitializeError) { agi.init }
  end
  
  def test_reinit
    agi_h = get_dummy_agi
    agi_g = get_dummy_agi(["agi_network: yes",""])
    params = agi_g.channel_params
    assert_equal('agi://localhost:4573/sample/1/?foo=bar', agi_g.channel_params['request'])
    agi_g.reinit
    assert_raise(AGIHangupError) { agi_h.reinit }
    assert_equal('yes', agi_g.channel_params['network'])
    assert_nil(agi_g.channel_params['request'])
  end
  def test_answer
    agi_h = get_dummy_agi    
    agi_s = get_dummy_agi(["200 result=0"])
    agi_f = get_dummy_agi(["200 result=1"])
    agi_c = get_dummy_agi(["200 result=-1"])
    response_s = agi_s.answer
    response_f = agi_f.answer
    assert_raise(AGIHangupError) { agi_h.answer }
    assert_equal(0, response_s.native)
    assert_equal(1, response_f.native)
    assert(response_s.success?)
    assert(! response_f.success?)
    assert_raise(AGIChannelError) { agi_c.answer }
  end

  def test_say_datetime
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.say_datetime(Time.now, '#') }
    assert_raise(AGIChannelError) { agi_f.say_datetime(Time.now, '#') }
    assert(agi_s.say_datetime(Time.now, '#').success?)
    assert_equal('#', agi_d.say_datetime(Time.now, '#'))
  end

  def test_say_date
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.say_date(Time.now, '#') }
    assert_raise(AGIChannelError) { agi_f.say_date(Time.now, '#') }
    assert(agi_s.say_date(Time.now, '#').success?)
    assert_equal('#', agi_d.say_date(Time.now, '#'))
  end

  def test_say_time
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.say_time(Time.now, '#') }
    assert_raise(AGIChannelError) { agi_f.say_time(Time.now, '#') }
    assert(agi_s.say_time(Time.now, '#').success?)
    assert_equal('#', agi_d.say_time(Time.now, '#'))
  end


  def test_say_alpha
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.say_alpha("hi", '#') }
    assert_raise(AGIChannelError) { agi_f.say_alpha("hi", '#') }
    assert(agi_s.say_alpha("hi", '#').success?)
    assert_equal('#', agi_d.say_alpha("hi", '#'))
  end

  def test_say_phonetic
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.say_phonetic("hi", '#') }
    assert_raise(AGIChannelError) { agi_f.say_phonetic("hi", '#') }
    assert(agi_s.say_phonetic("hi", '#').success?)
    assert_equal('#', agi_d.say_phonetic("hi", '#'))
  end

  def test_say_digits
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.say_digits(12345, '#') }
    assert_raise(AGIChannelError) { agi_f.say_digits(12345, '#') }
    assert(agi_s.say_digits(12345, '#').success?)
    assert_equal('#', agi_d.say_digits(12345, '#'))
  end

  def test_say_number
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.say_number(12345, '#') }    
    assert_raise(AGIChannelError) { agi_f.say_number(12345, '#') }
    assert(agi_s.say_number(12345, '#').success?)
    assert_equal('#', agi_d.say_number(12345, '#'))
  end

  def test_receive_char
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.receive_char() }    
    assert_raise(AGIChannelError) { agi_f.receive_char() }
    assert_raise(AGICommandError) { agi_s.receive_char() }
    assert_equal('#', agi_d.receive_char())
  end
  def test_record_file
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.record_file("myfile", "gsm", "#") }    
    assert_raise(AGIChannelError) { agi_f.record_file("myfile", "gsm", "#") }
    assert(agi_s.record_file("myfile", "gsm", "#").success?)
    assert_equal('#', agi_d.record_file("myfile", "gsm", "#"))
  end
  
  def test_stream_file
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.stream_file(["myfile1",'myfile2'], "#") }    
    assert_raise(AGIChannelError) { agi_f.stream_file(["myfile1",'myfile2'], "#") }
    assert(agi_s.stream_file(["myfile1",'myfile2'], "#").success?)
    assert_equal('#', agi_d.stream_file(["myfile1",'myfile2'], "#"))
  end
  
  def test_get_option
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.get_option("myfile", "#") }    
    assert_raise(AGIChannelError) { agi_f.get_option("myfile", "#") }
    assert(agi_s.get_option("myfile", "#").success?)
    assert_equal('#', agi_d.get_option("myfile", "#"))
  end
  
  def test_wait_for_digit
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    assert_raise(AGIHangupError) { agi_h.wait_for_digit() }    
    assert_raise(AGIChannelError) { agi_f.wait_for_digit() }
    assert(agi_s.wait_for_digit().success?)
    assert_equal('#', agi_d.wait_for_digit())
  end
  
  def test_control_stream_file
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=48"])
    assert_raise(AGIHangupError) { agi_h.control_stream_file("myfile", "#") }    
    assert_raise(AGIChannelError) { agi_f.control_stream_file("myfile", "#") }
    assert(agi_s.control_stream_file("myfile", "#").success?)
    assert_equal('0', agi_d.control_stream_file("myfile", "0", 3000, '*', '#', '5'))
  end

  def test_get_variable
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_n = get_dummy_agi(["200 result=0"])
    agi_s = get_dummy_agi(["200 result=1 (variablevalue)"])
    assert_raise(AGIHangupError) { agi_h.get_variable('VARIABLENAME') }    
    assert_raise(AGIChannelError) { agi_f.get_variable('VARIABLENAME') }
    assert(! agi_n.get_variable('VARIABLENAME').success?)
    assert_equal('variablevalue', agi_s.get_variable('VARIABLENAME'))
  end

  def test_get_full_variable
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_n = get_dummy_agi(["200 result=0"])
    agi_s = get_dummy_agi(["200 result=1 (variablevalue)"])
    assert_raise(AGIHangupError) { agi_h.get_full_variable('VARIABLENAME') }    
    assert_raise(AGIChannelError) { agi_f.get_full_variable('VARIABLENAME') }
    assert(! agi_n.get_full_variable('VARIABLENAME').success?)
    assert_equal('variablevalue', agi_s.get_full_variable('VARIABLENAME'))
  end

  def test_database_get
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_n = get_dummy_agi(["200 result=0"])
    agi_s = get_dummy_agi(["200 result=1 (dbvarvalue)"])
    assert_raise(AGIHangupError) { agi_h.database_get('family', 'key') }    
    assert_raise(AGIChannelError) { agi_f.database_get('family', 'key') }
    assert(! agi_n.database_get('family', 'key').success?)
    assert_equal('dbvarvalue', agi_s.database_get('family', 'key'))
  end

  def test_channel_status
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0", "200 result=1", "200 result=2", "200 result=3",
                            "200 result=4", "200 result=5", "200 result=6", "200 result=7"])
    assert_raise(AGIHangupError) { agi_h.channel_status }
    assert_raise(AGIChannelError) { agi_f.channel_status }
    assert_equal("DOWN, AVAILABLE", agi_s.channel_status)
    assert_equal("DOWN, RESERVED", agi_s.channel_status)
    assert_equal("OFF HOOK", agi_s.channel_status)
    assert_equal("DIGITS DIALED", agi_s.channel_status)
    assert_equal("LINE RINGING", agi_s.channel_status)
    assert_equal("REMOTE RINGING", agi_s.channel_status)
    assert_equal("UP", agi_s.channel_status)
    assert_equal("BUSY", agi_s.channel_status("foo"))    
  end
  
  def test_database_del
    agi = get_dummy_agi(["200 result=0", "200 result=1", "200 result=-1"])
    assert(! agi.database_del('family', 'key').success?)
    assert(agi.database_del('family', 'key').success?)
    assert_raise(AGIChannelError) { agi.database_del('family', 'key') }
    assert_raise(AGIHangupError) { agi.database_del('family', 'key') }
  end

  def test_database_deltree
    agi = get_dummy_agi(["200 result=0", "200 result=1", "200 result=-1"])
    assert(! agi.database_deltree('family', 'key').success?)
    assert(agi.database_deltree('family', 'key').success?)
    assert_raise(AGIChannelError) { agi.database_deltree('family', 'key') }
    assert_raise(AGIHangupError) { agi.database_deltree('family') }
  end

  def test_database_put
    agi = get_dummy_agi(["200 result=0", "200 result=1", "200 result=-1"])
    assert(! agi.database_put('family', 'key','value').success?)
    assert(agi.database_put('family', 'key','value').success?)
    assert_raise(AGIChannelError) { agi.database_put('family', 'key','value') }
    assert_raise(AGIHangupError) { agi.database_put('family', 'key','value') }
  end

  def test_noop
    agi = get_dummy_agi(["200 result=0", "200 result=1", "200 result=-1","200 result=1"])
    assert(agi.noop().success?) 
    assert(agi.noop().success?)
    assert_raise(AGIChannelError) { agi.noop() }
    assert(agi.noop("test").success?)
    assert_raise(AGIHangupError) { agi.noop() }
  end
  
  def test_exec
    agi = get_dummy_agi(["200 result=1", "200 result=1 (foo)", "200 result=83", "200 result=-1", "200 result=-2", "500 Invalid Command"])
    assert(agi.exec("testing testing 123...").success?)
    assert_equal('foo', agi.exec("testing testing 123..."))
    assert_equal(83, agi.exec("testing testing 123..."))
    assert_raise(AGIChannelError) { agi.exec("testing testing 123...") }
    assert_raise(AGICommandError) { agi.exec("testing testing 123...") }
    assert_raise(AGICommandError) { agi.exec("testing testing 123...") }
    assert_raise(AGIHangupError) { agi.exec("testing testing 123...") }
  end

  def test_get_data
    agi = get_dummy_agi(["200 result=123456", "200 result=-1", "200 result=123456", "200 result=12", "200 result=0123"])
    assert_equal(123456, agi.get_data("testaudio"))
    assert_raise(AGIChannelError) { agi.get_data("testaudio") }
    assert_equal(123456, agi.get_data("testaudio", 10))
    assert_equal(12, agi.get_data("testaudio", 10, 2))
#    assert_equal('0123', agi.get_data("testaudio").to_s)    
#    assert_raise(AGIHangupError) { agi.get_data("testaudio") }
  end
  
  def test_hangup
    agi = get_dummy_agi(["200 result=0", "200 result=1", "200 result=-1"])
    assert(! agi.hangup().success?)
    assert(agi.hangup().success?)
    assert_raise(AGIChannelError) { agi.hangup() }
    assert_raise(AGIHangupError) { agi.hangup() }
  end

  def test_send_image
    agi = get_dummy_agi(["200 result=0", "200 result=-1"])
    assert(agi.send_image('testimage').success?)
    assert_raise(AGIChannelError) { agi.send_image('testimage') }
    assert_raise(AGIHangupError) { agi.send_image('testimage') }
  end

  def test_send_text
    agi = get_dummy_agi(["200 result=0", "200 result=-1"])
    assert(agi.send_text('testtext').success?)
    assert_raise(AGIChannelError) { agi.send_text('testtext') }
    assert_raise(AGIHangupError) { agi.send_text('testtext') }
  end

  def test_set_autohangup
    agi = get_dummy_agi(["200 result=0", "200 result=-1"])
    assert(agi.set_autohangup(100).success?)
    assert_raise(AGIChannelError) { agi.set_autohangup(100) }
    assert_raise(AGIHangupError) { agi.set_autohangup(100) }
  end

  def test_set_callerid
    agi = get_dummy_agi(["200 result=1", "200 result=-1"])
    assert(agi.set_callerid(12345).success?)
    assert_raise(AGIChannelError) { agi.set_callerid(12345) }
    assert_raise(AGIHangupError) { agi.set_callerid(12345) }
  end

  def test_set_context
    agi = get_dummy_agi(["200 result=0", "200 result=-1"])
    assert(agi.set_context('testcontext').success?)
    assert_raise(AGIChannelError) { agi.set_context('testcontext') }
    assert_raise(AGIHangupError) { agi.set_context('testcontext') }
  end

  def test_set_extension
    agi = get_dummy_agi(["200 result=0", "200 result=-1"])
    assert(agi.set_extension('testextension').success?)
    assert_raise(AGIChannelError) { agi.set_extension('testextension') }
    assert_raise(AGIHangupError) { agi.set_extension('testextension') }
  end

  def test_set_priority
    agi = get_dummy_agi(["200 result=0", "200 result=-1"])
    assert(agi.set_priority('testpriority').success?)
    assert_raise(AGIChannelError) { agi.set_priority('testpriority') }
    assert_raise(AGIHangupError) { agi.set_priority('testpriority') }
  end

  def test_set_music
    agi = get_dummy_agi(["200 result=0", "200 result=-1"])
    assert(agi.set_music('on').success?)
    assert_raise(AGIChannelError) { agi.set_music('on') }
    assert_raise(AGIHangupError) { agi.set_music('on') }
  end

  def test_set_variable
    agi = get_dummy_agi(["200 result=1", "200 result=-1"])
    assert(agi.set_variable('variable','value').success?)
    assert_raise(AGIChannelError) { agi.set_variable('variable','value') }
    assert_raise(AGIHangupError) { agi.set_variable('variable','value') }
  end

  def test_tdd_mode
    agi = get_dummy_agi(["200 result=0", "200 result=-1", "200 result=1"])
    assert_raise(AGIChannelError) { agi.tdd_mode('on') }
    assert_raise(AGIChannelError) { agi.tdd_mode('on') }
    assert(agi.tdd_mode('on').success?)
    assert_raise(AGIHangupError) { agi.tdd_mode('on') }
  end

  def test_verbose
    agi = get_dummy_agi(["200 result=1", "200 result=-1"])
    assert(agi.verbose('message','level').success?)
    assert_raise(AGIChannelError) { agi.verbose('message','level') }
    assert_raise(AGIHangupError) { agi.verbose('message','level') }
  end

  def test_background
    agi_h = get_dummy_agi
    agi_f = get_dummy_agi(["200 result=-1"])
    agi_s = get_dummy_agi(["200 result=0"])
    agi_d = get_dummy_agi(["200 result=35"])
    agi_m = get_dummy_agi(["200 result=0","200 result=0","200 result=35"])
    agi_ms = get_dummy_agi(["200 result=0","200 result=0","200 result=0"])
    agi_e = get_dummy_agi(["200 result=(timeout)"])
    assert_raise(AGITimeoutError) { agi_e.background("myfile", "#")}
    assert_raise(AGIHangupError) { agi_h.background("myfile", "#") }    
    assert_raise(AGIChannelError) { agi_f.background("myfile", "#") }
    assert_equal('#', agi_m.background(['myfile1','myfile2','myfile3'], '#'))
    assert(agi_s.background("myfile", "#").success?)
    assert(agi_ms.background(["myfile","myfile2",'myfile3'], "#").success?)    
    assert_equal('#', agi_d.background("myfile", "#"))
  end

  def test_background_digits
    agi_h = get_dummy_agi
    agi_s = get_dummy_agi(["200 result=0"])
    assert_raise(AGIHangupError) {agi_h.background_digits("12345")}
    assert(agi_s.background_digits("1").success?)
  end
  private
  def get_dummy_agi(input=nil)
    asterisk_io_in = StringIO.new
    asterisk_io_in << "agi_network: yes\n"
    asterisk_io_in << "agi_request: agi://localhost:4573/sample/1/?foo=bar\n"
    asterisk_io_in << "agi_channel: SIP/5061-00000000\n"
    asterisk_io_in << "agi_language: en\n"
    asterisk_io_in << "agi_type: SIP\n"
    asterisk_io_in << "agi_type: SIP\n"
    asterisk_io_in << "agi_uniqueid: 1234567890\n"
    asterisk_io_in << "agi_callerid: \"SIPPhone\" <1234>\n"
    asterisk_io_in << "agi_dnid: 1\n"
    asterisk_io_in << "agi_rdnis: unknown\n"
    asterisk_io_in << "agi_context: ruby-agi\n"
    asterisk_io_in << "agi_extension: s\n"
    asterisk_io_in << "agi_priority: 2\n"
    asterisk_io_in << "agi_enhanced: 0.0\n"
    asterisk_io_in << "\n"
    unless input.nil?
      input.each { |data| asterisk_io_in << "#{data}\n"}
    end
    asterisk_io_in.rewind
    logger = Logger.new('/dev/null')
    #logger = Logger.new(STDERR)
    agi = AGI.new({:input => asterisk_io_in, :output => StringIO.new, :logger => logger})
    agi.init
    return agi
  end
end


## Copyright (c) 2007, Vonage Holdings
##
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
##      * Redistributions of source code must retain the above copyright
## notice, this list of conditions and the following disclaimer.
##      * Redistributions in binary form must reproduce the above copyright
## notice, this list of conditions and the following disclaimer in the
## documentation and/or other materials provided with the distribution.
##      * Neither the name of Vonage Holdings nor the names of its       
## contributors may be used to endorse or promote products derived from this
## software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
## LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.