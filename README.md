# ManualImageCoding

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/ManualImageCoding.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/ManualImageCoding.jl/dev/)
[![Build Status](https://github.com/LilithHafner/ManualImageCoding.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/ManualImageCoding.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/ManualImageCoding.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/ManualImageCoding.jl)

## Installation

To install this software on Linux or Mac, run the following command:

```
curl -fLsS https://raw.githubusercontent.com/lilithhafner/quickdraw/main/script | sh -s https://github.com/LilithHafner/ManualImageCoding.jl
```

To install this software on Windows, install Julia and then run the following command:
```
(echo julia -e "import Pkg; Pkg.activate(\"ManualImageCoding\", shared=true); try Pkg.add(url=\"https://github.com/LilithHafner/ManualImageCoding.jl\"); catch; println(\"Warning: update failed\") end; using ManualImageCoding: main; main()" %0 %* && echo pause) > ManualImageCoding.bat
```

In all cases, the command will create an executable called `ManualImageCoding` that can be double clicked to run.
