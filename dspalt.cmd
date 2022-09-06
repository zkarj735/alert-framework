/*@ COMP: PGM(FMRDSPALTD) HLPPNLGRP(FMHDSPALT) HLPID(*CMD) */
CMD        PROMPT('Display alert detail')
PARM       KWD(POS) TYPE(*CHAR) LEN(9) DFT(*TODAY) +
             SPCVAL((*TODAY *TODAY) (*SUN *SUN) (*MON +
             *MON) (*TUE *TUE) (*WED *WED) (*THU *THU) +
             (*FRI *FRI) (*SAT *SAT)) MIN(0) +
             ALWUNPRT(*NO) CHOICE('See help text') +
             PROMPT('Position to')                         