require 'objectified_environments/base'

describe ObjectifiedEnvironments::Base do
  it "should hold environment data" do
    b = ObjectifiedEnvironments::Base.new(:rails_env => 'foo', :user_name => 'bar', :host_name => 'baz')
    b.send(:rails_env).should == 'foo'
    b.send(:user_name).should == 'bar'
    b.send(:host_name).should == 'baz'
  end

  it "should not require any data but rails_env" do
    b = ObjectifiedEnvironments::Base.new(:rails_env => 'foo')
    b.send(:rails_env).should == 'foo'
    b.send(:user_name).should == nil
    b.send(:host_name).should == nil
  end

  it "should not expose this data by default" do
    lambda { b.rails_env }.should raise_error
    lambda { b.user_name }.should raise_error
    lambda { b.host_name }.should raise_error
  end

  it "should implement #must_implement as something that raises" do
    b = ObjectifiedEnvironments::Base.new(:rails_env => 'foo')
    class << b
      def foo
        must_implement
      end
    end

    lambda { b.foo }.should raise_error
  end
end
