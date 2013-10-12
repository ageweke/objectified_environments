require File.join(File.dirname(__FILE__), 'rails_requirer')

module ObjectifiedEnvironments
  class DataProvider
    def rails_env
      @rails_env ||= begin
        out = Rails.env || ''
        if out.strip.length == 0
          raise "#{self.name}: There appears to be no Rails.env set; I can't create an objectified environment for you. I don't know why this would happen. Rails.env is: #{Rails.env.inspect}"
        end

        out
      end
    end

    def user_name
      @user_name ||= begin
        require 'etc'

        candidates = [ Etc.getlogin, ENV['USER'], ENV['LOGNAME'], ENV['USERNAME'] ]
        candidates = candidates.map { |c| c.strip unless (! c) || c.strip.length == 0 }.compact
        candidates[0] || :none
      end

      @user_name unless @user_name == :none
    end

    def host_name
      @host_name ||= begin
        candidates = [ host_name_from_hostname_command, socket_gethostname ]
        candidates = candidates.map { |c| normalize_hostname(c) }.compact
        candidates[0] || :none
      end

      @host_name unless @host_name == :none
    end

    private
    def host_name_from_hostname_command
      out = `hostname`
      out if $?.success? && out && out.strip.length > 0
    end

    def socket_gethostname
      require 'socket'

      out = Socket.gethostname rescue nil
      out.strip if out && out.strip.length > 0
    end

    def normalize_hostname(hostname)
      return nil unless hostname && hostname.strip.length > 0

      out = hostname.strip.downcase.gsub(/[\-_]+/, '_')
      out if out =~ /^[A-Z_][A-Z0-9_]*$/i # must be a valid Ruby identifier
    end
  end
end
