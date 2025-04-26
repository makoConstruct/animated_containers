{
  description = "the flutter devshell definition for nixos developers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      # not doing android builds for now, mobile is no fun
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.android_sdk.accept_license = true;
        };
        android = pkgs.androidenv.composeAndroidPackages {
          toolsVersion = "26.1.1";
          platformToolsVersion = "34.0.1";
          buildToolsVersions = [ "30.0.1" "33.0.1" ];
          includeEmulator = true;
          emulatorVersion = "34.1.9";
          platformVersions = [ "28" "29" "33" "34" "35" ];
          includeSources = false;
          includeSystemImages = true;
          # we need "google_apis" here but it doesn't build, nix hashes are wrong
          systemImageTypes = [ "google_apis_playstore" ];
          abiVersions = [ "armeabi-v7a" "arm64-v8a" ];
          cmakeVersions = [ "3.10.2" ];
          includeNDK = true;
          ndkVersions = [ "22.0.7026061" ];
          useGoogleAPIs = true;
          useGoogleTVAddOns = false;
        #   extraLicenses = [
        #     "android-googletv-license"
        #     "android-sdk-arm-dbt-license"
        #     "android-sdk-license"
        #     "android-sdk-preview-license"
        #     "google-gdk-license"
        #     "intel-android-extra-license"
        #     "intel-android-sysimage-license"
        #     "mips-android-sysimage-license"            
          # ];
        };
      in {
        devShells.default =
          pkgs.mkShell {
            buildInputs = with pkgs; [
              flutter327
              jdk17
              android.platform-tools
              gst_all_1.gstreamer
              gst_all_1.gst-plugins-base
              gst_all_1.gst-plugins-good
              gst_all_1.gst-libav
              glibc
              # you may need this for linux
              # pkg-config gtk3 gtk3.dev ninja clang glibc
            ];
            
            nativeBuildInputs = [pkgs.pkg-config];
            
            shellHook = ''
              export PKG_CONFIG_PATH="${pkgs.gst_all_1.gstreamer.dev}/lib/pkgconfig:${pkgs.gst_all_1.gst-plugins-base.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
              export PS1="$PS1 (❄ "
            '';

            ANDROID_HOME = android.androidsdk + /libexec/android-sdk;
            JAVA_HOME = pkgs.jdk17;
            ANDROID_AVD_HOME = (toString ./.) + "/.android/avd";
            ANDROID_SDK_ROOT = android.androidsdk + /libexec/android-sdk;
          };
        
        # needed because gradle wants to use dynamic linking or something. I don't understand why this is a problem.
        # this isn't working. can't accept licenses. Unsure what happened with the above.
        devShells.fhs = (pkgs.buildFHSEnv {
            name = "flutter-android-env";
            targetPkgs = pkgs': with pkgs'; [
              flutter327
              jdk17
              android.platform-tools
              android.androidsdk
              gst_all_1.gstreamer
              gst_all_1.gst-plugins-base
              gst_all_1.gst-plugins-good
              gst_all_1.gst-libav
              glibc
              pkg-config
              # Add any other dependencies you need
            ];
            
            # profile = ''
            #   export ANDROID_HOME=${pkgs.android.androidsdk}/libexec/android-sdk
            #   export JAVA_HOME=${pkgs.jdk17}
            #   export ANDROID_AVD_HOME=$PWD/.android/avd
            #   export ANDROID_SDK_ROOT=${pkgs.android.androidsdk}/libexec/android-sdk
            # '';
            
            runScript = ''
              bash
            '';
          }).env;
      });
      
      
}