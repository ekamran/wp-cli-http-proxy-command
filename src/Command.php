<?php

namespace WP_CLI\HttpProxy;

use WP_CLI;
use WP_CLI\Utils;

final class Command {
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

		WP_CLI::line( 'Status: ' . $response->status_code );
		WP_CLI::line( 'Body: ' . $response->body );
	}
}
