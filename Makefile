
snake: snake.o
	gcc -o snake snake.o -lX11 -no-pie

snake.o: snake.asm
	nasm -f elf64 -gdwarf snake.asm

.PHONY: clean

clean:
	rm *.o snake