<?php
/**
 * The base configuration for WordPress
 *
 * The wp-config.php creation script uses this file during the installation.
 * You don't have to use the web site, you can copy this file to "wp-config.php"
 * and fill in the values.
 *
 * This file contains the following configurations:
 *
 * * Database settings
 * * Secret keys
 * * Database table prefix
 * * ABSPATH
 *
 * @link https://wordpress.org/documentation/article/editing-wp-config-php/
 *
 * @package WordPress
 */

// ** Database settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define( 'DB_NAME', $_SERVER['DB_NAME'] );

/** MySQL database username */
define( 'DB_USER', $_SERVER['DB_USER'] );

/** MySQL database password */
define( 'DB_PASSWORD', $_SERVER['DB_PASSWORD'] );

/** MySQL hostname */
define( 'DB_HOST', $_SERVER['DB_HOST'] );

/** Database Charset to use in creating database tables. */
define( 'DB_CHARSET', 'utf8' );

/** The Database Collate type. Don't change this if in doubt. */
define( 'DB_COLLATE', '' );

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         '6kDyB 6FJg;8$Dy]c<tJ2G.[|;.e3STW3|EgDBa?;)s)eYW_=VaE@*`*h&{!NH*#');
define('SECURE_AUTH_KEY',  '{r3ks/3di$+=+AyHdW|VeD( 1H1u^|w-7rcOpT_H}a~aFBOP$)WO&^WonnQlDbp@');
define('LOGGED_IN_KEY',    '|RCfZ2QM]`KAgqVNUkbZ=2g-HF!0C2Xa%+JrsmV~,ePJcR|F7oWVZCdqs7(BOIo^');
define('NONCE_KEY',        'r*rL-CJu9p(/&n+:b%.Z5HzP&Mc*,}W6j+/?/}uqh( s82_qTw|xol>Fi)3Th}I%');
define('AUTH_SALT',        '5QSbmr0wnn{xXKCErfzH|<;_pp~;tTY~rbhVQKB|R7%(~W,r]#k3.jD^|Px@?awx');
define('SECURE_AUTH_SALT', 'j9xiPskJIY9]2/%n0dfGj:`,>v&x-T;Ii@lz]7P-{oWogxT.3w:[3|lX65Bxz5r7');
define('LOGGED_IN_SALT',   'e73$%;CuUMumW4.$NEfaFU(3kOn-Aw-4p=3f;T?2]%o[n<PGLrUZ=O`Az1OekHU>');
define('NONCE_SALT',       'PM%AiQ59z52o>U).]d7k2-y+~tZM58$Zecv;5>-O8&3-1 3e?bnj(07o=5Xm!xi)');

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each
 * a unique prefix. Only numbers, letters, and underscores please!
 */
$table_prefix = 'wp_';

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 *
 * For information on other constants that can be used for debugging,
 * visit the documentation.
 *
 * @link https://wordpress.org/documentation/article/debugging-in-wordpress/
 */
define( 'WP_DEBUG', false );

// Force SSL if behind a load balancer (Elastic Beanstalk)
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

$protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https://' : 'http://';

// Set Home and Site URL dynamically if needed, or use the PRIMARY_DOMAIN env var
if (isset($_SERVER['PRIMARY_DOMAIN'])) {
    define('WP_HOME', $protocol . $_SERVER['PRIMARY_DOMAIN']);
    define('WP_SITEURL', $protocol . $_SERVER['PRIMARY_DOMAIN']);
}

/* Add any custom values between this line and the "stop editing" line. */

/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';
