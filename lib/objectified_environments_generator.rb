require File.join(File.dirname(__FILE__), 'objectified_environments/rails_requirer')

class ObjectifiedEnvironmentsGenerator < Rails::Generators::Base
  def create_environment_files
    needed_environments = all_environments.select { |e| (! environment_defined?(e)) }

    needed_environments.each do |environment|
      create_environment(environment)
    end

    create_superclasses_for(needed_environments)
  end

  private
  def create_environment(environment)
    target_file = File.join(objenv_dir, "#{environment.underscore}.rb")

    if File.exist?(target_file)
      puts "skip #{target_file}"
    else
      create_file(target_file) do
        content_for_environment(environment)
      end
    end
  end

  def create_superclasses_for(environments)
    superclasses = environments.map { |e| superclass_for_environment(e) }.uniq
    superclasses -= [ "ObjectifiedEnvironments::Base" ]
    superclasses = superclasses.map do |sc|
      if sc =~ /::([A-Z0-9_]+)$/i
        $1
      else
        sc
      end
    end

    unless superclasses.length == 0
      superclasses.each { |sc| create_environment(sc) }
      create_superclasses_for(superclasses)
    end
  end

  DEFAULT_ENVIRONMENT_SUPERCLASS = 'Objenv::Environment'
  ENVIRONMENT_HIERARCHY = {
    'Environment' => "ObjectifiedEnvironments::Base",

    'LocalEnvironment' => 'Environment',
    'Development' => 'LocalEnvironment',
    'Test' => 'LocalEnvironment',

    'ProductionEnvironment' => 'Environment',
    'Production' => 'ProductionEnvironment'
  }
  ENVIRONMENTS_MODULE = "Objenv"

  CLASS_COMMENTS = { }
  CLASS_COMMENTS['Environment'] = <<-EOS
# This is the root class of all of your objectified environments -- i.e., all the other
# classes in config/lib/objenv. As such, it defines the behavior of a "default" environment,
# with subclasses overriding its methods as needed.
#
# You might think that this is useless -- after all, the whole point of environments is to
# define things that *aren't* common across RAILS_ENV settings, so what could possibly go
# here? However, you'll find that several things are useful about this class:
#
#   - If you define all methods here and simply call #must_implement (defined in
#     ObjectifiedEnvironments::Base) in them, then you'll have an elegant template that
#     immediately shows everybody exactly what varies based on environment and what they
#     need to think about/override when creating a new environment.
#
#   - Often, you'll want to define methods on the environment that actually include a
#     little bit of functionality -- like creating and returning a Memcached client, for
#     example. This can therefore be a nice place to put the structure of those methods.
#     (The method that the rest of the code actually calls directly can be defined here,
#     while subclasses override methods that provide crucial information -- like the name
#     of the Memcached host, for example -- that this method uses to do its work.)
#
#   - You may well have cases where nearly all environments behave identically, but only
#     one or two vary. It therefore makes a lot of sense to put the default behavior
#     here, and override as necessary only in those one or two cases.
#
# Note that the inheritance hierarchy here is only suggested and part of the
# objectified_environments generator, but not the core Gem code itself. You can change and
# rearrange things to your heart's content.
EOS

  CLASS_COMMENTS['LocalEnvironment'] = <<-EOS
# This class is a descendent of the base Environment class and is inherited by Development
# and Test, the two environments that typically run locally (i.e., not on a remote server).
# It's very common that these two environments share a lot of settings in common -- hence
# the case for this class.
#
# Note that the inheritance hierarchy here is only suggested and part of the
# objectified_environments generator, but not the core Gem code itself. You can change and
# rearrange things to your heart's content.
EOS

  CLASS_COMMENTS['Development'] = <<-EOS
# This class defines environment settings when RAILS_ENV == 'development'.
#
# If you have settings to define that also apply to Test, please consider placing them
# in LocalEnvironment, the superclass of this class, instead. You'll keep your code DRYer.
#
# Note that the inheritance hierarchy here is only suggested and part of the
# objectified_environments generator, but not the core Gem code itself. You can change and
# rearrange things to your heart's content.
EOS

  CLASS_COMMENTS['Test'] = <<-EOS
# This class defines environment settings when RAILS_ENV == 'test'.
#
# If you have settings to define that also apply to Development, please consider placing them
# in LocalEnvironment, the superclass of this class, instead. You'll keep your code DRYer.
#
# Note that the inheritance hierarchy here is only suggested and part of the
# objectified_environments generator, but not the core Gem code itself. You can change and
# rearrange things to your heart's content.
EOS

  CLASS_COMMENTS['ProductionEnvironment'] = <<-EOS
# This class is a descendent of the base Environment class and is inherited by Production.
# While this may seem a bit silly -- why have an intermediate class between Environment and
# Production at all? -- there's a good reason for it. It's exceptionally common to create
# 'production-like' environments, like 'qa', 'beta', and so on. These environments very often
# share a great number of environment settings, and this class is a perfect place to put
# that code. If you start from the beginning separating out settings that apply to "any
# environment that's like production" from "only production itself", adding these environments
# in the future gets to be a whole lot easier.
#
# Note that the inheritance hierarchy here is only suggested and part of the
# objectified_environments generator, but not the core Gem code itself. You can change and
# rearrange things to your heart's content.
EOS

  CLASS_COMMENTS['Production'] = <<-EOS
# This class defines environment settings when RAILS_ENV == 'production'.
#
# Please see the comment at the top of ProductionEnvironment, as well. If you have settings
# that apply to 'any production-like environment' rather than 'only production itself', putting
# that code in ProductionEnvironment instead of in this class will likely serve you better
# in the long run.
#
# Note that the inheritance hierarchy here is only suggested and part of the
# objectified_environments generator, but not the core Gem code itself. You can change and
# rearrange things to your heart's content.
EOS

  def content_for_environment(environment)
    %{#{CLASS_COMMENTS[environment.camelize] || ''}
module #{ENVIRONMENTS_MODULE}
  class #{environment.camelize} < #{superclass_for_environment(environment)}
    # Add your own method definitions here!
  end
end
}
  end

  def superclass_for_environment(environment)
    ENVIRONMENT_HIERARCHY[environment.camelize] || DEFAULT_ENVIRONMENT_SUPERCLASS
  end

  def environment_defined?(environment)
    target_class_name = "#{ENVIRONMENTS_MODULE}::#{environment.camelize}"
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
    @objenv_dir ||= File.join(config_lib_dir, ENVIRONMENTS_MODULE.underscore)
  end

  def current_environment
    Rails.env
  end
end
