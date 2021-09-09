#!/bin/bash
#
# uninstall Splashtop Streamer script file
#
# Created by Cartor on 2019-11-18.
# Copyright 2019 Splashtop Inc. All rights reserved.
#

currentUser="$1"
appBundleId="com.splashtop.Splashtop-Streamer"
appOldName="$(pkgutil --only-dirs --files ${appBundleId} 2>/dev/null | head -n 1 2>/dev/null)"
[ -z "${appOldName}" ] && appOldName="Splashtop Streamer.app"

function exceCMD() {
	cmd="${1}"
	echo "${cmd}" | sh
	#echo "${cmd}"
	#echo "${cmd}" >> ~/uninstaller.log
}

function kill_process() {
    process_list="$1"

	for process in "${process_list[@]}" ; do
        exceCMD "sudo killall \"${process}\" 2>/dev/null || true"
    done
}

function del_files() {
    file_list="$1"

	for file in "${file_list[@]}" ; do
        exceCMD "sudo rm -rf ${file} 2>/dev/null || true"
    done
}

function del_launchctl_file() {
    file="$1"

    if [ -f "${file}" ]; then
	    if [ -z "$2" ]; then
	    	exceCMD "sudo launchctl unload ${file} 2>/dev/null || true"
	    else
	   		exceCMD "sudo -u $USER launchctl unload ${file} 2>/dev/null || true"
	   	fi
		exceCMD "sudo rm -rf ${file}* 2>/dev/null || true"
	fi
}

function del_launchctl_files_by_user() {
    file_list="$1"
    user="$2"

	for file in "${file_list[@]}" ; do
        del_launchctl_file "${file}" "${user}"
    done
}

function remove_kext() {
    _kext="$1"
    bundle_id="$2"

    if [ ! -z "${bundle_id}" ]; then
    	exceCMD "sudo kextstat -b \"${bundle_id}\" > /dev/null 2>&1 && sudo kextunload -b \"${bundle_id}\" > /dev/null 2>&1"
    fi

    exceCMD "sudo kextunload ${_kext} > /dev/null 2>&1"
	exceCMD "sudo rm -rf \"${_kext}\""
	exceCMD "sudo kextcache --clear-staging > /dev/null 2>&1"
}

function killOtherProductProcess() {
	echo "do kill killOtherProductProcess"
	process_list=("Splashtop Streamer Pro" "Splashtop Streamer for eno")
	kill_process "${process_list[@]}"
}

function killprocess() {
	if [ -d "/Applications/${appOldName}" ] ; then
		echo "do logout"
		exceCMD "open st-streamer://com.splashtop.streamer?logout=1 > /dev/null 2>&1 && sleep 4"
	fi
	echo "do kill process"

	process_list=("Splashtop Streamer" "inputserv" "spupnp" "SRProxy" "SRFeature" "SplashtopRemote" "SRIOFrameBuffer" "SRStreamerDaemon")
	kill_process "${process_list[@]}"
}

function killS4Bprocess() {
	echo "do kill killS4Bprocess"

	process_list=("Splashtop Streamer for Business" "SRStreamerBusinessDaemon")
	kill_process "${process_list[@]}"
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

function removePrinterDriver() {
	PDFWriterBundleId="de.lisanet.PDFwriter.pkg"
	PDFWriterInstallPath="$(pkgutil --only-dirs --files ${PDFWriterBundleId} 2>/dev/null | head -n 1 2>/dev/null)"
	uninstallScript="/Applications/${appOldName}/Contents/Resources/uninstall_pdfwriter.sh"

	if [ ! -z "${PDFWriterInstallPath}" ]; then
		script="${PDFWriterInstallPath}/uninstall.sh"
		if [ -f "${script}" ]; then
			exceCMD "sudo \"${script}\" 2>/dev/null || true"
		fi
	fi

	if [ -f "${uninstallScript}" ]; then
		exceCMD "sudo \"${uninstallScript}\" 2>/dev/null || true"
	fi

	if [ -d "/Users/Shared/PDFwriter" ]; then
		exceCMD "sudo rm -rf /Users/Shared/PDFwriter 2>/dev/null || true"
	fi

	for f in /Users/*; do
		PrinterFolder="${f}/Library/Printers/Splashtop Remote Printer.app"
		if [ -d "${PrinterFolder}" ]; then
			exceCMD "sudo rm -rf \"${PrinterFolder}\" 2>/dev/null || true"
		fi
	done
}

function removedriver() {
	KextInstallPath=("/Library/Extensions" "/System/Library/Extensions")
	KextInstaller="/Applications/${appOldName}/Contents/MacOS/KextInstaller.app/Contents/MacOS/KextInstaller"

	_kextName="SRXFrameBufferConnector.kext"

	removePrinterDriver

	if [ -f "${KextInstaller}" ]; then
		for _kextPath in "${KextInstallPath[@]}" ; do
			_kext="${_kextPath}/${_kextName}"

			[ -d "${_kext}" ] || continue

			exceCMD "sudo \"${KextInstaller}\" -u -n \"${_kext}\" 2>/dev/null || true"
		done
	else
	    echo "kext installer exit -1"
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

    if [ -d "/Library/Audio/Plug-Ins/HAL/SplashtopRemoteSound.driver" ]; then
    	if sudo rm -rf "/Library/Audio/Plug-Ins/HAL/SplashtopRemoteSound.driver" && system_profiler SPAudioDataType | grep "Splashtop Remote Sound:"; then
    		restartCoreAudioService
    	fi
    fi
}

function removeOtherProductPlist() {
	echo "do removeOtherProductPlist"

	file_list=("~/Library/Preferences/${appBundleId}-Pro.plist*" "~/Library/Preferences/${appBundleId}-for-eno.plist*")
	del_files "${file_list[@]}"
}

function removeplist() {
	echo "remove plist"
	exceCMD "[ -f ~/Library/Preferences/${appBundleId}.plist ] && defaults delete ${appBundleId} || echo 0"
	
	file_list=("/Users/Shared/SplashtopStreamer/*.plist" "~/Library/Preferences/com.splashtop.SRFeature.plist*" "~/Library/Preferences/com.splashtop.SplashtopRemote.plist*" "/Users/*/Library/Preferences/${appBundleId}.plist*" "/var/root/Library/Preferences/${appBundleId}.plist*" "~/Library/Preferences/${appBundleId}-UsageTracking.plist*" "/Users/*/Library/Preferences/${appBundleId}.plist*")
	del_files "${file_list[@]}"

	pkgutil_list=("com.splashtop.splashtopStreamer.com.splashtop.streamer-daemon.pkg" "com.splashtop.splashtopStreamer.com.splashtop.streamer-daemon.pkg" "com.splashtop.splashtopStreamer.com.splashtop.streamer-for-user.pkg" "com.splashtop.splashtopStreamer.com.splashtop.streamer-srioframebuffer.pkg" "com.splashtop.splashtopStreamer.postflight.pkg" "com.splashtop.splashtopStreamer.SplashtopStreamer.pkg" "com.splashtop.splashtopStreamer.com.splashtop.streamer-for-root.pkg" "${appBundleId}")

	for pkgutil in "${pkgutil_list[@]}" ; do
        exceCMD "sudo pkgutil --forget ${pkgutil} 2>/dev/null || true"
    done
}

function removeS4bPlist() {
	echo "remove s4b plist"

	file_list=("/Users/*/Library/Preferences/${appBundleId}-for-Business.plist*" "/var/root/Library/Preferences/${appBundleId}-for-Business.plist*" "/Library/LaunchAgents/com.splashtop.s4b-for-root.plist*" "/Library/LaunchAgents/com.splashtop.s4b-for-user.plist*")
	del_files "${file_list[@]}"
}

function removefiles() {
	echo "remove files"
	# try to remove uri setting.
	lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister" # or `locate -l1 lsregister`
	exceCMD "${lsregister} -u '/Applications/${appOldName}'"

	file_list=("~/Library/Caches/iris-proxy-pipe*" "~/Library/Logs/iris-log-pipe" "~/Library/Logs/SPLog.txt*" "/Users/Shared/SplashtopStreamer/.PreInstall" "/Users/Shared/SplashtopStreamer/SPLOG.txt*" "/Users/Shared/SplashtopStreamer/SPLOG.bak*" "/Users/Shared/SplashtopStreamer/SPLOG.tmp*" "/Applications/SplashtopRemote.app" "'/Applications/SplashtopRemoteStreamer.app'" "'/Applications/${appOldName}'" "'/Applications/Splashtop Streamer for Business.app'" "/System/Library/Extensions/SRXDisplayCard.kext" "/System/Library/Extensions/SRXFrameBufferConnector.kext" "/Library/Extensions/SRXDisplayCard.kext" "/Library/Extensions/SRXFrameBufferConnector.kext" "/Library/Frameworks/SRFrameBufferConnection.framework" "/Users/Shared/SplashtopStreamer/Premium" "/Users/Shared/SplashtopStreamer/AntiVirus" "/Users/Shared/SplashtopStreamer/scheduleData" "~/Library/Caches/${appBundleId}")
	del_files "${file_list[@]}"
}

function removeOtherProductFiles() {
	echo "do removeOtherProductFiles"

	file_list=("'/Applications/Splashtop Streamer Pro.app'" "'/Applications/Splashtop Streamer for eno.app'")
	del_files "${file_list[@]}"
}

function removeS4Bfiles() {
	echo "do removeS4Bfiles"
	file_list=("'/Applications/Splashtop Streamer for Business.app'")
	del_files "${file_list[@]}"
}

function rmsystemplist() {
	echo "do system check"

	file_list=("/Library/LaunchAgents/com.splashtop.streamer.SRServiceAgent.plist" "/Library/LaunchAgents/com.splashtop.streamer-for-user.plist")
	del_launchctl_files_by_user "${file_list[@]}" "$USER"

	if [ -f "/Library/LaunchAgents/com.splashtop.streamer-for-root.plist" ]; then
		file_list=("/Library/LaunchAgents/com.splashtop.streamer-for-root.plist" "/Users/*/Library/LaunchAgents/com.splashtop.streamer-for-user.plist")
		del_files "${file_list[@]}"
	fi

	file_list=("/Library/LaunchDaemons/com.splashtop.streamer.SRServiceDaemon.plist" "/Library/LaunchDaemons/com.splashtop.streamer-daemon.plist" "/Library/LaunchDaemons/com.splashtop.streamer-srioframebuffer.plist" "/Library/LaunchAgents/com.splashtop.business.SRServiceAgent.plist" "/Library/LaunchAgents/com.splashtop.business.SRServicePreLogin.plist" "/Library/LaunchDaemons/com.splashtop.s4b-daemon.plist")
	del_launchctl_files_by_user "${file_list[@]}" ""
}

function clearPlistCache() {
	if [ -z "$1" ]; then
		exceCMD "ps axc -Ouser | grep [c]fprefsd | awk '{print \$1}' | xargs kill"
	else
		exceCMD "ps axc -Ouser | grep [c]fprefsd | grep \"$1\" | awk '{print \$1}' | xargs kill"
	fi
}

function initLog() {
	exceCMD "sudo rm -rf /Users/Shared/SplashtopStreamer/SPLOG.txt*"
	echo "installlog"
	[ -f "/Users/Shared/SplashtopStreamer/SPLOG.txt" ] || exceCMD "sudo touch /Users/Shared/SplashtopStreamer/SPLOG.txt"
	exceCMD "sudo chmod 666 /Users/Shared/SplashtopStreamer/SPLOG.txt"
}

function doinstall() {
	echo "install"
	killprocess
	rmsystemplist
	process_list=("Splashtop Streamer" "SRStreamerDaemon")
	kill_process "${process_list[@]}"

	removedriver
	removefiles

	removeplist
	removeSoundDriver
}

function doupdate() {
	echo "update"
	killprocess
	delay 1
	rmsystemplist
}

function doInstallWithRmAll() {
	echo "doInstallWithRmAll"
	killprocess
	killS4Bprocess
	killOtherProductProcess
	rmsystemplist

	process_list=("Splashtop Streamer" "SRStreamerDaemon")
	kill_process "${process_list[@]}"
	
	removeS4bPlist
	removeOtherProductPlist
	removeOtherProductFiles
	removeS4Bfiles

	removedriver
	removefiles

	removeplist
	removeSoundDriver
	clearPlistCache "${currentUser}"
}

#echo "argv : $@" > ~/uninstaller.log

echo "argv : $@"

initLog
doinstall

