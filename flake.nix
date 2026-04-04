{
  description = "Flutter Android Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      android-nixpkgs,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        # Compose Android SDK package
        androidCustomPackage = android-nixpkgs.sdk.${system} (
          sdkPkgs: with sdkPkgs; [
            cmdline-tools-latest
            build-tools-36-0-0
            build-tools-35-0-0
            platform-tools
            platforms-android-31
            platforms-android-32
            platforms-android-33
            platforms-android-36
            platforms-android-34
            platforms-android-35
            cmake-3-22-1
            ndk-28-2-13676358
          ]
        );

        pinnedJDK = pkgs.jdk17;

      in
      {
        devShells.default = pkgs.mkShell {
          name = "flutter-dev-shell";

          # Shell commands to run when entering the shell
          shellHook = ''
            export ANDROID_HOME=${androidCustomPackage}/share/android-sdk
            export ANDROID_SDK_ROOT=$ANDROID_HOME
            export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/28.2.13676358
            export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
            export PATH=$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/build-tools/35.0.0:$ANDROID_HOME/build-tools/36.0.0:$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
            echo "-----------------------------------------------------------------"
            echo "      Your flutter android development environment is ready"
            echo "-----------------------------------------------------------------"
            # exec fish
          '';

          buildInputs =
            with pkgs;
            [
              flutter
              dart
              pkg-config
            ]
            ++ [
              pinnedJDK
              androidCustomPackage
            ];

          JAVA_HOME = pinnedJDK;
          GRADLE_USER_HOME = "/home/gaz/.gradle";
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/36.0.0/aapt2";
        };
      }
    );
}
