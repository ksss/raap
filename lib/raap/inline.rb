module RaaP
  module Inline
    def self.load(path)
      if File.directory?(path)
        Dir.glob("#{path}/**/*.rb").each do |file|
          load_file(file)
        end
      else
        load_file(path)
      end
    end

    def self.load_file(path)
      content = ::File.read(path)
      buffer = ::RBS::Buffer.new(name: path, content: content)
      prism = ::Prism.parse(content)
      result = ::RBS::InlineParser.parse(buffer, prism)
      source = ::RBS::Source::Ruby.new(buffer, prism, result.declarations, result.diagnostics)
      RBS.env.add_source(source)
    end
  end
end