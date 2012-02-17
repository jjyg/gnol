#ifdef __METASM__
#define EXPORT __attribute__((export))
#else
#define EXPORT
#endif

void init_interp(void) EXPORT
{
}

void interp_main_loop(void) EXPORT
{
}
