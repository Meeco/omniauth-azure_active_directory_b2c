require_relative 'lib/omniauth/strategies/azure_active_directory_b2c/version.rb'

Gem::Specification.new do |spec|
  spec.name = 'omniauth-azure_active_directory_b2c'
  spec.version = OmniAuth::Strategies::AzureActiveDirectoryB2C::VERSION

  spec.summary = 'Azure AD B2C Strategy for OmniAuth.'
  spec.homepage = 'https://github.com/Meeco/omniauth-azure_active_directory_b2c'
  spec.licenses = ['MIT']
  spec.email = 'developers@meeco.me'

  spec.authors = [
    'Brent Jacobs',
    'NextFaze',
    'Meeco',
    'Fishz',
    'kefon94'
  ]

  spec.files = [
      'lib/omniauth-azure_active_directory_b2c.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c/authentication_request.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c/authentication_response.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c/client.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c/jwt_validator.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c/policy_options.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c/policy.rb',
      'lib/omniauth/strategies/azure_active_directory_b2c/version.rb',
    ]

  spec.add_dependency 'omniauth', '~> 2.0'
  spec.add_dependency 'openid_connect', '~> 1.1'
end
