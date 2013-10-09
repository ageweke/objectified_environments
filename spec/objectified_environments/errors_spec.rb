require 'objectified_environments/errors'

describe ObjectifiedEnvironments do
  it "should have the right hierarchy" do
    ObjectifiedEnvironments::ObjectifiedEnvironmentError.superclass.should == StandardError
    ObjectifiedEnvironments::EnvironmentMissingError.superclass.should == ObjectifiedEnvironments::ObjectifiedEnvironmentError
    ObjectifiedEnvironments::UnableToInstantiateEnvironmentError.superclass.should == ObjectifiedEnvironments::ObjectifiedEnvironmentError
  end

  it "should be able to be created with just a message" do
    m = "foo"

    lambda { ObjectifiedEnvironments::ObjectifiedEnvironmentError.new(m) }.should_not raise_error
    lambda { ObjectifiedEnvironments::EnvironmentMissingError.new(m) }.should_not raise_error
    lambda { ObjectifiedEnvironments::UnableToInstantiateEnvironmentError.new(m) }.should_not raise_error
  end
end
