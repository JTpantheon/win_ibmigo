# Quick Start Guide: Building Go for AIX PPC64 Cross-Compilation

This guide provides quick instructions for building and using Go with AIX PPC64 support on Windows.

## Choose Your Go Version

| Version | Status | Use Case |
|---------|--------|----------|
| **1.20.5** | ✅ Ready to use (this repository) | Stable, proven solution |
| **1.24.10** | 📝 Patches available | Latest stable with new features |
| **1.25.4** | 📝 Patches available | Cutting edge, latest features |

## Option 1: Use Go 1.20.5 (This Repository)

This repository already contains Go 1.20.5 with AIX patches applied.

### Build from Source

```batch
REM Clone this repository
git clone https://github.com/JTpantheon/win_ibmigo.git
cd win_ibmigo\src

REM Build Go
call make.bat

REM Set environment
set GOROOT=%CD%\..
set PATH=%GOROOT%\bin;%PATH%
```

### Cross-Compile for AIX

```batch
REM Set target platform
set GOOS=aix
set GOARCH=ppc64
set CGO_ENABLED=1
set CC=path\to\ppc64-aix-gcc

REM Build your application
go build -o myapp.exe myapp.go
```

## Option 2: Use Go 1.24.10 or 1.25.4

### Step 1: Download Official Go Source

```batch
REM Download from GitHub
git clone --depth 1 --branch go1.24.10 https://github.com/golang/go.git go1.24.10
REM OR for Go 1.25.4
git clone --depth 1 --branch go1.25.4 https://github.com/golang/go.git go1.25.4
```

### Step 2: Apply AIX Patches

Follow the detailed instructions in [`AIX_PATCHES_GO_1.24_1.25.md`](./AIX_PATCHES_GO_1.24_1.25.md)

**Files to modify:**
- `src/runtime/tagptr_64bit.go`
- `src/runtime/malloc.go` (2 changes)
- `src/cmd/dist/build.go`
- `src/cmd/dist/util.go` (3 changes)

**Quick patch summary:**
1. Change memory addresses: `0xa` → `0x7`, `0x0a00...` → `0x0700...`
2. Force single-threaded builds: Add `-p=1` flag
3. Reduce parallelism: `maxbg = 1`
4. Add mkdir retries for IBM i file system

### Step 3: Build Patched Go

```batch
cd go1.24.10\src
REM or cd go1.25.4\src

REM Build Go toolchain
call make.bat
```

### Step 4: Cross-Compile

Same as Option 1 - set environment and build:

```batch
set GOROOT=%CD%\..
set PATH=%GOROOT%\bin;%PATH%
set GOOS=aix
set GOARCH=ppc64
set CGO_ENABLED=1
set CC=path\to\ppc64-aix-gcc

go build -o myapp.exe myapp.go
```

## Prerequisites

### On Windows (Build Machine)

1. **Go Bootstrap Compiler** (Go 1.17.13 or later)
   - Download from: https://go.dev/dl/
   - Set `GOROOT_BOOTSTRAP` if not in standard location

2. **C Compiler** (Optional, for CGO)
   - MinGW-w64 or similar
   - Must support C compilation

3. **AIX Cross-Compiler** (For CGO on AIX targets)
   - GCC for PPC64 AIX
   - Must be configured for cross-compilation

### On IBM i AIX (Target Machine)

1. **IBM i 7.4, 7.5 or later** (7.5 recommended for Power10 hardware)
   - The patches support both IBM i 7.4 and 7.5 identically
   - Memory addressing is compatible across both versions
   - AIX 7.2 binary compatibility maintained
2. **GCC 10** or later
   ```bash
   yum install gcc-10
   ```
3. **Required libraries** (if using ODBC/database features)
   ```bash
   yum install unixODBC unixODBC-devel libodbc2 ibm-iaccess
   ```

## Testing Your Build

### 1. Verify Go Installation

```batch
go version
REM Should show: go version go1.X.X windows/amd64
```

### 2. Test Cross-Compilation

Create a simple test program:

```go
// hello.go
package main

import "fmt"

func main() {
    fmt.Println("Hello from AIX!")
}
```

Build for AIX:

```batch
set GOOS=aix
set GOARCH=ppc64
go build -o hello hello.go
```

### 3. Deploy to IBM i

```bash
# On IBM i AIX system
chmod +x hello
./hello
# Should output: Hello from AIX!
```

## Common Issues

### Issue: "Cannot find GOROOT_BOOTSTRAP"

**Solution:**
```batch
set GOROOT_BOOTSTRAP=C:\Go
```
Point to your existing Go installation.

### Issue: Build fails with parallelism errors

**Solution:** Verify `maxbg = 1` and `-p=1` patches were applied correctly.

### Issue: Binary crashes on AIX with "invalid memory address"

**Solution:** Verify all memory address patches (0xa → 0x7) were applied.

### Issue: "mkdir: cannot create directory"

**Solution:** Verify mkdir retry patches were applied in `util.go`.

## Performance Notes

- **Build Time**: Patched builds are slower due to single-threading (`-p=1`)
- **Runtime**: No performance impact on compiled binaries
- **Binary Size**: Same as standard Go builds

## Additional Resources

- **Detailed Patch Guide**: [`AIX_PATCHES_GO_1.24_1.25.md`](./AIX_PATCHES_GO_1.24_1.25.md)
- **Verification Report**: [`VERIFICATION_REPORT.md`](./VERIFICATION_REPORT.md)
- **Go Issue Tracker**: https://github.com/golang/go/issues/45017
- **Parent Project**: https://github.com/onlysumitg/ibmigo

## Support

For issues specific to:
- **AIX patches**: Open an issue in this repository
- **Go language**: Use official Go channels (golang-nuts, GitHub)
- **IBM i setup**: Consult IBM i documentation

## Credits

These patches are based on research and work by:
- Micah Kimel
- Mike Measel
- rfx77 and the Go community
- onlysumitg (original Windows implementation)

## License

This project maintains the same BSD-style license as the Go programming language. See [LICENSE](./LICENSE) for details.
