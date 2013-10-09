require 'objectified_environments/errors'

module ObjectifiedEnvironments
  class EnvironmentBuilder
    def initialize(data_provider)
      @rails_env = data_provider.rails_env
      @user_name = data_provider.user_name
      @host_name = data_provider.host_name

      raise ArgumentError, "@rails_env is required: #{rails_env.inspect}" unless @rails_env && @rails_env.strip.length > 0
    end

    def environment
      candidates = [
        maybe_candidate(@user_name, @host_name, @rails_env),
        maybe_candidate(@host_name, @rails_env),
        maybe_candidate(@user_name, @rails_env),
        maybe_candidate(@rails_env)
      ].compact

      raise "This should be impossible: we should always have a candidate" unless candidates.length > 0

      out = nil
      candidates.each do |candidate|
        klass = class_for_candidate(candidate)
        return instantiate_from_class(klass) if klass
      end

      no_environment_found!(candidates)
    end

    private
    def maybe_candidate(*args)
      missing_args = false
      args.each do |a|
        missing_args = true if (! a) || (a.strip.length == 0)
      end
      return nil if missing_args

      args.join("_")
    end

    def class_name_for_candidate(candidate)
      "Objenv::#{candidate.camelize}"
    end

    def class_for_candidate(candidate)
      class_name = class_name_for_candidate(candidate)

      out = begin
        class_name.constantize
      rescue NameError
        nil
      end

      out
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

    def no_environment_found!(candidates)
      raise ObjectifiedEnvironments::EnvironmentMissingError, %{No ObjectifiedEnvironment definition was found.

Rails.env: #{@rails_env.inspect}
Username:  #{@user_name.inspect}
Host name: #{@host_name.inspect}

This caused us to look for any environment named one of these (in order):

#{candidates.map { |c| class_name_for_candidate(c) }.join("\n")}

...but none of those exist.

You may want to run 'rails generate objectified_environments'.
}
    end
  end
end
