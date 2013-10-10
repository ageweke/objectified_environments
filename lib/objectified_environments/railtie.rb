module ObjectifiedEnvironments
  class Railtie < Rails::Railtie
    initializer "objectified_environments.add_autoload_path", :before => :set_autoload_paths do |app|
      autoload_directory = File.expand_path(File.join(Rails.root, 'config', 'lib'))

      # I know this works with Rails 3.0.0
      ActiveSupport::Dependencies.autoload_paths << autoload_directory
      # Maybe this is for 4.0.0?
      # Rails.application.config.autoload_paths << autoload_directory
    end

    initializer "objectified_environments.configure_rails_initialization" do |app|
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
