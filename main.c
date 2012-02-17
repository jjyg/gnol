#ifdef __METASM__
#define IMPORT __attribute__((import))
asm { .needed "./librubj.so" }
#else
#define IMPORT
#endif

void init_interp(void) IMPORT;
void interp_main_loop(void) IMPORT;

int main(int argc, char **argv, char **envp)
{
	init_interp();
	interp_main_loop();
	return 0;
}
