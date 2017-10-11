# OmniAuth::Strategies::AzureActiveDirectoryB2C

This gem is an Azure Active Directory B2C Strategy for [OmniAuth][omniauth].

# Usage

In your `Gemfile` add `gem 'omniauth-azure_active_directory_b2c'`.

In your codebase add `require 'omniauth-azure_active_directory_b2c'`.

# Configuration

Configuration depends on your stack... are you using a vanilla Rack application?  Are you using Rails with the Devise and OmniAuth module?  Are you using Rails directly with the OmniAuth gem? Are you using Sinatra?

## Rails, Devise, and the OmniAuth module

In `config/initializers/devise.rb`:

```ruby
config.omniauth :azure_active_directory_b2c, strategy_options
```

Head over to the [Devise repo][devise] and the [OmniAuth Module Overview][devise_omniauth] for further instructions on how to set up routes, controllers, etc.

See the next section for the strategy options.

## Rails and the OmniAuth gem

In `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :azure_active_directory_b2c, strategy_options
end
```

## Sinatra

```ruby
class MyApp < Sinatra::Base
  use Rack::Session::Cookie
  use OmniAuth::Builder do
    provider :azure_active_directory_b2c, strategy_options
  end

  get '/auth/:provider' do
    raise "OmniAuth provider has not been configured: %s" % params['provider']
  end

  get '/auth/:provider/callback' do
    env['omniauth.auth']
  end

end
```

Head over to [the OmniAuth repo][omniauth] and its [wiki][omniauth_wiki] for further background and instructions.

See the next section for the strategy options.

# Strategy Options

This strategy accepts the following options:

Option | Required | Description |
------ | -------- | ----------- |
`:name` | Optional | Sets the provider name used in the request and callback URLs.  Defaults to `'azure_active_directory_b2c'`.
`:redirect_uri` | Required | The absolute url sent to the Azure AD B2C policy to initiate the callback phase.
`:policy` | `policy` or `policy_options` Required | Provides an object that matches the OmniAuth::Strategies::AzureActiveDirectoryB2C::PolicyOptions interface.
`:policy_options` | `policy` or `policy_options` Required | A hash used to initialize an `OmniAuth::Strategies::AzureActiveDirectoryB2C::Policy object`.
`:authentication_request` | Optional | Provides an object that matches the `OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationRequest` interface.
`:authentication_response` | Optional | Provides an object that matches the `OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationResponse` interface
`:validate_callback_response` | Optional | Overrides the validation provided by this gem

Additional info for each option will follow.

This is a complete example:

```ruby
use OmniAuth::Builder do
  provider :azure_active_directory_b2c, {
    redirect_uri: ->(name) { 'http://localhost:9292/auth/%s/callback' % name },
    policy_options: {
      application_identifier: '00000000-0000-0000-0000-000000000000',
      application_secret: '****************',
      tenant_name: 'example.onmicrosoft.com',
      policy_name: 'b2c_1_signupin',
      scope: [
          :openid,
          'https://example.onmicrosoft.com/example-api/user_impersonation',
          'https://example.onmicrosoft.com/example-api/read',
          'https://example.onmicrosoft.com/example-api/write',
        ],
      jwk_signing_keys: {'keys' => [{ 'kid' => '...', 'n' => '...' }]},
    }
  }
end
```

## `:name`

By default, `:name` is set to `azure_active_directory_b2c`.

This tells the OmniAuth gem what to name the request and callback URLs.

Eg. `GET /auth/:name` and `GET /auth/:name/callback`.

When you direct a user to `GET /auth/azure_active_directory_b2c`, the `request_phase` of this strategy will be initiated and the user will be redirected to the `authorize` endpoint of the Azure Acitve Directory B2C Policy.

When the Azure Active Directory B2C Policy returns, it will return to the given `redirect_url` which should, by default, match up to `GET /auth/azure_active_directory_b2c/callback`.  This will initiate the `callback_phase` of this strategy.  The strategy uses the `code` returned from the policy to request an `access_code` and `id_token` from the policy.

The unencrypted user information will be available `env['omniauth.auth']`.

## `:redirect_uri`

This is required as the URI must be absolute.  The option can be used in one of two ways:

Pass in a String:
```ruby
provider :azure_active_directory_b2c, redirect_uri: 'https://localhost:9292/auth/azure_active_directory_b2c/callback'
```

Pass in a Proc that returns a String:
```ruby
provider :azure_active_directory_b2c, {
  redirect_uri: ->(name, options, params, request) {
    'https://localhost:9292/auth/%s/callback' % name
  }
}
```

You must ensure that `redirect_uri` is registered with the Application  Azure AD B2C  otherwise you will get errors.

## `:policy` and `:policy_options`

These options provide the configuation for the Azure AD B2C Tenant, Application, and Policy being used as the Identity Provider.

A hash can be passed to `policy_options` specifying the following:
- `:application_identifier`
- `:application_secret`
- `:tenant_name`: This is the Domain Name or Resource name found in the Overview blade in the Azure AD B2C portal.
- `:policy_name`: The name of the policy that the user should be redirected to and authenticated against
- `:scope`: Defaults to `[:openid]`, but can be overriden to request specific api permissions.  Eg. `[:openid, 'https://example.onmicrosoft.com/example-api/user_impersonation']`.  See the microsoft docs form more info: [here][ms_scopes] and [here][ms_oauth_code].
- `:jwk_signing_keys`: This is required to decode the `id_token` returned from the `token` endpoint.  The key can be found by going to the url that is specified in `jwks_uri` parameter at the policy's `.well-known/openid-configuration` page.  Eg: `https://login.microsoftonline.com/te/example.onmicrosoft.com/b2c_1_signupin/discovery/v2.0/keys`.

Alternatively, an object or Proc can be passed to the `:policy` option.
The object returned can be either:
* a subclass of `OmniAuth::Strategies::AzureActiveDirectoryB2C::Policy`, or;
* include the module `OmniAuth::Strategies::AzureActiveDirectoryB2C::PolicyOptions`
The usecase for doing this is to allow your application to dynamically use multiple Azure AD B2C Policies from multiple tenants.

Eg: Dynamically select a policy base on URL params `GET /auth/azure_active_directory_b2c?policy_name=test`
```ruby
# app/models/policy.rb
class Policy < ActiveRecord::Base
  include OmniAuth::Strategies::AzureActiveDirectoryB2C::PolicyOptions
end

# config/initializers/devise.rb
config.omniauth :azure_active_directory_b2c, {
  redirect_uri: ->(name) { 'http://localhost:9292/auth/%s/callback' % name },
  policy: ->(options, params, request) {
    policy_name = params['policy_name']
    policy = Policy.find_by(name: policy_name)
    raise "Policy with the given name not found : #{policy_name}" unless policy
    policy
  }
}
end
```

## `:authentication_request` and `:authentication_response`

Generally these options will not be used.

These two options allow the developer to provide their own implementation of `OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationRequest` and `OmniAuth::Strategies::AzureActiveDirectoryB2C::AuthenticationResponse`.

This may be necessary if the developer wants to
- use an unsupported authorization flow
- use a different decoding algorithm for the access code and id token
- access different claims returned in the id_token

## `:validate_callback_response`

The default validation can be overriden by passing a Proc to the `validate_callback_response` option.

Eg:
```ruby
class CustomError < OmniAuth::Strategies::AzureActiveDirectoryB2C::CallbackError
  failure_message_key :custom_error
end

use OmniAuth::Builder do
  provider :azure_active_directory_b2c, {
    validate_callback_response: ->(params, request) {
      if params['code'].nil?
        raise CustomError, 'Something went wrong'
      end
    }
  }
end
```

# Known Limitations

* The strategy only supports the `code` authorization flow.
* The gem doesnt support discovery, but neither does Azure AD B2C as far as I can tell.

[devise]: https://github.com/plataformatec/devise
[devise_omniauth]: https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview
[omniauth]: https://github.com/omniauth/omniauth
[omniauth_wiki]: https://github.com/omniauth/omniauth/wiki
[ms_scopes]: https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-access-tokens
[ms_oauth_code]: https://docs.microsoft.com/en-us/azure/active-directory-b2c/active-directory-b2c-reference-oauth-code
