{
description = "A flake for building Godot_4 with Android templates";

# --builders ssh-ng://nix-ssh@100.107.23.115
# Instructions: normally do nix develop.  Or change version, set both sha256s to "" (incl export templates) and run to find them, nix flake update

nixConfig = {
    extra-substituters = ["https://tunnelvr.cachix.org"];
    extra-trusted-public-keys = ["tunnelvr.cachix.org-1:IZUIF+ytsd6o+5F0wi45s83mHI+aQaFSoHJ3zHrc2G0="];
};

inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
inputs.android.url = "github:tadfisher/android-nixpkgs";

outputs = { self, nixpkgs, android }: rec {
    system = "x86_64-linux";
    version = "4.3.beta";
    exporttemplateurl = "https://downloads.tuxfamily.org/godotengine/4.3/beta1/Godot_v4.3-beta1_export_templates.tpz";
    pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };

    androidenv = android.sdk.x86_64-linux (sdkPkgs: with sdkPkgs; [
        build-tools-34-0-0
        cmdline-tools-latest
        platform-tools
        platforms-android-34
    ]);

    packages.x86_64-linux.godot_4_hacked =
        with pkgs;
        godot_4.overrideAttrs (old: {
            src = fetchFromGitHub {
                name = "godot_BBB${version}"; 
                owner = "godotengine";
                repo = "godot";
                rev = "a4f2ea91a1bd18f70a43ff4c1377db49b56bc3f0";
                hash = "sha256-1hV4XSPwG1pKkf8S3FuLnpGnyYdcQFJzwa6xnKzF9yE=";
            };

            preBuild = ''
                substituteInPlace editor/editor_node.cpp \
                    --replace 'About Godot' 'NNing! Godot[v${version}]'

                substituteInPlace platform/android/export/export_plugin.cpp \
                    --replace 'String sdk_path = EDITOR_GET("export/android/android_sdk_path")' 'String sdk_path = std::getenv("tunnelvr_ANDROID_SDK")'

                substituteInPlace platform/android/export/export_plugin.cpp \
                    --replace 'EDITOR_GET("export/android/debug_keystore")' 'std::getenv("tunnelvr_DEBUG_KEY")'

                substituteInPlace platform/android/export/export_plugin.cpp \
                    --replace 'EDITOR_GET("export/android/java_sdk_path")' 'std::getenv("tunnelvr_JAVA_SDK_PATH")'

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
            GODOT_VERSION_STATUS = "beta1";
            
            postBuild = let
                debugKey = runCommand "debugKey" {} ''
                    ${jre_minimal}/bin/keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
                    mv debug.keystore $out
                '';
            
                export-templates = fetchurl {
                    name = "godot_${version}";
                    url = exporttemplateurl;
                    sha256 = "";
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
                            --set tunnelvr_ANDROID_SDK "${androidenv}/share/android-sdk"\
                            --set tunnelvr_JAVA_SDK_PATH "${pkgs.jdk17}/lib/openjdk"\
                            --set tunnelvr_EXPORT_TEMPLATES "${export-templates}/templates" \
                            --set tunnelvr_DEBUG_KEY "${debugKey}" \
                            --set GODOT_BLENDER3_PATH "${pkgs.blender}/bin/" \
                            --set GRADLE_OPTS "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidenv}/share/android-sdk/build-tools/34.0.0/aapt2"
                    '';
    };


    #packages.x86_64-linux.default = packages.x86_64-linux.godot_4_hacked;
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
