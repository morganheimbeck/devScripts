#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Parameters are required:"
    echo "1. (required) name to be appended to /spec/Syrinx. to create the directory in"
    echo "2. (required) port to run on (ie. 8130 or 9009)"
    echo "3. (required) unique name to append to DE for the inittab to keep the API service running"
    echo "4. (optional) branch to check out otherwise will just check out dev"
    echo "DONT FORGET to add the first parameter to ansible so that we can manage updates to this directory from there"
fi
##### TODO ####
# test the port is not already in use and not in the /etc/nginx/conf.d/repos.d/nodeservers.all configs
# test that /spec/Syrinx.$1 doesn't already exist
# test that there is not a name overlap with DE$3 in the /etc/inittab file


###############
# This is to script the set up of a new api instance on the server
# @param 1 Name of the directory to be appended to /spec/Syrinx.
# @param 2 port that the api will listen to
# @param 3 unique identifier that will be appended to DE in naming the inittab
# @param 4 branch to clone and initially check out otherwise will default to the dev branch
# Examples:
#  `createAPI ApiBranchZZ 8129 BZ TR-211`
#  `createAPI ApiBranchD 8130 BD`

dirName=$1
port=$2
inittabName=$3
dirPath=/spec/Syrinx.$dirName
branch=${4:-dev}

echo "cloning API to $dirPath"
mkdir -p $dirPath
git clone -b master git@github.com:Tradetech/syrinxapi.git $dirPath

cd $dirPath
git fetch --all
git co $branch
git submodule update --init

echo "npm install commands"
$dirPath/bin/npm install tti sharednodelib

echo "copying config from /spec/Syrinx.ApiBranchC"
cp /spec/Syrinx.ApiBranchC/etc/config $dirPath/etc/config

echo "replace port in config file"
sed -i 's/8128/'$2'/g' $dirPath/etc/config
sed -i 's/Branch C/'$1'/g' $dirPath/etc/config

echo "add log files"
touch /var/log/DataEngine/$2_access.log
touch /var/log/DataEngine/$2_preAccess.log
touch /var/log/DataEngine/$2_event.log
touch /var/log/DataEngine/$2_debug.log
touch /var/log/DataEngine/$2_error.log
touch /var/log/DataEngine/$2_browser.log

echo "update permissions on directories and files"
#for files
find $dirPath/. -type f -exec chmod 0665 {} \;
#for directories
find $dirPath/. -type d -exec chmod 0775 {} \;
#for bin
find $dirPath/bin -type f -exec chmod 0775 {} \;
echo "update owner of files to dev:dev"
chown -R root:root $dirPath/.

echo "append to the /etc/nginx/conf.d/repos.d/nodeservers.all the rerouting required for dev frontends to use the api"
echo "
    # Pass node calls to the port running data engine:
    # Port $2 - API Syrinx $1
    location /node$2 {
        rewrite /node$2(.*) /\$1 break;
        proxy_pass  http://dev.tradetech.net:$2;
    }
    location /node$2/ {
        rewrite /node$2(.*) \$1 break;
        proxy_pass  http://dev.tradetech.net:$2;
    }
" | tee -a /etc/nginx/conf.d/repos.d/nodeservers.all

/etc/init.d/nginx configtest
/etc/init.d/nginx restart

echo "add to /etc/inittab so that the api is constantly running"
echo "DE$3:4:respawn:$dirPath/bin/DataEngine >> /var/log/inittab/Syrinx.$1.DataEngine.log 2>&1" | tee -a /etc/inittab
/sbin/init q

echo "Put the name you came up with in to the ansible task options for updating dev apis, name should be: .$1";
echo "if there are any errors trying to start up this api, they will show up here in this tail of /var/log/inittab/Syrinx.$1.DataEngine.log"
echo "to exit this script, just type CTRL-C"
tail -f /var/log/inittab/Syrinx.$1.DataEngine.log
