# Rails 3.0 and later let you just "require 'rails'". Rails 2.3 is far less modular; you have to require
# activesupport and then, super-grossly, just raw 'initializer'. Ick. But it does work.
begin
  require 'rails'
rescue LoadError => le
  require 'activesupport'
  require 'initializer'
end
