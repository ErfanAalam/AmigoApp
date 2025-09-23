{
  description = "Flutter Android Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, android-nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        # Compose Android SDK package
        androidCustomPackage = android-nixpkgs.sdk.${system} (sdkPkgs:
          with sdkPkgs; [
            cmdline-tools-latest
            build-tools-34-0-0
            platform-tools
            emulator
            platforms-android-34
          ]);

        pinnedJDK = pkgs.jdk17;

      in {
        devShells.default = pkgs.mkShell {
          name = "flutter-dev-shell";

          # Shell commands to run when entering the shell
          shellHook = ''
            export ANDROID_HOME=$HOME/Android/Sdk
            export ANDROID_SDK_ROOT=$HOME/Android/Sdk
            export PATH=$ANDROID_HOME/platform-tools:$PATH
            echo "hello fish"
            exec fish
          '';

          buildInputs = with pkgs;
            [ flutter dart pkg-config fish ]
            ++ [ pinnedJDK androidCustomPackage ];

          ANDROID_HOME = "/home/gaz/Android/Sdk";
          ANDROID_SDK_ROOT = "/home/gaz/Android/Sdk";
          PATH = "/home/gaz/Android/Sdk/platform-tools:$PATH";

          JAVA_HOME = pinnedJDK;
          GRADLE_USER_HOME = "/home/gaz/.gradle";
          GRADLE_OPTS =
            "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidCustomPackage}/share/android-sdk/build-tools/34.0.0/aapt2";
        };
      });
}
