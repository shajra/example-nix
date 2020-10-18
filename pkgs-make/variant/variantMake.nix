defaults:

{ nixpkgsRev ? defaults.base.nixpkgsRev
, nixpkgsSha256 ? defaults.base.nixpkgsSha256
, bootPkgsPath ? defaults.base.bootPkgsPath
, bootPkgs ? defaults.base.bootPkgs
, basePkgsPath ? defaults.base.basePkgsPath
, nixpkgsArgs ? defaults.base.nixpkgsArgs
, srcFilter ? defaults.base.srcFilter
, extraSrcFilter ? defaults.base.extraSrcFilter
, srcTransform ? defaults.base.srcTransform
, overlay ? defaults.base.overlay
, extraOverlay ? defaults.base.extraOverlay
, haskellArgs ? defaults.base.haskellArgs
, pythonArgs ? defaults.base.pythonArgs
}:

generator:

let

    chosenBootPkgs =
        if isNull bootPkgs
        then import bootPkgsPath {}
        else bootPkgs;

    nixpkgsPath =
        if isNull basePkgsPath
        then
            chosenBootPkgs.fetchFromGitHub {
                owner = "NixOS";
                repo = "nixpkgs";
                rev = nixpkgsRev;
                sha256 = nixpkgsSha256;
            }
        else basePkgsPath;

    nixpkgs = import nixpkgsPath (nixpkgsArgs // { inherit overlays; });

    overlays =
        (nixpkgsArgs.overlays or []) ++ [ overlay extraOverlay morePkgs ];

    morePkgs = self: super:
        let
            commonArgs = { nixpkgs = self; inherit pkgs; };
            hs = import ../haskell defaults.haskell (haskellArgs // commonArgs);
            py = import ../python defaults.python (pythonArgs // commonArgs);
            lib = import ../lib super;
            filterSource = lib.nix.sources.filterSource
                (lib.nix.sources.allFilters [
                    (extraSrcFilter lib)
                    (srcFilter lib)
                ]);
            cleanSource = lib.nix.sources.transformSourceIfLocal
                (lib.nix.composed [ (srcTransform lib) filterSource ]);
            cleanSourceOverride = attrs:
                if attrs ? src
                then { src = cleanSource attrs.src; }
                else {};
            callPackage = p:
                let
                    expr = if builtins.typeOf p == "path" then import p else p;
                    pkg = super.callPackage expr {};
                in
                    if pkg ? overrideAttrs
                    then pkg.overrideAttrs cleanSourceOverride
                    else pkg;
        in
            {
                lib = lib.nix;
                haskell = super.haskell // { lib = lib.haskell; };
                pkgsMake = {
                    inherit lib;
                    haskellPackages = hs.haskellPackages;
                    pythonPackages = py.pythonPackages;
                    pkgsChange = hs.pkgsChange;
                    call = {
                        package = callPackage;
                        haskell = hs.call // {
                            hackage = hs.haskellPackages.callHackage;
                        };
                        python = py.callPython;
                    };
                    env = { haskell = hs.env; python = py.env; };
                };
            } // pkgs;

    args = {
        lib = nixpkgs.pkgsMake.lib;
        call = nixpkgs.pkgsMake.call;
    };

    pkgs = generator args;

in

(nixpkgs.pkgsMake.pkgsChange pkgs) // {
    inherit nixpkgs;
    env = nixpkgs.pkgsMake.env;
}
