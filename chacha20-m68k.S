| vi:set ts=8:
#define OUTPUTBYTES	64
#define INPUTBYTES	16
#define KEYBYTES	32
#define CONSTBYTES	16
#define ROUNDS	20

| void
| crypto_core(
|  uint8_t *out,
|  const uint8_t *in,
|  const uint8_t *k,
|  const uint8_t *c);
	.global crypto_core
	.type	crypto_core, @function
crypto_core:
	linkw	%fp,#-128
	moveml	%d2-%d5/%a2-%a5,-(%sp)
	moveal	12(%fp),%a0	| %a0 := in
	moveal	16(%fp),%a1	| %a1 := k
	moveal	20(%fp),%a3	| %a3 := c

	leal	-128(%fp),%a4	| %a4 := x
	leal	-64(%fp),%a5	| %a5 := j

| Load from SRC and bswap it and then store it to x, j.
|  Inp: SRC
|  Out: %a4++, %a5++
|  Use: %d0
#define LETOBE(SRC)	\
	movel	SRC,%d0; \
	rorw	#8,%d0; \
	swap	%d0; \
	rorw	#8,%d0; \
	movel	%d0,(%a4)+; \
	movel	%d0,(%a5)+

	LETOBE((%a3)+)	| j0 : c +0
	LETOBE((%a3)+)	| j1 : c +4
	LETOBE((%a3)+)	| j2 : c +8
	LETOBE((%a3) )	| j3 : c +12
	LETOBE((%a1)+)	| j4 : k +0
	LETOBE((%a1)+)	| j5 : k +4
	LETOBE((%a1)+)	| j6 : k +8
	LETOBE((%a1)+)	| j7 : k +12
	LETOBE((%a1)+)	| j8 : k +16
	LETOBE((%a1)+)	| j9 : k +20
	LETOBE((%a1)+)	| j10: k +24
	LETOBE((%a1) )	| j11: k +28
	LETOBE((%a0)+)	| j12: in +0
	LETOBE((%a0)+)	| j13: in +4
	LETOBE((%a0)+)	| j14: in +8
	LETOBE((%a0) )	| j15: in +12

| Do QuarterRound.
|  Inp: %a0-%a3: source
|       %d4: shift count(=12)
|  Out: DST0-DST3 (%a0-%a3)
|  Use: %d0-%d3
#define QUARTERROUND(DST0, DST1, DST2, DST3) \
	movel	(DST0 * 4)(%a5),%d0; \
	movel	(DST1 * 4)(%a5),%d1; \
	movel	(DST2 * 4)(%a5),%d2; \
	movel	(DST3 * 4)(%a5),%d3; \
	addl	%d1,%d0; \
	eorl	%d0,%d3; \
	swap	%d3; \
	addl	%d3,%d2; \
	eorl	%d2,%d1; \
	roll	%d4,%d1; \
	addl	%d1,%d0; \
	eorl	%d0,%d3; \
	roll	#8,%d3; \
	addl	%d3,%d2; \
	eorl	%d2,%d1; \
	roll	#7,%d1; \
	movel	%d0,(DST0 * 4)(%a5); \
	movel	%d1,(DST1 * 4)(%a5); \
	movel	%d2,(DST2 * 4)(%a5); \
	movel	%d3,(DST3 * 4)(%a5)

	| QUARTERROUND( x0, x4, x8,x12);
	| QUARTERROUND( x1, x5, x9,x13);
	| QUARTERROUND( x2, x6,x10,x14);
	| QUARTERROUND( x3, x7,x11,x15);
	| QUARTERROUND( x0, x5,x10,x15);
	| QUARTERROUND( x1, x6,x11,x12);
	| QUARTERROUND( x2, x7, x8,x13);
	| QUARTERROUND( x3, x4, x9,x14);

	moveql	#12,%d4		| shift count
	moveql	#(ROUNDS / 2 -1),%d5	| loop count

	leal	-128(%fp),%a5	| %a5 := x
_loop:
	QUARTERROUND(0, 4, 8,12)
	QUARTERROUND(1, 5, 9,13)
	QUARTERROUND(2, 6,10,14)
	QUARTERROUND(3, 7,11,15)

	QUARTERROUND(0, 5,10,15)
	QUARTERROUND(1, 6,11,12)
	QUARTERROUND(2, 7, 8,13)
	QUARTERROUND(3, 4, 9,14)

	dbra	%d5,_loop

	leal	-64(%fp),%a4	| %a4 := j
	leal	-128(%fp),%a5	| %a5 := x

	| %a4 := j
	| %a5 := x
	moveal	8(%fp),%a0	| %a0 := out

| Add SRC1 and SRC2 and store to DST.
|  Use: %d0
#define ADDTOLE(SRC1,SRC2,DST) \
	movel	SRC1,%d0; \
	addl	SRC2,%d0; \
	rorw	#8,%d0; \
	swap	%d0; \
	rorw	#8,%d0; \
	movel	%d0,DST

	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 0
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 1
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 2
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 3
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 4
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 5
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 6
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 7
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 8
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 9
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 10
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 11
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 12
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 13
	ADDTOLE((%a4)+, (%a5)+, (%a0)+)	| 14
	ADDTOLE((%a4) , (%a5) , (%a0) )	| 15

	moveml	(%sp)+,%d2-%d5/%a2-%a5
	unlk	%fp
	rts
	.size	crypto_core, .-crypto_core
