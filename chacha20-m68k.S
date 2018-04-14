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
	linkw	%fp,#-64
	moveml	%d2-%d5/%a2-%a4,-(%sp)

	leal	-64(%fp),%a4	| %a4 := x
	moveal	8(%fp),%a2	| %a2 := out

| Load from SRC and bswap it and then store it to x, j.
|  Inp: SRC
|  Out: %a4++: x[0..15]
|       %a2++: j[0..15] as out[0..15]
|  Use: %d0
#define LETOBE(SRC)	\
	movel	SRC,%d0; \
	rorw	#8,%d0; \
	swap	%d0; \
	rorw	#8,%d0; \
	movel	%d0,(%a4)+; \
	movel	%d0,(%a2)+

	moveal	20(%fp),%a0	| %a0 := c
	LETOBE((%a0)+)	| j0 : c +0
	LETOBE((%a0)+)	| j1 : c +4
	LETOBE((%a0)+)	| j2 : c +8
	LETOBE((%a0) )	| j3 : c +12

	moveal	16(%fp),%a0	| %a0 := k
	LETOBE((%a0)+)	| j4 : k +0
	LETOBE((%a0)+)	| j5 : k +4
	LETOBE((%a0)+)	| j6 : k +8
	LETOBE((%a0)+)	| j7 : k +12
	LETOBE((%a0)+)	| j8 : k +16
	LETOBE((%a0)+)	| j9 : k +20
	LETOBE((%a0)+)	| j10: k +24
	LETOBE((%a0) )	| j11: k +28

	moveal	12(%fp),%a0	| %a0 := in
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
	movel	(%a0),%d0; \
	movel	(%a1),%d1; \
	addl	%d1,%d0; \
	movel	(%a3),%d3; \
	eorl	%d0,%d3; \
	swap	%d3; \
	movel	(%a2),%d2; \
	addl	%d3,%d2; \
	eorl	%d2,%d1; \
	roll	%d4,%d1; \
	addl	%d1,%d0; \
	movel	%d0,DST0; \
	eorl	%d0,%d3; \
	roll	#8,%d3; \
	movel	%d3,DST3; \
	addl	%d3,%d2; \
	movel	%d2,DST2; \
	eorl	%d2,%d1; \
	roll	#7,%d1; \
	movel	%d1,DST1

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

	leal	-64(%fp),%a4	| %a4 := x
	| %a1 はループの最後と最初が同じになるので2回目以降は初期化不要
	leal	16(%a4),%a1	| %a1 := x4
_loop:
	leal	(%a4),%a0	| %a0 := x0
	leal	32(%a4),%a2	| %a2 := x8
	leal	48(%a4),%a3	| %a3 := x12

	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3)+)	| x0, x4, x8,x12
	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3)+)	| x1, x5, x9,x13
	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3)+)	| x2, x6,x10,x14
	QUARTERROUND((%a0),  (%a1),  (%a2),  (%a3) )	| x3, x7,x11,x15
	leal	(%a4),%a0
	subq	#8,%a1
	subq	#4,%a2
	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3) )	| x0, x5,x10,x15
	leal	48(%a4),%a3
	QUARTERROUND((%a0)+, (%a1)+, (%a2),  (%a3)+)	| x1, x6,x11,x12
	leal	32(%a4),%a2
	QUARTERROUND((%a0)+, (%a1),  (%a2)+, (%a3)+)	| x2, x7, x8,x13
	leal	16(%a4),%a1
	QUARTERROUND((%a0),  (%a1),  (%a2),  (%a3) )	| x3, x4, x9,x14

	dbra	%d5,_loop

	| %a4 := x
	moveal	8(%fp),%a0	| %a0 := out

| Add SRC1 and DST and store to DST.
|  Use: %d0
#define ADDTOLE(SRC,DST) \
	movel	SRC,%d0; \
	addl	(%a0),%d0; \
	rorw	#8,%d0; \
	swap	%d0; \
	rorw	#8,%d0; \
	movel	%d0,DST

	ADDTOLE((%a4)+, (%a0)+)	| 0
	ADDTOLE((%a4)+, (%a0)+)	| 1
	ADDTOLE((%a4)+, (%a0)+)	| 2
	ADDTOLE((%a4)+, (%a0)+)	| 3
	ADDTOLE((%a4)+, (%a0)+)	| 4
	ADDTOLE((%a4)+, (%a0)+)	| 5
	ADDTOLE((%a4)+, (%a0)+)	| 6
	ADDTOLE((%a4)+, (%a0)+)	| 7
	ADDTOLE((%a4)+, (%a0)+)	| 8
	ADDTOLE((%a4)+, (%a0)+)	| 9
	ADDTOLE((%a4)+, (%a0)+)	| 10
	ADDTOLE((%a4)+, (%a0)+)	| 11
	ADDTOLE((%a4)+, (%a0)+)	| 12
	ADDTOLE((%a4)+, (%a0)+)	| 13
	ADDTOLE((%a4)+, (%a0)+)	| 14
	ADDTOLE((%a4) , (%a0) )	| 15

	moveml	(%sp)+,%d2-%d5/%a2-%a4
	unlk	%fp
	rts
	.size	crypto_core, .-crypto_core
