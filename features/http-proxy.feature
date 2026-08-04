Feature: HTTP proxy configuration

  Scenario: Show disabled status when no proxy config exists
    Given an empty directory

    When I run `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled
      """

  Scenario: Show enabled status from proxy URL config
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://proxy.example.com:8080
      """

    When I run `wp http-proxy status`
    Then STDOUT should contain:
      """
      HTTP proxy: enabled
      """
    And STDOUT should contain:
      """
      Host: proxy.example.com
      """
    And STDOUT should contain:
      """
      Port: 8080
      """
    And STDOUT should contain:
      """
      Authentication: no
      """

  Scenario: Show enabled status from scheme-less proxy URL config
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: proxy.example.com:8085
      """

    When I run `wp http-proxy status`
    Then STDOUT should contain:
      """
      HTTP proxy: enabled
      """
    And STDOUT should contain:
      """
      Host: proxy.example.com
      """
    And STDOUT should contain:
      """
      Port: 8085
      """

  Scenario: Show enabled status from host and port config
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        host: proxy.example.com
        port: 8081
      """

    When I run `wp http-proxy status`
    Then STDOUT should contain:
      """
      HTTP proxy: enabled
      """
    And STDOUT should contain:
      """
      Host: proxy.example.com
      """
    And STDOUT should contain:
      """
      Port: 8081
      """

  Scenario: Ignore proxy environment variables by default
    Given an empty directory

    When I run `/usr/bin/env HTTP_PROXY=http://proxy.example.com:8082 wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled
      """

  Scenario: Read proxy environment variables only when enabled in config
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        env: true
      """

    When I run `/usr/bin/env HTTP_PROXY=http://proxy.example.com:8083 wp http-proxy status`
    Then STDOUT should contain:
      """
      HTTP proxy: enabled
      """
    And STDOUT should contain:
      """
      Host: proxy.example.com
      """
    And STDOUT should contain:
      """
      Port: 8083
      """

  Scenario: Prefer HTTPS proxy environment variables when environment lookup is enabled
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        env: true
      """

    When I run `/usr/bin/env HTTPS_PROXY=http://secure-proxy.example.com:8443 HTTP_PROXY=http://proxy.example.com:8083 wp http-proxy status`
    Then STDOUT should contain:
      """
      Host: secure-proxy.example.com
      """
    And STDOUT should contain:
      """
      Port: 8443
      """

  Scenario: Disable configured proxy explicitly
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        enabled: false
        url: http://proxy.example.com:8084
      """

    When I run `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled
      """

  Scenario: Reject an invalid proxy port
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        host: proxy.example.com
        port: 70000
      """

    When I run `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled
      """

  Scenario: Show proxy authentication and bypass hosts
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user:secret-token@proxy.example.com:8084
        bypass-hosts:
          - localhost
          - "*.test"
      """

    When I run `wp http-proxy status`
    Then STDOUT should contain:
      """
      Authentication: yes
      """
    And STDOUT should contain:
      """
      Bypass hosts: localhost,*.test
      """
    And STDOUT should not contain:
      """
      secret-token
      """

  Scenario: Preserve literal credentials configured separately
    Given a WP install
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://proxy.example.com:8084
        username: user%40example.com
        password: p%40ss
      """

    When I run `wp eval 'echo WP_PROXY_USERNAME . ":" . WP_PROXY_PASSWORD;'`
    Then STDOUT should be:
      """
      user%40example.com:p%40ss
      """

  Scenario: Decode credentials embedded in a proxy URL
    Given a WP install
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user%40example.com:p%40ss@proxy.example.com:8084
      """

    When I run `wp eval 'echo WP_PROXY_USERNAME . ":" . WP_PROXY_PASSWORD;'`
    Then STDOUT should be:
      """
      user@example.com:p@ss
      """

  Scenario: Define WordPress proxy constants after wp-config.php loads
    Given a WP install
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user:pass@proxy.example.com:8086
        bypass-hosts:
          - localhost
      """

    When I run `wp eval 'echo WP_PROXY_HOST . ":" . WP_PROXY_PORT . ":" . WP_PROXY_USERNAME . ":" . WP_PROXY_PASSWORD . ":" . WP_PROXY_BYPASS_HOSTS;'`
    Then STDOUT should be:
      """
      proxy.example.com:8086:user:pass:localhost
      """

  Scenario: Keep existing WordPress proxy constants from wp-config.php
    Given a WP install
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'existing proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:8893 -t proxy`
    When I run `wp config set WP_PROXY_HOST 127.0.0.1 --type=constant`
    And I run `wp config set WP_PROXY_PORT 8893 --raw --type=constant`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: proxy.example.com
        port: 8086
      """

    When I run `wp eval 'echo WP_PROXY_HOST . ":" . WP_PROXY_PORT;'`
    Then STDOUT should be:
      """
      127.0.0.1:8893
      """
    And STDERR should be empty

    When I run `wp eval '$response = WP_CLI\Utils\http_request( "GET", "http://proxy-target.invalid/existing-proxy-check" ); echo $response->body;'`
    Then STDOUT should be:
      """
      existing proxy reached http://proxy-target.invalid/existing-proxy-check
      """

  Scenario: Route a WordPress core request through the configured proxy
    Given a WP install
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:8896 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8896
      """

    When I run `wp eval '$response = wp_remote_get( "http://proxy-target.invalid/wp-core-check" ); echo wp_remote_retrieve_body( $response );'`
    Then STDOUT should be:
      """
      proxy reached http://proxy-target.invalid/wp-core-check
      """

  Scenario: Bypass the proxy for a matching WordPress core request
    Given a WP install
    And a target/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'direct request reached';
      """
    And I launch in the background `php -S 127.0.0.1:8895 -t target`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8897
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp eval '$response = wp_remote_get( "http://127.0.0.1:8895/wp-core-direct-check" ); echo wp_remote_retrieve_body( $response );'`
    Then STDOUT should be:
      """
      direct request reached
      """

  Scenario: Check a URL through a configured proxy
    Given an empty directory
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:8899 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8899
      """

    When I run `wp http-proxy check http://example.com/proxy-check`
    Then STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: proxy reached http://example.com/proxy-check
      """

  Scenario: Authenticate a request through the configured proxy
    Given an empty directory
    And a proxy/index.php file:
      """
      <?php
      $expected = 'Basic ' . base64_encode( 'user@example.com:p@ss' );

      if ( ! isset( $_SERVER['HTTP_PROXY_AUTHORIZATION'] ) || $expected !== $_SERVER['HTTP_PROXY_AUTHORIZATION'] ) {
          header( 'Proxy-Authenticate: Basic realm="proxy"' );
          http_response_code( 407 );
          exit;
      }

      header( 'Content-Type: text/plain' );
      echo 'authenticated proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:8894 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user%40example.com:p%40ss@127.0.0.1:8894
      """

    When I run `wp http-proxy check http://auth-target.invalid/proxy-auth-check`
    Then STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: authenticated proxy reached http://auth-target.invalid/proxy-auth-check
      """

  Scenario: Bypass hosts skip the proxy for matching URLs
    Given an empty directory
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:8898 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8897
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp http-proxy check http://127.0.0.1:8898/direct-check`
    Then STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: proxy reached /direct-check
      """

  Scenario: Wildcard bypass hosts skip the proxy for matching URLs
    Given an empty directory
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:8898 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8897
        bypass-hosts:
          - "*.0.0.1"
      """

    When I run `wp http-proxy check http://127.0.0.1:8898/wildcard-direct-check`
    Then STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: proxy reached /wildcard-direct-check
      """

  Scenario: Apply the proxy when a bypassed request redirects to another host
    Given an empty directory
    And a target/index.php file:
      """
      <?php
      header( 'Location: http://redirect-target.invalid/through-proxy', true, 302 );
      """
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:8892 -t target`
    And I launch in the background `php -S 127.0.0.1:8891 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8891
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp http-proxy check http://127.0.0.1:8892/start`
    Then STDOUT should contain:
      """
      Body: proxy reached http://redirect-target.invalid/through-proxy
      """

  Scenario: Bypass the proxy when a proxied request redirects to a matching host
    Given an empty directory
    And a target/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'direct redirect reached';
      """
    And a proxy/index.php file:
      """
      <?php
      header( 'Location: http://127.0.0.1:8892/direct', true, 302 );
      """
    And I launch in the background `php -S 127.0.0.1:8892 -t target`
    And I launch in the background `php -S 127.0.0.1:8891 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8891
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp http-proxy check http://redirect-source.invalid/start`
    Then STDOUT should contain:
      """
      Body: direct redirect reached
      """

  Scenario: Check reports a clean error when the proxy is unreachable
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 8897
      """

    When I try `wp http-proxy check http://example.com/proxy-check`
    Then STDERR should contain:
      """
      Error: Failed to get url 'http://example.com/proxy-check':
      """
    And the return code should be 1
