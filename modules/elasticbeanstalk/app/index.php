<?php
/**
 * WordPress Bootstrap for Elastic Beanstalk
 */

// WordPress is installed on EFS
$wordpress_dir = '/var/www/efs/wordpress';
$wp_config = $wordpress_dir . '/wp-config.php';

if (file_exists($wp_config)) {
    // WordPress is installed, load it
    define('WP_USE_THEMES', true);
    require_once($wp_config);
    require_once($wordpress_dir . '/wp-blog-header.php');
} else {
    // WordPress not yet installed - show setup page
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <title>Lodge104 - WordPress Setup</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
            h1 { color: #333; }
            .status { color: #2196F3; font-weight: bold; }
            .info { background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0; }
            .details { background: #e7f3ff; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
            code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🏕️ Lodge104 - WordPress Installation</h1>
            <p class="status">WordPress is being set up on EFS...</p>
            
            <div class="info">
                <h3>⚠️ Setup Required</h3>
                <p>WordPress files are being downloaded to EFS. You need to create <code>wp-config.php</code> with your database settings.</p>
            </div>
            
            <div class="details">
                <h3>Environment Details:</h3>
                <ul>
                    <li><strong>Platform:</strong> PHP <?php echo phpversion(); ?> on Amazon Linux 2023</li>
                    <li><strong>Web Server:</strong> Nginx</li>
                    <li><strong>WordPress Location:</strong> <?php echo $wordpress_dir; ?></li>
                    <li><strong>Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?></li>
                </ul>
            </div>
            
            <p><a href="/info.php">View PHP Info</a></p>
        </div>
    </body>
    </html>
    <?php
}


