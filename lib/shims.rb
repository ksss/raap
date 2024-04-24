# frozen_string_literal: true

# Ruby 3.2
unless Exception.method_defined?(:detailed_message)
  class Exception
    alias detailed_message message
  end
end

# Ruby 3.2
unless defined?(Data)
  class Data
    class << self
      def define(*syms)
        _ = Class.new do |c|
          define_method(:initialize) do |*args, **kwargs|
            if !args.empty?
              syms.zip(args).each do |sym, arg|
                instance_variable_set("@#{sym}", arg)
              end
            end
            if !kwargs.empty?
              kwargs.each do |k, v|
                instance_variable_set("@#{k}", v)
              end
            end
          end

          syms.each do |sym|
            c.define_method(sym) do
              instance_variable_get("@#{sym}")
            end
          end
        end
      end
    end
  end
end
