require File.join(File.dirname(__FILE__), 'rails_requirer')

module ObjectifiedEnvironments
  class Railtie < Rails::Railtie
    initializer "objectified_environments.setup", :before => :load_environment_config do |app|
      autoload_directory = File.expand_path(File.join(Rails.root, 'config', 'lib'))
      ActiveSupport::Dependencies.autoload_paths << autoload_directory

      unless defined?(Rails) && Rails.kind_of?(Module)
        raise %{ObjectifiedEnvironments declares a dependency on Rails, and Rails appears to be
running our initialization code (the Railtie), yet Rails does not appear to be defined as a module.
We don't know what's wrong, and are bailing out lest we cause more problems. Please report this
issue, including the version of Rails you are running: #{Rails.version}.}
      end

      module ::Rails
        class << self
          def objenv
            @_objectified_environment ||= ObjectifiedEnvironments.create_objectified_environment
          end
        end
      end
    end
  end
end
