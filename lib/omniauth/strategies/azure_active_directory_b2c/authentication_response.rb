module OmniAuth
  module Strategies
    class AzureActiveDirectoryB2C
      class AuthenticationResponse

        class AuthenticationMethod
          BASIC = 'basic'
          BODY = 'body'
          POST = 'post'
        end

        attr_reader :policy, :client, :code

        def initialize(policy, code, **override_options)
          @policy = policy
          @client = policy.initialize_client({ redirect_uri: nil, **override_options })
          @client.authorization_code = code
          @code = code
        end

        def access_token
          @access_token ||= get_access_token!
        end

        def id_token
          @id_token ||= get_id_token!
        end

        def refresh_token
          access_token.refresh_token
        end

        def expires_in
          access_token.expires_in
        end

        def subject_id
          id_token.sub
        end

        def user_info
          {
            name: id_token.raw_attributes['name'],
            email: ([*id_token.raw_attributes['emails']].first || id_token.raw_attributes['email']),
            nickname: id_token.raw_attributes['preferred_username'],
            first_name: id_token.raw_attributes['given_name'],
            last_name: id_token.raw_attributes['family_name'],
            gender: id_token.raw_attributes['gender'],
            image: id_token.raw_attributes['picture'],
            phone: id_token.raw_attributes['phone_number'],
            urls: { website: id_token.raw_attributes['website'] }
          }
        end

        def extra_info
          { raw_info: id_token.raw_attributes }
        end

        def scope
          policy.scope
        end

        def authentication_method
          AuthenticationMethod::BODY
        end

        def credentials
          {
            id_token: id_token,
            token: access_token.access_token,
            refresh_token: refresh_token,
            expires_in: expires_in,
            scope: scope,
          }
        end

        def default_access_token_options
          {
            scope: scope,
            client_auth_method: authentication_method,
          }
        end

        def get_access_token!
          client.access_token!(default_access_token_options)
        end

        def get_id_token!
          # TODO: if the id_token is not passed back, we could get the id token from the userinfo endpoint (or fail if no endpoint is defined?)
          encrypted_id_token = access_token.id_token
          decoded_id_token = decode_id_token!(encrypted_id_token)
        end

        def decode_id_token!(id_token)
          ::OpenIDConnect::ResponseObject::IdToken.decode(id_token, public_key)
        end

        def public_key
          if policy.jwk_signing_algorithm == :RS256 && policy.jwk_signing_keys
            jwk_key
          else
            raise 'id_token signing algorithm is currently not supported: %s' % policy.jwk_signing_algorithm
          end
        end

        def jwk_key
          key = policy.jwk_signing_keys
          if key.has_key?('keys')
            JSON::JWK::Set.new(key['keys']) # a set of keys
          else
            JSON::JWK.new(key) # a single key
          end
        end

        def validate_id_token(seconds_since_epoc = Time.now.to_i)
          JwtValidator.validate(id_token.raw_attributes, public_key, policy, seconds_since_epoc)
        end

      end # AuthenticationResponse
    end # AzureActiveDirectoryB2C
  end # Strategies
end # OmniAuth
