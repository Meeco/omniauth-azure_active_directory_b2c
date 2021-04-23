require 'omniauth'

require_relative 'azure_active_directory_b2c/authentication_request.rb'
require_relative 'azure_active_directory_b2c/authentication_response.rb'
require_relative 'azure_active_directory_b2c/client.rb'
require_relative 'azure_active_directory_b2c/jwt_validator.rb'
require_relative 'azure_active_directory_b2c/policy_options.rb'
require_relative 'azure_active_directory_b2c/policy.rb'
require_relative 'azure_active_directory_b2c/version.rb'

module OmniAuth
  module Strategies
    class AzureActiveDirectoryB2C

      include OmniAuth::Strategy

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
      IdTokenValidationError = Class.new(CallbackError) { failure_message_key :id_token_validation_failed }

      #########################################
      # Strategy options
      #########################################

      option :name, 'azure_active_directory_b2c'
      option :redirect_uri # the url to return to in the callback phase
      option :policy_options

      #########################################
      # Strategy - setup
      #########################################

      def policy_options
        @policy_options ||= options.policy_options || (raise MissingOptionError, '`policy_options` not defined')
      end

      def policy
        @policy = Policy.new(**policy_options.symbolize_keys)
      end

      def redirect_uri
        @redirect_uri ||= options.redirect_uri || (raise MissingOptionError, '`redirect_uri` not defined')
      end

      def setup_phase
      end

      #########################################
      # Strategy - request
      #########################################

      def authentication_request
        @authentication_request ||= AuthenticationRequest.new(policy, redirect_uri: redirect_uri)
      end

      def authorization_uri
        authentication_request.authorization_uri
      end

      def set_session_variables!
        # set the session details to check against in the callback_phase
        session['omniauth.nonce'] = authentication_request.nonce
        session['omniauth.state'] = authentication_request.state
      end

      def request_phase
        # this phase needs to redirect to B2C with the correct params and record the state and nonce in the session to check against in the callback_phase
        set_session_variables!
        redirect authentication_request.authorization_uri
      end

      #########################################
      # Strategy - callback
      #########################################

      def authentication_response
        @authentication_response ||= AuthenticationResponse.new(policy, request.params['code'])
      end

      def callback_phase
        validate_callback_response!
        validate_id_token!
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
        elsif !code
          raise MissingCodeError, 'Code was not returned from OpenID Connect Provider'
        end
      end

      def validate_id_token!
        results = authentication_response.validate_id_token
        if results.has_errors?
          raise IdTokenValidationError, results.full_messages.join('. ')
        end
      end

      #########################################
      # Auth Hash Schema
      #########################################

      def user_info
        authentication_response.user_info
      end

      def subject_id
        authentication_response.subject_id
      end

      def extra_info
        authentication_response.extra_info
      end

      def credentials
        authentication_response.credentials
      end

      # return the details required by OmniAuth
      info { user_info }
      uid { subject_id }
      extra { extra_info }
      credentials { credentials }

    end
  end
end
OmniAuth.config.add_camelization('azure_active_directory_b2c', 'AzureActiveDirectoryB2C')
