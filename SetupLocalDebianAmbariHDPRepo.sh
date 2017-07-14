#! /bin/bash
# Below script sets up an local debian repo using apache web service with Ambari and HDP binaries
# that are mirrored from HWX repo for a given Ambari and HDP stack version and HDP UTILS version

#Example of all input params
#AMBARI_REPO_URL=http://private-repo-1.hortonworks.com/ambari/ubuntu16/2.x/updates/2.5.0.4-1/ambari.list
#HDP_REPO_URL=http://private-repo-1.hortonworks.com/HDP/ubuntu16/2.x/updates/2.5.2.1-6/hdp.list

AMBARI_LIST_URL=$1
HDP_LIST_URL=$2

usage() 
{  
    echo "Usage: sudo bash setuplocaldebianrepo.sh AMBARI_REPO_URL HDP_REPO_URL";   
    exit 1;
}

#validate input arguments
if [ "$#" -ne 2 ]; then
    echo "Expected number of arguments is 8"
    usage
fi

if [ -z $AMBARI_LIST_URL ] ; then
    echo "AMBARI hwx repo url not provided"
    usage
fi

if [ -z $HDP_LIST_URL ] ; then
    echo "HDP hwx repo url not provided"
    usage
fi

FullHostName=private-repo-hwx.chinanorth.cloudapp.chinacloudapi.cn

echo ----------------------------------------------------------------------------------------------
echo ----------------------------------------------------------------------------------------------
echo Setting up local debian repo for Abmari and HDP on $FullHostName

regex="([a-z]*.list)$"
[[ $AMBARI_LIST_URL =~ $regex ]] && AMBARI_LIST_FILE=${BASH_REMATCH[1]}
[[ $HDP_LIST_URL =~ $regex ]] && HDP_LIST_FILE=${BASH_REMATCH[1]}

wget -q $AMBARI_LIST_URL -O $AMBARI_LIST_FILE
wget -q $HDP_LIST_URL -O $HDP_LIST_FILE

versionregex="([^\/]+$)"

ambarifilelines=`cat $AMBARI_LIST_FILE`
stringarray=($ambarifilelines)

AMBARI_REPO_URL=${stringarray[2]}
[[ $AMBARI_REPO_URL =~ $versionregex ]]
AMBARI_STACK_VERSION=${BASH_REMATCH[0]}
SYNC_AMBARI=
if [ -z "$AMBARI_STACK_VERSION" ]
then
   SYNC_AMBARI=#
fi

hdpfilelines=`cat $HDP_LIST_FILE`
stringarray=($hdpfilelines)

HDP_REPO_URL=${stringarray[2]}
HDP_UTILS_REPO_URL=${stringarray[6]}

[[ $HDP_REPO_URL =~ $versionregex ]]
HDP_STACK_VERSION=${BASH_REMATCH[0]}

regex="([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"
[[ ${stringarray[6]} =~ $regex ]]
HDP_UTILS_VERSION=${BASH_REMATCH[1]}

SYNC_HDP=
if [ -z "$HDP_STACK_VERSION" ]
then
   SYNC_HDP=#
fi

SYNC_HDP_UTIL=
if [ -z "$HDP_UTILS_VERSION" ]
then
   SYNC_HDP_UTIL=#
fi

LOCAL_REPO_NAME=hwx-$AMBARI_STACK_VERSION-$HDP_STACK_VERSION

setUpLocalHDPDebianRepo()
{   
    echo "AMBARI_REPO_URL is $AMBARI_REPO_URL"
    echo "HDP_REPO_URL is $HDP_REPO_URL"
    echo "HDP_UTILS_REPO_URL is $HDP_UTILS_REPO_URL"
    echo "AMBARI_STACK_VERSION is $AMBARI_STACK_VERSION"
    echo "HDP_STACK_VERSION is $HDP_STACK_VERSION"    
    echo "HDP_UTILS_VERSION is $HDP_UTILS_VERSION"    
    
    cat >/etc/apt/$LOCAL_REPO_NAME.list <<EOL
set nthreads     20
set base_path    /tmp/$LOCAL_REPO_NAME
#HDP 2.6
$SYNC_AMBARI deb $AMBARI_REPO_URL Ambari main
$SYNC_HDP deb $HDP_REPO_URL HDP main
$SYNC_HDP_UTIL deb $HDP_UTILS_REPO_URL HDP-UTILS main
EOL
   
    mkdir -p /tmp/$LOCAL_REPO_NAME
    downloadPackagesLocally
}

downloadPackagesLocally()
{
    apt-mirror /etc/apt/$LOCAL_REPO_NAME.list  

    SOURCE_FOLDER=/tmp/$LOCAL_REPO_NAME/mirror
    cd $SOURCE_FOLDER
  
    ambariPath=$(find . -type d -name "ambari" -print 2>/dev/null -quit)
    hdpPath=$(find . -type d -name "HDP" -print 2>/dev/null -quit)
    hdpUtilsPath=$(find . -type d -name "HDP-UTILS-$HDP_UTILS_VERSION" -print 2>/dev/null -quit)

    targetambariPath=$(echo $AMBARI_REPO_URL | awk -F"/ambari" '{print $2}')
    targethdpPath=$(echo $HDP_REPO_URL | awk -F"/HDP" '{print $2}')
    targethdpUtilPath=$(echo $HDP_UTILS_REPO_URL | awk -F"/HDP-UTILS-$HDP_UTILS_VERSION" '{print $2}')    
    
    # Get path before last slash
    pathregex=(.+)\/    
    
    [[ $targetambariPath =~ $pathregex ]]
    AMBARI_FOLDER=${BASH_REMATCH[1]}    

    [[ $targethdpPath =~ $pathregex ]]
    HDP_FOLDER=${BASH_REMATCH[1]}   
    
    TARGET_FOLDER=/var/hwx/repo
    
    echo Create folder $TARGET_FOLDER/ambari/$AMBARI_FOLDER
    echo Create folder $TARGET_FOLDER/HDP/$HDP_FOLDER
    echo Create folder $TARGET_FOLDER/HDP-UTILS-$HDP_UTILS_VERSION/repos
    mkdir -p $TARGET_FOLDER/ambari/$AMBARI_FOLDER
    mkdir -p $TARGET_FOLDER/HDP/$HDP_FOLDER
    mkdir -p $TARGET_FOLDER/HDP-UTILS-$HDP_UTILS_VERSION/repos
    
    echo Move folder $SOURCE_FOLDER/$ambariPath$targetambariPath to folder $TARGET_FOLDER/ambari/$AMBARI_FOLDER
    echo Move folder $SOURCE_FOLDER/$hdpPath$targethdpPath to folder $TARGET_FOLDER/HDP/$HDP_FOLDER   
    echo Move folder $SOURCE_FOLDER/$hdpUtilsPath$targethdpUtilPath to folder $TARGET_FOLDER/HDP-UTILS-$HDP_UTILS_VERSION$targethdpUtilPath    
    mv -f $SOURCE_FOLDER/$ambariPath$targetambariPath $TARGET_FOLDER/ambari/$AMBARI_FOLDER
    mv -f $SOURCE_FOLDER/$hdpPath$targethdpPath $TARGET_FOLDER/HDP/$HDP_FOLDER   
    mv -f $SOURCE_FOLDER/$hdpUtilsPath$targethdpUtilPath $TARGET_FOLDER/HDP-UTILS-$HDP_UTILS_VERSION/repos

    #ln -s $TARGET_FOLDER/ambari /var/www/html/ambari
    #ln -s $TARGET_FOLDER/HDP /var/www/html/HDP
    #ln -s $TARGET_FOLDER/HDP-UTILS-$HDP_UTILS_VERSION /var/www/html/HDP-UTILS-$HDP_UTILS_VERSION
}

startAndValidateLocalHDPDebianRepo()
{
    #echo "Starting local debian repo"
    #systemctl daemon-reload
    #systemctl stop apache2  
    #systemctl start apache2   
    #echo "End of starting local debian repo" 
   
    # these directory structure can change post mirroring, depending on what HWX repo is used (private-repo-1.hortonworks.com or AWS repo)
    # so basically extract the path from the given input urls
    ambariPath=$(echo $AMBARI_REPO_URL | awk -F"/ambari" '{print $2}')
    hdpPath=$(echo $HDP_REPO_URL | awk -F"/HDP" '{print $2}')
    hdpUtilPath=$(echo $HDP_UTILS_REPO_URL | awk -F"/HDP-UTILS-$HDP_UTILS_VERSION" '{print $2}')
   
    echo "Printing ambariPath $ambariPath"
    echo "Printing hdpPath $hdpPath"
    echo "Printing hdpUtilPath $hdpUtilPath"
   
    ambariUrl=http://$FullHostName/ambari$ambariPath
    hdpRepoUrl=http://$FullHostName/HDP$hdpPath
    hdpUtilsUrl=http://$FullHostName/HDP-UTILS-$HDP_UTILS_VERSION$hdpUtilPath
   
    validateRepo $ambariUrl
   
    echo "Creating ambari.list file"
    cat >/var/www/html/ambari/$ambariPath/ambari.list <<EOL
#VERSION_NUMBER=$AMBARI_STACK_VERSION
deb $ambariUrl Ambari main
EOL
    validateRepo $ambariUrl/ambari.list
    
    validateRepo $hdpRepoUrl
    validateRepo $hdpUtilsUrl
    
    echo "Creating hdp.list file"
    cat >/var/www/html/HDP/$hdpPath/hdp.list <<EOL
#VERSION_NUMBER=$HDP_STACK_VERSION
deb $hdpRepoUrl HDP main
deb $hdpUtilsUrl HDP-UTILS main 
EOL 
    validateRepo $hdpRepoUrl/hdp.list
}

validateRepo()
{
    echo "Validating $1 is accessible"
    wget -q $1
    if [ $? -ne 0 ]; then   
        echo "$1 is NOT accessible"
        exit 132
    else
        echo "Local Repo $1 successfully set up ....."
    fi
}

cleanUpTmpDirectories()
{
    echo Cleaning up /tmp/$LOCAL_REPO_NAME
    rm -rf /tmp/$LOCAL_REPO_NAME
}

setUpLocalHDPDebianRepo
startAndValidateLocalHDPDebianRepo
#cleanUpTmpDirectories
