require File.join(File.dirname(__FILE__), 'command_helpers')

module ObjectifiedEnvironments
  module Specs
    module Helpers
      class RailsHelper
        include ObjectifiedEnvironments::Specs::Helpers::CommandHelpers

        def initialize(container_dir, options = { })
          @container_dir = container_dir
          @options = { }

          @rails_root = nil
          @rails_version = nil
        end

        def with_new_rails_installation(options = { })
          rails_root = create_new_rails_installation(options)
          old_dir = Dir.pwd

          old_rails_env = ENV['RAILS_ENV']

          begin
            Dir.chdir(rails_root)
            ENV['RAILS_ENV'] = options[:rails_env] if options[:rails_env]

            yield self

            Dir.chdir(old_dir)
            # FileUtils.rm_rf(File.dirname(rails_root)) unless options[:keep_even_after_success]
          rescue => e
            Dir.chdir(old_dir)
            # leave directory around
            raise e
          ensure
            ENV['RAILS_ENV'] = old_rails_env
          end
        end

        private
        def set_gemfile!(options)
          # For reasons I don't understand at all, running 'bundle install' against our installed Rails instance
          # absolutely refuses to install remote gems -- all it will do is use ones that have already been installed.
          # And that means it can only safely use gems in the top-level objectified_environments/Gemfile.
          # As a result, we overwrite the Gemfile here to contain only the reference to Rails itself, rather than
          # the additional stuff that the default Rails Gemfile contains. This, despite the fact that the command_helper
          # explicitly strips out all BUNDLE_* environment variables before executing a subcommand.
          #
          # This is unfortunate, because it would be safer to use all the default gems. If a subsequent contributor
          # knows what's going on here and how to make it work, by all means, please do!
          gem_lines = [
            "source 'http://rubygems.org'",
            "gem 'rails', '#{Rails.version}'"
          ]

          # Rails >= 3.2 uses sqlite3 by default, and won't even boot by default unless you add that to your Gemfile.
          if Rails.version =~ /^4\./ || Rails.version =~ /^3\.[23456789]/
            if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
              gem_lines << "gem 'activerecord-jdbcsqlite3-adapter'"
            else
              gem_lines << "gem 'sqlite3'"
            end
          end

          if gem_lines.length > 0
            $stdout << "[adding required gems to Gemfile..."
            $stdout.flush
            File.open("Gemfile", "w") { |f| gem_lines.each { |gl| f.puts gl } }
            $stdout << "]"
            $stdout.flush
          end
        end

        def modify_database_yml_as_needed!(options)
          if options[:rails_env]
            require 'yaml'

            db_yaml_file = File.join('config', 'database.yml')
            db_yaml = YAML.load_file(db_yaml_file)

            unless db_yaml[options[:rails_env].to_s]
              $stdout << "[adding environment '#{options[:rails_env]}' to database.yml..."
              $stdout.flush

              db_yaml[options[:rails_env].to_s] = db_yaml['development'].dup
              new_yaml = YAML.dump(db_yaml)
              new_yaml = new_yaml.split("\n").map { |l| l unless l =~ /^\-+$/i }.compact.join("\n")
              File.open(db_yaml_file, 'w') { |f| f.puts new_yaml }

              $stdout << "]"
              $stdout.flush
            end
          end
        end

        def check_installed_rails_version!(options)
          $stdout << "[checking Rails version..."
          $stdout.flush

          check_rails_version_file = File.join('tmp', 'check_rails_version.rb')
          File.open(check_rails_version_file, 'w') do |f|
            f.puts <<-EOS
puts "Rails version: " + Rails.version
EOS
          end

          run_script = if options[:using_rails_version] =~ /^2/
            "ruby script/runner"
          else
            "rails runner"
          end

          result = safe_system("bundle exec #{run_script} #{check_rails_version_file}", :output_must_match => /^\s*Rails\s+version\s*:\s*\S+\s*$/mi, :what_we_were_doing => "running a small script to check the version of Rails we installed")
          if result =~ /^\s*Rails\s+version\s*:\s*(\S+)\s*$/mi
            $stdout << $1
            $stdout.flush
          else
            raise "Unable to find the current Rails version; output was: #{result}"
          end

          $stdout << "]"
          $stdout.flush
        end

        def fetch_rails_command_version(options)
          $stdout << "[checking Rails command version..."
          $stdout.flush
          version_text = safe_system("rails --version", :output_must_match => /^\s*Rails\s+(\d+\.\d+\.\d+)\s*$/i, :what_we_were_doing => "checking the version of Rails used by the 'rails' command")
          version = if version_text =~ /^\s*Rails\s+(\d+\.\d+\.\d+)\s*$/i
            $1
          else
            raise "Unable to determine version of Rails; we got: #{version_text.inspect}"
          end
          $stdout << "]"
          $stdout.flush

          version
        end

        def create_new_rails_installation!(options)
          cmd = if options[:using_rails_version] =~ /^2/
            "rails objenvspec"
          else
            "rails new objenvspec"
          end

          $stdout << "[creating new Rails installation..."
          $stdout.flush
          safe_system(cmd, :what_we_were_doing => 'create a Rails project for our spec', :output_must_match => %r{create.*config/boot}mi)
          $stdout << "]"
          $stdout.flush
        end

        def run_bundle_install!(options)
          $stdout << "[running 'bundle install'..."
          $stdout.flush
          safe_system("bundle install", :what_we_were_doing => "run 'bundle install' for our test Rails project")
          $stdout << "]"
          $stdout.flush
          end

        def create_new_rails_installation(options)
          require 'fileutils'

          rails_holder = File.join(@container_dir, "rails-#{Rails.version}-#{Time.now.strftime("%Y%m%d-%H%M%S")}-#{rand(1_000_000)}")
          FileUtils.mkdir_p(rails_holder)

          rails_version = fetch_rails_command_version(options)
          options = options.merge(:using_rails_version => rails_version)

          old_dir = Dir.pwd
          Dir.chdir(rails_holder)
          create_new_rails_installation!(options)

          rails_root = File.join(rails_holder, 'objenvspec')
          Dir.chdir(rails_root)

          set_gemfile!(options)
          modify_database_yml_as_needed!(options)
          run_bundle_install!(options)

          check_installed_rails_version!(options)

          Dir.chdir(old_dir)
          rails_root
        end
      end
    end
  end
end
