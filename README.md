# C Runtime Error Static Analyzer

This is a simple static analysis tool for C code, built using **Flex** and **Bison**. It parses C-like syntax to detect a list of common runtime errors, memory safety issues, and security vulnerabilities directly from the source code.

The tool works by building a simple symbol table and tracking the state of pointer variables (e.g., `is_malloced`, `is_freed`, `is_null_checked`) across different scopes.

## 🚀 Key Features

* [cite_start]**Lexical Analysis** using Flex (`c_analyzer.l`) [cite: 1-28].
* [cite_start]**Syntactic & Semantic Analysis** using Bison (`c_analyzer.y`) [cite: 29-154].
* **Scope Management** to track variables within functions and blocks.
* **Stateful Variable Tracking** for pointers to detect lifecycle errors.
* **Colored, line-numbered output** for clear error reporting.
* **Comprehensive Test Suite** (`test_all_patterns.c`) demonstrating all detected errors and correct code.

## 🔎 Detected Error Patterns

This analyzer is specifically designed to find the following 10 critical error patterns:

### 1. Memory Lifecycle Errors

* **Memory Leak**: Detects memory allocated with `malloc` or `calloc` that is not `free`'d before its pointer goes out of scope.
* **Double Free**: Flags attempts to `free` a pointer that has already been freed.
* **Invalid Free**: Catches attempts to `free` non-heap memory, such as stack variables (`free(&x)`), unallocated pointers, or non-pointer variables.

### 2. Pointer State Errors

* **Use After Free (UAF)**: Reports on the dereferencing of a pointer (read or write) after it has been `free`'d.
* **NULL Pointer Dereference**: Identifies dereferencing of a pointer that has been explicitly set to `NULL`.
* **Missing NULL Check**: Issues a warning immediately after a `malloc` or `calloc` call if it is not followed by a `NULL` check, as the resulting pointer may be dereferenced.
* **Return Local Address**: Detects when a function returns the address of a local (stack) variable, which leads to a dangling pointer.

### 3. Buffer & String Security Errors

* **Write to Read-Only Memory**: Catches attempts to modify a string literal (e.g., `char *s = "hello"; s[0] = 'H';`).
* **Unsafe Function Use**: Flags the use of inherently unsafe C standard library functions:
    * `gets()`
    * `strcpy()`
    * `strcat()`
    * `sprintf()`
* **Unsafe `scanf` (Buffer Overflow Risk)**: Detects the use of `scanf` with an unbounded `%s` format specifier, which can lead to a buffer overflow.

## 🛠️ How It Works

1.  **Lexer (`c_analyzer.l`)**: This file defines patterns to tokenize the C source code. [cite_start]It recognizes keywords (like `malloc`, `if`, `int`) [cite: 4-15][cite_start], identifiers, operators [cite: 23-25], and punctuation. It also tracks the current `line_num` and ignores whitespace and comments.

2.  **Parser (`c_analyzer.y`)**: This file defines the grammar for a subset of the C language. As the parser (Bison) processes the tokens from the lexer, it executes C code for specific grammar rules.

3.  **State Management**:
    * A `Variable` struct and a global `vars` array act as the symbol table.
    * When a variable is declared, `add_var()` is called.
    * When `malloc` is assigned, `mark_malloced()` updates the variable's state.
    * When `free` is called, `mark_freed()` checks for double-free or invalid-free errors before updating the state.
    * When a pointer is dereferenced (`*p`), `check_use_after_free()` and checks for `is_null` are performed.
    * `enter_scope()` and `exit_scope()` manage variable visibility. `check_memory_leaks()` is called when a scope is exited.

## ⚙️ How to Build and Run

You will need `flex`, `bison`, and a C compiler like `gcc`.

```bash
# 1. Generate the parser and lexer C files
bison -d c_analyzer.y
flex c_analyzer.l

# 2. Compile the generated files into an executable
#    'c_analyzer.tab.c' and 'c_analyzer.tab.h' are from bison
#    'lex.yy.c' is from flex
gcc -o c_analyzer c_analyzer.tab.c lex.yy.c -lfl

# 3. Run the analyzer on a C source file
./c_analyzer test_all_patterns.c
