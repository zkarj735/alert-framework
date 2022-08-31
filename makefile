BIN_LIB=QGPL
LIBLIST=$(BIN_LIB)
SHELL=/QOpenSys/usr/bin/qsh

all: dspalt.cmd fmrdspaltd.sqlrpgle

dspalt.cmd: fmhdspaltd.pnlgrp
fmrdspaltd.sqlrpgle: fmddspaltd.dspf

%.sqlrpgle:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QRPGLESRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qrpglesrc/$*.sqlrpgle') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QRPGLESRC.file/$*.mbr') MBROPT(*REPLACE)"
	liblist -a $(LIBLIST);\
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QRPGLESRC) MEMBER($*) COMPTYPE(*COMPILE)"

%.cmd:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QCMDSRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qcmdsrc/$*.cmd') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QCMDSRC.file/$*.mbr') MBROPT(*REPLACE)"
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QDDSSRC) MEMBER($*) COMPTYPE(*COMPILE)"

%.dspf:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QDDSSRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qddssrc/$*.dspf') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QDDSSRC.file/$*.mbr') MBROPT(*REPLACE)"
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QDDSSRC) MEMBER($*) COMPTYPE(*COMPILE)"

%.pnlgrp:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QPNLSRC) RCDLEN(92)"
	system "CPYFRMSTMF FROMSTMF('./qddssrc/$*.pnlgrp') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QPNLSRC.file/$*.mbr') MBROPT(*REPLACE)"
	system -s "FMCMPSRC SOURCE($(BIN_LIB)/QPNLSRC) MEMBER($*) COMPTYPE(*COMPILE)"
