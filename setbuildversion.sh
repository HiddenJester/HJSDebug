#!/bin/sh
# Copied from http://blog.jaredsinclair.com/post/97193356620/the-best-of-all-possible-xcode-automated-build

# TLS 2015-05-08 Because of the requirement to make the WatchKit version info to the app versions and the ability
# to run the script against the WatchKit app I have to set the WatchKit's info in a git hook and thereforce I can't
# do the test for the Debug scheme. For now I've just disabled the ability to set the branch information in the
# in the bundle version. I attempted to push it in into CFBundleShortVersionString but WatchKit insists that those
# match as well.
#
# Set the build number to the current git commit count.
# If we're using the Dev scheme, then we'll suffix the build
# number with the current branch name, to make collisions
# far less likely across feature branches.
#   http://w3facility.info/question/how-do-i-force-xcode-to-rebuild-the-info-plist-file-in-my-project-every-time-i-build-the-project/
#
git=`sh /etc/profile; which git`
appBuild=`"$git" rev-list --all |wc -l`
#if [ $CONFIGURATION = "Debug" ]; then
#branchName=`"$git" rev-parse --abbrev-ref HEAD`
#/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $appBuild-$branchName" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
#else
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $appBuild" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
#fi
echo "Updated ${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"