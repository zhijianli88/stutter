all:
	gcc -O2 -lm latency.c -o latency
	gcc -O2 memhog.c -o memhog
clean:
	rm -f latency memhog
