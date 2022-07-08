function importEnv {
  BUILDPATH="$(dirname $(realpath $0))/output"
  MANIFEST="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git"
  MANIFEST_BRANCH="twrp-12.1"
  DEVICE="X692"
  DT_LINK="https://github.com/ryenyuku/twrp_device_infinix_x692.git"
  DT_PATH="device/infinix/X692"
  TARGET="recoveryimage"
}

function beginBuild {
  echo -e "\n\033[0;32mSetting up environment..\033[0m"
  importEnv

  echo -e "\033[0;36mBUILDPATH: \033[0;37m$BUILDPATH\033[0m"
  echo -e "\033[0;36mMANIFEST: \033[0;37m$MANIFEST\033[0m"
  echo -e "\033[0;36mMANIFEST_BRANCH: \033[0;37m$MANIFEST_BRANCH\033[0m"
  echo -e "\033[0;36mDEVICE: \033[0;37m$DEVICE\033[0m"
  echo -e "\033[0;36mDT_LINK: \033[0;37m$DT_LINK\033[0m"
  echo -e "\033[0;36mDT_PATH: \033[0;37m$DT_PATH\033[0m"

  mkdir -p $BUILDPATH
  cd $BUILDPATH
  
  echo -e "\n\033[0;32mSyncing recovery source and device tree..\033[0m"
  repo init -u $MANIFEST -b $MANIFEST_BRANCH --depth=1
  repo sync -j$(nproc)

  # Cherry-pick patches from https://gerrit.twrp.me/c/android_bootable_recovery/+/5405
  git fetch https://gerrit.twrp.me/android_bootable_recovery refs/changes/05/5405/25 && git cherry-pick FETCH_HEAD

  # Another cherry-pick patches, this time from https://gerrit.twrp.me/c/android_system_vold/+/5540
  git fetch https://gerrit.twrp.me/android_system_vold refs/changes/40/5540/7 && git cherry-pick FETCH_HEAD

  git clone $DT_LINK --depth=1 --single-branch $DT_PATH

  echo -e "\n\033[0;32mBuilding..\033[0m"
  export ALLOW_MISSING_DEPENDENCIES=true
  . build/envsetup.sh; lunch twrp_$DEVICE-eng; mka $TARGET

  echo -e "\n\033[0;32mCopying generated recovery image..\033[0m"
  cd ..
  rm -f recovery.img
  cp -v output/out/target/product/$DEVICE/recovery.img .

  echo -e "\n\033[0;32mGenerating checksums..\033[0m"
  rm -f checksums
  sha1sum --tag recovery.img >> checksums
  sha256sum --tag recovery.img >> checksums
  md5sum --tag recovery.img >> checksums
}

function checkGitAuthority {
  MISSINGGITAUTHORITY=0
  if [ -z "$(git config --global user.email)" ]; then
    MISSINGGITAUTHORITY=1
  fi
  if [ -z "$(git config --global user.name)" ]; then
    [ $MISSINGGITAUTHORITY == 1 ] && MISSINGGITAUTHORITY=3 || MISSINGGITAUTHORITY=2
  fi

  if [ $MISSINGGITAUTHORITY -gt 0]]; then
    if [ $MISSINGGITAUTHORITY == 3]; then
      echo -e "\e[1;31mError:\e[0m Please set your Git username and email identity!"
    else
      [$MISSINGGITAUTHORITY == 1] && echo -e "\e[1;31mError:\e[0m Please set your Git email identity!" || echo -e "\e[1;31mError:\e[0m Please set your Git username identity!"
    fi
    exit 1
  fi

  beginBuild
}

echo -e "\e[1;33mWARNING:\e[0m Building TWRP is network expensive and you must have at least 60GiB of free storage space"
read -p ":: Proceed with building? [Y/N] "
case "${REPLY,,}" in
  y | yes)
    checkGitAuthority;;
  *)
    echo "Cancelled by user"
    exit 1;;
esac
