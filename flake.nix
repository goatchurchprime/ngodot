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
    version = "4.3.stable";
    exporttemplateurl = "https://github.com/godotengine/godot-builds/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz";
    exporttemplatesha256 = "sha256-c3vvaJAZKU4cEOdbg4cQEb3+OUFoEQurX8g9Qi4V+Sg=";
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
                rev = "77dcf97d82cbfe4e4615475fa52ca03da645dbd8";
                hash = "sha256-v2lBD3GEL8CoIwBl3UoLam0dJxkLGX0oneH6DiWkEsM=";
            };

            preBuild = ''
                substituteInPlace editor/editor_node.cpp \
                    --replace-fail 'About Godot' 'NNNing! Godot[v${version}]'

                substituteInPlace platform/android/export/export_plugin.cpp \
                    --replace-fail 'EDITOR_GET("export/android/debug_keystore")' 'std::getenv("tunnelvr_DEBUG_KEY")'

                substituteInPlace editor/editor_paths.cpp \
                    --replace-fail 'return get_data_dir().path_join("keystores/debug.keystore")' 'return std::getenv("tunnelvr_DEBUG_KEY")'

                substituteInPlace servers/register_server_types.cpp \
                    --replace-fail 'GDREGISTER_CLASS(AudioStreamMicrophone);' 'GDREGISTER_CLASS(AudioStreamMicrophone);GDREGISTER_CLASS(AudioStreamPlaybackMicrophone);'

                substituteInPlace modules/gltf/register_types.cpp \
                    --replace-fail 'EDITOR_GET("filesystem/import/blender/blender_path");' 'std::getenv("tunnelvr_BLENDER3_PATH");'
            '';
        }); 


    packages.x86_64-linux.godot_4_android = 
        with pkgs;
        symlinkJoin { 
            name = "godot_4-with-android-sdk";
            nativeBuildInputs = [ makeWrapper ];
            paths = [ packages.x86_64-linux.godot_4_hacked ];
            GODOT_VERSION_STATUS = "rc2";
            
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
                            --set tunnelvr_EXPORT_TEMPLATES "${export-templates}/templates" \
                            --set tunnelvr_DEBUG_KEY "${debugKey}" \
                            --set tunnelvr_BLENDER3_PATH "${pkgs.blender}/bin/" \
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
