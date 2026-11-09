# WP-CLI HTTP Proxy Command

Configure an opt-in HTTP proxy for WordPress core requests and WP-CLI requests made through its HTTP helper.

Built by [ShifteQ](https://shifteq.com).

## Installation

Install the latest release:

    wp package install ekamran/wp-cli-http-proxy-command:@stable

Or install the development version from the `main` branch:

    wp package install ekamran/wp-cli-http-proxy-command:dev-main

The package is on [Packagist](https://packagist.org/packages/ekamran/wp-cli-http-proxy-command). WP-CLI nightly installs it from there, without GitHub API requests. WP-CLI 2.12 looks up Packagist at an address Packagist no longer serves, so it installs the package from GitHub, through GitHub's API. Without a GitHub token, that API allows 60 requests an hour per IP address, and one install used about 20 in testing.

With WP-CLI 2.12, if `:@stable` fails with "Could not guess stable version", GitHub's API limit may have been reached. An install can also fail with "Could not authenticate against github.com" when the limit runs out during the install. Wait for it to reset, or install a specific release from the [Releases](https://github.com/ekamran/wp-cli-http-proxy-command/releases) page, which skips the stable version lookup:

    wp package install ekamran/wp-cli-http-proxy-command:v0.1.3

Replace `v0.1.3` with the latest stable version shown on the Releases page. With no API quota left, a fresh install worked in testing only when the machine had SSH access to GitHub.

### Behind a proxy

WP-CLI does not load installed packages for `wp package` commands, so this package's proxy does not apply to its own install. When the machine reaches the internet only through a proxy, set `https_proxy` for the install. For a proxy with a login, use `http://user:password@proxy.example.com:8080`:

    https_proxy=http://proxy.example.com:8080 wp package install ekamran/wp-cli-http-proxy-command:@stable

A password typed into a command is saved in your shell history. Where you can, set `https_proxy` from a file only you can read, or from your secret manager, before you run the command.

Set it the same way for `wp package update` and `wp package uninstall`.

### Without `wp package install`

If `wp package install` cannot reach GitHub or Packagist, for example behind a proxy that accepts only NTLM logins, which Composer could not log in to in testing, load the package from a copy. Download the source ZIP of a release from the [Releases](https://github.com/ekamran/wp-cli-http-proxy-command/releases) page, unzip it, and require its main file in `wp-cli.yml` or `~/.wp-cli/config.yml`:

    require:
      - /path/to/wp-cli-http-proxy-command/http-proxy-command.php

A file loaded with `require:` still loads when you pass `--skip-packages`.

## Updating

Read the upgrade notes of a new release on the [Releases](https://github.com/ekamran/wp-cli-http-proxy-command/releases) page first.

With WP-CLI 2.12, `wp package update` keeps the release that `:@stable` installed. To move to a newer release, run the install command again:

    wp package install ekamran/wp-cli-http-proxy-command:@stable

WP-CLI nightly records `@stable` for that install, so there `wp package update` moves to the newest release. An install of a specific version, such as `:v0.1.1`, stays on that version with either.

## Uninstalling

    wp package uninstall ekamran/wp-cli-http-proxy-command

Then remove the `http-proxy` block from your configuration. Once the package is gone, WP-CLI ignores the block without a warning.

## Compatibility

Requires PHP 7.2.24 or later, and WP-CLI 2.12 or a later 2.x release, or WP-CLI 3.x.

Tested with:

- WP-CLI 2.12.0 on PHP 7.2 to 8.4 with SQLite, and on PHP 8.3 with MySQL 8.4.
- WP-CLI nightly (3.0.0-alpha) on PHP 8.5.
- WordPress 6.9 on PHP 7.2 and 7.3, the latest WordPress release on newer PHP versions, and WordPress trunk on PHP 8.4.
- Linux and macOS, and PHP without the cURL extension (see [Limitations](#limitations)). Not tested on Windows.
- End to end on the official `wordpress:cli-php8.4` image, with WP-CLI 2.12.0 and nightly, where a Squid 6.13 proxy was the only way out of the network: `wp package install`, `update` and `uninstall`; `wp core download`, `install`, `check-update`, `update` and `verify-checksums`; `wp plugin install`, `update` and `verify-checksums`; `wp theme install`; `wp language core install`; and `wp cli check-update`. With no proxy login, a Basic login, and `env: true`. The `wp core`, `wp plugin`, `wp theme`, `wp language` and `wp cli` steps also passed with a Digest login, and with an NTLM login on a Debian-based `php:8.4-cli` image with the package loaded through `require:`.

Known upstream limitations:

- On PHP 8.5, WP-CLI 2.12 prints PHP deprecation notices from libraries bundled in WP-CLI itself ([wp-cli/wp-cli#6271](https://github.com/wp-cli/wp-cli/issues/6271)). WP-CLI recommends its nightly build on PHP 8.5 until a stable release with the fixes is out.
- On PHP 8.4, when PHP reports deprecation notices, WP-CLI 2.12's `wp package install` and `wp package list` print them from libraries bundled in WP-CLI, such as Composer. The package still installs, and this package's own commands printed none in testing.
- On the official `wordpress:cli` image, WP-CLI 2.12.0's `wp core download` ran out of memory at PHP's default 128M while extracting WordPress. It worked with `php -d memory_limit=512M`. WP-CLI nightly did not run out.

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

Only HTTP proxies are supported. A URL with another scheme, such as `socks5://` or `https://`, is not used. Proxy auto-config (PAC) files and automatic proxy discovery are not supported either: set the HTTP proxy's own address.

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

In a `url`, percent-encode special characters in the username and password, such as `@` as `%40`. The separate `username` and `password` settings take them as written.

This package does not read proxy environment variables by default. To use one as the package's proxy, opt in:

    http-proxy:
      env: true

A `url`, or a `host` and `port`, takes precedence over `env: true`.

When `env: true` is set, the package checks `HTTPS_PROXY`, `https_proxy`, `HTTP_PROXY`, then `http_proxy`.
The first non-empty value is used as one proxy for all supported requests. The package does not read `NO_PROXY` or `no_proxy`; configure those hosts with `bypass-hosts`.

cURL also reads the standard proxy environment variables on its own, which can change where requests sent with PHP's cURL extension go. See [Limitations](#limitations).

Proxy credentials in `wp-cli.yml` are stored as plain text. Keep configuration containing credentials out of version control and restrict access to the file, or use an appropriate secret-management mechanism.

Keep the whole `http-proxy` block in one configuration file. When more than one file sets it, such as `~/.wp-cli/config.yml` and `wp-cli.yml`, WP-CLI uses the block from the file with the highest priority and ignores the others, unless that file sets `_: merge: true`.

## Commands

Check the current proxy configuration:

    wp http-proxy status

Perform a test request through WP-CLI's HTTP helper:

    wp http-proxy check http://example.com

It prints the proxy this package sets for the URL, then the response status and the size of the response body, for example:

    Proxy: proxy.example.com:8080
    Status: 200
    Body size: 577 bytes

`Proxy: none` gives the reason this package sets no proxy for the URL: there is no `http-proxy` configuration, it has `enabled: false`, it cannot be used (a warning names the problem), `env: true` found no proxy environment variable, or the host is in `bypass-hosts`. When the proxy is off, `status` gives the same reason after `HTTP proxy: disabled`. Add `--body` to print the response body instead of its size.

When cURL sends the request, `check` also names any proxy environment variable that cURL reads for it, because that variable can change the route. See [Limitations](#limitations).

## Behavior

- Defines missing WordPress proxy constants after `wp-config.php` loads.
- When `wp-config.php` already defines `WP_PROXY_HOST` and `WP_PROXY_PORT`, WordPress uses them, and so do WP-CLI requests made after WordPress loads. `wp http-proxy status` and `check` run before WordPress loads, so they do not see proxy constants from `wp-config.php`.
- Configures WP-CLI's own HTTP requests through its Requests hooks.
- Normalizes proxy URLs to Requests' `host:port` format.
- Applies `bypass-hosts` to WordPress and WP-CLI HTTP requests, and checks each redirect of a WP-CLI request again.
- Requires an explicit proxy port in URL and host/port configuration.
- Warns when the proxy configuration cannot be used, and when only one of the username and password is set.
- Can be disabled with `enabled: false`. When installed with `wp package install`, it is also skipped with `--skip-packages`; a copy loaded with `require:` is not.

## Proxy logins

The package passes the username and password to Requests, which lets cURL choose the login method the proxy asks for. In testing with Squid:

- Basic: works.
- Digest: works when PHP's cURL extension sends the request.
- NTLM: works when PHP's cURL library was built with NTLM support, as in the Debian-based `php` images. The cURL library in the Alpine-based `wordpress:cli` image has no NTLM, and the proxy refuses the login with `CONNECT tunnel failed, response 407`. To check your PHP:

      php -r 'echo curl_version()["features"] & CURL_VERSION_NTLM ? "NTLM: yes" : "NTLM: no", PHP_EOL;'

- Kerberos (Negotiate): not tested.

Without PHP's cURL extension, Requests' socket transport sends Basic logins only. `wp package` commands use Composer, which could not log in to an NTLM-only proxy in testing. See [Without `wp package install`](#without-wp-package-install).

## HTTPS inspection

Some company proxies inspect HTTPS: they sign each site's certificate with their own certificate authority (CA). Until that CA is trusted, requests fail with `cURL error 60: SSL certificate OpenSSL verify result: unable to get local issuer certificate`. This package does not change certificate checks.

Add the proxy's CA to the operating system's trust store. On Debian, Ubuntu and Alpine:

    cp proxy-ca.pem /usr/local/share/ca-certificates/proxy-ca.crt
    update-ca-certificates

In testing on the `wordpress:cli` image, WP-CLI requests, WordPress requests and `wp package install` then worked. PHP's cURL library in the Debian and Alpine images also reads the system CA folder, `/etc/ssl/certs`, next to the CA bundle that WordPress sets.

If you cannot change the trust store, make one file with the system CAs and the proxy's CA. Keep the system CAs in it for hosts the proxy does not inspect:

    cat /etc/ssl/certs/ca-certificates.crt proxy-ca.pem > /path/to/ca-with-proxy.pem

Then point both WP-CLI and WordPress at it:

- WP-CLI: set `curl.cainfo = /path/to/ca-with-proxy.pem` in the `php.ini` that WP-CLI runs with.
- WordPress verifies with its own CA bundle, so add an mu-plugin:

      <?php
      add_filter(
          'http_request_args',
          static function ( $args ) {
              $args['sslcertificates'] = '/path/to/ca-with-proxy.pem';
              return $args;
          }
      );

Tested with mitmproxy as the inspecting proxy.

## Limitations

This package covers WordPress core requests and WP-CLI requests that use `WP_CLI\Utils\http_request()`. Commands that use another HTTP client are outside that path.

When PHP's cURL extension sends a request, cURL also reads the standard proxy environment variables itself:

- With no `http-proxy` configuration, HTTPS requests still go through a proxy set in `https_proxy`, even though `wp http-proxy status` shows the package as disabled.
- A host listed in `no_proxy` or `NO_PROXY` skips the proxy configured by this package as well.
- A request to a host in `bypass-hosts` goes to the proxy set in the environment, if there is one, instead of connecting directly.

WordPress core never sends requests for `localhost` or for the host in its site URL through a proxy. WP-CLI requests for `localhost` do go through the proxy configured by this package, unless `localhost` is listed in `bypass-hosts`.

WordPress looks up the IP address of a download's host before it downloads a plugin, theme, translation or update, even when a proxy sends the request (`wp_safe_remote_get()`). On a machine that cannot resolve public hostnames such as `downloads.wordpress.org`, `wp plugin install`, `wp plugin update`, `wp theme install` and `wp language core install` fail with `A valid URL was not provided.`, while `wp core download`, `wp core update` and the checksum commands work. Such a machine needs DNS for public hostnames.

Without PHP's cURL extension, Requests sends requests with its socket transport. HTTP requests, proxy authentication and `bypass-hosts` work there, but HTTPS requests through the proxy fail: the socket transport cannot open a tunnel through the proxy, so the request fails before it is sent. WordPress core requests behave the same way.

WP-CLI does not load installed packages for `wp package` commands, so this package configures none of their requests. This includes the Composer and package-index networking used by `wp package browse`, `list`, `install`, and `update`, and the requests these commands send through WP-CLI's HTTP helper.

Composer reads the standard proxy environment variables itself, so set `https_proxy` (or `HTTPS_PROXY`) for these commands, as shown in [Behind a proxy](#behind-a-proxy).

## Troubleshooting

Start with `wp http-proxy status` and `wp http-proxy check <url>`.

| Message | Likely cause |
|---|---|
| `Warning: HTTP proxy disabled: ...` | The setting it names cannot be used. |
| `cURL error 7: Failed to connect to ... over proxy ...` | The proxy host or port is wrong, or the proxy is down. |
| `cURL error 7: Failed to connect to ...` after `Proxy: none (...)` | No proxy is set for that request. |
| `cURL error 7: CONNECT tunnel failed, response 407` | A wrong username or password, or a login method PHP's cURL cannot use. See [Proxy logins](#proxy-logins). |
| `cURL error 60: SSL certificate ...` | The proxy inspects HTTPS. See [HTTPS inspection](#https-inspection). |
| `A valid URL was not provided.` | The machine cannot resolve the download host. See [Limitations](#limitations). |
| `Error: Package installation failed.` behind a proxy | `wp package` commands do not use this package. See [Behind a proxy](#behind-a-proxy). |

## Development

Install dependencies:

    composer install

Run the local checks:

    composer test

The Behat suite covers opt-in config paths, environment handling, credentials, warnings for configuration that cannot be used, the route and reasons that `check` and `status` report, real local proxy and bypass requests through both WordPress and WP-CLI, Requests' socket transport, and clean failure behavior.
