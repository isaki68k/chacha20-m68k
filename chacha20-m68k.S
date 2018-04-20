| vi:set ts=8:

| QuarterRound order is following:
|  QR( x0, x4, x8,x12)
|  QR( x1, x5, x9,x13)
|  QR( x2, x6,x10,x14)
|  QR( x3, x7,x11,x15)
|  QR( x0, x5,x10,x15)
|  QR( x1, x6,x11,x12)
|  QR( x2, x7, x8,x13)
|  QR( x3, x4, x9,x14)
| However, since there is no dependency on the order within a Round,
| so exchange the order in "Diagonal Round"(second half round).  It makes
| register transition easier:
|  QR( x0, x4, x8,x12)
|  QR( x1, x5, x9,x13)
|  QR( x2, x6,x10,x14)
|  QR( x3, x7,x11,x15)
|  QR( x0, x5,x10,x15)
|  QR( x3, x4, x9,x14)
|  QR( x2, x7, x8,x13)
|  QR( x1, x6,x11,x12)

| a+=b; d^=a; d<<<=16;
| c+=d; b^=c; b<<<=12;
| a+=b; d^=a; d<<<=8;
| c+=d; b^=c; b<<<=7;
| Let the low byte of %d7 = 12.
#define QUARTERROUND(A,B,C,D)	\
	addl	B,A; \
	eorl	A,D; \
	swap	D; \
	addl	D,C; \
	eorl	C,B; \
	roll	%d7,B; \
	addl	B,A; \
	eorl	A,D; \
	roll	#8,D; \
	addl	D,C; \
	eorl	C,B; \
	roll	#7,B;


	.global	crypto_core
	.type	crypto_core, @function
crypto_core:
	linkw	%fp,#-64
	moveml	%d2-%d7/%a2-%a5,-(%sp)
	movel	%fp,-(%sp)		| save %fp
	lea	-64(%fp),%a5		| %a5 = j

	movel	20(%fp),%a0		| %a0 = &c[0]
	movel	16(%fp),%a1		| %a1 = &k[0]
	leal	16(%a1),%a2		| %a2 = &k[4]
	movel	12(%fp),%a3		| %a3 = &in[0]

	/*
	 * Load
	 *
	 * for (i = 0; i < 4; i++)
	 *   j[i] = le32toh(c[i]);
	 * for (i = 0; i < 8; i++)
	 *   j[4+i] = le32toh(k[i]);
	 * for (i = 0; i < 4; i++)
	 *   j[12+i] = le32toh(in[i]);
	 */

	movel	%a5,%a6			| %a6 = j (break %fp here)

	| To improve performance, memory access instructions and register
	| operation instructions should be interleaved though it makes
	| difficult for humans to read...
	| And why m68k does not have bswap32 :)
	moveq	#4-1,%d7
LDLOOP:
	movel	(%a0)+,%d0
	rolw	#8,%d0
	movel	(%a0)+,%d1
	swap	%d0
	rolw	#8,%d0
	movel	%d0,(%a5)+
	rolw	#8,%d1
	movel	(%a0)+,%d2
	swap	%d1
	rolw	#8,%d1
	movel	%d1,(%a5)+
	rolw	#8,%d2
	movel	(%a0),%d3
	swap	%d2
	rolw	#8,%d2
	movel	%d2,(%a5)+
	rolw	#8,%d3
	swap	%d3
	rolw	#8,%d3
	movel	%d3,(%a5)+

	movel	%a1,%a0
	movel	%a2,%a1
	movel	%a3,%a2
	dbra	%d7,LDLOOP

	/* Copy j[] to x[] */
	| Register map:
	| 0, 4, 8,12   d0, d2, d4, d6
	| 1, 5, 9,13 = d1, a2, a4, a6
	| 2, 6,10,14   a0, d3, a5,(m0)
	| 3, 7,11,15   a1, a3, d5,(m1)

	movel	%d3,-(%sp)		| x15
	movel	%d2,-(%sp)		| x14
	movel	%d0,%d6			| x12
	movel	%d1,-(%sp)		| x13

	movel	(%a6)+,%d0		| x0
	movel	(%a6)+,%d1		| x1
	movel	(%a6)+,%a0		| x2
	movel	(%a6)+,%a1		| x3
	movel	(%a6)+,%d2		| x4
	movel	(%a6)+,%a2		| x5
	movel	(%a6)+,%d3		| x6
	movel	(%a6)+,%a3		| x7
	movel	(%a6)+,%d4		| x8
	movel	(%a6)+,%a4		| x9
	movel	(%a6)+,%a5		| x10
	movel	(%a6),%d5		| x11

#define ROUND	20
	| %d7 := $xxxxCCRR
	| CC (high byte) is loop counter and detects carry.
	| RR (low byte) is rotate counter(12). Note that rotate instructions
	| only refer the lower 6 bits of rotate register.
	movew	#(((256-(ROUND / 2)) << 8) + 12),%d7

	movel	(%sp),%a6		| reload x13
	| sp+0  x13
	| sp+4  x14
	| sp+8  x15
	| sp+12 fp

	/*
	 * Quarter Round Loop
	 */
QRLOOP:
	| Register map:
	| 0, 4, 8, 12   d0, d2, d4, d6
	| 1, 5, 9, 13 = d1, a2, a4, a6
	| 2, 6,10, 14   a0, d3, a5,(m4)
	| 3, 7,11, 15   a1, a3, d5,(m8)

	QUARTERROUND(%d0,%d2,%d4,%d6)	| ( x0, x4, x8,x12)

	exg	%d2,%a2
	exg	%d4,%a4
	exg	%d6,%a6

	| 0, 4, 8, 12   d0, a2, a4, a6
	| 1, 5, 9, 13 = d1, d2, d4, d6
	| 2, 6,10, 14   a0, d3, a5,(m4)
	| 3, 7,11, 15   a1, a3, d5,(m8)

	QUARTERROUND(%d1,%d2,%d4,%d6)	| ( x1, x5, x9,x13)

	movel	%d6,(%sp)+	| save x13
	exg	%d1,%a0
	movel	(%sp),%d6	| load x14
	exg	%d4,%a5

	| 0, 4, 8, 12   d0, a2, a4, a6
	| 1, 5, 9, 13 = a0, d2, a5,(m0)
	| 2, 6,10, 14   d1, d3, d4, d6
	| 3, 7,11, 15   a1, a3, d5,(m8)

	QUARTERROUND(%d1,%d3,%d4,%d6)	| ( x2, x6,x10,x14)

	movel	%d6,(%sp)+	| x14
	exg	%d1,%a1
	movel	(%sp),%d6	| x15
	exg	%d3,%a3

	| 0, 4, 8, 12   d0, a2, a4, a6
	| 1, 5, 9, 13 = a0, d2, a5,(m0)
	| 2, 6,10, 14   a1, a3, d4,(m4)
	| 3, 7,11, 15   d1, d3, d5, d6

	QUARTERROUND(%d1,%d3,%d5,%d6)	| ( x3, x7,x11,x15)

	QUARTERROUND(%d0,%d2,%d4,%d6)	| ( x0, x5,x10,x15)

	movel	%d6,(%sp)	| x15
	exg	%d4,%a5
	movel	-(%sp),%d6	| x14
	exg	%d2,%a2

	| 0, 4, 8, 12   d0, d2, a4, a6
	| 1, 5, 9, 13 = a0, a2, d4,(m0)
	| 2, 6,10, 14   a1, a3, a5, d6
	| 3, 7,11, 15   d1, d3, d5,(m8)

	QUARTERROUND(%d1,%d2,%d4,%d6)	| ( x3, x4, x9,x14)

	movel	%d6,(%sp)	| x14
	exg	%d4,%a4
	movel	-(%sp),%d6	| x13
	exg	%d1,%a1

	| 0, 4, 8, 12   d0, d2, d4, a6
	| 1, 5, 9, 13 = a0, a2, a4, d6
	| 2, 6,10, 14   d1, a3, a5,(m4)
	| 3, 7,11, 15   a1, d3, d5,(m8)

	QUARTERROUND(%d1,%d3,%d4,%d6)	| ( x2, x7, x8,x13)

	exg	%d6,%a6
	exg	%d3,%a3
	exg	%d1,%a0

	| 0, 4, 8, 12   d0, d2, d4, d6
	| 1, 5, 9, 13 = d1, a2, a4, a6
	| 2, 6,10, 14   a0, d3, a5,(m4)
	| 3, 7,11, 15   a1, a3, d5,(m8)

	QUARTERROUND(%d1,%d3,%d5,%d6)	| ( x1, x6,x11,x12)

	addiw	#256,%d7
	bcc	QRLOOP

	/*
	 * Store
	 *
	 * for (i = 0; i < 16; i++)
	 *   out[i] = htole32(x[i] + j[i]);
	 */
	movel	%a6,(%sp)	| save x13
	| sp+0  x13
	| sp+4  x14
	| sp+8  x15
	| sp+12 fp
	movel	%a5,%d7		| %d7 := x10

	moveal	12(%sp),%a6	| %a6 := %fp
	leal	-64(%a6),%a5	| %a5 := j
	moveal	8(%a6),%a6	| %a6 := out

	| 0, 4, 8, 12   d0, d2, d4, d6
	| 1, 5, 9, 13 = d1, a2, a4,(m0)
	| 2, 6,10, 14   a0, d3, d7,(m4)
	| 3, 7,11, 15   a1, a3, d5,(m8)

	| Do interleaved store
#define ST2(DR1,DR2) \
	rolw	#8,DR1; \
	swap	DR1; \
	addl	(%a5)+,DR2; \
	rolw	#8,DR1; \
	movel	DR1,(%a6)+;

	addl	(%a5)+,%d0
	ST2(%d0,%d1)		| x0
	ST2(%d1,%a0)		| x1
	movel	%a0,%d0
	ST2(%d0,%a1)		| x2
	movel	%a1,%d0
	ST2(%d0,%d2)		| x3
	ST2(%d2,%a2)		| x4
	movel	%a2,%d0
	ST2(%d0,%d3)		| x5
	ST2(%d3,%a3)		| x6
	movel	%a3,%d0
	ST2(%d0,%d4)		| x7
	ST2(%d4,%a4)		| x8
	movel	%a4,%d0
	ST2(%d0,%d7)		| x9
	ST2(%d7,%d5)		| x10
	ST2(%d5,%d6)		| x11

	rolw	#8,%d6
	swap	%d6
	movel	(%sp)+,%d0	| pop x13
	rolw	#8,%d6
	movel	%d6,(%a6)+	| x12

	addl	(%a5)+,%d0
	rolw	#8,%d0
	movel	(%sp)+,%d1	| pop x14
	swap	%d0
	addl	(%a5)+,%d1
	rolw	#8,%d0
	movel	%d0,(%a6)+	| x13
	rolw	#8,%d1
	movel	(%sp)+,%d2	| pop x15
	swap	%d1
	addl	(%a5),%d2
	rolw	#8,%d1
	movel	%d1,(%a6)+	| x14
	rolw	#8,%d2
	swap	%d2
	rolw	#8,%d2
	movel	%d2,(%a6)	| x15

	movel	(%sp)+,%fp
	moveml	(%sp)+,%d2-%d7/%a2-%a5
	unlk	%fp
	rts
	.size	crypto_core, .-crypto_core
