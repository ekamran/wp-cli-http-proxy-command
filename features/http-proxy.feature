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

  Scenario: Show proxy authentication and bypass hosts
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user:pass@proxy.example.com:8084
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

  Scenario: Define WordPress proxy constants
    Given an empty directory
    And a wp-cli.yml file:
      """
      http-proxy:
        url: http://user:pass@proxy.example.com:8086
        bypass-hosts:
          - localhost
      """

    When I run `wp eval 'echo WP_PROXY_HOST . ":" . WP_PROXY_PORT . ":" . WP_PROXY_USERNAME . ":" . WP_PROXY_PASSWORD . ":" . WP_PROXY_BYPASS_HOSTS;' --skip-wordpress`
    Then STDOUT should be:
      """
      proxy.example.com:8086:user:pass:localhost
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
