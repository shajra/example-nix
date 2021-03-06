{ hello
, example-shell-app-unwrapped
, stdenv
, makeWrapper
}:

stdenv.mkDerivation {

    name = "example-shell-app-wrapped";

    nativeBuildInputs = [ makeWrapper ];

    app = example-shell-app-unwrapped;
    inherit hello;

    builder = builtins.toFile "builder.sh" ''
        source $stdenv/setup
        mkdir -p "$out/bin"
        ln -s "$app/bin/example-shell" \
            "$out/bin"
        wrapProgram "$out/bin/example-shell" \
            --prefix PATH : "$hello/bin"
    '';

}