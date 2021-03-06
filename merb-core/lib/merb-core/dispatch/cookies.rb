module Merb

  class Cookies < Mash
  
    # @api private
    def initialize(constructor = {})
      @_options_lookup  = Mash.new
      @_cookie_defaults = { "domain" => Merb::Controller._default_cookie_domain, "path" => '/' }
      super constructor
    end

    # Implicit assignment of cookie key and value.
    #
    # By using this method, a cookie key is marked for being
    # included in the Set-Cookie response header.
    #
    # @param [#to_s] name Name of the cookie.
    # @param [#to_s] value Value of the cookie.
    #
    # @api public
    def []=(key, value)
      @_options_lookup[key] ||= {}
      super
    end

    # Explicit assignment of cookie key, value and options
    #
    # By using this method, a cookie key is marked for being
    # included in the Set-Cookie response header.
    #
    # @param (see #[]=)
    # @param [Hash] options Additional options for the cookie
    # @option options [String] :path ("/")
    #   The path for which this cookie applies.
    # @option options [Time] :expires
    #   Cookie expiry date.
    # @option options [String] :domain
    #   The domain for which this cookie applies.
    # @option options [Boolean] :secure
    #   Security flag.
    # @option options [Boolean] :http_only
    #   HttpOnly cookies
    #
    # @api private
    def set_cookie(name, value, options = {})
      @_options_lookup[name] = options
      self[name] = value
    end

    # Removes the cookie on the client machine by setting the value to an
    # empty string and setting its expiration date into the past.
    #
    # @param [#to_s] name Name of the cookie to delete.
    # @param [Hash] options Additional options to pass to {#set_cookie}.
    #
    # @api public
    def delete(name, options = {})
      set_cookie(name, "", options.merge("expires" => Time.at(0)))
    end

    # Generate any necessary headers.
    #
    # @return [Hash] The headers to set, or an empty array if no cookies
    #   are set.
    #
    # @api private
    def extract_headers(controller_defaults = {})
      defaults = @_cookie_defaults.merge(controller_defaults)
      cookies = []
      self.each do |name, value|
        # Only set cookies that marked for inclusion in the response header. 
        next unless @_options_lookup[name]
        options = defaults.merge(@_options_lookup[name])
        if (expiry = options["expires"]).respond_to?(:gmtime)
          options["expires"] = expiry.gmtime.strftime(Merb::Const::COOKIE_EXPIRATION_FORMAT)
        end
        secure  = options.delete("secure")
        http_only = options.delete("http_only")
        kookie  = "#{name}=#{Merb::Parse.escape(value)}; "
        # WebKit in particular doens't like empty cookie options - skip them.
        options.each { |k, v| kookie << "#{k}=#{v}; " unless v.blank? }
        kookie  << 'secure; ' if secure
        kookie  << 'HttpOnly; ' if http_only
        cookies << kookie.rstrip
      end
      cookies.empty? ? {} : { 'Set-Cookie' => cookies.join(Merb::Const::NEWLINE) }
    end
    
  end
  
  module CookiesMixin
    
    def self.included(base)
      # Allow per-controller default cookie domains (see callback below)
      base.class_inheritable_accessor :_default_cookie_domain
      base._default_cookie_domain = Merb::Config[:default_cookie_domain]
      
      # Add a callback to enable Set-Cookie headers
      base._after_dispatch_callbacks << lambda do |c|
        headers = c.request.cookies.extract_headers("domain" => c._default_cookie_domain)
        c.headers.update(headers)
      end
    end

    # @return [Merb::Cookies]
    #   A new Cookies instance representing the cookies that came in
    #   from the request object
    #
    # @note Headers are passed into the cookie object so that you can do:
    #       cookies[:foo] = "bar"
    #
    # @api public
    def cookies
      request.cookies
    end
    
    module RequestMixin

      # @return [Hash] The cookies for this request.
      #
      # @note
      #   If a method `#default_cookies` is defined it will be called.
      #   This can be used for session fixation purposes for example.
      #   The method returns a Hash of key,value pairs.
      #
      # @api public
      def cookies
        @cookies ||= begin
          values  = Merb::Parse.query(@env[Merb::Const::HTTP_COOKIE], ';,')
          cookies = Merb::Cookies.new(values)
          cookies.update(default_cookies) if respond_to?(:default_cookies)
          cookies
        end
      end
      
    end   
    
  end
  
end
