%{
#include <stdio.h>
#include <string.h>
#include "y.tab.h"

/* MODIFICATION 1: Add colors and extern variable */
#define COLOR_RESET   "\033[0m"
#define COLOR_RED     "\033[1;31m"
extern int errors_found; /* Get global error count from y.tab.c */

int line_num = 1;
%}

%option noyywrap
%option noinput
%option nounput

%%

"malloc"        { return MALLOC; }
"calloc"        { return CALLOC; }
"realloc"       { return REALLOC; }
"free"          { return FREE; }
"return"        { return RETURN; }
"if"            { return IF; }
"else"          { return ELSE; }
"while"         { return WHILE; }
"for"           { return FOR; }
"int"           { return INT; }
"char"          { return CHAR; }
"void"          { return VOID; }
"scanf"         { return SCANF; }
"gets"          { return GETS; }
"strcpy"        { return STRCPY; }
"strcat"        { return STRCAT; }
"sprintf"       { return SPRINTF; }
"NULL"          { return NULLPTR; }

[a-zA-Z_][a-zA-Z0-9_]* { 
    yylval.str = strdup(yytext); 
    return IDENTIFIER; 
}

\"([^\\\"]|\\.)*\"  { 
    yylval.str = strdup(yytext); 
    return STRING_LITERAL; 
}

[0-9]+          { yylval.num = atoi(yytext); return NUMBER; }

"=="            { return EQUAL; }
"!="            { return NOTEQUAL; }
">"             { return GREATER; }
"<"             { return LESS; }
">="            { return GREATEQ; }
"<="            { return LESSEQ; }
"&&"            { return AND; }
"||"            { return OR; }
"!"             { return NOT; }
"+"             { return PLUS; }
"-"             { return MINUS; }

"*"             { return STAR; }
"&"             { return AMPERSAND; }
"="             { return ASSIGN; }
";"             { return SEMICOLON; }
","             { return COMMA; }
"("             { return LPAREN; }
")"             { return RPAREN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }
"["             { return LBRACKET; }
"]"             { return RBRACKET; }

"//".* { /* Single-line comment */ }
"/*"([^*]|\*+[^*/])*\*+"/"  { /* Multi-line comment */ }

[ \t]+          { /* Ignore whitespace */ }
\n              { line_num++; }

.               { 
/*
    printf("%sLexer Error:%s Unrecognized character '%s' at line %d\n", 
           COLOR_RED, COLOR_RESET, yytext, line_num);
    errors_found++; //Increment global error count 
    return UNKNOWN_CHAR; */
}

%%



