{
description = "A flake for building Godot_4 with Android templates";

# --builders ssh-ng://nix-ssh@100.107.23.115
# Instructions: normally do nix develop.  Or change version, set sha256s to "" and run to find them, nix flake update

nixConfig = {
    extra-substituters = ["https://tunnelvr.cachix.org"];
    extra-trusted-public-keys = ["tunnelvr.cachix.org-1:IZUIF+ytsd6o+5F0wi45s83mHI+aQaFSoHJ3zHrc2G0="];
};

inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
inputs.android.url = "github:tadfisher/android-nixpkgs";

outputs = { self, nixpkgs, android }: rec {
    system = "x86_64-linux";
    version = "4.2.1.stable";
    exporttemplateurl = "https://downloads.tuxfamily.org/godotengine/4.2.1/Godot_v4.2.1-stable_export_templates.tpz";
    exporttemplatehash = "sha256-20R7f7hnjm9Va03weUOZLJqdUH+7IBsMiE56f3+a2H4=";

    pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };

    androidenv = android.sdk.x86_64-linux (sdkPkgs: with sdkPkgs; [
        build-tools-33-0-2
        cmdline-tools-latest
        platform-tools
        platforms-android-33
    ]);

    
    packages.x86_64-linux.godot_4_hacked =
        with pkgs;
        godot_4.overrideAttrs (old: {
            src = fetchFromGitHub {
                name = "godot_BBB${version}"; 
                owner = "godotengine";
                repo = "godot";
                rev = "b09f793f564a6c95dc76acc654b390e68441bd01";
                hash = "sha256-Q6Og1H4H2ygOryMPyjm6kzUB6Su6T9mJIp0alNAxvjQ=";
            };

            preBuild = ''
                substituteInPlace editor/editor_node.cpp \
                    --replace 'About Godot' 'NNingo! Godot[v${version}]'

                substituteInPlace platform/android/export/export.cpp \
                    --replace 'EDITOR_DEF("export/android/debug_keystore", "")' 'EDITOR_DEF("export/android/debug_keystore", OS::get_singleton()->get_environment("tunnelvr_DEBUG_KEY"))'

                substituteInPlace editor/editor_paths.cpp \
                    --replace 'return get_data_dir().path_join(export_templates_folder)' 'printf("HITHEREE\n"); return std::getenv("tunnelvr_EXPORT_TEMPLATES")'

                substituteInPlace modules/gltf/register_types.cpp \
                    --replace 'EDITOR_DEF_RST("filesystem/import/blender/blender3_path", "");' 'EDITOR_DEF_RST("filesystem/import/blender/blender3_path", (std::getenv("GODOT_BLENDER3_PATH") != nullptr ? std::getenv("GODOT_BLENDER3_PATH") : "notset"));'
            '';
        }); 


    packages.x86_64-linux.godot_4_android = 
        with pkgs;
        symlinkJoin { 
            name = "godot_4-with-android-sdk";
            nativeBuildInputs = [ makeWrapper ];
            paths = [ packages.x86_64-linux.godot_4_hacked ];
            GODOT_VERSION_STATUS = "dev6";
            
            postBuild = let
                debugKey = runCommand "debugKey" {} ''
                    ${jre_minimal}/bin/keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
                    mv debug.keystore $out
                '';
            
                export-templates = fetchurl {
                    name = "godot_${version}";
                    url = exporttemplateurl;
                    sha256 = exporttemplatehash;
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
                            --set tunnelvr_EXPORT_TEMPLATES "${export-templates}/templates" \
                            --set tunnelvr_DEBUG_KEY "${debugKey}" \
                            --set GODOT_BLENDER3_PATH "${pkgs.blender}/bin/" \
                            --set GRADLE_OPTS "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidenv}/share/android-sdk/build-tools/33.0.2/aapt2"
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
