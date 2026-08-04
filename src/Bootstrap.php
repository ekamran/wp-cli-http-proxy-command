<?php

namespace WP_CLI\HttpProxy;

use WP_CLI;
use WP_CLI\RequestsLibrary;

final class Bootstrap {
	/** @var bool */
	private static $initialized = false;

	public static function init() {
		if ( self::$initialized ) {
			return;
		}

		self::$initialized = true;
		$config            = ProxyConfig::from_runner();

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
			static function ( $options ) use ( $config ) {
				RequestsLibrary::register_autoloader();

				if ( empty( $options['hooks'] ) ) {
					$options['hooks'] = self::requests_hooks();
				}

				// Requests exposes the URL here in both WP-CLI 2.x and 3.x.
				self::register_requests_proxy( $options['hooks'], $config );
				$options['proxy'] = false;

				return $options;
			}
		);
	}

	private static function requests_hooks() {
		$class = RequestsLibrary::is_v1() ? '\\Requests_Hooks' : '\\WpOrg\\Requests\\Hooks';

		return new $class();
	}

	private static function register_requests_proxy( $hooks, ProxyConfig $config ) {
		$proxy_class   = RequestsLibrary::is_v1() ? '\\Requests_Proxy_HTTP' : '\\WpOrg\\Requests\\Proxy\\Http';
		$proxy         = new $proxy_class( self::requests_proxy( $config ) );
		$proxy_enabled = false;

		$hooks->register(
			'requests.before_request',
			static function ( $url ) use ( $config, &$proxy_enabled ) {
				$proxy_enabled = ! self::should_bypass_url( $config, $url );
			}
		);
		$hooks->register(
			'curl.before_send',
			static function ( &$handle ) use ( $proxy, &$proxy_enabled ) {
				if ( $proxy_enabled ) {
					$proxy->curl_before_send( $handle );
				}
			}
		);
		$hooks->register(
			'fsockopen.remote_socket',
			static function ( &$remote_socket ) use ( $proxy, &$proxy_enabled ) {
				if ( $proxy_enabled ) {
					$proxy->fsockopen_remote_socket( $remote_socket );
				}
			}
		);
		$hooks->register(
			'fsockopen.remote_host_path',
			static function ( &$path, $url ) use ( $proxy, &$proxy_enabled ) {
				if ( $proxy_enabled ) {
					$proxy->fsockopen_remote_host_path( $path, $url );
				}
			}
		);

		if ( $proxy->use_authentication ) {
			$hooks->register(
				'fsockopen.after_headers',
				static function ( &$headers ) use ( $proxy, &$proxy_enabled ) {
					if ( $proxy_enabled ) {
						$proxy->fsockopen_header( $headers );
					}
				}
			);
		}
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
