# frozen_string_literal: true

module RaaP
  module RBS
    def self.builder
      @builder ||= ::RBS::DefinitionBuilder.new(env: env.resolve_type_names)
    end

    def self.env
      @env ||= ::RBS::Environment.from_loader(loader)
    end

    def self.loader
      @loader ||= ::RBS::CLI::LibraryOptions.new.loader
    end

    def self.parse_type(type)
      raise ArgumentError, "empty type" if type == ""

      ::RBS::Parser.parse_type(type, require_eof: true) or raise
    end

    def self.parse_method_type(method_type)
      raise ArgumentError, "empty method type" if method_type == ""

      ::RBS::Parser.parse_method_type(method_type, require_eof: true) or raise
    end

    def self.parse_member(member_type)
      _, _, decls = ::RBS::Parser.parse_signature(<<~RBS)
        module MemberScope
          #{member_type}
        end
      RBS
      decl = decls.first or raise
      raise unless decl.is_a?(::RBS::AST::Declarations::Module)

      member = decl.members.first or raise
      raise unless member.is_a?(::RBS::AST::Members::Attribute)

      member.tap do |m|
        m = __skip__ = m
        _shift_location(m.type, -m.location.start_pos)
        _shift_location(m, -m.location.start_pos)
      end
    end

    def self._shift_location(localable, shift)
      return if localable.location.nil?

      l = localable.instance_variable_get("@location")
      localable.instance_variable_set(
        "@location",
        ::RBS::Location.new(
          buffer: ::RBS::Buffer.new(
            name: l.buffer.name,
            content: l.buffer.content[-shift..l.end_pos],
          ),
          start_pos: l.start_pos + shift,
          end_pos: l.end_pos + shift,
        )
      )
      case localable
      when ::RBS::Types::Union
        localable.types.each { |t| _shift_location(t, shift) }
      when ::RBS::Types::Optional
        _shift_location(localable.type, shift)
      end
    end

    def self.find_alias_decl(type_name, method_name)
      env.class_decls[type_name].decls.each do |d|
        d.decl.members.each do |member|
          case member
          when ::RBS::AST::Members::Alias
            return member if member.new_name == method_name
          end
        end
      end

      nil
    end
  end
end
