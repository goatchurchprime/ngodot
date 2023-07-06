{
description = "A flake for building Godot_4";

inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

outputs = { self, nixpkgs }: rec {
    system = "x86_64-linux";
    version = "4.1";
    pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; android_sdk.accept_license = true; }; };
    
    packages.x86_64-linux.godot_4_hacked =

      with import nixpkgs { system = "x86_64-linux"; };
      godot_4.overrideAttrs (old: {
        src = fetchFromGitHub {
            name = "godot_${version}"; 
            owner = "godotengine";
            repo = "godot";
            rev = "${version}-stable";
            hash = "sha256-v9qKrPYQz4c+xkSu/2ru7ZE5EzKVyXhmrxyHZQkng2U=";
        };

        preBuild = 
        ''
          substituteInPlace editor/editor_node.cpp \
            --replace 'About Godot' 'NNing! Godot'

          substituteInPlace platform/android/export/export_plugin.cpp \
            --replace 'String sdk_path = EDITOR_GET("export/android/android_sdk_path")' 'String sdk_path = std::getenv("tunnelvr_ANDROID_SDK")'

          substituteInPlace platform/android/export/export_plugin.cpp \
            --replace 'EDITOR_GET("export/android/debug_keystore")' 'std::getenv("tunnelvr_DEBUG_KEY")'

          substituteInPlace editor/editor_paths.cpp \
            --replace 'return get_data_dir().path_join(export_templates_folder)' 'printf("HITHERE\n"); return std::getenv("tunnelvr_EXPORT_TEMPLATES")'
        '';
    }); 

    packages.x86_64-linux.godot_4_android = 
        with import nixpkgs { system = "x86_64-linux"; config = { allowUnfree = true; android_sdk = { accept_license = true;}; }; };
        symlinkJoin { 
            name = "godot_4-with-android-sdk";
            nativeBuildInputs = [ makeWrapper ];
            paths = [ packages.x86_64-linux.godot_4_hacked ];
            
            postBuild = let
                debugKey = runCommand "debugKey" {} ''
                    ${jre_minimal}/bin/keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
                    mv debug.keystore $out
                '';
            
               export-templates = fetchurl {
                    name = "godot_${version}";
                    url = "https://downloads.tuxfamily.org/godotengine/${version}/Godot_v${version}-stable_export_templates.tpz";
                    sha256 = "sha256-FzYOLPgqTyNADXhDHKXWhhF7bnNjz98HaQfLfIb9olk=";
                    recursiveHash = true;
                    downloadToTemp = true;
                    postFetch = ''
                       ${unzip}/bin/unzip $downloadedFile -d ./
                        mkdir -p $out/templates/${version}.stable
                        mv ./templates/* $out/templates/${version}.stable
                    '';
                };
                in
                    ''
                        wrapProgram $out/bin/godot4 \
                            --set tunnelvr_ANDROID_SDK "${androidenv.androidPkgs_9_0.androidsdk}/libexec/android-sdk"\
                            --set tunnelvr_EXPORT_TEMPLATES "${export-templates}/templates" \
                            --set tunnelvr_DEBUG_KEY "${debugKey}"
                    '';
      };




#    packages.x86_64-linux.godot_4_android = packages.x86_64-linux.godot_4_hacked;
    packages.x86_64-linux.default = packages.x86_64-linux.godot_4_android;

    devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
            packages.x86_64-linux.godot_4_android
            caddy
        ];
    };
            
};
}
