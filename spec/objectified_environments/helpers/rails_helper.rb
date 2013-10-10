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
          rails_root = create_new_rails_installation
          old_dir = Dir.pwd

          begin
            Dir.chdir(rails_root)
            yield rails_root
            Dir.chdir(old_dir)
            FileUtils.rm_rf(File.dirname(rails_root)) unless options[:keep_even_after_success]
          rescue => e
            Dir.chdir(old_dir)
            # leave directory around
            raise e
          end
        end

        private
        def create_new_rails_installation
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

          # Rails 4 uses sqlite3 by default, and won't even boot by default unless you add that to your Gemfile.
          if Rails.version =~ /^4\./
            $stdout << "[adding sqlite3 to Gemfile..."
            $stdout.flush
            File.open("Gemfile", "a") { |f| f.puts "gem 'sqlite3'" }
            $stdout << "]"
            $stdout.flush
          end

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
