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
            # @type self: Object
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
              # @type self: Object
              instance_variable_get("@#{sym}")
            end
          end
        end
      end
    end
  end
end

# RBS 3.8
unless RBS::TypeName.singleton_class.method_defined?(:parse)
  module RBS
    class TypeName
      def self.parse(string)
        absolute = string.start_with?("::")

        *path, name = string.delete_prefix("::").split("::").map(&:to_sym)
        raise unless name

        TypeName.new(
          name:,
          namespace: RBS::Namespace.new(path:, absolute:)
        )
      end
    end
  end
end
