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
=end
#AGIResponse implements a simple response object which stores Asterisk's native result, and provided data, to be evaluated in various ways.

#AGIResponse implements a simple response object which stores Asterisk's native result, and provided data, to be evaluated in various ways.
class AGIResponse
  attr_accessor :native, :data, :success
  def initialize
    @native  = nil
    @data    = nil
    @success = false
  end
#Allows the response object to be evaluated as a string, returning the data.
  def to_s
      return @data.to_s
  end
  alias_method :to_str, :to_s

#Allows the response object to be evaluated as an integer, returning the data if it can be evaluated as such
  def to_i
    if @data.respond_to?(:to_i)
      return @data.to_i
    else
      return nil
    end
  end

#Allows the response object to be compared with a regular expression, if possible
  def =~(regexp)
    return unless regexp.instance_of?(Regexp)
    if @data.respond_to?(:to_s)
      return @data.to_s =~ regexp
    else
      return nil
    end
  end

#Allows the object to be compared for equality.
  def ==(string)
      @data == string
  end
  
#Can check the response object to see if the associated command was successful.
  def success?
    @success
  end

#Check to see if the object is nil returns whether the data is nil
  def nil?
    @data.nil?
  end

#Allow addition for numbers (Integer, Float, Fixnum)
  def +(rvalue)
    values = coerce(rvalue)
    return ( values[1] + values[0])
  end

#Allow subtraction for numbers (Integer, Float, Fixnum)
  def -(rvalue)
    values = coerce(rvalue)
    return ( values[1] - values[0])
  end
  
#Allow multiplication of numbers (Integer, Float, Fixnum)
  def *(rvalue)
    values = coerce(rvalue)
    return ( values[1] * values[0])
  end

#Allow division of numbers (Integer, Float, Fixnum)
  def /(rvalue)
    values = coerce(rvalue)
    return ( values[1] / values[0])
  end
  
#Allow exponentiation of numbers (Integer, Float, Fixnum)
  def **(rvalue)
    values = coerce(rvalue)
    return ( values[1] ** values[0])
  end

#Allow modulus of numbers (Integer, Float, Fixnum)
  def %(rvalue)
    values = coerce(rvalue)
    return ( values[1] % values[0])
  end


  private
  def coerce(other)
    if Integer === other
      [other, Integer(@data)]
    elsif Float === other
      [other, Float(@data)]
    elsif Fixnum === other
      [other, Fixnum(@data)]
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