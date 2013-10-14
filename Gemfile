source 'https://rubygems.org'

# Specify your gem's dependencies in objectified_environments.gemspec
gemspec

rails_version = ENV['OBJECTIFIED_ENVIRONMENTS_RAILS_TEST_VERSION']
rails_version = rails_version.strip if rails_version

version_spec = case rails_version
when nil then nil
when 'master' then { :git => 'git://github.com/rails/rails.git' }
else "=#{rails_version}"
end

if version_spec
  $stderr.puts "VERSION_SPEC: #{version_spec}"
  gem("rails", version_spec)
end
