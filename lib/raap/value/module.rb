# frozen_string_literal: true

module RaaP
  module Value
    # FIXME: consider self_types
    # HINT: intersection?
    class Module < BasicObject
      def initialize(type, size: 3)
        @type = type.is_a?(::String) ? ::RaaP::RBS.parse_type(type) : type
        @size = size
        unless @type.instance_of?(::RBS::Types::ClassInstance)
          ::Kernel.raise ::TypeError, "not a module type: #{@type}"
        end

        one_instance_ancestors = ::RaaP::RBS.builder.ancestor_builder.one_instance_ancestors(@type.name.absolute!).self_types
        @self_type = if one_instance_ancestors.nil? || one_instance_ancestors.empty?
                       ::Object.new
                     else
                       one_instance_ancestors.map do |a_instance|
                         if a_instance.args.empty?
                           # : BasicObject
                           a_instance.name.absolute!.to_s
                         else
                           # : _Each[Integer]
                           args = a_instance.args.zip(@type.args).map do |_var, instance|
                             if instance
                               instance.to_s
                             else
                               'untyped'
                             end
                           end
                           "#{a_instance.name}[#{args.map(&:to_s).join(', ')}]"
                         end
                       end.then do |ts|
                         if !ts.include?('::BasicObject') || ts.any? { |t| t.split('::').last&.start_with?('_') }
                           ts.unshift('Object')
                         end
                         Type.new(ts.uniq.join(' & ')).pick(size:)
                       end
                     end
        const = ::Object.const_get(@type.name.absolute!.to_s)
        BindCall.extend(self, const)
      end

      def method_missing(name, *args, **kwargs, &block)
        @self_type.__send__(name, *args, **kwargs, &block)
      end

      def respond_to?(name, include_all = false)
        if BindCall.instance_of?(@self_type, ::BasicObject)
          BindCall.respond_to?(@self_type, name, include_all)
        else
          @self_type.respond_to?(name, include_all)
        end
      end

      def inspect = "#<module #{@type} : #{BindCall.class(@self_type)} size=#{@size}>"
      def class = Value::Module
    end
  end
end
