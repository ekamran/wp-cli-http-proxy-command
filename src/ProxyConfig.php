<?php

namespace WP_CLI\HttpProxy;

use WP_CLI;

final class ProxyConfig {
	/**
	 * @var array<string, mixed>
	 */
	private $config;

	/**
	 * @var array<string, mixed>
	 */
	private $parts;

	/**
	 * @param array<string, mixed> $config
	 * @param array<string, mixed> $parts
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
			return rawurldecode( (string) $this->config['username'] );
		}

		if ( isset( $this->parts['user'] ) ) {
			return rawurldecode( (string) $this->parts['user'] );
		}

		return null;
	}

	public function password() {
		if ( isset( $this->config['password'] ) ) {
			return rawurldecode( (string) $this->config['password'] );
		}

		if ( isset( $this->parts['pass'] ) ) {
			return rawurldecode( (string) $this->parts['pass'] );
		}

		return null;
	}

	public function bypass_hosts() {
		if ( empty( $this->config['bypass-hosts'] ) ) {
			return null;
		}

		if ( is_array( $this->config['bypass-hosts'] ) ) {
			return implode( ',', array_map( 'strval', $this->config['bypass-hosts'] ) );
		}

		return (string) $this->config['bypass-hosts'];
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
		// wp_parse_url() is not available before WordPress loads.
		// phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
		$parts = parse_url( $url );

		if ( ! is_array( $parts ) || empty( $parts['host'] ) ) {
			return false;
		}

		$host = strtolower( (string) $parts['host'] );

		foreach ( $this->bypass_hosts_list() as $pattern ) {
			$pattern = strtolower( $pattern );

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
	 * @param array<string, mixed> $config
	 * @return array<string, mixed>|null
	 */
	private static function resolve_parts( array $config ) {
		if ( ! empty( $config['url'] ) ) {
			return self::parse_url( (string) $config['url'] );
		}

		if ( ! empty( $config['host'] ) && ! empty( $config['port'] ) ) {
			return [
				'host' => (string) $config['host'],
				'port' => (string) $config['port'],
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
	 * @return array<string, mixed>|null
	 */
	private static function parse_url( $url ) {
		if ( false === strpos( $url, '://' ) ) {
			$url = 'http://' . $url;
		}

		// wp_parse_url() is not available before WordPress loads.
		// phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
		$parts = parse_url( $url );

		if ( ! is_array( $parts ) || empty( $parts['host'] ) || empty( $parts['port'] ) ) {
			return null;
		}

		return $parts;
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
