%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int line_num;
extern FILE *yyin;
int yylex();
void yyerror(const char *s);

/* ANSI Color codes */
#define COLOR_RESET   "\033[0m"
#define COLOR_RED     "\033[1;31m"
#define COLOR_YELLOW  "\033[93m"
#define COLOR_BLUE    "\033[1;34m"
#define COLOR_CYAN    "\033[1;36m"
#define COLOR_GREEN   "\033[1;32m"
#define COLOR_MAGENTA "\033[1;35m"

/* Data structures for tracking */
#define MAX_VARS 1000
#define MAX_SCOPE 100

typedef struct {
    char *name;
    int is_pointer;
    int is_malloced;
    int is_freed;
    int is_null_checked;
    int alloc_line;
    int free_line;
    int scope_level;
    int is_local;
    int is_string_literal;
    int array_size;
    int is_null;
} Variable;

Variable vars[MAX_VARS];
int var_count = 0;
int scope_level = 0;
int errors_found = 0;

/* Function prototypes */
Variable* find_var(char *name);
void add_var(char *name, int is_pointer, int is_local);
void mark_malloced(char *name, int line);
void mark_freed(char *name, int line);
void mark_null_checked(char *name);
void check_use_after_free(char *name, int line);
void check_null_deref(char *name, int line);
void check_memory_leaks();
void enter_scope();
void exit_scope();
void report_error(const char *type, int line, const char *msg);

%}

%union {
    char *str;
    int num;
}

%token <str> IDENTIFIER STRING_LITERAL
%token <num> NUMBER
%token MALLOC CALLOC REALLOC FREE RETURN IF ELSE WHILE FOR
%token INT CHAR VOID SCANF GETS STRCPY STRCAT SPRINTF NULLPTR
%token STAR AMPERSAND ASSIGN SEMICOLON COMMA
%token LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET
%token EQUAL NOTEQUAL GREATER LESS GREATEQ LESSEQ AND OR NOT PLUS MINUS

%token UNKNOWN_CHAR 

/*operator precedence */
%right NOT
%left AND
%left OR

%start program

%%

program:
    /* empty */
    | program statement
    | program function_def
    ;

function_def:
    type IDENTIFIER LPAREN params RPAREN block {
        check_memory_leaks();
    }
    | type STAR IDENTIFIER LPAREN params RPAREN block {
        check_memory_leaks();
    }
    ;

params:
    /* empty */
    | param_list
    ;

param_list:
    type STAR IDENTIFIER
    | type IDENTIFIER
    | param_list COMMA type STAR IDENTIFIER
    | param_list COMMA type IDENTIFIER
    ;

type:
    INT
    | CHAR
    | VOID
    ;

block:
    LBRACE { enter_scope(); } statements RBRACE { exit_scope(); }
    ;

statements:
    /* empty */
    | statements statement
    ;

statement:
    declaration SEMICOLON
    | assignment SEMICOLON
    | free_stmt SEMICOLON
    | function_call SEMICOLON
    | return_stmt SEMICOLON
    | if_stmt
    | loop_stmt
    | block
    | SEMICOLON

    | error SEMICOLON 
    ;

declaration:
    type STAR IDENTIFIER {
        add_var($3, 1, scope_level > 0);
    }
    | type STAR IDENTIFIER ASSIGN MALLOC LPAREN NUMBER RPAREN {
        add_var($3, 1, scope_level > 0);
        mark_malloced($3, line_num);
        report_error("MISSING_NULL_CHECK", line_num, 
            "No NULL check after malloc - could cause segfault if allocation fails");
    }
    | type STAR IDENTIFIER ASSIGN CALLOC LPAREN NUMBER COMMA NUMBER RPAREN {
        add_var($3, 1, scope_level > 0);
        mark_malloced($3, line_num);
        report_error("MISSING_NULL_CHECK", line_num, 
            "No NULL check after calloc - could cause segfault if allocation fails");
    }
    | type IDENTIFIER LBRACKET NUMBER RBRACKET {
        add_var($2, 0, scope_level > 0);
        Variable *v = find_var($2);
        if (v) v->array_size = $4;
    }
    | type IDENTIFIER {
        add_var($2, 0, scope_level > 0);
    }
    | type STAR IDENTIFIER ASSIGN STRING_LITERAL {
        add_var($3, 1, scope_level > 0);
        Variable *v = find_var($3);
        if (v) v->is_string_literal = 1;
    }
    | type IDENTIFIER LBRACKET RBRACKET ASSIGN STRING_LITERAL {
        add_var($2, 0, scope_level > 0);
        Variable *v = find_var($2);
        if (v) v->is_string_literal = 0;
    }
    ;

assignment:
    IDENTIFIER ASSIGN MALLOC LPAREN NUMBER RPAREN {
        mark_malloced($1, line_num);
        report_error("MISSING_NULL_CHECK", line_num, 
            "No NULL check after malloc - could cause segfault if allocation fails");
    }
    | IDENTIFIER ASSIGN CALLOC LPAREN NUMBER COMMA NUMBER RPAREN {
        mark_malloced($1, line_num);
        report_error("MISSING_NULL_CHECK", line_num, 
            "No NULL check after calloc - could cause segfault if allocation fails");
    }
    | IDENTIFIER ASSIGN NULLPTR {
        Variable *v = find_var($1);
        if (v) {
            v->is_null_checked = 1;
            v->is_null = 1;
        }
    }
    | IDENTIFIER ASSIGN STRING_LITERAL {
        Variable *v = find_var($1);
        if (v && v->is_pointer) {
            v->is_string_literal = 1;
        }
    }
    | IDENTIFIER ASSIGN NUMBER
    | STAR IDENTIFIER ASSIGN NUMBER {
        Variable *v = find_var($2);
        if (v && v->is_null) {
            report_error("NULL_POINTER_DEREF", line_num, 
                "Dereferencing NULL pointer - will cause segfault");
        }
        check_use_after_free($2, line_num);
    }
    | IDENTIFIER LBRACKET NUMBER RBRACKET ASSIGN NUMBER {
        Variable *v = find_var($1);
        if (v && v->is_string_literal) {
            report_error("WRITE_TO_READONLY", line_num, 
                "Attempting to modify string literal - will cause segfault");
        }
    }
    ;

free_stmt:
    FREE LPAREN IDENTIFIER RPAREN {
        mark_freed($3, line_num);
    }
    | FREE LPAREN AMPERSAND IDENTIFIER RPAREN {
        report_error("INVALID_FREE", line_num, 
            "Attempting to free address of stack variable - will cause segfault");
    }
    ;

function_call:
    GETS LPAREN IDENTIFIER RPAREN {
        report_error("UNSAFE_FUNCTION", line_num, 
            "gets() is unsafe and deprecated - use fgets() instead");
    }
    | SCANF LPAREN STRING_LITERAL COMMA IDENTIFIER RPAREN {
        if (strstr($3, "%s") != NULL) {
            int has_width = 0;
            char *fmt = $3;
            for (int i = 0; fmt[i]; i++) {
                if (fmt[i] == '%' && fmt[i+1] == 's') {
                    if (i > 0 && fmt[i-1] >= '0' && fmt[i-1] <= '9') {
                        has_width = 1;
                    }
                }
            }
            if (!has_width) {
                report_error("BUFFER_OVERFLOW", line_num, 
                    "scanf with unbounded %s can cause buffer overflow - use width specifier");
            }
        }
    }
    | STRCPY LPAREN IDENTIFIER COMMA STRING_LITERAL RPAREN {
        Variable *v = find_var($3);
        if (v && v->array_size > 0) {
            int src_len = strlen($5) - 2;
            if (src_len >= v->array_size) {
                report_error("BUFFER_OVERFLOW", line_num, 
                    "strcpy: source string too large for destination buffer");
            }
        }
        report_error("UNSAFE_FUNCTION", line_num, 
            "strcpy is unsafe - use strncpy() instead");
    }
    | STRCPY LPAREN IDENTIFIER COMMA IDENTIFIER RPAREN {
        report_error("UNSAFE_FUNCTION", line_num, 
            "strcpy is unsafe - use strncpy() instead");
    }
    | STRCAT LPAREN IDENTIFIER COMMA IDENTIFIER RPAREN {
        report_error("UNSAFE_FUNCTION", line_num, 
            "strcat is unsafe - use strncat() instead");
    }
    | STRCAT LPAREN IDENTIFIER COMMA STRING_LITERAL RPAREN {
        report_error("UNSAFE_FUNCTION", line_num, 
            "strcat is unsafe - use strncat() instead");
    }
    | SPRINTF LPAREN IDENTIFIER COMMA STRING_LITERAL RPAREN {
        report_error("UNSAFE_FUNCTION", line_num, 
            "sprintf is unsafe - use snprintf() instead");
    }
    | IDENTIFIER LPAREN RPAREN
    | IDENTIFIER LPAREN arg_list RPAREN
    ;

arg_list:
    IDENTIFIER
    | NUMBER
    | STRING_LITERAL
    | arg_list COMMA IDENTIFIER
    | arg_list COMMA NUMBER
    | arg_list COMMA STRING_LITERAL
    ;

return_stmt:
    RETURN AMPERSAND IDENTIFIER {
        Variable *v = find_var($3);
        if (v && v->is_local) {
            report_error("RETURN_LOCAL_ADDRESS", line_num, 
                "Returning address of local variable - will cause dangling pointer");
        }
    }
    | RETURN IDENTIFIER
    | RETURN NUMBER
    | RETURN
    ;

if_stmt:
    IF LPAREN condition RPAREN block
    | IF LPAREN condition RPAREN block ELSE block
    ;
    
condition:
    IDENTIFIER
    | IDENTIFIER EQUAL EQUAL NULLPTR { 
        mark_null_checked($1); 
    }
    | IDENTIFIER NOTEQUAL EQUAL NULLPTR { 
        mark_null_checked($1); 
    }
    | IDENTIFIER EQUAL EQUAL NUMBER
    | IDENTIFIER NOTEQUAL EQUAL NUMBER
    | IDENTIFIER GREATER NUMBER
    | IDENTIFIER LESS NUMBER
    | STAR IDENTIFIER {
        check_use_after_free($2, line_num);
    }
    | STAR IDENTIFIER EQUAL EQUAL NUMBER
    | condition AND condition
    | condition OR condition
    | NOT condition
    ;

loop_stmt:
    WHILE LPAREN condition RPAREN block
    | FOR LPAREN for_init SEMICOLON for_cond SEMICOLON for_inc RPAREN block
    ;

for_init:
    /* empty */
    | declaration
    | assignment
    ;

for_cond:
    /* empty */
    | condition
    ;

for_inc:
    /* empty */
    | assignment
%%

/* * MODIFICATION 3: Replace the empty yyerror function.
 * This will now print a useful message when a syntax error is found.
 */
void yyerror(const char *s) {
    // 's' is the default "syntax error" message.
    //printf("%sSyntax Error:%s at line %d. Attempting to recover by skipping to next ';'.\n", 
      //     COLOR_RED, COLOR_RESET, line_num);
    // No need to increment errors_found here, the lexer will do it.
}

Variable* find_var(char *name) {
    for (int i = var_count - 1; i >= 0; i--) {
        if (strcmp(vars[i].name, name) == 0 && vars[i].scope_level <= scope_level) {
            return &vars[i];
        }
    }
    return NULL;
}

void add_var(char *name, int is_pointer, int is_local) {
    if (var_count >= MAX_VARS) return;
    
    vars[var_count].name = strdup(name);
    vars[var_count].is_pointer = is_pointer;
    vars[var_count].is_malloced = 0;
    vars[var_count].is_freed = 0;
    vars[var_count].is_null_checked = 0;
    vars[var_count].alloc_line = 0;
    vars[var_count].free_line = 0;
    vars[var_count].scope_level = scope_level;
    vars[var_count].is_local = is_local;
    vars[var_count].is_string_literal = 0;
    vars[var_count].array_size = 0;
    vars[var_count].is_null = 0;
    var_count++;
}

void mark_malloced(char *name, int line) {
    Variable *v = find_var(name);
    if (v) {
        v->is_malloced = 1;
        v->alloc_line = line;
        v->is_freed = 0;
        v->is_null = 0;
    }
}

void mark_freed(char *name, int line) {
    Variable *v = find_var(name);
    if (!v) {
        report_error("INVALID_FREE", line, "Freeing undefined variable");
        return;
    }
    
    if (!v->is_pointer) {
        report_error("INVALID_FREE", line, 
            "Attempting to free non-pointer variable - will cause segfault");
        return;
    }
    
    if (!v->is_malloced) {
        report_error("INVALID_FREE", line, 
            "Freeing pointer not allocated with malloc - will cause segfault");
        return;
    }
    
    if (v->is_freed) {
        char msg[200];
        snprintf(msg, sizeof(msg), 
            "Double free detected - pointer already freed at line %d", v->free_line);
        report_error("DOUBLE_FREE", line, msg);
        return;
    }
    
    v->is_freed = 1;
    v->free_line = line;
}

void check_use_after_free(char *name, int line) {
    Variable *v = find_var(name);
    if (v && v->is_freed) {
        report_error("USE_AFTER_FREE", line, 
            "Using pointer after free - dangling pointer causes segfault");
    }
}

void check_null_deref(char *name, int line) {
    Variable *v = find_var(name);
    if (v) {
        // Check if pointer is NULL
        if (v->is_pointer && !v->is_malloced && !v->is_null_checked) {
            // Could be uninitialized or NULL
        }
        // Check if malloc'd pointer used without NULL check
        if (v->is_malloced && !v->is_null_checked && !v->is_freed) {
            report_error("NULL_DEREF_RISK", line, 
                "Dereferencing pointer without NULL check - could segfault if malloc failed");
        }
    }
}

void mark_null_checked(char *name) {
    Variable *v = find_var(name);
    if (v) v->is_null_checked = 1;
}

void check_memory_leaks() {
    for (int i = 0; i < var_count; i++) {
        if (vars[i].is_malloced && !vars[i].is_freed && 
            vars[i].scope_level <= scope_level) {
            char msg[200];
            snprintf(msg, sizeof(msg), 
                "Memory leak: '%s' allocated at line %d but never freed", 
                vars[i].name, vars[i].alloc_line);
            report_error("MEMORY_LEAK", vars[i].alloc_line, msg);
        }
    }
}

void enter_scope() {
    scope_level++;
}

void exit_scope() {
    check_memory_leaks();
    
    int new_count = 0;
    for (int i = 0; i < var_count; i++) {
        if (vars[i].scope_level < scope_level) {
            vars[new_count++] = vars[i];
        }
    }
    var_count = new_count;
    scope_level--;
}

void report_error(const char *type, int line, const char *msg) {
    // Determine color based on error type
    /*
    const char *color = COLOR_RED;
    const char *prefix = "Runtime Error:";
    
    if (strstr(type, "LEAK") != NULL) {
        color = COLOR_YELLOW;
        prefix = "Runtime Warning:";
    } else if (strstr(type, "UNSAFE") != NULL) {
        color = COLOR_YELLOW;
        prefix = "Runtime Warning:";
    } else if (strstr(type, "MISSING_NULL") != NULL) {
        color = COLOR_YELLOW;
        prefix = "Runtime Warning:";
    } else if (strstr(type, "BUFFER") != NULL) {
        color = COLOR_RED;
        prefix = "Runtime Error:";
    }
    */
    printf("Line %d: %s[%s]%s %s\n", line, COLOR_YELLOW, type, COLOR_RESET, msg);
    errors_found++;
}

int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Cannot open file: %s\n", argv[1]);
            return 1;
        }
    }
    
    //printf("%s=== C Runtime Error Static Analyzer ===%s\n", COLOR_CYAN, COLOR_RESET);
    //printf("Analyzing for 10 critical error patterns...\n\n");
    
    yyparse();
    /*
    printf("\n%s=== Analysis Complete ===%s\n", COLOR_CYAN, COLOR_RESET);
    if (errors_found > 0) {
        printf("%sTotal errors found: %d%s\n", COLOR_RED, errors_found, COLOR_RESET);
    } else {
        printf("%sTotal errors found: %d%s\n", COLOR_GREEN, errors_found, COLOR_RESET);
    }
    */
    if (yyin && yyin != stdin) fclose(yyin);
    return 0;
}


