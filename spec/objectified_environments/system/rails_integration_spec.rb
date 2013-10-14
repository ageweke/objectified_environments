require File.join(File.dirname(__FILE__), '..', 'helpers', 'rails_helper')
require File.join(File.dirname(__FILE__), '..', 'helpers', 'command_helpers')

describe "ObjectifiedEnvironments Rails integration" do
  include ObjectifiedEnvironments::Specs::Helpers::CommandHelpers

  before :each do
    @gem_root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
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

  def add_gem_to_gemfile
    append_file('Gemfile', "gem 'objectified_environments', :path => '#{@gem_root}'\n")
  end

  def new_rails_helper(options = { })
    tmp_dir = File.join(@gem_root, 'tmp')
    ObjectifiedEnvironments::Specs::Helpers::RailsHelper.new(tmp_dir, options)
  end

  it "should instantiate and use the development environment properly when RAILS_ENV=development" do
    new_rails_helper.run! do |rh|
      add_gem_to_gemfile
      splat_file(File.join(lib_objenv_dir, 'development.rb'), %{class Objenv::Development; def spec_output; "this_is_dev_env_1"; end; end})

      old_rails_env = ENV['RAILS_ENV']
      begin
        ENV['RAILS_ENV'] = 'development'
        result = rh.run_as_script!("puts Rails.objenv.spec_output", :script_name => "check_env_spec_script")
        result.strip.should match(/^this_is_dev_env_1$/mi)
      ensure
        ENV['RAILS_ENV'] = old_rails_env
      end
    end
  end

  it "should be available during initializer and configuration time" do
    new_rails_helper.run! do |rh|
      add_gem_to_gemfile
      splat_file(File.join(lib_objenv_dir, 'test.rb'), %{class Objenv::Test; def spec_output; "this_is_test_env_2"; end; end})
      splat_file(File.join(rh.root, 'config', 'initializers', 'spec_initializer.rb'), "puts 'initializer: ' + Rails.objenv.spec_output")

      test_env_file = File.join(rh.root, "config", "environments", "test.rb")
      test_env = "puts 'before env: ' + Rails.objenv.spec_output\n" + File.read(test_env_file) + "\nputs 'after env: ' + Rails.objenv.spec_output\n"
      File.open(test_env_file, 'w') { |f| f << test_env }

      result = rh.run_as_script!("puts 'done'", :script_name => "check_initializer_spec_script")
      result.should match(/^initializer: this_is_test_env_2$/mi)
      result.should match(/^before env: this_is_test_env_2$/mi)
      result.should match(/^after env: this_is_test_env_2$/mi)
      result.should match(/^done$/mi)
    end
  end

  context "generator" do
    it "should create all necessary classes, including one for whatever RAILS_ENV is set" do
      new_rails_helper(:rails_env => 'bar').run! do |rh|
        add_gem_to_gemfile
        rh.run_generator("objectified_environments")

        script = <<-EOS
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

        result = rh.run_as_script!(script, :script_name => "check_generator_spec_script")

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
