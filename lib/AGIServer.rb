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

There are several ways to use the AGIServer module. All of them have a few things in common. In general, since we're creating a server, we need a way to cleanly kill it. So we setup sigint anf sigterm handlers to shutdown all instances of AGIServer Objects

  trap('INT')   { AGIServer.shutdown }
  trap('TERM')   { AGIServer.shutdown }

We also tend to use a logger because this should be daemonized. While developing, I reccomend you log to STDERR

  logger = Logger.new(STDERR)
  logger.level = Logger::DEBUG

I use YAML for configuration options. This just sets up the bind port, address, and some threading configuration options.

  config = YAML.load_file('config/example-config.yaml')
  config[:logger] = logger
  config[:params] = {:custom1 => 'data1'}

And then we generate our server

  begin
    MyAgiServer = AGIServer.new(config)
  rescue Errno::EADDRINUSE
    error = "Cannot start MyAgiServer, Address already in use."
    logger.fatal(error)
    print "#{error}\n"
    exit
  else
    print "#{$$}"
  end

In this example, I'll show you the rails-routing means of working with the AGIServer. Define a Route class along with a few routes, and start the server.

  class TestRoutes < AGIRoute
    def sample
      agi.answer
      print  "CUSTOM1 = [#{params[:custom1]}]\n"
      print  "URI     = [#{request[:uri]}]\n"
      print  "ID      = [#{request[:id]}]\n"
      print  "METHOD  = [#{request[:method]}]\n"
      print  "OPTIONS = #{request[:options].pretty_inspect}"
      print  "FOO     = [#{request[:options]['foo']}]\n"
      print '-' * 10 + "\n"
      helper_method
      agi.hangup
    end
    private
    def helper_method
      print "I'm private which means I'm not accessible as a route!\n"
    end
  end
  MyAgiServer.start
  MyAgiServer.finish

Pointing an asterisk extension at agi://localhost:4573/TestRoutes/sample/1/?foo=bar will execute the sample method in the TestRoutes class.

In this example, I'll show you how to use a block to define the AGI logic. Simply start the server and pass it a block expecting an agi object:

  MyAgiServer.start do |agi|
    agi.answer
    puts "I'm Alive!"
    agi.hangup
  end
  MyAgiServer.finish

In this example, I'll show you another way to use a block to define the AGI logic. This block makes configuration parameters available during the call:

  MyAgiServer.start do |agi,params|
    agi.answer
    print  "PARAMS = #{params.pretty_inspect}"
    agi.hangup
  end
  MyAgiServer.finish

=end
#AGIServer is a threaded server framework that is intended to be used to communicate with an Asterisk PBX via the Asterisk Gateway Interface, an interface for adding functionality to asterisk. This class implements a server object which will listen on a tcp host:port and accept connections, setup an AGI object, and either yield to a supplied block, which itself defines callflow, or route to public methods of the AGIRoute objects.
require 'socket'
require 'thread'
require 'logger'
require 'AGI.rb'
require 'AGIExceptions'
require 'AGIRouter'

#AGIServer is a threaded server framework that is intended to be used to communicate with an Asterisk PBX via the Asterisk Gateway Interface, an interface for adding functionality to asterisk. This class implements a server object which will listen on a tcp host:port and accept connections, setup an AGI object, and either yield to a supplied block, which itself defines callflow, or route to public methods of the AGIRoute objects.
class AGIServer
  #A list of all current AGIServers
  @@servers = []
  #Binding Parameters supplied during initialization.
  attr_reader :bind_host, :bind_port
  #Creates an AGIServer Object based on the provided Parameter Hash, and binds to the appropriate host/port. Will also set signal handlers that will shut down all AGIServer's upon receipt of SIGINT or SIGTERM.
  #* :bind_host sets the hostname or ip address to bind to. Defaults to localhost.
  #* :bind_port sets the port to bind to. Defaults to 4573.
  #* :max_workers sets the maximum number of worker threads to allow for connection processing. Defaults to 10
  #* :min_workers sets the minimum number of worker threads to maintain for connection processing. Defaults to 5
  #* :jobs_per_worker sets the number of connections each worker will handle before exiting. Defaults to 50
  #* :logger sets the Logger object to use for logging. Defaults to Logger.new(STDERR).
  #* :params can be any object you wish to be made available to all workers; I suggest a hash of objects.
  def initialize(params={})
    #Options
    @bind_host        = params[:bind_host]        || 'localhost'
    @bind_port        = params[:bind_port]        || 4573
    @max_workers      = params[:max_workers]      || 10
    @min_workers      = params[:min_workers]      || 5
    @jobs_per_worker  = params[:jobs_per_worker]  || 50
    @logger           = params[:logger]           || Logger.new(STDERR)
    @stats            = params[:stats]            || false
    @params           = params[:params]           || Hash.new

    #Threads
    @listener         = nil
    @monitor          = nil
    @workers          = []
    
    #Synchronization
    @worker_queue     = Queue.new
    @shutdown         = false

    #Initial Bind
    begin
      @listen_socket  = TCPServer.new(@bind_host, @bind_port)
    rescue Errno::EADDRINUSE
      @logger.fatal("AGIServer cannot bind to #{@bind_host}:#{@bind_port}, Address already in use.")
      raise    
    end
    
    #Track for signal handling
    @@servers << self
    AGIRouter.logger(@logger)
    
    trap('INT')   { shutdown }
    trap('TERM')  { shutdown }
  end
  #call-seq:
  # run()
  # run() { |agi| block }
  # run() { |agi,params| block }
  #
  #Starts the server to run. If a block is provided, the block will be run by all workers to handle connections. If a block is not provided, will attempt to route calls to public methods of AGIRoute objects.
  #
  #1. Listener Thread: The Listener Thread is the simplest of the Threads. It accepts client sockets from the main socket, and enqueues those client sockets into the worker_queue.
  #2. Worker Threads: The Worker Thread is also fairly simple. It loops jobs_per_worker times, and each time, dequeues from the worker_queue. If the result is nil, it exits, otherwise, it interacts with the client socket, either yielding to the aforementioned supplied block or routing to the AGIRoutes. If a Worker Thread is instantiated, it will continue to process requests until it processes jobs_per_worker jobs or the server is stopped.
  #3. Monitor Thread: The Monitor Thread is the most complex of the threads at use. It instantiates Worker Threads if at any time it detects that there are fewer workers than min_workers, and if at any time it detects that the worker_queue length is greater than zero while there are fewer than max_workers. 
  def run(&block)
    @logger.info{"AGIServer Initializing Monitor Thread"}
    @monitor = Thread.new do
      poll = 0
      while ! @shutdown do
        poll += 1
        if (@workers.length < @max_workers and @worker_queue.length > 0) or ( @workers.length < @min_workers ) then
          @logger.info{"AGIServer Starting Worker Thread to handle requests"}

          #Begin Worker Thread
          worker_thread = Thread.new do
            @jobs_per_worker.times do
              client = @worker_queue.deq
              break if client.nil?
              @logger.debug{"AGIServer Worker received Connection"}
              agi = AGI.new({ :input => client, :output => client, :logger => @logger })
              begin
                agi.init
                params = @params
                if block.nil?
                  router = AGIRouter.new(agi.channel_params['request'])
                  router.route(agi, params)
                else
                  if block.arity == 2
                    yield(agi, params)                    
                  elsif block.arity == 1
                    yield(agi)
                  end
                end
              rescue AGIHangupError => error
                @logger.error{"AGIServer Worker Caught Unhandled Hangup: #{error}"}
              rescue AGIError => error
                @logger.error{"AGIServer Worker Caught Unhandled Exception: #{error.class} #{error.to_s}"}
              rescue Exception => error
                @logger.error{"AGIServer Worker Got Unhandled Exception: #{error.class} #{error}"}
              ensure
                client.close
                @logger.debug{"AGIServer Worker done with Connection"}
              end
            end
            @workers.delete(Thread.current)
            @logger.info{"AGIServer Worker handled last Connection, terminating"}
          end
          #End Worker Thread
          
          @workers << worker_thread
          next #Short Circuit back without a sleep in case we need more threads for load
        end
        if @stats and poll % 10 == 0 then
          @logger.debug{"AGIServer #{@workers.length} active workers, #{@worker_queue.length} jobs waiting"} 
        end
        sleep 1
      end
      @logger.debug{"AGIServer Signaling all Worker Threads to finish up and exit"}
      @workers.length.times{ @worker_queue.enq(nil) }
      @workers.each { |worker| worker.join }
      @logger.debug{"AGIServer Final Worker Thread closed"}
    end

    @logger.info{"AGIServer Initializing Listener Thread"}
    @listener = Thread.new do
      begin
        while( client = @listen_socket.accept )
          @logger.debug{"AGIServer Listener received Connection Request"}
          @worker_queue.enq(client)
        end
      rescue IOError
        # Occurs on socket shutdown.
      end
    end
  end
  alias_method :start, :run

  #Will  wait for the Monitor and Listener threads to join. The Monitor thread itself will wait for all of it's instantiated Worker threads to join.
  def join
    @listener.join && @logger.debug{"AGIServer Listener Thread closed"}
    @monitor.join && @logger.debug{"AGIServer Monitor Thread closed"}
  end
  alias_method :finish, :join

  #Closes the listener socket, so that no new requests will be accepted. Signals to the Monitor thread to shutdown it's Workers when they're done with their current clients.
  def shutdown
    @logger.info{"AGIServer Shutting down gracefully"}
    @listen_socket.close && @logger.info{"AGIServer No longer accepting connections"}
    @shutdown = true && @logger.info{"AGIServer Signaling Monitor to close after active sessions complete"}
  end
  alias_method :stop, :shutdown

  #Calls shutdown on all AGIServer objects.
  def AGIServer.shutdown
    @@servers.each { |server| server.shutdown }
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