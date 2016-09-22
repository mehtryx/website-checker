#!/bin/sh
# ---- website-checker.sh ----
# Pings a list of websites using cURL to see if they are up and
# there are no errors. 
################################################################################


# Formatting output to make it easier to function read 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# This is a path to a plain text list of URLs to check, one per line
# Make sure this uses proper unix newline characters or you will get 400 Bad Request errors
# when you try to curl the URLs
url_list=./urllist.txt

# Init empty variable for storing errors
failures=""

# We need to use an up to date CA cert bundle to verify that our SSL certs are working for https:// URLs
# You can obtain this file from: http://curl.haxx.se/docs/caextract.html
cabundle=./cacert.pem

# Loop through all of the URLs and cURL them
while read siteurl
do
	# curl flags
	# --location = Follow HTTP redirects
	# --include = Include the HTTP headers in the output
	# --silent = Don't show progress bar
	# --show-error = We hide the progress bar with --silent, but we still need errors, this fixes that
	# --max-time = How long to allow curl to run for each try (connection and download)
	# --cacert = See comment above
	# --user-agent = The user agent string to use
	# --write-out = Additional information for curl to write to its output
	echo "Checking $siteurl"
	result=$(curl --location --include --silent --show-error --max-time 12 --header "Cache control: no-cache" --cacert $cabundle --user-agent "Mozilla/5.0 (Windows NT 6.3; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0" --write-out "\nHTTP Code: %{http_code}\nTotal Time: %{time_total} sec\nDownload Size: %{size_download} B\nDownload Speed: %{speed_download} B/sec\nEffective URL: %{url_effective}" "$siteurl" 2>&1)
	
	# This outputs the siteurl with the http status information when the request completes.
	# sed is a stream editor, the pattern ^.*HTTP Code finds the status information we write out at the end of the request in the above curl request with --write-out
	# the -n tells sed not to output the pattern and the format of the -e command is /pattern/replace/  so we are replacing the preceeding content with blank to remove from output
	printf "${CYAN}"
	echo $result | sed -n -e 's/^.*HTTP Code/HTTP Code/p'
	printf "${NC}"
	# Search for our string, if it isn't found, the site is down
	# -q is grep's quite flag, makes it not write to standard out
	if ! echo "$result" | grep -q "HTTP Code: 200" ; then
		
		# Add the site url and the curl output to our failures variable
		failures="$failures"$'\n\n'"======================="$'\n\n'"$siteurl"$'\n'"----------------------"$'\n'"$result"
		
	fi
	
done < $url_list

# Check for failures, if we have them, send the email
if ! [ -z "$failures" ]; then
	
	echo "One or more of your websites might be down. See the results in failure.txt"
	echo $failures | iconv -c -t UTF-8 | tr -d '\r' > failures.txt
	
fi
