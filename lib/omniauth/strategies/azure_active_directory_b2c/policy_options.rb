module OmniAuth
  module Strategies
    class AzureActiveDirectoryB2C
      module PolicyOptions

        def respond_to_missing?(method_name, *args)
          self.class.instance_methods.include?("policy_#{method_name}".to_sym) || super
        end

        def method_missing(method_name, *args, &block)
          policy_method_name = 'policy_%s' % method_name
          if respond_to?(policy_method_name)
            send(policy_method_name, *args, &block)
          else
            super
          end
        end

        def policy_application_identifier
          raise MissingOptionError, '`application_identifier` not defined'
        end

        def policy_application_secret
          raise MissingOptionError, '`application_secret` not defined'
        end

        def policy_issuer
          raise MissingOptionError, '`issuer` not defined'
        end

        def policy_tenant_name
          raise MissingOptionError, '`tenant_name` not defined'
        end

        def policy_policy_name
          raise MissingOptionError, '`policy_name` not defined'
        end

        def policy_host_name
          'https://login.microsoftonline.com/te/%s/%s' % [tenant_name, policy_name]
        end

        def policy_authorization_endpoint
          @authorization_endpoint || '%s/oauth2/v2.0/authorize' % host_name
        end

        def policy_token_endpoint
          @token_endpoint || '%s/oauth2/v2.0/token' % host_name
        end

        def policy_jwks_uri
          '%s/discovery/v2.0/keys' % host_name
        end

        def policy_jwk_signing_algorithm
          # this can be "discovered" from the `jwks_uri` property at .well-known/openid-configuration
          'RS256'.to_sym
        end

        def policy_id_token_signing_algorithm
          policy_jwk_signing_algorithm
        end

        def policy_scope
          [
            :openid, # This requests an ID token
            # :offline_access, # This requests a refresh token using Auth Code flows.  See: https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-reference-oauth-code).
            # Request API permissions.  See https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-access-tokens
          ]
        end

        def policy_jwk_signing_keys
          # public keys are listed at the url specified in the the `jwks_uri` property at .well-known/openid-configuration
          # eg. https://login.microsoftonline.com/mipwtest.onmicrosoft.com/discovery/v2.0/keys?p=b2c_1_signupin
          raise MissingOptionError, '`jwk_signing_keys` not defined'
        end

        def policy_default_client_options
          {
            identifier: application_identifier,
            secret: application_secret,
            authorization_endpoint: authorization_endpoint,
            token_endpoint: token_endpoint,
            jwks_uri: jwks_uri,
          }
        end

        def policy_initialize_client(redirect_uri:, **override_options)
          options = default_client_options.merge(override_options)
          options[:redirect_uri] = redirect_uri
          Client.new(options)
        end

      end # PolicyOptions
    end # AzureActiveDirectoryB2C
  end # Strategies
end # OmniAuth
