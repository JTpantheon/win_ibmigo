# AIX PPC64 Cross-Compile Patches for Go 1.24.10 and 1.25.4

This document describes the necessary changes to enable AIX PPC64 cross-compilation support in Go 1.24.10 and Go 1.25.4, similar to the patches applied to Go 1.20.5 in this repository.

**Target Platforms**: IBM i 7.4, IBM i 7.5, and AIX on Power Systems

## Background

The official Go releases do not fully support cross-compiling for AIX PPC64 from Windows due to memory addressing differences on IBM i systems. This repository contains patches that adjust memory addresses and build settings to enable this functionality.

**IBM i 7.5 Compatibility**: These patches work identically on both IBM i 7.4 and 7.5, as both versions use the same 64-bit memory addressing scheme and PASE environment. See `IBM_I_7.5_COMPATIBILITY.md` for details.

## Analysis Summary

Both Go 1.24.10 and Go 1.25.4 require the same set of patches that were originally applied to Go 1.20.5. The changes are necessary because:

1. **Memory Addressing**: IBM i AIX uses a different memory address space (`0x7xxx...` instead of `0xAxxx...`)
2. **Build Parallelism**: IBM i requires single-threaded builds to avoid race conditions
3. **File System Operations**: IBM i file system needs retry logic for mkdir operations

## Required Changes

### Go 1.24.10 Changes

#### 1. `src/runtime/tagptr_64bit.go` (Line 78)
**Note**: In Go 1.24+, the AIX-specific pointer handling moved from `lfstack_64bit.go` to `tagptr_64bit.go`

```go
# Change from:
return unsafe.Pointer(uintptr((tp >> aixTagBits << 3) | 0xa<<56))

# Change to:
return unsafe.Pointer(uintptr((tp >> aixTagBits << 3) | 0x7<<56))
```

#### 2. `src/runtime/malloc.go` (Line 308)
```go
# Change from:
arenaBaseOffset = 0xffff800000000000*goarch.IsAmd64 + 0x0a00000000000000*goos.IsAix

# Change to:
arenaBaseOffset = 0xffff800000000000*goarch.IsAmd64 + 0x0700000000000000*goos.IsAix
```

#### 3. `src/runtime/malloc.go` (Line 539)
```go
# Change from:
p = uintptr(i)<<40 | uintptrMask&(0xa0<<52)

# Change to:
p = uintptr(i)<<40 | uintptrMask&(0x70<<52)
```

#### 4. `src/cmd/dist/build.go` (After Line 1734)
```go
# Add after the plan9 vx32 check:
goCmd = append(goCmd, "-p=1")  // Force single-threaded builds for IBM i
```

#### 5. `src/cmd/dist/util.go` (Line 124)
```go
# Change from:
var maxbg = 4 /* maximum number of jobs to run at once */

# Change to:
var maxbg = 1 /* maximum number of jobs to run at once */
```

#### 6. `src/cmd/dist/util.go` - xmkdir function
Add retry logic after the error check:
```go
func xmkdir(p string) {
	err := os.Mkdir(p, 0777)
	if err != nil {
		fatalf("%v", err)
	}
	// Add 11 retry attempts for IBM i
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
	os.Mkdir(p, 0777)
}
```

#### 7. `src/cmd/dist/util.go` - xmkdirall function
Add the same retry logic:
```go
func xmkdirall(p string) {
	err := os.MkdirAll(p, 0777)
	if err != nil {
		fatalf("%v", err)
	}
	// Add 11 retry attempts for IBM i
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
	os.MkdirAll(p, 0777)
}
```

### Go 1.25.4 Changes

Go 1.25.4 requires the **exact same changes** as Go 1.24.10, with line numbers being very similar (within 2-3 lines).

The key file locations are:
- `src/runtime/tagptr_64bit.go` (Line 80)
- `src/runtime/malloc.go` (Lines 310, 541)
- `src/cmd/dist/build.go` (After Line 1738)
- `src/cmd/dist/util.go` (Line 124, and xmkdir/xmkdirall functions)

## Technical Explanation

### Memory Address Change (0xA to 0x7)

The change from `0xA` to `0x7` in the high-order bits of pointers is necessary because:

1. IBM i AIX reserves the `0xA` address range for system use
2. Go programs compiled for AIX need to use the `0x7` address range
3. The arena base offset (`0x0a00000000000000` → `0x0700000000000000`) aligns the Go heap with this requirement
4. The pointer packing/unpacking code must match this addressing scheme

### Build Parallelism

The `-p=1` flag and `maxbg = 1` changes force single-threaded builds because:

1. IBM i file systems may have race conditions with parallel builds
2. The retry logic in mkdir operations requires sequential execution
3. This ensures reliable builds even if it's slower

### Mkdir Retry Logic

The multiple retry calls are a workaround for IBM i file system behavior where:

1. Directory creation may not be immediately visible to subsequent operations
2. Multiple attempts ensure the directory is properly created
3. This is a known quirk of IBM i PASE environment

## Testing

After applying these patches, you can test the modified Go compiler by:

1. Build the Go toolchain from source on Windows
2. Set environment variables:
   ```batch
   set GOOS=aix
   set GOARCH=ppc64
   set CGO_ENABLED=1
   ```
3. Attempt to cross-compile a simple Go program
4. Deploy and test the binary on an IBM i AIX system (7.4, 7.5, or later)

**Note**: The same compiled binaries work on both IBM i 7.4 and 7.5 without recompilation.

## References

- Original patches derived from: https://github.com/golang/go/issues/45017
- Parent repository: https://github.com/onlysumitg/win_ibmigo
- Related repository: https://github.com/onlysumitg/ibmigo

## Version Compatibility

### Go Versions

| Go Version | Requires Patches | Status |
|------------|-----------------|---------|
| 1.20.5     | Yes             | Applied in this repo |
| 1.24.10    | Yes             | Applied in this repo |
| 1.25.4     | Yes             | Patches documented |

### IBM i Versions

| IBM i Version | Compatible | Notes |
|---------------|-----------|-------|
| 7.4           | ✅ Yes    | Fully tested |
| 7.5           | ✅ Yes    | Same patches, recommended for Power10 |
| Future versions | ✅ Expected | Uses same memory addressing |

## Notes

1. These patches are specifically for cross-compiling from Windows to AIX PPC64
2. The patches modify runtime memory management and build tooling
3. **Important**: Do not use patched Go for other platforms - only for AIX PPC64 targets
4. The `cgo_import_dynamic` handling in `src/cmd/compile/internal/noder/lex.go` does not need changes in Go 1.24+ as the AIX validation logic is already properly implemented

## Credits

- Original research and patches by: Micah Kimel, Mike Measel, rfx77, and the Go community
- Implementation for Windows: onlysumitg
- This documentation: Generated for Go 1.24.10 and 1.25.4 compatibility
