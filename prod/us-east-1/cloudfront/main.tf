# CloudFront function to redirect www.lodge104.net to lodge104.net
resource "aws_cloudfront_function" "www_redirect" {
  name    = "www-redirect-prod"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = <<-EOT
function handler(event) {
  var request = event.request;
  var host = request.headers.host.value;
  
  // Redirect www.lodge104.net to lodge104.net
  if (host === 'www.lodge104.net') {
    var location = 'https://lodge104.net' + request.uri;
    
    // Preserve query string if present
    if (request.querystring && Object.keys(request.querystring).length > 0) {
      var queryParts = [];
      for (var key in request.querystring) {
        queryParts.push(key + '=' + request.querystring[key].value);
      }
      location += '?' + queryParts.join('&');
    }
    
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: {
        'location': {
          value: location
        }
      }
    };
  }
  
  return request;
}
EOT
}

# Use local-exec to patch the CloudFront distribution with the function
# This waits for the module to be created first, then patches it
resource "null_resource" "patch_cloudfront_with_function" {
  depends_on = [
    aws_cloudfront_function.www_redirect,
  ]

  # Delay execution to ensure module outputs are available
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      sleep 5
      
      # Get distribution ID from CloudFront distributions created in this apply
      # by looking for the one with lodge104.net alias
      DIST_ID=$(aws cloudfront list-distributions \
        --query 'DistributionList.Items[?contains(Aliases.Items, `lodge104.net`)].Id' \
        --output text | head -1)
      
      if [ -z "$DIST_ID" ]; then
        echo "Warning: Could not find CloudFront distribution with lodge104.net alias"
        exit 0
      fi
      
      FUNCTION_ARN="${aws_cloudfront_function.www_redirect.arn}"
      
      # Get current distribution config
      aws cloudfront get-distribution-config \
        --id "$DIST_ID" \
        --query 'DistributionConfig' \
        --output json > /tmp/cf-config.json
      
      # Get the ETag for update
      ETAG=$(aws cloudfront get-distribution-config \
        --id "$DIST_ID" \
        --query 'ETag' \
        --output text)
      
      # Check if function association already exists
      if ! jq -e '.DefaultCacheBehavior.FunctionAssociations[] | select(.FunctionARN == "'$FUNCTION_ARN'")' /tmp/cf-config.json > /dev/null 2>&1; then
        # Add function association to default cache behavior
        jq '.DefaultCacheBehavior.FunctionAssociations |= if type == "null" or . == [] then [{"EventType": "viewer-request", "FunctionARN": "'$FUNCTION_ARN'"}] else . + [{"EventType": "viewer-request", "FunctionARN": "'$FUNCTION_ARN'"}] end' /tmp/cf-config.json > /tmp/cf-config-updated.json
        
        # Update the distribution
        aws cloudfront update-distribution \
          --id "$DIST_ID" \
          --distribution-config file:///tmp/cf-config-updated.json \
          --if-match "$ETAG"
        
        echo "Successfully added function association to CloudFront distribution"
      else
        echo "Function association already present"
      fi
      
      rm -f /tmp/cf-config.json /tmp/cf-config-updated.json
    EOT
  }
}

output "www_redirect_function_arn" {
  value = aws_cloudfront_function.www_redirect.arn
}
