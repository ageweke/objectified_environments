module ObjectifiedEnvironments
  module Specs
    module Helpers
      module CommandHelpers
        def safe_system(command, options = { })
          output = `#{command} 2>&1`

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
