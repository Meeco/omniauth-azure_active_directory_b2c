# OmniAuth::Strategies::AzureActiveDirectoryB2C

This gem is an Azure Active Directory B2C Strategy for [OmniAuth]

# Usage

In your `Gemfile` add `gem 'omniauth-azure_active_directory_b2c'`.

In your codebase add `require 'omniauth-azure_active_directory_b2c'`.

# Configuration

## Rails using Devise

In `config/initializers/devise.rb`:

```ruby
config.omniauth :openid_connect, strategy_options
```


[1]: https://github.com/omniauth/omniauth
