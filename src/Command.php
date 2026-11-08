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
		$config = ProxyConfig::from_runner();

		if ( ! $config ) {
			WP_CLI::line( 'HTTP proxy: disabled' );
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
	 * ## OPTIONS
	 *
	 * <url>
	 * : URL to request.
	 */
	public function check( $args ) {
		list( $url ) = $args;
		$response    = null;

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
			WP_CLI::line( 'Body: ' . $response->body );
			return;
		}

		WP_CLI::error( 'WP-CLI returned an unexpected HTTP response.' );
	}
}
