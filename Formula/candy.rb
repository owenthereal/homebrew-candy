class Candy < Formula
  desc "Zero-config reverse proxy server"
  homepage "https://github.com/owenthereal/candy"
  head "https://github.com/owenthereal/candy.git"
  url "https://github.com/owenthereal/candy/archive/v0.4.6.tar.gz"
  sha256 "cbc6ba56c05fb425ac47965993a51d522f6098fc8a991d2c796f5af72d9b22b5"

  depends_on "go" => :build

  def install
    system "make", "build"

    bin.install "build/candy"
    prefix.install_metafiles
    etc.install "example/candyconfig" => "candyconfig"
    (etc/"resolver").install "example/mac/candy-test" => "candy-test"
  end

  def service
    run [opt_bin/"candy", "launch", "--dns-local-ip"]
    keep_alive true
    run_at_load true
    sockets "tcp://0.0.0.0:80"
    working_dir HOMEBREW_PREFIX
    log_path var/"log/candy/output.log"
    error_log_path var/"log/candy/output.log"
  end

  def caveats
    <<~EOS
      To finish the installation, you need to create a DNS resolver file
      in /etc/resolver/YOUR_DOMAIN. Creating the /etc/resolver directory
      and the config file requires superuser privileges. You can set things
      up with an one-liner

          sudo candy setup

      Alternatively, you can execute the following bash script

          sudo mkdir -p /etc/resolver && \\
            sudo chown -R $(whoami):$(id -g -n) /etc/resolver && \\
            cp #{etc/"resolver/candy-test"} /etc/resolver/candy-test

      To have launchd start Candy now and restart at login

          brew services start candy

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
