module OmniAuth
  module Strategies
    class AzureActiveDirectoryB2C
      class Policy
        include AzureActiveDirectoryB2C::PolicyOptions

        attr_reader :application_identifier, :application_secret, :issuer, :tenant_name, :policy_name, :jwk_signing_algorithm, :jwk_signing_keys

        def initialize(application_identifier:, application_secret:, issuer:, tenant_name:, policy_name:, jwk_signing_keys:, scope: nil)
          @application_identifier = application_identifier
          @application_secret = application_secret
          @issuer = issuer
          @tenant_name = tenant_name
          @policy_name = policy_name
          @jwk_signing_keys = jwk_signing_keys
          @scope = *scope
        end

        def scope
          @scope.any? ? @scope : super
        end
      end # Policy
    end # AzureActiveDirectoryB2C
  end # Strategies
end # OmniAuth
