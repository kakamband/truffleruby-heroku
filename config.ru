require "complex"
require "rack"

if ENV["RACK_ENV"] == "profile"
  use Rack::RubyProf,
    :path => File.expand_path(File.join(__dir__, 'log/profile')),
    :prefix => "rsb-rack-#{Process.pid}-",
    :max_requests => ENV["RSB_PROFILE_REQS"] || 10_000
end

class SpeedTest
  HEADERS = { "Content-Type" => "text/html" }
  ROUTES = {
    "/" => proc { [200, HEADERS, ["Hello World!"]] },
    "/static" => proc { [200, HEADERS, ["Static Text"]] },
    "/request" => proc { |env| r = Rack::Request.new(env); [200, HEADERS, ["Static Text"]] },
    "/mandelbrot" => proc { |env|
      x, i = env["QUERY_STRING"].split("&",2).map { |item| item.split("=", 2)[1].to_f }

      [200, HEADERS, [ SpeedTest.in_mandelbrot(x,i) ? "in" : "out" ]]
    },
    "/fivehundred" => proc { raise "This raises an error!" },
    "/delay" => proc { |env|
      t = 0.001
      if env["QUERY_STRING"] != nil && env["QUERY_STRING"] != ""
        t = env["QUERY_STRING"].split("=",2)[1].to_f
      end
      sleep t
      [ 200, HEADERS, [ "Static Text" ] ]
    },
    "/erb" => proc { |env|
      [ 200, HEADERS, [ SpeedTest.erb_template ] ]
    },
    # Not yet: /db
    "/process_mem" => proc { [ 200, HEADERS, [ "Process memory in bytes: #{GetProcessMem.new.bytes.to_i}" ] ] },

    # In multiprocess configurations, this only shuts down a single worker. That's probably not what you want.
    "/shutdown" => proc { exit 0 },
  }

  require 'erb'
  TEMPLATE = ERB.new(<<erb)
<html>
  <head> <%= title %> </head>
  <body>
    <h1> <%= title %> </h1>
    <p>
      <%= content %>
    </p>
  </body>
</html>
erb

  def self.erb_template
    title = 'hello world!'
    content = "hello world!\n" * 10
    TEMPLATE.result(binding)
  end

  def self.in_mandelbrot(x, i)
    z0 = Complex(x, i)
    z = z0
    80.times { z = z * z }
    z.abs < 2.0
  end

  def call(env)
    route = ROUTES[env["PATH_INFO"]]
    if route
      return route.call(env)
    else
      [ 404, HEADERS, [ "Sad Trombone... Your route is not found." ] ]
    end
  end
end

run SpeedTest.new
