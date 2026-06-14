# API Reference

## `build_mex`

```@docs
Mexicah.build_mex
```

## `build_all_mex`

```@docs
Mexicah.build_all_mex
```

## `@mexfunction`

```@docs
Mexicah.var"@mexfunction"
```

## `@mexgradient`

```@docs
Mexicah.var"@mexgradient"
```

## `mex_ext`

Returns the platform-appropriate MEX file extension:

| Platform | Extension |
|---|---|
| Linux x86-64 | `.mexa64` |
| macOS x86-64 | `.mexmaci64` |
| macOS ARM64 | `.mexmaca64` |
| Windows x86-64 | `.mexw64` |
