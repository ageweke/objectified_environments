module ObjectifiedEnvironments
  class ObjectifiedEnvironmentError < StandardError; end
  class EnvironmentMissingError < ObjectifiedEnvironmentError; end
  class UnableToInstantiateEnvironmentError < ObjectifiedEnvironmentError; end
end
