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
	moveml	%d2-%d7/%a2-%a5,-(%sp)
	moveal	12(%fp),%a1	| %a1 := in
	moveal	16(%fp),%a2	| %a2 := k
	moveal	20(%fp),%a3	| %a3 := c

	leal	-128(%fp),%a4	| %a4 := x
	leal	-64(%fp),%a5	| %a5 := j

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

	LOAD_LE2((%a3)+, (%a3)+)	| j0,j1   = x0,x1   = c+0,4
	LOAD_LE2((%a3)+, (%a3) )	| j2,j3   = x2,x3   = c+8,12
	LOAD_LE2((%a2)+, (%a2)+)	| j4,j5   = x4,x5   = k+0,4
	LOAD_LE2((%a2)+, (%a2)+)	| j6,j7   = x6,x7   = k+8,12
	LOAD_LE2((%a2)+, (%a2)+)	| j8,j9   = x8,x9   = k+16,20
	LOAD_LE2((%a2)+, (%a2) )	| j10,j11 = x10,x11 = k+24,28
	LOAD_LE2((%a1)+, (%a1)+)	| j12,j13 = x12,x13 = in+0,4
	LOAD_LE2((%a1)+, (%a1) )	| j14,j15 = x14,x15 = in+8,12

	| Here %a4 := j (= x16)

	movel	%fp,-(%sp)
	movel	#(ROUNDS/2),-(%sp)
	leal	-128(%fp),%a3		| %a3 := x
	movel	(%a3)+,%d0		| x0
	movel	(%a3)+,%d4		| x1
	movel	(%a3)+,%a0		| x2
	movel	(%a3)+,%a4		| x3
	movel	(%a3)+,%d1		| x4
	movel	(%a3)+,%d5		| x5
	movel	(%a3)+,%a1		| x6
	movel	(%a3)+,%a5		| x7
	movel	(%a3)+,%d2		| x8
	movel	(%a3)+,%d6		| x9
	movel	(%a3)+,%a2		| x10
	movel	(%a3)+,%a6		| x11
	movel	(%a3)+,%d3		| x12
	movel	(%a3)+,%d7		| x13
	movel	4(%a3),-(%sp)		| x15
	movel	(%a3),%a3		| x14

	| %sp+0  = x15
	| %sp+4  = counter
	| %sp+8  = %fp

#define QUARTERROUND(A,B,C,D)	\
	addl	B,A; \
	eorl	A,D; \
	swap	D; \
	addl	D,C; \
	eorl	C,B; \
	swap	B; \
	rorl	#4,B; \
	addl	B,A; \
	eorl	A,D; \
	roll	#8,D; \
	addl	D,C; \
	eorl	C,B; \
	roll	#7,B
loop:
	| (1st) 0, 4, 8, 12
	QUARTERROUND(%d0, %d1, %d2, %d3)

	| (2nd) 1, 5, 9, 13
	QUARTERROUND(%d4, %d5, %d6, %d7)

	exg	%d0,%a0
	exg	%d1,%a1
	exg	%d2,%a2
	exg	%d3,%a3

	| (3rd) 2, 6, 10, 14
	QUARTERROUND(%d0, %d1, %d2, %d3)

	exg	%d4,%a4
	exg	%d5,%a5
	movel	%d7,-(%sp)
	exg	%d6,%a6
	movel	4(%sp),%d7

	| (4th) 3, 7, 11, 15
	QUARTERROUND(%d4, %d5, %d6, %d7)

	| レジスタマップ
	| 0, 4, 8, 12
	| 1, 5, 9, 13
	| 2, 6, 10, 14
	| 3, 7, 11, 15
	| a0, a1, a2, a3
	| a4, a5, a6, ()
	| d0, d1, d2, d3
	| d4, d5, d6, d7

	| (5th) 0, 5, 10, 15
	exg	%d0,%a0
	exg	%d5,%a5
	| レジスタマップ
	| 0, 4, 8, 12
	| 1, 5, 9, 13
	| 2, 6, 10, 14
	| 3, 7, 11, 15
	| d0, a1, a2, a3
	| a4, d5, a6, ()
	| a0, d1, d2, d3
	| d4, a5, d6, d7
	QUARTERROUND(%d0, %d5, %d2, %d7)

	| (6th) 1, 6, 11, 12
	exg	%d4,%a4
	exg	%d3,%a3
	| レジスタマップ
	| 0, 4, 8, 12
	| 1, 5, 9, 13
	| 2, 6, 10, 14
	| 3, 7, 11, 15
	| d0, a1, a2, d3
	| d4, d5, a6, ()
	| a0, d1, d2, a3
	| a4, a5, d6, d7
	QUARTERROUND(%d4, %d1, %d6, %d3)

	| (7th) 2, 7, 8, 13
	exg	%d0,%a0
	exg	%d5,%a5
	movel	%d7,4(%sp)
	exg	%d2,%a2
	movel	(%sp)+,%d7
	| レジスタマップ
	| 0, 4, 8, 12
	| 1, 5, 9, 13
	| 2, 6, 10, 14
	| 3, 7, 11, 15
	| a0, a1, d2, d3
	| d4, a5, a6, d7
	| d0, d1, a2, a3
	| a4, d5, d6, ()
	QUARTERROUND(%d0, %d5, %d2, %d7)

	| (8th) 3, 4, 9, 14
	exg	%d4,%a4
	exg	%d1,%a1
	exg	%d6,%a6
	exg	%d3,%a3
	| レジスタマップ
	| 0, 4, 8, 12
	| 1, 5, 9, 13
	| 2, 6, 10, 14
	| 3, 7, 11, 15
	| a0, d1, d2, a3
	| a4, a5, d6, d7
	| d0, a1, a2, d3
	| d4, d5, a6, ()
	QUARTERROUND(%d4, %d1, %d6, %d3)

	exg	%d0,%a0
	exg	%d3,%a3
	exg	%d4,%a4
	exg	%d5,%a5
	| レジスタマップ
	| 0, 4, 8, 12
	| 1, 5, 9, 13
	| 2, 6, 10, 14
	| 3, 7, 11, 15
	| d0, d1, d2, d3
	| d4, d5, d6, d7
	| a0, a1, a2, a3
	| a4, a5, a6, ()

	subql	#1,4(%sp)
	bne	loop

	movel	%a3,-(%sp)
	| %sp+0  = x14 (= %a3)
	| %sp+4  = x15
	| %sp+8  = counter
	| %sp+12 = %fp

	movel	12(%sp),%a3
	leal	-128(%a3),%a3		| %a3 := x
	movel	%d0,(%a3)+		| x0
	movel	%d4,(%a3)+		| x1
	movel	%a0,(%a3)+		| x2
	movel	%a4,(%a3)+		| x3
	movel	%d1,(%a3)+		| x4
	movel	%d5,(%a3)+		| x5
	movel	%a1,(%a3)+		| x6
	movel	%a5,(%a3)+		| x7
	movel	%d2,(%a3)+		| x8
	movel	%d6,(%a3)+		| x9
	movel	%a2,(%a3)+		| x10
	movel	%a6,(%a3)+		| x11
	movel	%d3,(%a3)+		| x12
	movel	%d7,(%a3)+		| x13
	movel	(%sp)+,(%a3)+		| x14
	movel	(%sp)+,(%a3)+		| x15
	addql	#4,%sp			| discard counter
	movel	(%sp)+,%a6		| restore %fp
	| %sp, %fp are now restored.

	| Store j + x -> out
	leal	-64(%fp),%a4	| %a4 := j
	leal	-128(%fp),%a5	| %a5 := x
	moveal	8(%fp),%a0	| %a0 := out
	moveql	#8-1,%d2
storeloop:
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
	dbra	%d2,storeloop

	moveml	(%sp)+,%d2-%d7/%a2-%a5
	unlk	%fp
	rts
	.size	crypto_core, .-crypto_core
