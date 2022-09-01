**FREE
//******************************************************************************
// Program      FMRDSPALTD                                                     *
// Author       Allister Jenks                                                 *
// Date         09 Sep 2021                                                    *
// Purpose      Displays the Alert Detail file.                                *
//******************************************************************************
// PROGRAM MODIFICATIONS                                                       *
// 02 Jun 2022  A Jenks                                                        *
// Modify to accept AAAAAAAA or AAAA-AAAA instead of a day, to position to a   *
// specific alert's details. This is the first 8 characters of a hash derived  *
// from the event timestamp, event type, and event item.                       *
// --------------------------------------------------------------------------- *
//******************************************************************************

//@ OPT: *CRTMOD
//@ POST: CRTPGM AJENKS/FMRDSPALTD MODULE(AJENKS/FMRDSPALTD)

ctl-opt debug;

// FILES
// Display file
dcl-f fmddspaltd workstn sfile(LISTSFL:scrRRN) infds(infds) indds(df);

// PROTOTYPES AND INTERFACES
// Main procedure interface
dcl-pi fmrdspaltd;
//  p_range char(6) const;
  p_range char(9) const;
end-pi;

// Prototype for sending an error message
dcl-pr sendMessage extpgm('QMHSNDPM');
  ID char(7) const; // Message ID
  qMsgf char(20) const; // Qualified message file
  data char(512) const; // Message data
  dataLen int(10) const; // Message data length
  type char(10) const; // Message type
  stack char(10) const; // Call stack entry
  stackCount int(10) const; // Call stack counter
  key char(4); // Message key
  errc0100 likeDS(errc0100); // Error block
end-pr;

// Prototype for removing messages
dcl-pr removeMessages extpgm('QMHRMVPM');
  stack char(10);
  stackCount int(10);
  key char(4);
  remove char(10);
  errc0100 likeds(errc0100);
end-pr;


// DEFINITIONS - SPECIALS
// Program Status Data Structure
dcl-ds psds PSDS;
  scr_prog *proc;
end-ds;

// File Information Data Structure
dcl-ds infds qualified;
  aid char(1) pos(369);
end-ds;

// Indicator Data Structure
dcl-ds df qualified;
// Keys
//  exit ind pos(3);
//  refresh ind pos(5);
//  back ind pos(7);
//  forward ind pos(8);
//  cancel ind pos(12);
//  end ind pos(18);
//  pageUp ind pos(25);
//  pageDown ind pos(26);
  // Conditioning
  sflCtl ind pos(27);
  sflEnd ind pos(28);
  altColour ind pos(30);
  dateError ind pos(31);
  timeError ind pos(32);
end-ds;

// DEFINITIONS
// Miscellaneous
dcl-s reqDay char(6); // Day requested (original input parameter)
dcl-s reqHash char(8); // Hash requested (without hyphen)
dcl-s scrRRN packed(3:0); // Subfile RRN for writing
dcl-s sflSize packed(2:0) inz(18); // Must equal subfile page size
dcl-s sflLoad packed(2:0); // Set to sflSize + 1 to detect EOF
dcl-s limitTime timestamp; // File start position for subfile
dcl-s offset int(10); // Offset for page load
dcl-s lastOffset like(offset); // Last offset shown on screen
dcl-s quitLoop ind; // Loop control variable
dcl-s endOfData ind; // Signal that last record is displayed
dcl-s pd like(pst_date); // Copy of position to date field for processing
dcl-s pdn char(6); // Sub-processing of position to date field for day names
dcl-s pt like(pst_time); // Copy of position to time field for processing
dcl-s validDate ind; // Flag a valid date position to operation
dcl-s validTime ind; // Flag a valid time position to operation
dcl-s i int(5); // Loop index
dcl-s firstTs timestamp; // First timestamp shown on screen
dcl-s dayOfWeek int(5); // Number representing day of week for displayed time
dcl-s formattedTimestamp char(26); // Formatted for display
dcl-s longText char(150); // Used for detail display

// sendAlert parameter variables
dcl-ds mh qualified;
  ID char(7) inz('CPF9898');
  qMsgf char(20) inz('QCPFMSG   *LIBL     ');
  data char(80);
  dataLen int(10) inz(%Size(mh.data));
  type char(10) inz('*INFO');
  stack char(10) inz('*');
  stackCount int(10) inz(0);
  key char(4);
  remove char(10) inz('*ALL');
end-ds;

// Constants
dcl-c lower const('abcdefghijklmnopqrstuvwxyz');
dcl-c upper const('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
dcl-c F3 const(x'33');
dcl-c F5 const(x'35');
dcl-c F12 const(x'3C');
dcl-c F18 const(x'B6');
dcl-c Enter const(x'F1');
dcl-c PageUp const(x'F4');
dcl-c PageDown const(x'F5');

// Data structure for SQL result set
dcl-ds rs qualified;
  colour char(1);
  rowid int(20);
  etim char(26);
  evnt char(25);
  item char(100);
  otim char(26);
  text char(3000);
  alerts int(20);
end-ds;

// API Error block
dcl-ds errc0100;
  bytPrv int(10) inz(%Size(errc0100));
  bytAvl int(10);
  msgId char(7);
  *n    char(1);
  msgDta char(128);
end-ds;


// MAINLINE
exec sql
  set option datfmt = *ISO;

sflLoad = sflSize + 1;

// Get the initial starting timestamp
if %subst(p_range: 1: 1) = '*';
  reqDay = %subst(p_range: 1: 6);
  limitTime = getTimestampByDay(reqDay);
else;
  if %subst(p_range: 5: 1) = '-';
    reqHash = %subst(p_range: 1: 4) + %subst(p_range: 6: 4);
  else;
    reqHash = %subst(p_range: 1: 8);
  endif;
  limitTime = getTimestampByHash(reqHash);
endif;

// Get the SQL offset based on that time
exsr findOffset;

// Populate the subfile
exsr loadSub;

// Process subfile until exit requested
dow *inlr = *Off;
  df.sflCtl = *on;
  write LISTKEY;
  write MSGCTL;
  exfmt LISTHDG;
  exsr clearMessages;

  select;
    when infds.aid = F3 or infds.aid = F12;
      *inlr = *on;
      return;
    when infds.aid = F5;
      exsr loadSub;
    when infds.aid = F18;
      exsr gotoEOF;
      exsr loadSub;
    when infds.aid = PageUp;
      offset -= sflSize;
      if offset < 0;
        offset = 0;
      endif;
      exsr loadSub;
    when infds.aid = PageDown;
      if not endOfData;
        offset += sflSize;
      endif;
      exsr loadSub;
    when infds.aid = Enter;
      exsr actionInput;
    other;
      mh.data = 'Function key not allowed';
      exsr showMessage;
  endsl;
enddo;

*inlr = *on;
return;

// -----------------------------------------------------------------------------
begsr findOffset;

exec sql
  with t1 as (
           select row_number() over (
                    order by c.adetim, c.aditem, c.adotim
                  ) as rid, c.*
             from fmpaltdtl c
             order by c.adetim, c.aditem, c.adotim),
       t2 (pos_ts) as (
         select t1.adetim
           from t1
           where t1.adotim >= :limitTime
           order by t1.adetim, t1.aditem, t1.adotim
           limit 1)
    select coalesce(min(rid) - 1, (select max(rid) - 1 from t1)) into :offset
      from t1, t2
      where t1.adetim = pos_ts;

endsr;
// -----------------------------------------------------------------------------
begsr loadSub;

// Clear the subfile
df.sflCtl = *off;
df.sflEnd = *off;
scrRRN = 0;
write LISTHDG;

// Load a page from the file
df.sflEnd = *off;
scrRRN = 0;

exec sql
  declare C1 insensitive cursor for
  with
    t1 as (
      select distinct adetim, aditem
        from fmpaltdtl
        order by adetim, aditem),
    t2 as (
      select adetim, aditem, (
             select count(*) from t1 a where
               concat(char(a.adetim), a.aditem) <
                 concat(char(b.adetim), b.aditem))
             as ctr
        from t1 b),
    t3 as (
     select
       case when mod(t2.ctr, 2) = 0 then '0' else '1' end as colour,
       row_number() over (order by c.adetim, c.aditem, c.adotim ) as rid, c.*
       from fmpaltdtl c left join t2
            on c.adetim = t2.adetim and c.aditem = t2.aditem
       order by c.adetim, c.aditem, c.adotim)
  select t3.*,
     (select count(*) from fmpaltlog l
      where l.altime = t3.adetim and l.alitem = t3.aditem and
            l.alalrt <> 'IGNORE')
      as alerts
    from t3 limit :sflLoad offset :offset;

exec sql
  open C1;

exec sql
  fetch next from C1 into :rs;

quitLoop = *off;
endOfData = *off;
if sqlcod > 0;
  // The positioning should never go beyond the available but just in case
  df.sflEnd = *on;
  quitLoop = *on;
  endOfData = *on;
endif;

dow not quitLoop;
  if scrRRN = 0;
    firstTS = %timestamp(rs.otim);
  endif;
  k_colour = rs.colour;
  if rs.colour = '0';
    df.altColour = *off;
  else;
    df.altColour = *on;
  endif;
  s_opt = *blank;
  k_adetim = rs.etim;
  k_adevnt = rs.evnt;
  k_aditem = rs.item;
  k_adtext = rs.text;
  s_adtext = *blanks;
  if %len(%trim(rs.text)) <= 91;
    s_adtext = %subst(rs.text: 1: 91);
  else;
    s_adtext = %subst(rs.text: 1: 87) + ' ...';
  endif;
  dayOfWeek = %rem(%diff(%date(%timestamp(rs.otim)): D'1900-01-01': *days): 7);
  s_dow = %subst('MonTueWedThuFriSatSun': 1 + dayOfWeek * 3: 3);
  formattedTimestamp = %scanrpl('-': '/': rs.otim);
  formattedTimestamp = %scanrpl('.': ':': formattedTimestamp);
  %subst(formattedTimestamp: 11: 1) = ' ';
  %subst(formattedTimestamp: 20: 1) = '.';
  s_adotim = formattedTimestamp;
  if rs.alerts > 0;
    s_flag = '*';
  else;
    s_flag = *blank;
  endif;
  scrRRN += 1;
  write(e) LISTSFL;
  if %eof(fmddspaltd); // End of subfile reached
    quitLoop = *on;
  endif;

  exec sql
    fetch next from C1 into :rs;
  if sqlcod > 0; // End of data reached
    df.sflEnd = *on;
    endOfData = *on;
    quitLoop = *on;
  endif;
enddo;
lastOffset = rs.rowid - 1;

exec sql
  close C1;

endsr;
// -----------------------------------------------------------------------------
begsr actionInput;
// Check the position to fields first
  validDate = *on;
  if pst_date <> *blanks; // Sort out date position first
    validDate = *off;
    pd = %trim(%xlate(lower: upper: pst_date));
    if %subst(pd: 1: 1) = '*';
      pdn = %subst(pd: 1: 4);
    else;
      pdn = '*' + %subst(pd: 1: 3);
    endif;
    select;
      // First check for day names
      when pd = '*TODAY' or pd = 'TODAY';
        limitTime = getTimestampByDay('*TODAY');
        validDate = *on;
      when pdn = '*MON' or pdn = '*TUE' or pdn = '*WED' or pdn = '*THU'
        or pdn = '*FRI' or pdn = '*SAT' or pdn = '*SUN';
        limitTime = getTimestampByDay(pdn);
        validDate = *on;

      other; // Some kind of date
        for i = 1 to %len(%trim(pd)); // convert non-digit to ~
          if %check('0123456789': %subst(pd: i: 1)) > 0;
            %subst(pd: i: 1) = '~';
          endif;
        endfor;
        pd = %scanrpl('~': '': pd); // strip all ~
        if %len(%trim(pd)) = 5 or %len(%trim(pd)) = 7; // leading zero needed
          pd = '0' + %trim(pd);
        endif;
        if %len(%trim(pd)) = 6; // Missing century
          pd = '20' + %trim(pd);
        endif;
        pd = %subst(pd: 1: 4) + '-' + %subst(pd: 5: 2) + '-' + %subst(pd: 7: 2); // Add separators
        test(de) pd;
        if not %error;
          limitTime = %timestamp(%date(pd));
          validDate = *on;
        endif;
    endsl;
  endif;
  validTime = *on;
  if pst_time <> *blanks; // Sort out time position
    validTime = *off;
    pt = pst_time;
    for i = 1 to %len(%trim(pt)); // convert non-digit to ~
      if %check('0123456789': %subst(pt: i: 1)) > 0;
        %subst(pt: i: 1) = '~';
      endif;
    endfor;
    pt = %scanrpl('~': '': pt); // strip all ~
    if %rem(%len(%trim(pt)): 2) = 1; // odd length needs a leading zero
      pt = '0' + %trim(pt);
    endif;
    select;
      when %len(%trim(pt)) = 2; // HH
        pt = %subst(pt: 1: 2) + '.00.00';
      when %len(%trim(pt)) = 4; // HHMM
        pt = %subst(pt: 1: 2) + '.' + %subst(pt: 3: 2) + '.00';
      when %len(%trim(pt)) = 6; // HHMMSS
        pt = %subst(pt: 1: 2) + '.' + %subst(pt: 3: 2) + '.' + %subst(pt: 5: 2); // Add separators
    endsl;
    test(et) pt;
    if not %error; // we have a valid time
      if not validDate; // but no valid date so we need to invent one
        limitTime = %date(firstTS) + %time(pt);
      else;
        limitTime = %date(limitTime) + %time(pt);
      endif;
      validTime = *on;
    endif;
  endif;

  df.dateError = not validDate;
  df.timeError = not validTime;
  if validDate and validTime and (pst_date <> *blanks or pst_time <> *blanks);
    mh.data = 'List positioned to ' + %char(limitTime);
    exsr showMessage;
    pst_date = *blanks;
    pst_time = *blanks;
    exsr findOffset;
    exsr loadSub;

  else; // process options if we didn't reposition
    readc(e) LISTSFL;
    dow not %eof(fmddspaltd);
      select;
        when s_opt = '5';
          displayLongText(K_ADTEXT: S_ADOTIM);
        when s_opt = '6';
          longText = 'Event: ' + %trim(K_ADEVNT) + ', Item: ' + %trim(K_ADITEM);
          displayLongText(longText: S_ADOTIM);
      endsl;
      s_opt = *blank;
      if k_colour = '0';
        df.altColour = *off;
      else;
        df.altColour = *on;
      endif;

      update LISTSFL;
      readc(e) LISTSFL;
    enddo;
  endif;

endsr;

// -----------------------------------------------------------------------------

begsr gotoEOF;
  exec sql
  with t1 as (
           select row_number() over (
                    order by c.adetim, c.aditem, c.adotim
                  ) as rid, c.*
             from fmpaltdtl c
             order by c.adetim, c.aditem, c.adotim),
       t2 (pos_ts) as (
         select t1.adetim
           from t1
           where t1.adotim >= :limitTime
           order by t1.adetim, t1.aditem, t1.adotim
           limit 1)
    select max(rid) - 1 into :offset
      from t1, t2
      where t1.adetim = pos_ts;
  offset -= sflSize - 1;

endsr;

// -----------------------------------------------------------------------------

begsr clearMessages;
  mh.key = *blanks;
  removeMessages(mh.stack: mh.stackCount: mh.key: mh.remove: errc0100);
endsr;

begsr showMessage;
  sendMessage(mh.ID: mh.qMsgf: mh.data: mh.dataLen:
              mh.type: mh.stack: mh.stackCount: mh.key: errc0100);
endsr;

// ================================================================================
dcl-proc getTimestampByDay;

dcl-pi *n timestamp;
  theDay char(6) const;
end-pi;

dcl-s theTime timestamp;
dcl-s today int(5);
dcl-s required int(5);
dcl-s datediff int(5);

select;
  when theDay = '*TODAY';
    theTime = %timestamp(%date);
  other;
    today = %rem(%diff(%date(): D'1900-01-01': *days): 7);
    required = %div(%scan(%trim(theDay): '*MON*TUE*WED*THU*FRI*SAT*SUN') - 1: 4);
    datediff = %rem(7 + today - required: 7);
    if datediff = 0;
      datediff = 7;
    endif;
    theTime = %timestamp(%date) - %days(datediff);
endsl;

return theTime;
end-proc;
// ================================================================================
dcl-proc getTimestampByHash;

dcl-pi *n timestamp;
  theHash char(8) const;
end-pi;

dcl-s theTime timestamp;

// Find the timestamp based on the hash
exec sql
  select min(adetim) into :theTime
    from fmpaltdtl d
   where left(hex(hash(to_char(adetim) || adevnt || aditem)),8)
    = upper(:theHash);

return theTime;
end-proc;
// ================================================================================
dcl-proc displayLongText;
// Procedure interface
dcl-pi *n;
  text varchar(3000: 2) const;
  title varchar(70: 2) const;
end-pi;

// Execute command
dcl-pr pcmd extpgm('QCAPCMD');
  *n char(512);
  *n int(10);
  *n likeds(qca_optblk);
  *n int(10);
  *n char(8);
  *n char(8);
  *n int(10);
  *n int(10);
  *n likeds(errc0100);
end-pr;

// Display long text
dcl-pr showText extpgm('QUILNGTX');
  *n char(3000) const;
  *n int(10) const;
  *n char(7) const;
  *n char(20) const;
  *n likeds(errc0100);
end-pr;

// QCAPCMD parameters
dcl-s qca_cmd char(512);
dcl-s qca_cmdlen int(10) Inz(%Size(qca_cmd));
dcl-ds qca_optblk qualified;
  tocp int(10) Inz(0);
  dbcs char(1) Inz('0');
  pmpt char(1) Inz('0');
  synt char(1) Inz('0');
  msgk int(10) Inz(0);
  rsvd char(9) Inz(X'000000000000000000');
end-ds;
dcl-s qca_optlen int(10) Inz(20);
dcl-s qca_optfmt char(8) Inz('CPOP0100');
dcl-s qca_rtncmd char(8);
dcl-s qca_rtnavl int(10) Inz(0);
dcl-s qca_rtnlen int(10) Inz(0);
dcl-ds qca_err likeds(errc0100);

// API error parameter
dcl-ds errc0100 qualified;
  bytprv int(10) inz( %size( errc0100 ));
  bytavl int(10);
  msgid char(7);
  *N char(1);
  msgdta char(128);
end-ds;

qca_cmd = 'crtmsgf qtemp/tempmsgf';
pcmd(qca_cmd: qca_cmdlen: qca_optblk: qca_optlen: qca_optfmt: qca_rtncmd:
          qca_rtnavl: qca_rtnlen: qca_err);
qca_cmd = 'addmsgd HDR0001 qtemp/tempmsgf msg(''' + %trim(title) + ''')';
pcmd(qca_cmd: qca_cmdlen: qca_optblk: qca_optlen: qca_optfmt: qca_rtncmd:
          qca_rtnavl: qca_rtnlen: qca_err);

showText(%trim(text): 3000: 'HDR0001': 'TEMPMSGF  QTEMP     ': errc0100);

qca_cmd = 'dltmsgf qtemp/tempmsgf';
pcmd(qca_cmd: qca_cmdlen: qca_optblk: qca_optlen: qca_optfmt: qca_rtncmd:
          qca_rtnavl: qca_rtnlen: qca_err);

end-proc;
