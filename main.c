#ifdef __METASM__
#define IMPORT __attribute__((import))
asm { .needed "./librubj.so" }
#else
#define IMPORT
#endif

void init_interp(void) __attribute__((import));
void interp_main_loop(void) __attribute__((import));

int main(int argc, char **argv, char **envp)
{
	init_interp();
	interp_main_loop();
	return 0;
}
