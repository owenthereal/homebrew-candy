class Candy < Formula
  desc "Zero-config reverse proxy server"
  homepage "https://github.com/owenthereal/candy"
  head "https://github.com/owenthereal/candy.git"
  url "https://github.com/owenthereal/candy/archive/v0.2.1.tar.gz"
  sha256 "a26b84ea35e8aa3d37826dca8f5701e08ae8e4274b931ad9595931c0030f9b09"

  depends_on "go" => :build

  def install
    system "make", "build"

    bin.install "build/candy"
    prefix.install_metafiles
    etc.install "example/candyconfig" => "candyconfig"
    (etc/"resolver").install "example/test_resolver" => "candy-test"
  end

  plist_options startup: true

  def plist
    <<~EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
            <string>#{opt_bin}/candy</string>
            <string>launch</string>
            <string>--dns-local-ip</string>
        </array>
        <key>KeepAlive</key>
        <true/>
        <key>RunAtLoad</key>
        <true/>
        <key>Sockets</key>
        <dict>
            <key>Socket</key>
            <dict>
                <key>SockNodeName</key>
                <string>0.0.0.0</string>
                <key>SockServiceName</key>
                <string>80</string>
            </dict>
            <key>SocketTLS</key>
            <dict>
                <key>SockNodeName</key>
                <string>0.0.0.0</string>
                <key>SockServiceName</key>
                <string>443</string>
            </dict>
        </dict>
        <key>StandardOutPath</key>
        <string>#{var}/log/candy.log</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/candy.log</string>
    </dict>
</plist>
    EOS
  end

  def caveats
    <<~EOS
      To finish the installation, you need to create a DNS resolver file
      in /etc/resolver/YOUR_DOMAIN. Creating the /etc/resolver directory
      requires superuser privileges. You can set things up with an one-liner

          sudo candy setup

      Or, you can execute this bash script

          sudo mkdir -p /etc/resolver && \\
            sudo chown -R $(whoami):$(id -g -n) /etc/resolver && \\
            cp #{etc/"resolver/candy-test"} /etc/resolver/candy-test

      To have launchd start Candy now and restart at login

          brew servies start candy

      Or, if you don't want/need a background service you can just run

          candy run

      A sample Candy config file is in #{etc/"candyconfig"}. You can
      copy it to your home to override Candy's default setting

          cp #{etc/"candyconfig"} ~/.candyconfig
    EOS
  end

  test do
    http = free_port
    https = free_port
    dns = free_port
    admin = free_port

    mkdir_p testpath/".candy"
    (testpath/".candy/app").write(admin)

    (testpath/"candyconfig").write <<~EOS
      {
        "domain": ["brew-test"],
        "http-addr": ":#{http}",
        "https-addr": ":#{https}",
        "dns-addr": "127.0.0.1:#{dns}",
        "admin-addr": "127.0.0.1:#{admin}",
        "host-root": "#{testpath/".candy"}"
      }
    EOS
    puts shell_output("cat #{testpath/"candyconfig"}")

    fork do
      exec bin/"candy", "run", "--config", testpath/"candyconfig"
    end

    sleep 2

    assert_match "\":#{http}\"", shell_output("curl -s http://127.0.0.1:#{admin}/config/apps/http/servers/candy/listen/0")
    assert_match "\":#{https}\"", shell_output("curl -s http://127.0.0.1:#{admin}/config/apps/http/servers/candy/listen/1")
    assert_match "127.0.0.1", shell_output("dig +short @127.0.0.1 -p #{dns} app.brew-test")
  end
end
