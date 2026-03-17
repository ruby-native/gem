require "json"
require "fileutils"

module RubyNative
  class CLI
    class Credentials
      PATH = File.join(Dir.home, ".ruby_native", "credentials")

      def self.token
        return unless File.exist?(PATH)
        JSON.parse(File.read(PATH))["token"]
      rescue JSON::ParserError
        nil
      end

      def self.save(token)
        dir = File.dirname(PATH)
        FileUtils.mkdir_p(dir)
        File.write(PATH, JSON.generate(token: token))
        File.chmod(0600, PATH)
      end

      def self.clear
        File.delete(PATH) if File.exist?(PATH)
      end
    end
  end
end
