module ObjectifiedEnvironments
  class Base
    def initialize(environment_properties)
      @rails_env = environment_properties[:rails_env]
      @user_name = environment_properties[:user_name]
      @host_name = environment_properties[:host_name]
    end

    private
    attr_reader :rails_env, :user_name, :host_name

    def must_implement
      raise "You must override this method in #{self.class.name} or a superclass."
    end
  end
end
