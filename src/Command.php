<?php

namespace WP_CLI\HttpProxy;

use RuntimeException;
use WP_CLI;
use WP_CLI\Utils;

/**
 * Shows the HTTP proxy configuration and tests requests through it.
 */
final class Command {
	/**
	 * Shows the current HTTP proxy configuration.
	 */
	public function status() {
		$loaded = ProxyConfig::load_from_runner();
		$config = $loaded['config'];

		if ( ! $config ) {
			WP_CLI::line( 'HTTP proxy: disabled (' . $loaded['off_reason'] . ')' );
			return;
		}

		WP_CLI::line( 'HTTP proxy: enabled' );
		WP_CLI::line( 'Host: ' . $config->host() );
		WP_CLI::line( 'Port: ' . $config->port() );
		WP_CLI::line( 'Authentication: ' . ( null !== $config->username() && null !== $config->password() ? 'yes' : 'no' ) );
		WP_CLI::line( 'Bypass hosts: ' . ( $config->bypass_hosts() ?: 'none' ) );
	}

	/**
	 * Performs a test request through WP-CLI's HTTP helper.
	 *
	 * Prints the proxy this package sets for the URL, then the response status and the size of the response body.
	 *
	 * ## OPTIONS
	 *
	 * <url>
	 * : URL to request.
	 *
	 * [--body]
	 * : Print the response body instead of its size.
	 *
	 * ## EXAMPLES
	 *
	 *     $ wp http-proxy check http://example.com
	 *     Proxy: proxy.example.com:8080
	 *     Status: 200
	 *     Body size: 577 bytes
	 */
	public function check( $args, $assoc_args ) {
		list( $url ) = $args;
		$response    = null;
		$loaded      = ProxyConfig::load_from_runner();
		$config      = $loaded['config'];
		$proxy       = $config ? Bootstrap::proxy_for_url( $config, $url ) : null;

		if ( ! $config ) {
			WP_CLI::line( 'Proxy: none (' . $loaded['off_reason'] . ')' );
		} elseif ( null === $proxy ) {
			WP_CLI::line( 'Proxy: none (the host is in bypass-hosts)' );
		} elseif ( is_array( $proxy ) ) {
			WP_CLI::line( 'Proxy: ' . $proxy[0] . ' (with authentication)' );
		} else {
			WP_CLI::line( 'Proxy: ' . $proxy );
		}

		$curl_variables = self::curl_proxy_variables( $url, null !== $proxy );

		if ( $curl_variables && null !== $proxy ) {
			WP_CLI::line( 'Note: cURL also reads ' . implode( ' and ', $curl_variables ) . ', so a host listed there skips this proxy.' );
		} elseif ( $curl_variables ) {
			WP_CLI::line( 'Note: cURL also reads ' . implode( ' and ', $curl_variables ) . ', so this request can still go through a proxy set there.' );
		}

		try {
			$response = Utils\http_request(
				'GET',
				$url,
				null,
				[],
				[
					'halt_on_error' => false,
					'max_retries'   => 1,
				]
			);
		} catch ( RuntimeException $exception ) {
			WP_CLI::error( $exception->getMessage() );
		}

		// Inside a WordPress install older than 6.2, WP-CLI uses that install's Requests 1.x.
		if ( $response instanceof \WpOrg\Requests\Response || $response instanceof \Requests_Response ) {
			WP_CLI::line( 'Status: ' . $response->status_code );

			if ( Utils\get_flag_value( $assoc_args, 'body', false ) ) {
				WP_CLI::line( 'Body: ' . $response->body );
			} else {
				WP_CLI::line( 'Body size: ' . strlen( $response->body ) . ' bytes' );
			}

			return;
		}

		WP_CLI::error( 'WP-CLI returned an unexpected HTTP response.' );
	}

	/**
	 * Names the proxy environment variables that cURL reads for this request and that are set.
	 *
	 * When this package sets a proxy, cURL ignores its own proxy variables but still reads its bypass list.
	 * cURL reads http_proxy only in lowercase.
	 *
	 * @param string $url     Requested URL.
	 * @param bool   $proxied Whether this package sets a proxy for the request.
	 * @return string[]
	 */
	private static function curl_proxy_variables( $url, $proxied ) {
		// Requests sends the request with its socket transport when PHP has no cURL extension.
		if ( ! function_exists( 'curl_init' ) ) {
			return [];
		}

		if ( $proxied ) {
			$names = [ 'no_proxy', 'NO_PROXY' ];
		} else {
			// wp_parse_url() is not available before WordPress loads.
			// phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
			$scheme = strtolower( (string) parse_url( $url, PHP_URL_SCHEME ) );
			$names  = 'https' === $scheme ? [ 'https_proxy', 'HTTPS_PROXY' ] : [ 'http_proxy' ];
			$names  = array_merge( $names, [ 'all_proxy', 'ALL_PROXY' ] );
		}

		return array_values(
			array_filter(
				$names,
				static function ( $name ) {
					$value = getenv( $name );

					return false !== $value && '' !== $value;
				}
			)
		);
	}
}
