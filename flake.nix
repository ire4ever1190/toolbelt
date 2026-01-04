{
  description = "A Nix-flake-based Nim development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs { inherit system; };
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default =
            let
              odbcDrivers = pkgs.writeTextDir "odbcinst.ini" ''
                [${pkgs.unixODBCDrivers.sqlite.fancyName}]
                Description = ${pkgs.unixODBCDrivers.sqlite.meta.description}
                Driver = ${pkgs.unixODBCDrivers.sqlite}/${pkgs.unixODBCDrivers.sqlite.driver}
              '';
            in
            pkgs.mkShellNoCC {
              packages = with pkgs; [
                nim
                nimble

                unixODBCDrivers.sqlite
                unixODBC
              ];
              shellHook = ''
                export ODBCSYSINI=${odbcDrivers}
                export ODBCINI=${./odbc.ini}
                export LD_LIBRARY_PATH="${pkgs.unixODBC}/lib:$LD_LIBRARY_PATH"
              '';
            };
        }
      );
    };
}
