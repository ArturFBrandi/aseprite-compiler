# aseprite-compiler

One command to build and run [Aseprite](https://github.com/aseprite/aseprite) from
source on Windows.

## Usage

```
git clone <this repo>
cd aseprite-compiler
build.cmd
```

**First run**: downloads the latest Aseprite source release, downloads the matching
pre-built Skia library, compiles Aseprite with CMake + Ninja, then launches it.
This takes a while (large downloads + a full C++ build) and needs a few GB of
free disk space.

**Every run after that**: just launches the already-built `build\bin\aseprite.exe`
immediately, skipping everything else.

Options (pass to `build.cmd` or `.\build.ps1` directly):

* `-Rebuild` — wipe the downloaded source/Skia and the build output, and start over
  (e.g. to pick up a newer Aseprite release).
* `-NoRun` — build (if needed) but don't launch Aseprite afterwards.

## Prerequisites

* Windows 11
* [Visual Studio 2022 Community](https://visualstudio.microsoft.com/downloads/) with
  the **Desktop development with C++** workload. The script detects this via
  `vswhere` and fails with instructions if it's missing — it won't install Visual
  Studio for you.
* [CMake](https://cmake.org) and [Ninja](https://ninja-build.org) — the script
  installs these automatically via `winget` if they're missing.
* Internet access (to fetch the Aseprite source and Skia from GitHub Releases).

## How it works

`build.ps1`:

1. If `build\bin\aseprite.exe` already exists, launches it and exits — that's the
   whole "just open Aseprite" path.
2. Otherwise, checks/installs CMake and Ninja, and loads the MSVC x64 developer
   environment from the Visual Studio install found via `vswhere`.
3. Downloads the latest `Aseprite-vX.Y.Z-Source.zip` from
   [aseprite/aseprite releases](https://github.com/aseprite/aseprite/releases)
   into `.deps\aseprite-src`.
4. Reads `laf\misc\skia-tag.txt` from that source to find the exact Skia build
   Aseprite needs, and downloads it from
   [aseprite/skia releases](https://github.com/aseprite/skia/releases) into
   `.deps\skia`.
5. Configures with `cmake -G Ninja` and builds the `aseprite` target.
6. Launches `build\bin\aseprite.exe`.

`.deps\` and `build\` are gitignored — they're regenerated on demand, not checked in.
