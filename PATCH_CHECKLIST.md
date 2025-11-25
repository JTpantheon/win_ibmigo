# Patch Checklist: Go 1.24.10 / 1.25.4 for AIX PPC64

Use this checklist when applying AIX PPC64 patches to Go 1.24.10 or 1.25.4.

## Before You Start

- [ ] Downloaded official Go source (1.24.10 or 1.25.4)
- [ ] Have a text editor ready
- [ ] Read `AIX_PATCHES_GO_1.24_1.25.md` for detailed instructions

## File 1: `src/runtime/tagptr_64bit.go`

Location: Around line 78 (Go 1.24.10) or line 80 (Go 1.25.4)

- [ ] Find the line: `return unsafe.Pointer(uintptr((tp >> ... << 3) | 0xa<<56))`
- [ ] Change `0xa<<56` to `0x7<<56`
- [ ] Save file

**Expected result:**
```go
return unsafe.Pointer(uintptr((tp >> ... << 3) | 0x7<<56))
```

## File 2: `src/runtime/malloc.go` - Change 1

Location: Around line 308 (Go 1.24.10) or line 310 (Go 1.25.4)

- [ ] Find: `arenaBaseOffset = 0xffff800000000000*goarch.IsAmd64 + 0x0a00000000000000*goos.IsAix`
- [ ] Change `0x0a00000000000000` to `0x0700000000000000`
- [ ] Save file

**Expected result:**
```go
arenaBaseOffset = 0xffff800000000000*goarch.IsAmd64 + 0x0700000000000000*goos.IsAix
```

## File 3: `src/runtime/malloc.go` - Change 2

Location: Around line 539 (Go 1.24.10) or line 541 (Go 1.25.4)

- [ ] Find: `p = uintptr(i)<<40 | uintptrMask&(0xa0<<52)`
- [ ] Change `0xa0<<52` to `0x70<<52`
- [ ] Save file

**Expected result:**
```go
p = uintptr(i)<<40 | uintptrMask&(0x70<<52)
```

## File 4: `src/cmd/dist/build.go`

Location: Around line 1734-1735 (Go 1.24.10) or line 1738-1739 (Go 1.25.4)

Find this section:
```go
if gohostos == "plan9" && os.Getenv("sysname") == "vx32" {
    goCmd = append(goCmd, "-p=1")
}
```

- [ ] Add one line AFTER the closing brace: `goCmd = append(goCmd, "-p=1")  // Force single-threaded builds for IBM i`
- [ ] Save file

**Expected result:**
```go
if gohostos == "plan9" && os.Getenv("sysname") == "vx32" {
    goCmd = append(goCmd, "-p=1")
}
goCmd = append(goCmd, "-p=1")  // Force single-threaded builds for IBM i
```

## File 5: `src/cmd/dist/util.go` - Change 1

Location: Around line 124

- [ ] Find: `var maxbg = 4 /* maximum number of jobs to run at once */`
- [ ] Change `4` to `1`
- [ ] Save file

**Expected result:**
```go
var maxbg = 1 /* maximum number of jobs to run at once */
```

## File 6: `src/cmd/dist/util.go` - Change 2

Location: xmkdir function (around line 270)

Find:
```go
func xmkdir(p string) {
    err := os.Mkdir(p, 0777)
    if err != nil {
        fatalf("%v", err)
    }
}
```

- [ ] Add 11 retry lines AFTER the closing brace of the if statement (BEFORE the closing brace of the function)
- [ ] Save file

**Expected result:**
```go
func xmkdir(p string) {
    err := os.Mkdir(p, 0777)
    if err != nil {
        fatalf("%v", err)
    }
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

## File 7: `src/cmd/dist/util.go` - Change 3

Location: xmkdirall function (around line 278)

Find:
```go
func xmkdirall(p string) {
    err := os.MkdirAll(p, 0777)
    if err != nil {
        fatalf("%v", err)
    }
}
```

- [ ] Add 11 retry lines AFTER the closing brace of the if statement (BEFORE the closing brace of the function)
- [ ] Save file

**Expected result:**
```go
func xmkdirall(p string) {
    err := os.MkdirAll(p, 0777)
    if err != nil {
        fatalf("%v", err)
    }
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

## Verification

- [ ] Run verification script: `./test-aix-patches.sh /path/to/go-source`
- [ ] All 8 tests should pass

## Build and Test

- [ ] Build Go from source (on Windows: `cd src && make.bat`)
- [ ] Set environment: `GOOS=aix GOARCH=ppc64 CGO_ENABLED=1`
- [ ] Test cross-compilation with a simple program
- [ ] Deploy and test on IBM i AIX

## Quick Check

If you completed all steps, you should have made changes to:
- [ ] 1 file in `src/runtime/` (tagptr_64bit.go) - 1 change
- [ ] 1 file in `src/runtime/` (malloc.go) - 2 changes
- [ ] 1 file in `src/cmd/dist/` (build.go) - 1 change
- [ ] 1 file in `src/cmd/dist/` (util.go) - 3 changes

**Total: 4 files, 7 changes**

## Troubleshooting

### Test fails: "Memory address 0x7<<56" not found
- Check tagptr_64bit.go line 78/80
- Make sure you changed `0xa` to `0x7` (not `0x70` or other values)

### Test fails: "OLD address 0xa<<56 should NOT exist"
- You didn't complete the change in tagptr_64bit.go
- Make sure `0xa<<56` is completely replaced with `0x7<<56`

### Test fails: "Arena base offset not found"
- Check malloc.go around line 308/310
- Make sure you changed `0x0a00000000000000` to `0x0700000000000000`
- Count the zeros carefully (16 hex digits total)

### Test fails: "Single-threaded build flag" not found
- Check build.go around line 1734/1738
- Make sure you added the line AFTER the plan9 check
- Include the comment: `// Force single-threaded builds for IBM i`

### Test fails: "maxbg" not set to 1
- Check util.go around line 124
- Make sure you changed `var maxbg = 4` to `var maxbg = 1`

### Test fails: "xmkdir has retry logic"
- Check util.go xmkdir function
- Make sure you added 11 os.Mkdir lines (12 total including the original)
- Lines should be inside the function but after the if statement

### Test fails: "xmkdirall has retry logic"
- Check util.go xmkdirall function
- Make sure you added 11 os.MkdirAll lines (12 total including the original)
- Lines should be inside the function but after the if statement

## Need Help?

See these documents:
- `AIX_PATCHES_GO_1.24_1.25.md` - Detailed technical guide
- `QUICK_START.md` - Quick start guide
- `VERIFICATION_REPORT.md` - Analysis report
- `SUMMARY.md` - Executive summary

## Done!

Once all checkboxes are checked and tests pass, you're ready to build Go from source and cross-compile for AIX PPC64!
