#!/bin/sh

# Make sure only root can run this script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
configFolderGit=""

while getopts "f:" opt; do
    case "$opt" in
    f)  configFolderGit=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

if [ "$configFolderGit" == "" ]; then
        echo "Argument -f missing."
        exit 1
fi

# Check nginx
if ! dpkg -l nginx | grep 'ii.*nginx' > /dev/null 2>&1; then
	echo "Nginx not installed, initializing installation..."
	apt-get install nginx -y
fi

# Check git
if ! dpkg -l git | grep 'ii.*git' > /dev/null 2>&1; then
	echo "Git not installed, initializing installation..."
	apt-get install git -y
fi

# Check Lets Encrypt
if ! dpkg -l letsencrypt | grep 'ii.*letsencrypt' > /dev/null 2>&1; then	
	echo "Lets encrypt not installed, initializing installation..."
	apt-get install letsencrypt -y
fi

# Copy the ssl validation file to nginx directory
echo "Copying the ssl validation file to nginx directory..."
cp ~/nginx-configurations/$configFolderGit/default-validate-ssl /etc/nginx/sites-available/default

# Verify if exist the file nginx.conf if yes then copy this one time the file
if [ -f ~/nginx-configurations/$configFolderGit/nginx.conf ]; then
	echo "Copying the nginx.conf to the root folder of nginx..."
	cp ~/nginx-configurations/$configFolderGit/nginx.conf /etc/nginx/nginx.conf
fi

# Verify if exist the letsencrypt-automation log folder to hold the logs of ssl-renew
if [ -d /var/log/letsencrypt-automation ]; then
        echo "Log folder already created, making the ssl-renew.log file"
		touch /var/log/letsencrypt-automation/ssl-renew.log

else
        echo "Log folder don't exist, creating it now with the ssl-renew.log file"
		mkdir /var/log/letsencrypt-automation && touch /var/log/letsencrypt-automation/ssl-renew.log
fi

# Restart the nginx
echo "Restarting nginx..."
service nginx restart

# Read the domain file building the parameters for letsencrypt
domainParameters=""
exec 3<~/nginx-configurations/$configFolderGit/domain
while read line <&3
do
	[ "$line" == "" ] && continue
	domainParameters="$domainParameters -d $line"
done
exec 3<&-

# Create the certificate
echo "Generating certificate for domains $domainParameters ."
letsencrypt certonly -a webroot --webroot-path=/usr/share/nginx/html $domainParameters --agree-tos -m myemail@company.com

if [ ! -d "/etc/letsencrypt/live/$domain/" ]; then
	# Control will enter here if domain doesn't exist.
	echo "SSL not generated"
else
	# Copy the ssl configurated file to nginx directory
	echo "Copying the ssl configurated file to nginx directory..."
	cp ~/nginx-configurations/$configFolderGit/default /etc/nginx/sites-available/default

	# Restart the nginx
	echo "Restarting nginx..."
	service nginx restart

	# Remove previous lines from the crontab
	lineRemove="/root/nginx-configurations/ssl-renew.sh -f $configFolderGit"
	crontab -u root -l | grep -v "$lineRemove"  | crontab -u root -
	# Create on crontab the command to execute the renew scripts
	line="0 1 * * * bash /root/nginx-configurations/ssl-renew.sh -f $configFolderGit"
	(crontab -u root -l; echo "$line" ) | crontab -u root -
fi
# End of file


# ADD THE PASSWORD
# sudo apt-get install apache2-utils -y
# htpasswd -c /etc/nginx/.htpasswd hariken

