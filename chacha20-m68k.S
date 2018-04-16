| vi:set ts=8:
#define OUTPUTBYTES	64
#define INPUTBYTES	16
#define KEYBYTES	32
#define CONSTBYTES	16
#define ROUNDS	20

| Convert LE<->BE
.macro	BSWAP32	reg
	rorw	#8,\reg
	swap	\reg
	rorw	#8,\reg
.endm

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
	moveal	12(%fp),%a1	| %a1 := in
	moveal	16(%fp),%a2	| %a2 := k
	moveal	20(%fp),%a3	| %a3 := c

	leal	-128(%fp),%a4	| %a4 := x
	leal	-64(%fp),%a5	| %a5 := j

| Load from SRC and bswap it and then store it to x, j.
|  Inp: SRC
|  Out: %a4++, %a5++
|  Use: %d0
#define LOAD_LE(SRC)	\
	movel	SRC,%d0; \
	BSWAP32	%d0; \
	movel	%d0,(%a4)+; \
	movel	%d0,(%a5)+

| Load SRC1,SRC2 and bswap them and store them to x, j.
|  Inp: SRC1, SRC2
|  Out: %a4++, %a5++
|  Use: %d0, %d1
#define LOAD_LE2(SRC1, SRC2)	\
	movel	SRC1,%d0; \
	rorw	#8,%d0; \
	movel	SRC2,%d1; \
	swap	%d0; \
	rorw	#8,%d0; \
	movel	%d0,(%a4)+; \
	rorw	#8,%d1; \
	movel	%d0,(%a5)+; \
	swap	%d1; \
	rorw	#8,%d1; \
	movel	%d1,(%a4)+; \
	movel	%d1,(%a5)+

#if 0
	LOAD_LE((%a3)+)	| j0 : c +0
	LOAD_LE((%a3)+)	| j1 : c +4
	LOAD_LE((%a3)+)	| j2 : c +8
	LOAD_LE((%a3) )	| j3 : c +12
	LOAD_LE((%a2)+)	| j4 : k +0
	LOAD_LE((%a2)+)	| j5 : k +4
	LOAD_LE((%a2)+)	| j6 : k +8
	LOAD_LE((%a2)+)	| j7 : k +12
	LOAD_LE((%a2)+)	| j8 : k +16
	LOAD_LE((%a2)+)	| j9 : k +20
	LOAD_LE((%a2)+)	| j10: k +24
	LOAD_LE((%a2) )	| j11: k +28
	LOAD_LE((%a1)+)	| j12: in +0
	LOAD_LE((%a1)+)	| j13: in +4
	LOAD_LE((%a1)+)	| j14: in +8
	LOAD_LE((%a1) )	| j15: in +12
#else
	LOAD_LE2((%a3)+, (%a3)+)	| j0,j1   = x0,x1   = c+0,4
	LOAD_LE2((%a3)+, (%a3) )	| j2,j3   = x2,x3   = c+8,12
	LOAD_LE2((%a2)+, (%a2)+)	| j4,j5   = x4,x5   = k+0,4
	LOAD_LE2((%a2)+, (%a2)+)	| j6,j7   = x6,x7   = k+8,12
	LOAD_LE2((%a2)+, (%a2)+)	| j8,j9   = x8,x9   = k+16,20
	LOAD_LE2((%a2)+, (%a2) )	| j10,j11 = x10,x11 = k+24,28
	LOAD_LE2((%a1)+, (%a1)+)	| j12,j13 = x12,x13 = in+0,4
	LOAD_LE2((%a1)+, (%a1) )	| j14,j15 = x14,x15 = in+8,12
#endif

| Do QuarterRound.
|  Inp: %a0-%a3: source
|       %d4: shift count(=12)
|  Out: DST0-DST3 (%a0-%a3)
|  Use: %d0-%d3
#define QUARTERROUND(DST0, DST1, DST2, DST3) \
	movel	(%a0),%d0; \
	movel	(%a1),%d1; \
	movel	(%a3),%d3; \
	addl	%d1,%d0; \
	movel	(%a2),%d2; \
	eorl	%d0,%d3; \
	swap	%d3; \
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

	leal	-128(%fp),%a5	| %a5 := x
	| %a1 はループの最後と最初が同じになるので2回目以降は初期化不要
	leal	16(%a5),%a1	| %a1 := x4
	| %a2 はループ内では sub で調整したほうが速い
	leal	36(%a5),%a2	| %a2 := x9
	| %a3 もループ内では sub で調整したほうが速い
	lea	56(%a5),%a3	| %a3 := x14
2:
	leal	(%a5),%a0	| %a0 := x0
	subq	#4,%a2		| %a2 := x8
	subq	#8,%a3		| %a3 := x12

	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3)+)	| x0, x4, x8,x12
	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3)+)	| x1, x5, x9,x13
	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3)+)	| x2, x6,x10,x14
	QUARTERROUND((%a0),  (%a1),  (%a2),  (%a3) )	| x3, x7,x11,x15
	leal	(%a5),%a0
	subq	#8,%a1
	subq	#4,%a2
	QUARTERROUND((%a0)+, (%a1)+, (%a2)+, (%a3) )	| x0, x5,x10,x15
	suba	%d4,%a3
	QUARTERROUND((%a0)+, (%a1)+, (%a2),  (%a3)+)	| x1, x6,x11,x12
	suba	%d4,%a2
	QUARTERROUND((%a0)+, (%a1),  (%a2)+, (%a3)+)	| x2, x7, x8,x13
	suba	%d4,%a1
	QUARTERROUND((%a0),  (%a1),  (%a2),  (%a3) )	| x3, x4, x9,x14

	dbra	%d5,2b

	| Store j + x -> out
	| %a4 := j
	| %a5 := x
	moveal	8(%fp),%a0	| %a0 := out
#if 0
	moveql	#16-1,%d1
3:
	movel	(%a4)+,%d0
	addl	(%a5)+,%d0	| j[i] + x[i]
	BSWAP32	%d0
	movel	%d0,(%a0)+	| -> out[i]
	dbra	%d1, 3b
#else
	moveql	#8-1,%d2
3:
	movel	(%a4)+,%d0
	addl	(%a5)+,%d0	| j[i] + x[i]
	rorw	#8,%d0
	movel	(%a4)+,%d1
	swap	%d0
	addl	(%a5)+,%d1	| j[i+1] + x[i+1]
	rorw	#8,%d0
	movel	%d0,(%a0)+	| -> out[i]
	rorw	#8,%d1
	swap	%d1
	rorw	#8,%d1
	movel	%d1,(%a0)+	| -> out[i+1]
	dbra	%d2,3b
#endif

	moveml	(%sp)+,%d2-%d5/%a2-%a5
	unlk	%fp
	rts
	.size	crypto_core, .-crypto_core
