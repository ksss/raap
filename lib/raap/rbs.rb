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
