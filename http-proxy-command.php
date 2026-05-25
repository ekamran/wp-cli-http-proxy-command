<?php

if ( ! class_exists( 'WP_CLI' ) ) {
	return;
}

require_once __DIR__ . '/src/ProxyConfig.php';
require_once __DIR__ . '/src/Bootstrap.php';
require_once __DIR__ . '/src/Command.php';

\WP_CLI\HttpProxy\Bootstrap::init();
