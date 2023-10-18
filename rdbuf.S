#ifndef MYRDBUF_S
#else
// version 1.0 10/12/2022 //
    .arch   armv6
    .arm
    .fpu    vfp
    .syntax unified

    // global constants
    #include "cipher.h"

    .extern fread
    .extern feof
    .extern ferror
    .text

    // int rdbuf(r0=FILE *in, r1=FILE *fpbook, r2=int cnt, r3=char *iobuf, 
    //            on the stack at ARG5 offset=char *bookbuf)
    // returns number of bytes read EXIT_FAIL otherwise
    // you can change or remove any comments in this file

    .type   rdbuf, %function
    .global rdbuf
    .equ    ARG5,  4 
    .equ    FP_OFF, 28
 
rdbuf:
    push    {r4-r9, fp, lr}
    add     fp, sp, FP_OFF
   /*
    * r4 FILE *in
    * r5 FILE *fpbook
    * r6 int cnt
    * r7 char *iobuf
    * r8 size_t bytes
    */
    // save the register args (r0-r3) into preserved registers
    // as there are many function calls
    mov     r4, r0 // r4 FILE *in
    mov     r5, r1 // r5 FILE *fpbook
    mov     r6, r2 // r6 int cnt
    mov     r7, r3 // r7 char *iobuf

    // check for end of file feof(in)
    bl      feof // r0 is already "in"
    // if r0 is not zero at EOF, set r0 to 0 and return
    cmp     r0, 0
    bne     .Leof

    // otherwise check for read errors
    // check for error ferror(in)
    mov     r0, r4
    bl      ferror

    cmp     r0, 0
    // if r0 is zero, no errors, do the reads
    // if r0 is not zero, set r0 to EXIT_FAIL and return
    bne     .Lerror
    // bytes = fread(r0=iobuf, r1=1, r2=cnt, r3=in)
    // set parameters
    mov     r0, r7
    mov     r1, 1
    mov     r2, r6
    mov     r3, r4
    
    bl      fread

    // save bytes so we can check that we read same bytes from bookfile
    mov     r8, r0 // r8 = bytes
    // if r0 <= 0 return with r0 = 0
    cmp     r0, 0
    ble     .Leof
    
    // r0 = fread(r0=bookbuf, r1=1, r2=bytes, r3=fpbook)
    
    //set parameters
    // the pointer to bookbuf is passed on the stack so
    // you need to do a ldr from ARG5 offset to get the address
    // to pass to the fread
    ldr     r0, [fp, 4] //set bookbuf (offset 4)
    mov     r1, 1
    mov     r2, r8
    mov     r3, r5

    bl      fread

    cmp     r0, r8
    // if r0 on the return from fread is not equal to bytes 
    // return in r0 from stdin (into iobuf) return EXIT fail
    // otherwise set r0 = bytes and return
    beq     .Lsuccess
.Lerror:
    mov     r0, EXIT_FAIL
    b       .Ldone
.Lsuccess:
    mov     r0, r8
    b       .Ldone
.Leof:
    mov     r0, 0
.Ldone:
    sub     sp, fp, FP_OFF
    pop     {r4-r9, fp, lr}
    bx      lr

    .size   rdbuf, (. - rdbuf)
    .section .note.GNU-stack,"",%progbits
.end
#endif
