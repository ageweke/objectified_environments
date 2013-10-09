require 'objectified_environments/environment_builder'

describe ObjectifiedEnvironments::EnvironmentBuilder do
  class FakeDataProvider
    def initialize(rails_env, user_name, host_name)
      @rails_env = rails_env
      @user_name = user_name
      @host_name = host_name
    end

    attr_reader :rails_env, :user_name, :host_name
  end

  def new_with(*args)
    fake_data_provider = FakeDataProvider.new(*args)
    ObjectifiedEnvironments::EnvironmentBuilder.new(fake_data_provider)
  end

  describe "construction" do
    it "should require a non-blank, non-nil Rails.env" do
      lambda { new_with('  ', nil, nil) }.should raise_error
      lambda { new_with(nil, nil, nil) }.should raise_error
    end

    it "should work with just a Rails.env" do
      lambda { new_with('foo', nil, nil) }.should_not raise_error
    end
  end

  describe "#environment" do
    def define_classes_for(name_or_names, options = { }, &block)
      names = Array(name_or_names)

      names.each do |name|
        n = name
        root = Object

        while n =~ /^([^:]+)::(.*)$/
          module_name = $1; n = $2
          is_defined = eval("defined?(#{module_name})")
          unless is_defined
            root.module_eval "module #{module_name}; end"
          end
          root = eval("#{root.name}::#{module_name}")
        end

        root.module_eval "class #{name}; end"
      end

      block.call

      names.each do |name|
        root = Object
        if name =~ /^(.*)::([^:]+)$/
          root = $1.constantize
          name = $2
        end

        root.send(:remove_const, name.to_sym)
      end
    end

    context "simple Rails.env classes" do
      it "should create an environment just named after Rails.env if defined" do
        define_classes_for('Objenv::Foo') do
          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::Foo
        end
      end

      it "should create an environment just named after Rails.env even if user and host are missing" do
        define_classes_for('Objenv::Foo') do
          env = new_with('foo', nil, nil).environment
          env.class.should == Objenv::Foo
        end
      end

      it "should fail with a nice error message if the class is not defined, showing what we looked for" do
        define_classes_for('Objenv::Marph') do
          eb = new_with('foo', 'bar', 'baz')

          exception = nil
          begin
            eb.environment
          rescue ObjectifiedEnvironments::EnvironmentMissingError => eme
            exception = eme
          end

          exception.should_not be_nil

          exception.message.should =~ /foo/
          exception.message.should =~ /bar/
          exception.message.should =~ /baz/

          exception.message.should =~ /Objenv::Foo/
          exception.message.should =~ /Objenv::User::BarFoo/
          exception.message.should =~ /Objenv::Host::BazFoo/
          exception.message.should =~ /Objenv::UserHost::BarBazFoo/
        end
      end

      it "should fail with a nice error message if the class blows up upon instantiation" do
        define_classes_for('Objenv::Foo') do
          class Objenv::Foo
            def initialize(*args)
              raise "kaboomba"
            end
          end

          eb = new_with('foo', 'bar', 'baz')

          exception = nil
          begin
            eb.environment
          rescue ObjectifiedEnvironments::UnableToInstantiateEnvironmentError => utiee
            exception = utiee
          end

          exception.should_not be_nil

          exception.message.should =~ /Objenv::Foo/
          exception.message.should =~ /kaboomba/
        end
      end

      it "should fail with a nice error message if the class's constructor takes too many parameters" do
        define_classes_for('Objenv::Foo') do
          class Objenv::Foo
            def initialize(x, y)
              # ok
            end
          end

          eb = new_with('foo', 'bar', 'baz')

          exception = nil
          begin
            eb.environment
          rescue ObjectifiedEnvironments::UnableToInstantiateEnvironmentError => utiee
            exception = utiee
          end

          exception.should_not be_nil

          exception.message.should =~ /Objenv::Foo/
        end
      end

      it "should pass in environment information if the class accepts it" do
        define_classes_for('Objenv::Foo') do
          class Objenv::Foo
            def initialize(h)
              @h = h
            end
            attr_reader :h
          end

          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::Foo
          env.h[:rails_env].should == 'foo'
          env.h[:user_name].should == 'bar'
          env.h[:host_name].should == 'baz'
        end
      end

      it "should pass in environment information if the class accepts it with optional arguments" do
        define_classes_for('Objenv::Foo') do
          class Objenv::Foo
            def initialize(h, x = nil, y = nil)
              @h = h
            end
            attr_reader :h
          end

          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::Foo
          env.h[:rails_env].should == 'foo'
          env.h[:user_name].should == 'bar'
          env.h[:host_name].should == 'baz'
        end
      end
    end

    context "with a username" do
      it "should prefer a username-specified class" do
        define_classes_for([ 'Objenv::User::BarFoo', 'Objenv::Foo' ]) do
          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::User::BarFoo
        end
      end

      it "should not require a Rails-env-only class" do
        define_classes_for([ 'Objenv::User::BarFoo' ]) do
          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::User::BarFoo
        end
      end
    end

    context "with a hostname" do
      it "should prefer a hostname-specified class" do
        define_classes_for([ 'Objenv::Host::BazFoo', 'Objenv::Foo' ]) do
          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::Host::BazFoo
        end
      end

      it "should not require a Rails-env-only class" do
        define_classes_for([ 'Objenv::Host::BazFoo' ]) do
          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::Host::BazFoo
        end
      end
    end

    context "with a username and hostname both" do
      it "should prefer a username-and-hostname-specified class" do
        define_classes_for([ 'Objenv::UserHost::BarBazFoo', 'Objenv::Host::BazFoo', 'Objenv::User::BarFoo', 'Objenv::Foo' ]) do
          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::UserHost::BarBazFoo
        end
      end

      it "should not require any other classes" do
        define_classes_for([ 'Objenv::UserHost::BarBazFoo' ]) do
          env = new_with('foo', 'bar', 'baz').environment
          env.class.should == Objenv::UserHost::BarBazFoo
        end
      end
    end
  end
end
