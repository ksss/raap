# frozen_string_literal: true

module RaaP
  module Value
    class Intersection < BasicObject
      def initialize(type, size: 3)
        @type = type.is_a?(::String) ? RBS.parse_type(type) : type
        unless @type.instance_of?(::RBS::Types::Intersection)
          ::Kernel.raise ::TypeError, "not an intersection type: #{@type}"
        end
        @children = @type.types.map { |t| Type.new(t).pick(size:) }
        @size = size
      end

      def inspect
        "#<intersection @type.to_s=#{@type.to_s.inspect} @size=#{@size.inspect}>"
      end

      def class
        Intersection
      end

      def method_missing(name, *args, **kwargs, &block)
        @children.each do |child|
          if BindCall.respond_to?(child, name)
            return child.__send__(name, *args, **kwargs, &block)
          end
        end

        super
      end

      def respond_to?(name, include_all = false)
        @children.any? do |type|
          BindCall.respond_to?(type, name, include_all)
        end

        super
      end
    end
  end
end
