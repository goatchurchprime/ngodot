# Instructions: normally do nix develop.  Or change version, set both sha256s to "" (incl export templates) and run to find them, nix flake update
{
description = "A flake for building Godot 4 with Android templates and Gradle";

inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
inputs.android.url = "github:tadfisher/android-nixpkgs";

outputs = { self, nixpkgs, android }: rec {
    system = "x86_64-linux";
    version = "4.4.1.stable";
    exporttemplateurl = "https://github.com/godotengine/godot-builds/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz";
    exporttemplatesha256 = "sha256-TjtUmI3WxCS6YfEmJSc8Gmk9bja4vyhRrW0Nb1MGt5w=";
    pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };

    androidenv = android.sdk.x86_64-linux (sdkPkgs: with sdkPkgs; [
        build-tools-34-0-0
        cmdline-tools-latest
        platform-tools
        platforms-android-34
    ]);

    packages.x86_64-linux.godot_4_wrapped =
        with pkgs;
        godot_4_4.overrideAttrs (old: {
            src = fetchFromGitHub {
                name = "godot_${version}_wrapped";
                owner = "godotengine";
                repo = "godot";
                rev = "49a5bc7b616bd04689a2c89e89bda41f50241464";
                hash = "sha256-BBlKKsVURPYqKuxrwMbDD7tKHDfvihxbhXFnHWUyuDk=";
            };

            preBuild = ''
                substituteInPlace editor/editor_node.cpp \
                    --replace-fail 'About Godot' 'Godot[v${version}] (nix-godot-android)'

                substituteInPlace platform/android/export/export_plugin.cpp \
                    --replace-fail 'EDITOR_GET("export/android/debug_keystore")' 'std::getenv("GODOT_DEBUG_KEY")'

                substituteInPlace editor/editor_paths.cpp \
                    --replace-fail 'return get_data_dir().path_join("keystores/debug.keystore")' 'return std::getenv("GODOT_DEBUG_KEY")'

                substituteInPlace editor/editor_paths.cpp \
                    --replace-fail 'return get_data_dir().path_join(export_templates_folder)' 'return std::getenv("GODOT_EXPORT_TEMPLATES")'

                substituteInPlace modules/gltf/register_types.cpp \
                    --replace-fail 'EDITOR_GET("filesystem/import/blender/blender_path");' 'std::getenv("GODOT_BLENDER3_PATH");'
            '';
        });


    packages.x86_64-linux.godot_4_android =
        with pkgs;
        symlinkJoin {
            name = "godot_4-with-android-sdk";
            nativeBuildInputs = [ makeWrapper ];
            paths = [ packages.x86_64-linux.godot_4_wrapped ];

            postBuild = let
                debugKey = runCommand "debugKey" {} ''
                    ${jre_minimal}/bin/keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
                    mv debug.keystore $out
                '';
                export-templates = fetchurl {
                    name = "godot_${version}";
                    url = exporttemplateurl;
                    sha256 = exporttemplatesha256;
                    recursiveHash = true;
                    downloadToTemp = true;
                    postFetch = ''
                       ${unzip}/bin/unzip $downloadedFile -d ./
                        mkdir -p $out/templates/${version}
                        mv ./templates/* $out/templates/${version}
                    '';
                };
                in
                    ''
                        wrapProgram $out/bin/godot4 \
                            --set ANDROID_HOME "${androidenv}/share/android-sdk"\
                            --set JAVA_HOME "${pkgs.jdk17}/lib/openjdk"\
                            --set GODOT_EXPORT_TEMPLATES "${export-templates}/templates" \
                            --set GODOT_DEBUG_KEY "${debugKey}" \
                            --set GODOT_BLENDER3_PATH "${pkgs.blender}/bin/" \
                            --set GRADLE_OPTS "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidenv}/share/android-sdk/build-tools/34.0.0/aapt2"
                    '';
    };


    packages.x86_64-linux.default = packages.x86_64-linux.godot_4_android;

    devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
            packages.x86_64-linux.default
            jdk17
            gradle
        ];
    };
};
}
