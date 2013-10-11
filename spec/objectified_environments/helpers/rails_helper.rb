require File.join(File.dirname(__FILE__), 'command_helpers')

module ObjectifiedEnvironments
  module Specs
    module Helpers
      class RailsHelper
        include ObjectifiedEnvironments::Specs::Helpers::CommandHelpers

        def initialize(container_dir)
          @container_dir = container_dir
        end

        def with_new_rails_installation(options = { })
          rails_root = create_new_rails_installation(options)
          old_dir = Dir.pwd

          old_rails_env = ENV['RAILS_ENV']

          begin
            Dir.chdir(rails_root)
            ENV['RAILS_ENV'] = options[:rails_env] if options[:rails_env]

            yield rails_root

            Dir.chdir(old_dir)
            FileUtils.rm_rf(File.dirname(rails_root)) unless options[:keep_even_after_success]
          rescue => e
            Dir.chdir(old_dir)
            # leave directory around
            raise e
          ensure
            ENV['RAILS_ENV'] = old_rails_env
          end
        end

        private
        def add_to_gemfile_as_needed!(options)
          gem_lines = [ ]

          # Rails 4 uses sqlite3 by default, and won't even boot by default unless you add that to your Gemfile.
          if Rails.version =~ /^4\./
            if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
              gem_lines << "gem 'activerecord-jdbcsqlite3-adapter'"
            else
              gem_lines << "gem 'sqlite3'"
            end
          end

          if gem_lines.length > 0
            $stdout << "[adding required gems to Gemfile..."
            $stdout.flush
            File.open("Gemfile", "a") { |f| gem_lines.each { |gl| f.puts gl } }
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

        def create_new_rails_installation(options)
          require 'fileutils'

          rails_holder = File.join(@container_dir, "rails-#{Rails.version}-#{Time.now.strftime("%Y%m%d-%H%M%S")}-#{rand(1_000_000)}")
          FileUtils.mkdir_p(rails_holder)

          old_dir = Dir.pwd
          Dir.chdir(rails_holder)
          $stdout << "[creating new Rails installation..."
          $stdout.flush
          safe_system("rails new objenvspec", :what_we_were_doing => 'create a Rails project for our spec', :output_must_match => %r{create.*config/boot}mi)
          $stdout << "]"
          $stdout.flush

          rails_root = File.join(rails_holder, 'objenvspec')
          Dir.chdir(rails_root)

          add_to_gemfile_as_needed!(options)
          modify_database_yml_as_needed!(options)

          $stdout << "[running 'bundle install'..."
          $stdout.flush
          safe_system("bundle install", :what_we_were_doing => "run 'bundle install' for our test Rails project")
          $stdout << "]"
          $stdout.flush

          Dir.chdir(old_dir)
          rails_root
        end
      end
    end
  end
end
