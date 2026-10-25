# WP-CLI HTTP Proxy Command

Configure an opt-in HTTP proxy for WordPress core requests and WP-CLI requests made through its HTTP helper.

Built by [ShifteQ](https://shifteq.com).

## Installation

Install the latest release:

    wp package install ekamran/wp-cli-http-proxy-command:@stable

Or install the development version from the `main` branch:

    wp package install ekamran/wp-cli-http-proxy-command:dev-main

## Compatibility

Requires PHP 7.2.24 or later, and WP-CLI 2.12 or a later 2.x release, or WP-CLI 3.x.

Tested with:

- WP-CLI 2.12.0 on PHP 7.2 and PHP 8.4.
- WP-CLI nightly (3.0.0-alpha) on PHP 8.5.

Known upstream limitations:

- On PHP 8.5, WP-CLI 2.12 prints PHP deprecation notices from libraries bundled in WP-CLI itself ([wp-cli/wp-cli#6271](https://github.com/wp-cli/wp-cli/issues/6271)). WP-CLI recommends its nightly build on PHP 8.5 until a stable release with the fixes is out.
- On PHP 8.4, when PHP reports deprecation notices, WP-CLI 2.12's `wp package install` and `wp package list` print them from libraries bundled in WP-CLI, such as Composer. The package still installs, and this package's own commands printed none in testing.

## Configuration

Add an `http-proxy` block to `wp-cli.yml`:

    http-proxy:
      url: http://proxy.example.com:8080

Scheme-less proxy URLs are supported too:

    http-proxy:
      url: proxy.example.com:8080

Or configure host and port separately:

    http-proxy:
      host: proxy.example.com
      port: 8080

Authentication and bypass hosts are supported:

    http-proxy:
      url: http://proxy.example.com:8080
      username: proxy-user
      password: proxy-password
      bypass-hosts:
        - localhost
        - "*.local"

Environment variables are not read by default. To opt into environment lookup:

    http-proxy:
      env: true

When `env: true` is set, the command checks `HTTPS_PROXY`, `https_proxy`, `HTTP_PROXY`, then `http_proxy`.
The first non-empty value is used as one proxy for all supported requests. `NO_PROXY` and `no_proxy` are not read; configure those hosts with `bypass-hosts`.

Proxy credentials in `wp-cli.yml` are stored as plain text. Keep configuration containing credentials out of version control and restrict access to the file, or use an appropriate secret-management mechanism.

## Commands

Check the current proxy configuration:

    wp http-proxy status

Perform a test request through WP-CLI's HTTP helper:

    wp http-proxy check http://example.com

## Behavior

- Defines missing WordPress proxy constants after `wp-config.php` loads.
- Configures WP-CLI's own HTTP requests through its Requests hooks.
- Normalizes proxy URLs to Requests' `host:port` format.
- Applies `bypass-hosts` to WordPress and WP-CLI HTTP requests when the request URL is available.
- Requires an explicit proxy port in URL and host/port configuration.
- Can be disabled with `enabled: false` or bypassed with `--skip-packages`.

## Limitations

This package covers WordPress core requests and WP-CLI requests that use `WP_CLI\Utils\http_request()`. Commands that use another HTTP client are outside that path.

In particular, the Composer and package-index networking used by `wp package browse`, `list`, `install`, and `update` is separate and is not configured by this package. Individual command paths that call WP-CLI's HTTP helper directly can still use the proxy.

## Development

Install dependencies:

    composer install

Run the local checks:

    composer test

The Behat suite covers opt-in config paths, environment handling, credentials, real local proxy and bypass requests through both WordPress and WP-CLI, and clean failure behavior.
