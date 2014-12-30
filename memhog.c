#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

int main(int argc, char **argv)
{
	void *p, *map;
	int flags;
	int stride = getpagesize();
	size_t memfault_size;

	memfault_size = strtol(argv[1], NULL, 0);

	flags = MAP_ANONYMOUS | MAP_PRIVATE;

	map = mmap(NULL, memfault_size, PROT_READ | PROT_WRITE,
		   flags, 0, 0);
	if (map == MAP_FAILED) {
		perror("mmap");
		exit(EXIT_FAILURE);
	}

	for (p = map; p < (map + memfault_size); p += stride)
		*(volatile unsigned long *)p = (unsigned long)p;

	pause();
	exit(EXIT_SUCCESS);
}
