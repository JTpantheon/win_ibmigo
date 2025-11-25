#!/bin/bash
# Test script to verify AIX PPC64 patches are correctly applied
# Usage: ./test-aix-patches.sh <path-to-go-source>

GO_SRC_DIR="${1:-.}"

echo "==================================="
echo "AIX PPC64 Patch Verification Script"
echo "==================================="
echo ""
echo "Testing Go source directory: $GO_SRC_DIR"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0

test_file() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if [ ! -f "$GO_SRC_DIR/$file" ]; then
        echo -e "${YELLOW}⚠️  SKIP${NC} - $description (file not found)"
        return
    fi
    
    if grep -q "$pattern" "$GO_SRC_DIR/$file"; then
        echo -e "${GREEN}✅ PASS${NC} - $description"
        ((PASS_COUNT++))
    else
        echo -e "${RED}❌ FAIL${NC} - $description"
        ((FAIL_COUNT++))
    fi
}

echo "Checking memory address patches..."
echo "-----------------------------------"

# Check tagptr_64bit.go (Go 1.24+) or lfstack_64bit.go (Go 1.20)
if [ -f "$GO_SRC_DIR/src/runtime/tagptr_64bit.go" ]; then
    test_file "src/runtime/tagptr_64bit.go" "0x7<<56" "Memory address 0x7<<56 in tagptr_64bit.go"
    if grep -q "| 0xa<<56" "$GO_SRC_DIR/src/runtime/tagptr_64bit.go"; then
        echo -e "${RED}❌ FAIL${NC} - OLD address 0xa<<56 should NOT exist in tagptr_64bit.go"
        ((FAIL_COUNT++))
    else
        echo -e "${GREEN}✅ PASS${NC} - OLD address 0xa<<56 correctly removed from tagptr_64bit.go"
        ((PASS_COUNT++))
    fi
elif [ -f "$GO_SRC_DIR/src/runtime/lfstack_64bit.go" ]; then
    test_file "src/runtime/lfstack_64bit.go" "0x7<<56" "Memory address 0x7<<56 in lfstack_64bit.go"
    if grep -q "| 0xa<<56" "$GO_SRC_DIR/src/runtime/lfstack_64bit.go"; then
        echo -e "${RED}❌ FAIL${NC} - OLD address 0xa<<56 should NOT exist in lfstack_64bit.go"
        ((FAIL_COUNT++))
    else
        echo -e "${GREEN}✅ PASS${NC} - OLD address 0xa<<56 correctly removed from lfstack_64bit.go"
        ((PASS_COUNT++))
    fi
fi

test_file "src/runtime/malloc.go" "0x0700000000000000" "Arena base offset 0x0700000000000000"
test_file "src/runtime/malloc.go" "0x70<<52" "Memory address 0x70<<52"

echo ""
echo "Checking build configuration patches..."
echo "---------------------------------------"

test_file "src/cmd/dist/build.go" 'goCmd.*append.*"-p=1".*ibmi' "Single-threaded build flag (-p=1)"
test_file "src/cmd/dist/util.go" "maxbg = 1" "Max background jobs set to 1"

echo ""
echo "Checking mkdir retry patches..."
echo "-------------------------------"

# Check if xmkdir has multiple os.Mkdir calls
if [ -f "$GO_SRC_DIR/src/cmd/dist/util.go" ]; then
    MKDIR_COUNT=$(grep -c "os.Mkdir(p, 0777)" "$GO_SRC_DIR/src/cmd/dist/util.go" || echo "0")
    if [ "$MKDIR_COUNT" -gt 5 ]; then
        echo -e "${GREEN}✅ PASS${NC} - xmkdir has retry logic ($MKDIR_COUNT calls)"
        ((PASS_COUNT++))
    else
        echo -e "${RED}❌ FAIL${NC} - xmkdir missing retry logic (found $MKDIR_COUNT calls, expected >5)"
        ((FAIL_COUNT++))
    fi
    
    MKDIRALL_COUNT=$(grep -c "os.MkdirAll(p, 0777)" "$GO_SRC_DIR/src/cmd/dist/util.go" || echo "0")
    if [ "$MKDIRALL_COUNT" -gt 5 ]; then
        echo -e "${GREEN}✅ PASS${NC} - xmkdirall has retry logic ($MKDIRALL_COUNT calls)"
        ((PASS_COUNT++))
    else
        echo -e "${RED}❌ FAIL${NC} - xmkdirall missing retry logic (found $MKDIRALL_COUNT calls, expected >5)"
        ((FAIL_COUNT++))
    fi
fi

echo ""
echo "==================================="
echo "Test Summary"
echo "==================================="
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ All AIX PPC64 patches verified successfully!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some patches are missing or incorrect.${NC}"
    echo "Please refer to AIX_PATCHES_GO_1.24_1.25.md for detailed instructions."
    exit 1
fi
