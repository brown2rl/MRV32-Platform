/* Kilo -- A very simple editor in less than 1-kilo lines of code (as counted
 *         by "cloc"). Does not depend on libcurses, directly emits VT100
 *         escapes on the terminal.
 *
 * -----------------------------------------------------------------------
 *
 * Copyright (C) 2016 Salvatore Sanfilippo <antirez at gmail dot com>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *  *  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *
 *  *  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * -----------------------------------------------------------------------
 *
 * Modified for RISCVRAM kernel — replaces all standard headers with minilib.h.
 * Changes from original marked with "RISCVRAM:" comments.
 */

#define KILO_VERSION "0.0.1"

/* RISCVRAM: single header replaces all of libc + POSIX */
#include "minilib.h"

/* Syntax highlight types */
#define HL_NORMAL 0
#define HL_NONPRINT 1
#define HL_COMMENT 2   /* Single line comment. */
#define HL_MLCOMMENT 3 /* Multi-line comment. */
#define HL_KEYWORD1 4
#define HL_KEYWORD2 5
#define HL_STRING 6
#define HL_NUMBER 7
#define HL_MATCH 8      /* Search match. */

#define HL_HIGHLIGHT_STRINGS (1<<0)
#define HL_HIGHLIGHT_NUMBERS (1<<1)

struct editorSyntax {
    char **filematch;
    char **keywords;
    char singleline_comment_start[2];
    char multiline_comment_start[3];
    char multiline_comment_end[3];
    int flags;
};

/* This structure represents a single line of the file we are editing. */
typedef struct erow {
    int idx;            /* Row index in the file, zero-based. */
    int size;           /* Size of the row, excluding the null term. */
    int rsize;          /* Size of the rendered row. */
    char *chars;        /* Row content. */
    char *render;       /* Row content "rendered" for screen (for TABs). */
    unsigned char *hl;  /* Syntax highlight type for each character in render.*/
    int hl_oc;          /* Row had open comment at end in last syntax highlight
                           check. */
} erow;

typedef struct hlcolor {
    int r,g,b;
} hlcolor;

struct editorConfig {
    int cx,cy;  /* Cursor x and y position in characters */
    int rowoff;     /* Offset of row displayed. */
    int coloff;     /* Offset of column displayed. */
    int screenrows; /* Number of rows that we can show */
    int screencols; /* Number of cols that we can show */
    int numrows;    /* Number of rows */
    int rawmode;    /* Is terminal raw mode enabled? */
    erow *row;      /* Rows */
    int dirty;      /* File modified but not saved. */
    char *filename; /* Currently open filename */
    char statusmsg[80];
    time_t statusmsg_time;
    struct editorSyntax *syntax;    /* Current syntax highlight, or NULL. */
};

static struct editorConfig E;

enum KEY_ACTION{
        KEY_NULL = 0,       /* NULL */
        CTRL_C = 3,         /* Ctrl-c */
        CTRL_D = 4,         /* Ctrl-d */
        CTRL_F = 6,         /* Ctrl-f */
        CTRL_H = 8,         /* Ctrl-h */
        TAB = 9,            /* Tab */
        CTRL_L = 12,        /* Ctrl+l */
        ENTER = 13,         /* Enter */
        CTRL_Q = 17,        /* Ctrl-q */
        CTRL_S = 19,        /* Ctrl-s */
        CTRL_U = 21,        /* Ctrl-u */
        ESC = 27,           /* Escape */
        BACKSPACE =  127,   /* Backspace */
        /* The following are just soft codes, not really reported by the
         * terminal directly. */
        ARROW_LEFT = 1000,
        ARROW_RIGHT,
        ARROW_UP,
        ARROW_DOWN,
        DEL_KEY,
        HOME_KEY,
        END_KEY,
        PAGE_UP,
        PAGE_DOWN
};

void editorSetStatusMessage(const char *fmt, ...);

/* =========================== Syntax highlights DB =========================
 *
 * In order to add a new syntax, define two arrays with a list of file name
 * matches and keywords. The file name matches are used in order to match
 * a given syntax with a given file name: if a match pattern starts with a
 * dot, it is matched as the last past of the filename, for example ".c".
 * Otherwise the pattern is just searched inside the filenme, like "Makefile").
 *
 * The list of keywords to highlight is just a list of words, however if they
 * a trailing '|' character is added at the end, they are highlighted in
 * a different color, so that you can have two different sets of keywords.
 *
 * Finally add a stanza in the HLDB global variable with two two arrays
 * of strings, and a set of flags in order to enable highlighting of
 * comments and numbers.
 *
 * The characters for single and multi line comments must be exactly two
 * and must be provided as well (see the C language example).
 *
 * There is no support to highlight patterns currently. */

/* C / C++ */
char *C_HL_extensions[] = {".c",".h",".cpp",".hpp",".cc",NULL};
char *C_HL_keywords[] = {
    /* C Keywords */
    "auto","break","case","continue","default","do","else","enum",
    "extern","for","goto","if","register","return","sizeof","static",
    "struct","switch","typedef","union","volatile","while","NULL",

    /* C++ Keywords */
    "alignas","alignof","and","and_eq","asm","bitand","bitor","class",
    "compl","constexpr","const_cast","deltype","delete","dynamic_cast",
    "explicit","export","false","friend","inline","mutable","namespace",
    "new","noexcept","not","not_eq","nullptr","operator","or","or_eq",
    "private","protected","public","reinterpret_cast","static_assert",
    "static_cast","template","this","thread_local","throw","true","try",
    "typeid","typename","virtual","xor","xor_eq",

    /* C types */
    "int|","long|","double|","float|","char|","unsigned|","signed|",
    "void|","short|","auto|","const|","bool|",NULL
};

/* Here we define an array of syntax highlights by extensions, keywords,
 * comments delimiters and flags. */
struct editorSyntax HLDB[] = {
    {
        /* C / C++ */
        C_HL_extensions,
        C_HL_keywords,
        "//","/*","*/",
        HL_HIGHLIGHT_STRINGS | HL_HIGHLIGHT_NUMBERS
    }
};

#define HLDB_ENTRIES (sizeof(HLDB)/sizeof(HLDB[0]))

/* ======================= Low level terminal handling ====================== */

/* RISCVRAM: No termios.  Your kernel's sys_read_raw (a3=1) already delivers
 * single raw bytes without echo or line buffering — that IS raw mode.
 * We keep the rawmode flag so the rest of kilo's logic is undisturbed. */

void disableRawMode(int fd) {
    (void)fd;
    /* RISCVRAM: Nothing to restore — the kernel has no cooked-mode layer.
     * If you later add one, send the "disable raw" command here. */
    E.rawmode = 0;
}

void editorAtExit(void) {
    disableRawMode(STDIN_FILENO);
    write(STDOUT_FILENO, "\x1b[?25h\x1b[2J\x1b[H", 14);
}

int enableRawMode(int fd) {
    (void)fd;
    if (E.rawmode) return 0;
    atexit(editorAtExit);
    E.rawmode = 1;
    return 0;
}

/* RISCVRAM: Read a single raw byte from the terminal.
 *
 * Uses sys_read_raw (a3=1) which your kernel exposes for uncooked,
 * single-byte, non-blocking(ish) reads.
 *
 * IMPORTANT: If your sys_read_raw BLOCKS when no byte is available, then
 * pressing bare ESC will hang until the next keypress.  Two fixes:
 *   (a) Make sys_read_raw return 0 when no byte is pending (preferred), or
 *   (b) Add a timeout syscall and wire it in here.
 * If sys_read_raw returns 0 for "no data", the code below works correctly
 * as a drop-in replacement for the original VTIME=1 behavior.
 */
static int tty_read_byte(char *c)
{
    return (int)sys_read_raw(STDIN_FILENO, c);
}

/* Read a key from the terminal, trying to handle escape sequences. */
int editorReadKey(int fd) {
    int nread;
    char c, seq[3];
    (void)fd;

    /* RISCVRAM: spin until we get a byte. */
    while ((nread = tty_read_byte(&c)) == 0);
    if (nread == -1) exit(1);

    while(1) {
        switch(c) {
        case ESC:    /* escape sequence */
            /* If this is just an ESC, we'll timeout here. */
            if (tty_read_byte(seq) == 0) return ESC;
            if (tty_read_byte(seq+1) == 0) return ESC;

            /* ESC [ sequences. */
            if (seq[0] == '[') {
                if (seq[1] >= '0' && seq[1] <= '9') {
                    /* Extended escape, read additional byte. */
                    if (tty_read_byte(seq+2) == 0) return ESC;
                    if (seq[2] == '~') {
                        switch(seq[1]) {
                        case '3': return DEL_KEY;
                        case '5': return PAGE_UP;
                        case '6': return PAGE_DOWN;
                        }
                    }
                } else {
                    switch(seq[1]) {
                    case 'A': return ARROW_UP;
                    case 'B': return ARROW_DOWN;
                    case 'C': return ARROW_RIGHT;
                    case 'D': return ARROW_LEFT;
                    case 'H': return HOME_KEY;
                    case 'F': return END_KEY;
                    }
                }
            }

            /* ESC O sequences. */
            else if (seq[0] == 'O') {
                switch(seq[1]) {
                case 'H': return HOME_KEY;
                case 'F': return END_KEY;
                }
            }
            break;
        default:
            return c;
        }
    }
}

/* Use the ESC [6n escape sequence to query the horizontal cursor position
 * and return it. On error -1 is returned, on success the position of the
 * cursor is stored at *rows and *cols and 0 is returned. */
int getCursorPosition(int ifd, int ofd, int *rows, int *cols) {
    char buf[32];
    unsigned int i = 0;
    (void)ifd;

    /* Report cursor location */
    if (write(ofd, "\x1b[6n", 4) != 4) return -1;

    /* Read the response: ESC [ rows ; cols R */
    /* RISCVRAM: use sys_read_raw so we get bytes without echo */
    while (i < sizeof(buf)-1) {
        if (tty_read_byte(buf+i) != 1) break;
        if (buf[i] == 'R') break;
        i++;
    }
    buf[i] = '\0';

    /* Parse it. */
    if (buf[0] != ESC || buf[1] != '[') return -1;
    if (sscanf(buf+2,"%d;%d",rows,cols) != 2) return -1;
    return 0;
}

/* RISCVRAM: No ioctl(TIOCGWINSZ).  Always use the escape-sequence probe.
 * PuTTY responds to this correctly. */
int getWindowSize(int ifd, int ofd, int *rows, int *cols) {
    int orig_row, orig_col, retval;

    /* Get the initial position so we can restore it later. */
    retval = getCursorPosition(ifd,ofd,&orig_row,&orig_col);
    if (retval == -1) goto failed;

    /* Go to right/bottom margin and get position. */
    if (write(ofd,"\x1b[999C\x1b[999B",12) != 12) goto failed;
    retval = getCursorPosition(ifd,ofd,rows,cols);
    if (retval == -1) goto failed;

    /* Restore position. */
    char seq[32];
    snprintf(seq,32,"\x1b[%d;%dH",orig_row,orig_col);
    if (write(ofd,seq,strlen(seq)) == -1) {
        /* Can't recover... */
    }
    return 0;

failed:
    return -1;
}

/* ====================== Syntax highlight color scheme  ==================== */

int is_separator(int c) {
    return c == '\0' || isspace(c) || strchr(",.()+-/*=~%[];",c) != NULL;
}

/* Return true if the specified row last char is part of a multi line comment
 * that starts at this row or at one before, and does not end at the end
 * of the row but spawns to the next row. */
int editorRowHasOpenComment(erow *row) {
    if (row->hl && row->rsize && row->hl[row->rsize-1] == HL_MLCOMMENT &&
        (row->rsize < 2 || (row->render[row->rsize-2] != '*' ||
                            row->render[row->rsize-1] != '/'))) return 1;
    return 0;
}

/* Set every byte of row->hl (that corresponds to every character in the line)
 * to the right syntax highlight type (HL_* defines). */
void editorUpdateSyntax(erow *row) {
    row->hl = realloc(row->hl,row->rsize);
    memset(row->hl,HL_NORMAL,row->rsize);

    if (E.syntax == NULL) return; /* No syntax, everything is HL_NORMAL. */

    int i, prev_sep, in_string, in_comment;
    char *p;
    char **keywords = E.syntax->keywords;
    char *scs = E.syntax->singleline_comment_start;
    char *mcs = E.syntax->multiline_comment_start;
    char *mce = E.syntax->multiline_comment_end;

    /* Point to the first non-space char. */
    p = row->render;
    i = 0; /* Current char offset */
    while(*p && isspace(*p)) {
        p++;
        i++;
    }
    prev_sep = 1; /* Tell the parser if 'i' points to start of word. */
    in_string = 0; /* Are we inside "" or '' ? */
    in_comment = 0; /* Are we inside multi-line comment? */

    /* If the previous line has an open comment, this line starts
     * with an open comment state. */
    if (row->idx > 0 && editorRowHasOpenComment(&E.row[row->idx-1]))
        in_comment = 1;

    while(*p) {
        /* Handle // comments. */
        if (prev_sep && *p == scs[0] && *(p+1) == scs[1]) {
            /* From here to end is a comment */
            memset(row->hl+i,HL_COMMENT,row->size-i);
            return;
        }

        /* Handle multi line comments. */
        if (in_comment) {
            row->hl[i] = HL_MLCOMMENT;
            if (*p == mce[0] && *(p+1) == mce[1]) {
                row->hl[i+1] = HL_MLCOMMENT;
                p += 2; i += 2;
                in_comment = 0;
                prev_sep = 1;
                continue;
            } else {
                prev_sep = 0;
                p++; i++;
                continue;
            }
        } else if (*p == mcs[0] && *(p+1) == mcs[1]) {
            row->hl[i] = HL_MLCOMMENT;
            row->hl[i+1] = HL_MLCOMMENT;
            p += 2; i += 2;
            in_comment = 1;
            prev_sep = 0;
            continue;
        }

        /* Handle "" and '' */
        if (in_string) {
            row->hl[i] = HL_STRING;
            if (*p == '\\') {
                row->hl[i+1] = HL_STRING;
                p += 2; i += 2;
                prev_sep = 0;
                continue;
            }
            if (*p == in_string) in_string = 0;
            p++; i++;
            continue;
        } else {
            if (*p == '"' || *p == '\'') {
                in_string = *p;
                row->hl[i] = HL_STRING;
                p++; i++;
                prev_sep = 0;
                continue;
            }
        }

        /* Handle non printable chars. */
        if (!isprint(*p)) {
            row->hl[i] = HL_NONPRINT;
            p++; i++;
            prev_sep = 0;
            continue;
        }

        /* Handle numbers */
        if ((isdigit(*p) && (prev_sep || row->hl[i-1] == HL_NUMBER)) ||
            (*p == '.' && i >0 && row->hl[i-1] == HL_NUMBER)) {
            row->hl[i] = HL_NUMBER;
            p++; i++;
            prev_sep = 0;
            continue;
        }

        /* Handle keywords and lib calls */
        if (prev_sep) {
            int j;
            for (j = 0; keywords[j]; j++) {
                int klen = strlen(keywords[j]);
                int kw2 = keywords[j][klen-1] == '|';
                if (kw2) klen--;

                if (!memcmp(p,keywords[j],klen) &&
                    is_separator(*(p+klen)))
                {
                    /* Keyword */
                    memset(row->hl+i,kw2 ? HL_KEYWORD2 : HL_KEYWORD1,klen);
                    p += klen;
                    i += klen;
                    break;
                }
            }
            if (keywords[j] != NULL) {
                prev_sep = 0;
                continue; /* We had a keyword match */
            }
        }

        /* Not special chars */
        prev_sep = is_separator(*p);
        p++; i++;
    }

    /* Propagate syntax change to the next row if the open commen
     * state changed. This may recursively affect all the following rows
     * in the file. */
    int oc = editorRowHasOpenComment(row);
    if (row->hl_oc != oc && row->idx+1 < E.numrows)
        editorUpdateSyntax(&E.row[row->idx+1]);
    row->hl_oc = oc;
}

/* Maps syntax highlight token types to terminal colors. */
int editorSyntaxToColor(int hl) {
    switch(hl) {
    case HL_COMMENT:
    case HL_MLCOMMENT: return 36;     /* cyan */
    case HL_KEYWORD1: return 33;    /* yellow */
    case HL_KEYWORD2: return 32;    /* green */
    case HL_STRING: return 35;      /* magenta */
    case HL_NUMBER: return 31;      /* red */
    case HL_MATCH: return 34;      /* blu */
    default: return 37;             /* white */
    }
}

/* Select the syntax highlight scheme depending on the filename,
 * setting it in the global state E.syntax. */
void editorSelectSyntaxHighlight(char *filename) {
    for (unsigned int j = 0; j < HLDB_ENTRIES; j++) {
        struct editorSyntax *s = HLDB+j;
        unsigned int i = 0;
        while(s->filematch[i]) {
            char *p;
            int patlen = strlen(s->filematch[i]);
            if ((p = strstr(filename,s->filematch[i])) != NULL) {
                if (s->filematch[i][0] != '.' || p[patlen] == '\0') {
                    E.syntax = s;
                    return;
                }
            }
            i++;
        }
    }
}

/* ======================= Editor rows implementation ======================= */

/* Update the rendered version and the syntax highlight of a row. */
void editorUpdateRow(erow *row) {
    unsigned int tabs = 0, nonprint = 0;
    int j, idx;

   /* Create a version of the row we can directly print on the screen,
     * respecting tabs, substituting non printable characters with '?'. */
    free(row->render);
    for (j = 0; j < row->size; j++)
        if (row->chars[j] == TAB) tabs++;

    unsigned long long allocsize =
        (unsigned long long) row->size + tabs*8 + nonprint*9 + 1;
    if (allocsize > UINT32_MAX) {
        printf("Some line of the edited file is too long for kilo\n");
        exit(1);
    }

    row->render = malloc(row->size + tabs*8 + nonprint*9 + 1);
    idx = 0;
    for (j = 0; j < row->size; j++) {
        if (row->chars[j] == TAB) {
            row->render[idx++] = ' ';
            while((idx+1) % 8 != 0) row->render[idx++] = ' ';
        } else {
            row->render[idx++] = row->chars[j];
        }
    }
    row->rsize = idx;
    row->render[idx] = '\0';

    /* Update the syntax highlighting attributes of the row. */
    editorUpdateSyntax(row);
}

/* Insert a row at the specified position, shifting the other rows on the bottom
 * if required. */
void editorInsertRow(int at, char *s, size_t len) {
    if (at > E.numrows) return;
    E.row = realloc(E.row,sizeof(erow)*(E.numrows+1));
    if (at != E.numrows) {
        memmove(E.row+at+1,E.row+at,sizeof(E.row[0])*(E.numrows-at));
        for (int j = at+1; j <= E.numrows; j++) E.row[j].idx++;
    }
    E.row[at].size = len;
    E.row[at].chars = malloc(len+1);
    if (!E.row[at].chars) mini_printf("CHARS ALLOC FAIL row %d\n", at);
    memcpy(E.row[at].chars,s,len+1);
    E.row[at].hl = NULL;
    E.row[at].hl_oc = 0;
    E.row[at].render = NULL;
    E.row[at].rsize = 0;
    E.row[at].idx = at;
    editorUpdateRow(E.row+at);
    E.numrows++;
    E.dirty++;
}

/* Free row's heap allocated stuff. */
void editorFreeRow(erow *row) {
    free(row->render);
    free(row->chars);
    free(row->hl);
}

/* Remove the row at the specified position, shifting the remainign on the
 * top. */
void editorDelRow(int at) {
    erow *row;

    if (at >= E.numrows) return;
    row = E.row+at;
    editorFreeRow(row);
    memmove(E.row+at,E.row+at+1,sizeof(E.row[0])*(E.numrows-at-1));
    for (int j = at; j < E.numrows-1; j++) E.row[j].idx++;
    E.numrows--;
    E.dirty++;
}

/* Turn the editor rows into a single heap-allocated string.
 * Returns the pointer to the heap-allocated string and populate the
 * integer pointed by 'buflen' with the size of the string, escluding
 * the final nulterm. */
char *editorRowsToString(int *buflen) {
    char *buf = NULL, *p;
    int totlen = 0;
    int j;

    /* Compute count of bytes */
    for (j = 0; j < E.numrows; j++)
        totlen += E.row[j].size+1; /* +1 is for "\n" at end of every row */
    *buflen = totlen;
    totlen++; /* Also make space for nulterm */

    p = buf = malloc(totlen);
    for (j = 0; j < E.numrows; j++) {
        memcpy(p,E.row[j].chars,E.row[j].size);
        p += E.row[j].size;
        *p = '\n';
        p++;
    }
    *p = '\0';
    return buf;
}

/* Insert a character at the specified position in a row, moving the remaining
 * chars on the right if needed. */
void editorRowInsertChar(erow *row, int at, int c) {
    if (at > row->size) {
        /* Pad the string with spaces if the insert location is outside the
         * current length by more than a single character. */
        int padlen = at-row->size;
        /* In the next line +2 means: new char and null term. */
        row->chars = realloc(row->chars,row->size+padlen+2);
        memset(row->chars+row->size,' ',padlen);
        row->chars[row->size+padlen+1] = '\0';
        row->size += padlen+1;
    } else {
        /* If we are in the middle of the string just make space for 1 new
         * char plus the (already existing) null term. */
        row->chars = realloc(row->chars,row->size+2);
        memmove(row->chars+at+1,row->chars+at,row->size-at+1);
        row->size++;
    }
    row->chars[at] = c;
    editorUpdateRow(row);
    E.dirty++;
}

/* Append the string 's' at the end of a row */
void editorRowAppendString(erow *row, char *s, size_t len) {
    row->chars = realloc(row->chars,row->size+len+1);
    memcpy(row->chars+row->size,s,len);
    row->size += len;
    row->chars[row->size] = '\0';
    editorUpdateRow(row);
    E.dirty++;
}

/* Delete the character at offset 'at' from the specified row. */
void editorRowDelChar(erow *row, int at) {
    if (row->size <= at) return;
    memmove(row->chars+at,row->chars+at+1,row->size-at);
    editorUpdateRow(row);
    row->size--;
    E.dirty++;
}

/* Insert the specified char at the current prompt position. */
void editorInsertChar(int c) {
    int filerow = E.rowoff+E.cy;
    int filecol = E.coloff+E.cx;
    erow *row = (filerow >= E.numrows) ? NULL : &E.row[filerow];

    /* If the row where the cursor is currently located does not exist in our
     * logical representaion of the file, add enough empty rows as needed. */
    if (!row) {
        while(E.numrows <= filerow)
            editorInsertRow(E.numrows,"",0);
    }
    row = &E.row[filerow];
    editorRowInsertChar(row,filecol,c);
    if (E.cx == E.screencols-1)
        E.coloff++;
    else
        E.cx++;
    E.dirty++;
}

/* Inserting a newline is slightly complex as we have to handle inserting a
 * newline in the middle of a line, splitting the line as needed. */
void editorInsertNewline(void) {
    int filerow = E.rowoff+E.cy;
    int filecol = E.coloff+E.cx;
    erow *row = (filerow >= E.numrows) ? NULL : &E.row[filerow];

    if (!row) {
        if (filerow == E.numrows) {
            editorInsertRow(filerow,"",0);
            goto fixcursor;
        }
        return;
    }
    /* If the cursor is over the current line size, we want to conceptually
     * think it's just over the last character. */
    if (filecol >= row->size) filecol = row->size;
    if (filecol == 0) {
        editorInsertRow(filerow,"",0);
    } else {
        /* We are in the middle of a line. Split it between two rows. */
        editorInsertRow(filerow+1,row->chars+filecol,row->size-filecol);
        row = &E.row[filerow];
        row->chars[filecol] = '\0';
        row->size = filecol;
        editorUpdateRow(row);
    }
fixcursor:
    if (E.cy == E.screenrows-1) {
        E.rowoff++;
    } else {
        E.cy++;
    }
    E.cx = 0;
    E.coloff = 0;
}

/* Delete the char at the current prompt position. */
void editorDelChar(void) {
    int filerow = E.rowoff+E.cy;
    int filecol = E.coloff+E.cx;
    erow *row = (filerow >= E.numrows) ? NULL : &E.row[filerow];

    if (!row || (filecol == 0 && filerow == 0)) return;
    if (filecol == 0) {
        /* Handle the case of column 0, we need to move the current line
         * on the right of the previous one. */
        filecol = E.row[filerow-1].size;
        editorRowAppendString(&E.row[filerow-1],row->chars,row->size);
        editorDelRow(filerow);
        row = NULL;
        if (E.cy == 0)
            E.rowoff--;
        else
            E.cy--;
        E.cx = filecol;
        if (E.cx >= E.screencols) {
            int shift = (E.screencols-E.cx)+1;
            E.cx -= shift;
            E.coloff += shift;
        }
    } else {
        editorRowDelChar(row,filecol-1);
        if (E.cx == 0 && E.coloff)
            E.coloff--;
        else
            E.cx--;
    }
    if (row) editorUpdateRow(row);
    E.dirty++;
}

/* RISCVRAM: editorOpen rewritten to use raw syscalls instead of
 * fopen/getline/fclose.  Reads entire file into a buffer, then splits
 * into lines. */
int editorOpen(char *filename) {
    E.dirty = 0;
    free(E.filename);
    size_t fnlen = strlen(filename)+1;
    E.filename = malloc(fnlen);
    memcpy(E.filename,filename,fnlen);

    int fd = open(filename, 0);
    if (fd < 0) {
        /* RISCVRAM: the kernel signals failure with a generic negative value
         * rather than -errno, so minilib's open() cannot produce a truthful
         * ENOENT and we cannot tell "does not exist" from any other error.
         *
         * Treat every failure as "new file" -- the normal case on a fresh RAM
         * filesystem -- and report it through the status bar (see main()).
         * The old code called perror() here, which was doubly useless: the
         * message said "Unknown error" because strerror() knows only four
         * codes, and the first screen repaint erased it anyway. */
        E.dirty = 0;
        return 1;
    }

    /* Read entire file into memory.  We grow the buffer as needed. */
    size_t cap = 4096;
    size_t total = 0;
    char *filebuf = malloc(cap);
    if (!filebuf) { close(fd); return 1; }

/* Replace the bulk-read + split approach with line-at-a-time reading */
char linebuf[256];
int linepos = 0;
char ch;
ssize_t n;
while ((n = read(fd, &ch, 1)) > 0) {
    if (ch == '\n') {
        if (linepos > 0 && linebuf[linepos-1] == '\r') linepos--;
        editorInsertRow(E.numrows, linebuf, linepos);
        linepos = 0;
    } else if (linepos < (int)sizeof(linebuf)-1) {
        linebuf[linepos++] = ch;
    }
}
if (linepos > 0) {
    editorInsertRow(E.numrows, linebuf, linepos);
}
close(fd);

    /* Split into lines. */
    char *p = filebuf;
    char *end = filebuf + total;
    while (p < end) {
        char *eol = p;
        while (eol < end && *eol != '\n') eol++;
        /* Strip trailing \r if present. */
        int linelen = (int)(eol - p);
        if (linelen > 0 && p[linelen-1] == '\r') linelen--;
        editorInsertRow(E.numrows, p, linelen);
        p = eol + 1;
    }
    free(filebuf);

    E.dirty = 0;
    return 0;
}

/* Save the current file on disk. Return 0 on success, 1 on error. */
int editorSave(void) {
    int len;
    char *buf = editorRowsToString(&len);
    int fd = open(E.filename,1);
    if (fd == -1) goto writeerr;

    /* Use truncate + a single write(2) call in order to make saving
     * a bit safer, under the limits of what we can do in a small editor. */
    if (ftruncate(fd,len) == -1) goto writeerr;
    if (write(fd,buf,len) != len) goto writeerr;

    close(fd);
    free(buf);
    E.dirty = 0;
    editorSetStatusMessage("%d bytes written on disk", len);
    return 0;

writeerr:
    free(buf);
    if (fd != -1) close(fd);
    editorSetStatusMessage("Can't save! I/O error: %s",strerror(errno));
    return 1;
}

/* ============================= Terminal update ============================
 *
 * RISCVRAM: Differential (incremental) screen updates, low-memory version.
 *
 * The original kilo redrew the whole screen on every keypress: ~2-3 KB of
 * text and escape sequences per keystroke.  Instead we keep a "shadow" copy
 * of what the terminal is believed to be displaying, rebuild each row on
 * demand, and emit only the cells that actually differ.
 *
 * MEMORY.  An earlier version of this kept two full screen buffers, which
 * cost 16.9 KB of .bss -- far too much to sit alongside minilib's 32 KB
 * heap on a RAM-resident kernel, and enough to collide with the stack or
 * the kernel itself on a machine with a fixed load region.  Only the shadow
 * has to be screen-sized: the desired image is built one row at a time into
 * fb_row, diffed, emitted, and then folded into the shadow.  Total cost is
 * now about 4.3 KB:
 *
 *     fb_shadow   KILO_MAX_ROWS * KILO_MAX_COLS * 2  =  3840 bytes
 *     fb_row      KILO_MAX_COLS * 2                  =   160 bytes
 *     obuf        OBUF_SIZE                          =   256 bytes
 *
 * If it still does not fit, shrink KILO_MAX_COLS/ROWS to your real terminal
 * size -- they only need to be as large as the screen you actually drive.
 *
 * ZERO-INITIALISED STATE.  Every variable below is designed so that
 * all-bits-zero means "I know nothing, repaint everything".  Nothing here
 * relies on a non-zero initialiser, so the editor starts correctly even if
 * the loader sets up .bss but not .data.
 */

#define KILO_MAX_ROWS 24      /* Must be >= real terminal rows. */
#define KILO_MAX_COLS 80      /* Must be >= real terminal columns. */

/* Cell attribute byte: low 7 bits = SGR color (39 == terminal default),
 * high bit = reverse video. */
#define ATTR_REVERSE  0x80
#define ATTR_COLOR    0x7f
#define COLOR_DEFAULT 39
#define ATTR_UNKNOWN  0xff

typedef struct scell {
    unsigned char c;     /* Character to display. */
    unsigned char attr;  /* Color + reverse-video flag. */
} scell;

static scell fb_shadow[KILO_MAX_ROWS][KILO_MAX_COLS];  /* Believed on screen. */
static scell fb_row[KILO_MAX_COLS];                    /* Row being built. */

static int fb_ready;         /* 0 = shadow unknown, repaint everything. */
static int fb_cursor_known;  /* 0 = cursor position unknown. */
static int fb_cursor_row;
static int fb_cursor_col;

/* Throw away what we believe about the screen and repaint from scratch. */
void editorForceRedraw(void) {
    fb_ready = 0;
    fb_cursor_known = 0;
}

/* ---- Output buffer ------------------------------------------------------
 *
 * How we are allowed to talk to the kernel's write syscall:
 *
 *   KILO_WRITE_CHUNK
 *       Max bytes handed to sys_write in one call.  minilib's write() uses
 *       8, which is a good hint about the UART FIFO, so we match it.
 *
 *   KILO_WRITE_RETURNS_COUNT
 *       Your syscall convention documents a0 as "arg1 (and return value)",
 *       so a write handler that never sets a0 leaves the fd sitting there
 *       and appears to "return" 1 regardless of what it wrote.  Until that
 *       is confirmed the return value cannot be trusted, so we default to
 *       ignoring it -- exactly what the original kilo did.  Set this to 1
 *       only if probe.c test [1] shows a real byte count.
 */
#define KILO_WRITE_CHUNK         8
#define KILO_WRITE_RETURNS_COUNT 0
#define OBUF_SIZE                256

static char obuf[OBUF_SIZE];
static int  obuf_len;

static void obFlush(void) {
    int off = 0;
    while (off < obuf_len) {
        int chunk = obuf_len - off;
        if (chunk > KILO_WRITE_CHUNK) chunk = KILO_WRITE_CHUNK;
#if KILO_WRITE_RETURNS_COUNT
        {
            long ret = sys_write(STDOUT_FILENO, obuf + off, chunk);
            if (ret <= 0) break;        /* Refused: stop, resync via Ctrl-L. */
            off += (int)ret;
        }
#else
        sys_write(STDOUT_FILENO, obuf + off, chunk);
        off += chunk;                   /* Fire and forget. */
#endif
    }
    obuf_len = 0;
}

static void obAppend(const char *s, int len) {
    while (len > 0) {
        int space = OBUF_SIZE - obuf_len;
        int n;
        if (space == 0) {
            obFlush();
            space = OBUF_SIZE;
        }
        n = (len < space) ? len : space;
        memcpy(obuf + obuf_len, s, n);
        obuf_len += n;
        s += n;
        len -= n;
    }
}

static void obAppendStr(const char *s) {
    obAppend(s, strlen(s));
}

/* ---- Geometry ----------------------------------------------------------- */

/* Total rows we manage: text area plus the two status rows. */
static int fbTotalRows(void) {
    int r = E.screenrows + 2;
    if (r > KILO_MAX_ROWS) r = KILO_MAX_ROWS;
    if (r < 0) r = 0;
    return r;
}

/* Usable columns on screen row 'y'.  We never touch the very last cell of
 * the very last row: writing there triggers auto-wrap (and a scroll) on
 * most terminals, which would shift the display out from under us. */
static int fbRowWidth(int y) {
    int w = E.screencols;
    if (w > KILO_MAX_COLS) w = KILO_MAX_COLS;
    if (y == fbTotalRows() - 1) w--;
    if (w < 0) w = 0;
    return w;
}

/* ---- Row painting ------------------------------------------------------- */

static void rowSet(int x, int w, unsigned char c, unsigned char attr) {
    if (x >= 0 && x < w && x < KILO_MAX_COLS) {
        fb_row[x].c = c;
        fb_row[x].attr = attr;
    }
}

/* Build screen row 'y' into fb_row.  Pure memory work: no syscalls, no
 * allocation, and no second screen-sized buffer. */
static void fbRenderRow(int y, int w) {
    int x, j;

    for (x = 0; x < KILO_MAX_COLS; x++) {
        fb_row[x].c = ' ';
        fb_row[x].attr = COLOR_DEFAULT;
    }

    /* --- Text area --- */
    if (y < E.screenrows) {
        int filerow = E.rowoff + y;
        erow *r;
        int len;

        if (filerow >= E.numrows) {
            if (E.numrows == 0 && y == E.screenrows / 3) {
                char welcome[80];
                int welcomelen = snprintf(welcome, sizeof(welcome),
                    "Kilo editor -- version %s", KILO_VERSION);
                int padding = (E.screencols - welcomelen) / 2;
                x = 0;
                if (padding > 0) {
                    rowSet(x++, w, '~', COLOR_DEFAULT);
                    padding--;
                }
                while (padding-- > 0 && x < w) x++;   /* Already blank. */
                for (j = 0; j < welcomelen && x < w; j++)
                    rowSet(x++, w, (unsigned char)welcome[j], COLOR_DEFAULT);
            } else {
                rowSet(0, w, '~', COLOR_DEFAULT);
            }
            return;
        }

        r = &E.row[filerow];
        len = r->rsize - E.coloff;
        if (len > 0) {
            char *c = r->render + E.coloff;
            unsigned char *hl = r->hl + E.coloff;
            if (len > w) len = w;
            for (x = 0; x < len; x++) {
                if (hl[x] == HL_NONPRINT) {
                    char sym;
                    if (c[x] <= 26)
                        sym = '@' + c[x];
                    else
                        sym = '?';
                    rowSet(x, w, (unsigned char)sym,
                           COLOR_DEFAULT | ATTR_REVERSE);
                } else if (hl[x] == HL_NORMAL) {
                    rowSet(x, w, (unsigned char)c[x], COLOR_DEFAULT);
                } else {
                    rowSet(x, w, (unsigned char)c[x],
                           (unsigned char)editorSyntaxToColor(hl[x]));
                }
            }
        }
        return;
    }

    /* --- Status row (reverse video) --- */
    if (y == E.screenrows) {
        unsigned char a = COLOR_DEFAULT | ATTR_REVERSE;
        char status[80], rstatus[80];
        int len = snprintf(status, sizeof(status), "%.20s - %d lines %s",
            E.filename, E.numrows, E.dirty ? "(modified)" : "");
        int rlen = snprintf(rstatus, sizeof(rstatus),
            "%d/%d", E.rowoff + E.cy + 1, E.numrows);
        int rstart;

        for (x = 0; x < w; x++) rowSet(x, w, ' ', a);
        for (x = 0; x < len && x < w; x++)
            rowSet(x, w, (unsigned char)status[x], a);

        rstart = E.screencols - rlen;
        if (rstart < len) rstart = len;   /* Never overlap the left status. */
        for (x = 0; x < rlen && rstart + x < w; x++)
            rowSet(rstart + x, w, (unsigned char)rstatus[x], a);
        return;
    }

    /* --- Message row --- */
    {
        int msglen = strlen(E.statusmsg);
        if (msglen && time(NULL) - E.statusmsg_time < 5) {
            for (x = 0; x < msglen && x < w; x++)
                rowSet(x, w, (unsigned char)E.statusmsg[x], COLOR_DEFAULT);
        }
    }
}

/* ---- Diff and emit ------------------------------------------------------ */

/* Move the terminal from attribute 'prev' to attribute 'attr'.  Pass
 * ATTR_UNKNOWN at the start of a changed span so the sequence is
 * self-contained and does not depend on prior terminal state.  When only the
 * color changes we emit just the color code, which matters because syntax
 * highlighting flips colors several times per line. */
static void emitAttr(unsigned char attr, unsigned char prev) {
    int color = attr & ATTR_COLOR;
    char buf[16];
    int n;

    if (prev == ATTR_UNKNOWN ||
        (prev & ATTR_REVERSE) != (attr & ATTR_REVERSE))
    {
        obAppendStr("\x1b[0m");
        if (attr & ATTR_REVERSE) obAppendStr("\x1b[7m");
        if (color != COLOR_DEFAULT) {
            n = snprintf(buf, sizeof(buf), "\x1b[%dm", color);
            obAppend(buf, n);
        }
        return;
    }
    n = snprintf(buf, sizeof(buf), "\x1b[%dm", color);
    obAppend(buf, n);
}

/* Bring the terminal in sync with the logical editor state in 'E'. */
void editorRefreshScreen(void) {
    int y, x, n;
    int total = fbTotalRows();
    int touched = 0;         /* Did we write any cells this pass? */
    int cx, filerow, j;
    erow *row;
    char buf[32];

    if (!fb_ready) {
        /* ESC[2J blanks every cell to space-with-default-attribute, so that
         * is exactly what the shadow should claim the screen holds.
         * Recording blanks (rather than an impossible value) lets the diff
         * skip empty regions and trailing whitespace entirely, so a cold
         * start sends only the actual text. */
        for (y = 0; y < KILO_MAX_ROWS; y++) {
            for (x = 0; x < KILO_MAX_COLS; x++) {
                fb_shadow[y][x].c = ' ';
                fb_shadow[y][x].attr = COLOR_DEFAULT;
            }
        }
        obAppendStr("\x1b[0m\x1b[2J");
        fb_cursor_known = 0;
        fb_ready = 1;
        touched = 1;
    }

    for (y = 0; y < total; y++) {
        int w = fbRowWidth(y);
        int first = -1, last = -1;
        int blank_from, stop;
        unsigned char cur_attr;

        fbRenderRow(y, w);

        for (x = 0; x < w; x++) {
            if (fb_row[x].c != fb_shadow[y][x].c ||
                fb_row[x].attr != fb_shadow[y][x].attr)
            {
                if (first == -1) first = x;
                last = x;
            }
        }
        if (first == -1) continue;   /* Row unchanged: emit nothing at all. */

        /* Where does this row's run of trailing default-blank cells begin?
         * Most source lines are far shorter than the screen is wide, so
         * clearing the tail with one ESC[0K beats emitting dozens of
         * spaces. */
        blank_from = w;
        while (blank_from > 0 &&
               fb_row[blank_from-1].c == ' ' &&
               fb_row[blank_from-1].attr == COLOR_DEFAULT) blank_from--;

        stop = last;
        if (blank_from <= last && (last - blank_from + 1) >= 8) {
            stop = blank_from - 1;
        } else {
            blank_from = -1;         /* Not worth it; write the spaces. */
        }

        if (!touched) {
            obAppendStr("\x1b[?25l");   /* Hide cursor while we paint. */
            touched = 1;
        }

        n = snprintf(buf, sizeof(buf), "\x1b[%d;%dH", y + 1, first + 1);
        obAppend(buf, n);

        cur_attr = ATTR_UNKNOWN;
        for (x = first; x <= stop; x++) {
            char ch;
            if (fb_row[x].attr != cur_attr) {
                emitAttr(fb_row[x].attr, cur_attr);
                cur_attr = fb_row[x].attr;
            }
            ch = (char)fb_row[x].c;
            obAppend(&ch, 1);
            fb_shadow[y][x] = fb_row[x];
        }

        if (blank_from >= 0) {
            /* Reset first: ESC[0K fills with the *current* background, so
             * erasing under reverse video would paint a bright bar. */
            obAppendStr("\x1b[0m\x1b[0K");
            cur_attr = COLOR_DEFAULT;
            /* ESC[0K clears to the true end of the line, so sync the whole
             * tail, not just the part inside the changed span. */
            for (x = (first > blank_from ? first : blank_from); x < w; x++) {
                fb_shadow[y][x].c = ' ';
                fb_shadow[y][x].attr = COLOR_DEFAULT;
            }
        }
        if (cur_attr != COLOR_DEFAULT) obAppendStr("\x1b[0m");
        fb_cursor_known = 0;         /* Cursor left somewhere else. */
    }

    /* Put the cursor at its logical position.  The horizontal position may
     * differ from E.cx because of TABs. */
    cx = 1;
    filerow = E.rowoff + E.cy;
    row = (filerow >= E.numrows) ? NULL : &E.row[filerow];
    if (row) {
        for (j = E.coloff; j < (E.cx + E.coloff); j++) {
            if (j < row->size && row->chars[j] == TAB) cx += 7 - ((cx) % 8);
            cx++;
        }
    }
    if (!fb_cursor_known || fb_cursor_row != E.cy + 1 || fb_cursor_col != cx) {
        n = snprintf(buf, sizeof(buf), "\x1b[%d;%dH", E.cy + 1, cx);
        obAppend(buf, n);
        fb_cursor_row = E.cy + 1;
        fb_cursor_col = cx;
        fb_cursor_known = 1;
    }

    if (touched) obAppendStr("\x1b[?25h");   /* Show cursor again. */

    obFlush();   /* Nothing queued => no syscall at all. */
}

/* Set an editor status message for the second line of the status, at the
 * end of the screen. */
void editorSetStatusMessage(const char *fmt, ...) {
    va_list ap;
    va_start(ap,fmt);
    vsnprintf(E.statusmsg,sizeof(E.statusmsg),fmt,ap);
    va_end(ap);
    E.statusmsg_time = time(NULL);
}

/* =============================== Find mode ================================ */

#define KILO_QUERY_LEN 256

void editorFind(int fd) {
    char query[KILO_QUERY_LEN+1] = {0};
    int qlen = 0;
    int last_match = -1; /* Last line where a match was found. -1 for none. */
    int find_next = 0; /* if 1 search next, if -1 search prev. */
    int saved_hl_line = -1;  /* No saved HL */
    char *saved_hl = NULL;

#define FIND_RESTORE_HL do { \
    if (saved_hl) { \
        memcpy(E.row[saved_hl_line].hl,saved_hl, E.row[saved_hl_line].rsize); \
        free(saved_hl); \
        saved_hl = NULL; \
    } \
} while (0)

    /* Save the cursor position in order to restore it later. */
    int saved_cx = E.cx, saved_cy = E.cy;
    int saved_coloff = E.coloff, saved_rowoff = E.rowoff;

    while(1) {
        editorSetStatusMessage(
            "Search: %s (Use ESC/Arrows/Enter)", query);
        editorRefreshScreen();

        int c = editorReadKey(fd);
        if (c == DEL_KEY || c == CTRL_H || c == BACKSPACE) {
            if (qlen != 0) query[--qlen] = '\0';
            last_match = -1;
        } else if (c == ESC || c == ENTER) {
            if (c == ESC) {
                E.cx = saved_cx; E.cy = saved_cy;
                E.coloff = saved_coloff; E.rowoff = saved_rowoff;
            }
            FIND_RESTORE_HL;
            editorSetStatusMessage("");
            return;
        } else if (c == ARROW_RIGHT || c == ARROW_DOWN) {
            find_next = 1;
        } else if (c == ARROW_LEFT || c == ARROW_UP) {
            find_next = -1;
        } else if (isprint(c)) {
            if (qlen < KILO_QUERY_LEN) {
                query[qlen++] = c;
                query[qlen] = '\0';
                last_match = -1;
            }
        }

        /* Search occurrence. */
        if (last_match == -1) find_next = 1;
        if (find_next) {
            char *match = NULL;
            int match_offset = 0;
            int i, current = last_match;

            for (i = 0; i < E.numrows; i++) {
                current += find_next;
                if (current == -1) current = E.numrows-1;
                else if (current == E.numrows) current = 0;
                match = strstr(E.row[current].render,query);
                if (match) {
                    match_offset = match-E.row[current].render;
                    break;
                }
            }
            find_next = 0;

            /* Highlight */
            FIND_RESTORE_HL;

            if (match) {
                erow *row = &E.row[current];
                last_match = current;
                if (row->hl) {
                    saved_hl_line = current;
                    saved_hl = malloc(row->rsize);
                    memcpy(saved_hl,row->hl,row->rsize);
                    memset(row->hl+match_offset,HL_MATCH,qlen);
                }
                E.cy = 0;
                E.cx = match_offset;
                E.rowoff = current;
                E.coloff = 0;
                /* Scroll horizontally as needed. */
                if (E.cx > E.screencols) {
                    int diff = E.cx - E.screencols;
                    E.cx -= diff;
                    E.coloff += diff;
                }
            }
        }
    }
}

/* ========================= Editor events handling  ======================== */

/* Handle cursor position change because arrow keys were pressed. */
void editorMoveCursor(int key) {
    int filerow = E.rowoff+E.cy;
    int filecol = E.coloff+E.cx;
    int rowlen;
    erow *row = (filerow >= E.numrows) ? NULL : &E.row[filerow];

    switch(key) {
    case ARROW_LEFT:
        if (E.cx == 0) {
            if (E.coloff) {
                E.coloff--;
            } else {
                if (filerow > 0) {
                    E.cy--;
                    E.cx = E.row[filerow-1].size;
                    if (E.cx > E.screencols-1) {
                        E.coloff = E.cx-E.screencols+1;
                        E.cx = E.screencols-1;
                    }
                }
            }
        } else {
            E.cx -= 1;
        }
        break;
    case ARROW_RIGHT:
        if (row && filecol < row->size) {
            if (E.cx == E.screencols-1) {
                E.coloff++;
            } else {
                E.cx += 1;
            }
        } else if (row && filecol == row->size) {
            E.cx = 0;
            E.coloff = 0;
            if (E.cy == E.screenrows-1) {
                E.rowoff++;
            } else {
                E.cy += 1;
            }
        }
        break;
    case ARROW_UP:
        if (E.cy == 0) {
            if (E.rowoff) E.rowoff--;
        } else {
            E.cy -= 1;
        }
        break;
    case ARROW_DOWN:
        if (filerow < E.numrows) {
            if (E.cy == E.screenrows-1) {
                E.rowoff++;
            } else {
                E.cy += 1;
            }
        }
        break;
    }
    /* Fix cx if the current line has not enough chars. */
    filerow = E.rowoff+E.cy;
    filecol = E.coloff+E.cx;
    row = (filerow >= E.numrows) ? NULL : &E.row[filerow];
    rowlen = row ? row->size : 0;
    if (filecol > rowlen) {
        E.cx -= filecol-rowlen;
        if (E.cx < 0) {
            E.coloff += E.cx;
            E.cx = 0;
        }
    }
}

/* Process events arriving from the standard input, which is, the user
 * is typing stuff on the terminal. */
#define KILO_QUIT_TIMES 3
void editorProcessKeypress(int fd) {
    /* When the file is modified, requires Ctrl-q to be pressed N times
     * before actually quitting. */
    static int quit_times = KILO_QUIT_TIMES;

    int c = editorReadKey(fd);
    switch(c) {
    case ENTER:         /* Enter */
        editorInsertNewline();
        break;
    case CTRL_C:        /* Ctrl-c */
        /* We ignore ctrl-c, it can't be so simple to lose the changes
         * to the edited file. */
        break;
    case CTRL_Q:        /* Ctrl-q */
        /* Quit if the file was already saved. */
        if (E.dirty && quit_times) {
            editorSetStatusMessage("WARNING!!! File has unsaved changes. "
                "Press Ctrl-Q %d more times to quit.", quit_times);
            quit_times--;
            return;
        }
        exit(0);
        break;
    case CTRL_S:        /* Ctrl-s */
        editorSave();
        break;
    case CTRL_F:
        editorFind(fd);
        break;
    case BACKSPACE:     /* Backspace */
    case CTRL_H:        /* Ctrl-h */
    case DEL_KEY:
        editorDelChar();
        break;
    case PAGE_UP:
    case PAGE_DOWN:
        if (c == PAGE_UP && E.cy != 0)
            E.cy = 0;
        else if (c == PAGE_DOWN && E.cy != E.screenrows-1)
            E.cy = E.screenrows-1;
        {
        int times = E.screenrows;
        while(times--)
            editorMoveCursor(c == PAGE_UP ? ARROW_UP:
                                            ARROW_DOWN);
        }
        break;

    case ARROW_UP:
    case ARROW_DOWN:
    case ARROW_LEFT:
    case ARROW_RIGHT:
        editorMoveCursor(c);
        break;
    case CTRL_L: /* ctrl+l, clear screen */
        /* RISCVRAM: With differential updates this is the escape hatch --
         * it throws away our shadow copy of the screen and repaints from
         * scratch, in case anything else scribbled on the terminal. */
        editorForceRedraw();
        break;
    case ESC:
        /* Nothing to do for ESC in this mode. */
        break;
    default:
        editorInsertChar(c);
        break;
    }

    quit_times = KILO_QUIT_TIMES; /* Reset it to the original value. */
}

int editorFileWasModified(void) {
    return E.dirty;
}

void updateWindowSize(void) {
    E.screencols = 80;
    E.screenrows = 24;
    /* RISCVRAM: the framebuffers are statically sized, so clamp. */
    if (E.screencols > KILO_MAX_COLS) E.screencols = KILO_MAX_COLS;
    if (E.screenrows > KILO_MAX_ROWS) E.screenrows = KILO_MAX_ROWS;
    E.screenrows -= 2;
    editorForceRedraw();
}

/* RISCVRAM: no SIGWINCH support — window size is fixed at startup.
 * If you add a signal syscall later, you can restore this. */

void initEditor(void) {
    E.cx = 0;
    E.cy = 0;
    E.rowoff = 0;
    E.coloff = 0;
    E.numrows = 0;
    E.row = NULL;
    E.dirty = 0;
    E.filename = NULL;
    E.syntax = NULL;
    updateWindowSize();
    /* RISCVRAM: no signal(SIGWINCH, ...) */
}

int main(int argc, char **argv) {
    int is_new;

    if (argc != 2) {
        fprintf(0,"Usage: kilo <filename>\n\r");
        exit(1);
    }

    initEditor();
    editorSelectSyntaxHighlight(argv[1]);
    is_new = editorOpen(argv[1]);
    enableRawMode(STDIN_FILENO);
    if (is_new)
        editorSetStatusMessage("New file \"%s\" -- Ctrl-S = save | Ctrl-Q = quit",
                               argv[1]);
    else
        editorSetStatusMessage(
            "HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find");
    while(1) {
        editorRefreshScreen();
        editorProcessKeypress(STDIN_FILENO);
    }
    return 0;
}
