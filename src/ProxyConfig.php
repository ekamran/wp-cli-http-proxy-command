<?php

namespace WP_CLI\HttpProxy;

use InvalidArgumentException;
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
		return self::load_from_runner()['config'];
	}

	/**
	 * Reads the http-proxy configuration and explains any part of it that cannot be used.
	 *
	 * @return array{config: self|null, warnings: string[]}
	 */
	public static function load_from_runner() {
		$none   = [
			'config'   => null,
			'warnings' => [],
		];
		$runner = WP_CLI::get_runner();

		if ( ! $runner || empty( $runner->extra_config['http-proxy'] ) || ! is_array( $runner->extra_config['http-proxy'] ) ) {
			return $none;
		}

		$config = $runner->extra_config['http-proxy'];

		if ( isset( $config['enabled'] ) && ! self::to_bool( $config['enabled'] ) ) {
			return $none;
		}

		try {
			$parts = self::resolve_parts( $config );
		} catch ( InvalidArgumentException $exception ) {
			return [
				'config'   => null,
				'warnings' => [ 'HTTP proxy disabled: ' . $exception->getMessage() ],
			];
		}

		if ( ! $parts ) {
			return $none;
		}

		$proxy    = new self( $config, $parts );
		$warnings = [];

		if ( ( null === $proxy->username() ) !== ( null === $proxy->password() ) ) {
			$warnings[] = 'HTTP proxy authentication not used: set both a username and a password.';
		}

		return [
			'config'   => $proxy,
			'warnings' => $warnings,
		];
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
	 * Returns null when `env: true` finds no proxy environment variable.
	 *
	 * @param array<string, mixed> $config
	 * @return array{host: string, port: int|string, user?: string, pass?: string}|null
	 * @throws InvalidArgumentException When the configured proxy cannot be used.
	 */
	private static function resolve_parts( array $config ) {
		if ( isset( $config['url'] ) ) {
			$url = self::config_string( $config['url'] );

			if ( null !== $url && '' !== $url ) {
				return self::parse_proxy_url( $url, 'the http-proxy url' );
			}
		}

		if ( isset( $config['host'] ) || isset( $config['port'] ) ) {
			$host = isset( $config['host'] ) ? self::config_string( $config['host'] ) : null;

			if ( null === $host || '' === $host || ! isset( $config['port'] ) ) {
				throw new InvalidArgumentException( 'set both host and port in the http-proxy configuration.' );
			}

			$port = self::normalize_port( $config['port'] );

			if ( null === $port ) {
				throw new InvalidArgumentException( 'the http-proxy port is not valid. Use a port from 1 to 65535.' );
			}

			// The host setting accepts a bare IPv6 address, which needs brackets next to a port.
			if ( false !== filter_var( $host, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6 ) ) {
				$host = '[' . $host . ']';
			}

			return self::parse_proxy_url( $host . ':' . $port, 'the http-proxy host' );
		}

		if ( ! empty( $config['env'] ) && self::to_bool( $config['env'] ) ) {
			$env = self::proxy_env();

			if ( ! $env ) {
				return null;
			}

			return self::parse_proxy_url( $env['value'], 'the ' . $env['name'] . ' environment variable' );
		}

		throw new InvalidArgumentException( 'the http-proxy configuration has no url, host and port, or env setting.' );
	}

	/**
	 * @param string $url    Proxy URL. A URL without a scheme is treated as http://.
	 * @param string $source Where the URL came from, for warnings.
	 * @return array{host: string, port: int|string, user?: string, pass?: string}
	 * @throws InvalidArgumentException When the URL is not a usable HTTP proxy address.
	 */
	private static function parse_proxy_url( $url, $source ) {
		if ( false === strpos( $url, '://' ) ) {
			$url = 'http://' . $url;
		}

		// wp_parse_url() is not available before WordPress loads.
		// phpcs:ignore WordPress.WP.AlternativeFunctions.parse_url_parse_url
		$parts = parse_url( $url );

		if ( ! is_array( $parts ) || empty( $parts['host'] ) ) {
			throw new InvalidArgumentException( $source . ' is not a valid proxy address.' );
		}

		$scheme = isset( $parts['scheme'] ) ? strtolower( $parts['scheme'] ) : 'http';

		if ( 'http' !== $scheme ) {
			throw new InvalidArgumentException( $source . ' uses ' . $scheme . '://, but only HTTP proxies (http://) are supported.' );
		}

		$host = $parts['host'];

		if ( false !== strpos( $host, ':' ) && '[' !== $host[0] ) {
			if ( false !== filter_var( $host, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6 ) ) {
				throw new InvalidArgumentException( $source . ' has an IPv6 address without brackets. Use the form http://[2001:db8::1]:8080.' );
			}

			throw new InvalidArgumentException( $source . ' is not a valid proxy address.' );
		}

		if ( ! isset( $parts['port'] ) ) {
			throw new InvalidArgumentException( $source . ' has no port. Add one, such as http://proxy.example.com:8080.' );
		}

		$port = self::normalize_port( $parts['port'] );

		if ( null === $port ) {
			throw new InvalidArgumentException( $source . ' has an invalid port. Use a port from 1 to 65535.' );
		}

		$normalized = [
			'host' => $host,
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

	/**
	 * @return array{name: string, value: string}|false
	 */
	private static function proxy_env() {
		foreach ( [ 'HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy' ] as $name ) {
			$value = getenv( $name );

			if ( false !== $value && '' !== $value ) {
				return [
					'name'  => $name,
					'value' => $value,
				];
			}
		}

		return false;
	}

	private static function to_bool( $value ) {
		return filter_var( $value, FILTER_VALIDATE_BOOLEAN );
	}
}
