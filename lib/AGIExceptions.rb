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
AGIExceptions declares various exception classes for the AGI Framework.
=end

#There are several possible Exceptions that can occur with AGI communication. This file provides custom exception classes that mirror them.
#= Exceptions:
#* AGIError
#* AGIHangupError
#* AGITimeoutError
#* AGIChannelError
#* AGICommandError
#* AGIInitializeError

#AGIError is the base Exception Class from which all other AGI Exceptions inherit.
#= Children:
#* AGIHangupError
#* AGITimeoutError
#* AGIChannelError
#* AGICommandError
#* AGIInitializeError
class AGIError < Exception
  # This is the raw string returned from Asterisk to the AGI if one was available
  attr_accessor :raw_data
  def initialize(raw_data, *rest)
    @raw_data = raw_data
    super(rest)
  end
  def to_s
    @raw_data
  end
  def to_str
    self.to_s
  end  
end

#AGIHangupError signifies that the Asterisk Channel associated with the AGI has been hung up, unexpectedly. It inherits from AGIError.
class AGIHangupError < AGIError
end

#AGITimeoutError signifies that a Asterisk notified the AGI that a requested command timed out. It inherits from AGIError.
class AGITimeoutError < AGIError
end

#AGIChannelError signifies that Asterisk notified the AGI of a channel error. It inherits from AGIError.
class AGIChannelError < AGIError
end

#AGICommandError signifies that Asterisk has notified us that there was an error with the requested Command, usually the syntax. It inherits from AGIError.
class AGICommandError < AGIError
end

#AGIInitializeError significes that the AGI has been instructed to initialize a channel which had previously been reinitialized. If this is actually intended, it can be accomplished by first calling reinit, which will reset channel parameters beforehand.
class AGIInitializeError < AGIError
end

#AGIMenuFailure signifies that there was a failure in constructing or playing an AGIMenu
class AGIMenuFailure < Exception
  def initialize(str)
    @message = str
  end
  def to_s
    @message
  end
  def to_str
    self.to_s
  end
end

class AGIStateFailure < Exception
  def initialize(str)
    @message = str
  end
  def to_s
    @message
  end
  def to_str
    self.to_s
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
