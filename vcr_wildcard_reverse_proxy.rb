#!/usr/bin/env ruby

# See README.md about setting up dnsmasq
# > ruby vcr_wildcard_reverse_proxy.rb -sv
# > curl http://test_www.google.com.br.vcr:9000/
# Should record "test" cassette containing an interaction to www.google.com.br
# Restart and running curl again will make sure it is played back

require 'rubygems'
require 'goliath'
require 'em-http-request'
require 'em-synchrony/em-http'
require 'pp'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'cassettes'
  c.hook_into :webmock
  c.default_cassette_options = { :record => :new_episodes, :allow_playback_repeats => true }
  c.before_record do |interaction, cassette|
      puts "Recording to #{cassette.name}"
  end
  c.before_playback do |interaction, cassette|
      puts "Playing from #{cassette.name}"
  end
end

# Hash#clone doesn't do deep copies? :(
def deep_copy(o)
    Marshal.load(Marshal.dump(o))
end

class VCRGoliath < Goliath::API
  use Goliath::Rack::Params

  def rewrite_hosts(obj, is_response=false)
      puts "Rewriting #{obj}"
      original_host = env['HTTP_HOST'].dup
      real_host = env['REAL_HOST']

      if obj.respond_to? :gsub!
          obj.gsub! real_host, original_host if is_response
          obj.gsub! original_host, real_host unless is_response
      elsif obj.respond_to? :each_pair
          obj.each_pair { |k, v| obj[k] = rewrite_hosts(v) }
      elsif obj.respond_to? :map
          obj.map { |o| rewrite_hosts(o) }
      end
      # require 'pry'; binding.pry unless env['HTTP_HOST'] == original_host
      obj
  end

  def on_headers(env, headers)
    logger.debug 'proxying new request: ' + headers.inspect
    env['client-headers'] = deep_copy(headers)
  end

  def response(env)
    logger.debug env
    original_host = env['HTTP_HOST']
    cassette, real_host = original_host.split('_')
    real_host.slice! ".vcr:#{env[Goliath::Request::SERVER_PORT]}"
    env['REAL_HOST'] = real_host

    if logger.debug?
        logger.debug "Proxying request from #{original_host} to #{real_host} using cassette #{cassette}"
    end

   rewrite_hosts(env['client-headers'])

    # I probably shouldn't have used an event server without checking if VCR is threadsafe...
    EM::Synchrony.sleep(0.5) while VCR.current_cassette != nil

    VCR.use_cassette(cassette, :exclusive => true) do
      start_time = Time.now.to_f

      params = {:head => env['client-headers'], :query => env.params}

      req = EventMachine::HttpRequest.new('https://' + real_host + env[Goliath::Request::REQUEST_URI])
      resp = case(env[Goliath::Request::REQUEST_METHOD])
        when 'GET'  then req.get(params)
        when 'POST' then
            real_body = env[Goliath::Request::RACK_INPUT].read.gsub(original_host, real_host)
            req.post(params.merge(:body => real_body))
        when 'HEAD' then req.head(params)
        else p "UNSUPPORTED METHOD #{env[Goliath::Request::REQUEST_METHOD]}"
      end

      response_headers = {}
      resp.response_header.each_pair do |k, v|
        response_headers[to_http_header(k)] = rewrite_hosts(v, true)
      end
      rewrite_hosts(resp.response, true)
      response_headers['Content-Length'] = resp.response.length.to_s
      [resp.response_header.status, response_headers, resp.response]
    end
  end

  def to_http_header(k)
    k.downcase.split('_').collect { |e| e.capitalize }.join('-')
  end
end

at_exit do
  VCR.eject_cassette
end
