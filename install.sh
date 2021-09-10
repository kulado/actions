#!/bin/bash
#
# STP
#
# ReleaseDate: 20210716
# Created by Cartor on 2019-06-13.
# Copyright 2019 Splashtop Inc. All rights reserved.
#

#----------------common function start-----------------------#


function exceCMD() {
    cmd="${1}"
    echo "${cmd}" | sh
    #echo "${cmd}"
    #echo "${cmd}" >> ~/uninstaller.log
}

function tarCopyFile() {
    _DIR=$(pwd)

    SOURCE="$(dirname "$1")"
    DESTINATION="$2"
    FILE="$(basename "$1")"

    echo "Copying file to ${DESTINATION}"
    cd "${SOURCE}"
    sudo tar cf - "${FILE}" | (cd "${DESTINATION}"; sudo tar xfp -)
    cd "${_DIR}"
}

function vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

function plist_WriteOption() {
    FILENAME="${1}"
    KEY="${2}"
    VALUE="${3}"
    TYPE="${4}"
    
    sed "s/REPALCE_STRING/${2}/g" <<- EOF >> "${FILENAME}"
            <key>REPALCE_STRING</key>
EOF

    if [ "${TYPE}" == "bool" ]; then
        sed "s/REPALCE_STRING/${3}/g" <<- EOF >> "${FILENAME}"
             <REPALCE_STRING/>
EOF
    elif [ "${TYPE}" == "int" ]; then
        sed "s/REPALCE_STRING/${3}/g" <<- EOF >> "${FILENAME}"
             <integer>REPALCE_STRING</integer>
EOF
    elif [ "${TYPE}" == "data" ]; then
        sed "s/REPALCE_STRING/${3}/g" <<- EOF >> "${FILENAME}"
             <data>REPALCE_STRING</data>
EOF
    else
        sed "s/REPALCE_STRING/${3}/g" <<- EOF >> "${FILENAME}"
             <string>REPALCE_STRING</string>
EOF
    fi
}

function setDeployCode() {
    FILENAME="${1}"
    DCode="${2}"

    keys=("DeployCode" "DeployTeamNameCache" "DeployTeamOwnerCache" "LastDeployCode" "TeamCode" "TeamCodeInUse")
    values=("${DCode}" "" "" "" "" "")
    types=("string" "string" "string" "string" "string" "string")

    n=${#keys[@]}
    for (( i=0; i<n; i++ ))
    do
        key=${keys[i]}
        value=${values[i]}
        type=${types[i]}

        plist_WriteOption "${FILENAME}" "${key}" "${value}" "${type}"
    done
}

function setShowDeployLoginWarning() {
    FILENAME="${1}"

    ShowDeployLoginWarning="true"
    if [ "${2// }" == "0" ]; then
        ShowDeployLoginWarning="false"
    fi
    plist_WriteOption "${FILENAME}" "ShowDeployLoginWarning" "${ShowDeployLoginWarning}" "bool"
}

function setComputerName() {
    FILENAME="${1}"
    plist_WriteOption "${FILENAME}" "HostName" "${2}" "string"
}

function setPermissionProtectionOption() {
    FILENAME="${1}"
    REQUEST_PERMISSION="${2}"
    EnablePermissionProtection=""

    if [ -z "${REQUEST_PERMISSION// }" ]; then
        return
    fi

    EnablePermissionProtection="${REQUEST_PERMISSION// }"
    if [ ! -z "${EnablePermissionProtection// }" ]; then
        plist_WriteOption "${FILENAME}" "EnablePermissionProtection" "${EnablePermissionProtection}" "int"
    fi    
}

function setSecurityOption() {
    FILENAME="${1}"
    SECURITY_OPTION="${2}"

    EnableSecurityCodeProtection=""
    EnableOSCredential=""

    if [ "$SECURITY_OPTION" == "0" ]; then
        EnableSecurityCodeProtection="false"
        EnableOSCredential="false"
    fi

    if [ "$SECURITY_OPTION" == "1" ]; then
        EnableSecurityCodeProtection="true"
        EnableOSCredential="false"
    fi

    if [ "$SECURITY_OPTION" == "2" ]; then
        EnableSecurityCodeProtection="false"
        EnableOSCredential="true"
    fi
    
    if [ ! -z "${EnableSecurityCodeProtection// }" ]; then
        plist_WriteOption "${FILENAME}" "EnableSecurityCodeProtection" "${EnableSecurityCodeProtection}" "bool"
    fi

    if [ ! -z "${EnableOSCredential// }" ]; then
        plist_WriteOption "${FILENAME}" "EnableOSCredential" "${EnableOSCredential}" "bool"
    fi    
}

function setInitSecurityCode() {
    FILENAME="${1}"
    plist_WriteOption "${FILENAME}" "init_security_code" "${2}" "bool"
}

function setLegacyConnectionLoopbackOnly() {
    FILENAME="${1}"
    plist_WriteOption "${FILENAME}" "LegacyConnectionLoopbackOnly" "true" "bool"
}

function setHideTrayIcon() {
    FILENAME="${1}"
    plist_WriteOption "${FILENAME}" "HideTrayIcon" "true" "bool"
}

function setDefaultClientDeviceName() {
    FILENAME="${1}"
    plist_WriteOption "${FILENAME}" "DefaultClientDeviceName" "${2}" "string"
}

function setShowStreamerUI() {
    FILENAME="${1}"

    keys=("FirstTimeClose" "FirstTimeLogin" "PermissionAlert")
    values=("false" "false" "false")
    types=("bool" "bool" "bool")

    n=${#keys[@]}
    for (( i=0; i<n; i++ ))
    do
        key=${keys[i]}
        value=${values[i]}
        type=${types[i]}

        plist_WriteOption "${FILENAME}" "${key}" "${value}" "${type}"
    done
}

function setEnableLanConnection() {
    FILENAME="${1}"

    plist_WriteOption "${FILENAME}" "EnableLanConnection" "false" "bool"
}

function setBackendAddress() {
    FILENAME="${1}"

    plist_WriteOption "${FILENAME}" "BackendAddress" "${2}" "string"
}

function setBackendAccount() {
    FILENAME="${1}"

    plist_WriteOption "${FILENAME}" "SplashtopAccount" "${2}" "string"
}

function setBackendPassword() {
    FILENAME="${1}"

    plist_WriteOption "${FILENAME}" "SplashtopPassword" "${2}" "string"
}

function setInfraGenForce() {
    FILENAME="${1}"
    plist_WriteOption "${FILENAME}" "InfraGenForce" "${2}" "int"
}

function setForceUUID32() {
    FILENAME="${1}"
    plist_WriteOption "${FILENAME}" "ForceUUID32" "${2}" "bool"
    
}

function setCommonDict() {
    FILENAME="${1}"
    STREAMER_TYPE="${2}"
    STREAMER="${3}"

    if [ "$STREAMER_TYPE" == "0" ]; then
        cat <<- EOF >> "${FILENAME}"
    <key>Common</key>
    <dict>
        <key>HidePreferenceDomainSelection</key>
        <true/>
        <key>EulaAccepted</key>
        <true/>
    </dict>
EOF
    else
        sed "s/REPALCE_STRING/${STREAMER_TYPE}/g" <<- EOF >> "${FILENAME}"
    <key>Common</key>
    <dict>
        <key>HidePreferenceDomainSelection</key>
        <true/>
        <key>EulaAccepted</key>
        <true/>
        <key>StreamerType</key>
        <integer>REPALCE_STRING</integer>
    </dict>
EOF
    fi
}

function setStreamerTypeDict() {
    FILENAME="${1}"
    STREAMER_TYPE="${2}"
    STREAMER="${3}"

    keys=()
    values=()
    types=()

    sed "s/REPALCE_STRING/${STREAMER}/g" <<- EOF >> "${FILENAME}"
    <key>REPALCE_STRING</key>
    <dict>
EOF

    if [ "$STREAMER_TYPE" == "0" ]; then
        keys+=("ShowDeployMode" "SplashtopAccount")
        values+=("true" "")
        types+=("bool" "string")
    fi

    if [ "$STREAMER_TYPE" == "1" ]; then
        keys+=("ShowDeployMode" "SplashtopAccount")
        values+=("true" "")
        types+=("bool" "string")
    fi

    if [ "$STREAMER_TYPE" == "2" ]; then
        keys+=("FirstTimeLogin" "BackendConnected" "ClientCertificateData" "CustomizeTeamCode" "FirstTimeLogin" "IsNewUUIDScheme" "RelayConnected")
        values+=("false" "true" "" "" "" "" "true")
        types+=("bool" "bool" "data" "string" "string" "string" "bool")
    fi

    n=${#keys[@]}
    for (( i=0; i<n; i++ ))
    do
        key=${keys[i]}
        value=${values[i]}
        type=${types[i]}

        plist_WriteOption "${FILENAME}" "${key}" "${value}" "${type}"
    done
}

function setPlistByStreamerType() {
    FILENAME="${1}"
    STREAMER_TYPE="${2}"
    STREAMER=""

    if [ "$STREAMER_TYPE" == "0" ]; then
        STREAMER="STP"
    fi

    if [ "$STREAMER_TYPE" == "1" ]; then
        STREAMER="STB"
    fi

    if [ "$STREAMER_TYPE" == "2" ]; then
        STREAMER="STE"
    fi

    cat <<- EOF > "${FILENAME}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UniversalSetting</key>
    <true/>
EOF

    setCommonDict "${FILENAME}" "${STREAMER_TYPE// }" "${STREAMER// }"
    setStreamerTypeDict "${FILENAME}" "${STREAMER_TYPE// }" "${STREAMER// }"
}

function restartApp() {
    APPNAME="${1}"
    ps axc -Ouser | grep -i "${APPNAME}" | awk '{print $1}' | xargs kill
    sleep 2
    open -b `osascript -e "id of app \"${APPNAME}\""`
}

function restartCoreAudioService() {
    MAJOR_MAC_VERSION=$(sw_vers -productVersion | awk -F '.' '{print $1 "." $2}')
    vercomp "${MAJOR_MAC_VERSION}" "10.9"
    if [ $? -eq 1 ]; then
        sleep 1; sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod; sleep 1;
    else
        sleep 1; sudo kill `ps -ax | grep 'coreaudiod' | grep 'sbin' |awk '{print $1}'`; sleep 1;
    fi
}

function removeSoundDriver() {
    KextInstallPath=("/Library/Extensions" "/System/Library/Extensions")
    KextName=("SplashtopSoundDriver.kext" "Soundflower.kext")

    for _kextPath in "${KextInstallPath[@]}" ; do
        for _kextName in "${KextName[@]}" ; do
            is_unload=true
            _kext="${_kextPath}/${_kextName}"
            _plist="${_kext}/Contents/Info.plist"

            BundleIdentifier=""
            Version=""

            [ -d "${_kext}" ] || continue

            if [ -f "${_plist}" ]; then
                #CFBundleIdentifier
                #CFBundleShortVersionString
                echo "${_plist}"

                BundleIdentifier=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${_plist}")
                Version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${_plist}")
            fi

            if [[ "${_kextName}" == "Soundflower.kext" && "${Version}" != "1.6.7" ]]; then
                is_unload=false
            fi

            if [ "$is_unload" = true ]; then
                [ -d "${_kext}" ] && echo "unstall kext... [${_kext}]" ; remove_kext "${_kext}" "${BundleIdentifier}"
            fi
        done
    done
}

function remove_kext() {
    _kext="$1"
    bundle_id="$2"

    if [ -z "${bundle_id}" ]; then
        exceCMD "sudo kextunload ${_kext}"
    else
        exceCMD "sudo kextstat -b \"${bundle_id}\" > /dev/null 2>&1 && sudo kextunload -b \"${bundle_id}\""
    fi

    exceCMD "sudo rm -rf \"${_kext}\""
}

function installKextSoundDriver() {
    KEXTPATH="${1}"
    KEXTNAME="${2}"
    #SplashtopSoundDriver.kext

    MAJOR_MAC_VERSION=$(sw_vers -productVersion | awk -F '.' '{print $1 "." $2}')
    vercomp "${MAJOR_MAC_VERSION}" "10.14"
    [[ $? -eq 1 ]] && KEXTINSTALLPATH="/Library/Extensions" || KEXTINSTALLPATH="/System/Library/Extensions"

    # copy app to tmp folder
    tarCopyFile "${KEXTPATH}/${KEXTNAME}" "${KEXTINSTALLPATH}"
    
    sudo chown -R root:wheel "${KEXTINSTALLPATH}/${KEXTNAME}"
    sudo chmod -R 755 "${KEXTINSTALLPATH}/${KEXTNAME}"
    sudo kextload "${KEXTINSTALLPATH}/${KEXTNAME}"
    sudo kextcache --clear-staging > /dev/null 2>&1
    sudo kextutil "${KEXTINSTALLPATH}/${KEXTNAME}"
    sudo kextstat | grep "${KEXTNAME%.*}"
}

function installPluginSoundDriver() {
    _path="$1"
    PlugInsPath="/Library/Audio/Plug-Ins/HAL"
    SoundPlugInsDriver="$2"

    _plist="${_path}/${SoundPlugInsDriver}/Contents/Info.plist"
    _version==$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${_plist}")

    if [ -d "${PlugInsPath}/${SoundPlugInsDriver}" ]; then
        _plist="${PlugInsPath}/${SoundPlugInsDriver}/Contents/Info.plist"
        Version==$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${_plist}")

        vercomp "${_version}" "${Version}"
        if [ $? -eq 1 ]; then
            if sudo rm -rf "${PlugInsPath}/${SoundPlugInsDriver}" && system_profiler SPAudioDataType | grep "Splashtop Remote Sound:"; then
                restartCoreAudioService
            fi
            sleep 1
        else
            # skipped install
            return
        fi
    fi

    if sudo cp -rf "${_path}/${SoundPlugInsDriver}" "${PlugInsPath}/"; then
        restartCoreAudioService
    fi
}

function installSoundDriver() {
    KEXTPATH="${1}"
    KEXTNAME="${2}"

    SOUNDPLUGINSPATH="${KEXTPATH}/updated"
    #vercomp "${MAJOR_MAC_VERSION}" "10.15"
    #[ $? -eq 1 ] && SOUNDPLUGINSPATH="${KEXTPATH}/universal"

    MAJOR_MAC_VERSION=$(sw_vers -productVersion | awk -F '.' '{print $1 "." $2}')
    vercomp "${MAJOR_MAC_VERSION}" "10.8"
    if [ $? -eq 1 ]; then
        SoundPlugInsDriver="SplashtopRemoteSound.driver"
        if [ -d "${SOUNDPLUGINSPATH}/${SoundPlugInsDriver}" ]; then
            installPluginSoundDriver "${SOUNDPLUGINSPATH}" "${SoundPlugInsDriver}"
            return
        fi
    fi

    installKextSoundDriver "${KEXTPATH}/updated" "${KEXTNAME}"
}
#----------------common function end-------------------------#

function usage()
{
    echo -e "Usage: `basename $1` [-i input streamer dmg file] [-d deploy code] [-a account based setting] [-w show deploy warning] ..."
    echo -e "\t-i : input streamer dmg file."
    echo -e "\t-k : input streamer pkg file."
    echo -e "\t-d : deploy code."
    echo -e "\t-w : show deploy warning (0/1). (default 1)"
    echo -e "\t-n : computer name."
    echo -e "\t-s : show Streamer UI after installation (0/1). (default 1)"
    echo -e "\t-c : init security code."
    echo -e "\t-e : Require additional password to connect (0:off, 1:Require security code, 2:Require Mac login). (default 0)"
    echo -e "\t-r : Request permission to connect (0:off, 1:reject after request expires, 2:connect after request expires, 3:reject after request expires and allow connect in pre-login)."
    echo -e "\t-l : loopback connection only (0/1). (default 0)"
    echo -e "\t-v : install/update driver (0/1). (default 1)"
    echo -e "\t-h : hide tray icon (0/1). (default 0)"
    echo -e "\t-b : default client name on connection bubble."
    echo -e "\t-p : enable LAN TCP/UDP server. (default 1)"
    echo -e "\t-t : to skip install pkg or dmg, to re-config setting."
    echo -e "\t-f : force Infrastructure Generation setting."
    echo -e "\t-x : Use high precision UUID."
}

#----------------usage function--------------------------#

CHECK_NEED_DMG_IN="0"
CHECK_NEED_DEPLOY_CODE="0"
CHECK_NEED_PKG_IN="1"
DEPLOY_CODE="75PZ545Z4J3L"
COMPUTER_NAME="$(whoami)@$(scutil --get ComputerName)"
REQUEST_PERMISSION="0"
INIT_SECURITY_CODE=""
SECURITY_OPTION="0"
LOOPBACK_ONLY="0"
INSTALL_DRIVER="1"
HIDE_TRAY_ICON="1"
DEFAULT_CLIENT_NAME="Updating..."
SHOW_DEPLOY_WARNING="0"
SHOW_STREAMER_UI="0"
ENABLE_LAN_SERVER="1"
SkippedInstall="0"
InfraGenForce="1"
ForceUUID32="1"

if [ "${CHECK_NEED_DMG_IN}" == "0" ] && [ "${CHECK_NEED_PKG_IN}" == "0" ] && [ "${SkippedInstall}" == "0" ]; then
    echo "Please input streamer dmg or pkg file!"
    usage "$0"
    exit 1
fi

#if [ "$CHECK_NEED_DEPLOY_CODE" == "0" ]; then
#echo "No deploy code!"
#usage "$0"
#exit 1
#fi

PRE_INSTALL_PATH="/Users/Shared/SplashtopStreamer"
#write .PreInstall
echo "Inject settings"
if [ ! -d "$PRE_INSTALL_PATH" ]; then
    mkdir "$PRE_INSTALL_PATH"
fi

if [ "$INSTALL_DRIVER" == "0" ]; then
    NO_DRIVER="${PRE_INSTALL_PATH}/.NoDriver"
    touch "$NO_DRIVER"
fi

TEMP_DIR="$(mktemp -d)"
trap "rm -rf $TEMP_DIR" EXIT

PRE_INSTALL="${PRE_INSTALL_PATH}/.PreInstall"
FILENAME="${TEMP_DIR}/.PreInstall.$$"
echo "Writing file ${PRE_INSTALL}"
#set plist header and common dict
# 0: STP, 1: STB, 2: STE
setPlistByStreamerType "${FILENAME}" "1"

[ ! -z "${DEPLOY_CODE// }" ] && setDeployCode "${FILENAME}" "${DEPLOY_CODE// }"
setShowDeployLoginWarning "${FILENAME}" "${SHOW_DEPLOY_WARNING// }"
[ ! -z "${COMPUTER_NAME// }" ] && setComputerName "${FILENAME}" "${COMPUTER_NAME// }"
[ ! -z "${REQUEST_PERMISSION// }" ] && setPermissionProtectionOption "${FILENAME}" "${REQUEST_PERMISSION// }"
[ ! -z "${SECURITY_OPTION// }" ] && setSecurityOption "${FILENAME}" "${SECURITY_OPTION// }"
[ ! -z "${INIT_SECURITY_CODE// }" ] && setInitSecurityCode "${FILENAME}" "${INIT_SECURITY_CODE// }"
[ "$LOOPBACK_ONLY" == "1" ] && setLegacyConnectionLoopbackOnly "${FILENAME}"
[ "$HIDE_TRAY_ICON" == "1" ] && setHideTrayIcon "${FILENAME}"
[ ! -z "${DEFAULT_CLIENT_NAME// }" ] && setDefaultClientDeviceName "${FILENAME}" "${DEFAULT_CLIENT_NAME// }"
[ "$SHOW_STREAMER_UI" == "0" ] && setShowStreamerUI "${FILENAME}"
[ "$ENABLE_LAN_SERVER" == "0" ] && setEnableLanConnection "${FILENAME}"
[ ! -z "${InfraGenForce// }" ] && setInfraGenForce "${FILENAME}" "${InfraGenForce}"
[ ! -z "${ForceUUID32// }" ] && setForceUUID32 "${FILENAME}" "${ForceUUID32}"

cat <<- EOF >> "${FILENAME}"
    </dict>
</dict>
</plist>
EOF

sudo cp -r "${FILENAME}" "${PRE_INSTALL}"
rm -rf "${FILENAME}"
#sudo chown -R root:wheel "${PRE_INSTALL}"
sudo chmod -R 755 "${PRE_INSTALL}"

if [ "${SkippedInstall}" == "0" ]; then
        curl -s -S -L -o "${TEMP_DIR}"/streamer.dmg https://git.io/download-streamer
        DMG_IN="${TEMP_DIR}"/streamer.dmg
        VOLUME=$(hdiutil attach -nobrowse "${DMG_IN}" | awk 'END {print $3}')
        [ -z "${VOLUME}" ] && VOLUME="/Volumes/SplashtopStreamer"
        echo "Install silently"
        NORMAL_INSTALLER="${VOLUME}/Splashtop Streamer.pkg"
        HIDDEN_INSTALLER="${VOLUME}/.Splashtop Streamer.pkg"
        if [ -f "${NORMAL_INSTALLER}" ]; then
            sudo installer -pkg "${NORMAL_INSTALLER}" -target /
        else
            sudo installer -pkg "${HIDDEN_INSTALLER}" -target /
        fi

        echo "Unmount dmg. ${VOLUME}"
        hdiutil detach -quiet "${VOLUME}"
else
    if [ ! -d "/Applications/Splashtop Streamer.app" ]; then
        echo "Error : Splashtop Streamer is not installed."

        rm -rf "${PRE_INSTALL}" 2>/dev/null || true
        exit 1;
    fi

    echo "Skipped install pkg or dmg, to re-config setting."
    restartApp "Splashtop Streamer"
fi

if [ "$INSTALL_DRIVER" == "1" ] && [ "$USER" == "root" ]; then
    MAJOR_MAC_VERSION=$(sw_vers -productVersion | awk -F '.' '{print $1 "." $2}')
    vercomp "${MAJOR_MAC_VERSION}" "10.8"
    if [ $? == 1 ]; then 
        removeSoundDriver
        installSoundDriver "/Applications/Splashtop Streamer.app/Contents/Resources" "SplashtopSoundDriver.kext"
    fi
fi

#echo "Launch Streamer"
#open "/Applications/Splashtop Streamer.app"
echo "Done!"

exit 0

