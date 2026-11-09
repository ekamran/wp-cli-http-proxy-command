Feature: HTTP proxy configuration

  Scenario: Show disabled status when no proxy config exists
    Given an empty directory

    When I run `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (no http-proxy configuration)
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
      HTTP proxy: disabled (no http-proxy configuration)
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

  Scenario: Prefer a configured proxy address over environment lookup
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://configured-proxy.example.com:8088
        env: true
      """

    When I run `/usr/bin/env HTTPS_PROXY=http://env-proxy.example.com:8443 wp http-proxy status`
    Then STDOUT should contain:
      """
      Host: configured-proxy.example.com
      """
    And STDOUT should contain:
      """
      Port: 8088
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
      HTTP proxy: disabled (http-proxy has enabled: false)
      """

  Scenario: Reject an invalid proxy port
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        host: proxy.example.com
        port: 70000
      """

    When I try `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """
    And STDERR should be:
      """
      Warning: HTTP proxy disabled: the http-proxy port is not valid. Use a port from 1 to 65535.
      """
    And the return code should be 0

  Scenario: Warn when the proxy URL has no port
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user:secret-token@proxy.example.com
      """

    When I try `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """
    And STDERR should be:
      """
      Warning: HTTP proxy disabled: the http-proxy url has no port. Add one, such as http://proxy.example.com:8080.
      """
    And the return code should be 0

    When I try `wp http-proxy check http://127.0.0.1:18897/unusable-config-check`
    Then STDOUT should contain:
      """
      Proxy: none (the http-proxy configuration cannot be used)
      """
    And STDOUT should not contain:
      """
      secret-token
      """
    And STDERR should contain:
      """
      Warning: HTTP proxy disabled: the http-proxy url has no port.
      """

  Scenario: Warn when the http-proxy setting is not a block
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy: http://user:secret-token@proxy.example.com:8080
      """

    When I try `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """
    And STDERR should be:
      """
      Warning: HTTP proxy disabled: the http-proxy setting must be a block with url, host and port, or env, such as url: http://proxy.example.com:8080.
      """
    And the return code should be 0

  Scenario: Warn when the proxy URL uses a scheme other than http
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: socks5://proxy.example.com:1080
      """

    When I try `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """
    And STDERR should be:
      """
      Warning: HTTP proxy disabled: the http-proxy url uses socks5://, but only HTTP proxies (http://) are supported.
      """
    And the return code should be 0

  Scenario: Warn when the proxy environment variable cannot be used
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        env: true
      """

    When I try `/usr/bin/env HTTPS_PROXY=https://proxy.example.com:8443 wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """
    And STDERR should be:
      """
      Warning: HTTP proxy disabled: the HTTPS_PROXY environment variable uses https://, but only HTTP proxies (http://) are supported.
      """
    And the return code should be 0

  Scenario: Stay quiet when environment lookup finds no proxy variable
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        env: true
      """

    When I run `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (env: true found no proxy environment variable)
      """

  Scenario: Warn when the proxy configuration has no address
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        bypass-hosts:
          - localhost
      """

    When I try `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """
    And STDERR should be:
      """
      Warning: HTTP proxy disabled: the http-proxy configuration has no url, host and port, or env setting.
      """
    And the return code should be 0

  Scenario: Add brackets to a bare IPv6 proxy host
    Given a WP install
    And a wp-cli.yml file:
      """
      http-proxy:
        host: "2001:db8::1"
        port: 3128
      """

    When I run `wp http-proxy status`
    Then STDOUT should contain:
      """
      Host: [2001:db8::1]
      """

    When I run `wp eval 'echo WP_PROXY_HOST . " " . WP_PROXY_PORT;'`
    Then STDOUT should be:
      """
      [2001:db8::1] 3128
      """

  Scenario: Warn when a proxy URL has an IPv6 address without brackets
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://2001:db8::1:3128
      """

    When I try `wp http-proxy status`
    Then STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """
    And STDERR should be:
      """
      Warning: HTTP proxy disabled: the http-proxy url has an IPv6 address without brackets. Use the form http://[2001:db8::1]:8080.
      """
    And the return code should be 0

  Scenario: Warn when only a proxy username is set
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://proxy.example.com:8080
        username: proxy-user
      """

    When I try `wp http-proxy status`
    Then STDOUT should contain:
      """
      HTTP proxy: enabled
      """
    And STDOUT should contain:
      """
      Authentication: no
      """
    And STDERR should be:
      """
      Warning: HTTP proxy authentication not used: set both a username and a password.
      """
    And the return code should be 0

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
    And I launch in the background `php -S 127.0.0.1:18893 -t proxy`
    When I run `wp config set WP_PROXY_HOST 127.0.0.1 --type=constant`
    And I run `wp config set WP_PROXY_PORT 18893 --raw --type=constant`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18897
      """

    When I run `wp eval 'echo WP_PROXY_HOST . ":" . WP_PROXY_PORT;'`
    Then STDOUT should be:
      """
      127.0.0.1:18893
      """
    And STDERR should be empty

    When I run `wp eval '$response = WP_CLI\Utils\http_request( "GET", "http://proxy-target.invalid/existing-proxy-check" ); echo $response->body;'`
    Then STDOUT should be:
      """
      existing proxy reached http://proxy-target.invalid/existing-proxy-check
      """

    # status and check run before WordPress loads, so they use the http-proxy configuration.
    When I run `wp http-proxy status`
    Then STDOUT should contain:
      """
      Port: 18897
      """

    When I try `wp http-proxy check http://proxy-target.invalid/before-wordpress-check`
    Then STDOUT should contain:
      """
      Proxy: 127.0.0.1:18897
      """
    And STDERR should contain:
      """
      Error: Failed to get url 'http://proxy-target.invalid/before-wordpress-check':
      """

  Scenario: Route a WordPress core request through the configured proxy
    Given a WP install
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:18896 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18896
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
    And I launch in the background `php -S 127.0.0.1:18895 -t target`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18897
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp eval '$response = wp_remote_get( "http://127.0.0.1:18895/wp-core-direct-check" ); echo wp_remote_retrieve_body( $response );'`
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
    And I launch in the background `php -S 127.0.0.1:18899 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18899
      """

    When I run `wp http-proxy check http://example.com/proxy-check --body`
    Then STDOUT should contain:
      """
      Proxy: 127.0.0.1:18899
      """
    And STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: proxy reached http://example.com/proxy-check
      """

  Scenario: Check a URL through a configured proxy with Requests 1.x from WordPress 6.1
    Given an empty directory
    # Download before the proxy is configured, so the download does not go through the test proxy.
    When I run `wp core download --version=6.1.7 --skip-content`
    Then STDOUT should contain:
      """
      Success: WordPress downloaded.
      """

    Given a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:18901 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18901
      """

    When I run `wp eval --skip-wordpress 'echo WP_CLI\RequestsLibrary::get_version();'`
    Then STDOUT should be:
      """
      v1
      """

    # Requests 1.x in WordPress 6.1 prints deprecation notices on PHP 8.1 and later.
    When I try `wp http-proxy check http://example.com/requests-v1-check --body`
    Then the return code should be 0
    And STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: proxy reached http://example.com/requests-v1-check
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
    And I launch in the background `php -S 127.0.0.1:18894 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user%40example.com:p%40ss@127.0.0.1:18894
      """

    When I run `wp http-proxy check http://auth-target.invalid/proxy-auth-check --body`
    Then STDOUT should contain:
      """
      Proxy: 127.0.0.1:18894 (with authentication)
      """
    And STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: authenticated proxy reached http://auth-target.invalid/proxy-auth-check
      """
    And STDOUT should not contain:
      """
      p@ss
      """
    And STDOUT should not contain:
      """
      p%40ss
      """

  Scenario: Authenticate through the proxy with Requests' socket transport
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
    # Requests uses its socket transport when PHP has no cURL extension.
    And a socket-transport.php file:
      """
      <?php
      WP_CLI::add_hook(
          'http_request_options',
          static function ( $options ) {
              if ( empty( $options['hooks'] ) ) {
                  $options['hooks'] = new WpOrg\Requests\Hooks();
              }

              $options['hooks']->register(
                  'fsockopen.before_send',
                  static function ( &$request ) {
                      file_put_contents( 'socket-request.txt', $request );
                  }
              );
              $options['transport'] = 'WpOrg\Requests\Transport\Fsockopen';

              return $options;
          }
      );
      """
    And I launch in the background `php -S 127.0.0.1:18902 -t proxy`
    And a wp-cli.yml file:
      """
      require:
        - socket-transport.php
      http-proxy:
        url: http://user%40example.com:p%40ss@127.0.0.1:18902
      """

    When I run `wp http-proxy check http://auth-target.invalid/socket-auth-check --body`
    Then STDOUT should contain:
      """
      Status: 200
      """
    And STDOUT should contain:
      """
      Body: authenticated proxy reached http://auth-target.invalid/socket-auth-check
      """
    And the socket-request.txt file should contain:
      """
      GET http://auth-target.invalid/socket-auth-check HTTP/1.1
      """
    And the socket-request.txt file should contain:
      """
      Proxy-Authorization: Basic
      """

  Scenario: Send WP-CLI requests for localhost through the proxy while WordPress core connects directly
    Given a WP install
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And a target/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'direct request reached';
      """
    And I launch in the background `php -S 127.0.0.1:18903 -t proxy`
    And I launch in the background `php -S 127.0.0.1:18904 -t target`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18903
      """

    When I run `wp http-proxy check http://localhost:18904/helper-localhost --body`
    Then STDOUT should contain:
      """
      Body: proxy reached http://localhost:18904/helper-localhost
      """

    When I run `wp eval '$response = wp_remote_get( "http://localhost:18904/core-localhost" ); echo wp_remote_retrieve_body( $response );'`
    Then STDOUT should be:
      """
      direct request reached
      """

  Scenario: Bypass hosts skip the proxy for matching URLs
    Given an empty directory
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And I launch in the background `php -S 127.0.0.1:18898 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18897
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp http-proxy check http://127.0.0.1:18898/direct-check --body`
    Then STDOUT should contain:
      """
      Proxy: none (the host is in bypass-hosts)
      """
    And STDOUT should contain:
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
    And I launch in the background `php -S 127.0.0.1:18898 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18897
        bypass-hosts:
          - "*.0.0.1"
      """

    When I run `wp http-proxy check http://127.0.0.1:18898/wildcard-direct-check --body`
    Then STDOUT should contain:
      """
      Proxy: none (the host is in bypass-hosts)
      """
    And STDOUT should contain:
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
    And I launch in the background `php -S 127.0.0.1:18892 -t target`
    And I launch in the background `php -S 127.0.0.1:18891 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18891
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp http-proxy check http://127.0.0.1:18892/start --body`
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
      header( 'Location: http://127.0.0.1:18892/direct', true, 302 );
      """
    And I launch in the background `php -S 127.0.0.1:18892 -t target`
    And I launch in the background `php -S 127.0.0.1:18891 -t proxy`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18891
        bypass-hosts:
          - 127.0.0.1
      """

    When I run `wp http-proxy check http://redirect-source.invalid/start --body`
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
        port: 18897
      """

    When I try `wp http-proxy check http://example.com/proxy-check`
    Then STDERR should contain:
      """
      Error: Failed to get url 'http://example.com/proxy-check':
      """
    And the return code should be 1

  Scenario: Check reports a direct request and the body size by default
    Given an empty directory
    And a target/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'direct request reached';
      """
    And I launch in the background `php -S 127.0.0.1:18905 -t target`

    When I run `wp http-proxy check http://127.0.0.1:18905/no-config-check`
    Then STDOUT should be:
      """
      Proxy: none (no http-proxy configuration)
      Status: 200
      Body size: 22 bytes
      """

  Scenario: Check notes a cURL proxy variable when the package sets no proxy
    Given an empty directory
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'environment proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And a target/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'direct request reached';
      """
    And I launch in the background `php -S 127.0.0.1:18906 -t proxy`
    And I launch in the background `php -S 127.0.0.1:18907 -t target`

    When I run `/usr/bin/env http_proxy=http://127.0.0.1:18906 wp http-proxy check http://env-target.invalid/env-check --body`
    Then STDOUT should contain:
      """
      Proxy: none (no http-proxy configuration)
      """
    And STDOUT should contain:
      """
      Note: cURL also reads http_proxy, so this request can still go through a proxy set there.
      """
    And STDOUT should contain:
      """
      Body: environment proxy reached http://env-target.invalid/env-check
      """

    # cURL reads http_proxy only in lowercase.
    When I run `/usr/bin/env HTTP_PROXY=http://127.0.0.1:18906 wp http-proxy check http://127.0.0.1:18907/uppercase-check --body`
    Then STDOUT should not contain:
      """
      Note:
      """
    And STDOUT should contain:
      """
      Body: direct request reached
      """

  Scenario: Check notes NO_PROXY, which makes cURL skip the configured proxy
    Given an empty directory
    And a target/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'direct request reached';
      """
    And I launch in the background `php -S 127.0.0.1:18908 -t target`
    And a wp-cli.yml file:
      """
      http-proxy:
        host: 127.0.0.1
        port: 18897
      """

    When I run `/usr/bin/env NO_PROXY=127.0.0.1 wp http-proxy check http://127.0.0.1:18908/no-proxy-check --body`
    Then STDOUT should contain:
      """
      Proxy: 127.0.0.1:18897
      """
    And STDOUT should contain:
      """
      Note: cURL also reads NO_PROXY, so a host listed there skips this proxy.
      """
    And STDOUT should contain:
      """
      Body: direct request reached
      """

  Scenario: Use the http-proxy block from the configuration file with the highest priority
    Given an empty directory
    # The test framework loads this package through the global config file, so keep loading it.
    When I run `wp eval --skip-wordpress 'echo getenv( "WP_CLI_CONFIG_PATH" );'`
    Then save STDOUT as {TEST_CONFIG_PATH}

    Given a global.yml file:
      """
      _:
        inherit: {TEST_CONFIG_PATH}
      http-proxy:
        url: http://proxy-user:proxy-password@proxy.example.com:8087
      """
    And a wp-cli.yml file:
      """
      http-proxy:
        bypass-hosts:
          - localhost
      """

    When I try `/usr/bin/env WP_CLI_CONFIG_PATH=global.yml wp http-proxy status`
    Then STDERR should contain:
      """
      Warning: HTTP proxy disabled: the http-proxy configuration has no url, host and port, or env setting.
      """
    And STDOUT should be:
      """
      HTTP proxy: disabled (the http-proxy configuration cannot be used)
      """

    Given a wp-cli.yml file:
      """
      _:
        merge: true
      http-proxy:
        bypass-hosts:
          - localhost
      """

    When I run `/usr/bin/env WP_CLI_CONFIG_PATH=global.yml wp http-proxy status`
    Then STDOUT should contain:
      """
      Host: proxy.example.com
      """
    And STDOUT should contain:
      """
      Authentication: yes
      """
    And STDOUT should contain:
      """
      Bypass hosts: localhost
      """

  Scenario: Check reports the proxy from WordPress proxy constants that a required file defines
    Given an empty directory
    And a proxy/index.php file:
      """
      <?php
      header( 'Content-Type: text/plain' );
      echo 'constant proxy reached ' . $_SERVER['REQUEST_URI'];
      """
    And a proxy-constants.php file:
      """
      <?php
      define( 'WP_PROXY_HOST', '127.0.0.1' );
      define( 'WP_PROXY_PORT', 18909 );
      """
    And I launch in the background `php -S 127.0.0.1:18909 -t proxy`
    And a wp-cli.yml file:
      """
      require:
        - proxy-constants.php
      http-proxy:
        host: 127.0.0.1
        port: 18897
      """

    When I run `wp http-proxy check http://constant-target.invalid/constant-check --body`
    Then STDOUT should contain:
      """
      Proxy: 127.0.0.1:18909
      """
    And STDOUT should contain:
      """
      Body: constant proxy reached http://constant-target.invalid/constant-check
      """
