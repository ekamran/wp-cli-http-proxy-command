# WP-CLI HTTP Proxy Command

Configure an opt-in HTTP proxy for WordPress core requests and WP-CLI requests made through its HTTP helper.

Requires WP-CLI 2.12.0 or later in the 2.x release line.

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

## Commands

Check the current proxy configuration:

    wp http-proxy status

Perform a test request through WP-CLI's HTTP helper:

    wp http-proxy check http://example.com

## Behavior

- Defines missing WordPress proxy constants after `wp-config.php` loads.
- Configures WP-CLI's own HTTP requests through `http_request_options`.
- Normalizes proxy URLs to Requests' `host:port` format.
- Applies `bypass-hosts` to WordPress and WP-CLI HTTP requests when the request URL is available.
- Can be disabled with `enabled: false` or bypassed with `--skip-packages`.

## Limitations

Composer-backed `wp package` commands, including `browse`, `list`, `install`, and `update`, use a separate HTTP client. Their network requests are not configured by this package.

## Development

Install dependencies:

    composer install

Run the local checks:

    composer test

The Behat suite covers the opt-in config paths, safe environment variable handling, a local proxy request, and bypass host behavior.
