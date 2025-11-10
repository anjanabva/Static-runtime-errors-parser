/*
 * COMPREHENSIVE TEST SUITE FOR C RUNTIME ERROR ANALYZER
 * Tests all 10 error patterns + parser grammar rules
 */

/* ============================================================================
 * GROUP 1: MEMORY LIFECYCLE ERRORS (3 patterns)
 * ============================================================================ */
// TEST 1: Memory Leak - Basic
void test_leak_basic() {
    int *p;
    p = malloc(100);
    *p = 42;
    return;  // ERROR: Memory leak - 'p' never freed
}

// TEST 2: Memory Leak - Declaration with malloc
void test_leak_combined_decl() {
    int *p = malloc(200);
    *p = 10;
    return;  // ERROR: Memory leak
}

// TEST 3: Memory Leak - Multiple allocations
void test_leak_multiple() {
    int *p;
    int *q;
    p = malloc(50);
    q = malloc(100);
    free(p);
    return;  // ERROR: 'q' leaked
}

// TEST 4: Double Free - Basic
void test_double_free_basic() {
    int *p;
    p = malloc(50);
    free(p);
    free(p);  // ERROR: Double free
}

// TEST 5: Double Free - After use
void test_double_free_complex() {
    int *p;
    p = malloc(100);
    *p = 5;
    free(p);
    free(p);  // ERROR: Double free
}

// TEST 6: Invalid Free - Stack variable
void test_invalid_free_stack() {
    int x;
    x = 5;
    free(&x);  // ERROR: Freeing stack variable
}

// TEST 7: Invalid Free - Non-malloced pointer
void test_invalid_free_pointer() {
    int *p;
    free(p);  // ERROR: Freeing non-malloced pointer
}

// TEST 8: Invalid Free - Non-pointer
void test_invalid_free_nonpointer() {
    int x;
    x = 10;
}

/* ============================================================================
 * GROUP 2: POINTER STATE ERRORS (4 patterns)
 * ============================================================================ */

// TEST 9: Use-After-Free - Basic
void test_uaf_basic() {
    int *p;
    p = malloc(10);
    free(p);
    *p = 5;  // ERROR: Use after free
}

// TEST 10: Use-After-Free - Read access
void test_uaf_read() {
    int *p;
    int x;
    p = malloc(20);
    free(p);
    x = *p;  // ERROR: Use after free (read)
}

// TEST 11: Use-After-Free - In condition
void test_uaf_condition() {
    int *p;
    p = malloc(30);
    free(p);
    if (*p == 0) {  // ERROR: Use after free in condition
        return;
    }
}

// TEST 12: NULL Pointer Dereference - Direct
void test_null_deref_direct() {
    int *p;
    p = NULL;
    *p = 10;  // ERROR: NULL pointer dereference
}

// TEST 13: NULL Pointer Dereference - After check
void test_null_deref_after_assign() {
    int *p;
    p = NULL;
    *p = 5;  // ERROR: NULL dereference
}

// TEST 14: Missing NULL Check - Basic
void test_missing_null_basic() {
    int *p;
    p = malloc(1000);
    *p = 5;  // WARNING: No NULL check
}

// TEST 15: Missing NULL Check - Combined declaration
void test_missing_null_combined() {
    int *p = malloc(2000);
    *p = 10;  // WARNING: No NULL check
}

// TEST 16: Missing NULL Check - calloc
void test_missing_null_calloc() {
    int *p;
    p = calloc(10, 4);
    *p = 15;  // WARNING: No NULL check
}

// TEST 17: Return Local Address - Basic
int* test_return_local_basic() {
    int x;
    x = 5;
    return &x;  // ERROR: Returning address of local variable
}

// TEST 18: Return Local Address - Pointer
int* test_return_local_ptr() {
    int y;
    y = 100;
    return &y;  // ERROR: Returning local address
}

/* ============================================================================
 * GROUP 3: BUFFER & STRING SECURITY ERRORS (3 patterns)
 * ============================================================================ */

// TEST 19: Write to Read-Only - String literal modification
void test_readonly_basic() {
    char *s;
    s = "hello";
    s[0] = 72;  // ERROR: Modifying string literal
}

// TEST 20: Write to Read-Only - Combined declaration
void test_readonly_combined() {
    char *s = "world";
    s[1] = 88;  // ERROR: Modifying string literal
}

// TEST 21: Write to Read-Only - Multiple accesses
void test_readonly_multiple() {
    char *s;
    s = "test";
    s[0] = 65;  // ERROR: First modification
    s[1] = 66;  // ERROR: Second modification
}

// TEST 22: Unsafe scanf - No width specifier
void test_scanf_unsafe_basic() {
    char s[20];
    scanf("%s", s);  // ERROR: Unbounded %s
}

// TEST 23: Unsafe scanf - Multiple format specifiers
void test_scanf_unsafe_multiple() {
    char name[30];
    int age;
    scanf("%s %d", name);  // ERROR: Unbounded %s
}

// TEST 24: Safe scanf - With width specifier
void test_scanf_safe() {
    char buffer[50];
    scanf("%49s", buffer);  // OK: Width specified
}

// TEST 25: Unsafe strcpy - String literal
void test_strcpy_unsafe_literal() {
    char dest[10];
    strcpy(dest, "this-is-way-too-long");  // ERROR: Buffer overflow + unsafe
}

// TEST 26: Unsafe strcpy - Variable
void test_strcpy_unsafe_var() {
    char dest[15];
    char src[20];
    strcpy(dest, src);  // ERROR: Unsafe function
}

// TEST 27: Unsafe gets
void test_gets_unsafe() {
    char buf[100];
    gets(buf);  // ERROR: gets() is unsafe
}

// TEST 28: Unsafe strcat
void test_strcat_unsafe() {
    char buf[50];
    strcat(buf, "data");  // ERROR: strcat is unsafe
}

// TEST 29: Unsafe sprintf
void test_sprintf_unsafe() {
    char buf[30];
    sprintf(buf, "formatted");  // ERROR: sprintf is unsafe
}

/* ============================================================================
 * CORRECT CODE TESTS (Should NOT report errors)
 * ============================================================================ */

// TEST 30: Correct malloc + free
void test_correct_malloc_free() {
    int *p;
    p = malloc(100);
    
    if (p == NULL) {  // NULL check present
        return;
    }
    
    *p = 42;
    free(p);  // Properly freed
    // No errors expected
}

// TEST 31: Correct with early return
void test_correct_early_return() {
    int *p;
    p = malloc(50);
    
    if (p == NULL) {
        return;  // OK: early return on NULL
    }
    
    *p = 10;
    free(p);
    // No errors expected
}

// TEST 32: Correct calloc usage
void test_correct_calloc() {
    int *arr;
    arr = calloc(10, 4);
    
    if (arr != NULL) {  // NULL check
        arr[0] = 5;
        free(arr);
    }
    // No errors expected
}

/* ============================================================================
 * SCOPE AND CONTROL FLOW TESTS
 * ============================================================================ */

// TEST 33: Nested scopes
void test_nested_scopes() {
    int *p;
    p = malloc(100);
    
    {
        int *q;
        q = malloc(50);
        free(q);  // Inner scope freed correctly
    }
    
    free(p);  // Outer scope freed correctly
    // No errors expected
}

// TEST 34: If-else branches
void test_if_else_branches() {
    int *p;
    p = malloc(100);
    
    if (p != NULL) {
        *p = 10;
        free(p);
    }
    // No errors expected (freed in if)
}

// TEST 35: While loop
void test_while_loop() {
    int *p;
    int i;
    i = 0;
    
    p = malloc(100);
    
    while (i < 5) {
        i = i + 1;
    }
    
    free(p);
    // No errors expected
}

// TEST 36: For loop
void test_for_loop() {
    int *p;
    int i;
    
    p = malloc(200);
    
    for (i = 0; i < 10; i = i + 1) {
        *p = i;
    }
    
    free(p);
    // No errors expected
}

/* ============================================================================
 * EDGE CASES AND COMPLEX SCENARIOS
 * ============================================================================ */

// TEST 37: Multiple pointers same scope
void test_multiple_pointers() {
    int *p;
    int *q;
    int *r;
    
    p = malloc(10);
    q = malloc(20);
    r = malloc(30);
    
    free(p);
    free(q);
    free(r);
    // No errors expected
}

// TEST 38: Reuse after free (correct)
void test_reuse_after_free() {
    int *p;
    
    p = malloc(100);
    free(p);
    
    p = malloc(200);  // Reassignment OK
    free(p);
    // No errors expected
}

// TEST 39: Array declarations
void test_arrays() {
    char buf1[50];
    char buf2[100];
    int arr[10];
    
    buf1[0] = 65;
    arr[0] = 10;
    // No errors expected
}

// TEST 40: Function calls in statements
void test_function_calls() {
    int *p;
    p = malloc(100);
    
    if (p == NULL) {
        return;
    }
    
    free(p);
    test_correct_malloc_free();  // Call another function
    // No errors expected
}

/* ============================================================================
 * MAIN FUNCTION
 * ============================================================================ */

int main() {
    // Memory Lifecycle
    test_leak_basic();
    test_leak_combined_decl();
    test_leak_multiple();
    test_double_free_basic();
    test_double_free_complex();
    test_invalid_free_stack();
    test_invalid_free_pointer();
    
    // Pointer State
    test_uaf_basic();
    test_uaf_read();
    test_null_deref_direct();
    test_null_deref_after_assign();
    test_missing_null_basic();
    test_missing_null_combined();
    test_missing_null_calloc();
    test_return_local_basic();
    test_return_local_ptr();
    
    // Buffer Security
    test_readonly_basic();
    test_readonly_combined();
    test_readonly_multiple();
    test_scanf_unsafe_basic();
    test_scanf_unsafe_multiple();
    test_strcpy_unsafe_literal();
    test_strcpy_unsafe_var();
    test_gets_unsafe();
    test_strcat_unsafe();
    test_sprintf_unsafe();
    
    // Correct code (no errors)
    test_correct_malloc_free();
    test_correct_early_return();
    test_correct_calloc();
    test_nested_scopes();
    test_if_else_branches();
    test_while_loop();
    test_for_loop();
    
    // Complex scenarios
    test_multiple_pointers();
    test_reuse_after_free();
    test_arrays();
    test_function_calls();
    
    return 0;
}
