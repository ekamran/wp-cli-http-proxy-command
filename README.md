# WP-CLI HTTP Proxy Command

Configure an opt-in HTTP proxy for WordPress core requests and WP-CLI requests made through its HTTP helper.

Built by [ShifteQ](https://shifteq.com).

## Installation

Install the latest release:

    wp package install ekamran/wp-cli-http-proxy-command:@stable

Or install the development version from the `main` branch:

    wp package install ekamran/wp-cli-http-proxy-command:dev-main

If `:@stable` fails with "Could not guess stable version", GitHub's API limit may have been reached. An install can also fail with "Could not authenticate against github.com" when the limit runs out during the install. Wait for it to reset, or install a specific release from the [Releases](https://github.com/ekamran/wp-cli-http-proxy-command/releases) page, which skips the stable version lookup:

    wp package install ekamran/wp-cli-http-proxy-command:v0.1.0

Replace `v0.1.0` with the latest stable version shown on the Releases page. With no API quota left, a fresh install worked in testing only when the machine had SSH access to GitHub.

## Compatibility

Requires PHP 7.2.24 or later, and WP-CLI 2.12 or a later 2.x release, or WP-CLI 3.x.

Tested with:

- WP-CLI 2.12.0 on PHP 7.2 and PHP 8.4.
- WP-CLI nightly (3.0.0-alpha) on PHP 8.5.
- Linux and macOS, and PHP without the cURL extension (see [Limitations](#limitations)). Not tested on Windows.

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

Only HTTP proxies are supported. A URL with another scheme, such as `socks5://` or `https://`, is not used.

In a URL, write an IPv6 address in brackets, such as `http://[2001:db8::1]:8080`. The `host` setting accepts it with or without brackets.

When the configuration cannot be used, for example a URL without a port, the package leaves the proxy off and prints a warning each time WP-CLI loads it.

Authentication and bypass hosts are supported:

    http-proxy:
      url: http://proxy.example.com:8080
      username: proxy-user
      password: proxy-password
      bypass-hosts:
        - localhost
        - "*.local"

This package does not read proxy environment variables by default. To use one as the package's proxy, opt in:

    http-proxy:
      env: true

When `env: true` is set, the package checks `HTTPS_PROXY`, `https_proxy`, `HTTP_PROXY`, then `http_proxy`.
The first non-empty value is used as one proxy for all supported requests. The package does not read `NO_PROXY` or `no_proxy`; configure those hosts with `bypass-hosts`.

cURL also reads the standard proxy environment variables on its own, which can change where requests sent with PHP's cURL extension go. See [Limitations](#limitations).

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
- Applies `bypass-hosts` to WordPress and WP-CLI HTTP requests, and checks each redirect of a WP-CLI request again.
- Requires an explicit proxy port in URL and host/port configuration.
- Warns when the proxy configuration cannot be used, and when only one of the username and password is set.
- Can be disabled with `enabled: false` or bypassed with `--skip-packages`.

## Limitations

This package covers WordPress core requests and WP-CLI requests that use `WP_CLI\Utils\http_request()`. Commands that use another HTTP client are outside that path.

When PHP's cURL extension sends a request, cURL also reads the standard proxy environment variables itself:

- With no `http-proxy` configuration, HTTPS requests still go through a proxy set in `https_proxy`, even though `wp http-proxy status` shows the package as disabled.
- A host listed in `no_proxy` or `NO_PROXY` skips the proxy configured by this package as well.
- A request to a host in `bypass-hosts` goes to the proxy set in the environment, if there is one, instead of connecting directly.

WordPress core never sends requests for `localhost` or for the host in its site URL through a proxy. WP-CLI requests for `localhost` do go through the proxy configured by this package, unless `localhost` is listed in `bypass-hosts`.

Without PHP's cURL extension, Requests sends requests with its socket transport. HTTP requests, proxy authentication and `bypass-hosts` work there, but HTTPS requests through the proxy fail: the socket transport cannot open a tunnel through the proxy, so the request fails before it is sent. WordPress core requests behave the same way.

WP-CLI does not load installed packages for `wp package` commands, so this package configures none of their requests. This includes the Composer and package-index networking used by `wp package browse`, `list`, `install`, and `update`, and the requests these commands send through WP-CLI's HTTP helper.

Composer reads the standard proxy environment variables itself. To send those commands through a proxy, set `https_proxy` when you run them (uppercase `HTTPS_PROXY` also works):

    https_proxy=http://proxy.example.com:8080 wp package update

## Development

Install dependencies:

    composer install

Run the local checks:

    composer test

The Behat suite covers opt-in config paths, environment handling, credentials, warnings for configuration that cannot be used, real local proxy and bypass requests through both WordPress and WP-CLI, Requests' socket transport, and clean failure behavior.
