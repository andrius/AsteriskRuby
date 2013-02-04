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


require "test/unit"
require 'stringio'
require 'AGIMenu'

class TestAGIMenu < Test::Unit::TestCase
  def test_menu_from_filename
    check_menu(get_menu_from_filename)
  end
  def test_menu_from_file
    check_menu(get_menu_from_file)
  end
  def test_menu_from_yaml
    check_menu(get_menu_from_yaml)
  end
  def test_menu_from_hash
    check_menu(get_menu_from_hash)
  end
  def test_menu_build
    check_menu(get_menu_build)
  end     
  private
  def check_menu(menu)
    assert_equal(["*", "1", "2", "#"], menu.order)
    initial_order = menu.order
    # invalid order
    assert_raise(AGIMenuFailure) {  menu.reorder(['1']) }
    # force it
    menu.reorder(['1'], true)
    assert_equal(['1'], menu.order)
    # reset it back so its useful in future tests
    menu.reorder(initial_order, true)
    assert_equal(["*", "1", "2", "#"], menu.order)
    assert_raise(ArgumentError) {  menu.play() }
    # duplicate dtmf
    assert_raise(AGIMenuFailure) {  menu.add('*', "duplicate-dtmf") }
    agi, io = get_dummy_agi(15, '*')
    assert_equal('*', menu.play(:agi => agi).data, :introduction => true, :conclusion => true )
    io.rewind
    expected = get_expected_results(:length => 15, :introduction => true, :conclusion => true)
    while line = io.gets
      assert_equal(expected.gets, line)
    end
    agi, io = get_dummy_agi(15, '*')
    assert_equal('*', menu.play(:agi => agi, :introduction => false, :conclusion => false).data )
    io.rewind
    expected = get_expected_results(:length => 15, :introduction => false, :conclusion => false)
    while line = io.gets
      assert_equal(expected.gets, line)
    end
  end
  def get_menu_from_filename
    AGIMenu.new(File.expand_path(File.join(File.dirname(__FILE__), 'config/menu.yaml')))
  end
  def get_menu_from_file
    AGIMenu.new(File.open(File.expand_path(File.join(File.dirname(__FILE__), 'config/menu.yaml'))))
  end
  def get_menu_from_yaml
    AGIMenu.new(File.open( File.expand_path(File.join(File.dirname(__FILE__), 'config/menu.yaml')) ) { |f| YAML::load( f ) })
  end
  def get_menu_from_hash
    hash = {:introduction=>["welcome", "instructions"],
     :conclusion=>"what-is-your-choice",
     :timeout=>5,
     :choices=>
      [{:dtmf=>"*", :audio=>["press-star-to-go-back"]},
       {:dtmf=>'1', :audio=>["press", "digits/1", "for-option-1"]},
       {:dtmf=>'2', :audio=>["press", "digits/2", "for-option-2"]},
       {:dtmf=>"#", :audio=>"or-press-pound-to-repeat"}]}
    return AGIMenu.new(hash)
  end
  def get_menu_build
    menu = AGIMenu.new()
    menu.conclusion = 'what-is-your-choice'
    menu.introduction = ['welcome', 'instructions']
    menu.timeout = 5
    menu.add('*', 'press-star-to-go-back')
    menu.add('1', ['press','digits/1', 'for-option-1'])
    menu.add('2', ['press','digits/2', 'for-option-2'])
    menu.add('#', 'or-press-pound-to-repeat')
    return menu
  end
  def get_dummy_agi(length, char='*')
    dec = char[0]
    asterisk_io_in = StringIO.new
    asterisk_io_out = StringIO.new
    length.times { asterisk_io_in << "200 result=0\n" }
    asterisk_io_in << "200 result=#{dec}\n"
    asterisk_io_in.rewind
#    logger = Logger.new(STDERR)
    logger = Logger.new('/dev/null')
    agi = AGI.new({:input => asterisk_io_in, :output => asterisk_io_out, :logger => logger})
    return agi, asterisk_io_out
  end
  def get_expected_results(conf={})
    length = conf[:length]
    expected = StringIO.new
    if conf[:introduction] then
      expected << "STREAM FILE welcome '*12#'\n" && length -= 1 unless length <= 0
      expected << "STREAM FILE instructions '*12#'\n" && length -= 1 unless length <= 0
    end
    expected << "STREAM FILE press-star-to-go-back '*12#'\n" && length -= 1 unless length <= 0
    expected << "STREAM FILE press '*12#'\n" && length -= 1 unless length <= 0
    expected << "STREAM FILE digits/1 '*12#'\n" && length -= 1 unless length <= 0
    expected << "STREAM FILE for-option-1 '*12#'\n" && length -= 1 unless length <= 0
    expected << "STREAM FILE press '*12#'\n" && length -= 1 unless length <= 0
    expected << "STREAM FILE digits/2 '*12#'\n" && length -= 1 unless length <= 0
    expected << "STREAM FILE for-option-2 '*12#'\n" && length -= 1 unless length <= 0
    expected << "STREAM FILE or-press-pound-to-repeat '*12#'\n" && length -= 1 unless length <= 0
    if conf[:conclusion]
      expected << "STREAM FILE what-is-your-choice '*12#'\n" && length -= 1 unless length <= 0
    end
    while length >= 0
      expected << "WAIT FOR DIGIT 5000\n" && length -= 1
    end
    expected.rewind
    return expected
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