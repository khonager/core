{
  description = "Core Flutter and Android development";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; android_sdk.accept_license = true; };
        };
        android = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "36" ];
          buildToolsVersions = [ "35.0.0" ];
          includeNDK = true;
          ndkVersions = [ "28.2.13676358" ];
          cmakeVersions = [ "3.22.1" ];
        };
      in {
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.flutter pkgs.jdk17 pkgs.python3 android.androidsdk ];
          ANDROID_HOME = "${android.androidsdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
          JAVA_HOME = pkgs.jdk17.home;
        };
      });
}
