{
description = "A flake for compiling godot and its android templates";

# start in directory repositories/godot (source code of godot)
#  hack this source code's version.py to match the template you will make
# do: nix develop ../ngodot/androidenv
# then: nix develop nixpkgs#godot_4
# To compile:
#   runPhase buildPhase
#   runPhase installPhase
#   runPhase fixupPhase

# Make sure the godot/version.py matches the directory in /home/julian/.local/share/godot/export_templates/4.4.dev6
# (Attempts at building the android templates on nix have failed here, please copy in from compiling on windows)
# after you install the templates you may need to do:
# chmod 755 ../godot_multiplayer_networking_workbench_G4/android/build/gradlew


# --builders ssh-ng://nix-ssh@100.107.23.115
# Instructions: normally do nix develop.  Or change version, set both sha256s to "" (incl export templates) and run to find them, nix flake update

nixConfig = {
    extra-substituters = ["https://tunnelvr.cachix.org"];
    extra-trusted-public-keys = ["tunnelvr.cachix.org-1:IZUIF+ytsd6o+5F0wi45s83mHI+aQaFSoHJ3zHrc2G0="];
};

inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
inputs.android.url = "github:tadfisher/android-nixpkgs";

outputs = { self, nixpkgs, android }: rec {
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };

    androidenv = android.sdk.x86_64-linux (sdkPkgs: with sdkPkgs; [
        build-tools-34-0-0
        cmdline-tools-latest
        platform-tools
        platforms-android-34
        #ndk-23-2-8568313  # this is the version we want according to the docs
    ]);

    devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
            jdk17
            gradle
            #androidenv
        ];
        #inputsFrom = [ pkgs.godot_4 ];  # need to follow up with nix develop 
        shellHook = ''
            export ANDROID_HOME="${androidenv}/share/android-sdk"
            export JAVA_HOME="${pkgs.jdk17}/lib/openjdk"
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidenv}/share/android-sdk/build-tools/34.0.0/aapt2"
        '';
    };
};
}
