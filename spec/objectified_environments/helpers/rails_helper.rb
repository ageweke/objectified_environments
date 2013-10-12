require File.join(File.dirname(__FILE__), 'command_helpers')
require 'fileutils'

module ObjectifiedEnvironments
  module Specs
    module Helpers
      class RailsHelper
        include ObjectifiedEnvironments::Specs::Helpers::CommandHelpers

        def initialize(container_dir, options = { })
          @container_dir = container_dir
          @options = options

          @root = nil
          @version = nil
          @running = false
        end

        attr_reader :root, :version

        def run!(&block)
          begin
            @running = true
            preserve_state do
              new_rails_installation!

              Dir.chdir(root)
              ENV['RAILS_ENV'] = options[:rails_env] if options[:rails_env]

              block.call(self)

              FileUtils.rm_rf(File.dirname(root)) unless options[:always_keep_installation]
            end
          ensure
            @running = false
          end
        end

        def major_version
          Integer($1) if version && version =~ /^(\d+)\./i
        end

        def major_and_minor_version
          Float($1) if version && version =~ /^(\d+\.\d+)\./i
        end

        def run_script_command
          if major_version <= 2
            "ruby #{File.join('script', 'runner')}"
          else
            "rails runner"
          end
        end

        def run_script!(script_path, *args)
          opts = args.pop if args && args[-1] && args[-1].kind_of?(Hash)
          opts ||= { }

          must_be_running!
          Dir.chdir(root) do
            cmd = "bundle exec #{run_script_command} #{script_path}"
            if args.length > 0
              cmd << " "
              cmd << args.join(" ")
            end
            safe_system(cmd, opts)
          end
        end

        def run_as_script!(contents, opts = { })
          script_file = opts[:script_name] || "temp_rails_script_#{rand(1_000_000)}"
          script_file << ".rb" unless script_file =~ /\.rb$/i

          File.open(script_file, 'w') { |f| f.puts contents }

          run_script!(script_file, opts)
        end

        def run_generator(*args)
          cmd = if major_version <= 2
            "script/generate"
          else
            "rails generate"
          end

          cmd = "bundle exec #{cmd} #{args.join(" ")}"
          safe_system(cmd)
        end

        def running?
          !! @running
        end

        private
        attr_reader :container_dir, :options

        def must_be_running!
          unless running?
            raise "You can only call this while the Rails helper is running, and it isn't right now."
          end
        end

        def project_name
          options[:project_name] || 'rails_project'
        end

        def preserve_state(&block)
          old_dir = Dir.pwd
          old_rails_env = ENV['RAILS_ENV']

          begin
            block.call
          ensure
            Dir.chdir(old_dir)
            ENV['RAILS_ENV'] = old_rails_env
          end
        end

        def notify(string, &block)
          $stdout << "[#{string}..."
          $stdout.flush

          block.call

          $stdout << "]"
          $stdout.flush
        end

        def create_rails_holder!
          raise "No version yet?!?" unless version
          out = File.join(container_dir, "rails-#{Time.now.strftime("%Y%m%d-%H%M%S")}-#{rand(1_000_000)}-#{version}")
          FileUtils.mkdir_p(out)
          out
        end

        def new_rails_installation!
          fetch_rails_version!
          rails_holder = create_rails_holder!

          Dir.chdir(rails_holder)
          create_rails_project!

          @root = File.join(rails_holder, project_name)
          Dir.chdir(root)

          set_gemfile!
          modify_database_yml_as_needed!
          run_bundle_install!

          check_installed_rails_version!
        end

        def set_gemfile!
          # For reasons I don't understand at all, running 'bundle install' against our installed Rails instance
          # absolutely refuses to install remote gems -- all it will do is use ones that have already been installed.
          # And that means it can only safely use gems in the top-level Gemfile of whatever gem or other code we're
          # running under.
          #
          # As a result, we overwrite the Gemfile here to contain only the reference to Rails itself, rather than
          # the additional stuff that the default Rails Gemfile contains. This, despite the fact that the command_helper
          # explicitly strips out all BUNDLE_* environment variables before executing a subcommand.
          #
          # This is unfortunate, because it would be safer to use all the default gems. If a subsequent contributor
          # knows what's going on here and how to make it work, by all means, please do!
          gem_lines = [
            "source 'http://rubygems.org'",
            "gem 'rails', '#{version}'"
          ]

          # Rails >= 3.2 uses sqlite3 by default, and won't even boot by default unless you add that to your Gemfile.
          if major_and_minor_version >= 3.2
            if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
              gem_lines << "gem 'activerecord-jdbcsqlite3-adapter'"
            else
              gem_lines << "gem 'sqlite3'"
            end
          end

          if gem_lines.length > 0
            notify("adding required lines to Gemfile") do
              File.open("Gemfile", "w") { |f| f.puts gem_lines.join("\n") }
            end
          end
        end

        # If we're using a RAILS_ENV other than one of the three defaults, then database.yml needs to contain
        # configuration for that environment, even if we never actually touch the database, because certain Rails
        # versions refuse to even start if it's not present.
        def modify_database_yml_as_needed!
          rails_env = options[:rails_env]
          if rails_env
            rails_env = rails_env.to_s
            require 'yaml'

            db_yaml_file = File.join('config', 'database.yml')
            db_yaml = YAML.load_file(db_yaml_file)

            unless db_yaml[rails_env]
              notify("adding environment '#{rails_env}' to database.yml") do
                dev_content = db_yaml['development']
                raise "No default database.yml entry for 'development'?!?" unless dev_content

                db_yaml[rails_env] = dev_content.dup
                new_yaml = YAML.dump(db_yaml)
                # Get rid of the silly '---' line that YAML.dump puts at the start.
                new_yaml = new_yaml.split("\n").map { |l| l unless l =~ /^\-+$/i }.compact.join("\n")
                File.open(db_yaml_file, 'w') { |f| f.puts new_yaml }
              end
            end
          end
        end

        def check_installed_rails_version!
          notify "checking version of Rails in our new project" do
            output = run_as_script!(%{puts "Rails version: " + Rails.version},
              :script_name => "check_rails_version",
              :output_must_match => /^\s*Rails\s+version\s*:\s*\S+\s*$/mi,
              :what_we_were_doing => "running a small script to check the version of Rails we installed")

            if output =~ /^\s*Rails\s+version\s*:\s*(\S+)\s*$/mi
              installed_version = $1

              unless installed_version == version
                raise "Whoa: the Rails project we created is reporting itself as version '#{installed_version}', but 'rails --version' gave us '#{version}'. Something is horribly wrong."
              end
            end
          end
        end

        def fetch_rails_version!
          v = nil

          notify "checking version of Rails we're using" do
            version_text = safe_system("rails --version", :output_must_match => /^\s*Rails\s+(\d+\.\d+\.\d+)\s*$/i, :what_we_were_doing => "checking the version of Rails used by the 'rails' command")
            v = if version_text =~ /^\s*Rails\s+(\d+\.\d+\.\d+)\s*$/i
              $1
            else
              raise "Unable to determine version of Rails; we got: #{version_text.inspect}"
            end

            $stdout << v
            $stdout.flush
          end

          @version = v
        end

        def create_rails_project_command
          if major_version <= 2
            "rails"
          else
            "rails new"
          end
        end

        def create_rails_project!
          notify "creating new Rails installation" do
            safe_system("#{create_rails_project_command} #{project_name}",
              :what_we_were_doing => 'create a Rails project for our spec',
              :output_must_match => %r{create.*config/boot}mi)
          end
        end

        def run_bundle_install!
          notify "running 'bundle install'" do
            safe_system("bundle install", :what_we_were_doing => "run 'bundle install' for our test Rails project")
          end
        end
      end
    end
  end
end
