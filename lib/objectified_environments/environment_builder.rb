require 'objectified_environments/errors'

module ObjectifiedEnvironments
  class EnvironmentBuilder
    def initialize(data_provider)
      @rails_env = normalize(data_provider.rails_env)
      @user_name = normalize(data_provider.user_name)
      @host_name = normalize(data_provider.host_name)

      raise ArgumentError, "@rails_env is required: #{rails_env.inspect}" unless @rails_env && @rails_env.strip.length > 0
    end

    def environment
      candidate_names = [ ]

      candidate_names << class_name_for_candidate(@rails_env, @user_name, @host_name) if @user_name && @host_name
      candidate_names << class_name_for_candidate(@rails_env, nil, @host_name) if @host_name
      candidate_names << class_name_for_candidate(@rails_env, @user_name, @nil) if @user_name
      candidate_names << class_name_for_candidate(@rails_env, nil, nil)

      raise "This should be impossible: we should always have a candidate" unless candidate_names.length > 0

      out = nil
      candidate_names.each do |candidate_name|
        klass = begin
          candidate_name.constantize
        rescue NameError
          nil
        end

        return instantiate_from_class(klass) if klass
      end

      no_environment_found!(candidate_names)
    end

    private
    def normalize(s)
      s.strip unless (!s) || (s.strip.length == 0)
    end

    def class_name_for_candidate(rails_env, user_name, host_name)
      rails_env = normalize(rails_env)
      user_name = normalize(user_name)
      host_name = normalize(host_name)

      if user_name && host_name
        target = "#{user_name}_#{host_name}_#{rails_env}"
        "Objenv::UserHost::#{target.camelize}"
      elsif host_name
        target = "#{host_name}_#{rails_env}"
        "Objenv::Host::#{target.camelize}"
      elsif user_name
        target = "#{user_name}_#{rails_env}"
        "Objenv::User::#{target.camelize}"
      else
        "Objenv::#{rails_env.camelize}"
      end
    end

    def instantiate_from_class(klass)
      begin
        constructor = klass.instance_method(:initialize)

        args = [ ]
        if constructor.arity != 0
          args = [ { :rails_env => @rails_env, :user_name => @user_name, :host_name => @host_name } ]
        end

        return klass.new(*args)
      rescue => e
        raise ObjectifiedEnvironments::UnableToInstantiateEnvironmentError, %{We found a valid objectified environment class '#{klass.name}', but,
when we tried to instantiate it, we got the following exception:

#{e.class.name}: #{e.message}
#{e.backtrace.join("\n")}}
      end
    end

    def no_environment_found!(candidate_names)
      raise ObjectifiedEnvironments::EnvironmentMissingError, %{No ObjectifiedEnvironment definition was found.

Rails.env: #{@rails_env.inspect}
Username:  #{@user_name.inspect}
Host name: #{@host_name.inspect}

This caused us to look for any environment named one of these (in order):

#{candidate_names.join("\n")}

...but none of those exist.

You may want to run 'rails generate objectified_environments'.
}
    end
  end
end
