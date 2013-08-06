vcr_wildcard_reverse_proxy
==========================

VCR+dnsmasq = language agnostic self-initializing fake

## Setting up DNS ##
You're going to need all requests to *.vcr to be sent through our proxy.  If you just have a few hosts you could edit
/etc/hosts, but the easiest way to make sure ANY *.vcr domain goes through our proxy is with dnsmasq.

Just set dnsmasq however you would for you system (here is a [simple guide](http://blakeembrey.com/articles/local-development-with-dnsmasq/) for OSX) and make sure your dnsmasq.conf file contains
<pre>
address=/.vcr/127.0.0.1
</pre>

If you've done this right the the IP address for *.vcr should always be 127.0.0.1:
```bash
 nslookup any_host_you_want.vcr
 Server:        127.0.0.1
 Address:   127.0.0.1#53

 Name:  any_host_you_want.vcr
 Address: 127.0.0.1
```

## Starting the server ##

The server is based on [Goliath](http://postrank-labs.github.io/goliath/) so it is easy to start:

```shell
$ ruby vcr_wildcard_reverse_proxy.rb -h
# Will show you some options

$ ruby vcr_wildcard_revesre_proxy.rb -sv
# Will start the server with verbose logging to stdout (port 9000 by default)
```

## Using the server ##

The server assumes hostnames will be in the format <cassette>_realhost.vcr (for example, test_google.com.br.vcr would use the "test"
  cassette and proxy to google.com.br)

The cassette will be ejected when you stop the server.

