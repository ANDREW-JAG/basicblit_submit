	.68000

ASTEROIDS	= 0

	.include "68k_inc/jaguar.inc"
	.include "68k_inc/blit_eq.inc"
	.include "68k_mac/help.mac"
	.include "tom.equ"
***** Derived from https://github.com/42Bastian/new_bjl/tree/main/exp/blit_tst build
*****adapted and condensed with kind permission of original coder, 42bs.
***All rights reserved 1_10_2025
*********blit_tst.s altered now no swap display buffer no gpu usage no blitter.
********* -->displaysurfer.s and testing for ntsc and static display protection
****************functioning correct sprite rendering 1_10_2025
vars		= $0001000


max_x		= 240		;;db 30_6_25
max_y_gr	= 200		;;db 30_6_25
framecount_50hz	= 900		;;image will display for 18 seconds only in pal/ntsc mode
framecount_60hz	= 1080


*ScreenMode	EQU CRY16|VIDEN|PWIDTH4|BGEN|CSYNC		;;orig 30_6_25
ScreenMode	EQU RGB16|VIDEN|PWIDTH4|BGEN|CSYNC
*******************
* variables

	RSRESET
	RSB obl,256
	RSL obls

	RSW a_vde
	RSW a_vdb
	RSW screen_flag
	RSW screen_saver	
*	.include "68k_var/text_scr.var"	
	RSL StackBottom,200
	RSL stack,1

vars_len	= RSCOUNT
	IF vars_len > (100*1024)
	FAIL
	ENDIF
******************
	

init:	INCLUDE "68k_inc/startup.inc"
******************
* Main
	lea	vars,a6
	lea	stack(a6),sp

	move.l	a6,a0
	move.l	#vars_len,d0
	bsr	memzero

	;; Setup Text screen

;;;********************
;;; Video setup
	bsr	VideoInit
	bsr	InitOP
	move.w	#ScreenMode,$f00028


	move	#$2000,sr		;;turn interrupts on
	

;;->	move.w	#4,screen_flag(a6)
;;; Initial text out
	
	.globl again
again:
//->	move.l	screen(a6),a0
//->	move.l	#320*200*2,d0
//->	bsr	memzero


//->	addq.w	#2,Cursor(a6)
//->	move.l	d7,d0
//->	bsr	PrintHEXl
//->
//->	addq.w	#2,Cursor(a6)
//->	move.l	d6,d0
//->	bsr	PrintHEXl


	bra	again

******************
*	.include "68k_inc/text_scr.inc"
******************


	.phrase
	dc.l	0		; dummy

*    CopyOBL	*
CopyOBL:	;clumsy but looks ok
	move.w	#obls,d0
	move.l	(a6,d0.w),a1
	lea	obl(a6),a0
	moveq	#(obl0_60hz-obl0)/4-1,d0
co:
	move.l	(a1)+,(a0)+
	dbra	d0,co
	rts
*****************
*   videoinit	*
	.include "68k_inc/videoinit.inc"
*****************
*    InitOP	*
InitOP:
	move.w #framecount_50hz,d0	;;initialise screen burn-in protection
	move.w d0,screen_saver
	lea obls_50hz(pc),a0	
	btst	#4,$00F14003
	beq.s	io_pal
	lea obls_60hz(pc),a0
	move.w #framecount_60hz,d0	;;initialise screen burn-in protection
	move.w d0,screen_saver
	move.l	#$10008ff0,$f00400+254*2
io_pal:	
	move.l (a0),obls(a6)		;;testcode remove 27_6_25
	bsr	CopyOBL
	lea	$00F00000,a2
	moveq	#0,d0
	move.w	a_vde(a6),d0
	move.w	d0,d1
	bclr	#0,d1
	move.w  d0,$48(a2)            ;; vde
	addq	#4,d0
	move.w d0,$4e(a2)

	lea	obl(a6),a0
	move.l	a0,d0
	swap	d0
	move.l	d0,OLP-_BASE(a2)
	move.l	#($1F00|C_VIDENA)<<16,INT1-_BASE(a2)
	lea	my_irq(pc),a0
	move.l	a0,$00000100.w
	rts

******************
* IRQ
my_irq:
	movem.l d0-d2/a0-a1,-(sp)
	move.w	INT1,d2
	btst	#0,d2
	beq.s	no_vi
	move.w screen_saver,d0		;;decrement frame counter
	subq.w #1,d0
	move.w d0,screen_saver
	bpl pass3		;;
	lea obls_end(pc),a0
	move.l (a0),obls(a6)
pass3:	bsr	CopyOBL
no_vi:
cont_irq:
	lsl.w	#8,d2
	or.w	#C_VIDENA,d2
	swap	d2
	move.l	d2,INT1

	movem.l (sp)+,d0-d2/a0-a1
	rte

obls_50hz:	dc.l	obl0
obls_60hz:	dc.l	obl0_60hz
obls_end:	dc.l 	obend

;;; memzero
;;; a0 - destination
;;; d0 - size
memzero:
	move.l	(sp)+,a2
	lea	A1_BASE,a1
	move.l	a0,(a1)
	move.l	#BLIT_PITCH1|BLIT_PIXEL32|BLIT_WID3584|BLIT_XADDPHR,_BLIT_A1_FLAGS(a1)
	lsr.l	#2,d0
	bset	#16,d0
	move.l	d0,_BLIT_COUNT(a1)
	moveq	#0,d0
	move.l	d0,_BLIT_A1_PIXEL(a1)
	move.l	d0,_BLIT_CMD(a1)
wbl1:
	move.l	_BLIT_CMD(a1),d0
	btst	#0,d0
	beq.s	wbl1
	pea	(a2)
	rts

;;; memcpy with blitter
;;; A0 -> A1, size D0

******************
* text-data
	.dphrase
picture:
	incbin	"surffinal.data"
	.phrase

*****************
* Objekte

vde_pal		equ (PAL_VMID+PAL_HEIGHT)/2+1
vde_ntsc	equ (NTSC_VMID+NTSC_HEIGHT)/2+1

bpp		= 4
gr_phrase	= max_x/4
y_start_pal	= 32 
y_start_ntsc	= 24

	.phrase
obl0:
	.objproc
	.org	vars
 branch VC < 33,_stop0
 branch VC > vde_pal,_stop0
**** I have changed the next instruction from--> bitmap picture,9,y_start_pal+1,gr_phrase,gr_phrase,max_y_gr,bpp,0,NOTRANS RELEASE,0,1
**** which is the expected behaviour to its current form to fix a discrepancy in the compile and linking process.
**** for creating .cof , other offsets required for .rom, and .j64.
 bitmap $4000+$250,9,y_start_pal+1,gr_phrase,gr_phrase,max_y_gr,bpp,0,NOTRANS RELEASE,0,1
_stop0:
 stop
	.68000
obl0_60hz:
	.objproc
	.org	vars
 branch VC < 25,_stop0_60hz
 branch VC > vde_ntsc,_stop0_60hz
**** I have changed the next instruction from--> bitmap picture,11,y_start_ntsc,gr_phrase,gr_phrase,max_y_gr,bpp,0,NOTRANS RELEASE,0,1
**** which is the expected behaviour to its current form to fix a discrepancy in the compile and linking process.
**** for creating .cof , other offsets required for .rom, and .j64. 
 bitmap $4000+$250,11,y_start_ntsc,gr_phrase,gr_phrase,max_y_gr,bpp,0,NOTRANS RELEASE,0,1 
_stop0_60hz:
 stop
	.68000
obend:
	.objproc
	.org	vars
 branch VC < 23,_stopend
 branch VC > 24,_stopend
**** dummy entry
 bitmap picture,9,y_start_pal+1,gr_phrase,gr_phrase,max_y_gr,bpp,0,NOTRANS RELEASE,0,1
_stopend:
 stop
	.68000
	print /x picture
jag_end:
	BSS

	END
