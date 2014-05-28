require 'java'
require 'jbundler'
require 'manticore'

class HisterixCommand < com.netflix.hystrix.HystrixCommand
  java_import com.netflix.hystrix.HystrixCommand::Setter
  java_import com.netflix.hystrix.HystrixCommandKey
  java_import com.netflix.hystrix.HystrixCommandGroupKey
  java_import com.netflix.hystrix.HystrixCommandProperties

  DEFAULT_TIMEOUT = 10_000
  DEFAULT_GROUP   = "default"


  def initialize(name_or_setter, group=DEFAULT_GROUP, timeout=DEFAULT_TIMEOUT)
    setter = name_or_setter if name_or_setter.is_a?(com.netflix.hystrix.HystrixCommand::Setter)
    setter ||= Setter.withGroupKey(HystrixCommandGroupKey::Factory.asKey(group))
                     .andCommandKey(HystrixCommandKey::Factory.asKey(name_or_setter))
                     .andCommandPropertiesDefaults(HystrixCommandProperties::Setter().withExecutionIsolationThreadTimeoutInMilliseconds(timeout))

    super(setter)
  end
end

class HttpClient
  CLIENT = Manticore::Client.new(
    request_timeout:    6000,
    connect_timeout:    25,
    socket_timeout:     25,
    pool_max:           10,
    pool_max_per_route: 2,
    follow_redirects:   true
  )

  def self.get(url)
    CLIENT.get(url).body
  end
end

class GoogleGetter < HisterixCommand

  def initialize
    super('google_getter')
  end

  def run
    home_page = HttpClient.get('http://www.google.com')
    home_page[0..14]
  end

  def getFallback
    FallbackGetter.new.execute
  end
end

class FailureGetter < HisterixCommand

  def initialize
    # short timeout that we'll exceed
    super('google_failure', 'default', 500)
  end

  def run
    sleep 2
  end

  def getFallback
    FallbackGetter.new.execute
  end
end

class FallbackGetter < HisterixCommand

  def initialize
    super('default')
  end

  def run
    'failed!'
  end

  def getFallback
    FallbackGetter.new.execute
  end
end

GoogleGetter.new
puts 'This should succeed'
puts GoogleGetter.new.execute

puts 'This should fail'
puts FailureGetter.new.execute

exit
