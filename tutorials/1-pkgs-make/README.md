- [Introduction to Pkgs-make](#org534b4ca)
- [Prerequisites](#org3965a99)
- [Following along with code](#org4e7f0d8)
- [Setting up a minimal build](#orgdf4d040)
  - [Referencing Pkgs-make](#org3ea4114)
  - [Calling Pkgs-make](#org900d315)
  - [Call-package calls](#org636dcf8)
    - [Example library code](#orgbf84b8c)
    - [Example application code](#org00ac8d2)
- [Alternative to hardcoding `/nix/store` references](#orge320a71)
- [Pinning Nixpkgs](#orgb98c2b7)
- [Overriding dependencies](#org4bd13bf)
  - [Overriding globally](#org1d21808)
  - [Overriding locally](#org659f3f3)
- [Curated overlays](#orgb9ff601)
- [Build Docker](#org80d0ef5)
  - [Nix-built Docker image](#orgbf1b761)
  - [Nix-built self-contained tarball](#orge9a79da)
- [License report (experimental)](#org8bd1124)
  - [Usage](#orgeef50e0)
  - [Caveats](#org7b8e769)



<a id="org534b4ca"></a>

# Introduction to Pkgs-make

[Pkgs-make](../../pkgs-make/README.md) is a library that can hopefully reduce some the boilerplate we might have to write when using Nix to manage a software lifecycle.

[Nix](https://nixos.org/nix) can do more than just build, package, and deploy software artifacts deterministically. For example, we can use Nix to set up developer environments. We obtain this flexibility in large part with Nix's expression language and the standard supporting library of the [Nixpkgs repository](https://github.com/NixOS/nixpkgs).

However, with all this flexibility, projects can easily end up with a sprawl of supporting Nix expressions. The moment we want to carry these features from one project to another, we have a strong motivation to factor the Nix expressions out into a library, ideally with nice ergonomics. This is how Pkgs-make came to be. It's not a lot of code, but it's enough to not want to copy-and-paste around.

If you have a C, Haskell, or Python project, this library should be usable as is. If you're using another language, it can likely be extended.


<a id="org3965a99"></a>

# Prerequisites

If you're new to Nix consider going through the [previous tutorial](../0-nix-intro/README.md) or reading the [Nix manual](https://nixos.org/nix/manual/#ch-expression-language).

Additionally, we're going to overview using Pkgs-make, but won't dive into every aspect. See the [documentation for Pkgs-make](../../pkgs-make/README.md) for more details.

And since you'll see not only calls to Pkgs-make, but also calls to Nixpkgs, you may want to have the [Nixpkgs manual](https://github.com/NixOS/nixpkgs) handy as well.


<a id="org4e7f0d8"></a>

# Following along with code

This tutorial introduces Pkgs-make using a small shell script program as an example. To illustrate a little complexity, the program is split into two packages, a library and an executable application.

The library package is just a single-file shell script defining a single function `do_with_header` that can be sourced in shell with the `.` (dot) operator. This function prints to the standard output the command to be run, and then runs it.

The application package runs this function to call the same open-source GNU Hello program we introduced in the [previous tutorial](../0-nix-intro/README.md).

Everything is tied together in [this tutorial's `build.nix` file](./build.nix). This file evaluates to an attribute set with a few derivations. One of the attributes is our final application, called `example-shell-app`. This application provides the shell script which is called `example-shell`:

```shell
nix build --no-link --file build.nix example-shell-app
tree "$(nix path-info --file build.nix example-shell-app)"
```

    /nix/store/l4rwsx6wmzp1218i2bpy21ilddd0qr03-example-shell
    └── bin
        └── example-shell
    
    1 directory, 1 file

Here's an invocation of it using `nix run`:

```shell
nix run --file build.nix example-shell-app --command example-shell
```

    
    
    *****
    ***** /nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/hello
    *****
    
    Hello, world!


<a id="orgdf4d040"></a>

# Setting up a minimal build

Stepping away from our example shell script application for a moment (we'll get back to it soon), here's a small example of a typical usage of Pkgs-make:

```nix
let
    pkgsMakePath =
	(import <nixpkgs> {}).fetchFromGitHub {
	    owner = "shajra";
	    repo = "example-nix";
	    rev = GIT_COMMIT_AS_STRING;
	    sha256 = HASH_AS_STRING;
	};
    pkgsMake = import pkgsMakePath;
    pkgsMakeArgs = {};  # empty set gives us defaults
in
pkgsMake pkgsMakeArgs ({call, ...}: {
    my-c-or-shell = call.package ./path/to/c/project;
    my-haskell-lib = call.haskell.lib ./path/to/haskell/package;
    my-haskell-app = call.haskell.app ./path/to/haskell/package;
    my-python = call.python ./path/to/python/package;
})
```

Let's discuss this expression piece by piece.


<a id="org3ea4114"></a>

## Referencing Pkgs-make

This repository's Pkgs-make library is on GitHub, and Nixpkgs has a `fetchFromGitHub` function that can help us retrieve it. But this means we need Nixpkgs to get Pkgs-make. As discussed in [the previous tutorial](../0-nix-intro/README.md), we can use `<nixpkgs>` to get from the `NIX_PATH` environment variable the path to a snapshot of Nixpkgs in `/nix/store`.

Any time we use the angle bracket syntax, we need to be extremely careful. We want our Nix expression to build the same artifact irrespective of what any user-level configuration or environment variables are set to. Which version of Nixpkgs we get with `<nixpkgs>` is out of the control of any Nix expression.

Fortunately, we can deal with this problem by only using the floating version of Nixpkgs to obtain a pinned version of our Pkgs-make library from GitHub.

When using `fetchFromGitHub` as shown example usage above, you'll just have to substitute in values for the `rev` and `sha256` attributes. The `rev` attribute is the long-form Git commit ID as a string to pin the version of this `example-nix` repository. The `sha256` attribute is a parity check as a string (in case GitHub is hacked or has a bug). You can get this hash with the following command:

```shell
nix-prefetch-url --unpack \
    "https://github.com/shajra/example-nix/archive/$REV.tar.gz"
```

Alternatively, if you use Git for your projects, you could include this repository as a [Git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules). Then Pkgs-make would be in a directory relative to your project, and your usage would look closer to what's used in this tutorial's [build.nix](./build.nix) file.

```text
pkgsMake = import ./path/to/pkgs-make;
```


<a id="org900d315"></a>

## Calling Pkgs-make

Pkgs-make, once imported, is a function to which we apply two arguments. We then are returned an attribute set with derivations to our project.

The first argument is configuration for Pkgs-make, passed in as an attribute set. Passing in an empty set (`{}`) results in default values being used.

The second argument passed to Pkgs-make is a function that builds an attribute set of your final derivations. Pkgs-make will pass to this function a set of utilities to use. As shown in our example usage above, one such utility is the `call` attribute, providing a nested set of functions for building derivations for different languages.


<a id="org636dcf8"></a>

## Call-package calls

If you look at the [`build.nix` file in this tutorial's directory](./build.nix), you'll see we pass a function to Pkgs-make similarly as our example usage above:

```text
pkgsMake pkgsMakeArgs ({call, lib}: rec {
    example-shell-lib = call.package ./library;
    example-shell-app = call.package ./application;
    …
})
```

We're only using one of these functions provided by `call.package` attribute. All of the functions available from `call` accept a path an argument. This path when imported should always accept an attribute set as input and return a derivation of a package. We'll look at an example of this function next.


<a id="orgbf84b8c"></a>

### Example library code

The [`default.nix` for our library](./library/default.nix) is as follows:

```nix
{ writeText, coreutils, gnused }:

writeText "example-shell-lib"
    ''
    do_with_header()
    {
	${coreutils}/bin/echo
	${coreutils}/bin/echo
	${coreutils}/bin/echo "***** $@" | ${gnused}/bin/sed 's/ /\n***** /g'
	${coreutils}/bin/echo "*****"
	${coreutils}/bin/echo
	"$@"
    }
    ''
```

Notice that this function takes in an attribute set that must have a `writeText`, `coreutils`, and `gnused` attribute.

The `call.package` function available via Pkgs-make is a variant of the standard function available at the top-level `callPackage` of Nixpkgs, which it ultimately delegates to. These functions use reflection to see which attributes are required by a function (in our case `writeText`, `coreutils`, and `gnused`), and then pass them in. This use of reflection is called [“call-package”-style](http://lethalman.blogspot.com/2014/09/nix-pill-13-callpackage-design-pattern.html). We didn't cover this in our prior Nix tutorial. Overuse of reflection can become anti-modular. So while we delegate to a few “call” functions that use the call-package style, many would advise against using it beyond that.

When reflecting, `call.package` (same as the standard `callPackage` function in Nixpkgs) will recognize attributes at the top-level of Nixpkgs. Both `coreutils` and `gnused` are derivations there:

```shell
nix search 'nixpkgs.(coreutils|gnused)$'
```

    Attribute name: nixpkgs.coreutils
    Package name: coreutils
    Version: 8.29
    Description: The basic file, shell and text manipulation utilities of the GNU operating system
    
    Attribute name: nixpkgs.gnused
    Package name: gnused
    Version: 4.5
    Description: GNU sed, a batch stream editor

The `writeText` attribute is not a derivation, but a function not found by `nix search`. There are a lot of functions at Nixpkgs' top-level. Some of these are documented in the [Nixpkgs manual](https://nixos.org/nixpkgs/manual). Others you discover by looking at other people's Nix expressions or by reading the Nixpkgs source code.

`writeText` produces a derivation for a single-file package given a name for the package, and the text content for the file. We use string interpolation to have the `/nix/store` paths of dependencies injected into the script.

Let's take a look at the built library file in `/nix/store`:

```shell
cat `nix path-info --file build.nix example-shell-lib`
```

    do_with_header()
    {
        /nix/store/n7qp8pffvcb5ff52l2nrc3g2wvxfrk75-coreutils-8.29/bin/echo
        /nix/store/n7qp8pffvcb5ff52l2nrc3g2wvxfrk75-coreutils-8.29/bin/echo
        /nix/store/n7qp8pffvcb5ff52l2nrc3g2wvxfrk75-coreutils-8.29/bin/echo "***** $@" | /nix/store/4qq502jmmwqrvr9y42m8kax686ppm6mh-gnused-4.5/bin/sed 's/ /\n***** /g'
        /nix/store/n7qp8pffvcb5ff52l2nrc3g2wvxfrk75-coreutils-8.29/bin/echo "*****"
        /nix/store/n7qp8pffvcb5ff52l2nrc3g2wvxfrk75-coreutils-8.29/bin/echo
        "$@"
    }

We can see that our string interpolation has hardcoded references to our dependencies. We'll discuss the importance of this more later.


<a id="org00ac8d2"></a>

### Example application code

Now let's look at the [`default.nix` for our application](./application/default.nix).

```nix
{ example-shell-lib
, hello
, writeShellScriptBin
}:

writeShellScriptBin "example-shell"
    ''
    . ${example-shell-lib}
    do_with_header ${hello}/bin/hello "$@"
    ''
```

This time, we see three inputs that are passed in via call-package reflection: `writeShellScriptBin`, `hello`, and `example-shell-lib`.

`hello` is a top-level derivation from Nixpkgs, so as before, we expect `call.package` to pass it in. But notice that the `example-shell-lib` passed in is our library, not a top-level package already in Nixpkgs. Every derivation built with an invocation of Pkgs-make can access one another to use as a build dependency. This is a convenience of using Pkgs-make over the `callPackage` function in Nixpkgs. Just don't create a dependency cycle otherwise the Nix build will fail.

`writeShellScriptBin` is very similar to the `writeText` function used in our library code. The major difference is that it turns the text into an executable shell script by turning on executable bits and prefixing the the text with a typical shell script header line:

```shell
cat "$(nix path-info \
    --file build.nix example-shell-app)/bin/example-shell"
```

    #!/nix/store/8zkg9ac4s4alzyf4a8kfrig1j73z66dw-bash-4.4-p23/bin/bash
    . /nix/store/i39wa8v79k231d49i7cs98k55k7rpjmg-example-shell-lib
    do_with_header /nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/hello "$@"

Again, you see that we've used string interpolation to inject `/nix/store` paths into our shell script. This is very important for a couple of reasons.

1.  We often want our application to work consistently, irrespective of what a user has installed on their system. Shell scripts in particular often rely on a variety of applications beyond a standard installation.

2.  In Nix explicit references to `/nix/store` is how Nix recognizes dependencies, which has implications for correct caching and garbage collection.

Because of our textual references, Nix recognizes all the following dependencies transitively:

```shell
nix path-info --recursive --file build.nix example-shell-app
```

    /nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10
    /nix/store/4qq502jmmwqrvr9y42m8kax686ppm6mh-gnused-4.5
    /nix/store/83lrbvbmxrgv7iz49mgd42yvhi473xp6-glibc-2.27
    /nix/store/8zkg9ac4s4alzyf4a8kfrig1j73z66dw-bash-4.4-p23
    /nix/store/93ljbaqhsipwamcn1acrv94jm6rjpcnd-acl-2.2.52
    /nix/store/i39wa8v79k231d49i7cs98k55k7rpjmg-example-shell-lib
    /nix/store/l4rwsx6wmzp1218i2bpy21ilddd0qr03-example-shell
    /nix/store/n7qp8pffvcb5ff52l2nrc3g2wvxfrk75-coreutils-8.29
    /nix/store/rmq6gnybmxxzpssj3s63sfjivlq4inrm-attr-2.4.47


<a id="orge320a71"></a>

# Alternative to hardcoding `/nix/store` references

Thus far, to make the derivations for both the `example-shell-lib` and `example-shell-app` attributes, we used string interpolation to hardcode a `/nix/store` reference for every dependency in our scripts.

Sometimes this is not as convenient to do. A program may call an executable that's expected to be on the `PATH`. For consistent operation, we might want to make sure that the executable we want is always found first.

This tutorial's `build.nix` file also contains two attributes `example-shell-app-unwrapped` and `example-shell-app-wrapped` that illustrate this problem and propose a solution:

```text
pkgsMake pkgsMakeArgs ({call, lib}: rec {
    example-shell-app-unwrapped = call.package ./application-unwrapped;
    example-shell-app-wrapped = call.package ./application-wrapped;
    …
})
```

If we look at the [`default.nix` for our unwrapped application](./application-unwrapped/default.nix), we'll see the exact same Nix expression except for one exception — we've called `hello` without an absolute path reference into `/nix/store`:

```nix
{ example-shell-lib
, writeShellScriptBin
}:

writeShellScriptBin "example-shell"
    ''
    . ${example-shell-lib}
    do_with_header hello "$@"
    ''
```

If we call it and we don't have Hello installed on our machine, we'll get an error:

```shell
nix run --file build.nix example-shell-app-unwrapped \
    --command example-shell 2>&1 || true
```

    
    
    *****
    ***** hello
    *****
    
    /nix/store/i39wa8v79k231d49i7cs98k55k7rpjmg-example-shell-lib: line 8: hello: command not found

The [`default.nix` for `example-shell-app-wrapped`](./application-wrapped/default.nix) shows a way to build a standard derivation using a `makeWrapper` utility from Nixpkgs:

```nix
{ stdenv
, example-shell-app-unwrapped
, hello
, makeWrapper
}:

stdenv.mkDerivation {

    name = "example-shell-app-unwrapped";

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
```

This utility makes a shell wrapper for any executable file that can do things like set environment variables. In our case our wrapper sets the `PATH` to include a `/nix/store` path where a specific version of Hello can can be found.

This is a common technique for many derivations in Nixpkgs. Furthermore, with techniques like this, we can use Nix to mix programs from all kinds of language ecosystems together.

We're glossing over the details in this `default.nix` file, like Nixpkg's `stdenv`, `mkDerivation`, and the attributes it expects like `src`, `nativeBuildInputs`, `builder`, and others not needed for this example. Hopefully you can still figure out what's going on from context. See the [Nixpkgs manual](https://nixos.org/nixpkgs/manual) for more details on making derivations from the standard environment `stdenv` with `makeWrapper`.

After wrapping, our application now works:

```shell
nix run --file build.nix example-shell-app-wrapped \
    --command example-shell
```

    
    
    *****
    ***** hello
    *****
    
    Hello, world!


<a id="orgb98c2b7"></a>

# Pinning Nixpkgs

Nixpkgs has a lot of code, all of which works towards building a ton of packages. It's important to recognize that Nixpkgs doesn't do any constraint solving of dependencies when building; if it did, it would no longer be deterministic. Instead, the versions of every package in Nixpkgs are explicit and community-curated. When you pin to a specific version of the Nixpkgs repository, you are also pinning to all the versions of every library in it.

When you pin to a specific version of Pkgs-make, it's defaults to pinning Nixpkgs. You can see which version of Nixpkgs Pkgs-make pins to in its [`config.nix`](../../pkgs-make/config.nix) file.

If you don't like this version of Nixpkgs, you can specify an overriding version as arguments to the Pkgs-make call:

```text
…
pkgsMakeArgs = {
    nixpkgsRev = YOUR_CUSTOM_REV;
    nixpkgsSha256 = SHA_FOR_CUSTOM_REV;
};
…
```

Getting the revision of Nixpkgs is simple. That's just the commit ID from Git for the project. To get the SHA-256 of the download, we could make a similar call to `nix-prefetch-url` as we made for pinning Pkgs-make earlier:

```shell
nix-prefetch-url --unpack \
    "https://github.com/nixos/nixpkgs/archive/$REV.tar.gz"
```

But typing that entire URL can get tedious. What many Nix users actually do is put in a dummy SHA-256 like a string of 52 zeros, and when they try to use the Nix expression, they get an error message like:

    …
    fixed-output derivation produced path '/nix/store/l3hldspr9a3nc9j9js7m4fhxv4s9yy38-source'
    with sha256 hash '1grsq8mcpl88v6kz8dp0vsybr0wzfg4pvhamj42dpd3vgr93l2ib'
    instead of the expected hash '0000000000000000000000000000000000000000000000000000'
    error: build of '/nix/store/0fcrg6z221afkpdpp33av2xcg2cina3n-source.drv' failed

Nix's error message tells us the calculated hash of the download which is the same as what we'd get with the `nix-prefetch-url` call. We can use it if we trust the GitHub and Nixpkgs. It may seem silly to intentionally create an error to figure out what you need, but it's undeniably convenient and used broadly within the Nix community.


<a id="org4bd13bf"></a>

# Overriding dependencies

Continuing with our shell application for dicussion, notice that when run it indicates we're running version 2.10 of GNU Hello:

```shell
nix run --file build.nix example-shell-app --command example-shell
```

    
    
    *****
    ***** /nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/hello
    *****
    
    Hello, world!

We may want another version, say 2.9. We have the option of changing the version of Hello locally for just `example-shell-app`, or we can globally change all references in Nixpkgs to Hello to a new version consistently. In other package managers, we can often only have one version of a library or application installed at a time. With Nix, we get more flexibility.


<a id="org1d21808"></a>

## Overriding globally

Changing a version for a package globally can sometimes make reasoning about consistency and compatibility easier. For instance, if a library is used for marshalling data, it's good to know that various packages are using the same protocol for communication with one another.

The packages we define with Pkgs-make have precedence, and by name will override everything in Nixpkgs. This tutorial's [`build.override_global.nix`](./build.override_global.nix) file shows how we can use this to conveniently specify a global override of the Hello package:

```nix
let
    pkgsMake = import ../../pkgs-make;
    pkgsMakeArgs = {};
in

pkgsMake pkgsMakeArgs ({call, ...}: {

    example-shell-lib = call.package ./library;

    example-shell-app = call.package ./application;

    hello = call.package ({stdenv, fetchurl}:
	stdenv.mkDerivation rec {
	    name = "hello-2.9";
	    src = fetchurl {
		url = "mirror://gnu/hello/${name}.tar.gz";
		sha256 = "19qy37gkasc4csb1d3bdiz9snn8mir2p3aj0jgzmfv0r2hi7mfzc";
	    };
	}
    );

})
```

Again, we use the standard `stdenv.mkDerivation` as well as `fetchurl` functions from Nixpkgs. The details of using these functions is beyond the scope of this tutorial, but you can see how simple it can be to package the typical open source C program in Nix. All you need is a name for Nix and to specify how to get the source code.

When we run `example-shell` from this new Nix build file, we can see that our downgrade of Hello from 2.10 to 2.9 is in play:

```shell
nix run --file build.override_global.nix example-shell-app \
    --command example-shell
```

    
    
    *****
    ***** /nix/store/mazn0n34dmngj3hiwwz0vgyfvm075flf-hello-2.9/bin/hello
    *****
    
    Hello, world!


<a id="org659f3f3"></a>

## Overriding locally

Sometimes we need to make a change locally to one package, without affecting other packages that have otherwise been community-vetted.

To do this, we just bypass the packages being provided via the call-package pattern. We have an example of this with [`build.override_local.nix`](./build.override_local.nix):

```nix
let
    pkgsMake = import ../../pkgs-make;
    pkgsMakeArgs = {};
in

pkgsMake pkgsMakeArgs ({call, ...}: {
    example-shell-lib = call.package ./library;
    example-shell-app = call.package ./application-overriding;
})
```

This Nix build file instead of delegating to `./application` as before, delegates to [`./application-overriding`](./application-overriding/default.nix), which has the following `default.nix` file:

```nix
{ example-shell-lib
, fetchurl
, writeShellScriptBin
, stdenv
}:

let

    hello = stdenv.mkDerivation rec {
	name = "hello-2.9";
	src = fetchurl {
	    url = "mirror://gnu/hello/${name}.tar.gz";
	    sha256 = "19qy37gkasc4csb1d3bdiz9snn8mir2p3aj0jgzmfv0r2hi7mfzc";
	};
    };

in

writeShellScriptBin "example-shell"
    ''
    . ${example-shell-lib}
    do_with_header ${hello}/bin/hello "$@"
    ''
```

We make the derivation for the 2.9 version of Hello with `stdenv.mkDerivation` as before, but this time locally with a let-binding.

Now, when we run `example-shell` from this build file, we can see that our downgrade of Hello from 2.10 to 2.9 is in play:

```shell
nix run --file build.override_local.nix example-shell-app \
    --command example-shell
```

    
    
    *****
    ***** /nix/store/mazn0n34dmngj3hiwwz0vgyfvm075flf-hello-2.9/bin/hello
    *****
    
    Hello, world!

But if any other application in Nixpkgs depended on Hello, it would pull in the later 2.10 version.


<a id="orgb9ff601"></a>

# Curated overlays

Sometimes changes haven't gotten into Nixpkgs. As an experiment, the Pkgs-make contributors curate a set of overrides for Nixpkgs. In particular, many of these overrides help keep some machine learning libraries more up-to-date.

As a result Pkgs-make has two variants:

-   plain (no overrides)
-   curated (with overrides)

By default, you get the curated variant. But you can import `variant/plain` if you don't prefer these overrides:

```text
…
pkgsMake = import "${pkgsMakePath}/variant/plain";
…
```

Please note, we don't have a lot of people managing this curation. Also, it would be even better if the work from curation within Pkgs-make could work back into Nixpkgs. Any help is much appreciated.


<a id="org80d0ef5"></a>

# Build Docker

You may find that with all the tools and features the Nix ecosystem offers that a tool like [Docker](https://www.docker.com) is unnecessary. Still, Docker has gained a lot of popularity for the production deployment of applications.

There are two attributes in the [`build.nix` file for this tutorial](./build.nix) that illustrate different ways of integrating our application into a Docker container, `example-shell-docker`, and `example-shell-tarball`:

-   **`example-shell-docker`:** a derivation that builds a Docker image we can bring into a Docker installation with the `docker load` command.

-   **`example-shell-tarball`:** a derivation that builds a self-contained tarball that can be used with an externally managed `Dockerfile`.


<a id="orgbf1b761"></a>

## Nix-built Docker image

We can build Docker images with Nix without requiring an installation of Docker. Here's the Nix expression from our `build.nix` file:

```text
example-shell-docker = lib.nix.dockerTools.buildImage {
    name = "example-shell";
    contents = example-shell-app;
    config = {
	Entrypoint = [ "/bin/example-shell" ];
    };
};
```

Just as Pkgs-make passes us a `call` attribute, we are also passed in a `lib` attribute that has some useful utilities for building Nix expressions. `lib.nix` is the standard `lib` of Nixpkgs, but extended with a few more functions by Pkgs-make. The `lib.nix.dockerTools.buildImage` attribute is the same function as in Nixpkgs. You can learn more about this function and others available in the [`dockerTools` section of the Nixpkgs manual](https://nixos.org/nixpkgs/manual/#sec-pkgs-dockerTools).

Note that our Nix expression specifies a Docker image name of “example-shell” and also all the information that would normally be in a separate `Dockerfile` (like the entry point). This builds an self-contained archive file that we can copy to any computer that has Docker installed and load with a `docker load` invocation:

```shell
nix build --no-link --file build.nix example-shell-docker
docker load --input \
    "$(nix path-info --file build.nix example-shell-docker)"
```

    Loaded image: example-shell:latest

At this point, we can run the loaded Docker image without concern that Nix was used to build the image:

```shell
docker run --rm -i example-shell
```

    
    
    *****
    ***** /nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/hello
    *****
    
    Hello, world!


<a id="orge9a79da"></a>

## Nix-built self-contained tarball

Pkgs-make provides a function to create a self-contained tarball on the `lib.nix.tarball` attribute:

```text
example-shell-tarball =
    lib.nix.tarball example-shell-app "example-shell.tar";
```

This tarball is self-contained and includes all the `/nix/store` files necessary to run the application. As a convenience, some symlinks are also included with pointers to top-level folders for our application:

```shell
nix build --no-link --file build.nix example-shell-tarball
tar --list --verbose \
	--file "$(nix path-info --file build.nix example-shell-tarball)" \
    | awk '{print $6, $7, $8}'
```

    nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/
    nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/
    nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/hello
    nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/share/
    nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/share/locale/
    …
    nix/store/rmq6gnybmxxzpssj3s63sfjivlq4inrm-attr-2.4.47/share/locale/pl/LC_MESSAGES/attr.mo
    nix/store/rmq6gnybmxxzpssj3s63sfjivlq4inrm-attr-2.4.47/share/locale/fr/
    nix/store/rmq6gnybmxxzpssj3s63sfjivlq4inrm-attr-2.4.47/share/locale/fr/LC_MESSAGES/
    nix/store/rmq6gnybmxxzpssj3s63sfjivlq4inrm-attr-2.4.47/share/locale/fr/LC_MESSAGES/attr.mo
    bin -> /nix/store/l4rwsx6wmzp1218i2bpy21ilddd0qr03-example-shell/bin

Because Nix-built artifacts have hardcoded references to `/nix/store`, this tarball must be unpacked to a root filesystem. We'll show next how to use it to build out the root filesystem of a Docker image, but this tarball may be useful with other utilities like the Unix `chroot` command.

Here's the [Dockerfile](./Dockerfile) we'll use to unpack our tarball into an image:

```dockerfile
FROM scratch
ADD example-shell.tar /
ENTRYPOINT ["/bin/example-shell"]
```

Note that it's base layer is the `scratch` Dockerfile image, which is completely empty. We're really not using the Dockerfile for anything other than unpacking our tarball. In other applications, we may also set up environment variables or expose ports, but the files within the image have been entirely constructed by Nix.

We can now build our Docker image the standard Docker way:

```shell
cp "$(nix path-info --file build.nix example-shell-tarball)" example-shell.tar
docker build --tag example-shell-tarball .
```

    Sending build context to Docker daemon  38.85MB
    Step 1/3 : FROM scratch
     --->
    Step 2/3 : ADD example-shell.tar /
     ---> 86b65d3cc9e3
    Step 3/3 : ENTRYPOINT ["/bin/example-shell"]
     ---> Running in 36319311fb71
    Removing intermediate container 36319311fb71
     ---> 9a6da58d7c58
    Successfully built 9a6da58d7c58
    Successfully tagged example-shell-tarball:latest

And our Docker image runs as we'd expect:

```shell
docker run --rm -i example-shell-tarball
```

    
    
    *****
    ***** /nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10/bin/hello
    *****
    
    Hello, world!


<a id="org8bd1124"></a>

# License report (experimental)


<a id="orgeef50e0"></a>

## Usage

Figuring out whether an application is properly licensed requires going through all the licenses of all the dependencies used.

Unfortunately, Nix doesn't offer a complete solution for this, but Pkgs-make can help a little.

The `example-shell-licenses` attribute of the Nix expression in [`build.nix` file](./build.nix) has an expression that generates a JSON file with license information for many of the dependencies required:

```text
example-shell-licenses = lib.nix.license-report.json {
    inherit example-shell-app;
};
```

We can use a tool like `jq` to nicely render it.

```shell
nix build --no-link --file build.nix example-shell-licenses
jq . < "$(nix path-info --file build.nix "example-shell-licenses")"
```

    {
      "example-shell-app": [
        {
          "homepage": "http://www.gnu.org/software/hello/manual/",
          "license": {
            "fullName": "GNU General Public License v3.0 or later",
            "shortName": "gpl3Plus",
            "spdxId": "GPL-3.0+",
            "url": "http://spdx.org/licenses/GPL-3.0+.html"
          },
          "path": "/nix/store/188avy0j39h7iiw3y7fazgh7wk43diz1-hello-2.10"
        },
    …
        {
          "path": "/nix/store/rmq6gnybmxxzpssj3s63sfjivlq4inrm-attr-2.4.47"
        }
      ]
    }


<a id="org7b8e769"></a>

## Caveats

There are important caveats to understand about this generated report:

-   runtime dependencies only, not compile-time
-   no mention of statically compiled libraries
-   some dependencies have missing license information
-   accuracy only as good as metadata in Nixpkgs.

This license report is currently limited to runtime dependencies (which is the common case for most inquiries). Pkgs-make finds runtime dependencies by recursively chasing hardcoded references to `/nix/store`. This doesn't tell us anything about compile-time dependencies. Furthermore, compile-time dependencies explode to a much larger set, and offer more challenges due to how some Nix expressions use string-interpolation.

Also, when a library is statically compiled, Nix loses track of the dependency (no reference back into `/nix/store`). To get a more accurate license report, create it from a dynamically-compiled variant instead.

Additionally, you may notice a project listed as a dependency with no license information. This is a limitation of current state of the art in Nix. `/nix/store` doesn't contain license information. To match the detected dependencies with license information, Pkgs-make does a heuristic crawl through Nixpkgs tree, starting with the derivation for our built artifact. Sometimes we don't find what we want.

Finally, the accuracy of the report is only as good as the information in Nixpkgs. For instance, gmp is currently listed as GPL-licensed, when it's actually dual-licensed with both GPL and LGPL.

Hopefully this report is still useful, provided you understand the caveats.