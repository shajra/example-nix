- [About Pkgs-make](#org2442b69)
- [Importing](#orgfc7cc42)
- [Specification of Functions and Types](#org3f23552)
  - [Notation and `PkgsMake`](#orgd01ba07)
  - [`PkgsMakeArgs`](#orgb0006db)
    - [Getting a base Nixpkgs](#org5385f59)
    - [Overlaying Nixpkgs](#org460505c)
    - [Default source filtering:](#orga0c031a)
    - [Language-specific configuration](#orgbe07b69)
  - [`Builder` function](#orgb20a6a2)
    - [PkgsMakeLib](#org1b2dce3)
    - [PkgsMakeCall](#org1848660)
    - [Returned derivations](#org9673024)
  - [Returned `Build`](#org845c4e6)
  - [Nix-shell environments](#org80300c0)
  - [Haskell-specific configuration](#org6bcdb1e)
  - [Python-specific configuration](#org940fc36)
- [Navigating the Code](#org38d42c5)



<a id="org2442b69"></a>

# About Pkgs-make

Pkgs-make is a library that factors away boilerplate we often end up when writing Nix expressions based solely on [Nixpkgs](https://github.com/NixOS/nixpkgs).

If you have a C, Haskell, or Python project, this library should be usable as is. If you're using another language, it can likely be extended.

One of the accompanying tutorials provides [an overview of using Pkgs-make](../tutorials/1-pkgs-make/README.md). Additionally, as a [Haskell tutorial](../tutorials/2-haskell/README.md) and [Python tutorial](../tutorials/2-python/README.md) both showcase language-specific usage.

This document specifies Pkgs-make in more rigor and completeness.


<a id="orgfc7cc42"></a>

# Importing

Pkgs-make is just a Nix library, similar to Nixpkgs, so once we fetch the repository we just need to import it from a Nix expression. Please see the tutorials if you don't know how to do that.

There's a few paths we can import in this repository:

| Path                          | Variant |
|----------------------------- |------- |
| `example-nix`                 | plain   |
| `example-nix/pkg-make`        | plain   |
| `example-nix/variant/curated` | curated |
| `example-nix/variant/plain`   | plain   |

Sometimes changes haven't gotten into Nixpkgs. As an experiment, the Pkgs-make contributors curate a set of overrides for Nixpkgs. In particular, many of these overrides help keep some machine learning libraries more up-to-date.

As a result Pkgs-make has two variants:

-   plain (no overrides)
-   curated (with overrides)

By default, you get the plain variant. But you can import `variant/curated` if you'd like to try out these overrides:

```text
…
pkgsMake = import "${pkgsMakePath}/variant/plain";
…
```

Please note, we don't have a lot of people managing this curation. Also, it would be even better if the work from curation within Pkgs-make could work back into Nixpkgs. Any help is much appreciated.


<a id="org3f23552"></a>

# Specification of Functions and Types


<a id="orgd01ba07"></a>

## Notation and `PkgsMake`

Since Nix doesn't have an official type notation, for this discussion we'll assume the following:

| Type Notation | Description                                           |
|------------- |----------------------------------------------------- |
| `Nixpkgs`     | an imported nixpkgs (e.g. from `import <nixpkgs> {}`) |
| `Drv`         | a Nix derivation                                      |
| `Bool`        | a boolean                                             |
| `String`      | a string                                              |
| `Path`        | a path                                                |
| `Path<v>`     | a path that when imported yields a value of type `v`  |
| `[e]`         | a list with elements of type `e`                      |
| `Set<v>`      | an attribute set with values of type `v`              |
| `Function`    | a function with arbitrary input and output types      |
| `i -> o`      | a function inputting type `i`, returning type `o`     |
| a + b         | a value either of type `a` or of type `b`             |

Pkgs-make is a higher-order function with the following types:

```
PkgsMake = PkgsMakeArgs -> Builder -> Build
Builder = BuildArgs -> Set<Drv>
```

Here `PkgsMakeArgs`, `BuildArgs`, and `Build` are all attribute sets (some nested).

In the following sections, we'll specify each of these types in greater detail.


<a id="orgb0006db"></a>

## `PkgsMakeArgs`

`PkgsMakeArgs` are the top-level configuration of a Pkgs-make call. No configuration is mandatory, and an empty set can be passed to Pkgs-make as the `PkgsMakeArgs` for defaults that should address common cases. You can see those defaults in the [`config.nix`](./config.nix) file

Here's some details its attributes:

| `PkgsMakeArgs` Attribute | Type           | Description                              |
|------------------------ |-------------- |---------------------------------------- |
| `nixpkgsRev`             | `String`       | commit ID of base `Nixpkgs`              |
| `nixpkgsSha256`          | `String`       | hash parity check for `nixpkgsRev`       |
| `nixpkgsArgs`            | `NixpkgsArgs`  | standard arguments for `Nixpkgs`         |
| `bootPkgsPath`           | `Path`         | path of explicitly set boot `Nixpkgs`    |
| `bootPkgs`               | `Nixpkgs`      | `Nixpkgs` to use to fetch base `Nixpkgs` |
| `basePkgsPath`           | `Path`         | path of explicitly set base `Nixpkgs`    |
| `overlay`                | `Overlay`      | overlay for `Nixpkgs` replacing defaults |
| `extraOverlay`           | `Overlay`      | overlay for `Nixpkgs` extending defaults |
| `srcFilter`              | `SrcFilter`    | source filter replacing defaults         |
| `extraSrcFilter`         | `SrcFilter`    | source filter extending defaults         |
| `srcTransform`           | `SrcTransform` | source-to-source transformation          |
| `haskellArgs`            | `HaskellArgs`  | Haskell-specific arguments               |
| `pythonArgs`             | `PythonArgs`   | Python-specific arguments                |


<a id="org5385f59"></a>

### Getting a base Nixpkgs

Many of `PkgsMakeArgs`'s attributes involve the retrieval and configuration of a base `Nixpkgs`. By default the dynamic `<nixpkgs>` path is used as the boot `Nixpkgs` only to fetch the real `Nixpkgs` used as a base (pinned to `nixpkgsRev`). If you prefer not to boot with the dynamic `<nixpkgs>`, you can supply a `bootPkgsPath` to import instead, or a pre-imported/configured `bootPkgs`. Or if you already have your base `Nixpkgs` pulled, you can provide its path as `basePkgsPath` for importing. We anticipate most people will just set `nixpkgsRev` and `nixpkgsSha256` and let Pkgs-make do the rest, trusting that the single fetch call we do with `<nixpkgs>` is benign.


<a id="org460505c"></a>

### Overlaying Nixpkgs

The `overlay` and `extraOverlay` attributes have a type of `Overlay`, which is the standard “overlay” in `Nixpkgs`:

```
Overlay = NixpkgsSelf -> NixpkgsSuper -> Set<Drv>=
NixpkgsSelf = Nixpkgs
NixpkgsSuper = Nixpkgs
```

These types for an `Overlay` have the following values:

| `Overlay` Parameter | Type           | Value                                      |
|------------------- |-------------- |------------------------------------------ |
| 1                   | `NixpkgsSelf`  | final `Nixpkgs` after all overlays applied |
| 2                   | `NixpkgsSuper` | `Nixpkgs` before overlay are applied       |
| return              | `Set<Drv>`     | overlaid packages.                         |


<a id="orga0c031a"></a>

### Default source filtering:

Source files used to build derivations are by default filtered by Pkgs-make. This way, things like temporary/intermediate files left behind by editors and other tools don't invalidate Nix's caching and trigger a new build.

You can modify this filtering with three attributes: `srcFilter, ~extraSrcFilter`, and `srcTransform`. These attributes have values of types `SrcFilter` and `SrcTransform`.

`SrcFilter` is a similar to the standard Nix source filter predicate but with a extra leading `PkgsMakeLib` parameter:

```
SrcFilter = PkgsMakeLib -> PathStr -> TypeStr -> Bool
PathStr = String
TypeStr = String
```

These types for a `SrcFilter` have the following values:

| `SrcFilter` Parameter | Type          | Value                                             |
|--------------------- |------------- |------------------------------------------------- |
| 1                     | `PkgsMakeLib` | a library of useful Nix functions                 |
| 2                     | `PathStr`     | path to the file to be filtered                   |
| 3                     | `TypeStr`     | result of calling `builtins.typeOf` on the path   |
| result                | `Bool`        | `false` to discard file/directory, `true` to keep |

`SrcTransform` is a function to modify standard Nix sources:

```
SrcTransform = Src -> Src
```

Here `Src` is a standard source type for Nix's derivation building. Often it's just a `Path`, but after filtering, it might be a more complicated attribute set that Nix can interpret as a filtered set of files.

Nixpkgs offers a some functions for filtering under [`lib.sources`](https://github.com/NixOS/nixpkgs/blob/master/lib/sources.nix). The `lib.sources.cleanSource` is an instance of the `SrcTransform` type, and `lib.sources.cleanSourceFilter` is an instance of the `SrcFilter` type. Pkgs-make provides more of these functions on the `lib` attribute of the `BuildArgs` set discussed later.


<a id="orgbe07b69"></a>

### Language-specific configuration

The language-specific `HaskellArgs` and `PythonArgs` are described more later, but their common attributes include the following:

| Language-specific Attribute | Type               | Description                        |
|--------------------------- |------------------ |---------------------------------- |
| `overrides`                 | `Override`         | overrides replacing defaults       |
| `extraOverrides`            | `Override`         | overrides extending defaults       |
| `srcFilter`                 | `SrcFilter`        | source filter replacing defaults   |
| `extraSrcFilter`            | `SrcFilter`        | source filter extending defaults   |
| `srcTransform`              | `SrcTransform`     | source-to-source transformation    |
| `envMoreTools`              | `Nixpkgs -> [Drv]` | extra env tools replacing defaults |

`Override` is has the following type:

```
Override = Nixpkgs -> PkgsSelf -> PkgsSuper -> Set<Drv + Function>
PkgsSelf = Set<Drv + Function>
PkgsSuper = Set<Drv + Function>
```

These types for an `Override` have the following values:

| `Override` Parameter | Type                  | Value                                      |
|-------------------- |--------------------- |------------------------------------------ |
| 1                    | `Nixpkgs`             | pinned `Nixpkgs` with all overlays applied |
| 2                    | `PkgsSelf`            | language-specific builds before overriding |
| 3                    | `PkgsSuper`           | language-specific builds after overriding  |
| return               | `Set<Drv + Function>` | overrides by name                          |

Note that `PkgsSelf` and `PkgsSuper` are platform-specific packages (like Nixpkgs's `haskellPackages` for Haskell or `pythonPackages` for Python), not top-level Nixpkgs packages.


<a id="orgb20a6a2"></a>

## `Builder` function

Pkgs-make will pass to a `Builder` function an input of type `BuildArgs`, which has the following attributes:

| `Builder` Attribute | Type         | Description                                    |
|------------------- |------------ |---------------------------------------------- |
| `lib`               | PkgsMakeLib  | various utilities in nested sets               |
| `call`              | PkgsMakeCall | various call-package functions (`Path -> Drv`) |


<a id="org1b2dce3"></a>

### PkgsMakeLib

The `lib` attribute of `BuildArgs` provides utilities that are largely the same utilities provided by Nixpkgs, but with some extension:

| `BuildArgs` Attribute | Type            | Description                                                  |
|--------------------- |--------------- |------------------------------------------------------------ |
| `nix`                 | `Set<Function>` | Nixpkgs' `lib` with [some extras](./lib/default.nix)         |
| `haskell`             | `Set<Function>` | Nixpkgs' `haskell.lib` with [some extras](./lib/haskell.nix) |


<a id="org1848660"></a>

### PkgsMakeCall

The `call` attribute provides *call-package* styled functions. These types of functions are commonly used in Nixpkgs, and are often called “callPackage” in code. The call-package style uses reflection to call functions with less boilerplate and is described in more detail in our [Pkgs-make tutorial](../tutorials/1-pkgs-make/README.md), and also in [one of the Nix Pills](http://lethalman.blogspot.com/2014/09/nix-pill-13-callpackage-design-pattern.html).

In summary, call-package functions call functions that take a destructured attribute set as an argument, and reflects over the attributes expected. The call-package function then chooses a value to pass in based upon the attribute name.

Four call-package functions are provided on the `call` attribute:

| Attribute               | Type              | Description                                 |
|----------------------- |----------------- |------------------------------------------- |
| `package`               | `PkgsMakeCallPkg` | standard call-package                       |
| `haskell.app`           | `PkgsMakeCallPkg` | call-package for Haskell executables        |
| `haskell.lib`           | `PkgsMakeCallPkg` | call-package for Haskell libraries          |
| `haskell.cabal2nix.app` | `PkgsMakeCallPkg` | same as `haskell.app`, but forces cabal2nix |
| `haskell.cabal2nix.lib` | `PkgsMakeCallPkg` | same as `haskell.lib`, but forces cabal2nix |
| `python`                | `PkgsMakeCallPkg` | call-package for Python packages            |

All of the call-package functions have a similar type:

```
PkgsMakeCallPkg = Path<Set -> Drv> + (Set -> Drv)
```

The call-package function takes a set as an input and returns a derivation. Or alternatively, the call-package function can take a path that returns this function when imported.

These call-package functions accept sets similar to the following call-package functions in Nixpkgs (which are delegated to ultimately). Additionally, these sets can include derivations being returned by the `Builder` function passed to Pkgs-make. This allows us to conveniently weave together code we're developing with other packages coming from Nixpkgs.

| `call` Attribute        | Expects `Set -> Drv` Similar To         |
|----------------------- |--------------------------------------- |
| `package`               | Nixpkgs's `callPackage`                 |
| `haskell.app`           | Nixpkgs's `haskellPackages.callPackage` |
| `haskell.lib`           | Nixpkgs's `haskellPackages.callPackage` |
| `haskell.cabal2nix.app` | Nixpkgs's `haskellPackages.callPackage` |
| `haskell.cabal2nix.lib` | Nixpkgs's `haskellPackages.callPackage` |
| `python`                | Nixpkgs's `pythonPackages.callPackage`  |

For the Haskell API, we have two call-package functions, `call.haskell.lib` and `call.haskell.app`, which are the same with the exception of the latter calling `lib.haskell.justStaticExecutables` on the derivation.

Also, the Haskell API is slightly different in that if you don't have a `default.nix` in the path you supply, one will be automatically generated from the Cabal file found in the path using the tool [`cabal2nix`](https://github.com/NixOS/cabal2nix). If you have a `default.nix` in your path, but don't want the call-package call too use it, you can use `haskell.cabal2nix.app` or `haskell.cabal2nix.lib` instead to force the call to `cabal2nix`.


<a id="org9673024"></a>

### Returned derivations

Using the library functions on the `lib` attribute and the call-package functions on the `call` attribute we can return a `Set<Drv>`.

As mentioned, all of the call-package functions will pull derivations from this set by name in addition to the normal packages they'd pull from in Nixpkgs.

With the normal “callPackage” functions in Nixpkgs, we'd have to set up some boilerplate of overlays and overrides. Pkgs-make does this for us. Additionally, Pkgs-make has a few defaults like source filtering that remove boilerplate we'd end up with on every project (we almost always want to filter away the “result” symlinks a Nix build can leave behind).


<a id="org845c4e6"></a>

## Returned `Build`

What Pkgs-make returns you is largely the same `Set<Drv>` you define, but augmented with a few extra attributes:

| `Build` Attribute | Type      | Description                         |
|----------------- |--------- |----------------------------------- |
| `env.haskell`     | `Drv`     | for `nix-shell` Haskell development |
| `env.python`      | `Drv`     | for `nix-shell` Python development  |
| `nixpkgs`         | `Nixpkgs` | final fully overlaid `Nixpkgs`      |

From this returned set, you can select out the packages you want by attribute for packaging and distribution.


<a id="org80300c0"></a>

## Nix-shell environments

The “env.\*” attributes in the returned `Build` set have derivations for use with `nix-shell`. `env.haskell` unifies all the dependencies of Haskell packages in your build, excluding packages you're developing locally. Similarly, `env.python` does the same for Python packages. This allows us to get multi-package project support from Nix.

Also, both `env.haskell` and `env.python` derivations have an added attribute `withEnvTools` of type `Nixpkgs -> [Drv]` for including additional development tools beyond what's pulled in by dependencies.

Note that the Haskell and Python environments already include some common development tools by default. You can see [`config.nix`](./config.nix) to see what's included.


<a id="org6bcdb1e"></a>

## Haskell-specific configuration

`lib.haskell` on the `PkgsMakeLib` instance has many functions from Nixpkgs's `haskell.lib` attribute that yield a changed derivation. One example of this is `lib.haskell.dontCheck`, which disables running tests when building.

`HaskellArgs` includes one more attribute:

| `HaskellArgs` Attribute | Type                             | Description                                   |
|----------------------- |-------------------------------- |--------------------------------------------- |
| `ghcVersion`            | `String`                         | which compiler to use (of the form “ghc822”)  |
| `pkgChanges`            | `PkgsMakeLib -> Set<Drv -> Drv>` | changes for packages by name                  |
| `changePkgs`            | `Set<[String]>`                  | names of packages to apply changes to by name |

`ghcVersion` chooses the version of GHC we're building with by the attribute name convention in Nixpkgs.

`pkgChanges` is a function that maps the names of packages to modify to functions built from those in `PkgsMakeLib` that are of the type `Drv -> Drv`.

`changePkgs` is a less expressive, but possibly more concise API that inverts what do with `pkgsChanges`. Here the attribute names of the `changePkgs` set are the names of functions from `lib.haskell` that must already be of the type `Drv -> Drv`. These function names are mapped to the names of packages to be modified.

For both `pkgChanges` and `changePkgs`, the packages modified can either come from the third-party Haskell libraries already in Nixpkgs, or they can be the packages we're currently building with the Pkgs-make call.


<a id="org940fc36"></a>

## Python-specific configuration

`PythonArgs` includes two more attribute:

| Attribute     | Type      | Description                                     |
|------------- |--------- |----------------------------------------------- |
| `pyVersion`   | `String`  | which interpretter to use (of the form “36”)    |
| `envPersists` | `Boolean` | whether to keep “editable” install files around |

`pyVersion` chooses the version of Python by the attribute name convention in Nixpkgs.

The returned `env.python` derivation, designed for use with `nix-shell` has a Nixpkgs “shellHook” that senses local Python projects built by Pkgs-make and installs them locally in [`pip`'s “editable” mode](https://pip.pypa.io/en/stable/reference/pip_install/#editable-installs). This sets up the `PATH` and `PYTHONPATH` to not only have pinned version of third-party Python libraries, but also references to the local unpinned projects under development

This setup by default involves some files persisted/cached in a temporary directory to save time entering the Nix shell after the first time. This persistence can be disabled with `envPersists`.


<a id="org38d42c5"></a>

# Navigating the Code

If you'd like to follow the implementation, this project is organized as follows:

| File/Directory                            | Description                            |
|----------------------------------------- |-------------------------------------- |
| [haskell/](./haskell)                     | Haskell-specific Nix expressions       |
| [haskell/overrides/](./haskell/overrides) | curated Haskell package overrides      |
| [lib/](./lib)                             | platform-agnostic functions            |
| [python/](./python)                       | Python-specific Nix expressions        |
| [python/overrides/](./python/overrides)   | curated Python package overrides       |
| [top/overrides/](./top/overrides)         | curated top-level package overrides    |
| [config.nix](./config.nix)                | configuration defaults                 |
| [default.nix](./default.nix)              | top-level entry point for convenience  |
