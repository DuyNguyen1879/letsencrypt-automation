#!/bin/sh

# Make sure only root can run this script
if [[ $EUID -ne 0 ]]; then
   echo $(date -u) "This script must be run as root" >> /var/log/letsencrypt-automation/ssl-renew.log
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

# Copy the ssl validation file to nginx directory
echo $(date -u) "Copying the ssl validation file to nginx directory..." >> /var/log/letsencrypt-automation/ssl-renew.log
cp /root/nginx-configurations/$configFolderGit/default-renew-ssl /etc/nginx/sites-available/default

# Restart the nginx
echo $(date -u) "Restarting nginx..." >> /var/log/letsencrypt-automation/ssl-renew.log
service nginx restart

# Renew the certificates
echo $(date -u) "Executing the renew..." >> /var/log/letsencrypt-automation/ssl-renew.log
letsencrypt renew --agree-tos -m "filipe@hariken.co" >> /var/log/letsencrypt-automation/ssl-renew.log

# Copy the ssl configurated file to nginx directory
echo $(date -u) "Copying the ssl configurated file to nginx directory..." >> /var/log/letsencrypt-automation/ssl-renew.log
cp /root/nginx-configurations/$configFolderGit/default /etc/nginx/sites-available/default

# Restart the nginx
echo $(date -u) "Restarting nginx..." >> /var/log/letsencrypt-automation/ssl-renew.log
service nginx restart
