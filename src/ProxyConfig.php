<?php

namespace WP_CLI\HttpProxy;

use WP_CLI;

final class ProxyConfig {
	/**
	 * @var array<string, mixed>
	 */
	private $config;

	/**
	 * @var array{host: string, port: int|string, user?: string, pass?: string}
	 */
	private $parts;

	/**
	 * @param array<string, mixed> $config
	 * @param array{host: string, port: int|string, user?: string, pass?: string} $parts
	 */
	private function __construct( array $config, array $parts ) {
		$this->config = $config;
		$this->parts  = $parts;
	}

	public static function from_runner() {
		$runner = WP_CLI::get_runner();

		if ( ! $runner || empty( $runner->extra_config['http-proxy'] ) || ! is_array( $runner->extra_config['http-proxy'] ) ) {
			return null;
		}

		$config = $runner->extra_config['http-proxy'];

		if ( isset( $config['enabled'] ) && ! self::to_bool( $config['enabled'] ) ) {
			return null;
		}

		$parts = self::resolve_parts( $config );

		if ( ! $parts ) {
			return null;
		}

		return new self( $config, $parts );
	}

	public function host() {
		return (string) $this->parts['host'];
	}

	public function port() {
		return (string) $this->parts['port'];
	}

	public function username() {
		if ( isset( $this->config['username'] ) ) {
			return self::config_string( $this->config['username'] );
		}

		if ( isset( $this->parts['user'] ) ) {
			return rawurldecode( $this->parts['user'] );
		}

		return null;
	}

	public function password() {
		if ( isset( $this->config['password'] ) ) {
			return self::config_string( $this->config['password'] );
		}

		if ( isset( $this->parts['pass'] ) ) {
			return rawurldecode( $this->parts['pass'] );
		}

		return null;
	}

	public function bypass_hosts() {
		if ( empty( $this->config['bypass-hosts'] ) ) {
			return null;
		}

		if ( is_array( $this->config['bypass-hosts'] ) ) {
			$hosts = array_filter(
				array_map( [ self::class, 'config_string' ], $this->config['bypass-hosts'] ),
				static function ( $host ) {
					return null !== $host;
				}
			);

			return $hosts ? implode( ',', $hosts ) : null;
		}

		return self::config_string( $this->config['bypass-hosts'] );
	}

	/**
	 * @return string[]
	 */
	public function bypass_hosts_list() {
		$bypass_hosts = $this->bypass_hosts();

		if ( null === $bypass_hosts ) {
			return [];
		}

		return array_filter( array_map( 'trim', explode( ',', $bypass_hosts ) ) );
	}

	public function should_bypass_url( $url ) {
		return self::url_matches_bypass_hosts( $url, $this->bypass_hosts_list() );
	}

	public function requests_proxy() {
		$proxy    = $this->host() . ':' . $this->port();
		$username = $this->username();
		$password = $this->password();

		if ( null !== $username && null !== $password ) {
			return [ $proxy, $username, $password ];
		}

		return $proxy;
	}

	/**
	 * @param string[] $bypass_hosts
	 */
	public static function url_matches_bypass_hosts( $url, array $bypass_hosts ) {
		// wp_parse_url() is not available before WordPress loads.
		// phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
		$parts = parse_url( $url );

		if ( ! is_array( $parts ) || empty( $parts['host'] ) ) {
			return false;
		}

		$host = strtolower( (string) $parts['host'] );

		foreach ( $bypass_hosts as $pattern ) {
			$pattern = strtolower( trim( $pattern ) );

			if ( '' === $pattern ) {
				continue;
			}

			if ( $host === $pattern ) {
				return true;
			}

			$regex = '/^' . str_replace( '\*', '.*', preg_quote( $pattern, '/' ) ) . '$/';

			if ( preg_match( $regex, $host ) ) {
				return true;
			}
		}

		return false;
	}

	/**
	 * @param array<string, mixed> $config
	 * @return array{host: string, port: int|string, user?: string, pass?: string}|null
	 */
	private static function resolve_parts( array $config ) {
		if ( isset( $config['url'] ) ) {
			$url = self::config_string( $config['url'] );

			if ( null !== $url && '' !== $url ) {
				return self::parse_url( $url );
			}
		}

		if ( isset( $config['host'], $config['port'] ) ) {
			$host = self::config_string( $config['host'] );
			$port = self::normalize_port( $config['port'] );

			if ( null === $host || '' === $host || null === $port ) {
				return null;
			}

			return [
				'host' => $host,
				'port' => $port,
			];
		}

		if ( ! empty( $config['env'] ) && self::to_bool( $config['env'] ) ) {
			$env = self::proxy_env();

			if ( $env ) {
				return self::parse_url( $env );
			}
		}

		return null;
	}

	/**
	 * @return array{host: string, port: int|string, user?: string, pass?: string}|null
	 */
	private static function parse_url( $url ) {
		if ( false === strpos( $url, '://' ) ) {
			$url = 'http://' . $url;
		}

		// wp_parse_url() is not available before WordPress loads.
		// phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
		$parts = parse_url( $url );

		if ( ! is_array( $parts ) || empty( $parts['host'] ) || ! isset( $parts['port'] ) ) {
			return null;
		}

		$port = self::normalize_port( $parts['port'] );

		if ( null === $port ) {
			return null;
		}

		$normalized = [
			'host' => $parts['host'],
			'port' => $port,
		];

		if ( isset( $parts['user'] ) ) {
			$normalized['user'] = $parts['user'];
		}

		if ( isset( $parts['pass'] ) ) {
			$normalized['pass'] = $parts['pass'];
		}

		return $normalized;
	}

	private static function normalize_port( $port ) {
		if ( ! is_int( $port ) && ! is_string( $port ) ) {
			return null;
		}

		if ( ! ctype_digit( (string) $port ) ) {
			return null;
		}

		$port = (int) $port;

		return $port >= 1 && $port <= 65535 ? $port : null;
	}

	private static function config_string( $value ) {
		if ( ! is_string( $value ) && ! is_int( $value ) && ! is_float( $value ) ) {
			return null;
		}

		return (string) $value;
	}

	private static function proxy_env() {
		foreach ( [ 'HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy' ] as $name ) {
			$value = getenv( $name );

			if ( false !== $value && '' !== $value ) {
				return $value;
			}
		}

		return false;
	}

	private static function to_bool( $value ) {
		return filter_var( $value, FILTER_VALIDATE_BOOLEAN );
	}
}
