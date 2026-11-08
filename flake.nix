{
  description = "A very basic flake";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (
    system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          nimble
          nim
        ];
        buildInputs = with pkgs; [
          openssl
        ];
      };
    }
  );
}
