require "objectified_environments/version"
require "objectified_environments/railtie"
require "objectified_environments/data_provider"
require "objectified_environments/environment_builder"
require "objectified_environments/base"
require "objectified_environments_generator"

module ObjectifiedEnvironments
  class << self
    def create_objectified_environment
      eb = environment_builder.new(data_provider)
      eb.environment
    end

    private
    def environment_builder
      ObjectifiedEnvironments::EnvironmentBuilder
    end

    def data_provider
      @data_provider ||= ObjectifiedEnvironments::DataProvider.new
    end
  end
end
