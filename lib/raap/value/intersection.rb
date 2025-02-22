# frozen_string_literal: true

module RaaP
  module Value
    module Intersection
      # Build an object to realize an intersection.
      def self.new(type, size: 3)
        type = type.is_a?(::String) ? RBS.parse_type(type) : type
        unless type.instance_of?(::RBS::Types::Intersection)
          ::Kernel.raise ::TypeError, "not an intersection type: #{type}"
        end
        instances = type.types.filter_map do |t|
          t.instance_of?(::RBS::Types::ClassInstance) && Object.const_get(t.name.absolute!.to_s)
        end
        instances.uniq!
        unless instances.count { |c| c.is_a?(::Class) } <= 1
          raise ArgumentError, "intersection type must have at least one class instance type in `#{instances}`"
        end

        base = instances.find { |c| c.is_a?(::Class) } || Object

        c = Class.new(base) do
          instances.select { |i| !i.is_a?(::Class) }.each do |m|
            include(m)
          end

          type.types.each do |t|
            case t
            when ::RBS::Types::Interface
              Interface.define_method_from_interface(self, t, size:)
            end
          end
        end
        type = ::RBS::Types::ClassInstance.new(name: ::RBS::TypeName.parse(base.name), args: [], location: nil)
        SymbolicCaller.new(Type.call_new_from(c, type, size:)).eval
      end
    end
  end
end
