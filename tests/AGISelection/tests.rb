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

# Unit test for AGISelection
require 'test/unit'
require 'stringio'
require 'AGISelection'


class TestAGISelection < Test::Unit::TestCase

# agi = AGI.new({})
# # Initialize the AGI or bad things will happen
# agi.init()
# yaml_hash = {:audio => 'tt-monkeys', :max_digits => 4}
# foo = AGISelection.new(yaml_hash)
# # Override the Audio file from the YAML hash
# foo.audio = 'somethingelse'
# foo.read(:agi => agi)

  def test_read
    agi = get_dummy_agi(["200 result=123456", "200 result=-1", "200 result=1234", "200 result=12"])
    yaml_hash = {:audio => 'tt-monkeys', :max_digits => 6}
    agi_sel = AGISelection.new(yaml_hash)
    assert_equal(123456, agi_sel.read(:agi => agi))
    assert_raise(AGIChannelError) {agi_sel.read(:agi => agi)}
    yaml_hash = {:audio => 'tt-monkeys', :max_digits => 4, :timeout => 60}
    agi_sel = AGISelection.new(yaml_hash)
    assert_equal(1234, agi_sel.read(:agi => agi))
    assert_raise(ArgumentError){agi_sel.read()}
    yaml_hash = {:max_digits => 4, :timeout => 60}
    agi_sel = AGISelection.new(yaml_hash)
    assert_raise(ArgumentError){agi_sel.read(:agi => agi)}
  end
  
  private
  def get_dummy_agi(input=nil)
    asterisk_io_in = StringIO.new
    unless input.nil?
      input.each { |data| asterisk_io_in << "#{data}\n"}
    end
    asterisk_io_in.rewind
    agi = AGI.new({ :input => asterisk_io_in, 
                    :logger => Logger.new('/dev/null'),
                    :output => StringIO.new})
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