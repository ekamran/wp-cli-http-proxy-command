<?php

namespace WP_CLI\HttpProxy;

use WP_CLI;

final class Bootstrap {
	public static function init() {
		$config = ProxyConfig::from_runner();

		if ( $config ) {
			self::define_wordpress_constants( $config );
			self::configure_wp_cli_requests( $config );
		}

		WP_CLI::add_command(
			'http-proxy',
			Command::class,
			[
				'when' => 'before_wp_load',
			]
		);
	}

	private static function define_wordpress_constants( ProxyConfig $config ) {
		if ( ! defined( 'WP_PROXY_HOST' ) ) {
			define( 'WP_PROXY_HOST', $config->host() );
		}

		if ( ! defined( 'WP_PROXY_PORT' ) ) {
			define( 'WP_PROXY_PORT', $config->port() );
		}

		$username = $config->username();
		$password = $config->password();

		if ( null !== $username && null !== $password ) {
			if ( ! defined( 'WP_PROXY_USERNAME' ) ) {
				define( 'WP_PROXY_USERNAME', $username );
			}

			if ( ! defined( 'WP_PROXY_PASSWORD' ) ) {
				define( 'WP_PROXY_PASSWORD', $password );
			}
		}

		$bypass_hosts = $config->bypass_hosts();

		if ( null !== $bypass_hosts && ! defined( 'WP_PROXY_BYPASS_HOSTS' ) ) {
			define( 'WP_PROXY_BYPASS_HOSTS', $bypass_hosts );
		}
	}

	private static function configure_wp_cli_requests( ProxyConfig $config ) {
		WP_CLI::add_hook(
			'http_request_options',
			static function ( $options, $method, $url ) use ( $config ) {
				if ( ! $config->should_bypass_url( $url ) ) {
					$options['proxy'] = $config->requests_proxy();
				}

				return $options;
			}
		);
	}
}
