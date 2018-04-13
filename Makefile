CC= /var/obj/7-1/x68k/tools/bin/m68k--netbsdelf-gcc \
	--sysroot=/var/obj/7-1/x68k/dst

.PHONY: a.out

.if defined(USE_ASM)
a.out:
	${CC} -g -O2 -DUSE_ASM -c arc4random.c
	${CC} -g -c chacha20-m68k.S
	${CC} -g -o a.out arc4random.o chacha20-m68k.o
.else
a.out:
	${CC} -g -O2 arc4random.c
.endif
