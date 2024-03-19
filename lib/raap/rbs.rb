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
  end
end
