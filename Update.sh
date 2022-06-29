#!/bin/bash

######Function Start######
#Clean leftovers
function cleanFile(){

}

#Error code system
function exitScript(){
    echo '[Critical] exit code detected!'
    echo "Exit code: $@ "
    echo '[Critical]You may follow the instructions to debug'
    if [ $@ = 1 ]; then
        sign='Unknown error'
    elif [ $@ = 2 ]; then
        sign='Can not create directory'
    elif [ $@ =3 ]; then
        code3='Non-64-bit system detected'
    else
        echo "Undefined error code"
    fi
    echo "${sign}"
    exit $@
}

#Create folders for the first time
function createFolder(){
    if [ ! -d ${serverPath} ]; then
        echo '[Info] Path to server is empty, creating new directory'
        mkdir ${serverPath}
        mkdir ${serverPath}/plugins
        if [ $? = 1 ]; then
        echo '[Info] mkdir returned error code 1, retrying with sudo'
            if [ $@ =~ 'unattended' ]; then
                echo '[Warn] unattended flag detected, terminating...'
                exitScript 2
            else
                if [ `whoami` = root ]; then
                    exitScript 2
                else
                    sudo mkdir ${serverPath}
                    sudo mkdir ${serverPath}/plugins
                fi
            fi
        fi
        echo '[Info] Directory created.'
    else
        echo '[Info] Directory already exists'
    fi
    if [ ! -d ${serverPath}/plugins ]; then
        echo '[Info] Plugins folder not found, trying to create'
        mkdir ${serverPath}/plugins
        if [ $? = 1 ]; then
            echo '[Info] mkdir failed, trying with root'
            if [[ $@ =~ 'unattended' ]]; then
                sudo mkdir ${serverPath}/plugins
            else
                echo '[Warn] unattended flag detected'
                exitScript 2
            fi
            if [ $? = 1 ]; then
                echo '[Warn] Plugins folder cannot be created'
                exitScript 2
            fi
        fi
    else
        echo '[Info] Directory already exists'
    fi
}

#Build origin server
function buildMojang(){
    if [ ${version} = 1.19 ]; then
        url=https://launcher.mojang.com/v1/objects/e00c4052dac1d59a1188b2aa9d5a87113aaf1122/server.jar
    fi
    wget https://launcher.mojang.com/v1/objects/e00c4052dac1d59a1188b2aa9d5a87113aaf1122/server.jar

}

#Build Spigot
function buildSpigot(){
    url="https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
    checkFile=BuildTools.jar
    echo "Downloading BuildTools for Spigot..."
    wget ${url} >/dev/null
    java -jar $checkFile nogui --rev ${version} >/dev/null
    rm -rf ${checkConfig}
    mv spigot-*.jar Spigot-latest.jar
    update Spigot-latest.jar
}

#testPackageManager
function detectPackageManager(){
    echo "Detecting package manager..."
    if [[ $(sudo apt install ) ]]; then
        echo 'Detected apt'
        return apt
    elif [[ $(sudo pacman -h ) ]]; then
        echo 'Detected pacman'
        return pacman
    elif [[ $(sudo dnf install ) ]]; then
        echo 'Detected dnf'
        return dnf
    else
        return unknown
    fi
}
#checkConfig
checkConfig(){
    if [ ! ${version} ]; then
        echo '$version not set, please enter your desied version:'
        read version
    fi
    if [ ! ${serverPath} ]; then
        echo "Warning! serverPath not set, please enter complete path to your server:"
        read serverPath
    fi
    if [ ! $build ]; then
        export build=500
    fi
}
#removeJarFile
function clean(){
    echo "Cleaning..."
    rm -rf *.jar
    rm -rf *.check
    rm -rf *.1
    rm -rf *.2
}
#moveFile
function update(){
    echo "Updating jar file..."
    if [[ $@ = "Paper-latest.jar" ]]; then
        mv $@ ${serverPath}
    elif [[ $@ = "Spigot-latest.jar" ]]; then
        mv $@ ${serverPath}/$@
    else
        mv $@ ${serverPath}/plugins/
    fi
}
#versionCompare
function versionCompare(){
    echo "Making sure you're up to date..."
    if [ $isPlugin = true ]; then
        checkPath="${serverPath}/plugins"
    else
        checkPath="${serverPath}"
    fi
    diff -q "${checkPath}/${checkFile}" "${checkFile}" >/dev/null 2>/dev/null
    return $?
}
#integrityProtect
function integrityProtect(){
    echo "Checking file integrity..."
    if [[ $@ =~ "unsafe" ]]; then
        echo "Warning! Default protection disabled. USE AT YOUR OWN RISK!"
        return 0
    else
        echo "Verifing ${checkFile}"
        if [ ${isPlugin} = false ]; then
            checkFile=Paper-latest.jar
            wget $url >/dev/null
            mv paper-*.jar Paper-latest.jar.check
            diff -q Paper-latest.jar.check Paper-latest.jar >/dev/null 2>/dev/null
            return $?
        else
            mv $checkFile "${checkFile}.check"
            wget $url >/dev/null
            diff -q $checkFile "${checkFile}.check" >/dev/null 2>/dev/null
            return $?
        fi
    fi
    if [ $? = 1 ]; then
        echo "Checking job done, repairing ${checkFile}."
        redownload
    else
        echo "Ckecking job done, ${ckeckFile} verified."
        clean
    fi
}
function redownload(){
    clean
    if [ ${isPlugin} = false ]; then
        checkFile=Paper-latest.jar
        wget $url >/dev/null 2>/dev/null
        mv paper-*.jar Paper-latest.jar
        integrityProtect
    else
        wget $url >/dev/null 2>/dev/null
        integrityProtect
    fi
}
#pluginUpdate
function pluginUpdate(){
    echo "Updating ${checkFile}"
    if [ $@ = Floodgate ]; then
        pluginName=Floodgate
        url="https://ci.opencollab.dev/job/GeyserMC/job/Floodgate/job/master/lastSuccessfulBuild/artifact/spigot/target/floodgate-spigot.jar"
    elif [ $@ = Geyser ]; then
        pluginName=Geyser
        url="https://ci.opencollab.dev/job/GeyserMC/job/Geyser/job/master/lastSuccessfulBuild/artifact/bootstrap/spigot/target/Geyser-Spigot.jar"
    elif [ $@ = SAC ]; then
        pluginName=SAC
        url="https://www.spigotmc.org/resources/soaromasac-lightweight-cheat-detection-system.87702/download?version=455200"
    elif [ $@ = MTVehicles ]; then
        pluginName="$@"
        url="https://www.spigotmc.org/resources/mtvehicles-vehicle-plugin-free-downloadable.80910/download?version=452759"
    else
        echo "Sorry, but we don't have your plugin's download url. Please wait for support~"
    fi
    echo "Downloading ${pluginName}"
    wget $url >/dev/null
    isPlugin=true
}
#systemUpdate
function systemUpdate(){
    if [[ $@ =~ 'nosudo' ]]; then
        if [ $? = apt ]; then
            echo "Updating using apt..."
            apt -y full-upgrade
        elif [ $? = dnf ]; then
            echo "Updating using dnf..."
            dnf -y update
        elif [ $? = pacman ]; then
            echo "Updating using pacman..."
            pacman --noconfirm -Syyu
        else
            unset packageManager
            echo "Package Manager not found! Enter command to update or type 'skip' to skip"
            read packageManager
            if [ ! ${packageManager} = skip ]; then
                ${packageManager}
            else
                echo "Skipping"
            fi
        fi
    else
        if [ $? = apt ]; then
            echo "Updating using apt..."
            sudo apt -y full-upgrade
        elif [ $? = dnf ]; then
            echo "Updating using dnf..."
            sudo dnf -y update
        elif [ $? = pacman ]; then
            echo "Updating using pacman..."
            sudo pacman --noconfirm -Syyu
        else
            unset packageManager
            if [[ $@ =~ "unattended" ]];then
                echo "unattended flag detected, skipping system update due to unknown package manager..."
            else
                echo "Package Manager not found! Enter command to update or type 'skip' to skip"
                read packageManager
                if [ ! ${packageManager} = skip ]; then
                    if [[ ${packageManager} =~ 'sudo' ]]; then
                        ${packageManager}
                    else
                        ${packageManager}
                    fi
                else
                    echo "Skipping"
                fi
            fi
        fi
    fi
}

#buildPaper
function buildPaper(){
    while [ ! -f paper-*.jar ]; do
        export build=`expr ${build} - 1`
        echo "Testing build ${build}"
        url="https://papermc.io/api/v2/projects/paper/versions/${version}/builds/${build}/downloads/paper-${version}-${build}.jar"
        wget $url >/dev/null
    done
    echo "Downloaded build ${build}."
    if [ -f paper-*.jar ]; then
        mv paper-*.jar Paper-latest.jar
    fi
    export isPlugin=false
    export checkFile=Paper-latest.jar
    integrityProtect
    versionCompare
    if [ $? = 0 ]; then
        echo "You're up to date."
        clean
    else
        echo "Updating Paper..."
        update Paper-latest.jar
    fi
    clean
}

#32-bit Warning
function checkBit(){
    getconf LONG_BIT
    return $?
    if [ $? = 64 ]; then
        echo "Running on 64-bit system."
    elif [ $? = 32 ]; then
        if [[ $@ =~ "unsafe" ]]; then
            echo "Warning at `date`, running on 32-bit system may encounter unexpected problems."
        else
            echo "32-bit system detected, script is stopping..."
            exitScript 3
        fi
    fi
}

function main(){
    echo "Hello! `whoami` at `date`"
    checkBit
    echo "Reading settings"
    clean
    checkConfig
    if [[ $@ =~ 'newserver' ]]; then
        createFolder $@
    fi

    ######Paper Update Start######
    echo "Starting auto update at `date`"
    cd ${serverPath}/Update/
    if [[ $@ =~ "paper" ]]; then
        buildPaper
    fi
    ######Paper Update End######

    ######Spigot Update Start######
    if [[ $@ =~ "spigot" ]]; then
        buildSpigot
        update
    fi
    ######Plugin Update Start######
    if [[ $@ =~ "mtvehicles" ]]; then
        isPlugin=true
        pluginUpdate MTVehicles
        checkFile="MTVehicles.jar"
        integrityProtect
        versionCompare
        update MTVehicles.jar
        clean
    fi

    if [[ $@ =~ "geyser" ]]; then
        export isPlugin=true
        pluginUpdate Geyser
        export checkFile='Geyser-Spigot.jar'
        integrityProtect
        versionCompare
        update *.jar
        clean
    fi

    if [[ $@ =~ "floodgate" ]]; then
        export isPlugin=true
        export checkFile='floodgate-spigot.jar'
        pluginUpdate Floodgate
        integrityProtect
        versionCompare
        update *.jar
        clean
    fi

    if [[ $@ =~ "sac" ]]; then
        echo "Warning! Beta support for SoaromaSAC"
        isPlugin=true
        unset checkFile
        update *.jar
    fi
    ######Plugin Update End######
    if [ `whoami` = 'root' ]; then
        systemUpdate nosudo $@
    else
        systemUpdate $@
    fi
    rm -rf ${serverPath}/plugins/BuildTools.jar
    clean
    echo "Job finished at `date`, have a nice day~"
    exitScript 0
}

######Function End######
if [[ $@ =~ "unattended" ]]; then
    main $@ 1>> updater.log 2>>debug.log
else
    main $@
fi
