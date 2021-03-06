/*
 * Use the fixed point version of Barrett reduction to compute a mod n
 * over GF(2) for given n using POWER8 instructions. We use k = 32.
 *
 * http://en.wikipedia.org/wiki/Barrett_reduction
 *
 * Copyright (C) 2015 Anton Blanchard <anton@au.ibm.com>, IBM
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of either:
 *
 *  a) the GNU General Public License as published by the Free Software
 *     Foundation; either version 2 of the License, or (at your option)
 *     any later version, or
 *  b) the Apache License, Version 2.0
 */
#include <ppc-asm.h>
#include "common/ppc-opcode.h"

#undef toc

#ifndef r1
#define r1 1
#endif

#ifndef r2
#define r2 2
#endif

	.section	.data
.balign 16

.barrett_fz_constants:
	/* Barrett constant m - (4^32)/n */
	.octa 0x0000000000000000000000011f91caf6	/* x^64 div p(x) */
	/* Barrett constant n */
	.octa 0x0000000000000000000000011edc6f41

.text
/* unsigned int barrett_reduction(unsigned long val) */
FUNC_START(barrett_reduction)
	addis	r4,r2,.barrett_fz_constants@toc@ha
	addi	r4,r4,.barrett_fz_constants@toc@l

	li	r5,16
	vxor	v1,v1,v1	/* zero v1 */

	/* Get a into v0 */
	MTVRD(v0, r3)
	vsldoi	v0,v1,v0,8	/* shift into bottom 64 bits, this is a */

	/* Load constants */
	lvx	v2,0,r4		/* m */
	lvx	v3,r5,r4	/* n */

	/*
	 * Now for the actual algorithm. The idea is to calculate q,
	 * the multiple of our polynomial that we need to subtract. By
	 * doing the computation 2x bits higher (ie 64 bits) and shifting the
	 * result back down 2x bits, we round down to the nearest multiple.
	 */
	VPMSUMD(v4,v0,v2)	/* ma */
	vsldoi	v4,v1,v4,8	/* q = floor(ma/(2^64)) */
	VPMSUMD(v4,v4,v3)	/* qn */
	vxor	v0,v0,v4	/* a - qn, subtraction is xor in GF(2) */

	/*
	 * Get the result into r3. We need to shift it left 8 bytes:
	 * V0 [ 0 1 2 X ]
	 * V0 [ 0 X 2 3 ]
	 */
	vsldoi	v0,v0,v1,8	/* shift result into top 64 bits of v0 */
	MFVRD(r3, v0)

	blr
FUNC_END(barrett_reduction)
	
