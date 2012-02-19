/* metasm */
#ifdef __METASM__
#define EXPORT __attribute__((export))
#else
#define EXPORT
#endif


/* stdlib headers */
void *malloc(int);

#define PROT_READ 1
#define PROT_WRITE 2
#define MAP_PRIVATE 2
#define MAP_ANONYMOUS 0x20
#define MAP_FAILED (-1)
void *mmap(void *addr, int len, int prot, int flags, int fd, int off);
int mprotect(void *addr, int len, int prot);
int munmap(void *addr, int len);


/* rubj headers */
typedef struct string {
	int len;
	char *buf;
} string;

/* rubj globals */
// array all_objects;
// hash globals;
// hash toplevel_constants; 	// == globals?
// array threads;
// string toplevel_bytecode;


/* rubj stdlib */
int kernel_puts(void *self, void *str)
{
	int printf(char *, ...);
	printf("%s\n", ((string*)str)->buf);
	return 0;
}

string *string_new2(char *buf, int len)
{
	string *str = malloc(sizeof(*str));
	str->len = len;
	str->buf = buf;
	return str;
}


/* rubj init */
// char main_bytecode[42] = { 28, 'l', 'o', 'l' };
//#include "init_bytecode.h"	// load the ruby parser / compiler to vm bytecode

char main_bytecode[42];

enum vm_bytecode_opcodes {
	bc_native_funcall_2,
	bc_return,
};

void init_interp(void) EXPORT
{
	/* signal(EFAULT, stack_underflow__backtraces__etc); */
	/* init all rubj globals */

	char *ptr = main_bytecode;
	*ptr = bc_native_funcall_2; ptr += 1;
	*(void**)ptr = kernel_puts; ptr += sizeof(void*);
	*(void**)ptr = 0; ptr += sizeof(void*);
	*(void**)ptr = string_new2("Hello, world!", 13); ptr += sizeof(void*);
	*ptr = bc_return; ptr += 1;
}

#ifndef PAGE_SIZE
#define PAGE_SIZE 4096
#endif

int stack_pivot(void *newsp, void *fn, void *fn_arg);

#ifdef __i386__
asm {
stack_pivot:
	push ebp
	mov ebp, esp
	mov esp, [ebp+0x8]	// newsp
	push ebp		// save original stack
	push [ebp+0x10]		// fn_arg
	call [ebp+0xc]		// fn
	add esp, 4		// pop fn_arg
	pop esp			// restore original stack
	pop ebp
	ret
}
#else
#error Y U NO stack_pivot?
#endif

/* allocate a new stack, run the specified function + arg with this */
/* TODO store stack boundaries for GC scan */
int run_on_new_stack(int size, int(*fn)(void*), void *fn_arg)
{
	char *stack_base;
	int ret;

	stack_base = mmap(0, size+PAGE_SIZE, PROT_READ|PROT_WRITE,
			MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
	if (stack_base == MAP_FAILED) {
		/* TODO raise? (main thread has no runtime at this point) */
		void perror(char*);
		void exit(int);
		perror("mmap");
		exit(1);
	}

	/* guard page */
	/* TODO growsdown etc */
	mprotect(stack_base, PAGE_SIZE, 0);

	ret = stack_pivot(stack_base + size+PAGE_SIZE, fn, fn_arg);

	munmap(stack_base, size+PAGE_SIZE);

	return ret;
}

int vm_interp_run(char *bytecode)
{
	for (;;) {
		switch (*bytecode++) {
		case bc_native_funcall_2:
			{
				int (*fptr)(void*, void*);
				void *arg1, *arg2;

				fptr = *(void**)bytecode;
				bytecode += sizeof(void*);

				arg1 = *(void**)bytecode;
				bytecode += sizeof(void*);

				arg2 = *(void**)bytecode;
				bytecode += sizeof(void*);

				fptr(arg1, arg2);
			}

			break;
		case bc_return:
			return 0;
		default:
			//raise "moo";
			break;
		}
	}
	return 0;
}

int stack_size = 1024*1024;
void interp_main_loop(void) EXPORT
{
#ifdef DONT_SWITCH_MAIN_THREAD_STACK
	vm_interp_run(main_bytecode);
#else
	run_on_new_stack(stack_size, vm_interp_run, main_bytecode);
#endif
}
