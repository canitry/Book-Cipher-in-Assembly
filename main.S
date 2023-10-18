    // version 1.0 05/22/2022 //
#ifndef MYMAIN_S
#else
    .arch   armv6
    .arm
    .fpu    vfp
    .syntax unified

    // imports
    #include "main.h"
    #include "rdbuf.h"
    #include "setup.h"
    #include "cipher.h"
    .extern fwrite
    .extern stdin
    .extern stdout
    .extern stderr

    .section .rodata
    // do not change these error messages
.Lbdrd:  .string "%s: read failed\n"
.Lbdwr:  .string "%s: write failed\n"

    .text

    //
    // encrypter [-d | -e] -b bookfile
    //
    // int main(int argc, char **argv)
    // int main(r0=argc, r1=argv)

    .global main
    .type   main, %function

    //
    // stack frame layout
    //
    // TODO PA9: complete the following stack frame design
    // You can change or delete any comments in this file
    //
    .equ    FP_OFF,     32                        // fp offset in main stack frame
    .equ    FPBOOK,     4 + FP_OFF                // FILE * to book file
    .equ    IOBUF,      BUFSZ + FPBOOK            // buffer for input file
    .equ    MODE,       4 + IOBUF                 // decrypt or encrypt mode
    .equ    BOOKBUF,    BUFSZ + MODE              // buffer for book file
    .equ    ARGV0,      4 + BOOKBUF               // save argv[0] for error printing
    //
    // add your local variables here if you need them:
    // NOTICE: Adjust PAD so FRMADD + FP_OFF + 4 divides by 8 EVENLY!
    //
    .equ    PAD,       0 + ARGV0                  // Stack frame PAD, BUFSZ = 128, 128%8=0
    .equ    OARG5,     4 + PAD                    // output arg5 must be at bottom
    .equ    FRMADD,    OARG5-FP_OFF               // space in frame for locals+passed args

    // TODO PA9: list how you are using the preserved registers
    // preserved register use
    // r4 int cnt
    // r5 stdout
    // r6 mode flag (came with the pa, don't know what to do with)
    // r7 stdin
    // r8 fpbook
    // r9 argv0 offset / in loop: iobuf
    // r10 argv[0] / in loop: bookbuf

main:
    push    {r4-r10, fp, lr}        // push all the usable preserved registers
    add     fp, sp, FP_OFF          // set frame pointer to frame base
    ldr     r3, =FRMADD             // get space needed for locals+passed args
    sub     sp, sp, r3              // allocate space for locals and passed args 
     
    // save argv[0] in argv0
    // at the entry to main() argc is in r0 and argv is in r1.
    ldr     r10, [r1] //r10=*argv

    ldr     r9, =ARGV0
    str     r10, [fp, -r9]
    // call int setup(r0=argc, r1=argv, r2=*mode, r3=*FPBOOK):
    //r0 = argc and r1 = argv already
    // r2 and r2 are output parameters. Put the address of where mode
    // and FPBOOK are located on main()'s stack and put these in r2 and r3
    // so setup can fill them in (passing a pointer to a local variable in r2,r3)
    ldr     r2, =MODE
    sub     r2, fp, r2 //r2 holds mem address to mode (r2=ptr to mode)
    
    ldr     r3, =FPBOOK
    sub     r3, fp, r3 //r3 = mem add to FPBOOK (ptr to fpbook)
    
    bl      setup
    // if setup fails, put EXIT_FAIL in r0 and then branch to .Lexit
    cmp     r0, 0
    beq     .Lsetup
    mov     r0, EXIT_FAIL
    b       .Lexit
.Lsetup:
    // set up for main loop
    // save the variables you need in the preserved registers as you will be making
    // function calls in the loop body below and r0-r3 will be used for that
    ldr     r6, =MODE
    ldr     r6, [fp, -r6]

    ldr     r7, =stdin
    ldr     r7, [r7]      //FILE *stdin

    ldr     r8, =FPBOOK
    ldr     r8, [fp, -r8] //FILE *fpbook (the pointer to fpbook struct)

    ldr     r9, =IOBUF
    sub     r9, fp, r9    //mem address of iobuf (ie. *iobuf)

    ldr     r10, =BOOKBUF
    sub     r10, fp, r10  //mem add of bookbuf (ie. *bookbuf)

    ldr     r5, =stdout
    ldr     r5, [r5]    //FILE *stdout
.Lloop:
    // this is a loop that runs until rdbuf indicates the EOF on stdin
    // was reached or there was an error.
    // int rdbuf(r0=stdin, r1=fpbook, r2=BUFSZ, r3=iobuf,OARG5=bookbuf)
    // NOTICE that the 5th arg is on the stack so you need to str the 
    // address of bookbuf at offset OARG5 on the stack
    //set params
    ldr     r0, =OARG5
    str     r10, [fp, -r0]
    mov     r0, r7
    mov     r1, r8
    mov     r2, BUFSZ
    mov     r3, r9
    
    bl      rdbuf 
    mov     r4, r0
    cmp     r4, 0 //while loop guard
    // if r0 on return from rdbuf has a 0 in r0 we are done, branch to .Ldone
    beq     .Ldone
    // if return less than 0, error print to stderr .Lbdrd, and go to .Ldone
    bgt     .Lendif1
    //set param for fprintf(stderr, .Lbdrd, argv0)
    ldr     r0, =stderr
    ldr     r0, [r0]

    ldr     r1, =.Lbdrd // literal address to "%s: read failed\n"

    ldr     r2, =ARGV0
    ldr     r2, [fp, -r2]
    
    bl      fprintf

    b       .Ldone
.Lendif1:
    // check the mode flag and call either encrypt or decrypt
    cmp     r6, ENCRYPT_MODE
    // int XXcrypt(r0=char *iobuf, r1=char *bookbuf, r2=int cnt)
    // encrypt or decrypt 
    // returns cnt
    bne     .Lelse2
    mov     r0, r9
    mov     r1, r10
    mov     r2, r4
    bl      encrypt
    b       .Lendif2
    .Lelse2:
    mov     r0, r9
    mov     r1, r10
    mov     r2, r4
    bl      decrypt    
    // make sure to save cnt so we can check that fwrite wrote cnt characters
    .Lendif2:
    mov     r4, r0
    // fwrite returns number of characters it wrote.
    // fwrite(r0=iobuf, r1=1, r2=cnt, r3=*stdout)
    mov     r0, r9
    mov     r1, 1
    mov     r2, r4
    mov     r3, r5

    bl      fwrite

    cmp     r0, r4
    beq     .Lloop
    // if cnt characters written go to .Lloop (write is ok)
    // othewise error, print to stderr .Lbdwr and fall through to .Ldone
    ldr     r0, =stderr
    ldr     r0, [r0]

    ldr     r1, =.Lbdwr // literal address to "%s: write failed\n"

    ldr     r2, =ARGV0
    ldr     r2, [fp, -r2]
    
    bl      fprintf
.Ldone:
    // normal exit, call fclose of fpbook and fall through
    // to .Lexit
    mov     r0, r8
    bl      fclose

.Lexit:
    sub     sp, fp, FP_OFF
    pop     {r4-r10, fp, lr}
    bx      lr

    .size   main, (. - main)
    .section .note.GNU-stack,"",%progbits
.end
#endif
