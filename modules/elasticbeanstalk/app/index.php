<?php
/**
 * WordPress Elastic Beanstalk Bootstrap
 * 
 * This file serves as a placeholder until WordPress is properly installed.
 * The actual WordPress installation is handled by the .ebextensions scripts.
 */

// Check if WordPress is installed and accessible
$wordpress_dir = '/mnt/efs/wordpress';
$wp_config = $wordpress_dir . '/wp-config.php';

if (file_exists($wp_config)) {
    // WordPress is installed, load it
    require_once($wp_config);
    require_once($wordpress_dir . '/wp-blog-header.php');
} else {
    // WordPress not yet installed
    header('HTTP/1.1 503 Service Unavailable');
    header('Retry-After: 300');
    echo "<!DOCTYPE html>\n";
    echo "<html>\n";
    echo "<head><title>WordPress Installation in Progress</title></head>\n";
    echo "<body>\n";
    echo "<h1>WordPress Installation in Progress</h1>\n";
    echo "<p>The WordPress installation is being set up. Please wait a few minutes and refresh this page.</p>\n";
    echo "</body>\n";
    echo "</html>\n";
}
