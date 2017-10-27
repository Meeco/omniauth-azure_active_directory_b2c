module OmniAuth
  module Strategies
    class AzureActiveDirectoryB2C

      class ValidationResult
        def error_messages
          @error_messages ||= []
        end

        def add_error(key, message)
          error_messages << { error: key, message: message }
        end

        def has_errors?
          error_messages.any?
        end

        def okay?
          error_messages.empty?
        end

        def full_messages
          error_messages.collect {|err| err[:message] }
        end
      end # ValidationResult

      class JwtValidator

        EPOC_TIME_LEEWAY_SECONDS = 10

        attr_reader :jwt, :jwt_key, :policy, :seconds_since_epoc

        def self.validate(jwt, jwt_key, policy, seconds_since_epoc = Time.now.to_i)
          new(jwt, jwt_key, policy, seconds_since_epoc).validate
        end

        def initialize(jwt, jwt_key, policy, seconds_since_epoc = Time.now.to_i)
          @jwt = jwt
          @jwt_key = jwt_key
          @policy = policy
          @seconds_since_epoc = seconds_since_epoc
        end

        def validate
          results = ValidationResult.new
          results.add_error(:algorithm_mismatch, "Signing algorithm mismatch: Expected `#{policy.jwk_signing_algorithm} but got #{jwt.algorithm}`") unless signing_algoritm_matches?
          results.add_error(:issue_mismatch, "Issue mismatch: Expected `#{policy.issuer}` but got `#{jwt[:iss]}`") unless issuer_matches?
          results.add_error(:audience_mismatch, "Audience mismatch: Expected `#{policy.aud}` but got `#{jwt[:aud]}`") unless audience_matches?
          results.add_error(:before_start_time, "Token has not yet commenced: Valid at #{jwt[:nbf]} but currently #{seconds_since_epoc}") unless on_or_after_not_before_time?
          results.add_error(:after_expiry_time, "Token has expired: Expired at #{jwt[:exp]} but currently #{seconds_since_epoc}") unless before_expiration_time?

          begin
            verify_signature!
          rescue JSON::JWS::VerificationFailed
            results.add_error(:signiture_verification_failed, 'Signture verification failed') unless signature_verified?
          rescue JSON::JWS::UnexpectedAlgorithm
            results.add_error(:unexpected_signiture_algorithm, 'Unexpected signature algorithm') unless signature_verified?
          rescue => e
            results.add_error(:signiture_verification_failed, e.message || 'Signature verification failed') unless signature_verified?
          end

          results # return results
        end

        def signing_algoritm_matches?
          # An attacker may change the signing algorith to provide a forged signature
          jwt.algorithm.to_sym == policy.jwk_signing_algorithm
        end

        def issuer_matches?
          jwt[:iss] && jwt[:iss] != '' && jwt[:iss] == policy.issuer
        end

        def audience_matches?
          jwt[:aud] && jwt[:aud] != '' && jwt[:aud] == policy.application_identifier
        end

        def on_or_after_not_before_time?
          (seconds_since_epoc + EPOC_TIME_LEEWAY_SECONDS) >= jwt[:nbf]
        end

        def before_expiration_time?
          (seconds_since_epoc - EPOC_TIME_LEEWAY_SECONDS) < jwt[:exp]
        end

        def verify_signature!
          jwt.verify!(jwt_key)
        end

      end # JwtVerifier
    end # AzureActiveDirectoryB2C
  end # Strategies
end # OmniAuth
