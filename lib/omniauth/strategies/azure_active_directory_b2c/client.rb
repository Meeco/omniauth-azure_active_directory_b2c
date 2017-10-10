require 'openid_connect'

module OmniAuth
  module Strategies
    class AzureActiveDirectoryB2C

      class Client < ::OpenIDConnect::Client
        # developers can override this class as required
        # Be sure to also override MicrosoftAzureB2C::Policy#initialize_client
      end

    end
  end
end
