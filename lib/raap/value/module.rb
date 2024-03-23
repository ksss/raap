module RaaP
  module Value
    # FIXME: consider self_types
    # HINT: intersection?
    class Module
      attr_reader :type

      def initialize(type)
        @type = type
        const = ::Object.const_get(type.name.absolute!.to_s)
        extend(const)
      end

      def inspect = "#<module #{@type}>"
      def class = Value::Module
    end
  end
end
