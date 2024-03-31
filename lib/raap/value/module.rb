module RaaP
  module Value
    # FIXME: consider self_types
    # HINT: intersection?
    class Module
      attr_reader :type

      def initialize(type)
        @type = type.is_a?(String) ? RBS.parse_type(type) : type
        unless @type.instance_of?(::RBS::Types::ClassInstance)
          raise ::TypeError, "not a module type: #{@type}"
        end
        const = ::Object.const_get(@type.name.absolute!.to_s)
        extend(const)
      end

      def inspect = "#<module #{@type}>"
      def class = Value::Module
    end
  end
end
