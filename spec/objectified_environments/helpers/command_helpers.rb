module ObjectifiedEnvironments
  module Specs
    module Helpers
      module CommandHelpers
        def safe_system(command, options = { })
          # Ugh. Bundler sets environment variables that causes subprocesses to use the same Bundler Gemfiles, etc.
          # While I'm sure this is exactly what you want in most circumstances, it breaks our handling of different
          # Rails versions. So we remove these explicitly when we execute a subprocess.
          old_env = { }
          ENV.keys.select { |k| k =~ /^BUNDLE_/ }.each do |key|
            old_env[key] = ENV[key]
            ENV.delete(key)
          end

          output = `#{command} 2>&1`

          old_env.each { |k,v| ENV[k] = v }

          successful = $?.success?
          successful = false if options[:output_must_match] && (! (output =~ options[:output_must_match]))

          unless successful
            what_we_were_doing = options[:what_we_were_doing] || "run a command"

            raise <<-EOS
Unable to #{what_we_were_doing}. In this directory:

  #{Dir.pwd}

...we ran:

  #{command}

...but it returned this result: #{$?.inspect}
...and gave this output:

#{output}
EOS
          end

          output
        end
      end
    end
  end
end
