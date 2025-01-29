# frozen_string_literal: true

module RaaP
  class TypeSubstitution
    def initialize(type_params, type_args)
      @type_params = type_params
      @type_args = type_args
    end

    def build
      bound_map = @type_params.zip(@type_args).to_h do |(bound, arg)|
        if arg
          [bound.name, arg]
        elsif bound.upper_bound
          [bound.name, bound.upper_bound]
        else
          [bound.name, ::RBS::Types::Variable.new(name: bound.name, location: nil)]
        end
      end
      ::RBS::Substitution.build(bound_map.keys, bound_map.values)
    end

    def method_type_sub(method_type, self_type: nil, instance_type: nil, class_type: nil)
      self_type = self_type.is_a?(::String) ? RBS.parse_type(self_type) : self_type
      instance_type = instance_type.is_a?(::String) ? RBS.parse_type(instance_type) : instance_type
      class_type = class_type.is_a?(::String) ? RBS.parse_type(class_type) : class_type
      sub = build
      if sub.empty? && self_type.nil? && instance_type.nil? && class_type.nil?
        return method_type
      end

      ::RBS::MethodType.new(
        type_params: [],
        type: method_type.type.sub(sub).then { |ty| sub(ty, self_type:, instance_type:, class_type:) },
        block: method_type.block&.sub(sub)&.then { |bl| sub(bl, self_type:, instance_type:, class_type:) },
        location: method_type.location
      )
    end

    private

    def sub(search, self_type:, instance_type:, class_type:)
      if self_type.nil? && instance_type.nil? && class_type.nil?
        return search
      end

      search.map_type do |ty|
        case ty
        when ::RBS::Types::Bases::Self
          self_type || ty
        when ::RBS::Types::Bases::Instance
          instance_type || ty
        when ::RBS::Types::Bases::Class
          class_type || ty
        else
          sub(ty, self_type:, instance_type:, class_type:)
        end
      end
    end
  end
end
