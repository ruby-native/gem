require "socket"
require "uri"
require "ruby_native/cli/credentials"

module RubyNative
  class CLI
    class Login
      HOST = ENV.fetch("RUBY_NATIVE_HOST", "https://rubynative.com")

      def initialize(argv = [])
      end

      def run
        server = TCPServer.new("127.0.0.1", 0)
        port = server.addr[1]

        url = "#{HOST}/cli/session/new?port=#{port}"
        puts "Opening browser to authorize..."
        open_browser(url)
        puts "Waiting for authorization..."

        token = wait_for_callback(server)
        server.close

        if token
          Credentials.save(token)
          puts "Logged in to Ruby Native."
        else
          puts "Authorization failed. No token received."
          exit 1
        end
      end

      private

      def open_browser(url)
        case RUBY_PLATFORM
        when /darwin/
          system("open", url)
        when /linux/
          system("xdg-open", url)
        when /mingw|mswin/
          system("start", url)
        end
      end

      def wait_for_callback(server)
        client = server.accept
        request_line = client.gets
        token = extract_token(request_line)

        body = if token
          "Authenticated! You can close this window."
        else
          "Something went wrong. No token found in the callback."
        end

        client.print "HTTP/1.1 200 OK\r\n"
        client.print "Content-Type: text/html\r\n"
        client.print "Connection: close\r\n"
        client.print "\r\n"
        client.print "<html><body><p>#{body}</p></body></html>"
        client.close

        token
      end

      def extract_token(request_line)
        return unless request_line
        path = request_line.split(" ")[1]
        return unless path
        uri = URI.parse("http://localhost#{path}")
        params = URI.decode_www_form(uri.query || "")
        params.assoc("token")&.last
      end
    end
  end
end
