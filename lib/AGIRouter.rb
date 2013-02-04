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
The AGIRouter is used to route clients to the proper AGIRoute method. It parses the URI presented to the AGIServer by asterisk in the request channel parameter, and if the AGIRoute object responds to the requested method/route, it calls it.
=end

#The AGIRouter is used to route clients to the proper AGIRoute method. It parses the URI presented to the AGIServer by asterisk in the request channel parameter, and if the AGIRoute object responds to the requested method/route, it calls it.
require 'logger'
require 'uri'
require 'AGIRoute'

#The AGIRouter is used to route clients to the proper AGIRoute method. It parses the URI presented to the AGIServer by asterisk in the request channel parameter, and if the AGIRoute object responds to the requested method/route, it calls it.
class AGIRouter
  #Logger for the AGIRouter class
  @@logger = Logger.new(STDERR)
  
  #Takes the request URI, and parses it into the requested method, a supplied id, and supplied options.
  def initialize(candidate_uri)
    @uri  = URI.parse(candidate_uri)
    @controller, @method, @id = parse_path(@uri.path)
    @options = parse_query(@uri.query)
  end
  
  #Can be used to reset the AGIRouter classes logger object.
  def AGIRouter.logger(logger)
    @@logger = logger
  end
  
  #Takes an agi, and an optional parameters hash, and attempts to route to the requested method. If the method does not exist or is private, uses the agi to change the channel extension to invalid and the priority to 1.
  def route(agi, params=nil)
    request = { :uri        => @uri, 
                :controller => @controller, 
                :method     => @method,
                :id         => @id,
                :options    => @options
              }
              
    if controller = get_controller(@controller)
      if check_controller(controller)
        if check_route(controller, @method)
          @@logger.info{"AGIRouter Routing Request to #{@controller} #{@method} by #{@uri}"}
          controller.new({:agi => agi, :params => params, :request => request}).method(@method).call()
        else
          @@logger.warn{"AGIRouter was asked to route a call to controller with unroutable method #{@controller} #{@method}"}      
          agi.set_extension('i')
          agi.set_priority('1')
        end
      else
        @@logger.warn{"AGIRouter was asked to route a call to an invalid controller #{@controller}"}      
        agi.set_extension('i')
        agi.set_priority('1')
      end
    else
      @@logger.warn{"AGIRouter was asked to route a call to a nonexistant controller #{@controller}"}      
      agi.set_extension('i')
      agi.set_priority('1')
    end
  end

  private
  def parse_path(uri_path)
    return nil if uri_path.nil?
    result = uri_path.split('/')[1,3]
  end
  def parse_query(uri_query)
    return nil if uri_query.nil?
    options = {}
    tuples = uri_query.split('&')
    tuples.each { |tuple| pair = tuple.split('='); options[pair[0]] = pair[1]}
    return options
  end
  
  def get_controller(requested_controller)
    begin
      return Module.const_get(requested_controller)
    rescue NameError
      # NameError when requested_controller doesn't exist as a class
      return nil
    end
  end
  
  def check_controller(candidate_controller)
    while candidate_controller = candidate_controller.superclass do
      return true if candidate_controller == AGIRoute
    end
    return nil    
  end
  
  def check_route(controller, requested_method)
    if controller.public_method_defined?(requested_method)
      return true
    else
      return false
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
