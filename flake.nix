{
  description = "Nerdlog - Nix flake packaging and devShell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        # Derive version / date / commit from the flake context when available
        rev = if self ? rev then self.rev else "dirty";
        lmd = if self ? lastModifiedDate then self.lastModifiedDate else "19700101000000"; # YYYYMMDDHHMMSS
        date = "${builtins.substring 0 4 lmd}-${builtins.substring 4 2 lmd}-${builtins.substring 6 2 lmd}T${builtins.substring 8 2 lmd}:${builtins.substring 10 2 lmd}:${builtins.substring 12 2 lmd}Z";
        version = if self ? rev then "unstable-${builtins.substring 0 8 self.rev}" else "dev";

        enableCgo = pkgs.stdenv.isLinux; # enable clipboard on Linux by default
        nativeInputs = lib.optionals enableCgo [ pkgs.pkg-config ];
        runtimeLibs = lib.optionals pkgs.stdenv.isLinux [
          pkgs.xorg.libX11
          pkgs.xorg.libXfixes
          pkgs.xorg.libXext
        ];
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "nerdlog";
          inherit version;
          src = ./.;

          # Main package lives under cmd/nerdlog
          subPackages = [ "cmd/nerdlog" ];

          # Go modules vendor hash (computed via `nix build`)
          vendorHash = "sha256-ig2b5OaTdJNdY6+sqErBqaKAHxtvptzIP17lB+sMQPA=";

          # Embed version info like the Makefile does
          ldflags = [
            "-s" "-w"
            "-X github.com/dimonomid/nerdlog/version.version=${version}"
            "-X github.com/dimonomid/nerdlog/version.commit=${rev}"
            "-X github.com/dimonomid/nerdlog/version.date=${date}"
            "-X github.com/dimonomid/nerdlog/version.builtBy=nix"
          ];

          env = {
            CGO_ENABLED = if enableCgo then "1" else "0";
          };
          nativeBuildInputs = nativeInputs;
          buildInputs = runtimeLibs;

          # Tests rely on a more involved environment; keep packaging fast.
          doCheck = false;

          meta = with lib; {
            description = "TUI for tailing and filtering logs across many nodes";
            homepage = "https://github.com/dimonomid/nerdlog";
            license = licenses.mit;
            mainProgram = "nerdlog";
            platforms = platforms.unix;
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/nerdlog";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.go
            pkgs.git
            pkgs.gnumake
            pkgs.gopls
          ] ++ nativeInputs ++ runtimeLibs;

          # Enable/disable clipboard support consistently in the shell
          CGO_ENABLED = if enableCgo then "1" else "0";
        };

        checks.build = self.packages.${system}.default;
        formatter = pkgs.alejandra;
      }
    );
}
