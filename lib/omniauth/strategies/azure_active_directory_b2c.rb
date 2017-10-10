require 'omniauth'
require 'proc_evaluate'

require_relative 'azure_active_directory_b2c/authentication_request.rb'
require_relative 'azure_active_directory_b2c/authentication_response.rb'
require_relative 'azure_active_directory_b2c/client.rb'
require_relative 'azure_active_directory_b2c/policy_options.rb'
require_relative 'azure_active_directory_b2c/policy.rb'
require_relative 'azure_active_directory_b2c/version.rb'

module OmniAuth
  module Strategies
    class AzureActiveDirectoryB2C

      include OmniAuth::Strategy

      using ProcEvaluate # adds the `evaluate` refinement method to Object and Proc instances

      #########################################
      # Error definitions
      #########################################

      GenericError = Class.new(StandardError)

      # Errors raised du to missing options or settings
      MissingOptionError = Class.new(GenericError)

      # Errors raised during the callback stage
      CallbackError = Class.new(GenericError) do
          attr_reader :failure_message_key
          def self.failure_message_key(key)
            define_method(:failure_message_key) { key }
          end
        end
      InvalidCredentialsError = Class.new(CallbackError) { failure_message_key :invalid_credentials }
      UnauthorizedError = Class.new(CallbackError) { failure_message_key :unauthorized }
      MissingCodeError = Class.new(CallbackError) { failure_message_key :missing_code }

      #########################################
      # Strategy options
      #########################################

      option :name, 'azure_active_directory_b2c'
      option :redirect_uri # the url to return to in the callback phase
      option :policy_options # a hash used to initialize OmniAuth::Strategies::AzureActiveDirectoryB2C::Policy
      option :policy # a proc, object or hash that matches the OmniAuth::Strategies::AzureActiveDirectoryB2C::PolicyOptions interface
      option :authentication_request # a proc, object or hash that matches the OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationRequest interface
      option :authentication_response # a proc, object or hash that matches the OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationResponse interface
      option :validate_callback_response # used to override the validation provided by this gem

      #########################################
      # Strategy - setup
      #########################################

      def setup_phase
        options.redirect_uri = options.redirect_uri.evaluate(options.name, options, request.params, request)
        options.policy = options.policy.evaluate(options, request.params, request)
        options.policy ||= Policy.new(**options.policy_options.symbolize_keys)
        raise MissingOptionError, 'No `policy` or `policy_options` option specified' if options.policy.nil?
        raise MissingOptionError, 'No `redirect` option specified' if options.redirect_uri.nil?
      end

      #########################################
      # Strategy - request
      #########################################

      def request_phase
        # this phase needs to redirect to B2C with the correct params and record the state and nonce in the session

        # allow developers to provide their own implementation of OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationRequest
        auth_request = options.authentication_request.evaluate(options.policy, redirect_uri: options.redirect_uri)

        # provide a default implementation
        auth_request ||= AuthenticationRequest.new(options.policy, redirect_uri: options.redirect_uri)

        # set the session details to check against in the callback_phase
        session['omniauth.nonce'] = auth_request.nonce
        session['omniauth.state'] = auth_request.state

        redirect auth_request.authorization_uri
      end

      #########################################
      # Strategy - callback
      #########################################

      def callback_phase
        # allow developers to provide custom validation
        if options.validate_callback_response
          options.validate_callback_response.evaluate(request.params, request)
        else
          validate_callback_response!
        end

        code = request.params['code']

        # allow developers to provide their own implementation of OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationResponse
        @auth_response = options.authentication_response.evaluate(options.policy, code)

        # provide a default implementation
        @auth_response ||= AuthenticationResponse.new(options.policy, code)

        super # required to complete the callback phase

      rescue UnauthorizedError => e
        return Rack::Response.new(['401 Unauthorized'], 401).finish
      rescue CallbackError => e
        fail!(e.failure_message_key, e)
      rescue ::Timeout::Error, ::Errno::ETIMEDOUT => e
        fail!(:timeout, e)
      rescue ::SocketError => e
        fail!(:failed_to_connect, e)
      end

      def validate_callback_response!
        state, code, error, error_reason, error_description = request.params.values_at('state', 'code', 'error', 'error_reason', 'error_description')

        if error || error_reason || error_description
          raise InvalidCredentialsError, [error, error_reason, error_description].compact.join('. ')
        elsif state.to_s.empty? || state != session.delete('omniauth.state')
          raise UnauthorizedError
        elsif !request.params['code']
          raise MissingCodeError, 'Code was not returned from OpenID Connect Provider'
        end
      end

      #########################################
      # Auth Hash Schema
      #########################################

      # return the details required by OmniAuth
      info { @auth_response.user_info }
      uid { @auth_response.subject_id }
      extra { @auth_response.extra_info }
      credentials { @auth_response.credentials }

    end
  end
end
OmniAuth.config.add_camelization('azure_active_directory_b2c', 'AzureActiveDirectoryB2C')

