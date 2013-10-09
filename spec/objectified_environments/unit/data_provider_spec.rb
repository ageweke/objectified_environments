require 'objectified_environments/data_provider'

describe ObjectifiedEnvironments::DataProvider do
  it "should be instantiable with no arguments" do
    lambda { subject.class.new }.should_not raise_error
  end

  describe "Rails.env" do
    it "should expose correctly" do
      expect(Rails).to receive(:env).once { 'bongo' }
      subject.rails_env.should == 'bongo'
    end

    it "should raise an error if there's none" do
      expect(Rails).to receive(:env).once { nil }
      lambda { subject.rails_env }.should raise_error
    end
  end

  describe "user_name" do
    before(:each) { @saved_env = { }; ENV.each { |k,v| @saved_env[k] = v } }
    after(:each) { @saved_env.each { |k,v| ENV[k] = v } }

    context "Etc.getlogin" do
      require 'etc'

      it "should return this first" do
        expect(Etc).to receive(:getlogin).once { 'marph' }
        subject.user_name.should == 'marph'
      end

      it "should skip this if blank" do
        expect(Etc).to receive(:getlogin).once { '  ' }
        ENV['USER'] = 'foo'

        subject.user_name.should == 'foo'
      end

      it "should skip this if nil" do
        expect(Etc).to receive(:getlogin).once { nil }
        ENV['USER'] = 'bar'

        subject.user_name.should == 'bar'
      end
    end

    context "environment variables" do
      def check_env(user, logname, username, expected_result)
        ENV['USER'] = user
        ENV['LOGNAME'] = logname
        ENV['USERNAME'] = username

        allow(Etc).to receive(:getlogin) { nil }

        dp = subject.class.new
        dp.user_name.should == expected_result
      end

      it "should check them in the right order" do
        check_env('foo', 'bar', 'baz', 'foo')
        check_env('   ', 'bar', 'baz', 'bar')
        check_env(nil, 'bar', 'baz', 'bar')

        check_env(nil, '   ', 'baz', 'baz')
        check_env(nil, nil, 'baz', 'baz')
      end

      it "should return nil if nothing is available" do
        check_env(nil, nil, nil, nil)
      end
    end
  end

  describe "host_name" do
    require 'socket'

    def set_hostname_from_hostname_command(dp, x)
      class << dp
        def specified_host_name=(x)
          @_specified_host_name = x
        end

        def host_name_from_hostname_command
          @_specified_host_name
        end
      end

      dp.specified_host_name = x
    end

    it "should return it from the hostname command by default" do
      set_hostname_from_hostname_command(subject, 'baz')
      subject.host_name.should == 'baz'
    end

    it "should strip whitespace from the hostname command and normalize it" do
      set_hostname_from_hostname_command(subject, "\n    Ba-Z\n  \n")
      subject.host_name.should == 'ba_z'
    end

    it "should skip the hostname command if blank" do
      set_hostname_from_hostname_command(subject, '   ')
      expect(Socket).to receive(:gethostname).once { 'foo' }
      subject.host_name.should == 'foo'
    end

    it "should skip the hostname command if nil" do
      set_hostname_from_hostname_command(subject, nil)
      expect(Socket).to receive(:gethostname).once { 'foo' }
      subject.host_name.should == 'foo'
    end

    it "should skip the hostname command if garbage" do
      set_hostname_from_hostname_command(subject, '$#@*($')
      expect(Socket).to receive(:gethostname).once { 'foo' }
      subject.host_name.should == 'foo'
    end

    it "should skip the hostname command if not a Ruby identifier" do
      set_hostname_from_hostname_command(subject, '0bar')
      expect(Socket).to receive(:gethostname).once { 'foo' }
      subject.host_name.should == 'foo'
    end

    it "should skip Socket.gethostname if blank" do
      set_hostname_from_hostname_command(subject, nil)
      expect(Socket).to receive(:gethostname).once { '   ' }
      subject.host_name.should be_nil
    end

    it "should skip Socket.gethostname if nil" do
      set_hostname_from_hostname_command(subject, nil)
      expect(Socket).to receive(:gethostname).once { nil }
      subject.host_name.should be_nil
    end

    it "should skip Socket.gethostname if garbage" do
      set_hostname_from_hostname_command(subject, nil)
      expect(Socket).to receive(:gethostname).once { "$*(@$" }
      subject.host_name.should be_nil
    end

    it "should skip Socket.gethostname if not a Ruby identifir" do
      set_hostname_from_hostname_command(subject, nil)
      expect(Socket).to receive(:gethostname).once { "0foo" }
      subject.host_name.should be_nil
    end

    it "should skip Socket.gethostname if it raises" do
      set_hostname_from_hostname_command(subject, nil)
      expect(Socket).to receive(:gethostname).once { raise "kaboom!" }
      subject.host_name.should be_nil
    end
  end
end
