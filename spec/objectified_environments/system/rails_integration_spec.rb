require File.join(File.dirname(__FILE__), '..', 'helpers', 'rails_helper')
require File.join(File.dirname(__FILE__), '..', 'helpers', 'command_helpers')

describe "ObjectifiedEnvironments Rails integration" do
  include ObjectifiedEnvironments::Specs::Helpers::CommandHelpers

  before :each do
    @gem_root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
    tmp_dir = File.join(@gem_root, 'tmp')
    @rails_helper = ObjectifiedEnvironments::Specs::Helpers::RailsHelper.new(tmp_dir)
  end

  after :each do
    # FileUtils.rm_rf(File.dirname(@rails_root))
  end

  def lib_objenv_dir
    File.join('config', 'lib', 'objenv')
  end

  def splat_file(path, contents)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') { |f| f << contents }
  end

  def append_file(path, contents)
    File.open(path, 'a') { |f| f << contents }
  end

  it "should instantiate and use whatever environment is specified by default" do
    @rails_helper.with_new_rails_installation do
      append_file('Gemfile', "gem 'objectified_environments', :path => '#{@gem_root}'")
      splat_file(File.join(lib_objenv_dir, 'foo.rb'), %{class Objenv::Foo; def spec_output; "this_is_foo_env_1"; end; end})

      spec_output_file = File.join('tmp', 'spec_script.rb')
      splat_file(File.join(spec_output_file), "puts Rails.objenv.spec_output")

      old_rails_env = ENV['RAILS_ENV']
      begin
        ENV['RAILS_ENV'] = 'foo'
        result = safe_system("rails runner #{spec_output_file}")
        result.strip.should match(/^this_is_foo_env_1$/mi)
      ensure
        ENV['RAILS_ENV'] = old_rails_env
      end
    end
  end

  context "generator" do
    it "should create all necessary classes, including one for whatever RAILS_ENV is set" do
      @rails_helper.with_new_rails_installation do
        append_file('Gemfile', "gem 'objectified_environments', :path => '#{@gem_root}'")

        old_rails_env = ENV['RAILS_ENV']
        begin
          ENV['RAILS_ENV'] = 'bar'
          safe_system("rails generate objectified_environments")
        ensure
          ENV['RAILS_ENV'] = old_rails_env
        end

        spec_output_file = File.join('tmp', 'spec_script.rb')
        splat_file(spec_output_file, <<-EOS)
%w{Bar Development Test Production LocalEnvironment ProductionEnvironment Environment}.each do |class_name|
  klass = eval("Objenv::" + class_name) rescue nil
  superclasses = [ ]

  current_class = klass
  while true
    break unless current_class
    current_class = current_class.superclass
    break if current_class == Object
    superclasses.unshift(current_class)
  end

  $stdout << class_name
  $stdout << ": "

  unless klass
    $stdout << "NOT PRESENT"
  end

  superclasses = superclasses.map { |sc| sc.name }.sort
  $stdout.puts superclasses.join(" ")
  $stdout.flush
end
EOS

        result = safe_system("rails runner #{spec_output_file}")

        result.should match(/^Environment: ObjectifiedEnvironments::Base$/mi)
        result.should match(/^LocalEnvironment: ObjectifiedEnvironments::Base Objenv::Environment$/mi)
        result.should match(/^Development: ObjectifiedEnvironments::Base Objenv::Environment Objenv::LocalEnvironment$/mi)
        result.should match(/^Test: ObjectifiedEnvironments::Base Objenv::Environment Objenv::LocalEnvironment$/mi)
        result.should match(/^ProductionEnvironment: ObjectifiedEnvironments::Base Objenv::Environment$/mi)
        result.should match(/^Production: ObjectifiedEnvironments::Base Objenv::Environment Objenv::ProductionEnvironment$/mi)
        result.should match(/^Bar: ObjectifiedEnvironments::Base Objenv::Environment$/mi)
      end
    end
  end
end
