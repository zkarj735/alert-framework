BIN_LIB=QGPL
LIBLIST=$(BIN_LIB)
SHELL=/QOpenSys/usr/bin/qsh

all: dspalt.cmd fmrdspaltd.sqlrpgle

dspalt.cmd: fmhdspalt.pnlgrp
fmrdspaltd.sqlrpgle: fmddspaltd.dspf

%.sqlrpgle:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QRPGLESRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qrpglesrc/$*.sqlrpgle') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QRPGLESRC.file/$*.mbr') MBROPT(*REPLACE)"
	system "CHGPFM FILE($(BIN_LIB)/QRPGLESRC) MBR($*) SRCTYPE(SQLRPGLE)"
	liblist -a $(LIBLIST);\
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QRPGLESRC) MEMBER($*) COMPTYPE(*COMPILE) SBMJOB(*NO)"

%.cmd:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QCMDSRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qcmdsrc/$*.cmd') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QCMDSRC.file/$*.mbr') MBROPT(*REPLACE)"
	system "CHGPFM FILE($(BIN_LIB)/QCMDSRC) MBR($*) SRCTYPE(CMD)"
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QCMDSRC) MEMBER($*) COMPTYPE(*COMPILE) SBMJOB(*NO)"

%.dspf:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QDDSSRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qddssrc/$*.dspf') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QDDSSRC.file/$*.mbr') MBROPT(*REPLACE)"
	system "CHGPFM FILE($(BIN_LIB)/QDDSSRC) MBR($*) SRCTYPE(DSPF)"
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QDDSSRC) MEMBER($*) COMPTYPE(*COMPILE) SBMJOB(*NO)"

%.pnlgrp:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QPNLSRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qpnlsrc/$*.pnlgrp') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QPNLSRC.file/$*.mbr') MBROPT(*REPLACE)"
	system "CHGPFM FILE($(BIN_LIB)/QPNLSRC) MBR($*) SRCTYPE(PNLGRP)"
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QPNLSRC) MEMBER($*) COMPTYPE(*COMPILE) SBMJOB(*NO)"
