#!/usr/bin/env bash
# test_patterns.sh — Validate grep patterns and scripts used in cpp-quality.yml
#
# Usage: bash tests/test_patterns.sh
#
# Tests cover:
#   1. cout-ban patterns (true positives & false negatives)
#   2. new/delete-ban patterns (true positives & false positives)
#   3. doctest-enforce patterns (gtest & google benchmark detection)
#   4. file-naming snake_case validation
#   5. file-naming built-in exemptions
#   6. End-to-end: diff-file-naming.sh
#   7. End-to-end: package naming (include/<pkg>/)
#   8. Dangerous-workflow patterns (injection regex)
#   9. Binary-artifact patterns (extension matching)
#  10. Hardening verification patterns (readelf output parsing)
#
# Exit code: 0 = all pass, 1 = failures found

set -euo pipefail

PASS=0
FAIL=0
TOTAL=0

pass() {
    PASS=$((PASS + 1))
    TOTAL=$((TOTAL + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL + 1))
    echo "  FAIL: $1"
}

assert_matches() {
    local pattern="$1" input="$2" desc="$3"
    if echo "$input" | grep -qE "$pattern"; then
        pass "$desc"
    else
        fail "$desc — expected match for: $input"
    fi
}

assert_no_match() {
    local pattern="$1" input="$2" desc="$3"
    if echo "$input" | grep -qE "$pattern"; then
        fail "$desc — unexpected match for: $input"
    else
        pass "$desc"
    fi
}

# =============================================================================
echo "=== 1. cout-ban patterns ==="
# =============================================================================

COUT_PATTERN='std::cout|std::cerr|std::clog|printf\(|fprintf\(|puts\('

# True positives — must match
assert_matches "$COUT_PATTERN" '    std::cout << "hello";'         "std::cout basic"
assert_matches "$COUT_PATTERN" '  std::cerr << err;'               "std::cerr basic"
assert_matches "$COUT_PATTERN" 'std::clog << msg;'                 "std::clog basic"
assert_matches "$COUT_PATTERN" '  printf("hello %d", x);'         "printf basic"
assert_matches "$COUT_PATTERN" '  fprintf(stderr, "err");'        "fprintf basic"
assert_matches "$COUT_PATTERN" '  puts("hello");'                  "puts basic"
assert_matches "$COUT_PATTERN" '    std::cout<<"no space";'        "std::cout no space before <<"
assert_matches "$COUT_PATTERN" 'printf("multiarg %d %s", a, b);'  "printf multiple args"

# False positives we accept (pattern is intentionally broad)

# True negatives — must NOT match
assert_no_match "$COUT_PATTERN" 'spdlog::info("hello");'          "spdlog not matched"
assert_no_match "$COUT_PATTERN" 'RCLCPP_INFO(logger, "hi");'      "ROS2 logger not matched"
assert_no_match "$COUT_PATTERN" 'auto cout_count = 5;'            "variable named cout_count"

# Known limitation: grep is line-based and matches inside comments.
# '// std::cout << x;' WILL match. This is by-design (conservative).
assert_matches "$COUT_PATTERN" '// std::cout << "commented";'     "comments matched (known — grep is line-based)"

# Test file exclusion pattern
TEST_PATTERN='test'
assert_matches "$TEST_PATTERN" 'src/test_utils.cpp'               "test file detected (test_utils)"
assert_matches "$TEST_PATTERN" 'tests/my_test.cpp'                "test file detected (tests/)"
assert_no_match "$TEST_PATTERN" 'src/main.cpp'                    "non-test file passes"
assert_no_match "$TEST_PATTERN" 'src/parser.hpp'                  "non-test header passes"

echo ""

# =============================================================================
echo "=== 2. new/delete-ban patterns ==="
# =============================================================================

NEW_PATTERN='\bnew\s+[A-Z_a-z]'
DELETE_PATTERN='\bdelete(\s|\[)'
COMBINED="$NEW_PATTERN|$DELETE_PATTERN"
EXCLUSION='make_unique|make_shared|make_obj|operator\s+(new|delete)|placement|#\s*include'

# Helper: matches ban AND not excluded
assert_banned() {
    local input="$1" desc="$2"
    if echo "$input" | grep -qE "$COMBINED" && ! echo "$input" | grep -qE "$EXCLUSION"; then
        pass "$desc"
    else
        fail "$desc — expected banned: $input"
    fi
}

# Helper: not banned (either no match or excluded)
assert_not_banned() {
    local input="$1" desc="$2"
    if echo "$input" | grep -qE "$COMBINED" && ! echo "$input" | grep -qE "$EXCLUSION"; then
        fail "$desc — unexpected ban for: $input"
    else
        pass "$desc"
    fi
}

# True positives — must be banned
assert_banned '  auto* p = new MyClass();'         "raw new MyClass"
assert_banned '  auto* p = new Widget(42);'        "raw new Widget"
assert_banned '  int* arr = new int[100];'         "raw new array"
assert_banned '  delete ptr;'                       "raw delete"
assert_banned '  delete[] arr;'                     "raw delete[]"
assert_banned '  auto* x = new std::string("hi");' "raw new std::string"
assert_banned '  Foo* f = new Foo{};'              "raw new with braces"

# True negatives — must NOT be banned
assert_not_banned '  auto p = std::make_unique<MyClass>();'  "make_unique OK"
assert_not_banned '  auto p = std::make_shared<Widget>();'   "make_shared OK"
assert_not_banned '  int new_value = 42;'                     "variable new_value OK"
assert_not_banned '  bool is_new = true;'                     "variable is_new OK"
assert_not_banned '  auto renew = func();'                    "variable renew OK"
assert_not_banned '  void* operator new(size_t s);'          "operator new OK"
assert_not_banned '  void operator delete(void* p);'         "operator delete OK"
assert_not_banned '  // placement new'                        "placement comment OK"
assert_not_banned '  #include <new>'                          "#include <new> OK"
assert_not_banned '  auto p = make_obj<Foo>();'              "make_obj OK"
assert_not_banned '  std::string newest = "x";'              "variable newest OK"

echo ""

# =============================================================================
echo "=== 3. doctest-enforce patterns ==="
# =============================================================================

GTEST_PATTERN='TEST\(|TEST_F\(|TEST_P\(|TYPED_TEST\(|EXPECT_EQ\(|EXPECT_NE\(|EXPECT_TRUE\(|EXPECT_FALSE\(|EXPECT_STREQ\(|EXPECT_THROW\(|EXPECT_NO_THROW\(|EXPECT_NEAR\(|EXPECT_LT\(|EXPECT_LE\(|EXPECT_GT\(|EXPECT_GE\(|EXPECT_THAT\(|ASSERT_EQ\(|ASSERT_NE\(|ASSERT_TRUE\(|ASSERT_FALSE\(|ASSERT_STREQ\(|ASSERT_THROW\(|ASSERT_NO_THROW\(|ASSERT_NEAR\(|ASSERT_LT\(|ASSERT_LE\(|ASSERT_GT\(|ASSERT_GE\(|ASSERT_THAT\(|ASSERT_DEATH\(|#include\s*[<"]gtest/|#include\s*[<"]gmock/'

GBENCH_PATTERN='benchmark::State|BENCHMARK\(|BENCHMARK_DEFINE_F\(|BENCHMARK_REGISTER_F\(|#include\s*[<"]benchmark/benchmark\.h[>"]'

# gtest — must detect
assert_matches "$GTEST_PATTERN" 'TEST(MySuite, MyTest) {'                     "gtest TEST()"
assert_matches "$GTEST_PATTERN" 'TEST_F(MyFixture, Test1) {'                  "gtest TEST_F()"
assert_matches "$GTEST_PATTERN" 'TEST_P(ParamSuite, Test) {'                  "gtest TEST_P()"
assert_matches "$GTEST_PATTERN" '  EXPECT_EQ(a, b);'                          "gtest EXPECT_EQ"
assert_matches "$GTEST_PATTERN" '  EXPECT_TRUE(flag);'                        "gtest EXPECT_TRUE"
assert_matches "$GTEST_PATTERN" '  EXPECT_THROW(func(), std::exception);'     "gtest EXPECT_THROW"
assert_matches "$GTEST_PATTERN" '  ASSERT_NE(ptr, nullptr);'                  "gtest ASSERT_NE"
assert_matches "$GTEST_PATTERN" '  ASSERT_DEATH(crash(), ".*");'              "gtest ASSERT_DEATH"
assert_matches "$GTEST_PATTERN" '#include <gtest/gtest.h>'                    "gtest include <>"
assert_matches "$GTEST_PATTERN" '#include "gtest/gtest.h"'                    "gtest include \"\""
assert_matches "$GTEST_PATTERN" '#include <gmock/gmock.h>'                    "gmock include"
assert_matches "$GTEST_PATTERN" '  EXPECT_THAT(vec, Contains(42));'           "gtest EXPECT_THAT"

# gtest — must NOT detect doctest equivalents
assert_no_match "$GTEST_PATTERN" 'TEST_CASE("my test") {'                     "doctest TEST_CASE"
assert_no_match "$GTEST_PATTERN" '  CHECK(a == b);'                            "doctest CHECK"
assert_no_match "$GTEST_PATTERN" '  REQUIRE(x > 0);'                           "doctest REQUIRE"
assert_no_match "$GTEST_PATTERN" '  CHECK_EQ(a, b);'                           "doctest CHECK_EQ"
assert_no_match "$GTEST_PATTERN" '#include <doctest/doctest.h>'                "doctest include"

# Google Benchmark — must detect
assert_matches "$GBENCH_PATTERN" 'static void BM_Sort(benchmark::State& s) {' "gbench benchmark::State"
assert_matches "$GBENCH_PATTERN" 'BENCHMARK(BM_Sort);'                         "gbench BENCHMARK()"
assert_matches "$GBENCH_PATTERN" 'BENCHMARK_DEFINE_F(Fix, Test)(State& s) {'   "gbench BENCHMARK_DEFINE_F"
assert_matches "$GBENCH_PATTERN" 'BENCHMARK_REGISTER_F(Fix, Test);'            "gbench BENCHMARK_REGISTER_F"
assert_matches "$GBENCH_PATTERN" '#include <benchmark/benchmark.h>'            "gbench include <>"
assert_matches "$GBENCH_PATTERN" '#include "benchmark/benchmark.h"'            "gbench include \"\""

# Google Benchmark — must NOT detect nanobench
assert_no_match "$GBENCH_PATTERN" '#include <nanobench.h>'                     "nanobench include"
assert_no_match "$GBENCH_PATTERN" 'ankerl::nanobench::Bench().run("x", f);'   "nanobench usage"

echo ""

# =============================================================================
echo "=== 4. file-naming snake_case ==="
# =============================================================================

SNAKE_CASE='^[a-z][a-z0-9_]*$'

# Valid snake_case
assert_matches "$SNAKE_CASE" 'main'                "single word"
assert_matches "$SNAKE_CASE" 'my_class'            "two words"
assert_matches "$SNAKE_CASE" 'flight_controller'   "long snake_case"
assert_matches "$SNAKE_CASE" 'nav2d'               "word with digit"
assert_matches "$SNAKE_CASE" 'a'                   "single char"
assert_matches "$SNAKE_CASE" 'x11_utils'           "digit in middle"

# Invalid snake_case
assert_no_match "$SNAKE_CASE" 'MyClass'            "PascalCase rejected"
assert_no_match "$SNAKE_CASE" 'myClass'            "camelCase rejected"
assert_no_match "$SNAKE_CASE" 'CONSTANT'           "UPPER_CASE rejected"
assert_no_match "$SNAKE_CASE" 'my-class'           "kebab-case rejected"
assert_no_match "$SNAKE_CASE" '2fast'              "starts with digit rejected"
assert_no_match "$SNAKE_CASE" '_private'           "starts with underscore rejected"
assert_no_match "$SNAKE_CASE" 'has space'          "space rejected"
assert_no_match "$SNAKE_CASE" ''                   "empty string rejected"
assert_no_match "$SNAKE_CASE" 'has.dot'            "dot rejected"

# Prefix stripping (simulating is_snake_case function logic)
echo ""
echo "--- 4a. Allowed prefix stripping ---"

check_with_prefix() {
    local name="$1" prefix="$2" desc="$3" expect="$4"
    local stripped="${name#$prefix}"
    if [[ "$name" == "${prefix}"* ]] && [ -n "$stripped" ] && echo "$stripped" | grep -qE "$SNAKE_CASE"; then
        result="pass"
    elif echo "$name" | grep -qE "$SNAKE_CASE"; then
        result="pass"
    else
        result="fail"
    fi

    if [ "$result" = "$expect" ]; then
        pass "$desc"
    else
        fail "$desc — expected $expect, got $result for: $name (prefix: $prefix)"
    fi
}

check_with_prefix '_bindings'    '_' "prefix _ on _bindings"       "pass"
check_with_prefix '_helper'      '_' "prefix _ on _helper"         "pass"
check_with_prefix '__init__'     '_' "prefix _ on __init__"        "fail"
check_with_prefix 'no_prefix'    '_' "no prefix needed"            "pass"
check_with_prefix '_'            '_' "prefix only, no name"        "fail"
check_with_prefix '_MyClass'     '_' "prefix _ but PascalCase"     "fail"

echo ""

# =============================================================================
echo "=== 5. file-naming built-in exemptions ==="
# =============================================================================

EXEMPT_FILES="CMakeLists.txt Dockerfile README.md CLAUDE.md CHANGELOG.md CONTRIBUTING.md LICENSE Makefile Doxyfile package.xml pyproject.toml setup.py setup.cfg Cargo.toml Cargo.lock"
EXEMPT_PATTERNS='^requirements.*\.txt$ ^\. ^__init__\.py$ ^__main__\.py$ ^__pycache__$ ^py\.typed$'

check_exempt_file() {
    local name="$1" desc="$2"
    for f in $EXEMPT_FILES; do
        if [ "$name" = "$f" ]; then
            pass "$desc"
            return
        fi
    done
    fail "$desc — $name not found in exempt list"
}

check_exempt_pattern() {
    local name="$1" desc="$2"
    for p in $EXEMPT_PATTERNS; do
        if echo "$name" | grep -qE "$p"; then
            pass "$desc"
            return
        fi
    done
    fail "$desc — $name matched no exempt pattern"
}

check_not_exempt() {
    local name="$1" desc="$2"
    for f in $EXEMPT_FILES; do
        if [ "$name" = "$f" ]; then
            fail "$desc — $name should NOT be exempt"
            return
        fi
    done
    for p in $EXEMPT_PATTERNS; do
        if echo "$name" | grep -qE "$p"; then
            fail "$desc — $name matched exempt pattern $p"
            return
        fi
    done
    pass "$desc"
}

# Exempt filenames
check_exempt_file "CMakeLists.txt"      "CMakeLists.txt exempt"
check_exempt_file "Dockerfile"          "Dockerfile exempt"
check_exempt_file "README.md"           "README.md exempt"
check_exempt_file "LICENSE"             "LICENSE exempt"
check_exempt_file "Makefile"            "Makefile exempt"
check_exempt_file "package.xml"         "package.xml exempt"
check_exempt_file "pyproject.toml"      "pyproject.toml exempt"
check_exempt_file "Cargo.toml"          "Cargo.toml exempt"

# Exempt patterns
check_exempt_pattern ".gitignore"          ".gitignore exempt (dotfile)"
check_exempt_pattern ".clang-tidy"         ".clang-tidy exempt (dotfile)"
check_exempt_pattern ".github"             ".github exempt (dotdir)"
check_exempt_pattern "__init__.py"         "__init__.py exempt"
check_exempt_pattern "__main__.py"         "__main__.py exempt"
check_exempt_pattern "__pycache__"         "__pycache__ exempt"
check_exempt_pattern "py.typed"            "py.typed exempt"
check_exempt_pattern "requirements.txt"    "requirements.txt exempt"
check_exempt_pattern "requirements-dev.txt" "requirements-dev.txt exempt"

# NOT exempt (should be checked)
check_not_exempt "MyClass.cpp"      "MyClass.cpp not exempt"
check_not_exempt "badName.hpp"      "badName.hpp not exempt"
check_not_exempt "some_file.py"     "some_file.py not exempt"

echo ""

# =============================================================================
echo "=== 6. End-to-end: diff-file-naming.sh ==="
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAMING_SCRIPT="$SCRIPT_DIR/scripts/diff-file-naming.sh"

if [ -x "$NAMING_SCRIPT" ] || [ -f "$NAMING_SCRIPT" ]; then
    # Create a temp git repo to test the script
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    cd "$TMPDIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"

    # Initial commit on main
    echo "init" > init.txt
    git add init.txt
    git commit -q -m "init"
    git branch -M main

    # Create feature branch with test files
    git checkout -q -b feature/test

    # Good files (snake_case)
    mkdir -p src/my_package
    echo "ok" > src/my_package/good_file.cpp
    echo "ok" > src/my_package/another_one.hpp
    echo "ok" > src/nav_utils.cpp

    # Exempt files
    echo "ok" > CMakeLists.txt
    echo "ok" > README.md
    mkdir -p .github/workflows
    echo "ok" > .github/workflows/ci.yml

    # Bad files (not snake_case)
    echo "bad" > MyClass.cpp
    echo "bad" > badName.hpp
    mkdir -p BadDir
    echo "bad" > BadDir/ok_file.cpp

    git add -A
    git commit -q -m "test files"

    # Run the script — capture exit code without triggering set -e
    EXIT_CODE=0
    OUTPUT=$(bash "$NAMING_SCRIPT" main 2>&1) || EXIT_CODE=$?

    # Should find violations
    if [ $EXIT_CODE -ne 0 ]; then
        pass "script exits non-zero on violations"
    else
        fail "script should exit non-zero on violations"
    fi

    # Should catch MyClass.cpp
    if echo "$OUTPUT" | grep -q "MyClass.cpp"; then
        pass "detects MyClass.cpp violation"
    else
        fail "missed MyClass.cpp violation"
    fi

    # Should catch badName.hpp
    if echo "$OUTPUT" | grep -q "badName.hpp"; then
        pass "detects badName.hpp violation"
    else
        fail "missed badName.hpp violation"
    fi

    # Should catch BadDir
    if echo "$OUTPUT" | grep -q "BadDir"; then
        pass "detects BadDir/ violation"
    else
        fail "missed BadDir/ violation"
    fi

    # Should NOT flag good files
    if echo "$OUTPUT" | grep -q "good_file.cpp"; then
        fail "false positive on good_file.cpp"
    else
        pass "good_file.cpp passes"
    fi

    # Should NOT flag exempt files
    if echo "$OUTPUT" | grep -q "CMakeLists.txt"; then
        fail "false positive on CMakeLists.txt"
    else
        pass "CMakeLists.txt exempt"
    fi

    if echo "$OUTPUT" | grep -q "README.md"; then
        fail "false positive on README.md"
    else
        pass "README.md exempt"
    fi

    # Should NOT flag .github/ paths
    if echo "$OUTPUT" | grep -q "\.github"; then
        fail "false positive on .github/"
    else
        pass ".github/ exempt"
    fi

    # Test with no violations
    cd "$TMPDIR"
    git checkout -q main
    git checkout -q -b feature/clean

    echo "clean" > clean_file.cpp
    mkdir -p good_dir
    echo "ok" > good_dir/another.hpp
    git add -A
    git commit -q -m "clean files"

    EXIT_CODE2=0
    OUTPUT2=$(bash "$NAMING_SCRIPT" main 2>&1) || EXIT_CODE2=$?

    if [ $EXIT_CODE2 -eq 0 ]; then
        pass "script exits 0 when all files pass"
    else
        fail "script should exit 0 when all files pass"
    fi
else
    echo "  SKIP: diff-file-naming.sh not found at $NAMING_SCRIPT"
fi

echo ""

# =============================================================================
echo "=== 7. End-to-end: package naming (include/<pkg>/) ==="
# =============================================================================

if [ -x "$NAMING_SCRIPT" ] || [ -f "$NAMING_SCRIPT" ]; then
    # Reuse temp dir from section 6 (trap already set)
    cd "$TMPDIR"
    git checkout -q main

    git checkout -q -b feature/package-naming

    # Good package names (snake_case)
    mkdir -p include/my_package
    echo "ok" > include/my_package/header.hpp
    mkdir -p include/nav_utils
    echo "ok" > include/nav_utils/types.hpp
    mkdir -p include/flight_controller
    echo "ok" > include/flight_controller/controller.hpp

    # Bad package names
    mkdir -p include/MyPackage
    echo "bad" > include/MyPackage/header.hpp
    mkdir -p include/flightController
    echo "bad" > include/flightController/header.hpp
    mkdir -p "include/Bad-Name"
    echo "bad" > "include/Bad-Name/header.hpp"

    git add -A
    git commit -q -m "package naming test files"

    EXIT_CODE_PKG=0
    OUTPUT_PKG=$(bash "$NAMING_SCRIPT" main 2>&1) || EXIT_CODE_PKG=$?

    # Should find violations
    if [ $EXIT_CODE_PKG -ne 0 ]; then
        pass "script exits non-zero on package naming violations"
    else
        fail "script should exit non-zero on package naming violations"
    fi

    # Should catch PascalCase package
    if echo "$OUTPUT_PKG" | grep -q "MyPackage"; then
        pass "detects MyPackage/ violation (PascalCase)"
    else
        fail "missed MyPackage/ violation"
    fi

    # Should catch camelCase package
    if echo "$OUTPUT_PKG" | grep -q "flightController"; then
        pass "detects flightController/ violation (camelCase)"
    else
        fail "missed flightController/ violation"
    fi

    # Should catch kebab-case package
    if echo "$OUTPUT_PKG" | grep -q "Bad-Name"; then
        pass "detects Bad-Name/ violation (kebab-case)"
    else
        fail "missed Bad-Name/ violation"
    fi

    # Should NOT flag good package names
    if echo "$OUTPUT_PKG" | grep -q "my_package"; then
        fail "false positive on my_package/"
    else
        pass "my_package/ passes"
    fi

    if echo "$OUTPUT_PKG" | grep -q "nav_utils"; then
        fail "false positive on nav_utils/"
    else
        pass "nav_utils/ passes"
    fi

    # Test clean package names only
    git checkout -q main
    git checkout -q -b feature/clean-packages

    mkdir -p include/good_pkg
    echo "ok" > include/good_pkg/api.hpp
    mkdir -p include/another_pkg
    echo "ok" > include/another_pkg/types.hpp
    git add -A
    git commit -q -m "clean package names"

    EXIT_CODE_PKG2=0
    OUTPUT_PKG2=$(bash "$NAMING_SCRIPT" main 2>&1) || EXIT_CODE_PKG2=$?

    if [ $EXIT_CODE_PKG2 -eq 0 ]; then
        pass "script exits 0 when all package names pass"
    else
        fail "script should exit 0 when all package names pass"
    fi
else
    echo "  SKIP: diff-file-naming.sh not found at $NAMING_SCRIPT"
fi

echo ""

# =============================================================================
echo "=== 8. Dangerous-workflow patterns ==="
# =============================================================================

# Pattern: PR-controlled input injection in run: steps
INJECTION_PR_PATTERN='\$\{\{\s*github\.event\.pull_request\.(title|body|head\.ref)\s*\}\}'
INJECTION_ISSUE_PATTERN='\$\{\{\s*github\.event\.issue\.(title|body)\s*\}\}'
INJECTION_COMMENT_PATTERN='\$\{\{\s*github\.event\.comment\.body\s*\}\}'

# PR injection — must detect
assert_matches "$INJECTION_PR_PATTERN" '  echo "${{ github.event.pull_request.title }}"'     "PR title injection"
assert_matches "$INJECTION_PR_PATTERN" '  echo "${{ github.event.pull_request.body }}"'      "PR body injection"
assert_matches "$INJECTION_PR_PATTERN" '  echo "${{ github.event.pull_request.head.ref }}"'  "PR head.ref injection"

# Issue injection — must detect
assert_matches "$INJECTION_ISSUE_PATTERN" '  echo "${{ github.event.issue.title }}"'         "issue title injection"
assert_matches "$INJECTION_ISSUE_PATTERN" '  echo "${{ github.event.issue.body }}"'          "issue body injection"

# Comment injection — must detect
assert_matches "$INJECTION_COMMENT_PATTERN" '  echo "${{ github.event.comment.body }}"'      "comment body injection"

# Safe patterns — must NOT detect
assert_no_match "$INJECTION_PR_PATTERN" '  echo "${{ github.event.pull_request.number }}"'   "PR number is safe"
assert_no_match "$INJECTION_PR_PATTERN" '  echo "${{ github.sha }}"'                          "github.sha is safe"
assert_no_match "$INJECTION_PR_PATTERN" '  echo "${{ github.ref }}"'                          "github.ref is safe"
assert_no_match "$INJECTION_ISSUE_PATTERN" '  echo "${{ github.event.issue.number }}"'        "issue number is safe"
assert_no_match "$INJECTION_COMMENT_PATTERN" '  echo "${{ github.event.comment.id }}"'        "comment id is safe"

# Pattern: pull_request_target + checkout of PR head
PRT_CHECKOUT_PATTERN='github\.event\.pull_request\.head\.(sha|ref)'
assert_matches "$PRT_CHECKOUT_PATTERN" '  ref: ${{ github.event.pull_request.head.sha }}'    "PRT checkout head.sha"
assert_matches "$PRT_CHECKOUT_PATTERN" '  ref: ${{ github.event.pull_request.head.ref }}'    "PRT checkout head.ref"
assert_no_match "$PRT_CHECKOUT_PATTERN" '  ref: ${{ github.ref }}'                            "normal ref is safe"

echo ""

# =============================================================================
echo "=== 9. Binary-artifact patterns ==="
# =============================================================================

BINARY_PATTERN='\.exe$|\.dll$|\.so$|\.dylib$|\.a$|\.o$|\.obj$|\.lib$|\.pyc$|\.pyo$|\.whl$|\.egg$|\.jar$|\.war$|\.class$|\.bin$'

# Must detect binary extensions
assert_matches "$BINARY_PATTERN" 'build/app.exe'            "detect .exe"
assert_matches "$BINARY_PATTERN" 'lib/helper.dll'           "detect .dll"
assert_matches "$BINARY_PATTERN" 'lib/libfoo.so'            "detect .so"
assert_matches "$BINARY_PATTERN" 'lib/libfoo.dylib'         "detect .dylib"
assert_matches "$BINARY_PATTERN" 'lib/libfoo.a'             "detect .a"
assert_matches "$BINARY_PATTERN" 'build/main.o'             "detect .o"
assert_matches "$BINARY_PATTERN" 'build/main.obj'           "detect .obj"
assert_matches "$BINARY_PATTERN" 'lib/helper.lib'           "detect .lib"
assert_matches "$BINARY_PATTERN" '__pycache__/mod.pyc'      "detect .pyc"
assert_matches "$BINARY_PATTERN" '__pycache__/mod.pyo'      "detect .pyo"
assert_matches "$BINARY_PATTERN" 'dist/pkg-1.0.whl'         "detect .whl"
assert_matches "$BINARY_PATTERN" 'dist/pkg-1.0.egg'         "detect .egg"
assert_matches "$BINARY_PATTERN" 'lib/app.jar'              "detect .jar"
assert_matches "$BINARY_PATTERN" 'deploy/app.war'           "detect .war"
assert_matches "$BINARY_PATTERN" 'build/Main.class'         "detect .class"
assert_matches "$BINARY_PATTERN" 'firmware/image.bin'        "detect .bin"

# Must NOT detect source/text files
assert_no_match "$BINARY_PATTERN" 'src/main.cpp'            "cpp not matched"
assert_no_match "$BINARY_PATTERN" 'src/lib.hpp'             "hpp not matched"
assert_no_match "$BINARY_PATTERN" 'scripts/build.sh'        "sh not matched"
assert_no_match "$BINARY_PATTERN" 'README.md'               "md not matched"
assert_no_match "$BINARY_PATTERN" 'config.yaml'             "yaml not matched"
assert_no_match "$BINARY_PATTERN" 'Makefile'                "Makefile not matched"
assert_no_match "$BINARY_PATTERN" 'src/binary_utils.cpp'    "binary_utils.cpp not matched (substring)"
assert_no_match "$BINARY_PATTERN" 'docs/classes.md'         "classes.md not matched (substring)"

echo ""

# =============================================================================
echo "=== 10. Hardening verification patterns ==="
# =============================================================================

# --- PIE detection (readelf -h output) ---
PIE_DYN_PATTERN='Type:\s+DYN'
PIE_EXEC_PATTERN='Type:\s+EXEC'

assert_matches "$PIE_DYN_PATTERN"  '  Type:                              DYN (Position-Independent Executable)'  "PIE binary detected (DYN)"
assert_matches "$PIE_DYN_PATTERN"  '  Type:                              DYN (Shared object file)'               "shared lib detected (DYN)"
assert_matches "$PIE_EXEC_PATTERN" '  Type:                              EXEC (Executable file)'                 "non-PIE binary detected (EXEC)"
assert_no_match "$PIE_DYN_PATTERN" '  Type:                              EXEC (Executable file)'                 "EXEC not matched as DYN"

# --- RELRO detection (readelf -l output) ---
RELRO_PATTERN='GNU_RELRO'

assert_matches "$RELRO_PATTERN"    '  GNU_RELRO      0x0000000000003e10 0x0000000000403e10'  "GNU_RELRO segment detected"
assert_no_match "$RELRO_PATTERN"   '  GNU_STACK      0x0000000000000000 0x0000000000000000'  "GNU_STACK not matched as RELRO"
assert_no_match "$RELRO_PATTERN"   '  LOAD           0x0000000000000000 0x0000000000400000'  "LOAD not matched as RELRO"

# --- BIND_NOW detection (readelf -d output) ---
BINDNOW_PATTERN='\(BIND_NOW\)'

assert_matches "$BINDNOW_PATTERN"    ' 0x0000000000000018 (BIND_NOW)           '                   "standalone BIND_NOW detected"
assert_no_match "$BINDNOW_PATTERN"   ' 0x000000000000001e (FLAGS)              BIND_NOW'           "FLAGS value not matched (no parens)"
assert_no_match "$BINDNOW_PATTERN"   ' 0x000000000000001e (FLAGS)              ORIGIN'             "ORIGIN not matched as BIND_NOW"
assert_no_match "$BINDNOW_PATTERN"   ' 0x0000000000000001 (NEEDED)             Shared library'     "NEEDED not matched as BIND_NOW"

# --- Stack canary detection (readelf -s output) ---
CANARY_PATTERN='__stack_chk_fail'

assert_matches "$CANARY_PATTERN"    '    42: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __stack_chk_fail@GLIBC_2.4'  "stack canary symbol detected"
assert_no_match "$CANARY_PATTERN"   '    42: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND printf@GLIBC_2.2.5'         "printf not matched as canary"

# --- FORTIFY detection (readelf -s output) ---
FORTIFY_PATTERN='__\w+_chk'

assert_matches "$FORTIFY_PATTERN"    '    55: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __printf_chk@GLIBC_2.3.4'     "FORTIFY __printf_chk detected"
assert_matches "$FORTIFY_PATTERN"    '    56: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __memcpy_chk@GLIBC_2.3.4'     "FORTIFY __memcpy_chk detected"
assert_matches "$FORTIFY_PATTERN"    '    57: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __sprintf_chk@GLIBC_2.3.4'    "FORTIFY __sprintf_chk detected"
assert_no_match "$FORTIFY_PATTERN"   '    42: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND printf@GLIBC_2.2.5'           "plain printf not matched as FORTIFY"
assert_no_match "$FORTIFY_PATTERN"   '    42: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND malloc@GLIBC_2.2.5'           "malloc not matched as FORTIFY"
assert_matches  "$FORTIFY_PATTERN"   '    42: 0000000000000000     0 FUNC    GLOBAL DEFAULT  UND __stack_chk_fail@GLIBC_2.4'   "stack_chk_fail matches FORTIFY pattern (known overlap)"

# --- NX detection (readelf -l output) ---
NX_EXECUTABLE_PATTERN='GNU_STACK.*RWE'

assert_matches "$NX_EXECUTABLE_PATTERN"    '  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000 0x0000 RWE 0x10'  "executable stack detected (RWE)"
assert_no_match "$NX_EXECUTABLE_PATTERN"   '  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000 0x0000 RW  0x10'  "non-executable stack OK (RW)"
assert_no_match "$NX_EXECUTABLE_PATTERN"   '  GNU_RELRO      0x0000000000003e10 0x0000000000403e10 0x0000 RW  0x1'                      "GNU_RELRO not matched as GNU_STACK"

echo ""

# =============================================================================
echo "=== 11. CET (Control-flow Enforcement) patterns ==="
# =============================================================================

# --- CET detection (readelf -n output) ---
CET_IBT_PATTERN='IBT'
CET_SHSTK_PATTERN='SHSTK'
CET_FEATURE_PATTERN='x86 feature:'

assert_matches "$CET_FEATURE_PATTERN"  '      Properties: x86 feature: IBT, SHSTK'                  "x86 feature line detected"
assert_matches "$CET_IBT_PATTERN"      '      Properties: x86 feature: IBT, SHSTK'                  "IBT detected in full CET"
assert_matches "$CET_SHSTK_PATTERN"    '      Properties: x86 feature: IBT, SHSTK'                  "SHSTK detected in full CET"
assert_matches "$CET_IBT_PATTERN"      '      Properties: x86 feature: IBT'                          "IBT-only detected"
assert_matches "$CET_SHSTK_PATTERN"    '      Properties: x86 feature: SHSTK'                        "SHSTK-only detected"
assert_no_match "$CET_FEATURE_PATTERN" '  GNU_STACK      0x0000000000000000 0x0000000000000000'      "GNU_STACK not matched as x86 feature"
assert_no_match "$CET_IBT_PATTERN"     '      Properties: x86 feature: SHSTK'                        "SHSTK-only does not match IBT"
assert_no_match "$CET_SHSTK_PATTERN"   '      Properties: x86 feature: IBT'                          "IBT-only does not match SHSTK"
assert_no_match "$CET_FEATURE_PATTERN" '  Type:                              DYN (Shared object file)' "DYN type not matched as x86 feature"

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "========================================"
echo "  Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "========================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
