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


require 'stringio'
require 'AGIServer'
require "test/unit"
require 'pp'

class TestController < AGIRoute
  def test_route
    agi.answer
    agi.set_variable('foo', params.pretty_inspect.chomp)
    agi.hangup
  end
  private
  def priv_route
    agi.answer
    agi.set_variable('foo', params.pretty_inspect.chomp)
    agi.hangup
  end
end

class NotAController
    def test_route
      agi.answer
      agi.set_variable('foo', params.pretty_inspect.chomp)
      agi.hangup
    end
    private
    def priv_route
      agi.answer
      agi.set_variable('foo', params.pretty_inspect.chomp)
      agi.hangup
    end
  end

class TestAsteriskAGIServer < Test::Unit::TestCase
  def test_routed_agiserver
    port = 4573
    agiserver = get_agiserver(port)
    agiserver.start
    client = TCPSocket.new('localhost', port)
    client << "agi_request: agi://localhost/TestController/test_route/1/?foo=bar&foobar=baz\n"
    client << "\n"
    assert_equal("ANSWER\n", client.gets)
    client << "200 result=0\n"
    assert_equal("SET VARIABLE foo {:param1=>\"param1_text\"}\n", client.gets)
    client << "200 result=0\n"
    assert_equal("HANGUP\n", client.gets)
    client << "200 result=1\n"
    client.close
    agiserver.shutdown
    agiserver.finish

    agiserver = get_agiserver(port)
    agiserver.start
    client = TCPSocket.new('localhost', port)
    client << "agi_request: agi://localhost/NotAController/test_route/1/?foo=bar&foobar=baz\n"
    client << "\n"
    assert_equal("SET EXTENSION i\n", client.gets)
    client << "200 result=1\n"
    assert_equal("SET PRIORITY 1\n", client.gets)
    client << "200 result=1\n"
    client.close
    agiserver.shutdown
    agiserver.finish

    agiserver = get_agiserver(port)
    agiserver.start
    client = TCPSocket.new('localhost', port)
    client << "agi_request: agi://localhost/NoController/test_route/1/?foo=bar&foobar=baz\n"
    client << "\n"
    assert_equal("SET EXTENSION i\n", client.gets)
    client << "200 result=1\n"
    assert_equal("SET PRIORITY 1\n", client.gets)
    client << "200 result=1\n"
    client.close
    agiserver.shutdown
    agiserver.finish
        
    agiserver = get_agiserver(port)
    agiserver.start
    client = TCPSocket.new('localhost', port)
    client << "agi_request: agi://localhost/TestController/no_route/1/?foo=bar&foobar=baz\n"
    client << "\n"
    assert_equal("SET EXTENSION i\n", client.gets)
    client << "200 result=1\n"
    assert_equal("SET PRIORITY 1\n", client.gets)
    client << "200 result=1\n"
    client.close
    agiserver.shutdown
    agiserver.finish
    
    agiserver = get_agiserver(port)
    agiserver.start
    client = TCPSocket.new('localhost', port)
    client << "agi_request: agi://localhost/TestController/priv_route/1/?foo=bar&foobar=baz\n"
    client << "\n"
    assert_equal("SET EXTENSION i\n", client.gets)
    client << "200 result=1\n"
    assert_equal("SET PRIORITY 1\n", client.gets)
    client << "200 result=1\n"
    client.close
    agiserver.shutdown
    agiserver.finish
  end
  def test_agiblock_agiserver
    port = 4574
    agiserver = get_agiserver(port)
    agiserver.start do |agi| 
      agi.answer
      agi.hangup
    end
    client = TCPSocket.new('localhost', port)
    client << "agi_request: agi://localhost/\n"
    client << "\n"
    assert_equal("ANSWER\n", client.gets)
    client << "200 result=0\n"
    assert_equal("HANGUP\n", client.gets)
    client << "200 result=1\n"
    client.close
    agiserver.shutdown
    agiserver.finish
  end
  def test_agiparamblock_agiserver
    port = 4574
    agiserver = get_agiserver(port)
    agiserver.start do |agi,params|
      agi.answer
      assert_equal("{:param1=>\"param1_text\"}", params.pretty_inspect.chomp)
      agi.hangup
    end
    client = TCPSocket.new('localhost', port)
    client << "agi_request: agi://localhost/\n"
    client << "\n"
    assert_equal("ANSWER\n", client.gets)
    client << "200 result=0\n"
    assert_equal("HANGUP\n", client.gets)
    client << "200 result=1\n"
    client.close
    agiserver.shutdown
    agiserver.finish
  end
  def test_exceptions
    port = 4575
    agiserver1 = get_agiserver(port)
    assert_raise(Errno::EADDRINUSE) {  agiserver2 = get_agiserver(port) }
    agiserver1.run
    client = TCPSocket.new('localhost', port)
    client.close
    sleep 10   
    agiserver1.shutdown
  end
  private
  def get_agiserver(port=4573)
    config = {:stats            => true,
              :bind_port        => port,
              :min_workers      => 5,
              :jobs_per_worker  => 2,
              :max_workers      => 10,
              :bind_host        => "127.0.0.1",
              :logger           => Logger.new('/dev/null'),
              :params           => {:param1 => 'param1_text'}
            }
    server = AGIServer.new(config)
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