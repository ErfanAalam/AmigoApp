
{
  description = "Flutter dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in pkgs.mkShell {
      buildInputs = [
        pkgs.flutter
        pkgs.dart
        pkgs.androidsdk
        pkgs.androidsdk-platform-tools
        pkgs.androidsdk-build-tools
        pkgs.pkg-config
        pkgs.gcc
        pkgs.git
        pkgs.fish
      ];

      shell = "fish";    # Use Fish instead of default shell

      # Environment variables for Flutter + Android SDK
      shellHook = ''
        export ANDROID_SDK_ROOT=${pkgs.androidsdk}/share/android-sdk
        export PATH=$ANDROID_SDK_ROOT/platform-tools:$PATH
        echo "Flutter dev environment loaded!"
      '';
    };
  };
}
