<?php

namespace WP_CLI\HttpProxy;

use WP_CLI;

final class Bootstrap {
	public static function init() {
		$config = ProxyConfig::from_runner();

		if ( $config ) {
			self::configure_wp_cli_requests( $config );
			WP_CLI::add_hook(
				'after_wp_config_load',
				static function () use ( $config ) {
					self::define_wordpress_constants( $config );
				}
			);
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
		// These are the proxy constants consumed by WordPress core.
		if ( ! defined( 'WP_PROXY_HOST' ) ) {
			// phpcs:ignore WordPress.NamingConventions.PrefixAllGlobals.NonPrefixedConstantFound
			define( 'WP_PROXY_HOST', $config->host() );
		}

		if ( ! defined( 'WP_PROXY_PORT' ) ) {
			// phpcs:ignore WordPress.NamingConventions.PrefixAllGlobals.NonPrefixedConstantFound
			define( 'WP_PROXY_PORT', $config->port() );
		}

		$username = $config->username();
		$password = $config->password();

		if ( null !== $username && null !== $password ) {
			if ( ! defined( 'WP_PROXY_USERNAME' ) ) {
				// phpcs:ignore WordPress.NamingConventions.PrefixAllGlobals.NonPrefixedConstantFound
				define( 'WP_PROXY_USERNAME', $username );
			}

			if ( ! defined( 'WP_PROXY_PASSWORD' ) ) {
				// phpcs:ignore WordPress.NamingConventions.PrefixAllGlobals.NonPrefixedConstantFound
				define( 'WP_PROXY_PASSWORD', $password );
			}
		}

		$bypass_hosts = $config->bypass_hosts();

		if ( null !== $bypass_hosts && ! defined( 'WP_PROXY_BYPASS_HOSTS' ) ) {
			// phpcs:ignore WordPress.NamingConventions.PrefixAllGlobals.NonPrefixedConstantFound
			define( 'WP_PROXY_BYPASS_HOSTS', $bypass_hosts );
		}
	}

	private static function configure_wp_cli_requests( ProxyConfig $config ) {
		WP_CLI::add_hook(
			'http_request_options',
			static function ( $options, $method = null, $url = null ) use ( $config ) {
				if ( null === $url || ! self::should_bypass_url( $config, $url ) ) {
					$options['proxy'] = self::requests_proxy( $config );
				}

				return $options;
			}
		);
	}

	private static function requests_proxy( ProxyConfig $config ) {
		if ( defined( 'WP_PROXY_HOST' ) && defined( 'WP_PROXY_PORT' ) ) {
			$proxy = WP_PROXY_HOST . ':' . WP_PROXY_PORT;

			if ( defined( 'WP_PROXY_USERNAME' ) && defined( 'WP_PROXY_PASSWORD' ) ) {
				return [ $proxy, WP_PROXY_USERNAME, WP_PROXY_PASSWORD ];
			}

			return $proxy;
		}

		return $config->requests_proxy();
	}

	private static function should_bypass_url( ProxyConfig $config, $url ) {
		if ( defined( 'WP_PROXY_BYPASS_HOSTS' ) ) {
			$bypass_hosts = array_map( 'trim', explode( ',', WP_PROXY_BYPASS_HOSTS ) );

			return ProxyConfig::url_matches_bypass_hosts( $url, $bypass_hosts );
		}

		return $config->should_bypass_url( $url );
	}
}
