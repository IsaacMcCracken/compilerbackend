bits 64
default rel

segment .data
    msg db "Hello world!", 0xd, 0xa, 0

segment .text
global main
extern ExitProcess

extern printf

main:
    push    rbp
    mov     rbp, rsp

    mov     rax, 0               ; i = 0

.for_loop:
    cmp     rax, 5
    jge     .end_loop            ; exit loop if i >= 5

    push    rax                  ; save loop counter

    sub     rsp, 32              ; shadow space (Windows ABI)
    lea     rcx, [msg]           ; RCX = pointer to message (1st argument to printf)
    call    printf
    add     rsp, 32              ; restore stack after call

    pop     rax                  ; restore loop counter
    inc     rax                  ; i++
    jmp     .for_loop

.end_loop:
    xor     rax, rax
    call    ExitProcess