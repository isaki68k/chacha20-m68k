| vi:set ts=8:

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
| d0, d2, d4, d6
| d1, a2, a4, a6
| a0, d3, a5, (x14)
| a1, a3, d5, (x15)
| d7 はワークレジスタ。

| a+=b; d^=a; d=rol(d,16)
| c+=d; b^=c; b=rol(b,12)
| a+=b; d^=a; d=rol(d,8)
| c+=d; b^=c; b=rol(b,7)
| %d7 の下位に 12 が置かれていること。
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
	movel	%sp,%a0
	moveml	%d2-%d7/%a2-%a6,-(%sp)

	leal	-12-64(%sp),%a6

	addql	#8,%a0		| skip PC, out
	movel	(%a0)+,%a3	| %a3 = &in[0]
	movel	(%a0)+,%a1	| %a1 = &k[0]
	leal	16(%a1),%a2	| %a2 = &k[4]
	movel	(%a0),%a0	| %a0 = &c[0]

	moveq	#4-1,%d7
LDLOOP:
	movel	(%a0)+,%d0
	rolw	#8,%d0
	movel	(%a0)+,%d1
	swap	%d0
	rolw	#8,%d0
	movel	%d0,(%a6)+
	rolw	#8,%d1
	movel	(%a0)+,%d2
	swap	%d1
	rolw	#8,%d1
	movel	%d1,(%a6)+
	rolw	#8,%d2
	movel	(%a0),%d3
	swap	%d2
	rolw	#8,%d2
	movel	%d2,(%a6)+
	rolw	#8,%d3
	swap	%d3
	rolw	#8,%d3
	movel	%d3,(%a6)+

	movel	%a1,%a0
	movel	%a2,%a1
	movel	%a3,%a2
	dbra	%d7,LDLOOP
				| sp-76 J0
				| ...
				| sp-16 J15
				| sp-12 (X13)
				| sp-8  (X14)
				| sp-4  (X15)
				| sp+0  movem 11 longword
				| sp+44 retPC

| レジスタマップ
| d0, d2, d4, d6
| d1, a2, a4, a6
| a0, d3, a5, (x14)
| a1, a3, d5, (x15)

				| work push
	
	movel	%d3,-(%sp)	| X15
	movel	%d2,-(%sp)	| X14
	movel	%d1,-(%sp)	| X13
				| sp-64 J0
				| ...
				| sp-4  J15
				| sp+0  X13
				| sp+4  X14
				| sp+8  X15
				| sp+12 movem

	movel	%d0,%d6			| X12

	leal	-64(%a6),%a6
	movel	(%a6)+,%d0		| X0
	movel	(%a6)+,%d1		| X1
	movel	(%a6)+,%a0		| X2
	movel	(%a6)+,%a1		| X3
	movel	(%a6)+,%d2		| X4
	movel	(%a6)+,%a2		| X5
	movel	(%a6)+,%d3		| X6
	movel	(%a6)+,%a3		| X7
	movel	(%a6)+,%d4		| X8
	movel	(%a6)+,%a4		| X9
	movel	(%a6)+,%a5		| X10
	movel	(%a6),%d5		| X11

	movel	(%sp),%a6		| X13

#define ROUND	20
	movew	#(((256-(ROUND / 2)) << 8) + 12),%d7	| d7 = {?,?,counter,12}

					| sp+0	X13
					| sp+4	X14
					| sp+8	X15

QRLOOP:
| 0, 4, 8, 12
| 1, 5, 9, 13
| 2, 6, 10, 14
| 3, 7, 11, 15
| レジスタマップ
| d0, d2, d4, d6
| d1, a2, a4, a6
| a0, d3, a5, (4)
| a1, a3, d5, (8)

| 0, 4, 8, 12 = d0 d2 d4 d6
	QUARTERROUND(%d0,%d2,%d4,%d6)

	exg	%d2,%a2
	exg	%d4,%a4
	exg	%d6,%a6

| レジスタマップ
| d0, a2, a4, a6
| d1, d2, d4, d6
| a0, d3, a5, (4)
| a1, a3, d5, (8)

| 1, 5, 9, 13 = d1 d2 d4 d6
	QUARTERROUND(%d1,%d2,%d4,%d6)

	movel	%d6,(%sp)+	| save X13
	exg	%d1,%a0
	movel	(%sp),%d6	| load X14
	exg	%d4,%a5

| レジスタマップ
| d0, a2, a4, a6
| a0, d2, a5, (0)
| d1, d3, d4, d6
| a1, a3, d5, (8)

| 2, 6, 10, 14 = d1 d3 d4 d6
	QUARTERROUND(%d1,%d3,%d4,%d6)

	movel	%d6,(%sp)+	| X14
	exg	%d1,%a1
	movel	(%sp),%d6	| X15
	exg	%d3,%a3

| レジスタマップ
| d0, a2, a4, a6
| a0, d2, a5, (0)
| a1, a3, d4, (4)
| d1, d3, d5, d6


| 3, 7, 11, 15 = d1 d3 d5 d6
	QUARTERROUND(%d1,%d3,%d5,%d6)

| 0, 5, 10, 15 = d0 d2 d4 d6
	QUARTERROUND(%d0,%d2,%d4,%d6)

	movel	%d6,(%sp)	| X15
	exg	%d4,%a5
	movel	-(%sp),%d6	| X14
	exg	%d2,%a2

| レジスタマップ
| d0, d2, a4, a6
| a0, a2, d4, (0)
| a1, a3, a5, d6
| d1, d3, d5, (8)

| 3, 4, 9, 14 = d1 d2 d4 d6
	QUARTERROUND(%d1,%d2,%d4,%d6)

	movel	%d6,(%sp)	| X14
	exg	%d4,%a4
	movel	-(%sp),%d6	| X13
	exg	%d1,%a1

| レジスタマップ
| d0, d2, d4, a6
| a0, a2, a4, d6
| d1, a3, a5, (4)
| a1, d3, d5, (8)

| 2, 7, 8, 13 = d1 d3 d4 d6
	QUARTERROUND(%d1,%d3,%d4,%d6)

	exg	%d6,%a6
	exg	%d3,%a3
	exg	%d1,%a0

| レジスタマップ
| d0, d2, d4, d6
| d1, a2, a4, a6
| a0, d3, a5, (4)
| a1, a3, d5, (8)

| 1, 6, 11, 12 = d1 d3 d5 d6
	QUARTERROUND(%d1,%d3,%d5,%d6)

	addiw	#256,%d7
	bcc	QRLOOP

	movel	%a6,(%sp)	| modify X13
				| sp-64 J0 
				| ...
				| sp-4  J15
				| sp+0  X13
				| sp+4  X14
				| sp+8  X15
				| sp+12 movem 11 longword
				| sp+56 retPC
				| sp+60 out
	movel	%a5,%d7		| d7 = X10

	leal	-64(%sp),%a5	| %a5 = &J[0]
	movel	60(%sp),%a6	| %a6 = out
	
| d0, d2, d4, d6
| d1, a2, a4, (0)
| a0, d3, d7, (4)
| a1, a3, d5, (8)

#define ST(DR1,DR2) \
	rolw	#8,DR1; \
	swap	DR1; \
	addl	(%a5)+,DR2; \
	rolw	#8,DR1; \
	movel	DR1,(%a6)+;

| d0, d2, d4, d6
| d1, a2, a4, (0)
| a0, d3, d7, (4)
| a1, a3, d5, (8)

	addl	(%a5)+,%d0
	ST(%d0,%d1)		| X0
	ST(%d1,%a0)		| X1
	movel	%a0,%d0
	ST(%d0,%a1)		| X2
	movel	%a1,%d0
	ST(%d0,%d2)		| X3
	ST(%d2,%a2)		| X4
	movel	%a2,%d0
	ST(%d0,%d3)		| X5
	ST(%d3,%a3)		| X6
	movel	%a3,%d0
	ST(%d0,%d4)		| X7
	ST(%d4,%a4)		| X8
	movel	%a4,%d0
	ST(%d0,%d7)		| X9
	ST(%d7,%d5)		| X10
	ST(%d5,%d6)		| X11

	rolw	#8,%d6
	swap	%d6
	movel	(%sp)+,%d0	| pop X13
	rolw	#8,%d6
	movel	%d6,(%a6)+	| X12

	addl	(%a5)+,%d0
	rolw	#8,%d0
	movel	(%sp)+,%d1	| pop X14
	swap	%d0
	addl	(%a5)+,%d1
	rolw	#8,%d0
	movel	%d0,(%a6)+	| X13
	rolw	#8,%d1
	movel	(%sp)+,%d2	| pop X15
	swap	%d1
	addl	(%a5),%d2
	rolw	#8,%d1
	movel	%d1,(%a6)+	| X14
	rolw	#8,%d2
	swap	%d2
	rolw	#8,%d2
	movel	%d2,(%a6)	| x15

	moveml	(%sp)+,%d2-%d7/%a2-%a6
	rts
	.size	crypto_core, .-crypto_core

| XXX: old
|     D0  D1  D2  D3  D4  D5  D6  D7  A0 A1 A2 A3 A4 A5 A6 (SP)
| Q1:[ 0]  1 [ 4]  5   6 [ 8] 11 [12]  2  3  7  9 10 13 14 15
|      |   |   |   |   |   X   |   X   |  |  |  *  |  *  |  |
| Q2:  | [ 1]  | [ 5]  | [ 9]  | [13]  2  |  |  8 10 12 14  |
|      |   X   |   |   |   X   |   X   *  |  |  |  *  |  *  |
| Q3:  | [ 2]  |   | [ 6][10]  | [14]  1  3  7  |  9  | 13 15
|      |   X   |   |   X   |   |   X   |  *  *  |  |  |  |  *
| Q4:  | [ 3]  |   | [ 7]  | [11][15]  |  2  6  |  |  |  | 14
|      |   |   |   |   |   |   |   |   |  |  |  |  |  |  |  |
| Q5:[ 0]  |   | [ 5]  | [10]  | [15]  |  |  |  |  9  |  | 14
|      |   |   |   |   |   X   |   X   |  |  |  |  *  |  |  *
| Q6:  | [ 3][ 4]  |   | [ 9]  | [14]  |  2  |  8 10  | 13 15
|      |   X   |   |   |   X   |   X   |  *  |  *  |  |  *  |
| Q7:  | [ 2]  |   | [ 7][ 8]  | [13]  1  3  6  9  | 12 14  |
|      |   X   |   |   X   |   |   X   *  |  *  |  |  *  |  |
| Q8:  | [ 1]  |   | [ 6]  | [11][12]  2  |  7  |  | 13  |  |
