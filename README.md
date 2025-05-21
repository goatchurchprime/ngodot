
# ngodot

A nix flake that wrap Godot with the Android runtime and Gradle (VR ready).

## usage

Create a file `flake.nix` at the root of your project, you can then enter the development environment using `nix develop`.

```
{
  description = "Example usage of ngodot";
  inputs.nix-godot-android.url = "github:goatchurchprime/ngodot";
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, nix-godot-android }: {
    devShells.x86_64-linux.default = nix-godot-android.devShells.x86_64-linux.default;
  };
}
```
