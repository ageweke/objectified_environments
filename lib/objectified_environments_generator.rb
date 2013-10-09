require 'rails/generators'

class ObjectifiedEnvironmentsGenerator < Rails::Generators::Base
  def create_environment_files
    needed_environments = all_environments.select { |e| (! environment_defined?(e)) }

    needed_environments.each do |environment|
      create_environment(environment)
    end

    create_local_environment_if_needed!(needed_environments)
  end

  private
  def create_environment(environment)
    target_file = File.join(objenv_dir, "#{environment}.rb")

    if File.exist?(target_file)
      puts "skip #{target_file}"
    else
      create_file(target_file) do
        content_for_environment(environment)
      end
    end
  end

  LOCAL_ENVIRONMENT_DESCENDENTS = %w{development test}

  def create_local_environment_if_needed!(needed_environments)
    if (needed_environments & LOCAL_ENVIRONMENT_DESCENDENTS).length > 0
      target_file = File.join(objenv_dir, 'local_environment.rb')

      unless File.exist?(target_file)
        create_file(target_file) do
          content_for_environment('local_environment')
        end
      end
    end
  end

  def content_for_environment(environment)
    %{module Objenv
  class #{environment.camelize} < #{superclass_for_environment(environment)}
    # Add your own method definitions here!
  end
end
}
  end

  def superclass_for_environment(environment)
    if LOCAL_ENVIRONMENT_DESCENDENTS.include?(environment)
      "LocalEnvironment"
    else
      "ObjectifiedEnvironments::Base"
    end
  end

  def environment_defined?(environment)
    target_class_name = "Objenv::#{environment.camelize}"
    begin
      target_class_name.constantize
      true
    rescue NameError => ne
      false
    end
  end

  def all_environments
    config_environments | [ current_environment ]
  end

  def config_environments
    return [ ] unless File.directory?(config_environments_dir)

    Dir.entries(config_environments_dir).map do |entry|
      $1.downcase if entry =~ /^([A-Z0-9_]+)\.rb$/i
    end.compact
  end

  def config_dir
    @config_dir ||= File.expand_path(File.join(Rails.root, 'config'))
  end

  def config_environments_dir
    @config_environments_dir ||= File.join(config_dir, 'environments')
  end

  def config_lib_dir
    @config_lib_dir ||= File.join(config_dir, 'lib')
  end

  def objenv_dir
    @objenv_dir ||= File.join(config_lib_dir, 'objenv')
  end

  def current_environment
    Rails.env
  end
end
