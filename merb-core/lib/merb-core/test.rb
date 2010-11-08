require 'merb-core/test/test_ext/object'
require 'merb-core/test/test_ext/string'

module Merb; module Test; end; end

require 'merb-core/test/helpers'

begin
  require 'webrat'
  require 'webrat/adapters/merb'
rescue LoadError => e
  if Merb.testing?
    Merb.logger.warn! "Couldn't load Webrat, so some features, like `visit' will not " \
                      "be available. Please install webrat if you want these features."
  end
end

if Merb.test_framework.to_s == "rspec"
  begin
    require 'merb-core/test/test_ext/rspec'
    require 'merb-core/test/matchers'
  rescue LoadError
    Merb.logger.warn! "You're using RSpec as a testing framework but you don't have " \
                      "the gem installed. To provide full functionality of the test " \
                      "helpers you should install it."
  end
end

Webrat.configure do |config|
  config.mode = :merb
end
