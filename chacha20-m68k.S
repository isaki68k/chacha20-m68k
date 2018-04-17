| 演算順序 0-1-2-3, 15-14-13-12 こうすることでレジスタ状態の戻しを楽にする。
| 0, 4, 8, 12
| 1, 5, 9, 13
| 2, 6, 10, 14
| 3, 7, 11, 15
| 0, 5, 10, 15
| 3, 4, 9, 14
| 2, 7, 8, 13
| 1, 6, 11, 12

| out[16], c[4], k[8], in[4]
| レジスタマップ
| 最初と最後にアクセスする位置をデータレジスタにする。
| 初期状態と最終状態を同じにすることでループしやすい。
| d0, d2, d5, d7
| d1, d3, a3, a5
| a0, d4, a4, a6
| a1, a2, d6, ()

| a+=b; d^=a; d=rol(d,16)
| c+=d; b^=c; b=rol(b,12)
| a+=b; d^=a; d=rol(d,8)
| c+=d; b^=c; b=rol(b,7)
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
	roll	#7,B;


| DREG = BSWAP(SRC)
#define LD(SRC,DREG)	\
	movel	SRC,DREG; \
	rolw	#8,DREG; \
	swap	DREG; \
	rolw	#8,DREG;

	.global	crypto_core
	.type	crypto_core, @function
crypto_core:
ENTRY:
	linkw	%fp,#-64
	moveml	%d2-%d7/%a2-%a5,-(%sp)
	movel	%fp,-(%sp)		| save fp
					| sp+0	 = fp
	lea	-64(%fp),%a5		| %a5 = J

	movel	8(%fp),%a0		| %a0 = &c[0]
	movel	12(%fp),%a1		| %a1 = &k[0]
	leal	16(%a1),%a2		| %a2 = &k[4]
	movel	16(%fp),%a3		| %a3 = &in[0]

	moveq	#4-1,%d2
LDLOOP2:
	moveq	#4-1,%d1
LDLOOP1:
	LD( (%a0)+, %d0 )		| J[0..15] = bswap( {c,k,in} [0..{4,8,4}] )
	movel	%d0,(%a5)+		
	dbra	%d1,LDLOOP1
	
	movel	%a1,%a0
	movel	%a2,%a1
	movel	%a3,%a2
	dbra	%d2,LDLOOP2

| レジスタマップ
| d0, d2, d5, d7
| d1, d3, a3, a5
| a0, d4, a4, a6
| a1, a2, d6, ()

	movel	-(%a5),-(%sp)		| X15
	movel	-(%a5),%a6		| X14 (fp broken here)
	subql	#4,%a5			| skip X13;
	movel	-(%a5),%d7		| X12
	movel	-(%a5),%d6		| X11
	movel	-(%a5),%a4		| X10
	movel	-(%a5),%a3		| X9
	movel	-(%a5),%d5		| X8
	movel	-(%a5),%a2		| X7
	movel	-(%a5),%d4		| X6
	movel	-(%a5),%d3		| X5
	movel	-(%a5),%d2		| X4
	movel	-(%a5),%a1		| X3
	movel	-(%a5),%a0		| X2
	movel	-(%a5),%d1		| X1
	movel	-(%a5),%d0		| X0

	movel	(13*4)(%a5),%a5		| X13

#define ROUND	20
	movel	#(ROUND/2),-(%sp)	| counter
					| sp+0	counter
					| sp+4	X15
					| sp+8	fp

QRLOOP:

| 0, 4, 8, 12
| 1, 5, 9, 13
| 2, 6, 10, 14
| 3, 7, 11, 15
| レジスタマップ
| d0, d2, d5, d7
| d1, d3, a3, a5
| a0, d4, a4, a6
| a1, a2, d6, ()

| 0, 4, 8, 12 = d0 d2 d5 d7
	QUARTERROUND(%d0,%d2,%d5,%d7)

	exg	%d5,%a3
	exg	%d7,%a5

| レジスタマップ
| d0, d2, a3, a5
| d1, d3, d5, d7
| a0, d4, a4, a6
| a1, a2, d6, ()

| 1, 5, 9, 13 = d1 d3 d5 d7
	QUARTERROUND(%d1,%d3,%d5,%d7)

| レジスタマップ
| d0, d2, a3, a5
| d1, d3, d5, d7
| a0, d4, a4, a6
| a1, a2, d6, ()

	exg	%d1,%a0
	exg	%d5,%a4
	exg	%d7,%a6

| レジスタマップ
| d0, d2, a3, a5
| a0, d3, a4, a6
| d1, d4, d5, d7
| a1, a2, d6, ()

| 2, 6, 10, 14 = d1 d4 d5 d7
	QUARTERROUND(%d1,%d4,%d5,%d7)

	movel	%d7,-(%sp)	| push X14
	exg	%d1,%a1
	exg	%d4,%a2
	movel	8(%sp),%d7	| X15
| レジスタマップ
| d0, d2, a3, a5
| a0, d3, a4, a6
| a1, a2, d5, ()
| d1, d4, d6, d7


| 3, 7, 11, 15 = d1 d4 d6 d7
	QUARTERROUND(%d1,%d4,%d6,%d7)

| 0, 5, 10, 15 = d0 d3 d5 d7
	QUARTERROUND(%d0,%d3,%d5,%d7)

	movel	%d7,8(%sp)	| X15
	exg	%d5,%a4
	movel	(%sp)+,%d7	| pop X14

| レジスタマップ
| d0, d2, a3, a5
| a0, d3, d5, a6
| a1, a2, a4, d7
| d1, d4, d6, ()

| 3, 4, 9, 14 = d1 d2 d5 d7
	QUARTERROUND(%d1,%d2,%d5,%d7)

	exg	%d7,%a6
	exg	%d6,%a3
	exg	%d1,%a0

| レジスタマップ
| d0, d2, d5, a5
| a0, d3, a3, d7
| d1, a2, a4, a6
| a1, d4, d6, ()

| 2, 7, 8, 13 = d1 d4 d5 d7
	QUARTERROUND(%d1,%d4,%d5,%d7)

	exg	%d7,%a5
	exg	%d4,%a2
	exg	%d1,%a0

| レジスタマップ
| d0, d2, d5, d7
| d1, d3, a3, a5
| a0, d4, a4, a6
| a1, a2, d6, ()

| 1, 6, 11, 12 = d1 d4 d6 d7
	QUARTERROUND(%d1,%d4,%d6,%d7)

	subql	#1,(%sp)		| counter
	bne	QRLOOP

	movel	%a6,(%sp)	| discard counter && push X14
	movel	%a5,-(%sp)	| push X13
				| sp+0	X13
				| sp+4	X14
				| sp+8	X15
				| sp+12	fp

	movel	12(%sp),%a6	| %a6 = fp
	leal	-64(%a6),%a5	| %a5 = J
	movel	4(%a6),%a6	| %a6 = out

#define STORE(DREG,DST) \
	rolw	#8,DREG; \
	swap	DREG; \
	rolw	#8,DREG; \
	movel	DREG,DST;

	addl	(%a5)+,%d0	| X0 += J[0]
	STORE(%d0,(%a6)+)
	addl	(%a5)+,%d1	| X1 += J[1]
	STORE(%d1,(%a6)+)
	addl	(%a5)+,%a0	| X2
	movel	%a0,%d0
	STORE(%d0,(%a6)+)
	addl	(%a5)+,%a1	| X3
	movel	%a1,%d0
	STORE(%d0,(%a6)+)
	addl	(%a5)+,%d2	| X4
	STORE(%d2,(%a6)+)
	addl	(%a5)+,%d3	| X5
	STORE(%d3,(%a6)+)
	addl	(%a5)+,%d4	| X6
	STORE(%d4,(%a6)+)
	addl	(%a5)+,%a2	| X7
	movel	%a2,%d0
	STORE(%d0,(%a6)+)
	addl	(%a5)+,%d5	| X8
	STORE(%d5,(%a6)+)
	addl	(%a5)+,%a3	| X9
	movel	%a3,%d0
	STORE(%d0,(%a6)+)
	addl	(%a5)+,%a4	| X10
	movel	%a4,%d0
	STORE(%d0,(%a6)+)
	addl	(%a5)+,%d6	| X11
	STORE(%d6,(%a6)+)
	addl	(%a5)+,%d7	| X12
	STORE(%d7,(%a6)+)

	moveq	#3-1,%d1
STORELOOP:
	movel	(%sp)+,%d0	| pop X13,X14,X15
	addl	(%a5)+,%d0
	STORE(%d0,(%a6)+)
	dbra	%d1,STORELOOP

	movel	(%sp)+,%fp
	movem	(%sp)+,%d2-%d7/%a2-%a5
	unlk	%fp
	rts
	.size	crypto_core, .-crypto_core
