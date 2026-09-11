create or replace package body Expo is
  --------------------------------------------------------------------------------
  bLockedExpoProcessing     boolean := false;
  bServiceDocsLoaded        boolean := false;
  bSkipLimit4Types          boolean := false;
  bSkipChkGroupLimits       boolean := false;
  --
  nINI_CashOrderNo_CntMode  pls_integer;
  --
  cSkipActPass              varchar2( 1 ) := '~';

  --------------------------------------------------------------------------------
  type recDocMemoOrderParams is record(
    DocType      pls_integer,
    ID_Move      pls_integer,
    ID_Move_Old  pls_integer,
    UniqCode     pls_integer,
    SchDate      pls_integer,
    SchDoc       pls_integer,
    Deals        pls_integer,
    Opers        pls_integer,
    Oper_Type    pls_integer,
    Oper_ExpoDt  pls_integer,
    Oper_AmnDt   pls_integer,
    Oper_AmnKt   pls_integer,
    Oper_ExpoKt  pls_integer,
    Oper_Valior  pls_integer,
    Oper_SysAmn  pls_integer,
    Oper_RowNum  pls_integer,
    OrdText      pls_integer,
    SysText      pls_integer,
    ChOper       pls_integer,
    Origin       pls_integer,
    DateTime     pls_integer,
    ID_Cust      pls_integer,
    Referencia   pls_integer,
    FolderMode   pls_integer
  );

  rDocMemoOrderParams       recDocMemoOrderParams;

  type rCredExpo is record(
    nIdExpo  integer,
    dValior  date
  );

  type taCredExpo is table of rCredExpo
    index by binary_integer;

  type rCashRows is record(
    nIDCash  integer,
    sInOut   varchar2( 1 ),
    sCodVal  varchar2( 3 ),
    nAmount  number
  );

  type taCashRows is table of rCashRows
    index by binary_integer;

  ----------------------------------------------------------------
  type EmpCurTyp is ref cursor;

  dCurrenReqStartStamp      integer;
  --------------------------------------------------------------------------------
  bZBalancePpv              boolean;
  bHaveFS_BK                boolean;
  bHaveBalances             boolean;
  bCommonSchBal             boolean;
  bSkipImportOborot         boolean;
  nModeAcc                  integer;
  nMaxDaySumC               number;
  nMaxDaySumF               number;
  dNar43Start               date;

  --------------------------------------------------------------------------------
  function GetMaxDaySum( sCliType in varchar2 )
    return number is
  begin
    if ( nMaxDaySumC is null ) then
      nMaxDaySumC  := Schema_GPSys.OraGPSys.My_to_number( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'MAXDAYSUM_C', '0' ) );
    end if;

    if ( nMaxDaySumF is null ) then
      nMaxDaySumF  := Schema_GPSys.OraGPSys.My_to_number( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'MAXDAYSUM_F', '0' ) );
    end if;

    return case
             when sCliType = 'C' then nMaxDaySumC
             when sCliType = 'F' then nMaxDaySumF
             else 0
           end;
  end GetMaxDaySum;

  --------------------------------------------------------------------------------
  function GetNar43StartDate
    return date is
  begin
    if ( dNar43Start is null ) then
      dNar43Start  := to_date( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'NAR43STARTDATE', '01.01.3000' ), 'dd.mm.yyyy' );
    end if;

    return dNar43Start;
  end GetNar43StartDate;

  --------------------------------------------------------------------------------
  function SkipImportOborot
    return boolean is
  begin
    if ( bSkipImportOborot is null ) then
      bSkipImportOborot      := nvl( Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValue( Schema_GPSys.OraGPSys.defUniqCode_All,
                                                                                                           'Счетоводство',
                                                                                                           'SKIP_IMPORTOBOROT',
                                                                                                           null
                                                                                                          )
                                                                       ),
                                     Schema_GPSys.OraSys.VerBankTokuda or
                                     Schema_GPSys.OraSys.VerBankDBank
                                    );
    end if;

    return bSkipImportOborot;
  end SkipImportOborot;

  --------------------------------------------------------------------------------
  function sSkipImportOborot
    return varchar2 is
    sRet  varchar2( 1 );
  begin
    if ( SkipImportOborot ) then
      sRet  := 'T';
    else
      sRet  := 'F';
    end if;

    return sRet;
  end sSkipImportOborot;

  --------------------------------------------------------------------------------
  function IsCommonSchBal
    return boolean is
  begin
    if ( bCommonSchBal is null ) then
      bCommonSchBal      := nvl( Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'COMMON_SCH_BAL', null ) ),
                                 false
                                );
    end if;

    return bCommonSchBal;
  end IsCommonSchBal;

  --------------------------------------------------------------------------------
  function IsSystemHaveBalances
    return boolean is
  begin
    if ( bHaveBalances is null ) then
      bHaveBalances  := nvl( Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValue( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'CHK_UNIQCODE', null ) ), true );
    end if;

    return bHaveBalances;
  end IsSystemHaveBalances;

  --------------------------------------------------------------------------------
  function GetZBalancePpv( nUniqCode integer )
    return boolean is
  begin
    if ( bZBalancePpv is null ) then
      bZBalancePpv  := Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'ЗадБалN4', 'T' ) );
    end if;

    return bZBalancePpv;
  end GetZBalancePpv;

  --------------------------------------------------------------------------------
  function SetZBalancePpv(
    nUniqCode   integer,
    bNewState   boolean
  )
    return boolean is
    bOldState  boolean;
  begin
    bOldState     := GetZBalancePpv( nUniqCode );
    bZBalancePpv  := bNewState;
    return bOldState;
  end SetZBalancePpv;

  --------------------------------------------------------------------------------
  procedure InitSkipLimit is
  begin
    if ( not aSkipLimit.count > 0 ) then
      aSkipLimit( ModeSkip_CredPadej )       := false;
      aSkipLimit( ModeSkip_CredLihvi )       := false;
      aSkipLimit( ModeSkip_Payment )         := false;
      aSkipLimit( ModeSkip_Limit )           := false;
      aSkipLimit( ModeSkip_CashZapor )       := false;
      aSkipLimit( ModeSkip_Cover )           := false;
      aSkipLimit( ModeSkip_DueAmn )          := false;
      aSkipLimit( ModeSkip_CardAuth )        := false;
      aSkipLimit( ModeSkip_DealOper )        := false;
      aSkipLimit( ModeSkip_CardMNO )         := false;
      aSkipLimit( ModeSkip_DealOrder )       := false;
      aSkipLimit( ModeSkip_CardMPV )         := false;
      aSkipLimit( ModeSkip_CommunalPay )     := false;
      aSkipLimit( ModeSkip_CardHOLD )        := false;
      aSkipLimit( ModeSkip_Sudeben )         := false;
      aSkipLimit( ModeSkip_CustInConfig )    := false;
      aSkipLimit( ModeSkip_ForApproval )     := false;
      aSkipLimit( ModeSkip_SudebenExtrnl )   := false;
      --
      aSkipLimit( ModeSkip_ChkLastUseDate )  := false;
      aSkipLimit( ModeSkip_LockLoan )        := false;
    end if;
  end InitSkipLimit;

  --------------------------------------------------------------------------------
  function GetSkipLimit( ModeSkip integer )
    return boolean is
  begin
    InitSkipLimit;
    return aSkipLimit( ModeSkip );
  end GetSkipLimit;

  --------------------------------------------------------------------------------
  function SetSkipLimit4Types( bNewState boolean )
    return boolean is
    bOldState  boolean;
  begin
    bOldState         := bSkipLimit4Types;
    bSkipLimit4Types  := bNewState;
    return bOldState;
  end SetSkipLimit4Types;

  --------------------------------------------------------------------------------
  function SkipChkGroupLimits( bNewState boolean )
    return boolean is
    bOldState  boolean;
  begin
    bOldState            := bSkipChkGroupLimits;
    bSkipChkGroupLimits  := bNewState;
    return bOldState;
  end SkipChkGroupLimits;

  --------------------------------------------------------------------------------
  function SetSkipLimit(
    ModeSkip    integer,
    bNewState   boolean
  )
    return boolean is
    bOldState  boolean;
  begin
    InitSkipLimit;
    bOldState               := aSkipLimit( ModeSkip );
    aSkipLimit( ModeSkip )  := bNewState;
    return bOldState;
  end SetSkipLimit;

  --------------------------------------------------------------------------------
  procedure SetAllSkipLimit( bNewState boolean ) is
  begin
    InitSkipLimit;
    aSkipLimit( ModeSkip_CredPadej )     := bNewState;
    aSkipLimit( ModeSkip_CredLihvi )     := bNewState;
    aSkipLimit( ModeSkip_Payment )       := bNewState;
    aSkipLimit( ModeSkip_Limit )         := bNewState;
    aSkipLimit( ModeSkip_CashZapor )     := bNewState;
    aSkipLimit( ModeSkip_Cover )         := bNewState;
    aSkipLimit( ModeSkip_DueAmn )        := bNewState;
    aSkipLimit( ModeSkip_CardAuth )      := bNewState;
    aSkipLimit( ModeSkip_DealOper )      := bNewState;
    aSkipLimit( ModeSkip_CardMNO )       := bNewState;
    aSkipLimit( ModeSkip_DealOrder )     := bNewState;
    aSkipLimit( ModeSkip_CardMPV )       := bNewState;
    aSkipLimit( ModeSkip_CommunalPay )   := bNewState;
    aSkipLimit( ModeSkip_CardHOLD )      := bNewState;
    aSkipLimit( ModeSkip_CustInConfig )  := bNewState;
    aSkipLimit( ModeSkip_ForApproval )   := bNewState;
  end SetAllSkipLimit;

  --------------------------------------------------------------------------------
  function SkipTheLimit(
    sTypeLimit  in EXPO_LIMITS.TYPE_LIMIT%type,
    nTypeExpo   in integer
  )
    return boolean is
    ii     integer;
    bSkip  boolean := false;
  begin
    if ( ( sTypeLimit = ExpoLimit_CredPadej and
          GetSkipLimit( ModeSkip_CredPadej ) ) or
        ( sTypeLimit = ExpoLimit_CredLihvi and
         GetSkipLimit( ModeSkip_CredLihvi ) ) or
        ( sTypeLimit = ExpoLimit_Payment and
         GetSkipLimit( ModeSkip_Payment ) ) or
        ( sTypeLimit = ExpoLimit_Limit and
         GetSkipLimit( ModeSkip_Limit ) ) or
        ( sTypeLimit = ExpoLimit_CashZapor and
         GetSkipLimit( ModeSkip_CashZapor ) ) or
        ( sTypeLimit = ExpoLimit_Cover and
         GetSkipLimit( ModeSkip_Cover ) ) or
        ( sTypeLimit = ExpoLimit_DueAmn and
         GetSkipLimit( ModeSkip_DueAmn ) ) or
        ( sTypeLimit = ExpoLimit_CardAuth and
         GetSkipLimit( ModeSkip_CardAuth ) ) or
        ( sTypeLimit = ExpoLimit_DealOper and
         GetSkipLimit( ModeSkip_DealOper ) ) or
        ( sTypeLimit = ExpoLimit_CardMNO and
         GetSkipLimit( ModeSkip_CardMNO ) ) or
        ( sTypeLimit = ExpoLimit_DealOrder and
         GetSkipLimit( ModeSkip_DealOrder ) ) or
        ( sTypeLimit = ExpoLimit_CardMPV and
         GetSkipLimit( ModeSkip_CardMPV ) ) or
        ( sTypeLimit = ExpoLimit_CommunalPay and
         GetSkipLimit( ModeSkip_CommunalPay ) ) or
        ( sTypeLimit = ExpoLimit_CardHOLD and
         GetSkipLimit( ModeSkip_CardHOLD ) ) or
        ( sTypeLimit in (ExpoLimit_SudebenZapor, /*ExpoLimit_SudebenPrc,*/
                                                ExpoLimit_SudebenIntrnl) and
         GetSkipLimit( ModeSkip_Sudeben ) ) or
        ( sTypeLimit = ExpoLimit_ForApproval and
         GetSkipLimit( ModeSkip_ForApproval ) ) or
        ( sTypeLimit = ExpoLimit_SudebenExtrnl and
         GetSkipLimit( ModeSkip_SudebenExtrnl ) ) ) then
      bSkip  := true;
    end if;

    if ( bSkip and
        bSkipLimit4Types and
        sTypeLimit = ExpoLimit_Limit and
        nvl( nTypeExpo, 0 ) > 0 ) then
      select count( 1 )
        into ii
        from Schema_GPSys.CONFSYSTEM_INT g
       where g.FLDSECTION = 'EXPOSITION' and
             g.FLDITEM = 'NOTSKIP_EXPOLIMIT_TYPES' and
             g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
             g.FLDVALUE like '%&' || to_char( nTypeExpo ) || '&%';

      bSkip  := ii = 0;
    end if;

    return bSkip;
  end SkipTheLimit;

  --------------------------------------------------------------------------------
  function SetSkipActPass( cNewState varchar2 )
    return varchar2 is
    cOldState  varchar( 1 );
  begin
    cOldState     := cSkipActPass;
    cSkipActPass  := cNewState;
    return cOldState;
  end SetSkipActPass;

  --------------------------------------------------------------------------------
  function SkipTheLimitActPass( cActPass varchar2 )
    return boolean is
  begin
    return nvl( cSkipActPass, '~' ) = cActPass;
  end SkipTheLimitActPass;

  --------------------------------------------------------------------------------
  function GetExpoNumber( Object_Name in varchar2 )
    return integer is
    pragma autonomous_transaction;
    i  integer;
  begin
       update EXPO_NUMBERS
          set NUM  = NUM + 1
        where OBJ_NAME = Object_Name
    returning NUM
         into i;

    if ( sql%rowcount = 0 ) then
      i  := 1;

      begin
        insert into EXPO_NUMBERS(
                      OBJ_NAME,
                      NUM
                    )
             values ( Object_Name,
                      i
                     );
      exception
        when dup_val_on_index then
             update EXPO_NUMBERS
                set NUM  = NUM + 1
              where OBJ_NAME = Object_Name
          returning NUM
               into i;
      end;
    end if;

    commit;
    return i;
  end GetExpoNumber;

  --------------------------------------------------------------------------------
  function GetExpoNumberW( Object_Name in varchar2 )
    return integer is
    i                  integer;
    deadlock_detected  exception;
    aParams            Schema_RA.GPC_RA.tblErrParams;
    pragma exception_init( deadlock_detected, -60 );
  begin
    begin
         update EXPO_NUMBERS
            set NUM  = NUM + 1
          where OBJ_NAME = Object_Name
      returning NUM
           into i;

      if ( sql%rowcount = 0 ) then
        i  := 1;

        begin
          insert into EXPO_NUMBERS(
                        OBJ_NAME,
                        NUM
                      )
               values ( Object_Name,
                        i
                       );
        exception
          when dup_val_on_index then
               update EXPO_NUMBERS
                  set NUM  = NUM + 1
                where OBJ_NAME = Object_Name
            returning NUM
                 into i;
        end;
      end if;
    exception
      when deadlock_detected then
        i                      := null;
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'OBJ_NAME';
        aParams( 1 ).ML_VALUE  := Object_Name;
        Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се получи нов номер за $OBJ_NAME$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
    end;

    return i;
  end GetExpoNumberW;

  --------------------------------------------------------------------------------
  procedure SetMaxExpoNumber(
    Object_Name  in varchar2,
    nCounter     in integer,
    bEnter       in boolean default false
  ) is
  begin
    if ( bEnter or
        Schema_GPSys.OraGPSys.OracleBoolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'QUEUES_PROCESSING', 'SetMaxNums', 'T' ) ) ) then
      update EXPO_NUMBERS
         set NUM  = greatest( nCounter, NUM )
       where OBJ_NAME = Object_Name;

      if ( sql%rowcount = 0 ) then
        insert into EXPO_NUMBERS(
                      OBJ_NAME,
                      NUM
                    )
             values ( Object_Name,
                      nCounter
                     );
      end if;
    end if;
  end SetMaxExpoNumber;

  --------------------------------------------------------------------------------
  function SchDocCntName(
    nUC    in integer,
    dDate  in date
  )
    return varchar2 is
    sKey  varchar2( 64 );
  begin
    sKey  := 'SchDoc';

    if ( IsSystemHaveBalances ) then
      sKey  := sKey || to_char( nUC, 'FM0999999999' );
    end if;

    sKey  := sKey || to_char( dDate, 'yyyymmdd' );
    return sKey;
  end SchDocCntName;

  --------------------------------------------------------------------------------
  function CashDocCntName(
    sOper    in varchar2,
    nIdExpo  in integer,
    dDate    in date
  )
    return varchar2 is
    sKey  varchar2( 64 ) := 'CASHORDER_';
  begin
    if ( nINI_CashOrderNo_CntMode is null ) then
      nINI_CashOrderNo_CntMode  := to_number( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'CashOrderNo_CounterMode', '0' ) );
    end if;

    case nINI_CashOrderNo_CntMode
      when 0 then
        sKey  := sKey || sOper;
      when 1 then
        sKey  := sKey || to_char( dDate, 'yyyymmdd' );
    end case;

    return sKey || to_char( nIdExpo );
  end CashDocCntName;

  --------------------------------------------------------------------------------
  procedure GetDocsConfiguration is
  begin
    select /*+ use_nl( a b c d e f g h i j k l m n o p q r s t u v w  )
               index ( a EXPO_SERVICEDOC_1 )
               index ( b EXPO_SERVICEDOC_1 )
               index ( c EXPO_SERVICEDOC_1 )
               index ( d EXPO_SERVICEDOC_1 )
               index ( e EXPO_SERVICEDOC_1 )
               index ( f EXPO_SERVICEDOC_1 )
               index ( g EXPO_SERVICEDOC_1 )
               index ( h EXPO_SERVICEDOC_1 )
               index ( i EXPO_SERVICEDOC_1 )
               index ( j EXPO_SERVICEDOC_1 )
               index ( k EXPO_SERVICEDOC_1 )
               index ( l EXPO_SERVICEDOC_1 )
               index ( m EXPO_SERVICEDOC_1 )
               index ( n EXPO_SERVICEDOC_1 )
               index ( o EXPO_SERVICEDOC_1 )
               index ( p EXPO_SERVICEDOC_1 )
               index ( q EXPO_SERVICEDOC_1 )
               index ( r EXPO_SERVICEDOC_1 )
               index ( s EXPO_SERVICEDOC_1 )
               index ( t EXPO_SERVICEDOC_1 )
               index ( u EXPO_SERVICEDOC_1 )
               index ( v EXPO_SERVICEDOC_1 )
               index ( w EXPO_SERVICEDOC_1 ) */
          a.doc_type,
           a.field_type,
           b.field_type,
           c.field_type,
           d.field_type,
           e.field_type,
           f.field_type,
           g.field_type,
           h.field_type,
           i.field_type,
           j.field_type,
           k.field_type,
           l.field_type,
           m.field_type,
           n.field_type,
           o.field_type,
           p.field_type,
           q.field_type,
           r.field_type,
           s.field_type,
           t.field_type,
           u.field_type,
           v.field_type,
           w.field_type
      into rDocMemoOrderParams.DocType,
           rDocMemoOrderParams.ID_Move,
           rDocMemoOrderParams.ID_Move_Old,
           rDocMemoOrderParams.UniqCode,
           rDocMemoOrderParams.SchDate,
           rDocMemoOrderParams.SchDoc,
           rDocMemoOrderParams.Deals,
           rDocMemoOrderParams.Opers,
           rDocMemoOrderParams.Oper_Type,
           rDocMemoOrderParams.Oper_ExpoDt,
           rDocMemoOrderParams.Oper_AmnDt,
           rDocMemoOrderParams.Oper_AmnKt,
           rDocMemoOrderParams.Oper_ExpoKt,
           rDocMemoOrderParams.Oper_Valior,
           rDocMemoOrderParams.Oper_SysAmn,
           rDocMemoOrderParams.Oper_RowNum,
           rDocMemoOrderParams.OrdText,
           rDocMemoOrderParams.SysText,
           rDocMemoOrderParams.ChOper,
           rDocMemoOrderParams.Origin,
           rDocMemoOrderParams.DateTime,
           rDocMemoOrderParams.ID_Cust,
           rDocMemoOrderParams.Referencia,
           rDocMemoOrderParams.FolderMode
      from EXPO_SERVICEDOC a,
           EXPO_SERVICEDOC b,
           EXPO_SERVICEDOC c,
           EXPO_SERVICEDOC d,
           EXPO_SERVICEDOC e,
           EXPO_SERVICEDOC f,
           EXPO_SERVICEDOC g,
           EXPO_SERVICEDOC h,
           EXPO_SERVICEDOC i,
           EXPO_SERVICEDOC j,
           EXPO_SERVICEDOC k,
           EXPO_SERVICEDOC l,
           EXPO_SERVICEDOC m,
           EXPO_SERVICEDOC n,
           EXPO_SERVICEDOC o,
           EXPO_SERVICEDOC p,
           EXPO_SERVICEDOC q,
           EXPO_SERVICEDOC r,
           EXPO_SERVICEDOC s,
           EXPO_SERVICEDOC t,
           EXPO_SERVICEDOC u,
           EXPO_SERVICEDOC v,
           EXPO_SERVICEDOC w
     where a.matter_id = 'MemoOrder' and
           b.matter_id = 'MemoOrder_ID_Move_Old' and
           c.matter_id = 'MemoOrder_UniqCode' and
           d.matter_id = 'MemoOrder_SchDate' and
           e.matter_id = 'MemoOrder_SchDoc' and
           f.matter_id = 'MemoOrder_Deals' and
           g.matter_id = 'MemoOrder_Opers' and
           h.matter_id = 'MemoOrder_Oper_Type' and
           i.matter_id = 'MemoOrder_Oper_ExpoDt' and
           j.matter_id = 'MemoOrder_Oper_AmnDt' and
           k.matter_id = 'MemoOrder_Oper_AmnKt' and
           l.matter_id = 'MemoOrder_Oper_ExpoKt' and
           m.matter_id = 'MemoOrder_Oper_Valior' and
           n.matter_id = 'MemoOrder_Oper_SysAmn' and
           o.matter_id = 'MemoOrder_Oper_RowNum' and
           p.matter_id = 'MemoOrder_OrdText' and
           q.matter_id = 'MemoOrder_SysText' and
           r.matter_id = 'MemoOrder_ChOper' and
           s.matter_id = 'MemoOrder_Origin' and
           t.matter_id = 'MemoOrder_DateTime' and
           u.matter_id = 'MemoOrder_ID_Cust' and
           v.matter_id = 'MemoOrder_Referencia' and
           w.matter_id = 'MemoOrder_FolderMode';
  end GetDocsConfiguration;

  --------------------------------------------------------------------------------
  procedure ForceWWWUpdate( nIDExpo in integer ) is
    ii  integer;
  begin
    select c.ID_EXPO
      into ii
      from Schema_GPSys.WWWCONF c,
           LOAN_EXPOSITION b,
           LOAN_EXPOSITION a
     where a.ID_EXPO = nIDExpo and
           a.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg and
           b.ID_CRED_ENGAGE = a.ID_CRED_ENGAGE and
           b.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_Obsujvashta and
           c.ID_EXPO = b.ID_EXPO and
           c.ACTIVE = 'T';

    SetMaxTriggNumber( 'ID_LASTLIMIT', ii );
  exception
    when others then
      null;
  end ForceWWWUpdate;

  --------------------------------------------------------------------------------
  procedure ExpoProcessing(
    nIQRecCount  in integer,
    bDelJunks    in boolean default false,
    nGateNo      in integer default -1
  ) is
    iqRec              Schema_GPSys.OUT_QUEUE_TEMPLATE%rowtype;
    aListFr            Schema_GPSys.OraGPSys.aStrings;
    aListTo            Schema_GPSys.OraGPSys.aStrings;
    aIDs               Schema_GPSys.OraGPSys.aNumbers;
    oDoc               Schema_GPSys.RecDocSysType;
    oDocIQ             Schema_GPSys.DocSysIQType;
    oDealList          Schema_GPSys.DocSysList;
    oDeal              Schema_GPSys.RecDocSysType;
    oOperList          Schema_GPSys.DocSysList;
    oOper              Schema_GPSys.RecDocSysType;
    cReferDt           EXPO_MOVES.REFERENCIA%type;
    cReferKt           EXPO_MOVES.REFERENCIA%type;
    RecExpoMove        EXPO_MOVES%rowtype;
    RecMoveText        EXPO_MOVE_TEXT%rowtype;
    RecBaseIntr        EXPO_BASE_INTR%rowtype;
    rGroupMoves        EXPO_GROUPMOVES%rowtype;
    rExpoLimit         EXPO_LIMITS%rowtype;
    rExpoZapor         EXPO_LIMITS%rowtype;
    rExpoLimObor       EXPO_LIM_OBOR%rowtype;
    rExpoAddIntrate    EXPO_ADDINTRATE%rowtype;
    handle             varchar2( 128 );
    ii                 integer;
    nExpoLimOborDoc    integer;
    IDExpo             integer;
    IDOldMove          integer;
    nCount             integer;
    nGroupLimitsID     integer;
    nDummy             integer;
    nIDExpoKt          integer;
    bDummy             boolean;
    bAll               boolean := false;
    dStart             date;
    dValiorPeriod      date;
    nStartSeq          number;
    nAmountKt          number;

    cursor iqqVP(
      qMove    in integer,
      qRowNum  in integer
    ) is
      ( select VALIOR_PERIOD
          from EXPO_MOVES
         where ID_MOVE = qMove and
               ORDROWNUM = qRowNum );

    deadlock_detected  exception;
    pragma exception_init( deadlock_detected, -60 );
  begin
    if ( not bLockedExpoProcessing ) then
      dbms_lock.allocate_unique( 'Schema_Expo.ExpoProcessing' || to_char( nGateNo ), handle );
      bLockedExpoProcessing  := dbms_lock.request( handle, dbms_lock.x_mode, 0, false ) = 0;

      if ( bLockedExpoProcessing ) then
        Schema_RA.GPC_Services.aProcessingHandles( Schema_RA.GPC_Services.aProcessingHandles.count + 1 )  := handle;
      end if;
    end if;

    if ( bLockedExpoProcessing ) then
      if ( nvl( nIQRecCount, 0 ) <= 0 ) then
        bAll  := true;
      else
        nCount  := nIQRecCount;
      end if;

      loop
        begin
          dCurrenReqStartStamp  := dbms_utility.GET_TIME( );

          if ( Schema_DocSys.DocSys_IQProcessing.FetchIQForProcess( 'Schema_DocSys.QUEUE_EXPO', iqRec, nGateNo ) ) then
            if ( Schema_GPSys.OraGPSys.ArcProcessedRows( ) ) then
              dStart     := sysdate;
              nStartSeq  := Schema_GPSys.OraGPSys.GetArcProcessingNextSeqVal( );
            end if;

            if ( not bServiceDocsLoaded ) then
              GetDocsConfiguration( );
              bServiceDocsLoaded  := true;
            end if;

            RecExpoMove  := null;
            RecMoveText  := null;
            IDOldMove    := null;
            Schema_DocSys.DocSys.GetDocument( iqRec.doc_type, iqRec.doc_num, iqRec.ch_stamp, oDoc );

            if ( iqRec.doc_type = rDocMemoOrderParams.DocType ) then
              Schema_DocSys.DocSys.GetList( Schema_DocSys.DocSys.GetDocValueNumber( oDoc, rDocMemoOrderParams.Deals ), oDealList );
              RecExpoMove.UNIQCODE     := Schema_DocSys.DocSys.GetDocValueNumber( oDoc, rDocMemoOrderParams.UniqCode );
              RecExpoMove.ID_MOVE      := Schema_DocSys.DocSys.GetDocValueNumber( oDoc, rDocMemoOrderParams.ID_Move );
              IDOldMove                := Schema_DocSys.DocSys.GetDocValueNumber( oDoc, rDocMemoOrderParams.ID_Move_Old );
              RecExpoMove.SCH_DATE     := Schema_DocSys.DocSys.GetDocValueDate( oDoc, rDocMemoOrderParams.SchDate );
              RecExpoMove.SCH_DOC      := Schema_DocSys.DocSys.GetDocValueNumber( oDoc, rDocMemoOrderParams.SchDoc );
              --
              RecMoveText.ORD_TEXT     := Schema_DocSys.DocSys.GetDocValueString( oDoc, rDocMemoOrderParams.OrdText );
              RecMoveText.SYS_TEXT     := Schema_DocSys.DocSys.GetDocValueString( oDoc, rDocMemoOrderParams.SysText );
              RecMoveText.CH_OPER      := Schema_DocSys.DocSys.GetDocValueNumber( oDoc, rDocMemoOrderParams.ChOper );
              RecMoveText.ORIGIN       := Schema_DocSys.DocSys.GetDocValueString( oDoc, rDocMemoOrderParams.Origin );
              RecMoveText.DATETIME     := Schema_DocSys.Docsys.GetDocValueString( oDoc, rDocMemoOrderParams.DateTime );
              RecMoveText.ID_CUST      := Schema_DocSys.DocSys.GetDocValueNumber( oDoc, rDocMemoOrderParams.ID_Cust );
              RecMoveText.FOLDER_MODE  := Schema_DocSys.DocSys.GetDocValueString( oDoc, rDocMemoOrderParams.FolderMode );

              if ( RecMoveText.FOLDER_MODE is not null and
                  Schema_GPSys.OraGPSys.SplitRanges( RecMoveText.FOLDER_MODE, aListFr, aListTo, false ) ) then
                RecMoveText.FOLDER_MODE  := aListFr( 1 );
                RecMoveText.FOLDER_DATE  := Schema_GPSys.OraGPSys.BegOfMonth( RecExpoMove.SCH_DATE );

                if ( aListFr.count >= 2 and
                    aListFr( 2 ) is not null and
                    trim( aListFr( 2 ) ) <> '0' ) then
                  RecMoveText.FOLDER_NMBR  := aListFr( 2 );
                else
                  RecMoveText.FOLDER_NMBR      := GetExpoNumber( 'Folder_' ||
                                                                 RecMoveText.FOLDER_MODE ||
                                                                 '_' ||
                                                                 to_char( RecExpoMove.UNIQCODE, 'FM0999999999' )||
                                                                 to_char( RecMoveText.FOLDER_DATE, 'yyyymmdd' )
                                                                );
                end if;

                if ( aListFr.count >= 3 and
                    aListFr( 3 ) is not null ) then
                  RecMoveText.FOLDER_TYPE  := aListFr( 3 );
                end if;
              end if;

              if ( nvl( IDOldMove, 0 ) > 0 ) then
                update EXPO_STRNMOVES
                   set ID_MOVE_OLD  = IDOldMove
                 where ID_MOVE_NEW = RecExpoMove.ID_MOVE;

                if ( sql%rowcount = 0 ) then
                  insert into EXPO_STRNMOVES(
                                ID_MOVE_OLD,
                                ID_MOVE_NEW
                              )
                       values ( IDOldMove,
                                RecExpoMove.ID_MOVE
                               );
                end if;

                Calclih.MarkLihvi4Storno( IDOldMove, RecExpoMove.ID_MOVE );
                Cmd_LoanTaxes.MarkAmortSch4Storno( IDOldMove );
              end if;

              update EXPO_MOVE_TEXT
                 set ORD_TEXT   = RecMoveText.ORD_TEXT,
                     SYS_TEXT   = RecMoveText.SYS_TEXT,
                     CH_OPER    = RecMoveText.CH_OPER,
                     ORIGIN     = RecMoveText.ORIGIN,
                     DATETIME   = RecMoveText.DATETIME,
                     ID_CUST    = RecMoveText.ID_CUST,
                     DOC_NUM    = iqRec.doc_num,
                     CH_STAMP   = iqRec.ch_stamp,
                     OPER_DATE  = Schema_RA.GPC_Tools.GetSchDate( null )
               where ID_MOVE = RecExpoMove.ID_MOVE;

              if ( sql%rowcount = 0 ) then
                insert into EXPO_MOVE_TEXT(
                              ID_MOVE,
                              ORD_TEXT,
                              SYS_TEXT,
                              CH_OPER,
                              ORIGIN,
                              DATETIME,
                              ID_CUST,
                              DOC_NUM,
                              CH_STAMP,
                              OPER_DATE,
                              FOLDER_MODE,
                              FOLDER_DATE,
                              FOLDER_NMBR
                            )
                     values ( RecExpoMove.ID_MOVE,
                              RecMoveText.ORD_TEXT,
                              RecMoveText.SYS_TEXT,
                              RecMoveText.CH_OPER,
                              RecMoveText.ORIGIN,
                              RecMoveText.DATETIME,
                              RecMoveText.ID_CUST,
                              iqRec.doc_num,
                              iqRec.ch_stamp,
                              Schema_RA.GPC_Tools.GetSchDate( null ),
                              RecMoveText.FOLDER_MODE,
                              RecMoveText.FOLDER_DATE,
                              RecMoveText.FOLDER_NMBR
                             );
              end if;

              SetMaxExpoNumber( 'ID_MOVE', RecExpoMove.ID_MOVE );
              SetMaxExpoNumber( SchDocCntName( RecExpoMove.UNIQCODE, RecExpoMove.SCH_DATE ), RecExpoMove.SCH_DOC );
              bDummy                   := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoMoves, RecExpoMove.ID_MOVE );

              for i in 1 .. oDealList.count loop
                Schema_DocSys.DocSys.GetDocument( oDealList( i ).DocType, oDealList( i ).LDocNo, oDealList( i ).LChStamp, oDeal );
                RecExpoMove.REFERENCIA   := Schema_DocSys.DocSys.GetDocValueString( oDeal, rDocMemoOrderParams.Referencia );
                RecExpoMove.TECHN_TYPE   := 0;
                RecExpoMove.TECHN_IDOBJ  := 0;

                if ( Schema_GPSys.OraGPSys.SplitRanges( RecExpoMove.REFERENCIA, aListFr, aListTo, false ) ) then
                  if ( aListFr.count = 1 ) then
                    cReferDt  := aListFr( 1 );
                    cReferKt  := aListFr( 1 );
                  elsif ( aListFr.count = 2 ) then
                    cReferDt  := aListFr( 1 );
                    cReferKt  := aListFr( 2 );
                  elsif ( aListFr.count >= 3 ) then
                    cReferDt                 := aListFr( 1 );
                    cReferKt                 := aListFr( 2 );
                    RecExpoMove.TECHN_TYPE   := Schema_GPSys.OraGPSys.My_to_number( trim( aListFr( 3 ) ) );
                    RecExpoMove.TECHN_IDOBJ  := Schema_GPSys.OraGPSys.My_to_number( trim( aListTo( 3 ) ) );
                  end if;
                end if;

                Schema_DocSys.DocSys.GetList( Schema_DocSys.DocSys.GetDocValueNumber( oDeal, rDocMemoOrderParams.Opers ), oOperList );

                for j in 1 .. oOperList.count loop
                  Schema_DocSys.DocSys.GetDocument( oOperList( j ).DocType, oOperList( j ).LDocNo, oOperList( j ).LChStamp, oOper );
                  RecExpoMove.OPER_TYPE   := Schema_DocSys.DocSys.GetDocValueNumber( oOper, rDocMemoOrderParams.Oper_Type );
                  RecExpoMove.VALIOR      := Schema_DocSys.DocSys.GetDocValueDate( oOper, rDocMemoOrderParams.Oper_Valior );
                  RecExpoMove.SYS_AMOUNT  := Schema_DocSys.DocSys.GetDocValueMoneyAmount( oOper, rDocMemoOrderParams.Oper_SysAmn );
                  --
                  RecExpoMove.ORDROWNUM   := Schema_DocSys.DocSys.GetDocValueNumber( oOper, rDocMemoOrderParams.Oper_RowNum );
                  --
                  RecExpoMove.ID_EXPO     := Schema_DocSys.DocSys.GetDocValueNumber( oOper, rDocMemoOrderParams.Oper_ExpoDt );
                  RecExpoMove.AMOUNT      := Schema_DocSys.DocSys.GetDocValueMoneyAmount( oOper, rDocMemoOrderParams.Oper_AmnDt );
                  nIDExpoKt               := Schema_DocSys.DocSys.GetDocValueNumber( oOper, rDocMemoOrderParams.Oper_ExpoKt );
                  nAmountKt               := Schema_DocSys.DocSys.GetDocValueMoneyAmount( oOper, rDocMemoOrderParams.Oper_AmnKt );

                  if ( nvl( IDOldMove, 0 ) > 0 ) then
                    select -ADD_AMOUNT, -- pri preminavane v evrova sreda ADD_AMOUNT i SYS_AMOUNT sa razmeneni i ot docsys-a
                           -SYS_AMOUNT -- za order pusnat v levova sreda v SYS_AMOUNT ima levove e ne evro
                      into RecExpoMove.ADD_AMOUNT,
                           RecExpoMove.SYS_AMOUNT
                      from EXPO_MOVES
                     where ID_MOVE = IDOldMove and
                           ORDROWNUM = RecExpoMove.ORDROWNUM and
                           DT_KT = 'D';
                  else
                    select nvl( sum( ADD_AMOUNT ),
                                case
                                  when Schema_GPSys.OraGPSys.SYS_CURR = Schema_GPSys.OraGPSys.BGN_CURR then
                                    case
                                      when Schema_GPSys.HeadExpo.IDExpo2CodVal( RecExpoMove.ID_EXPO ) = Schema_GPSys.OraGPSys.EUR_CURR then RecExpoMove.AMOUNT
                                      when Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoKt ) = Schema_GPSys.OraGPSys.EUR_CURR then nAmountKt
                                      else Schema_GPSys.OraGPSys.nTruncSet( RecExpoMove.SYS_AMOUNT / Schema_GPSys.OraGPSys.EURORate, Schema_GPSys.OraGPSys.EUR_CURR )
                                    end
                                  else
                                    case
                                      when Schema_GPSys.HeadExpo.IDExpo2CodVal( RecExpoMove.ID_EXPO ) = Schema_GPSys.OraGPSys.BGN_CURR then RecExpoMove.AMOUNT
                                      when Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoKt ) = Schema_GPSys.OraGPSys.BGN_CURR then nAmountKt
                                      else Schema_GPSys.OraGPSys.nTruncSet( RecExpoMove.SYS_AMOUNT * Schema_GPSys.OraGPSys.EURORate, Schema_GPSys.OraGPSys.BGN_CURR )
                                    end
                                end
                               )
                      into RecExpoMove.ADD_AMOUNT
                      from EXPO_MOVES
                     where ID_MOVE = RecExpoMove.ID_MOVE and
                           ORDROWNUM = RecExpoMove.ORDROWNUM and
                           DT_KT = 'D';
                  end if;

                  dValiorPeriod           := null;

                  if ( nvl( IDOldMove, 0 ) > 0 ) then
                    open iqqVP( IDOldMove, RecExpoMove.ORDROWNUM );

                    fetch iqqVP
                      into dValiorPeriod;

                    close iqqVP;
                  elsif ( RecExpoMove.TECHN_TYPE > 0 and
                         RecExpoMove.TECHN_IDOBJ > 0 ) then
                    select max( a.VALIOR_PERIOD )
                      into dValiorPeriod
                      from EXPO_MOVES a
                     where a.TECHN_TYPE = RecExpoMove.TECHN_TYPE and
                           a.TECHN_IDOBJ = RecExpoMove.TECHN_IDOBJ and
                           a.ID_MOVE = (select max( b.ID_MOVE )
                                          from EXPO_MOVES b
                                         where b.TECHN_TYPE = RecExpoMove.TECHN_TYPE and
                                               b.TECHN_IDOBJ = RecExpoMove.TECHN_IDOBJ);
                  end if;

                  if ( dValiorPeriod is not null and
                      nvl( IDOldMove, 0 ) = 0 and
                      RecExpoMove.TECHN_TYPE = Cmd_Expo_Add.nTechnInvoice and
                      RecExpoMove.TECHN_IDOBJ > 0 ) then
                    select count( 1 )
                      into nDummy
                      from Schema_DMA.BUILD_ARTICULS_OPERATION
                     where ID_DEAL = RecExpoMove.TECHN_IDOBJ;

                    if ( nDummy > 0 ) then
                      dValiorPeriod  := null;
                    end if;
                  end if;

                  update EXPO_MOVES
                     set SCH_DOC        = RecExpoMove.SCH_DOC,
                         REFERENCIA     = cReferDt,
                         TECHN_TYPE     = RecExpoMove.TECHN_TYPE,
                         TECHN_IDOBJ    = RecExpoMove.TECHN_IDOBJ,
                         DOC_NUM        = iqRec.doc_num,
                         CH_STAMP       = iqRec.ch_stamp,
                         VALIOR_PERIOD  = nvl( dValiorPeriod, RecExpoMove.VALIOR )
                   where ID_MOVE = RecExpoMove.ID_MOVE and
                         ORDROWNUM = RecExpoMove.ORDROWNUM and
                         DT_KT = 'D';

                  if ( sql%rowcount = 0 ) then
                    insert into EXPO_MOVES(
                                  ID_MOVE,
                                  UNIQCODE,
                                  OPER_TYPE,
                                  ID_EXPO,
                                  DT_KT,
                                  AMOUNT,
                                  SYS_AMOUNT,
                                  VALIOR,
                                  SCH_DATE,
                                  SCH_DOC,
                                  ORDROWNUM,
                                  REFERENCIA,
                                  TECHN_TYPE,
                                  TECHN_IDOBJ,
                                  DOC_NUM,
                                  CH_STAMP,
                                  VALIOR_PERIOD,
                                  DEAL_NUM,
                                  ADD_AMOUNT,
                                  EXPO_CODVAL
                                )
                         values ( RecExpoMove.ID_MOVE,
                                  RecExpoMove.UNIQCODE,
                                  RecExpoMove.OPER_TYPE,
                                  RecExpoMove.ID_EXPO,
                                  'D',
                                  RecExpoMove.AMOUNT,
                                  RecExpoMove.SYS_AMOUNT,
                                  RecExpoMove.VALIOR,
                                  RecExpoMove.SCH_DATE,
                                  RecExpoMove.SCH_DOC,
                                  RecExpoMove.ORDROWNUM,
                                  cReferDt,
                                  RecExpoMove.TECHN_TYPE,
                                  RecExpoMove.TECHN_IDOBJ,
                                  iqRec.doc_num,
                                  iqRec.ch_stamp,
                                  nvl( dValiorPeriod, RecExpoMove.VALIOR ),
                                  i,
                                  RecExpoMove.ADD_AMOUNT,
                                  Schema_GPSys.HeadExpo.IDExpo2CodVal( RecExpoMove.ID_EXPO )
                                 );
                  end if;

                  update EXPO_STATE
                     set OBOR_DT         = OBOR_DT + RecExpoMove.AMOUNT,
                         SYS_OBOR_DT     = SYS_OBOR_DT + RecExpoMove.SYS_AMOUNT,
                         ADD_OBOR_DT     = ADD_OBOR_DT + RecExpoMove.ADD_AMOUNT,
                         LASTSCHDATE     = RecExpoMove.SCH_DATE,
                         LASTVALIOR      = case
                                             when nvl( IDOldMove, 0 ) > 0 then null
                                             else RecExpoMove.VALIOR
                                           end
                   where ID_EXPO = RecExpoMove.ID_EXPO;

                  if ( sql%rowcount = 0 ) then
                    begin
                      insert into EXPO_STATE(
                                    ID_EXPO,
                                    OBOR_DT,
                                    OBOR_KT,
                                    SYS_OBOR_DT,
                                    SYS_OBOR_KT,
                                    LASTSCHDATE,
                                    LASTVALIOR,
                                    ADD_OBOR_DT,
                                    ADD_OBOR_KT
                                  )
                           values ( RecExpoMove.ID_EXPO,
                                    RecExpoMove.AMOUNT,
                                    0,
                                    RecExpoMove.SYS_AMOUNT,
                                    0,
                                    RecExpoMove.SCH_DATE,
                                    case
                                      when nvl( IDOldMove, 0 ) > 0 then null
                                      else RecExpoMove.VALIOR
                                    end,
                                    RecExpoMove.ADD_AMOUNT,
                                    0
                                   );
                    exception
                      when dup_val_on_index then
                        update EXPO_STATE
                           set OBOR_DT         = OBOR_DT + RecExpoMove.AMOUNT,
                               SYS_OBOR_DT     = SYS_OBOR_DT + RecExpoMove.SYS_AMOUNT,
                               ADD_OBOR_DT     = ADD_OBOR_DT + RecExpoMove.ADD_AMOUNT,
                               LASTSCHDATE     = RecExpoMove.SCH_DATE,
                               LASTVALIOR      = case
                                                   when nvl( IDOldMove, 0 ) > 0 then null
                                                   else RecExpoMove.VALIOR
                                                 end
                         where ID_EXPO = RecExpoMove.ID_EXPO;
                    end;
                  end if;

                  ForceWWWUpdate( RecExpoMove.ID_EXPO );
                  ---
                  RecExpoMove.ID_EXPO     := nIDExpoKt;
                  RecExpoMove.AMOUNT      := nAmountKt;

                  update EXPO_MOVES
                     set SCH_DOC        = RecExpoMove.SCH_DOC,
                         REFERENCIA     = cReferKt,
                         TECHN_TYPE     = RecExpoMove.TECHN_TYPE,
                         TECHN_IDOBJ    = RecExpoMove.TECHN_IDOBJ,
                         DOC_NUM        = iqRec.doc_num,
                         CH_STAMP       = iqRec.ch_stamp,
                         VALIOR_PERIOD  = nvl( dValiorPeriod, RecExpoMove.VALIOR )
                   where ID_MOVE = RecExpoMove.ID_MOVE and
                         ORDROWNUM = RecExpoMove.ORDROWNUM and
                         DT_KT = 'K';

                  if ( sql%rowcount = 0 ) then
                    insert into EXPO_MOVES(
                                  ID_MOVE,
                                  UNIQCODE,
                                  OPER_TYPE,
                                  ID_EXPO,
                                  DT_KT,
                                  AMOUNT,
                                  SYS_AMOUNT,
                                  VALIOR,
                                  SCH_DATE,
                                  SCH_DOC,
                                  ORDROWNUM,
                                  REFERENCIA,
                                  TECHN_TYPE,
                                  TECHN_IDOBJ,
                                  DOC_NUM,
                                  CH_STAMP,
                                  VALIOR_PERIOD,
                                  DEAL_NUM,
                                  ADD_AMOUNT,
                                  EXPO_CODVAL
                                )
                         values ( RecExpoMove.ID_MOVE,
                                  RecExpoMove.UNIQCODE,
                                  RecExpoMove.OPER_TYPE,
                                  RecExpoMove.ID_EXPO,
                                  'K',
                                  RecExpoMove.AMOUNT,
                                  RecExpoMove.SYS_AMOUNT,
                                  RecExpoMove.VALIOR,
                                  RecExpoMove.SCH_DATE,
                                  RecExpoMove.SCH_DOC,
                                  RecExpoMove.ORDROWNUM,
                                  cReferKt,
                                  RecExpoMove.TECHN_TYPE,
                                  RecExpoMove.TECHN_IDOBJ,
                                  iqRec.doc_num,
                                  iqRec.ch_stamp,
                                  nvl( dValiorPeriod, RecExpoMove.VALIOR ),
                                  i,
                                  RecExpoMove.ADD_AMOUNT,
                                  Schema_GPSys.HeadExpo.IDExpo2CodVal( RecExpoMove.ID_EXPO )
                                 );
                  end if;

                  update EXPO_STATE
                     set OBOR_KT         = OBOR_KT + RecExpoMove.AMOUNT,
                         SYS_OBOR_KT     = SYS_OBOR_KT + RecExpoMove.SYS_AMOUNT,
                         ADD_OBOR_KT     = ADD_OBOR_KT + RecExpoMove.ADD_AMOUNT,
                         LASTSCHDATE     = RecExpoMove.SCH_DATE,
                         LASTVALIOR      = case
                                             when nvl( IDOldMove, 0 ) > 0 then null
                                             else RecExpoMove.VALIOR
                                           end
                   where ID_EXPO = RecExpoMove.ID_EXPO;

                  if ( sql%rowcount = 0 ) then
                    begin
                      insert into EXPO_STATE(
                                    ID_EXPO,
                                    OBOR_DT,
                                    OBOR_KT,
                                    SYS_OBOR_DT,
                                    SYS_OBOR_KT,
                                    LASTSCHDATE,
                                    LASTVALIOR,
                                    ADD_OBOR_DT,
                                    ADD_OBOR_KT
                                  )
                           values ( RecExpoMove.ID_EXPO,
                                    0,
                                    RecExpoMove.AMOUNT,
                                    0,
                                    RecExpoMove.SYS_AMOUNT,
                                    RecExpoMove.SCH_DATE,
                                    case
                                      when nvl( IDOldMove, 0 ) > 0 then null
                                      else RecExpoMove.VALIOR
                                    end,
                                    0,
                                    RecExpoMove.ADD_AMOUNT
                                   );
                    exception
                      when dup_val_on_index then
                        update EXPO_STATE
                           set OBOR_KT         = OBOR_KT + RecExpoMove.AMOUNT,
                               SYS_OBOR_KT     = SYS_OBOR_KT + RecExpoMove.SYS_AMOUNT,
                               ADD_OBOR_KT     = ADD_OBOR_KT + RecExpoMove.ADD_AMOUNT,
                               LASTSCHDATE     = RecExpoMove.SCH_DATE,
                               LASTVALIOR      = case
                                                   when nvl( IDOldMove, 0 ) > 0 then null
                                                   else RecExpoMove.VALIOR
                                                 end
                         where ID_EXPO = RecExpoMove.ID_EXPO;
                    end;
                  end if;

                  ForceWWWUpdate( RecExpoMove.ID_EXPO );
                end loop;
              end loop;

              update BDG_MOVES
                 set DOC_NUM   = iqRec.doc_num,
                     CH_STAMP  = iqRec.ch_stamp
               where ID_MOVE = RecExpoMove.ID_MOVE;

              update ADD_MOVES
                 set DOC_NUM   = iqRec.doc_num,
                     CH_STAMP  = iqRec.ch_stamp
               where ID_MOVE = RecExpoMove.ID_MOVE;

              SetMaxTriggNumber( 'ID_LASTMOVE', RecExpoMove.ID_MOVE );
            else
              IDExpo           := null;
              rExpoLimit       := null;
              rExpoZapor       := null;
              RecBaseIntr      := null;
              rGroupMoves      := null;
              rExpoLimObor     := null;
              rExpoAddIntrate  := null;

              for rec in ( select a.FLDType,
                                  a.nv,
                                  a.sv,
                                  a.dv,
                                  a.mvc,
                                  a.mva,
                                  b.MATTER_ID
                             from table( cast( oDoc as Schema_GPSys.RecDocSysType ) ) a,
                                  EXPO_SERVICEDOC b
                            where b.DOC_TYPE = iqRec.doc_type and
                                  b.FIELD_TYPE = a.FLDType ) loop
                if ( rec.MATTER_ID = 'ID_EXPO' ) then
                  IDExpo  := rec.nv;
                elsif ( rec.MATTER_ID = 'LIMIT' ) then
                  rExpoLimit.CODVAL    := substr( rec.mvc, 1, 3 );
                  rExpoLimit.SUMLIMIT  := rec.mva;
                -- запори
                elsif ( rec.MATTER_ID = 'Zapor_IDZapor' ) then
                  rExpoZapor.ID_LIMIT  := rec.nv;
                elsif ( rec.MATTER_ID = 'Zapor_IDExpo' ) then
                  rExpoZapor.ID_EXPO  := rec.nv;
                elsif ( rec.MATTER_ID = 'Zapor_BegDate' ) then
                  rExpoZapor.BEG_DATE  := rec.dv;
                elsif ( rec.MATTER_ID = 'Zapor_EndDate' ) then
                  rExpoZapor.END_DATE  := rec.dv;
                elsif ( rec.MATTER_ID = 'Zapor_Type' ) then
                  rExpoZapor.TYPE_LIMIT  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_Amount' ) then
                  rExpoZapor.CODVAL    := substr( rec.mvc, 1, 3 );
                  rExpoZapor.SUMLIMIT  := rec.mva;
                elsif ( rec.MATTER_ID = 'Zapor_Status' ) then
                  rExpoZapor.STATUS  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_BegSysDate' ) then
                  rExpoZapor.BEG_SYSDATE  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_EndSysDate' ) then
                  rExpoZapor.END_SYSDATE  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_Reason' ) then
                  rExpoZapor.REASON  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_FullLimit' ) then
                  rExpoZapor.FULL_LIMIT  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_ProcLimit' ) then
                  rExpoZapor.PROC_LIMIT  := rec.nv;
                elsif ( rec.MATTER_ID = 'Zapor_BegUserID' ) then
                  rExpoZapor.BEG_USER_ID  := rec.nv;
                elsif ( rec.MATTER_ID = 'Zapor_EndUserID' ) then
                  rExpoZapor.END_USER_ID  := rec.nv;
                elsif ( rec.MATTER_ID = 'Zapor_KindLimit' ) then
                  rExpoZapor.KIND_LIMIT  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_Authority' ) then
                  rExpoZapor.AUTHORITY  := rec.nv;
                elsif ( rec.MATTER_ID = 'Zapor_EnforcementCase' ) then
                  rExpoZapor.ENFORCEMENT_CASE  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_OutNumber' ) then
                  rExpoZapor.OUT_NUMBER  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_Decree' ) then
                  rExpoZapor.DECREE  := rec.sv;
                elsif ( rec.MATTER_ID = 'Zapor_ExtNumber' ) then
                  rExpoZapor.EXT_NUMBER  := rec.sv;
                -- основни лихвени проценти
                elsif ( rec.MATTER_ID = 'BaseIntr_TypeBase' ) then
                  RecBaseIntr.BASE_PRC  := rec.sv;
                elsif ( rec.MATTER_ID = 'BaseIntr_CodVal' ) then
                  RecBaseIntr.CODVAL  := rec.sv;
                elsif ( rec.MATTER_ID = 'BaseIntr_FromDate' ) then
                  RecBaseIntr.FROM_DATE  := rec.dv;
                elsif ( rec.MATTER_ID = 'BaseIntr_Percent' ) then
                  RecBaseIntr.PERCENT  := rec.nv;
                elsif ( rec.MATTER_ID = 'BaseIntr_AmnTo' ) then
                  RecBaseIntr.AMN_TO  := rec.nv;
                elsif ( rec.MATTER_ID = 'BaseIntr_EndDate' ) then
                  RecBaseIntr.END_DATE  := rec.dv;
                --Групови операции
                elsif ( rec.MATTER_ID = 'GroupIdMoves_IdGroup' ) then
                  rGroupMoves.ID_GROUP  := rec.nv;
                elsif ( rec.MATTER_ID = 'GroupIdMoves_IdMove' ) then
                  rGroupMoves.ID_MOVE  := rec.nv;
                elsif ( rec.MATTER_ID = 'GroupIdMoves_Date' ) then
                  rGroupMoves.FLDDATE  := rec.dv;
                -- Лимити за обороти
                elsif ( rec.MATTER_ID = 'EXPOLIMOBOR_ID' ) then
                  rExpoLimObor.ID_LIM_OBOR  := rec.nv;
                elsif ( rec.MATTER_ID = 'EXPOLIMOBOR_ID_EXPO' ) then
                  rExpoLimObor.ID_EXPO  := rec.nv;
                elsif ( rec.MATTER_ID = 'EXPOLIMOBOR_LIM_MODE' ) then
                  rExpoLimObor.LIM_MODE  := rec.sv;
                elsif ( rec.MATTER_ID = 'EXPOLIMOBOR_VID_OBOR' ) then
                  rExpoLimObor.VID_OBOR  := rec.sv;
                elsif ( rec.MATTER_ID = 'EXPOLIMOBOR_LIM_OBOR' ) then
                  rExpoLimObor.LIM_OBOR  := rec.nv;
                -- Лихвени надбавки
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_ID' ) then
                  rExpoAddIntrate.REGID  := rec.nv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_IDEXPO' ) then
                  rExpoAddIntrate.ID_EXPO  := rec.nv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_FromDate' ) then
                  rExpoAddIntrate.BEGDATE  := rec.dv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_ToDate' ) then
                  rExpoAddIntrate.ENDDATE  := rec.dv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_HighProc' ) then
                  rExpoAddIntrate.LIHPROC  := rec.nv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_LowProc' ) then
                  rExpoAddIntrate.LOWPROC  := rec.nv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_Reason' ) then
                  rExpoAddIntrate.REASON  := rec.sv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_State' ) then
                  rExpoAddIntrate.STATUS  := rec.sv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_TypeProduct' ) then
                  rExpoAddIntrate.TYPE_PRODUCT  := rec.sv;
                elsif ( rec.MATTER_ID = 'EXPO_ADDINTRATE_CH_OPER' ) then
                  rExpoAddIntrate.CH_OPER  := rec.nv;
                --Групови лимити
                elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_ID_LIMIT' ) then
                  nGroupLimitsID  := rec.nv;
                end if;
              end loop;

              if ( nvl( IDExpo, 0 ) > 0 ) then
                begin
                  insert into EXPO_STATE(
                                ID_EXPO,
                                OBOR_DT,
                                OBOR_KT,
                                SYS_OBOR_DT,
                                SYS_OBOR_KT,
                                ADD_OBOR_DT,
                                ADD_OBOR_KT
                              )
                       values ( IDExpo,
                                0,
                                0,
                                0,
                                0,
                                0,
                                0
                               );
                exception
                  when dup_val_on_index then
                    null;
                end;

                if ( ( not Schema_GPSys.HeadExpo.IsItCreditExpo( IDExpo ) ) or
                    ( rExpoLimit.CODVAL is not null and
                     rExpoLimit.SUMLIMIT is not null ) ) then
                  delete from EXPO_LIMITS
                        where ID_EXPO = IDExpo and
                              ID_LIMIT is null;
                end if;

                if ( rExpoLimit.CODVAL is not null and
                    rExpoLimit.SUMLIMIT is not null ) then
                  insert into EXPO_LIMITS(
                                ID_EXPO,
                                TYPE_LIMIT,
                                CODVAL,
                                SUMLIMIT,
                                STATUS,
                                BEG_SYSDATE,
                                REASON,
                                DOC_NUM,
                                CH_STAMP
                              )
                       values ( IDExpo,
                                ExpoLimit_Limit,
                                rExpoLimit.CODVAL,
                                rExpoLimit.SUMLIMIT,
                                ZaporStat_Active,
                                to_char( sysdate, Schema_GPSys.GPC_Parser.FORMAT_TRANSPORT_DATETIME ),
                                rExpoZapor.REASON,
                                iqRec.doc_num,
                                iqRec.ch_stamp
                               );
                end if;

                SetMaxTriggNumber( 'ID_LASTLIMIT', IDExpo );
              end if;

              -- запори
              if ( rExpoZapor.ID_LIMIT is not null ) then
                if ( rExpoZapor.TYPE_LIMIT = ExpoLimit_ForbiddenKT ) then
                  rExpoZapor.SUMLIMIT    := 0;
                  rExpoZapor.PROC_LIMIT  := 0;
                  rExpoZapor.FULL_LIMIT  := 'F';
                end if;

                update EXPO_LIMITS
                   set ID_EXPO           = rExpoZapor.ID_EXPO,
                       BEG_DATE          = rExpoZapor.BEG_DATE,
                       END_DATE          = rExpoZapor.END_DATE,
                       CODVAL            = rExpoZapor.CODVAL,
                       SUMLIMIT          = rExpoZapor.SUMLIMIT,
                       STATUS            = rExpoZapor.STATUS,
                       BEG_SYSDATE       = rExpoZapor.BEG_SYSDATE,
                       BEG_USER_ID       = rExpoZapor.BEG_USER_ID,
                       END_SYSDATE       = rExpoZapor.END_SYSDATE,
                       END_USER_ID       = rExpoZapor.END_USER_ID,
                       REASON            = rExpoZapor.REASON,
                       FULL_LIMIT        = rExpoZapor.FULL_LIMIT,
                       PROC_LIMIT        = rExpoZapor.PROC_LIMIT,
                       KIND_LIMIT        = rExpoZapor.KIND_LIMIT,
                       AUTHORITY         = rExpoZapor.AUTHORITY,
                       ENFORCEMENT_CASE  = rExpoZapor.ENFORCEMENT_CASE,
                       OUT_NUMBER        = rExpoZapor.OUT_NUMBER,
                       DECREE            = rExpoZapor.DECREE,
                       EXT_NUMBER        = rExpoZapor.EXT_NUMBER,
                       DOC_NUM           = iqRec.doc_num,
                       CH_STAMP          = iqRec.ch_stamp
                 where ID_LIMIT = rExpoZapor.ID_LIMIT and
                       TYPE_LIMIT = rExpoZapor.TYPE_LIMIT;

                if ( sql%rowcount = 0 ) then
                  if ( not ZaporInternal( rExpoZapor.TYPE_LIMIT ) ) then
                    delete from EXPO_LIMITS
                          where ID_LIMIT = rExpoZapor.ID_LIMIT and
                                IsZaporInternal( TYPE_LIMIT ) = 'F';
                  end if;

                  insert into EXPO_LIMITS(
                                ID_LIMIT,
                                TYPE_LIMIT,
                                ID_EXPO,
                                BEG_DATE,
                                END_DATE,
                                CODVAL,
                                SUMLIMIT,
                                STATUS,
                                BEG_SYSDATE,
                                BEG_USER_ID,
                                END_SYSDATE,
                                END_USER_ID,
                                REASON,
                                FULL_LIMIT,
                                PROC_LIMIT,
                                KIND_LIMIT,
                                AUTHORITY,
                                ENFORCEMENT_CASE,
                                OUT_NUMBER,
                                DECREE,
                                EXT_NUMBER,
                                DOC_NUM,
                                CH_STAMP
                              )
                       values ( rExpoZapor.ID_LIMIT,
                                rExpoZapor.TYPE_LIMIT,
                                rExpoZapor.ID_EXPO,
                                rExpoZapor.BEG_DATE,
                                rExpoZapor.END_DATE,
                                rExpoZapor.CODVAL,
                                rExpoZapor.SUMLIMIT,
                                rExpoZapor.STATUS,
                                rExpoZapor.BEG_SYSDATE,
                                rExpoZapor.BEG_USER_ID,
                                rExpoZapor.END_SYSDATE,
                                rExpoZapor.END_USER_ID,
                                rExpoZapor.REASON,
                                rExpoZapor.FULL_LIMIT,
                                rExpoZapor.PROC_LIMIT,
                                rExpoZapor.KIND_LIMIT,
                                rExpoZapor.AUTHORITY,
                                rExpoZapor.ENFORCEMENT_CASE,
                                rExpoZapor.OUT_NUMBER,
                                rExpoZapor.DECREE,
                                rExpoZapor.EXT_NUMBER,
                                iqRec.doc_num,
                                iqRec.ch_stamp
                               );
                end if;

                SetMaxExpoNumber( 'Zapori', rExpoZapor.ID_LIMIT );
                bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj3( Schema_GPSys.OraGPSys.LockTypeZapori, rExpoZapor.ID_LIMIT );
                SetMaxTriggNumber( 'ID_LASTLIMIT', rExpoZapor.ID_EXPO );
              end if;

              if ( RecBaseIntr.BASE_PRC is not null ) then
                update EXPO_BASE_INTR
                   set PERCENT   = RecBaseIntr.PERCENT,
                       AMN_TO    = RecBaseIntr.AMN_TO,
                       END_DATE  = RecBaseIntr.END_DATE,
                       DOC_NUM   = iqRec.doc_num,
                       CH_STAMP  = iqRec.ch_stamp
                 where BASE_PRC = RecBaseIntr.BASE_PRC and
                       nvl( CODVAL, Schema_GPSys.OraGPSys.SYS_CURR ) = nvl( RecBaseIntr.CODVAL, Schema_GPSys.OraGPSys.SYS_CURR ) and
                       FROM_DATE = RecBaseIntr.FROM_DATE and
                       nvl( AMN_TO, 0 ) = nvl( RecBaseIntr.AMN_TO, 0 );

                if ( sql%rowcount = 0 ) then
                  insert into EXPO_BASE_INTR(
                                BASE_PRC,
                                CODVAL,
                                FROM_DATE,
                                PERCENT,
                                DOC_NUM,
                                CH_STAMP,
                                AMN_TO,
                                END_DATE
                              )
                       values ( RecBaseIntr.BASE_PRC,
                                nvl( RecBaseIntr.CODVAL, Schema_GPSys.OraGPSys.SYS_CURR ),
                                RecBaseIntr.FROM_DATE,
                                RecBaseIntr.PERCENT,
                                iqRec.doc_num,
                                iqRec.ch_stamp,
                                nvl( RecBaseIntr.AMN_TO, 0 ),
                                RecBaseIntr.END_DATE
                               );
                end if;
              end if;

              if ( rGroupMoves.ID_GROUP is not null and
                  rGroupMoves.ID_MOVE is not null ) then
                update EXPO_GROUPMOVES
                   set DOC_NUM   = iqRec.doc_num,
                       CH_STAMP  = iqRec.ch_stamp,
                       FLDDATE   = rGroupMoves.FLDDATE
                 where ID_GROUP = rGroupMoves.ID_GROUP and
                       ID_MOVE = rGroupMoves.ID_MOVE;

                if ( sql%rowcount = 0 ) then
                  insert into EXPO_GROUPMOVES(
                                ID_GROUP,
                                ID_MOVE,
                                DOC_NUM,
                                CH_STAMP,
                                FLDDATE
                              )
                       values ( rGroupMoves.ID_GROUP,
                                rGroupMoves.ID_MOVE,
                                iqRec.doc_num,
                                iqRec.ch_stamp,
                                rGroupMoves.FLDDATE
                               );
                end if;
              end if;

              if ( rExpoLimObor.ID_LIM_OBOR is not null ) then
                bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoLimitObor, rExpoLimObor.ID_LIM_OBOR );
                SetMaxExpoNumber( 'LimitObor', rExpoLimObor.ID_LIM_OBOR );

                update EXPO_LIM_OBOR
                   set ID_EXPO   = rExpoLimObor.ID_EXPO,
                       LIM_MODE  = rExpoLimObor.LIM_MODE,
                       VID_OBOR  = rExpoLimObor.VID_OBOR,
                       LIM_OBOR  = rExpoLimObor.LIM_OBOR,
                       DOC_NUM   = iqRec.doc_num,
                       CH_STAMP  = iqRec.ch_stamp
                 where ID_LIM_OBOR = rExpoLimObor.ID_LIM_OBOR;

                if ( sql%rowcount = 0 ) then
                  insert into EXPO_LIM_OBOR(
                                ID_LIM_OBOR,
                                ID_EXPO,
                                LIM_MODE,
                                VID_OBOR,
                                LIM_OBOR,
                                DOC_NUM,
                                CH_STAMP
                              )
                       values ( rExpoLimObor.ID_LIM_OBOR,
                                rExpoLimObor.ID_EXPO,
                                rExpoLimObor.LIM_MODE,
                                rExpoLimObor.VID_OBOR,
                                rExpoLimObor.LIM_OBOR,
                                iqRec.doc_num,
                                iqRec.ch_stamp
                               );
                end if;
              end if;

              if ( rExpoAddIntrate.REGID is not null ) then
                ExpoAddIntrate_UpdRegister( rExpoAddIntrate, iqRec.doc_num, iqRec.ch_stamp );
              end if;

              --
              if ( nGroupLimitsID is not null ) then
                oDocIQ  := Schema_GPSys.OraGPSys.DocObj2DocIQObj( oDoc, iqRec.doc_type );
                SaveGroupLimitsDataDocIntoReg( iqRec.doc_type, oDocIQ, iqRec.doc_num, iqRec.ch_stamp );
              end if;
            --
            end if;

            -- архивиране на входната опашка
            if ( Schema_GPSys.OraGPSys.ArcProcessedRows( ) ) then
              insert into EXPO_INPQUEUE_A(
                            DOC_NUM,
                            DOC_TYPE,
                            FIELD_TYPE,
                            FIELD_DATATYPE,
                            FIELD_NUM,
                            CH_STAMP,
                            OPERATIONS,
                            FLDSTART,
                            START_SEQ,
                            FLDEND,
                            END_SEQ,
                            GATENO
                          )
                select DOC_NUM,
                       DOC_TYPE,
                       FIELD_TYPE,
                       FIELD_DATATYPE,
                       FIELD_NUM,
                       CH_STAMP,
                       OPERATIONS,
                       dStart,
                       nStartSeq,
                       sysdate,
                       Schema_GPSys.OraGPSys.GetArcProcessingNextSeqVal( ),
                       GATENO
                  from Schema_DocSys.QUEUE_EXPO
                 where DOC_TYPE = iqRec.DOC_TYPE and
                       CH_STAMP = iqRec.CH_STAMP;
            end if;

            delete from Schema_DocSys.QUEUE_EXPO
                  where DOC_TYPE = iqRec.DOC_TYPE and
                        CH_STAMP = iqRec.CH_STAMP;

            --
            commit;
            Schema_GPSys.OraGPSys.WriteProcDuration( 'Schema_Expo',
                                                     'ExpoProcessing',
                                                     'dID: ' || to_char( iqRec.doc_num ) || ', docType: ' || to_char( iqRec.doc_type ),
                                                     dbms_utility.GET_TIME( ) - dCurrenReqStartStamp,
                                                     0,
                                                     0,
                                                     0,
                                                     0,
                                                     0,
                                                     0,
                                                     0,
                                                     0
                                                    );

            if ( not bAll ) then
              nCount  := nCount - 1;
              exit when nCount <= 0;
            end if;
          else
            exit; -- FetchIQForProcess
          end if;
        exception
          when deadlock_detected then
            rollback; -- za vseki sluchai
            exit;
        end;
      end loop;

      if ( bDelJunks ) then
        select distinct a.ID_MOVE
          bulk collect into aIDs
          from EXPO_MOVES a,
               Schema_GPSys.SYS_LOCKS b
         where a.CH_STAMP = 0 and
               a.ID_MOVE = b.id(+) and
               Schema_GPSys.OraGPSys.LockTypeExpoMoves = b.OBJ_TYPE(+) and
               b.id is null;

        if ( aIDs.count > 0 ) then
          forall ii in aIDs.first .. aIDs.last
            delete from EXPO_MOVES
                  where ID_MOVE = aIDs( ii );

          forall ii in aIDs.first .. aIDs.last
            delete from BDG_MOVES
                  where ID_MOVE = aIDs( ii );

          forall ii in aIDs.first .. aIDs.last
            delete from ADD_MOVES
                  where ID_MOVE = aIDs( ii );
        end if;

        aIDs.delete;

        select distinct a.ID_LIMIT
          bulk collect into aIDs
          from EXPO_LIMITS a,
               Schema_GPSys.SYS_LOCKS b
         where a.CH_STAMP = 0 and
               IsZaporInternal( a.TYPE_LIMIT ) = 'F' and
               a.ID_LIMIT = b.id(+) and
               Schema_GPSys.OraGPSys.LockTypeZapori = b.OBJ_TYPE(+) and
               b.id is null;

        if ( aIDs.count > 0 ) then
          forall ii in aIDs.first .. aIDs.last
            delete from EXPO_LIMITS
                  where ID_LIMIT = aIDs( ii );
        end if;

        aIDs.delete;

        select distinct a.ID_LIM_OBOR
          bulk collect into aIDs
          from EXPO_LIM_OBOR a,
               Schema_GPSys.SYS_LOCKS b
         where a.CH_STAMP = 0 and
               a.ID_LIM_OBOR = b.id(+) and
               Schema_GPSys.OraGPSys.LockTypeExpoLimitObor = b.OBJ_TYPE(+) and
               b.id is null;

        if ( aIDs.count > 0 ) then
          forall ii in aIDs.first .. aIDs.last
            delete from EXPO_LIM_OBOR
                  where ID_LIM_OBOR = aIDs( ii );
        end if;

        aIDs.delete;

        select distinct a.ID_LIMIT
          bulk collect into aIDs
          from GROUP_LIMITS a,
               Schema_GPSys.SYS_LOCKS b
         where a.CH_STAMP = 0 and
               a.ID_LIMIT = b.id(+) and
               Schema_GPSys.OraGPSys.LockTypeGroupLimits = b.OBJ_TYPE(+) and
               b.id is null;

        if ( aIDs.count > 0 ) then
          forall ii in aIDs.first .. aIDs.last
            delete from GROUP_LIMITS
                  where ID_LIMIT = aIDs( ii );
        end if;

        commit;
      end if;
    else
      RAISE_APPLICATION_ERROR( -20000, Schema_GPSys.MLng.Str2( 'ExpoProcessing() already running', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngEN ) );
    end if;
  end ExpoProcessing;

  --------------------------------------------------------------------------------
  function SaveGroupIdMoves( aIDMoves in Schema_GPSys.OraGPSys.aIntegers )
    return boolean is
    ii         pls_integer;
    jj         pls_integer;
    sCmdName   varchar2( 64 );
    oDoc       Schema_GPSys.DocSysIQType;
    bRet       boolean;
    nIdGroup   integer;
    nUniqCode  integer;
    nDocNo     integer;
    dDate      date;
    aParams    Schema_RA.GPC_RA.tblErrParams;
  begin
    bRet      := true;
    nIdGroup  := GetExpoNumber( 'ID_GROUPMOVE' );
    sCmdName  := 'GroupIdMoves';
    ii        := aIDMoves.first;

    while ( ii is not null and
           bRet ) loop
      bRet      := IDMove2DocDate( aIDMoves( ii ), nUniqCode, dDate, nDocNo );
      oDoc      := Schema_GPSys.DocSysIQType( );
      bRet      := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ID_GROUP', 1, nIdGroup ) and
                   Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ID_MOVE', 1, aIDMoves( ii ) ) and
                   Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, sCmdName, '1.FLDDATE', 1, dDate );

      if ( bRet ) then
        jj    := Schema_DocSys.DOCSYS_SaveInIQ.SaveDoc( oDoc );
        bRet  := jj = 0;

        if ( bRet ) then
          insert into EXPO_GROUPMOVES(
                        ID_GROUP,
                        ID_MOVE,
                        FLDDATE
                      )
               values ( nIdGroup,
                        aIDMoves( ii ),
                        dDate
                       );
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ERR';
          aParams( 1 ).ML_VALUE  := to_char( jj );
          Schema_RA.GPC_RA.RespSetErrorText( 'SaveDoc() error: $ERR$', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngEN, aParams );
        end if;
      end if;

      ii        := aIDMoves.next( ii );
    end loop;

    return bRet;
  end SaveGroupIdMoves;

  --------------------------------------------------------------------------------
  function SaveGroupObjRel( recGroupObj in out OBJ_GROUP_REL%rowtype )
    return boolean is
    oDoc      Schema_GPSys.DocSysIQType;
    sCmdName  varchar2( 64 );
    sOper     varchar2( 3 );
    jj        pls_integer;
    bRet      boolean;
    aParams   Schema_RA.GPC_RA.tblErrParams;
  begin
    bRet      := true;

    if ( nvl( recGroupObj.ID_GROUP, 0 ) > 0 ) then
      sOper  := 'EDT';
    else
      recGroupObj.ID_GROUP  := GetExpoNumber( 'ID_GROUPOBJ' );
      sOper                 := 'NEW';
    end if;

    sCmdName  := 'GroupRelation_' || sOper;
    oDoc      := Schema_GPSys.DocSysIQType( );
    bRet      := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ID_GROUP', 1, recGroupObj.ID_GROUP ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ID_OBJ1', 1, recGroupObj.ID_OBJ1 ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.TYPE_OBJ1', 1, recGroupObj.TYPE_OBJ1 ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ID_OBJ2', 1, recGroupObj.ID_OBJ2 ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.TYPE_OBJ2', 1, recGroupObj.TYPE_OBJ2 ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ID_CUST', 1, recGroupObj.ID_CUST ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.UNIQCODE', 1, recGroupObj.UNIQCODE ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.STATUS', 1, 'T' ) and
                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.CHOPER', 1, Schema_RA.GPC_RA.nCurrentUserID );

    if ( bRet ) then
      jj        := Schema_DocSys.DOCSYS_SaveInIQ.SaveDoc( oDoc );
      bRet      := jj = 0 and
                   Schema_GPSys.OraGPSys.MarkLockedObj( Schema_GPSys.OraGPSys.LockObjGroup, recGroupObj.ID_GROUP );

      if ( bRet ) then
        if ( sOper = 'NEW' ) then
          insert into OBJ_GROUP_REL(
                        ID_GROUP,
                        TYPE_OBJ1,
                        ID_OBJ1,
                        TYPE_OBJ2,
                        ID_OBJ2,
                        ID_CUST,
                        UNIQCODE,
                        STATUS,
                        CH_OPER
                      )
               values ( recGroupObj.ID_GROUP,
                        recGroupObj.TYPE_OBJ1,
                        recGroupObj.ID_OBJ1,
                        recGroupObj.TYPE_OBJ2,
                        recGroupObj.ID_OBJ2,
                        recGroupObj.ID_CUST,
                        recGroupObj.UNIQCODE,
                        'T',
                        Schema_RA.GPC_RA.nCurrentUserID
                       );
        else
          update OBJ_GROUP_REL
             set TYPE_OBJ1  = recGroupObj.TYPE_OBJ1,
                 ID_OBJ1    = recGroupObj.ID_OBJ1,
                 TYPE_OBJ2  = recGroupObj.TYPE_OBJ2,
                 ID_OBJ2    = recGroupObj.ID_OBJ2,
                 ID_CUST    = recGroupObj.ID_CUST,
                 UNIQCODE   = recGroupObj.UNIQCODE,
                 STATUS     = recGroupObj.STATUS,
                 CH_OPER    = Schema_RA.GPC_RA.nCurrentUserID
           where ID_GROUP = recGroupObj.ID_GROUP;
        end if;
      else
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ERR';
        aParams( 1 ).ML_VALUE  := to_char( jj );
        Schema_RA.GPC_RA.RespSetErrorText( 'SaveDoc() error: $ERR$', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngEN, aParams );
      end if;
    end if;

    return bRet;
  end SaveGroupObjRel;

  --------------------------------------------------------------------------------
  function GetLoanProduct(
    sPrograma  in varchar2,
    sCredAim   in varchar2,
    sPlanType  in varchar2,
    sFType     in varchar2
  )
    return integer is
    nDummy      integer;
    nIDProduct  integer := 0;

    cursor iqOpen(
      qsPrograma  in varchar2,
      qsCredAim   in varchar2,
      qsPlanType  in varchar2,
      qsFTYPE     in varchar2
    ) is
      select 1 as nLevel,
             ID_PRODUCT
        from GROUP_LOAN_CONF
       where PROGRAMA = qsPrograma and
             CRED_AIM = nvl( qsCredAim, '~' ) and
             PLAN_TYPE = nvl( qsPlanType, '~' ) and
             FTYPE = nvl( qsFType, '~' )
      union all
      select 2 as nLevel,
             ID_PRODUCT
        from GROUP_LOAN_CONF
       where PROGRAMA = qsPrograma and
             CRED_AIM = nvl( qsCredAim, '~' ) and
             PLAN_TYPE = nvl( qsPlanType, '~' ) and
             FTYPE is null
      union all
      select 3 as nLevel,
             ID_PRODUCT
        from GROUP_LOAN_CONF
       where PROGRAMA = qsPrograma and
             CRED_AIM = nvl( qsCredAim, '~' ) and
             PLAN_TYPE is null and
             FTYPE is null
      union all
      select 4 as nLevel,
             ID_PRODUCT
        from GROUP_LOAN_CONF
       where PROGRAMA = qsPrograma and
             CRED_AIM is null and
             PLAN_TYPE is null and
             FTYPE is null;

  begin
    open iqOpen( sPrograma, sCredAim, sPlanType, sFType );

    fetch iqOpen
      into nDummy, nIDProduct;

    if ( not iqOpen%found ) then
      nIDProduct  := 0;
    end if;

    close iqOpen;

    return nvl( nIDProduct, 0 );
  end GetLoanProduct;

  --------------------------------------------------------------------------------
  function ChkMaxDaySum(
    sError    in out varchar2,
    oOpers    in     Schema_GPSys.TblSchOper,
    dSchDate  in     date
  )
    return boolean is
    aParams  Schema_RA.GPC_RA.tblErrParams;
    nDays    integer;
    nOpers   number;
    nLimit   number;
    bRet     boolean := true;
  begin
    if ( not Expo.GetSkipLimit( Expo.ModeSkip_Limit ) ) then
      if ( GetMaxDaySum( 'C' ) > 0 and
          GetMaxDaySum( 'F' ) > 0 and
          ( not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 37 ) ) ) then
        nDays  := Schema_DocSys.DOCSYS.HowWorkDays( GetNar43StartDate, dSchDate );

        if ( nDays > 0 ) then
          for recCust
            in ( select xx.ID_CUST,
                        xx.AMOUNT_SYS,
                        yy.CLITYPE
                   from (  select ID_CUST,
                                  nvl( sum( AMOUNT_SYS ), 0 ) as AMOUNT_SYS
                             from (select /*+ LEADING( a b ) USE_NL( b ) */
                                         b.ID_CUST as ID_CUST,
                                          a.SysAmount as AMOUNT_SYS
                                     from Schema_GPSys.EXPOSITION b,
                                          table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                    where a.OperType not in
                                            ( Cmd_Expo.Sch_ImportOborot,
                                             Cmd_Expo.Sch_Preocenka,
                                             Cmd_Expo.Sch_ClearOborot,
                                             Cmd_Expo.Sch_RegTaxes,
                                             Cmd_Expo.Sch_OperTaxes,
                                             Cmd_Expo.Sch_BiseraTaxes,
                                             Cmd_Expo.Sch_BoricaTaxes,
                                             Cmd_Expo.Sch_ForeignTaxes,
                                             Cmd_Expo.Sch_RegisterTaxes,
                                             Cmd_Expo.Sch_UniStreamTaxes,
                                             Cmd_Expo.Sch_SBCTaxes,
                                             Cmd_Expo.Sch_FreeTaxes,
                                             Cmd_Expo.Sch_TEU_Commision ) and
                                          b.ID_EXPO = a.ExpoDt and
                                          b.ID_CUST > 0 and
                                          exists
                                            (select 1
                                               from Schema_GPSys.CONFSYSTEM_INT g
                                              where g.FLDSECTION = 'EXPOSITION' and
                                                    g.FLDITEM = 'MAXDAYSUM_TYPES' and
                                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%'))
                         group by ID_CUST
                           having nvl( sum( AMOUNT_SYS ), 0 ) > 0) xx,
                        Schema_Cust.CUSTOMS yy
                  where yy.ID = xx.ID_CUST and
                        yy.CLITYPE != 'B' ) loop
            with Expos as
                   (select /*+ inline */
                          x.ID_EXPO
                      from Schema_GPSys.EXPOSITION x
                     where x.ID_CUST = recCust.ID_CUST and
                           x.STATUS = 'T' and
                           exists
                             (select 1
                                from Schema_GPSys.CONFSYSTEM_INT g
                               where g.FLDSECTION = 'EXPOSITION' and
                                     g.FLDITEM = 'MAXDAYSUM_TYPES' and
                                     g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                     g.FLDVALUE like '%&' || to_char( x.TYPE_EXPO ) || '&%'))
            select nvl( sum( SYS_AMOUNT ), 0 )
              into nOpers
              from (select /*+ leading( a b c d ) use_nl( b c d ) */
                          b.SYS_AMOUNT as SYS_AMOUNT
                      from Expos a,
                           EXPO_MOVES b,
                           EXPO_MOVES c,
                           Schema_GPSys.EXPOSITION d
                     where b.ID_EXPO = a.ID_EXPO and
                           b.SCH_DATE between dNar43Start and dSchDate and
                           b.DT_KT = 'D' and
                           b.OPER_TYPE not in
                             ( Cmd_Expo.Sch_ImportOborot,
                              Cmd_Expo.Sch_Preocenka,
                              Cmd_Expo.Sch_ClearOborot,
                              Cmd_Expo.Sch_RegTaxes,
                              Cmd_Expo.Sch_OperTaxes,
                              Cmd_Expo.Sch_BiseraTaxes,
                              Cmd_Expo.Sch_BoricaTaxes,
                              Cmd_Expo.Sch_ForeignTaxes,
                              Cmd_Expo.Sch_RegisterTaxes,
                              Cmd_Expo.Sch_UniStreamTaxes,
                              Cmd_Expo.Sch_SBCTaxes,
                              Cmd_Expo.Sch_FreeTaxes,
                              Cmd_Expo.Sch_TEU_Commision ) and
                           c.ID_MOVE = b.ID_MOVE and
                           c.ORDROWNUM = b.ORDROWNUM and
                           c.DT_KT != b.DT_KT and
                           d.ID_EXPO = c.ID_EXPO and
                           d.ID_CUST != recCust.ID_CUST);

            nLimit  := GetMaxDaySum( recCust.CLITYPE ) * nDays;
            --
            bRet    := ( recCust.AMOUNT_SYS + nOpers ) <= nLimit;

            if ( not bRet ) then
              aParams.delete;

              if ( nvl( Schema_GPSys.OraGPSys.rPreview.bPreview, false ) or
                  Schema_GPSys.OraSys.VerBankTokuda ) then
                aParams( 1 ).ML_NAME   := 'SUMFREE';
                aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( greatest( nLimit - nOpers, 0 ) );
                sError                 := Schema_GPSys.MLng.Str2( 'Надвишенa максимална дневна сума. Разполагаем лимит към днешна дата $SUMFREE$',
                                                                  Schema_GPSys.MLng.ctxPayments,
                                                                  Schema_GPSys.MLng.lngBG,
                                                                  aParams
                                                                 );
              else
                aParams( 1 ).ML_NAME   := 'AMOUNT';
                aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( recCust.AMOUNT_SYS + nOpers );
                aParams( 2 ).ML_NAME   := 'SUMLIMIT';
                aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nLimit );
                aParams( 3 ).ML_NAME   := 'CODVAL';
                aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.SYS_CURR;
                aParams( 4 ).ML_NAME   := 'ID_CUST';
                aParams( 4 ).ML_VALUE  := to_char( recCust.ID_CUST );
                aParams( 5 ).ML_NAME   := 'SUMFREE';
                aParams( 5 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( greatest( nLimit - nOpers, 0 ) );
                sError                 := Schema_GPSys.MLng.Str2( 'Надвишенa максимална дневна сума за клиент $ID_CUST$. Ще се получи $AMOUNT$, при зададен общ лимит от $SUMLIMIT$ $CODVAL$. Разполагаем лимит към днешна дата $SUMFREE$',
                                                                  Schema_GPSys.MLng.ctxPayments,
                                                                  Schema_GPSys.MLng.lngBG,
                                                                  aParams
                                                                 );
              end if;
            end if;

            exit when not bRet;
          end loop;
        end if;
      end if;
    end if;

    return bRet;
  end ChkMaxDaySum;

  --------------------------------------------------------------------------------
  function ChkCustLimits(
    nIDObj    in integer,
    nOperSys  in number
  )
    return boolean is
    aParams  Schema_RA.GPC_RA.tblErrParams;
    nAmount  number := 0;
    nIDCust  integer := nIDObj;
    bRet     boolean := true;
  begin
    if ( not Expo.GetSkipLimit( Expo.ModeSkip_Limit ) ) then
      if ( nvl( nIDObj, 0 ) != 0 ) then
        if ( nIDObj < 0 ) then
          select nvl( min( a.ID_CUST ), 0 )
            into nIDCust
            from Schema_GPSys.EXPOSITION a
           where a.ID_EXPO = -nIDObj and
                 exists
                   (select 1
                      from Schema_GPSys.CONFSYSTEM_INT g
                     where g.FLDSECTION = 'EXPOSITION' and
                           g.FLDITEM = 'CUST_LIMIT_TYPES_P' and
                           g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                           g.FLDVALUE like '%&' || to_char( a.TYPE_EXPO ) || '&%');
        end if;

        if ( nIDCust > 0 ) then
          for recLimit in ( select *
                              from Schema_GPSys.TECHNO_LIMITS
                             where TYPE_LIMIT = Schema_GPSys.Cmd_OraGPSys.nTypeLimitAgrContr and
                                   TYPE_TECHNOL = Schema_GPSys.Cmd_OraGPSys.nTypeTechMaxBalance and
                                   ID_OBJECT = nIDCust and
                                   STATUS = 'T' and
                                   nvl( AMOUNT, 0 ) > 0 ) loop
            select /*+ LEADING( a b ) USE_NL( b ) */
                  nvl( sum( b.SYS_OBOR_KT - b.SYS_OBOR_DT ), 0 ) + nOperSys
              into nAmount
              from EXPO_STATE b,
                   Schema_GPSys.EXPOSITION a
             where a.ID_CUST = nIDCust and
                   a.STATUS = 'T' and
                   b.ID_EXPO = a.ID_EXPO and
                   exists
                     (select 1
                        from Schema_GPSys.CONFSYSTEM_INT g
                       where g.FLDSECTION = 'EXPOSITION' and
                             g.FLDITEM = 'CUST_LIMIT_TYPES_P' and
                             g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                             g.FLDVALUE like '%&' || to_char( a.TYPE_EXPO ) || '&%');

            nAmount      := Schema_GPSys.XchgRates.GetExactSum( nAmount,
                                                                null,
                                                                Schema_RA.GPC_Tools.GetSchDate( null ),
                                                                Schema_GPSys.OraGPSys.SYS_CURR,
                                                                recLimit.CODVAL,
                                                                Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                               );
            --
            bRet         := nAmount <= recLimit.AMOUNT;

            if ( not bRet ) then
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'ID_LIMIT';
              aParams( 1 ).ML_VALUE  := to_char( recLimit.ID_LIMIT );
              aParams( 2 ).ML_NAME   := 'AMOUNT';
              aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmount );
              aParams( 3 ).ML_NAME   := 'SUMLIMIT';
              aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( recLimit.AMOUNT );
              aParams( 4 ).ML_NAME   := 'CODVAL';
              aParams( 4 ).ML_VALUE  := recLimit.CODVAL;
              Schema_RA.GPC_RA.RespSetErrorText( 'Надвишен лимит по салдо, с номер: $ID_LIMIT$. Ще се получи $AMOUNT$, при зададен лимит от $SUMLIMIT$ $CODVAL$',
                                                 Schema_GPSys.MLng.ctxPayments,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;

            exit when not bRet;
          end loop;
        end if;
      end if;
    end if;

    return bRet;
  end ChkCustLimits;

  --------------------------------------------------------------------------------
  function ChkCustLimits(
    sError  in out varchar2,
    oOpers  in     Schema_GPSys.TblSchOper
  )
    return boolean is
    bRet  boolean := true;
  begin
    for recCust in (  select ID_CUST,
                             nvl( sum( AMOUNT_SYS ), 0 ) as AMOUNT_SYS
                        from (select /*+ LEADING( a b ) USE_NL( b ) */
                                    b.ID_CUST as ID_CUST,
                                     -a.SysAmount as AMOUNT_SYS
                                from Schema_GPSys.EXPOSITION b,
                                     table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                               where a.OperType not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot) and
                                     b.ID_EXPO = a.ExpoDt and
                                     b.ID_CUST > 0 and
                                     exists
                                       (select 1
                                          from Schema_GPSys.CONFSYSTEM_INT g
                                         where g.FLDSECTION = 'EXPOSITION' and
                                               g.FLDITEM = 'CUST_LIMIT_TYPES_P' and
                                               g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                               g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%')
                              union all
                              select /*+ LEADING( a b ) USE_NL( b ) */
                                    b.ID_CUST as ID_CUST,
                                     a.SysAmount as AMOUNT_SYS
                                from Schema_GPSys.EXPOSITION b,
                                     table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                               where a.OperType not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot) and
                                     b.ID_EXPO = a.ExpoKt and
                                     b.ID_CUST > 0 and
                                     exists
                                       (select 1
                                          from Schema_GPSys.CONFSYSTEM_INT g
                                         where g.FLDSECTION = 'EXPOSITION' and
                                               g.FLDITEM = 'CUST_LIMIT_TYPES_P' and
                                               g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                               g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%'))
                    group by ID_CUST
                      having nvl( sum( AMOUNT_SYS ), 0 ) > 0 ) loop
      bRet  := ChkCustLimits( recCust.ID_CUST, recCust.AMOUNT_SYS );
      --
      exit when not bRet;
    end loop;

    if ( not bRet ) then
      sError  := Schema_RA.GPC_RA.RespGetErrorText;
    end if;

    return bRet;
  end ChkCustLimits;

  --------------------------------------------------------------------------------
  function ChkGroupLimits(
    nIDExpo    in     integer,
    nIDCust    in     integer,
    nTypeExpo  in     integer,
    sCodVal    in     varchar2,
    dSchDate   in     date,
    nTransac   in     number,
    sError     in out varchar2
  )
    return boolean is
    recLimit  GROUP_LIMITS%rowtype;
    ii        integer;
    nOperSys  number := 0;
    bRet      boolean := true;
    aParams   Schema_RA.GPC_RA.tblErrParams;
  begin
    select count( 1 )
      into ii
      from Schema_GPSys.CONFSYSTEM_INT g
     where g.FLDSECTION = 'EXPOSITION' and
           g.FLDITEM = 'GROUP_LIMIT_TYPES_A' and
           g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
           g.FLDVALUE like '%&' || to_char( nTypeExpo ) || '&%';

    if ( ii > 0 ) then
      nOperSys  := -nTransac;
    else
      select count( 1 )
        into ii
        from Schema_GPSys.CONFSYSTEM_INT g
       where g.FLDSECTION = 'EXPOSITION' and
             g.FLDITEM = 'GROUP_LIMIT_TYPES_P' and
             g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
             g.FLDVALUE like '%&' || to_char( nTypeExpo ) || '&%';

      if ( ii > 0 ) then
        nOperSys  := nTransac;
      end if;
    end if;

    if ( nOperSys > 0 ) then
      begin
        select h.*
          into recLimit
          from GROUP_LIMITS h
         where h.ID_GROUP = (select nvl( min( b.ID_GROUP ), 0 )
                               from Schema_Cust.CUST_GROUPS b,
                                    Schema_Cust.CUST_GROUP_MEMBERS a
                              where a.ID_CUST = nIDCust and
                                    b.ID_GROUP = a.ID_GROUP and
                                    b.STATUS = 'T') and
               h.STATUS in ('F', 'T');

        bRet  := dSchDate between nvl( recLimit.BEG_DATE, dSchDate ) and nvl( recLimit.END_DATE, dSchDate );

        if ( bRet ) then
          bRet  := recLimit.STATUS = 'T';

          if ( not bRet ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_LIMIT';
            aParams( 1 ).ML_VALUE  := to_char( recLimit.ID_LIMIT );
            sError                 := Schema_GPSys.MLng.Str2( 'Нe е активиран лимит: $ID_LIMIT$', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG, aParams );
          end if;
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ID_LIMIT';
          aParams( 1 ).ML_VALUE  := to_char( recLimit.ID_LIMIT );
          sError                 := Schema_GPSys.MLng.Str2( 'Нарушена валидност за лимит: $ID_LIMIT$', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG, aParams );
        end if;

        if ( bRet ) then
          recLimit.BEG_DATE  := nvl( recLimit.BEG_DATE, dSchDate );
          recLimit.END_DATE  := nvl( recLimit.END_DATE, dSchDate );
        else
          recLimit.ID_GROUP  := 0;
          bRet               := not Schema_GPSys.OraSys.VerBankUnion and
                                not Schema_GPSys.OraSys.VerBankDBank;
        end if;
      exception
        when no_data_found then
          recLimit.ID_GROUP  := 0;
      end;

      if ( nvl( recLimit.ID_GROUP, 0 ) > 0 ) then
        if ( sCodVal != Schema_GPSys.OraGPSys.SYS_CURR ) then
          nOperSys  := Schema_GPSys.XchgRates.Conv2SysCurr( nOperSys, sCodVal, dSchDate );
        end if;

        bRet  := ApplyGroupLimits( nIDExpo, nIDCust, recLimit, nOperSys, sError );
      end if;
    end if;

    return bRet;
  end ChkGroupLimits;

  --------------------------------------------------------------------------------
  function ApplyGroupLimits(
    nIDExpo   in     integer,
    nIDCust   in     integer,
    recLimit  in     GROUP_LIMITS%rowtype,
    nOperSys  in     number,
    sError    in out varchar2
  )
    return boolean is
    rCustData   Schema_Cust.GPC_Customs.recCustData;
    sData       varchar2( 4000 );
    nAmountSys  number := 0;
    nAmountOpr  number := 0;
    bSubLimit1  boolean := false;
    bSubLimit2  boolean := false;
    bRet        boolean := true;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    select /*+ LEADING( a b c ) USE_NL( b c ) */
          nvl( sum( abs( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) ), 0 ) + nOperSys
      into nAmountSys
      from EXPO_STATE c,
           Schema_GPSys.EXPOSITION b,
           Schema_Cust.CUST_GROUP_MEMBERS a
     where a.ID_GROUP = recLimit.ID_GROUP and
           b.ID_CUST = a.ID_CUST and
           b.STATUS = 'T' and
           c.ID_EXPO = b.ID_EXPO and
           ( ( exists
                (select 1
                   from Schema_GPSys.CONFSYSTEM_INT g
                  where g.FLDSECTION = 'EXPOSITION' and
                        g.FLDITEM = 'GROUP_LIMIT_TYPES_A' and
                        g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                        g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
              ( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) > 0 ) or
            ( exists
               (select 1
                  from Schema_GPSys.CONFSYSTEM_INT g
                 where g.FLDSECTION = 'EXPOSITION' and
                       g.FLDITEM = 'GROUP_LIMIT_TYPES_P' and
                       g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                       g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
             ( c.SYS_OBOR_KT - c.SYS_OBOR_DT ) > 0 ) );

    if ( nIDCust = -1 ) then
      Schema_GPSys.GPC_Parser.RespAddArray( 1 );
      bRet      := Schema_GPSys.GPC_Parser.WriteInteger( recLimit.ID_LIMIT, sData ) and
                   Schema_GPSys.GPC_Parser.WriteInteger( recLimit.ID_GROUP, sData ) and
                   Schema_GPSys.GPC_Parser.WriteDate( recLimit.BEG_DATE, sData ) and
                   Schema_GPSys.GPC_Parser.WriteDate( recLimit.END_DATE, sData ) and
                   Schema_GPSys.GPC_Parser.WriteAmount( recLimit.SUMLIMIT, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( recLimit.STATUS, sData ) and
                   Schema_GPSys.GPC_Parser.WriteInteger( recLimit.APPROVED_BY, sData ) and
                   Schema_GPSys.GPC_Parser.WriteInteger( recLimit.CH_OPER, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( recLimit.CONFIRM_LVL, sData ) and
                   Schema_GPSys.GPC_Parser.WriteNumber( nAmountSys, sData ) and
                   true;

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddRow( sData );
      end if;

      Schema_GPSys.GPC_Parser.RespAddArray( 2 );
    else
      if ( nvl( recLimit.SUMLIMIT, 0 ) > 0 ) then
        bRet  := nAmountSys <= recLimit.SUMLIMIT;

        if ( not bRet ) then
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ID_LIMIT';
          aParams( 1 ).ML_VALUE  := to_char( recLimit.ID_LIMIT );
          aParams( 2 ).ML_NAME   := 'SYS_AMOUNT';
          aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmountSys );
          aParams( 3 ).ML_NAME   := 'SUMLIMIT';
          aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( recLimit.SUMLIMIT );
          sError                 := Schema_GPSys.MLng.Str2( 'Нарушен общ лимит: $ID_LIMIT$ Ще се получи $SYS_AMOUNT$, при зададен лимит от $SUMLIMIT$',
                                                            Schema_GPSys.MLng.ctxPayments,
                                                            Schema_GPSys.MLng.lngBG,
                                                            aParams
                                                           );
        end if;
      end if;
    end if;

    if ( bRet ) then
      for recSubLimit in ( select *
                             from GROUP_SUBLIMITS
                            where ID_LIMIT = recLimit.ID_LIMIT and
                                  ( nIDCust = -1 or
                                   ( nvl( ID_CUST, 0 ) in (0, nIDCust) and
                                    nvl( SUMLIMIT, 0 ) > 0 and
                                    ( nvl( ID_CUST, 0 ) > 0 or
                                     nvl( TERM_LIMIT, 0 ) > 0 or
                                     nvl( PRODUCT_LIMIT, 0 ) > 0 ) ) ) ) loop
        nAmountSys                 := 0;
        nAmountOpr                 := 0;
        recSubLimit.ID_CUST        := nvl( recSubLimit.ID_CUST, 0 );
        recSubLimit.TERM_LIMIT     := nvl( recSubLimit.TERM_LIMIT, 0 );
        recSubLimit.PRODUCT_LIMIT  := nvl( recSubLimit.PRODUCT_LIMIT, 0 );

        if ( recSubLimit.ID_CUST > 0 and
            recSubLimit.TERM_LIMIT = 0 and
            recSubLimit.PRODUCT_LIMIT = 0 ) then
          select /*+ LEADING( b c ) USE_NL( c ) */
                nvl( sum( abs( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) ), 0 ) + nOperSys,
                 nOperSys
            into nAmountSys,
                 nAmountOpr
            from EXPO_STATE c,
                 Schema_GPSys.EXPOSITION b
           where b.ID_CUST = recSubLimit.ID_CUST and
                 b.STATUS = 'T' and
                 c.ID_EXPO = b.ID_EXPO and
                 ( ( exists
                      (select 1
                         from Schema_GPSys.CONFSYSTEM_INT g
                        where g.FLDSECTION = 'EXPOSITION' and
                              g.FLDITEM = 'GROUP_LIMIT_TYPES_A' and
                              g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                              g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                    ( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) > 0 ) or
                  ( exists
                     (select 1
                        from Schema_GPSys.CONFSYSTEM_INT g
                       where g.FLDSECTION = 'EXPOSITION' and
                             g.FLDITEM = 'GROUP_LIMIT_TYPES_P' and
                             g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                             g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                   ( c.SYS_OBOR_KT - c.SYS_OBOR_DT ) > 0 ) );
        else
          select nvl( sum( AMOUNT ), 0 ),
                 nvl( sum( OPERSUM ), 0 )
            into nAmountSys,
                 nAmountOpr
            from (select /*+ LEADING( a b c d ) USE_NL( b c d ) */
                        nvl( sum( abs( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) ), 0 ) as AMOUNT,
                         0 as OPERSUM
                    from LOAN_EXPOSITION d,
                         EXPO_STATE c,
                         Schema_GPSys.EXPOSITION b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT = TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.STATUS = 'T' and
                         c.ID_EXPO = b.ID_EXPO and
                         ( ( exists
                              (select 1
                                 from Schema_GPSys.CONFSYSTEM_INT g
                                where g.FLDSECTION = 'EXPOSITION' and
                                      g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                  case recSubLimit.PRODUCT_LIMIT
                                                    when 0 then ''
                                                    else to_char( recSubLimit.PRODUCT_LIMIT )
                                                  end and
                                      g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                      g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                            ( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) > 0 ) or
                          ( exists
                             (select 1
                                from Schema_GPSys.CONFSYSTEM_INT g
                               where g.FLDSECTION = 'EXPOSITION' and
                                     g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                 case recSubLimit.PRODUCT_LIMIT
                                                   when 0 then ''
                                                   else to_char( recSubLimit.PRODUCT_LIMIT )
                                                 end and
                                     g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                     g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                           ( c.SYS_OBOR_KT - c.SYS_OBOR_DT ) > 0 ) ) and
                         d.ID_EXPO(+) = b.ID_EXPO and
                         nvl( d.TYPE_CRED_EXPO, 0 ) not in
                           ( Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_ProsrochenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_SudebnDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_PriznatDulg )
                  union all
                  select nvl( sum( abs( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) ), 0 ) as AMOUNT,
                         0 as OPERSUM
                    from /*+ LEADING( a b c d e f ) USE_NL( b c d e f ) */
                        Schema_Cust.CUSTOMS f,
                         LOAN_CREDIT e,
                         LOAN_EXPOSITION d,
                         EXPO_STATE c,
                         Schema_GPSys.EXPOSITION b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.STATUS = 'T' and
                         c.ID_EXPO = b.ID_EXPO and
                         ( ( exists
                              (select 1
                                 from Schema_GPSys.CONFSYSTEM_INT g
                                where g.FLDSECTION = 'EXPOSITION' and
                                      g.FLDITEM = 'GROUP_LIMIT_TYPES_A' and
                                      g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                      g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                            ( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) > 0 ) or
                          ( exists
                             (select 1
                                from Schema_GPSys.CONFSYSTEM_INT g
                               where g.FLDSECTION = 'EXPOSITION' and
                                     g.FLDITEM = 'GROUP_LIMIT_TYPES_P' and
                                     g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                     g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                           ( c.SYS_OBOR_KT - c.SYS_OBOR_DT ) > 0 ) ) and
                         d.ID_EXPO = b.ID_EXPO and
                         d.TYPE_CRED_EXPO in
                           ( Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_ProsrochenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_SudebnDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_PriznatDulg ) and
                         e.ID_CRED_ENGAGE = d.ID_CRED_ENGAGE and
                         ( recSubLimit.PRODUCT_LIMIT = 0 or
                          GetLoanProduct( e.PROGRAMA, e.CRED_AIM, e.PLAN_TYPE, f.FTYPE ) = recSubLimit.PRODUCT_LIMIT ) and
                         ( recSubLimit.TERM_LIMIT = TermLimit_Default or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) > 60 ) ) and
                         f.ID = b.ID_CUST
                  union all
                  select /*+ LEADING( a b c d e ) USE_NL( b c d e ) */
                        nvl( sum( abs( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) ), 0 ) as AMOUNT,
                         0 as OPERSUM
                    from LOAN_ENGAGE e,
                         LOAN_EXPOSITION d,
                         EXPO_STATE c,
                         Schema_GPSys.EXPOSITION b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT != TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.STATUS = 'T' and
                         c.ID_EXPO = b.ID_EXPO and
                         ( ( exists
                              (select 1
                                 from Schema_GPSys.CONFSYSTEM_INT g
                                where g.FLDSECTION = 'EXPOSITION' and
                                      g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                  case recSubLimit.PRODUCT_LIMIT
                                                    when 0 then ''
                                                    else to_char( recSubLimit.PRODUCT_LIMIT )
                                                  end and
                                      g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                      g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                            ( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) > 0 ) or
                          ( exists
                             (select 1
                                from Schema_GPSys.CONFSYSTEM_INT g
                               where g.FLDSECTION = 'EXPOSITION' and
                                     g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                 case recSubLimit.PRODUCT_LIMIT
                                                   when 0 then ''
                                                   else to_char( recSubLimit.PRODUCT_LIMIT )
                                                 end and
                                     g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                     g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                           ( c.SYS_OBOR_KT - c.SYS_OBOR_DT ) > 0 ) ) and
                         d.ID_EXPO = b.ID_EXPO and
                         e.ID_CRED_ENGAGE = d.ID_CRED_ENGAGE and
                         ( ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                            months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) > 60 ) )
                  union all
                  select /*+ LEADING( a b c e ) USE_NL( b c e ) */
                        nvl( sum( abs( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) ), 0 ) as AMOUNT,
                         0 as OPERSUM
                    from LOAN_MKU e,
                         EXPO_STATE c,
                         OTHER_EXPO b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT != TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.STATUS = 'T' and
                         c.ID_EXPO = b.ID_EXPO and
                         ( ( exists
                              (select 1
                                 from Schema_GPSys.CONFSYSTEM_INT g
                                where g.FLDSECTION = 'EXPOSITION' and
                                      g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                  case recSubLimit.PRODUCT_LIMIT
                                                    when 0 then ''
                                                    else to_char( recSubLimit.PRODUCT_LIMIT )
                                                  end and
                                      g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                      g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                            ( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) > 0 ) or
                          ( exists
                             (select 1
                                from Schema_GPSys.CONFSYSTEM_INT g
                               where g.FLDSECTION = 'EXPOSITION' and
                                     g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                 case recSubLimit.PRODUCT_LIMIT
                                                   when 0 then ''
                                                   else to_char( recSubLimit.PRODUCT_LIMIT )
                                                 end and
                                     g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                     g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                           ( c.SYS_OBOR_KT - c.SYS_OBOR_DT ) > 0 ) ) and
                         e.ID_CUST = b.ID_CUST and
                         b.ID_EXPO in (e.ID_EXPO, e.ID_EXPO1, e.ID_EXPO2, e.ID_EXPO3) and
                         ( ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                            months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, b.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, b.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, b.OPEN_DATE ) ) > 60 ) )
                  $if (Schema_GPSys.OraSys.bModule_Payments ) $then
                  union all
                  select /*+ LEADING( a b c e ) USE_NL( b c e ) */
                        nvl( sum( abs( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) ), 0 ) as AMOUNT,
                         0 as OPERSUM
                    from Schema_Payments.GUARANTEE e,
                         EXPO_STATE c,
                         OTHER_EXPO b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT != TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.STATUS = 'T' and
                         c.ID_EXPO = b.ID_EXPO and
                         ( ( exists
                              (select 1
                                 from Schema_GPSys.CONFSYSTEM_INT g
                                where g.FLDSECTION = 'EXPOSITION' and
                                      g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                  case recSubLimit.PRODUCT_LIMIT
                                                    when 0 then ''
                                                    else to_char( recSubLimit.PRODUCT_LIMIT )
                                                  end and
                                      g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                      g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                            ( c.SYS_OBOR_DT - c.SYS_OBOR_KT ) > 0 ) or
                          ( exists
                             (select 1
                                from Schema_GPSys.CONFSYSTEM_INT g
                               where g.FLDSECTION = 'EXPOSITION' and
                                     g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                 case recSubLimit.PRODUCT_LIMIT
                                                   when 0 then ''
                                                   else to_char( recSubLimit.PRODUCT_LIMIT )
                                                 end and
                                     g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                     g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') and
                           ( c.SYS_OBOR_KT - c.SYS_OBOR_DT ) > 0 ) ) and
                         e.ID_CUST = b.ID_CUST and
                         e.GUARANTEE_EXPO = b.ID_EXPO and
                         ( ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                            months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) > 60 ) )
                  $end
                  union all
                  select /*+ LEADING( a b d ) USE_NL( b d ) */
                        nOperSys as AMOUNT,
                         nOperSys as OPERSUM
                    from LOAN_EXPOSITION d,
                         Schema_GPSys.EXPOSITION b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT = TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.ID_EXPO = nIDExpo and
                         ( exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') or
                          exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') ) and
                         d.ID_EXPO(+) = b.ID_EXPO and
                         nvl( d.TYPE_CRED_EXPO, 0 ) not in
                           ( Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_ProsrochenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_SudebnDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_PriznatDulg )
                  union all
                  select /*+ LEADING( a b d e f ) USE_NL( b d e f ) */
                        nOperSys as AMOUNT,
                         nOperSys as OPERSUM
                    from Schema_Cust.CUSTOMS f,
                         LOAN_CREDIT e,
                         LOAN_EXPOSITION d,
                         Schema_GPSys.EXPOSITION b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.ID_EXPO = nIDExpo and
                         d.ID_EXPO = b.ID_EXPO and
                         d.TYPE_CRED_EXPO in
                           ( Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_ProsrochenDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_SudebnDulg,
                            Schema_GPSys.HeadExpo.ExpoCred_PriznatDulg ) and
                         e.ID_CRED_ENGAGE = d.ID_CRED_ENGAGE and
                         ( recSubLimit.PRODUCT_LIMIT = 0 or
                          GetLoanProduct( e.PROGRAMA, e.CRED_AIM, e.PLAN_TYPE, f.FTYPE ) = recSubLimit.PRODUCT_LIMIT ) and
                         ( recSubLimit.TERM_LIMIT = TermLimit_Default or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) > 60 ) ) and
                         f.ID = b.ID_CUST
                  union all
                  select /*+ LEADING( a b d e ) USE_NL( b d e ) */
                        nOperSys as AMOUNT,
                         nOperSys as OPERSUM
                    from LOAN_ENGAGE e,
                         LOAN_EXPOSITION d,
                         Schema_GPSys.EXPOSITION b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT != TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.ID_EXPO = nIDExpo and
                         ( exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') or
                          exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') ) and
                         d.ID_EXPO = b.ID_EXPO and
                         e.ID_CRED_ENGAGE = d.ID_CRED_ENGAGE and
                         ( ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                            months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) > 60 ) )
                  union all
                  select /*+ LEADING( a b e ) USE_NL( b e ) */
                        nOperSys as AMOUNT,
                         nOperSys as OPERSUM
                    from LOAN_MKU e,
                         OTHER_EXPO b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT != TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.ID_EXPO = nIDExpo and
                         ( exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') or
                          exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') ) and
                         e.ID_CUST = b.ID_CUST and
                         b.ID_EXPO in (e.ID_EXPO, e.ID_EXPO1, e.ID_EXPO2, e.ID_EXPO3) and
                         ( ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                            months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, b.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, b.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, b.OPEN_DATE ) ) > 60 ) )
                  $if (Schema_GPSys.OraSys.bModule_Payments ) $then
                  union all
                  select /*+ LEADING( a b e ) USE_NL( b e ) */
                        nOperSys as AMOUNT,
                         nOperSys as OPERSUM
                    from Schema_Payments.GUARANTEE e,
                         OTHER_EXPO b,
                         Schema_Cust.CUST_GROUP_MEMBERS a
                   where recSubLimit.TERM_LIMIT != TermLimit_Default and
                         a.ID_GROUP = recLimit.ID_GROUP and
                         ( recSubLimit.ID_CUST = 0 or
                          a.ID_CUST = recSubLimit.ID_CUST ) and
                         b.ID_CUST = a.ID_CUST and
                         b.ID_EXPO = nIDExpo and
                         ( exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_A' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') or
                          exists
                            (select 1
                               from Schema_GPSys.CONFSYSTEM_INT g
                              where g.FLDSECTION = 'EXPOSITION' and
                                    g.FLDITEM = 'GROUP_LIMIT_TYPES_P' ||
                                                case recSubLimit.PRODUCT_LIMIT
                                                  when 0 then ''
                                                  else to_char( recSubLimit.PRODUCT_LIMIT )
                                                end and
                                    g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                    g.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%') ) and
                         e.ID_CUST = b.ID_CUST and
                         e.GUARANTEE_EXPO = b.ID_EXPO and
                         ( ( recSubLimit.TERM_LIMIT = TermLimit_Short and
                            months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) <= 12 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Medium and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) between 12.01 and 60 ) or
                          ( recSubLimit.TERM_LIMIT = TermLimit_Long and
                           months_between( e.EXP_DATE, greatest( recLimit.BEG_DATE, e.OPEN_DATE ) ) > 60 ) )  $end
                                                                                                            );
        end if;

        if ( nIDCust = -1 ) then
          if ( recSubLimit.ID_CUST > 0 ) then
            rCustData.IDCust  := recSubLimit.ID_CUST;
            bRet              := Schema_Cust.GPC_Customs.GetCustData( rCustData );
          else
            rCustData  := null;
          end if;

          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( recSubLimit.ID_LIMIT, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( recSubLimit.ID_CUST, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( recSubLimit.TERM_LIMIT, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( recSubLimit.PRODUCT_LIMIT, sData ) and
                       Schema_GPSys.GPC_Parser.WriteNumber( recSubLimit.SUMLIMIT, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.Custname, sData ) and
                       Schema_GPSys.GPC_Parser.WriteNumber( nAmountSys, sData ) and
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;
        else
          if ( Schema_GPSys.OraSys.VerBankUnion or
              Schema_GPSys.OraSys.VerBankDBank ) then
            bRet      := recSubLimit.ID_CUST > 0 and
                         recSubLimit.TERM_LIMIT > 0 and
                         recSubLimit.PRODUCT_LIMIT > 0;

            if ( bRet ) then
              bSubLimit1      := true;
              bSubLimit2      := bSubLimit2 or
                                 nAmountOpr != 0;
            end if;
          end if;

          if ( bRet ) then
            bRet      := nAmountOpr = 0 or
                         nAmountSys <= recSubLimit.SUMLIMIT;

            if ( not bRet ) then
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'ID_LIMIT';
              aParams( 1 ).ML_VALUE  := to_char( recSubLimit.ID_LIMIT );
              aParams( 2 ).ML_NAME   := 'ID_CUST';
              aParams( 2 ).ML_VALUE  := to_char( recSubLimit.ID_CUST );
              aParams( 3 ).ML_NAME   := 'TERM_LIMIT';
              aParams( 3 ).ML_VALUE  := to_char( recSubLimit.TERM_LIMIT );
              aParams( 4 ).ML_NAME   := 'PRODUCT_LIMIT';
              aParams( 4 ).ML_VALUE  := to_char( recSubLimit.PRODUCT_LIMIT );
              aParams( 5 ).ML_NAME   := 'SYS_AMOUNT';
              aParams( 5 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmountSys );
              aParams( 6 ).ML_NAME   := 'SUMLIMIT';
              aParams( 6 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( recSubLimit.SUMLIMIT );
              sError                 := Schema_GPSys.MLng.Str2( 'Нарушен под-лимит: $ID_LIMIT$ клиент: $ID_CUST$ срок: $TERM_LIMIT$ продукт: $PRODUCT_LIMIT$ Ще се получи $SYS_AMOUNT$, при зададен лимит от $SUMLIMIT$',
                                                                Schema_GPSys.MLng.ctxPayments,
                                                                Schema_GPSys.MLng.lngBG,
                                                                aParams
                                                               );
            end if;
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_LIMIT';
            aParams( 1 ).ML_VALUE  := to_char( recSubLimit.ID_LIMIT );
            aParams( 2 ).ML_NAME   := 'ID_CUST';
            aParams( 2 ).ML_VALUE  := to_char( recSubLimit.ID_CUST );
            aParams( 3 ).ML_NAME   := 'TERM_LIMIT';
            aParams( 3 ).ML_VALUE  := to_char( recSubLimit.TERM_LIMIT );
            aParams( 4 ).ML_NAME   := 'PRODUCT_LIMIT';
            aParams( 4 ).ML_VALUE  := to_char( recSubLimit.PRODUCT_LIMIT );
            sError                 := Schema_GPSys.MLng.Str2( 'Непълно дефиниран под-лимит: $ID_LIMIT$ клиент: $ID_CUST$ срок: $TERM_LIMIT$ продукт: $PRODUCT_LIMIT$',
                                                              Schema_GPSys.MLng.ctxPayments,
                                                              Schema_GPSys.MLng.lngBG,
                                                              aParams
                                                             );
          end if;
        end if;

        exit when not bRet;
      end loop;

      if ( bRet and
          nIDCust != -1 and
          ( Schema_GPSys.OraSys.VerBankUnion or
           Schema_GPSys.OraSys.VerBankDBank ) ) then
        bRet      := bSubLimit1 and
                     bSubLimit2;

        if ( not bRet ) then
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ID_LIMIT';
          aParams( 1 ).ML_VALUE  := to_char( recLimit.ID_LIMIT );
          aParams( 2 ).ML_NAME   := 'ID_CUST';
          aParams( 2 ).ML_VALUE  := to_char( nIDCust );
          sError                 := Schema_GPSys.MLng.Str2( 'Не е дефиниран съответен под-лимит към лимит: $ID_LIMIT$ клиент: $ID_CUST$',
                                                            Schema_GPSys.MLng.ctxPayments,
                                                            Schema_GPSys.MLng.lngBG,
                                                            aParams
                                                           );
        end if;
      end if;
    end if;

    return bRet;
  end ApplyGroupLimits;

  --------------------------------------------------------------------------------
  function ChkSaldo(
    aExpo           in            Schema_GPSys.OraGPSys.aNumbers,
    aIDCust         in            Schema_GPSys.OraGPSys.aNumbers,
    aTypeExpo       in            Schema_GPSys.OraGPSys.aNumbers,
    aCodVal         in            Schema_GPSys.OraGPSys.aStrings,
    aStatus         in            Schema_GPSys.OraGPSys.aStrings,
    aActPass        in            Schema_GPSys.OraGPSys.aStrings,
    aBaseType       in            Schema_GPSys.OraGPSys.aNumbers,
    aOpenDate       in            Schema_GPSys.OraGPSys.aDates,
    oOpers          in            Schema_GPSys.TblSchOper,
    SchDate         in            date,
    dSysDate        in            date,
    IDOldMove       in            integer,
    aClosedExpo     in            Schema_GPSys.OraGPSys.aNumbers,
    aCashHead       in out nocopy Schema_GPSys.OraGPSys.aNumbers,
    aCashRows       in out nocopy taCashRows,
    aCashExpos      in out nocopy Schema_GPSys.Tbl2Int,
    aCredExpo       in out nocopy taCredExpo,
    aDifSaldo       in out nocopy Schema_GPSys.OraGPSys.aNumbers,
    sError          in out        varchar2,
    bOvercomeLimit  in            boolean
  )
    return boolean is
    pragma autonomous_transaction;
    nExpoBdg       integer;
    nSkipMode      integer;
    nCount         integer;
    nIDCash        integer;
    nOldSaldo      number;
    nSaldo         number;
    nSaldoBdg      number;
    nDifSaldo      number;
    nAmount        number;
    nAmountBdg     number;
    nObor          number;
    nDummy         number;
    dValior        date;
    dOpenDate      date;
    dFrDate        date;
    dToDate        date;
    bLimits        boolean;
    bChkOldValior  boolean;
    bSkipChk       boolean;
    bCredExpo      boolean;
    bRet           boolean := true;
    aParams        Schema_RA.GPC_RA.tblErrParams;

    cursor qExpoMoves(
      nExpo     in integer,
      nRelExpo  in integer,
      dVlr      in date
    ) is
        select sum( Amn ),
               sum( AmnBdg ),
               Valior
          from ((  select sum( decode( DT_KT, 'D', Amount, -Amount ) ) as Amn,
                          0 as AmnBdg,
                          Valior
                     from EXPO_MOVES
                    where ID_EXPO = nExpo and
                          VALIOR > dVlr and
                          AMOUNT != 0
                 group by Valior )
                union all
                (  select 0 as Amn,
                          sum( decode( DT_KT, 'D', Amount, -Amount ) ) as AmnBdg,
                          Valior
                     from EXPO_MOVES
                    where ID_EXPO = nRelExpo and
                          VALIOR > dVlr and
                          AMOUNT != 0
                 group by Valior )
                union all
                ( select 0 as Amn,
                         0 as AmnBdg,
                         dVlr
                    from dual )
                union all
                ( select 0 as Amn,
                         0 as AmnBdg,
                         to_date( '01.01.3000', 'dd.mm.yyyy' )
                    from dual )
                union all
                (  select sum( decode( a.ExpoDt, nExpo, a.AmountDt, 0 ) - decode( a.ExpoKt, nExpo, a.AmountKt, 0 ) ) as Amn,
                          0 as AmnBdg,
                          a.Valior
                     from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                    where a.Valior > dVlr and
                          nExpo in (a.ExpoDt, a.ExpoKt)
                 group by a.Valior )
                union all
                (  select 0 as Amn,
                          sum( decode( a.ExpoDt, nRelExpo, a.AmountDt, 0 ) - decode( a.ExpoKt, nRelExpo, a.AmountKt, 0 ) ) as AmnBdg,
                          a.Valior
                     from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                    where a.Valior > dVlr and
                          nRelExpo in (a.ExpoDt, a.ExpoKt)
                 group by a.Valior )
                order by 3 desc)
      group by Valior
      order by Valior desc;

    cursor qLimit1(
      nExpo  in integer,
      nEBdg  in integer,
      dVlr   in date,
      dSch   in date
    ) is
      select *
        from EXPO_LIMITS
       where ID_EXPO = nExpo and
             ( BEG_DATE is null or
              ( BEG_DATE <= dVlr and
               ( dSch is null or
                BEG_DATE <= dSch ) ) ) and
             ( END_DATE is null or
              dVlr <= END_DATE ) and
             STATUS = ZaporStat_Active and
             FULL_LIMIT = 'F'
      union all
      select *
        from EXPO_LIMITS
       where ID_EXPO = nEBdg and
             ( BEG_DATE is null or
              ( BEG_DATE <= dVlr and
               ( dSch is null or
                BEG_DATE <= dSch ) ) ) and
             ( END_DATE is null or
              dVlr <= END_DATE ) and
             STATUS = ZaporStat_Active and
             FULL_LIMIT = 'F';

    cursor qLimit2( nExpo in integer ) is
      select *
        from EXPO_LIM_OBOR
       where ID_EXPO = nExpo and
             LIM_MODE in ('D', 'M', 'Y');

  begin
    set transaction read only;
    bChkOldValior  := Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'CHK_OLD_VALIOR', 'T' ) );

    -- проверка на операциите по салда
    for ii in aExpo.first .. aExpo.last loop
      bRet      := ( aStatus( ii ) = 'T' or
                    Schema_GPSys.OraGPSys.SearchNumberInArray( aClosedExpo, aExpo( ii ) ) );

      if ( bRet ) then
        nExpoBdg   := Budgetexpo.GetBdgRelExpo( aExpo( ii ) );

        -- текущо салдо
        select sum( Amn ),
               sum( AmnBdg )
          into nSaldo,
               nSaldoBdg
          from (select OBOR_KT - OBOR_DT as Amn,
                       0 as AmnBdg
                  from EXPO_STATE
                 where ID_EXPO = aExpo( ii )
                union all
                select sum( decode( DT_KT, 'D', -AMOUNT, AMOUNT ) ) as Amn,
                       0 as AmnBdg
                  from EXPO_MOVES
                 where ID_EXPO = aExpo( ii ) and
                       CH_STAMP = 0 and
                       AMOUNT != 0
                union all
                select -nvl( sum( a.AMOUNT_DT ), 0 ) as Amn,
                       0 as AmnBdg
                  from table( cast( ArrDealOper as Schema_GPSys.tblDealOper ) ) a
                 where a.EXPO_DT = aExpo( ii )
                union all
                select nvl( sum( a.AMOUNT_KT ), 0 ) as Amn,
                       0 as AmnBdg
                  from table( cast( ArrDealOper as Schema_GPSys.tblDealOper ) ) a
                 where a.EXPO_KT = aExpo( ii )
                union all
                select 0 as Amn,
                       OBOR_KT - OBOR_DT as AmnBdg
                  from EXPO_STATE
                 where ID_EXPO = nExpoBdg
                union all
                select 0 as Amn,
                       sum( decode( DT_KT, 'D', -AMOUNT, AMOUNT ) ) as AmnBdg
                  from EXPO_MOVES
                 where ID_EXPO = nExpoBdg and
                       CH_STAMP = 0 and
                       AMOUNT != 0
                union all
                select 0 as Amn,
                       -nvl( sum( a.AMOUNT_DT ), 0 )
                  from table( cast( ArrDealOper as Schema_GPSys.tblDealOper ) ) a
                 where a.EXPO_DT = nExpoBdg
                union all
                select 0 as Amn,
                       nvl( sum( a.AMOUNT_KT ), 0 )
                  from table( cast( ArrDealOper as Schema_GPSys.tblDealOper ) ) a
                 where a.EXPO_KT = nExpoBdg);

        nSaldo     := nvl( nSaldo, 0 );
        nSaldoBdg  := nvl( nSaldoBdg, 0 ) + nSaldo;
        nOldSaldo  := nSaldo;
        nCount     := 0;
        nSkipMode  := null;

        for rec in (  select -decode( a.ExpoDt, aExpo( ii ), a.AmountDt, 0 ) + decode( a.ExpoKt, aExpo( ii ), a.AmountKt, 0 ) as Amn,
                             -decode( a.ExpoDt, nExpoBdg, a.AmountDt, 0 ) + decode( a.ExpoKt, nExpoBdg, a.AmountKt, 0 ) as AmnBdg,
                             a.Valior
                        from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                       where ( aExpo( ii ) in (a.ExpoDt, a.ExpoKt) ) or
                             ( nExpoBdg in (a.ExpoDt, a.ExpoKt) )
                    order by 3 desc ) loop
          nSaldo     := nSaldo + rec.Amn; -- салдото след операцията
          nSaldoBdg  := nSaldoBdg + rec.Amn + rec.AmnBdg;

          if ( nCount = 0 or
              dValior != rec.Valior ) then
            nCount  := nCount + 1;
          end if;

          if ( nSkipMode is null or
              nSkipMode in (-1, 1) ) then
            if ( rec.Amn >= 0 ) then
              if ( nvl( nSkipMode, 1 ) = 1 ) then
                nSkipMode  := 1;
              else
                nSkipMode  := 0;
              end if;
            else
              if ( nvl( nSkipMode, -1 ) = -1 ) then
                nSkipMode  := -1;
              else
                nSkipMode  := 0;
              end if;
            end if;
          end if;

          dValior    := rec.Valior; -- най-стария вальор
        end loop;

        if ( not bChkOldValior ) then
          dValior  := greatest( dValior, SchDate );
        end if;

        dOpenDate  := nvl( aOpenDate( ii ), least( dValior, SchDate ) );
        bRet       := dOpenDate <= SchDate;

        if ( bRet ) then
          bRet  := dOpenDate <= dValior;

          if ( bRet ) then
            select nvl( max( a.SCH_DATE ), SchDate )
              into dOpenDate
              from EXPO_MOVES a
             where a.ID_MOVE = (select max( b.ID_MOVE_LAST )
                                  from Schema_GPSys.EXPO_UNIQCODE_LOG b
                                 where b.ID_EXPO = aExpo( ii )) and
                   a.ORDROWNUM = 1 and
                   a.DT_KT = 'D';

            bRet  := dOpenDate <= SchDate;

            if ( bRet ) then
              select max( a.SCH_DATE )
                into dOpenDate
                from EXPO_MOVES a
               where a.ID_MOVE = (select max( b.ID_MOVE_LAST )
                                    from Schema_GPSys.EXPO_CODVAL_LOG b
                                   where b.ID_EXPO = aExpo( ii )) and
                     a.ORDROWNUM = 1 and
                     a.DT_KT = 'D';

              bRet      := dOpenDate is null or
                           ( dOpenDate <= SchDate and
                            dOpenDate <= dValior );

              if ( bRet ) then
                $if ( Schema_GPSys.OraSys.VerOverGas or
                     Schema_GPSys.OraSys.VerUstoi ) $then
                select nvl( max( b.ID_CRED_ENGAGE ), 0 )
                  into nDummy
                  from LOAN_MOVES b,
                       LOAN_EXPOSITION a
                 where a.ID_EXPO = aExpo( ii ) and
                       a.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                       a.TYPE_CRED_EXPO not in
                         ( Schema_GPSys.HeadExpo.ExpoCred_Obsujvashta,
                          Schema_GPSys.HeadExpo.ExpoCred_RedovDulgPlanLih,
                          Schema_GPSys.HeadExpo.ExpoCred_ProsrDulgPlanLih,
                          Schema_GPSys.HeadExpo.ExpoCred_ProsrLihvPlanLih,
                          Schema_GPSys.HeadExpo.ExpoCred_ZBalPrLihPlanLih ) and
                       b.ID_CRED_ENGAGE = a.ID_CRED_ENGAGE and
                       b.VALIOR > dValior;

                bRet  := nDummy = 0;

                $end
                --
                $if ( Schema_GPSys.OraSys.VerBankTokuda or
                     Schema_GPSys.OraSys.VerBankDBank ) $then
                if ( bChkOldValior ) then
                  bRet      := aBaseType( ii ) != Schema_GPSys.HeadExpo.ExpoCash or
                               dValior = dSysDate;
                end if;

                $end
                --
                if ( bRet ) then
                  if ( not bOvercomeLimit ) then
                    for rExpoTypeLimits in (  select *
                                                from (select 1 as MYLEVEL,
                                                             a.*
                                                        from EXPOTYPE_LIMITS a
                                                       where a.TYPE_EXPO = -aExpo( ii ) and
                                                             a.CODVAL = 'VAL' and
                                                             a.FROM_DATE <= SchDate
                                                      union all
                                                      select 2 as MYLEVEL,
                                                             a.*
                                                        from EXPOTYPE_LIMITS a
                                                       where a.TYPE_EXPO = aTypeExpo( ii ) and
                                                             a.CODVAL = aCodVal( ii ) and
                                                             a.FROM_DATE <= SchDate)
                                            order by MYLEVEL asc,
                                                     FROM_DATE desc ) loop
                      if ( rExpoTypeLimits.MINAMOUNT is not null and
                          rExpoTypeLimits.MAXAMOUNT is not null ) then
                        bRet  := nSaldo between rExpoTypeLimits.MINAMOUNT and rExpoTypeLimits.MAXAMOUNT;
                      elsif ( rExpoTypeLimits.MINAMOUNT is not null ) then
                        bRet  := nSaldo >= rExpoTypeLimits.MINAMOUNT;
                      elsif ( rExpoTypeLimits.MAXAMOUNT is not null ) then
                        bRet  := nSaldo <= rExpoTypeLimits.MAxAMOUNT;
                      end if;

                      exit;
                    end loop;
                  end if;

                  if ( bRet ) then
                    nDifSaldo        := nSaldo - nOldSaldo; -- изменението на салдото от операцията
                    aDifSaldo( ii )  := nDifSaldo;

                    if ( nvl( IDOldMove, 0 ) <= 0 ) then
                      for rec in qLimit2( aExpo( ii ) ) loop
                        if ( ( nvl( rec.VID_OBOR, '~' ) = 'D' and
                              nDifSaldo < 0 ) or
                            ( nvl( rec.VID_OBOR, '~' ) = 'K' and
                             nDifSaldo > 0 ) or
                            ( nvl( rec.VID_OBOR, '~' ) = 'S' and
                             nDifSaldo != 0 ) ) then
                          if ( rec.LIM_MODE = 'D' ) then
                            dFrDate  := SchDate;
                            dToDate  := SchDate;
                          elsif ( rec.LIM_MODE = 'M' ) then
                            dFrDate  := Schema_GPSys.OraGPSys.BegOfMonth( SchDate );
                            dToDate  := Schema_GPSys.OraGPSys.EndOfMonth( SchDate );
                          else
                            dFrDate  := Schema_GPSys.OraGPSys.MakeDate( 1, 1, extract( year from SchDate ) );
                            dToDate  := Schema_GPSys.OraGPSys.MakeDate( 31, 12, extract( year from SchDate ) );
                          end if;

                          if ( nvl( rec.VID_OBOR, '~' ) = 'D' ) then
                            select nvl( sum( Amount ), 0 )
                              into nObor
                              from (select sum( AMOUNT ) as Amount
                                      from EXPO_MOVES
                                     where ID_EXPO = aExpo( ii ) and
                                           SCH_DATE between dFrDate and dToDate and
                                           DT_KT = 'D' and
                                           OPER_TYPE not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot)
                                    union all
                                    select sum( a.AmountDt ) as Amount
                                      from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                     where aExpo( ii ) = a.ExpoDt and
                                           a.OperType not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot));
                          elsif ( nvl( rec.VID_OBOR, '~' ) = 'K' ) then
                            select nvl( sum( Amount ), 0 )
                              into nObor
                              from (select sum( AMOUNT ) as Amount
                                      from EXPO_MOVES
                                     where ID_EXPO = aExpo( ii ) and
                                           SCH_DATE between dFrDate and dToDate and
                                           DT_KT = 'K' and
                                           OPER_TYPE not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot)
                                    union all
                                    select sum( a.AmountKt ) as Amount
                                      from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                     where aExpo( ii ) = a.ExpoKt and
                                           a.OperType not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot));
                          else
                            select nvl( sum( Amount ), 0 )
                              into nObor
                              from (select sum( decode( DT_KT, 'D', -AMOUNT, AMOUNT ) ) as Amount
                                      from EXPO_MOVES
                                     where ID_EXPO = aExpo( ii ) and
                                           SCH_DATE between dFrDate and dToDate and
                                           OPER_TYPE not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot)
                                    union all
                                    select sum( -decode( a.ExpoDt, aExpo( ii ), a.AmountDt, 0 ) + decode( a.ExpoKt, aExpo( ii ), a.AmountKt, 0 ) ) as Amount
                                      from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                     where aExpo( ii ) in (a.ExpoDt, a.ExpoKt) and
                                           a.OperType not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot));
                          end if;

                          bRet  := nObor <= rec.LIM_OBOR;

                          if ( not bRet ) then
                            aParams.delete;
                            aParams( 1 ).ML_NAME   := 'ID_EXPO';
                            aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                            aParams( 2 ).ML_NAME   := 'OBOROT';
                            aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nObor );
                            aParams( 3 ).ML_NAME   := 'LIM_OBOROT';
                            aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( rec.LIM_OBOR );

                            if ( rec.LIM_MODE = 'D' ) then
                              if ( nvl( rec.VID_OBOR, '~' ) = 'D' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен дневен дебитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              elsif ( nvl( rec.VID_OBOR, '~' ) = 'K' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен дневен кредитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              else
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен дневен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              end if;
                            elsif ( rec.LIM_MODE = 'M' ) then
                              if ( nvl( rec.VID_OBOR, '~' ) = 'D' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен месечен дебитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              elsif ( nvl( rec.VID_OBOR, '~' ) = 'K' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен месечен кредитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              else
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен месечен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              end if;
                            elsif ( rec.LIM_MODE = 'Y' ) then
                              if ( nvl( rec.VID_OBOR, '~' ) = 'D' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен годишен дебитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              elsif ( nvl( rec.VID_OBOR, '~' ) = 'K' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен годишен кредитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              else
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен годишен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              end if;
                            else
                              if ( nvl( rec.VID_OBOR, '~' ) = 'D' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен дебитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              elsif ( nvl( rec.VID_OBOR, '~' ) = 'K' ) then
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен кредитен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              else
                                sError      := Schema_GPSys.MLng.Str2( 'Нарушен лимит по експозиция $ID_EXPO$ оборот $OBOROT$ лимит $LIM_OBOROT$',
                                                                       Schema_GPSys.MLng.ctxPayments,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      );
                              end if;
                            end if;
                          end if;
                        end if;

                        exit when not bRet;
                      end loop;
                    end if;

                    bCredExpo        := false;

                    if ( bRet and
                        nvl( IDOldMove, 0 ) <= 0 ) then
                      bCredExpo  := Schema_GPSys.HeadExpo.IsItCreditExpo( aExpo( ii ) );

                      if ( bCredExpo and
                          nDifSaldo < 0 ) then
                        bRet      := GetSkipLimit( ModeSkip_ChkLastUseDate ) or
                                     Loans.Chk4CreditLastUseDate( aExpo( ii ), dValior );

                        if ( bRet ) then
                          if ( Schema_GPSys.HeadExpo.IsItRevolveCred( aExpo( ii ) ) ) then
                            aCredExpo( aCredExpo.count + 1 ).nIdExpo  := aExpo( ii );
                            aCredExpo( aCredExpo.count ).dValior      := dValior;
                          end if;
                        else
                          aParams.delete;
                          aParams( 1 ).ML_NAME   := 'ID_EXPO';
                          aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                          sError                 := Schema_GPSys.MLng.Str2( 'Операция с вальор след датата на последно усвояване на експозиция $ID_EXPO$',
                                                                            Schema_GPSys.MLng.ctxPayments,
                                                                            Schema_GPSys.MLng.lngBG,
                                                                            aParams
                                                                           );
                        end if;
                      end if;
                    end if;

                    if ( bRet ) then
                      -- fill CASH docs
                      if ( aBaseType( ii ) = Schema_GPSys.HeadExpo.ExpoCash and
                          Schema_GPSys.HeadExpo.ChkCashExpo( Schema_GPSys.HeadExpo.IDExpo2UCode( aExpo( ii ) ), aExpo( ii ), 2, nIDCash ) ) then
                        aCashExpos.extend;
                        aCashExpos( aCashExpos.count )  := Schema_GPSys.T2Int( aExpo( ii ), nIDCash );

                        if ( nDifSaldo != 0 ) then
                          Schema_GPSys.OraGPSys.Add2UniqArr( aCashHead, nIDCash );
                          aCashRows( aCashRows.count + 1 ).nIDCash  := nIDCash;

                          if ( nDifSaldo > 0 ) then
                            aCashRows( aCashRows.count ).sInOut  := 'O';
                          else
                            aCashRows( aCashRows.count ).sInOut  := 'I';
                          end if;

                          aCashRows( aCashRows.count ).sCodVal      := aCodVal( ii );
                          aCashRows( aCashRows.count ).nAmount      := abs( nDifSaldo );
                        end if;
                      end if;

                      -- end  CASH docs
                      if ( nDifSaldo = 0 or
                          ( bCredExpo and
                           GetSkipLimit( ModeSkip_ChkLastUseDate ) ) ) then
                        bSkipChk  := true;
                      else
                        bSkipChk  := nvl( nExpoBdg, 0 ) <= 0;

                        if ( bSkipChk ) then -- не е бюджетна двойка сметки
                          if ( aActPass( ii ) = 'A' ) then
                            bSkipChk      := nvl( nSkipMode, 0 ) = -1 or
                                             ( nCount <= 1 and
                                              nDifSaldo <= 0 );

                            if ( bSkipChk ) then
                              select count( 1 )
                                into nCount
                                from EXPO_LIMITS
                               where ID_EXPO = aExpo( ii ) and
                                     STATUS = ZaporStat_Active;

                              bSkipChk  := nCount = 0;
                            end if;
                          elsif ( aActPass( ii ) = 'P' ) then
                            bSkipChk      := nvl( nSkipMode, 0 ) = 1 or
                                             ( nCount <= 1 and
                                              nDifSaldo >= 0 );
                          else
                            select count( 1 )
                              into nCount
                              from EXPO_LIMITS
                             where ID_EXPO = aExpo( ii ) and
                                   STATUS = ZaporStat_Active;

                            bSkipChk  := nCount = 0;
                          end if;
                        elsif ( aActPass( ii ) = 'P' ) then
                          bSkipChk      := nvl( nSkipMode, 0 ) = 1 or
                                           ( nCount <= 1 and
                                            nDifSaldo >= 0 );
                        end if;
                      end if;

                      if ( not bSkipChk ) then
                        open qExpoMoves( aExpo( ii ), nExpoBdg, dValior );

                        loop
                          fetch qExpoMoves
                            into nAmount, nAmountBdg, dValior;

                          exit when qExpoMoves%notfound or
                                    not bRet;
                          nSaldo     := nSaldo + nAmount;
                          nSaldoBdg  := nSaldoBdg + nAmount + nAmountBdg;

                          if ( aActPass( ii ) = 'A' ) then
                            bRet  := nSaldo <= 0;
                          elsif ( aActPass( ii ) = 'P' ) then
                            bRet  := nSaldo >= 0;
                          else
                            bRet  := true;
                          end if;

                          if ( bRet and
                              bCredExpo and
                              not SkipTheLimitActPass( aActPass( ii ) ) ) then
                            bRet  := Loans.IsInCredLimit( aExpo( ii ), nSaldo, dValior, SchDate );
                          end if;

                          if ( bRet ) then
                            if ( nExpoBdg > 0 ) then
                              bRet  := nSaldoBdg >= 0;
                            end if;

                            if ( bRet ) then
                              nDifSaldo  := 0;

                              select sum( -decode( a.ExpoDt, aExpo( ii ), a.AmountDt, 0 ) + decode( a.ExpoKt, aExpo( ii ), a.AmountKt, 0 ) )
                                into nDifSaldo
                                from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                               where aExpo( ii ) in (a.ExpoDt, a.ExpoKt) and
                                     a.Valior = dValior;

                              nDifSaldo  := nvl( nDifSaldo, 0 );

                              /*
                              Schema_RA.gpc_tools.WriteErrorMsg2( to_char( aExpo( ii ) )||
                                                                  '-' ||
                                                                  cSkipActPass ||
                                                                  '-' ||
                                                                  aActPass( ii )||
                                                                  '-' ||
                                                                  Schema_GPSys.OraGPSys.DocSysBoolean( cSkipActPass = aActPass( ii ) )
                                                                 );
                              */
                              if ( nDifSaldo <= 0 and
                                  not SkipTheLimitActPass( aActPass( ii ) ) ) then
                                for rec in ( select *
                                               from EXPO_LIMITS
                                              where ID_EXPO = aExpo( ii ) and
                                                    ( BEG_DATE is null or
                                                     ( BEG_DATE <= dValior and
                                                      ( SchDate is null or
                                                       BEG_DATE <= SchDate ) ) ) and
                                                    ( END_DATE is null or
                                                     dValior <= END_DATE ) and
                                                    STATUS = ZaporStat_Active and
                                                    FULL_LIMIT = 'T' ) loop
                                  bRet  := SkipTheLimit( rec.TYPE_LIMIT, aTypeExpo( ii ) );
                                  exit when not bRet;
                                end loop;

                                if ( bRet ) then
                                  bLimits     := false;
                                  nAmount     := 0;
                                  nAmountBdg  := 0;

                                  for rec in qLimit1( aExpo( ii ), nExpoBdg, dValior, SchDate ) loop
                                    if ( aActPass( ii ) = 'A' or
                                        not SkipTheLimit( rec.TYPE_LIMIT, aTypeExpo( ii ) ) ) then
                                      if ( nExpoBdg = rec.ID_EXPO ) then
                                        nAmountBdg      := nAmountBdg +
                                                           nvl( Schema_GPSys.XchgRates.GetExactSum( rec.SUMLIMIT,
                                                                                                    null,
                                                                                                    dValior,
                                                                                                    rec.CODVAL,
                                                                                                    aCodVal( ii ),
                                                                                                    Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                   ),
                                                                0
                                                               );
                                      else
                                        bLimits      := true;
                                        nAmount      := nAmount +
                                                        nvl( Schema_GPSys.XchgRates.GetExactSum( rec.SUMLIMIT, null, dValior, rec.CODVAL, aCodVal( ii ), Schema_GPSys.XchgRates.XchgRateType_Fixing ),
                                                             0
                                                            );
                                      end if;
                                    end if;
                                  end loop;

                                  /*
                                                            sError      := 'Експозиция номер ' ||
                                                                           aExpo( ii ) ||
                                                                           ' - оставаща наличност ' ||
                                                                           nSaldo ||
                                                                           ', лимит ' ||
                                                                           nAmount;

                                                            if ( dValior is not null ) then
                                                              sError  := sError || ' към ' || to_char( dValior, 'dd.mm.yyyy' );
                                                            end if;

                                                            Schema_RA.GPC_Tools.WriteErrorMsg( sError );
                                  */
                                  bRet        := ( not bLimits ) or
                                                 ( nSaldo >= nAmount );

                                  if ( bRet ) then
                                    if ( nExpoBdg > 0 ) then
                                      nAmountBdg  := greatest( nAmount, 0 ) + greatest( nAmountBdg, 0 );
                                      bRet        := nSaldoBdg >= nAmountBdg;
                                    end if;

                                    -- !!! не променяй текстовете - на някои места се проверява по текста каква е грешката при осч. на превода
                                    if ( not bRet ) then
                                      aParams.delete;
                                      aParams( 1 ).ML_NAME   := 'ID_EXPO';
                                      aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                                      aParams( 2 ).ML_NAME   := 'EXPO_BDG';
                                      aParams( 2 ).ML_VALUE  := to_char( nExpoBdg );
                                      aParams( 3 ).ML_NAME   := 'SALDO_BDG';
                                      aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldoBdg );
                                      aParams( 4 ).ML_NAME   := 'AMOUNT_BDG';
                                      aParams( 4 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmountBdg );
                                      sError                 := Schema_GPSys.MLng.Str2( 'Нарушен лимит по експозиции с номера $ID_EXPO$ и $EXPO_BDG$ оставаща наличност $SALDO_BDG$ лимит $AMOUNT_BDG$',
                                                                                        Schema_GPSys.MLng.ctxPayments,
                                                                                        Schema_GPSys.MLng.lngBG,
                                                                                        aParams
                                                                                       );
                                    end if;
                                  else
                                    if ( dValior is not null ) then
                                      aParams.delete;
                                      aParams( 1 ).ML_NAME   := 'ID_EXPO';
                                      aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                                      aParams( 2 ).ML_NAME   := 'SALDO';
                                      aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldo );
                                      aParams( 3 ).ML_NAME   := 'AMOUNT';
                                      aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmount );
                                      aParams( 4 ).ML_NAME   := 'VALIOR';
                                      aParams( 4 ).ML_VALUE  := to_char( dValior, 'dd.mm.yyyy' );
                                      sError                 := Schema_GPSys.MLng.Str2( 'Нарушен лимит по експозиция номер $ID_EXPO$ - оставаща наличност $SALDO$, лимит $AMOUNT$ към $VALIOR$',
                                                                                        Schema_GPSys.MLng.ctxPayments,
                                                                                        Schema_GPSys.MLng.lngBG,
                                                                                        aParams
                                                                                       );
                                    else
                                      aParams.delete;
                                      aParams( 1 ).ML_NAME   := 'ID_EXPO';
                                      aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                                      aParams( 2 ).ML_NAME   := 'SALDO';
                                      aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldo );
                                      aParams( 3 ).ML_NAME   := 'AMOUNT';
                                      aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmount );
                                      sError                 := Schema_GPSys.MLng.Str2( 'Нарушен лимит по експозиция номер $ID_EXPO$ - оставаща наличност $SALDO$, лимит $AMOUNT$',
                                                                                        Schema_GPSys.MLng.ctxPayments,
                                                                                        Schema_GPSys.MLng.lngBG,
                                                                                        aParams
                                                                                       );
                                    end if;
                                  end if;
                                else
                                  aParams.delete;
                                  aParams( 1 ).ML_NAME   := 'ID_EXPO';
                                  aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                                  sError                 := Schema_GPSys.MLng.Str2( 'Нарушен лимит по експозиция номер $ID_EXPO$',
                                                                                    Schema_GPSys.MLng.ctxPayments,
                                                                                    Schema_GPSys.MLng.lngBG,
                                                                                    aParams
                                                                                   );
                                end if;
                              end if;
                            else
                              -- !!! не променяй текста - на някои места се проверява по текста каква е грешката при осч. на превода
                              aParams.delete;
                              aParams( 1 ).ML_NAME   := 'ID_EXPO';
                              aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                              aParams( 2 ).ML_NAME   := 'EXPO_BDG';
                              aParams( 2 ).ML_VALUE  := to_char( nExpoBdg );
                              aParams( 3 ).ML_NAME   := 'SALDO_BDG';
                              aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldoBdg );
                              sError                 := Schema_GPSys.MLng.Str2( 'Експозиции с номера $ID_EXPO$ и $EXPO_BDG$ ще получат некоректно компенсирано салдо $SALDO_BDG$',
                                                                                Schema_GPSys.MLng.ctxPayments,
                                                                                Schema_GPSys.MLng.lngBG,
                                                                                aParams
                                                                               );

                              select max( a.Valior )
                                into dValior
                                from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                               where aExpo( ii ) in (a.ExpoDt, aExpo( ii )) and
                                     a.Valior <= dValior;

                              if ( dValior is not null ) then
                                aParams.delete;
                                aParams( 1 ).ML_NAME   := 'ID_EXPO';
                                aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                                aParams( 2 ).ML_NAME   := 'EXPO_BDG';
                                aParams( 2 ).ML_VALUE  := to_char( nExpoBdg );
                                aParams( 3 ).ML_NAME   := 'SALDO_BDG';
                                aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldoBdg );
                                aParams( 4 ).ML_NAME   := 'VALIOR';
                                aParams( 4 ).ML_VALUE  := to_char( dValior, 'dd.mm.yyyy' );
                                sError                 := Schema_GPSys.MLng.Str2( 'Експозиции с номера $ID_EXPO$ и $EXPO_BDG$ ще получат некоректно компенсирано салдо $SALDO_BDG$ към $VALIOR$',
                                                                                  Schema_GPSys.MLng.ctxPayments,
                                                                                  Schema_GPSys.MLng.lngBG,
                                                                                  aParams
                                                                                 );
                              end if;
                            end if;
                          else
                            -- !!! не променяй текста - на някои места се проверява по текста каква е грешката при осч. на превода
                            select max( a.Valior )
                              into dValior
                              from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                             where aExpo( ii ) in (a.ExpoDt, aExpo( ii )) and
                                   a.Valior <= dValior;

                            if ( dValior is not null ) then
                              $if ( Schema_GPSys.OraSys.VerFIS ) $then
                              aParams.delete;
                              aParams( 1 ).ML_NAME   := 'BK_ACC';
                              aParams( 1 ).ML_VALUE  := Schema_Expo.Expo.GetExpoBKAcc( aExpo( ii ) );
                              aParams( 2 ).ML_NAME   := 'SALDO';
                              aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldo );
                              aParams( 3 ).ML_NAME   := 'VALIOR';
                              aParams( 3 ).ML_VALUE  := to_char( dValior, 'dd.mm.yyyy' );
                              sError                 := Schema_GPSys.MLng.Str2( 'Сметка номер $BK_ACC$ ще получи некоректно салдо $SALDO$ към $VALIOR$',
                                                                                Schema_GPSys.MLng.ctxPayments,
                                                                                Schema_GPSys.MLng.lngBG,
                                                                                aParams
                                                                               );
                            $else
                              aParams.delete;
                              aParams( 1 ).ML_NAME   := 'ID_EXPO';
                              aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                              aParams( 2 ).ML_NAME   := 'SALDO';
                              aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldo );
                              aParams( 3 ).ML_NAME   := 'VALIOR';
                              aParams( 3 ).ML_VALUE  := to_char( dValior, 'dd.mm.yyyy' );
                              sError                 := Schema_GPSys.MLng.Str2( 'Експозиция номер $ID_EXPO$ ще получи некоректно салдо $SALDO$ към $VALIOR$',
                                                                                Schema_GPSys.MLng.ctxPayments,
                                                                                Schema_GPSys.MLng.lngBG,
                                                                                aParams
                                                                               );
                            $end
                            else
                              $if ( Schema_GPSys.OraSys.VerFIS ) $then
                              aParams.delete;
                              aParams( 1 ).ML_NAME   := 'BK_ACC';
                              aParams( 1 ).ML_VALUE  := Schema_Expo.Expo.GetExpoBKAcc( aExpo( ii ) );
                              aParams( 2 ).ML_NAME   := 'SALDO';
                              aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldo );
                              sError                 := Schema_GPSys.MLng.Str2( 'Сметка номер $BK_ACC$ ще получи некоректно салдо $SALDO$',
                                                                                Schema_GPSys.MLng.ctxPayments,
                                                                                Schema_GPSys.MLng.lngBG,
                                                                                aParams
                                                                               );
                            $else
                              aParams.delete;
                              aParams( 1 ).ML_NAME   := 'ID_EXPO';
                              aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                              aParams( 2 ).ML_NAME   := 'SALDO';
                              aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSaldo );
                              sError                 := Schema_GPSys.MLng.Str2( 'Експозиция номер $ID_EXPO$ ще получи некоректно салдо $SALDO$',
                                                                                Schema_GPSys.MLng.ctxPayments,
                                                                                Schema_GPSys.MLng.lngBG,
                                                                                aParams
                                                                               );
                            $end
                            end if;
                          end if;
                        end loop;

                        close qExpoMoves;
                      end if;
                    end if;
                  else
                    aParams.delete;
                    aParams( 1 ).ML_NAME   := 'ID_EXPO';
                    aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
                    sError                 := Schema_GPSys.MLng.Str2( 'Салдо извън лимитирания диапазон за експозиция $ID_EXPO$',
                                                                      Schema_GPSys.MLng.ctxPayments,
                                                                      Schema_GPSys.MLng.lngBG,
                                                                      aParams
                                                                     );
                  end if;
                else
                  aParams.delete;
                  aParams( 1 ).ML_NAME   := 'VALIOR';
                  aParams( 1 ).ML_VALUE  := to_char( dValior, 'dd.mm.yyyy' );
                  aParams( 2 ).ML_NAME   := 'ID_EXPO';
                  aParams( 2 ).ML_VALUE  := to_char( aExpo( ii ) );
                  sError                 := Schema_GPSys.MLng.Str2( 'Операция с недопустим вальор $VALIOR$ за експозиция $ID_EXPO$',
                                                                    Schema_GPSys.MLng.ctxPayments,
                                                                    Schema_GPSys.MLng.lngBG,
                                                                    aParams
                                                                   );
                end if;
              else
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'SCH_DATE';
                aParams( 1 ).ML_VALUE  := to_char( SchDate, 'dd.mm.yyyy' );
                aParams( 2 ).ML_NAME   := 'ID_EXPO';
                aParams( 2 ).ML_VALUE  := to_char( aExpo( ii ) );
                sError                 := Schema_GPSys.MLng.Str2( 'Операция с дата $SCH_DATE$ преди датата на последно превалутиране на експозиция $ID_EXPO$',
                                                                  Schema_GPSys.MLng.ctxPayments,
                                                                  Schema_GPSys.MLng.lngBG,
                                                                  aParams
                                                                 );
              end if;
            else
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'SCH_DATE';
              aParams( 1 ).ML_VALUE  := to_char( SchDate, 'dd.mm.yyyy' );
              aParams( 2 ).ML_NAME   := 'ID_EXPO';
              aParams( 2 ).ML_VALUE  := to_char( aExpo( ii ) );
              sError                 := Schema_GPSys.MLng.Str2( 'Операция с дата $SCH_DATE$ преди датата на последно прехвърляне на експозиция $ID_EXPO$',
                                                                Schema_GPSys.MLng.ctxPayments,
                                                                Schema_GPSys.MLng.lngBG,
                                                                aParams
                                                               );
            end if;
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'VALIOR';
            aParams( 1 ).ML_VALUE  := to_char( dValior, 'dd.mm.yyyy' );
            aParams( 2 ).ML_NAME   := 'ID_EXPO';
            aParams( 2 ).ML_VALUE  := to_char( aExpo( ii ) );
            sError                 := Schema_GPSys.MLng.Str2( 'Операция с вальор $VALIOR$ преди датата на откриване на експозиция $ID_EXPO$',
                                                              Schema_GPSys.MLng.ctxPayments,
                                                              Schema_GPSys.MLng.lngBG,
                                                              aParams
                                                             );
          end if;
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'SCH_DATE';
          aParams( 1 ).ML_VALUE  := to_char( SchDate, 'dd.mm.yyyy' );
          aParams( 2 ).ML_NAME   := 'ID_EXPO';
          aParams( 2 ).ML_VALUE  := to_char( aExpo( ii ) );
          sError                 := Schema_GPSys.MLng.Str2( 'Операция с дата $SCH_DATE$ преди датата на откриване на експозиция $ID_EXPO$',
                                                            Schema_GPSys.MLng.ctxPayments,
                                                            Schema_GPSys.MLng.lngBG,
                                                            aParams
                                                           );
        end if;
      else
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO';
        aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
        sError                 := Schema_GPSys.MLng.Str2( 'Несъществуваща или закрита експозиция $ID_EXPO$',
                                                          Schema_GPSys.MLng.ctxPayments,
                                                          Schema_GPSys.MLng.lngBG,
                                                          aParams
                                                         );
      end if;

      exit when not bRet;
    end loop;

    commit;
    return bRet;
  end ChkSaldo;

  --------------------------------------------------------------------------------
  function ChkExpoOpers(
    sError         in out varchar2,
    IDMove            out integer,
    nUniqCode      in     integer,
    nIDCust        in     integer,
    oOpers         in     Schema_GPSys.TblSchOper,
    SchDate        in     date,
    IDOldMove      in     integer,
    aClosedExpo    in     Schema_GPSys.OraGPSys.aNumbers,
    nIDExpo4Zapor  in     integer default null
  )
    return boolean is
    aExpo           Schema_GPSys.OraGPSys.aNumbers;
    aIDCust         Schema_GPSys.OraGPSys.aNumbers;
    aTypeExpo       Schema_GPSys.OraGPSys.aNumbers;
    aCodVal         Schema_GPSys.OraGPSys.aStrings;
    aStatus         Schema_GPSys.OraGPSys.aStrings;
    aActPass        Schema_GPSys.OraGPSys.aStrings;
    aBaseType       Schema_GPSys.OraGPSys.aNumbers;
    aDifSaldo       Schema_GPSys.OraGPSys.aNumbers;
    aOpenDate       Schema_GPSys.OraGPSys.aDates;
    rTypeDt         Schema_GPSys.EXPOTYPES%rowtype;
    rTypeKt         Schema_GPSys.EXPOTYPES%rowtype;
    rExpoDt         Schema_GPSys.EXPOSITION%rowtype;
    rExpoKt         Schema_GPSys.EXPOSITION%rowtype;
    bVatDt          boolean;
    bVatKt          boolean;
    bOldState       boolean;
    bDummy          boolean;
    bRet            boolean := true;
    nDummy          integer;
    nOperType       integer;
    nAmount         number;
    nAmountDraw     number := 0;
    nCashLimit      number;
    nDrawLimit      number;
    nAddAmount      number;
    nSysAmount      number;
    dSchDate        date;
    ----
    RecCashDoc      CASH_DOCS%rowtype;
    bCashDoc        boolean;
    bOvercomeLimit  boolean;
    nCashDoc        integer;
    aCashHead       Schema_GPSys.OraGPSys.aNumbers;
    aCashRows       taCashRows;
    aCashExpos      Schema_GPSys.Tbl2Int;
    aCredExpo       taCredExpo;
    aIDs            Schema_GPSys.OraGPSys.aNumbers;
    aIDLimits1      Schema_GPSys.OraGPSys.aRowids;
    aIDLimits2      Schema_GPSys.OraGPSys.aNumbers;
    aParams         Schema_RA.GPC_RA.tblErrParams;

    cursor qCashData(
      tnIDExpoDT  in integer,
      tnIDExpoKT  in integer
    ) is
      select nvl( b.ID_EXPO, 0 ) as IDEXPO,
             decode( b.PARAM2, 'AUTO', 'T', 'F' ) as IS_AUTO,
             ( select count( * )
                 from Schema_GPSys.EXPO_CONF c
                where b.PARAM2 = 'AUTO' and
                      c.FLDMODE = 'CashConf' and
                      c.PARAM2 = b.PARAM1 )
               as CNT_REAL_CASH
        from Schema_GPSys.EXPO_CONF b
       where b.PARAM1 in (select a.PARAM1
                            from Schema_GPSys.EXPO_CONF a
                           where a.ID_EXPO in (tnIDExpoDT, tnIDExpoKT) and
                                 a.FLDMODE = 'Cash') and
             b.FLDMODE = 'CashSch';

    cursor qCash( nMove in integer ) is
      select *
        from CASH_DOCS
       where ID_MOVE = nMove;

    ----
    cursor qExp(
      nExpoDt  in number,
      nExpoKt  in number
    ) is
      select b.IN_BALANCE as InBalDt,
             b.ACTPASS as ActPaDt,
             b.BASE_TYPE as BaseTypeDt,
             a.ID_CUST as CustDt,
             a.TYPE_EXPO as TypeDt,
             a.UNIQCODE as nUCodeDt,
             a.CODVAL as CodValDt,
             a.STATUS as StatusDt,
             a.EXPO_CODE as ExpoCodeDt,
             a.SYNT_CODE as SyntCodeDt,
             d.IN_BALANCE as InBalKt,
             d.ACTPASS as ActPaKt,
             d.BASE_TYPE as BaseTypeKt,
             c.ID_CUST as CustKt,
             c.TYPE_EXPO as TypeKt,
             c.UNIQCODE as nUCodeKt,
             c.CODVAL as CodValKt,
             c.STATUS as StatusKt,
             c.EXPO_CODE as ExpoCodeKt,
             c.SYNT_CODE as SyntCodeKt
        from Schema_GPSys.EXPOTYPES d,
             Schema_GPSys.EXPOSITION c,
             Schema_GPSys.EXPOTYPES b,
             Schema_GPSys.EXPOSITION a
       where a.ID_EXPO = nExpoDt and
             a.TYPE_EXPO = b.TYPE_EXPO and
             c.ID_EXPO = nExpoKt and
             c.TYPE_EXPO = d.TYPE_EXPO;

    cursor qChk4Prosr(
      pCustDt    in integer,
      pUniqCode  in integer
    ) is
      select UNIQCODE,
             NO_CHK4PROSR
        from CUST_TARIF
       where ID_CUST = pCustDt and
             UNIQCODE = pUniqCode
      union all
      select UNIQCODE,
             NO_CHK4PROSR
        from CUST_TARIF
       where ID_CUST = pCustDt and
             UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All
      order by UNIQCODE desc; -- първо излиза записа с истинското UNIQCODE, а на второ място - defUniqCode_All (1)

    cDummy          varchar2( 64 );
    cOldActPass     varchar2( 1 );
  begin
    /*
        for ii in oOpers.first .. oOpers.last loop
          dbms_output.put_line(
             oOpers( ii ).ExpoDt ||
            ' ' ||
            oOpers( ii ).ValDt ||
            ' ' ||
            oOpers( ii ).AmountDt ||
            ' ' ||
            oOpers( ii ).AmountKt ||
            ' ' ||
            oOpers( ii ).ValKt ||
            ' ' ||
            oOpers( ii ).ExpoKt ||
            ' ' ||
            oOpers( ii ).Valior ||
            ' ' ||
            oOpers( ii ).SysAmount
           );
        end loop;
    */
    if ( Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 29 ) and
        nvl( cSkipActPass, '~' ) = '~' ) then
      cOldActPass  := SetSkipActPass( 'P' );
    end if;

    bOvercomeLimit  := Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 6 );

    if ( bOvercomeLimit ) then
      bOldState  := SetSkipLimit( ModeSkip_Limit, true );
    end if;

    dSchDate        := Schema_RA.GPC_Tools.GetSchDate( nUniqCode );
    nCashLimit      := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'CASH_BIG_OPERS_LIMIT', null );
    nDrawLimit      := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'CASH_BIG_DRAW_LIMIT', null );
    aCashExpos      := Schema_GPSys.Tbl2Int( );

    for rec in ( select EXPODT,
                        AMOUNTDT,
                        AMOUNTKT,
                        EXPOKT,
                        OPERTYPE,
                        VALIOR,
                        SCHDATE
                   from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) ) loop
      if ( rec.OPERTYPE not in (Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot, Cmd_Expo.Sch_ImportOborot) ) then
        for recCash in qCashData( rec.EXPODT, rec.EXPOKT ) loop
          bRet  := recCash.IDEXPO != -1;

          if ( recCash.IS_AUTO = 'T' ) then
            bRet      := bRet and
                         recCash.CNT_REAL_CASH > 0;
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( bRet ) then
        open qExp( rec.EXPODT, rec.EXPOKT );

        fetch qExp
          into rTypeDt.IN_BALANCE,
               rTypeDt.ACTPASS,
               rTypeDt.BASE_TYPE,
               rExpoDt.ID_CUST,
               rExpoDt.TYPE_EXPO,
               rExpoDt.UNIQCODE,
               rExpoDt.CODVAL,
               rExpoDt.STATUS,
               rExpoDt.EXPO_CODE,
               rExpoDt.SYNT_CODE,
               rTypeKt.IN_BALANCE,
               rTypeKt.ACTPASS,
               rTypeKt.BASE_TYPE,
               rExpoKt.ID_CUST,
               rExpoKt.TYPE_EXPO,
               rExpoKt.UNIQCODE,
               rExpoKt.CODVAL,
               rExpoKt.STATUS,
               rExpoKt.EXPO_CODE,
               rExpoKt.SYNT_CODE;

        bRet  := qExp%found;

        close qExp;

        if ( bRet ) then
          bRet      := ( rExpoDt.UNIQCODE = nUniqCode and
                        rExpoKt.UNIQCODE = nUniqCode ) or
                       not IsSystemHaveBalances;

          if ( bRet ) then
            bRet  := rTypeDt.IN_BALANCE = rTypeKt.IN_BALANCE;

            if ( bRet and
                rTypeDt.IN_BALANCE = 'F' and
                Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'CHK_ZBAL', 'T' ) ) ) then
              bRet      := ( rTypeDt.ACTPASS = rTypeKt.ACTPASS ) or
                           ( rTypeDt.ACTPASS in ('*', '#', 'A') and
                            Schema_GPSys.HeadExpo.IsItCommonZBal( rec.EXPOKT, false ) ) or
                           ( rTypeDt.ACTPASS in ('*', '#', 'P') and
                            Schema_GPSys.HeadExpo.IsItCommonZBal( rec.EXPOKT, true ) ) or
                           ( Schema_GPSys.HeadExpo.IsItCommonZBal( rec.EXPODT, false ) and
                            rTypeKt.ACTPASS in ('*', '#', 'A') ) or
                           ( Schema_GPSys.HeadExpo.IsItCommonZBal( rec.EXPODT, true ) and
                            rTypeKt.ACTPASS in ('*', '#', 'P') );
            end if;

            if ( bRet ) then
              bRet      := Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 23 ) or
                           ( not ( Schema_GPSys.HeadExpo.IsItSpecialSynt( rExpoDt.EXPO_CODE, 'Prihod' ) = Schema_GPSys.OraGPSys.DocSysTrue and
                                  Schema_GPSys.HeadExpo.IsItSpecialSynt( rExpoKt.EXPO_CODE, 'Razhod' ) = Schema_GPSys.OraGPSys.DocSysTrue ) and
                            not ( Schema_GPSys.HeadExpo.IsItSpecialSynt( rExpoDt.EXPO_CODE, 'Razhod' ) = Schema_GPSys.OraGPSys.DocSysTrue and
                                 Schema_GPSys.HeadExpo.IsItSpecialSynt( rExpoKt.EXPO_CODE, 'Prihod' ) = Schema_GPSys.OraGPSys.DocSysTrue ) );
            end if;

            if ( bRet ) then
              if ( nvl( nDrawLimit, -1 ) > 0 and
                  Schema_GPSys.HeadExpo.IsItSpecialSynt( rExpoDt.SYNT_CODE, 'Money' ) = Schema_GPSys.OraGPSys.DocSysTrue and
                  Schema_GPSys.HeadExpo.IsItSpecialSynt( rExpoKt.SYNT_CODE, 'Money' ) = Schema_GPSys.OraGPSys.DocSysTrue ) then
                nDrawLimit  := null;
              end if;
            else
              sError  := Schema_GPSys.MLng.Str2( 'Некоректна контировка', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG );
            end if;
          else
            sError  := Schema_GPSys.MLng.Str2( 'Експозиции в различни баланси', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG );
          end if;
        else
          sError  := Schema_GPSys.MLng.Str2( 'Непозната експозиция', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG );
        end if;
      else
        sError  := Schema_GPSys.MLng.Str2( 'Касата е забранена или няма физическа каса', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG );
      end if;

      if ( bRet ) then
        bVatDt  := Schema_GPSys.HeadExpo.IsItVatExpo( rec.EXPODT );

        -- проверка за контировки с ДДС сметка
        if ( rExpoDt.TYPE_EXPO != rExpoKt.TYPE_EXPO and
            not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 1 ) ) then
          bVatKt  := Schema_GPSys.HeadExpo.IsItVatExpo( rec.EXPOKT );

          if ( bVatDt != bVatKt ) then
            if ( rExpoDt.ID_CUST = rExpoKt.ID_CUST ) then
              bRet      := ( not bVatDt ) and
                           bVatKt;
            else
              bRet      := ( bVatDt and
                            Schema_GPSys.HeadExpo.IsItRazchetBISERA( rec.EXPOKT ) ) or
                           ( bVatKt and
                            Schema_GPSys.HeadExpo.IsItRazchetBISERA( rec.EXPODT ) );
            end if;

            if ( not bRet ) then
              sError  := Schema_GPSys.MLng.Str2( 'Некоректна контировка за експозиция по ДДС', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG );
            end if;
          end if;
        end if;

        if ( bRet and
            Schema_GPSys.HeadExpo.IsItCashExpo( rec.EXPODT ) ) then
          bRet  := Schema_GPSys.XchgRates.IsCurrencyAllowed4CashOpers( rExpoDt.CODVAL );

          if ( not bRet ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'CODVAL';
            aParams( 1 ).ML_VALUE  := rExpoDt.CODVAL;
            sError                 := Schema_GPSys.MLng.Str2( 'Забранена операция на каса с валута $CODVAL$',
                                                              Schema_GPSys.MLng.ctxPayments,
                                                              Schema_GPSys.MLng.lngBG,
                                                              aParams
                                                             );
          end if;
        end if;

        if ( bRet and
            Schema_GPSys.HeadExpo.IsItCashExpo( rec.EXPOKT ) ) then
          bRet  := Schema_GPSys.XchgRates.IsCurrencyAllowed4CashOpers( rExpoKt.CODVAL );

          if ( not bRet ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'CODVAL';
            aParams( 1 ).ML_VALUE  := rExpoKt.CODVAL;
            sError                 := Schema_GPSys.MLng.Str2( 'Забранена операция на каса с валута $CODVAL$',
                                                              Schema_GPSys.MLng.ctxPayments,
                                                              Schema_GPSys.MLng.lngBG,
                                                              aParams
                                                             );
          end if;

          if ( bRet ) then
            -- проверка за теглене на каса при наличие на сътитуляри
            select count( 1 )
              into nDummy
              from Schema_GPSys.CONFSYSTEM c,
                   Schema_GPSys.EXPOSITION b,
                   EXPO_COTITULQRI a
             where a.ID_EXPO = rec.EXPODT and
                   b.ID_EXPO = a.ID_EXPO and
                   c.FLDSECTION = 'EXPOSITION' and
                   c.FLDITEM = 'EXPO_TYPES_NOCASH_WITHDRAWAL' and
                   c.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                   c.FLDVALUE like '%&' || to_char( b.TYPE_EXPO ) || '&%';

            bRet  := nDummy = 0;

            if ( not bRet ) then
              sError      := Schema_GPSys.MLng.Str2( 'Забранено теглене на каса от сметка с повече от 1 титуляр',
                                                     Schema_GPSys.MLng.ctxPayments,
                                                     Schema_GPSys.MLng.lngBG
                                                    );
            end if;
          end if;

          if ( bRet and
              ( not bOvercomeLimit ) ) then
            select /*+ LEADING( a b c d ) USE_NL( b c d )*/
                  nvl( sum( a.AMOUNT ), 0 )
              into nDummy
              from Schema_GPSys.EXPOTYPES d,
                   Schema_GPSys.EXPOSITION c,
                   EXPO_MOVES b,
                   EXPO_MOVES a
             where a.ID_EXPO = rec.EXPODT and
                   a.VALIOR = rec.VALIOR and
                   a.DT_KT = 'D' and
                   a.ID_MOVE = b.ID_MOVE and
                   a.ORDROWNUM = b.ORDROWNUM and
                   a.DT_KT != b.DT_KT and
                   b.ID_EXPO = c.ID_EXPO and
                   c.TYPE_EXPO = d.TYPE_EXPO and
                   d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash and
                   exists
                     (select 1
                        from Schema_GPSys.CONFSYSTEM_INT g
                       where g.FLDSECTION = 'EXPOSITION' and
                             g.FLDITEM = 'O_CURR_LIMIT_' || to_char( rExpoDt.TYPE_EXPO ) || '_' || rExpoDt.CODVAL and
                             g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                             g.FLDVALUE = -1);

            bRet  := nDummy = 0;

            if ( not bRet ) then
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'AMOUNT';
              aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nDummy );
              aParams( 2 ).ML_NAME   := 'CODVAL';
              aParams( 2 ).ML_VALUE  := rExpoDt.CODVAL;
              Schema_RA.GPC_RA.RespSetErrorText( 'Налично е теглене на каса на вальора $AMOUNT$ $CODVAL$',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;
          end if;
        end if;

        -- проверка за просрочия
        if ( bRet and
            not bVatDt and
            Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'CHK_PROSR', 'T' ) ) ) then
          open qChk4Prosr( rExpoDt.ID_CUST, nUniqCode );

          fetch qChk4Prosr
            into nDummy, cDummy;

          if ( qChk4Prosr%found ) then
            bDummy  := not nvl( Schema_GPSys.OraGPSys.Str2Boolean( cDummy ), false );
          else
            bDummy  := not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 2 );
          end if;

          close qChk4Prosr;

          if ( bDummy ) then
            if ( rExpoDt.ID_CUST != rExpoKt.ID_CUST and
                rExpoDt.ID_CUST > 0 and
                rTypeDt.ACTPASS != 'A' and
                Schema_GPSys.HeadExpo.IsItDepositExpo( rec.EXPODT ) and
                ( rExpoKt.ID_CUST > 0 or
                 Schema_GPSys.HeadExpo.IsItCashExpo( rec.EXPOKT ) or
                 Schema_GPSys.HeadExpo.IsItRazchetBISERA( rec.EXPOKT ) ) ) then
              bRet      := Schema_RA.GPC_Tools.IsIdCustInConfig( rExpoDt.ID_CUST ) or
                           not Schema_GPSys.HeadExpo.Check4Prosr( rExpoDt.ID_CUST );

              if ( not bRet ) then
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'ID_CUST';
                aParams( 1 ).ML_VALUE  := to_char( rExpoDt.ID_CUST );
                sError                 := Schema_GPSys.MLng.Str2( 'Съществуват налични просрочия за клиент $ID_CUST$',
                                                                  Schema_GPSys.MLng.ctxPayments,
                                                                  Schema_GPSys.MLng.lngBG,
                                                                  aParams
                                                                 );
              end if;
            end if;
          end if;
        end if;
      --
      else
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'sError';
        aParams( 1 ).ML_VALUE  := sError;
        aParams( 2 ).ML_NAME   := 'ID_EXPO_DT';
        aParams( 2 ).ML_VALUE  := to_char( rec.EXPODT );
        aParams( 3 ).ML_NAME   := 'ID_EXPO_KT';
        aParams( 3 ).ML_VALUE  := to_char( rec.EXPOKT );
        sError                 := Schema_GPSys.MLng.Str2( '$sError$ Дт: $ID_EXPO_DT$ -> Кт: $ID_EXPO_KT$', Schema_GPSys.MLng.ctxPayments, Schema_GPSys.MLng.lngBG, aParams );
      end if;

      if ( bRet ) then
        nDummy  := Schema_GPSys.OraGPSys.AScan( aExpo, rec.EXPODT );

        if ( nDummy = 0 ) then
          nDummy               := aOpenDate.count + 1;
          aExpo( nDummy )      := rec.EXPODT;
          aIDCust( nDummy )    := rExpoDt.ID_CUST;
          aTypeExpo( nDummy )  := rExpoDt.TYPE_EXPO;
          aStatus( nDummy )    := rExpoDt.STATUS;
          aCodVal( nDummy )    := rExpoDt.CODVAL;
          aActPass( nDummy )   := rTypeDt.ACTPASS;
          aBaseType( nDummy )  := rTypeDt.BASE_TYPE;
          aOpenDate( nDummy )  := GetExpoOpenDate( rec.EXPODT );
          aDifSaldo( nDummy )  := 0;
        end if;

        /* da se dopuskat operacii po olihviavane s valior
           do 30 dni po-maluk ot datata na otkrivane na smetka */
        if ( rec.VALIOR < nvl( aOpenDate( nDummy ), rec.VALIOR ) and
            rec.VALIOR >= rec.SCHDATE - 30 and
            rec.OPERTYPE in (Cmd_Expo.Sch_Lihvi, Cmd_Expo.Sch_TranLih, Cmd_Expo.Sch_Storno) ) then
          aOpenDate( nDummy )  := least( aOpenDate( nDummy ), rec.SCHDATE - 30 );
        end if;

        /* da se dopuskat operacii po olihviavane s valior
           do 30 dni po-maluk ot datata na otkrivane na smetka */
        if ( rec.EXPOKT != rec.EXPODT ) then
          nDummy  := Schema_GPSys.OraGPSys.AScan( aExpo, rec.EXPOKT );

          if ( nDummy = 0 ) then
            nDummy               := aOpenDate.count + 1;
            aExpo( nDummy )      := rec.EXPOKT;
            aIDCust( nDummy )    := rExpoKt.ID_CUST;
            aTypeExpo( nDummy )  := rExpoKt.TYPE_EXPO;
            aStatus( nDummy )    := rExpoKt.STATUS;
            aCodVal( nDummy )    := rExpoKt.CODVAL;
            aActPass( nDummy )   := rTypeKt.ACTPASS;
            aBaseType( nDummy )  := rTypeKt.BASE_TYPE;
            aOpenDate( nDummy )  := GetExpoOpenDate( rec.EXPOKT );
            aDifSaldo( nDummy )  := 0;
          end if;

          /* da se dopuskat operacii po olihviavane s valior
             do 30 dni po-maluk ot datata na otkrivane na smetka */
          if ( rec.VALIOR < nvl( aOpenDate( nDummy ), rec.VALIOR ) and
              rec.VALIOR >= rec.SCHDATE - 30 and
              rec.OPERTYPE in (Cmd_Expo.Sch_Lihvi, Cmd_Expo.Sch_TranLih, Cmd_Expo.Sch_Storno) ) then
            aOpenDate( nDummy )  := least( aOpenDate( nDummy ), rec.SCHDATE - 30 );
          end if;
        /* da se dopuskat operacii po olihviavane s valior
           do 30 dni po-maluk ot datata na otkrivane na smetka */
        end if;
      end if;

      if ( rExpoKt.ID_CUST > 0 and
          ( rExpoKt.ID_CUST != rExpoDt.ID_CUST or
           rTypeDt.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg ) and
          rec.AMOUNTKT > 0 ) then
        for recLimit in ( select a.rowid,
                                 a.*
                            from EXPO_LIMITS a
                           where a.ID_EXPO = rec.EXPOKT and
                                 a.TYPE_LIMIT = ExpoLimit_SudebenPrc and
                                 nvl( a.PROC_LIMIT, 0 ) > 0 and
                                 a.STATUS = ZaporStat_Active ) loop
          nAmount      := Schema_GPSys.XchgRates.GetExactSum( rec.AMOUNTKT * recLimit.PROC_LIMIT / 100,
                                                              nUniqCode,
                                                              rec.VALIOR,
                                                              rExpoKt.CODVAL,
                                                              recLimit.CODVAL,
                                                              Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                             );

          if ( nAmount > 0 ) then
            nDummy                := aIDLimits1.count + 1;
            aIDLimits1( nDummy )  := recLimit.rowid;
            aIDLimits2( nDummy )  := nAmount;
          end if;
        end loop;
      end if;

      exit when not bRet;
    end loop;

    if ( bRet ) then
      -- заключване на nUniqCode
      cDummy    := 'ChkExpoOpers_';
      --if ( IsSystemHaveBalances ) then
      cDummy    := cDummy || to_char( nUniqCode );
      --end if;
      nDummy    := GetExpoNumberW( cDummy );
      bRet      := nvl( nDummy, 0 ) > 0;

      if ( not bRet ) then
        sError  := Schema_RA.GPC_RA.RespGetErrorText;
      end if;

      bRet      := bRet and
                   ( GetSkipLimit( Expo.ModeSkip_LockLoan ) or
                    ChkSaldo( aExpo,
                              aIDCust,
                              aTypeExpo,
                              aCodVal,
                              aStatus,
                              aActPass,
                              aBaseType,
                              aOpenDate,
                              oOpers,
                              SchDate,
                              dSchDate,
                              IDOldMove,
                              aClosedExpo,
                              aCashHead,
                              aCashRows,
                              aCashExpos,
                              aCredExpo,
                              aDifSaldo,
                              sError,
                              bOvercomeLimit
                             ) );

      if ( bRet and
          ( not bSkipChkGroupLimits ) and
          nvl( IDOldMove, 0 ) <= 0 ) then
        for ii in aExpo.first .. aExpo.last loop
          if ( nvl( aIDCust( ii ), 0 ) > 0 and
              aDifSaldo( ii ) != 0 ) then
            bRet  := ChkGroupLimits( aExpo( ii ), aIDCust( ii ), aTypeExpo( ii ), aCodVal( ii ), dSchDate, aDifSaldo( ii ), sError );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( bRet ) then
        IDMove     := GetExpoNumber( 'ID_MOVE' );
        nOperType  := Cmd_Expo.Sch_Free;

        -- запис на операциите в EXPO_MOVES
        for ii in oOpers.first .. oOpers.last loop
          -- май трябва да се направи "сглобяване" на операциите
          if ( nvl( oOpers( ii ).OrdRowNum, 0 ) > 0 ) then
            nDummy  := oOpers( ii ).OrdRowNum;
          else
            nDummy  := ii;
          end if;

          if ( ii = oOpers.first ) then
            nOperType  := oOpers( ii ).OperType;
          end if;

          if ( nvl( IDOldMove, 0 ) > 0 ) then
            select -ADD_AMOUNT, -- pri preminavane v evrova sreda ADD_AMOUNT i SYS_AMOUNT sa razmeneni i ot docsys-a
                   -SYS_AMOUNT -- za order pusnat v levova sreda v SYS_AMOUNT ima levove e ne evro
              into nAddAmount,
                   nSysAmount
              from EXPO_MOVES
             where ID_MOVE = IDOldMove and
                   ORDROWNUM = nDummy and
                   DT_KT = 'D';
          else
            nAddAmount      := case
                                 when Schema_GPSys.OraGPSys.SYS_CURR = Schema_GPSys.OraGPSys.BGN_CURR then
                                   case
                                     when Schema_GPSys.HeadExpo.IDExpo2CodVal( oOpers( ii ).ExpoDt ) = Schema_GPSys.OraGPSys.EUR_CURR then oOpers( ii ).AmountDt
                                     when Schema_GPSys.HeadExpo.IDExpo2CodVal( oOpers( ii ).ExpoKt ) = Schema_GPSys.OraGPSys.EUR_CURR then oOpers( ii ).AmountKt
                                     else Schema_GPSys.OraGPSys.nTruncSet( oOpers( ii ).SysAmount / Schema_GPSys.OraGPSys.EURORate, Schema_GPSys.OraGPSys.EUR_CURR )
                                   end
                                 else
                                   case
                                     when Schema_GPSys.HeadExpo.IDExpo2CodVal( oOpers( ii ).ExpoDt ) = Schema_GPSys.OraGPSys.BGN_CURR then oOpers( ii ).AmountDt
                                     when Schema_GPSys.HeadExpo.IDExpo2CodVal( oOpers( ii ).ExpoKt ) = Schema_GPSys.OraGPSys.BGN_CURR then oOpers( ii ).AmountKt
                                     else Schema_GPSys.OraGPSys.nTruncSet( oOpers( ii ).SysAmount * Schema_GPSys.OraGPSys.EURORate, Schema_GPSys.OraGPSys.BGN_CURR )
                                   end
                               end;
            nSysAmount      := oOpers( ii ).SysAmount;
          end if;

          insert into EXPO_MOVES(
                        ID_MOVE,
                        UNIQCODE,
                        OPER_TYPE,
                        ID_EXPO,
                        DT_KT,
                        AMOUNT,
                        SYS_AMOUNT,
                        VALIOR,
                        SCH_DATE,
                        ORDROWNUM,
                        DEAL_NUM,
                        ADD_AMOUNT,
                        EXPO_CODVAL
                      )
               values ( IDMove,
                        nUniqCode,
                        oOpers( ii ).OperType,
                        oOpers( ii ).ExpoDt,
                        'D',
                        oOpers( ii ).AmountDt,
                        nSysAmount,
                        oOpers( ii ).Valior,
                        SchDate,
                        nDummy,
                        oOpers( ii ).DealNum,
                        nAddAmount,
                        Schema_GPSys.HeadExpo.IDExpo2CodVal( oOpers( ii ).ExpoDt )
                       );

          insert into EXPO_MOVES(
                        ID_MOVE,
                        UNIQCODE,
                        OPER_TYPE,
                        ID_EXPO,
                        DT_KT,
                        AMOUNT,
                        SYS_AMOUNT,
                        VALIOR,
                        SCH_DATE,
                        ORDROWNUM,
                        DEAL_NUM,
                        ADD_AMOUNT,
                        EXPO_CODVAL
                      )
               values ( IDMove,
                        nUniqCode,
                        oOpers( ii ).OperType,
                        oOpers( ii ).ExpoKt,
                        'K',
                        oOpers( ii ).AmountKt,
                        nSysAmount,
                        oOpers( ii ).Valior,
                        SchDate,
                        nDummy,
                        oOpers( ii ).DealNum,
                        nAddAmount,
                        Schema_GPSys.HeadExpo.IDExpo2CodVal( oOpers( ii ).ExpoKt )
                       );
        end loop;

        bCashDoc   := true;

        if ( nvl( IDOldMove, 0 ) > 0 ) then
          insert into EXPO_STRNMOVES(
                        ID_MOVE_OLD,
                        ID_MOVE_NEW
                      )
               values ( IDOldMove,
                        IDMove
                       );

          bRet      := Loans.CreditPadej4Storno( IDOldMove ) and
                       Calclih.RestoreExpoLihDate( IDOldMove, IDMove );

          if ( bRet ) then
            Calclih.MarkLihvi4Storno( IDOldMove, IDMove );
            bCashDoc  := false;

            open qCash( IDOldMove );

            loop
              fetch qCash
                into RecCashDoc;

              exit when qCash%notfound;
              bCashDoc      := RecCashDoc.STATUS = Cash.CashDoc_Confirmed or
                               Schema_GPSys.OraGPSys.IsSysObjLocked( Schema_GPSys.OraGPSys.LockTypeCash, RecCashDoc.ID_CASH );
              exit when bCashDoc;
            end loop;

            close qCash;

            $if ( Schema_GPSys.OraSys.VerOverGas or
                 Schema_GPSys.OraSys.VerUstoi ) $then
            delete from LOAN_MOVES
                  where ID_MOVE = IDOldMove;

            $end
            --
            $if ( Schema_GPSys.OraSys.VerCredito or Schema_GPSys.OraSys.VerFPMH ) $then
            update LOAN_DRAWNS
               set STATUS   = Loans.LoanStat_Closed,
                   ID_MOVE  = ( -1 ) * ID_MOVE
             where ID_MOVE = IDOldMove;

            if ( sql%rowcount = 0 ) then
              update LOAN_DRAWNS
                 set ID_MOVE1  = ( -1 ) * ID_MOVE1
               where ID_MOVE1 = IDOldMove;
            end if;

            delete from LOAN_REWARDS
                  where ID_MOVE = IDOldMove;

            $end
            --
            delete from TAXES_PAYS
                  where ID_MOVE = IDOldMove;

            aIDs.delete;

            select distinct ID_EXPO
              bulk collect into aIDs
              from EXPO_LIMITS
             where TYPE_LIMIT = ExpoLimit_ForApproval and
                   ID_LIMIT = IDOldMove;

            delete from EXPO_LIMITS
                  where TYPE_LIMIT = ExpoLimit_ForApproval and
                        ID_LIMIT = IDOldMove;

            if ( aIDs.count > 0 ) then
              for ii in aIDs.first .. aIDs.last loop
                SetMaxTriggNumber( 'ID_LASTLIMIT', aIDs( ii ) );
              end loop;
            end if;
          end if;
        else
          $if ( Schema_GPSys.OraSys.VerOverGas or
               Schema_GPSys.OraSys.VerUstoi ) $then
          insert into LOAN_MOVES(
                        ID_CRED_ENGAGE,
                        VALIOR,
                        ID_MOVE
                      )
            select distinct ID_CRED_ENGAGE,
                            VALIOR,
                            ID_MOVE
              from (select b.ID_CRED_ENGAGE as ID_CRED_ENGAGE,
                           a.Valior as VALIOR,
                           IDMove as ID_MOVE
                      from LOAN_EXPOSITION b,
                           table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                     where a.OperType not in (Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot) and
                           b.ID_EXPO = a.ExpoDt and
                           b.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                           b.TYPE_CRED_EXPO != Schema_GPSys.HeadExpo.ExpoCred_Obsujvashta
                    union all
                    select b.ID_CRED_ENGAGE as ID_CRED_ENGAGE,
                           a.Valior as VALIOR,
                           IDMove as ID_MOVE
                      from LOAN_EXPOSITION b,
                           table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                     where a.OperType not in (Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot) and
                           b.ID_EXPO = a.ExpoKt and
                           b.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                           b.TYPE_CRED_EXPO != Schema_GPSys.HeadExpo.ExpoCred_Obsujvashta);

          $end
          --
          $if ( Schema_GPSys.OraSys.VerCredito or Schema_GPSys.OraSys.VerFPMH ) $then
          if ( not GetSkipLimit( ModeSkip_ChkLastUseDate ) ) then
            for recOpers in ( select ID_CRED_ENGAGE,
                                     AMOUNT,
                                     Loans.GetLoanCodVal( ID_CRED_ENGAGE ) as CODVAL,
                                     IDMove as ID_MOVE,
                                     Loans.LoanStat_Registered as STATUS
                                from (  select ID_CRED_ENGAGE,
                                               nvl( sum( AMOUNT ), 0 ) as AMOUNT
                                          from (select b.ID_CRED_ENGAGE as ID_CRED_ENGAGE,
                                                       a.AmountDt as AMOUNT
                                                  from LOAN_EXPOSITION b,
                                                       table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                                 where a.OperType not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot) and
                                                       b.ID_EXPO = a.ExpoDt and
                                                       b.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                                                       b.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg
                                                union all
                                                select b.ID_CRED_ENGAGE as ID_CRED_ENGAGE,
                                                       -a.AmountKt as AMOUNT
                                                  from LOAN_EXPOSITION b,
                                                       table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                                 where a.OperType not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot) and
                                                       b.ID_EXPO = a.ExpoKt and
                                                       b.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                                                       b.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg)
                                      group by ID_CRED_ENGAGE
                                        having nvl( sum( AMOUNT ), 0 ) > 0) ) loop
              insert into LOAN_DRAWNS(
                            ID_CRED_ENGAGE,
                            CODVAL,
                            AMOUNT,
                            ID_MOVE,
                            STATUS
                          )
                   values ( recOpers.ID_CRED_ENGAGE,
                            recOpers.CODVAL,
                            recOpers.AMOUNT,
                            recOpers.ID_MOVE,
                            recOpers.STATUS
                           );

              for recCred in ( select ID_APPL
                                 from LOAN_CREDIT
                                where ID_CRED_ENGAGE = recOpers.ID_CRED_ENGAGE ) loop
                update LOAN_FAST_REQ
                   set DRAWDOWN  = 'T'
                 where ID_REQ = recCred.ID_APPL and
                       nvl( DRAWDOWN, 'F' ) = 'F';

                if ( sql%rowcount != 0 ) then
                  ExpFastLoanReq( recCred.ID_APPL );
                end if;

                exit;
              end loop;
            end loop;
          end if;

          $end
          null;
        end if;

        if ( bRet ) then
          if ( not bCashDoc ) then
            if ( nvl( IDOldMove, 0 ) > 0 ) then
              aIDs.delete;

              select distinct ID_EXPO
                bulk collect into aIDs
                from EXPO_LIMITS
               where TYPE_LIMIT = ExpoLimit_CashZapor and
                     ID_LIMIT in (select ID_CASH_DOC
                                    from CASH_DOCS
                                   where ID_MOVE = IDOldMove);

              delete from EXPO_LIMITS
                    where TYPE_LIMIT = ExpoLimit_CashZapor and
                          ID_LIMIT in (select ID_CASH_DOC
                                         from CASH_DOCS
                                        where ID_MOVE = IDOldMove);

              if ( aIDs.count > 0 ) then
                for ii in aIDs.first .. aIDs.last loop
                  SetMaxTriggNumber( 'ID_LASTLIMIT', aIDs( ii ) );
                end loop;
              end if;

              update CASH_DOCS
                 set STATUS  = Cash.CashDoc_Refused
               where ID_MOVE = IDOldMove;

              delete from CASH_BIG_OPERS
                    where ID_MOVE = IDOldMove;
            end if;
          else
            if ( aCashHead.count > 0 ) then
              for ii in aCashHead.first .. aCashHead.last loop
                nCashDoc  := Cash.GetCashNumber( 'ID_CASH_DOC' );

                insert into CASH_DOCS(
                              ID_CASH_DOC,
                              ID_CASH_SCH,
                              ID_MOVE,
                              UNIQCODE,
                              CASH_DATE,
                              STATUS,
                              ENTER_TIME,
                              ENTER_USER_ID
                            )
                     values ( nCashDoc,
                              aCashHead( ii ),
                              IDMove,
                              nUniqCode,
                              dSchDate,
                              Cash.CashDoc_Registered,
                              sysdate,
                              Schema_RA.GPC_RA.nCurrentUserID
                             );

                bRet      := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeCashDocs, nCashDoc );

                if ( bRet ) then
                  for jj in aCashRows.first .. aCashRows.last loop
                    if ( aCashHead( ii ) = aCashRows( jj ).nIDCash ) then
                      insert into CASH_DOC_ROWS(
                                    ID_CASH_DOC,
                                    IN_OUT,
                                    CODVAL,
                                    AMOUNT
                                  )
                           values ( nCashDoc,
                                    aCashRows( jj ).sInOut,
                                    aCashRows( jj ).sCodVal,
                                    aCashRows( jj ).nAmount
                                   );

                      if ( nvl( nCashLimit, -1 ) > 0 or
                          nvl( nDrawLimit, -1 ) > 0 ) then
                        nAmount      := Schema_GPSys.XchgRates.GetExactSum( aCashRows( jj ).nAmount,
                                                                            nUniqCode,
                                                                            dSchDate,
                                                                            aCashRows( jj ).sCodVal,
                                                                            Schema_GPSys.OraGPSys.SYS_CURR,
                                                                            Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                           );

                        if ( nvl( nDrawLimit, -1 ) > 0 and
                            aCashRows( jj ).sInOut = 'O' ) then
                          nAmountDraw  := nAmountDraw + nAmount;
                        end if;
                      end if;

                      if ( nvl( nIDCust, -1 ) > 0 and
                          ( nvl( rMemoOrderAdd.nModeOrigin, ModeCashBigOpers ) in (ModeCashMoneyGram, ModeCashOtherClient, ModeCashExternalClient, ModeCashCoins) or
                           nvl( nCashLimit, -1 ) > 0 ) ) then
                        if ( nAmount > 0 and
                            ( nvl( rMemoOrderAdd.nModeOrigin, ModeCashBigOpers ) in (ModeCashMoneyGram, ModeCashOtherClient, ModeCashExternalClient, ModeCashCoins) or
                             nAmount >= nCashLimit ) ) then
                          insert into CASH_BIG_OPERS(
                                        ID_CUST,
                                        CASH_DATE,
                                        IN_OUT,
                                        CODVAL,
                                        AMOUNT,
                                        SYS_AMOUNT,
                                        ID_CASH_DOC,
                                        ID_MOVE,
                                        OPER_TYPE,
                                        ID_RELCUST,
                                        ORIGIN
                                      )
                               values ( nIDCust,
                                        dSchDate,
                                        aCashRows( jj ).sInOut,
                                        aCashRows( jj ).sCodVal,
                                        aCashRows( jj ).nAmount,
                                        nAmount,
                                        nCashDoc,
                                        IDMove,
                                        nOperType,
                                        nvl( rMemoOrderAdd.nIDRelatedCust, 0 ),
                                        nvl( rMemoOrderAdd.nModeOrigin, ModeCashBigOpers )
                                       );
                        end if;
                      end if;
                    end if;
                  end loop;

                  if ( nvl( nDrawLimit, -1 ) > 0 and
                      nAmountDraw >= nDrawLimit ) then
                    update CASH_DOCS
                       set STATUS  = Cash.CashDoc_ForApproval
                     where ID_MOVE = IDMove;
                  end if;

                  -- касови запори
                  for rec in (  select sum( decode( b.Int1, a.ExpoDt, 0, -a.AmountDt ) + decode( b.Int1, a.ExpoKt, 0, a.AmountKt ) ) as Amount,
                                       decode( b.Int1, a.ExpoDt, a.ExpoKt, a.ExpoDt ) as IDExpo,
                                       decode( b.Int1, a.ExpoDt, a.ValKt, a.ValDt ) as CodVal,
                                       a.Valior as Valior
                                  from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a,
                                       table( cast( aCashExpos as Schema_GPSys.Tbl2Int ) ) b
                                 where a.ExpoDt != a.ExpoKt and
                                       ( a.ExpoDt = b.Int1 or
                                        a.ExpoKt = b.Int1 ) and
                                       b.Int2 = aCashHead( ii )
                              group by decode( b.Int1, a.ExpoDt, a.ExpoKt, a.ExpoDt ),
                                       decode( b.Int1, a.ExpoDt, a.ValKt, a.ValDt ),
                                       a.Valior ) loop
                    if ( rec.Amount > 0 and
                        ( nIDExpo4Zapor is not null or
                         ( nvl( Schema_GPSys.HeadExpo.IDExpo2IDCust( rec.IDExpo ), 0 ) > 0 and
                          Schema_GPSys.HeadExpo.IsItPasiveExpo( rec.IDExpo ) ) ) ) then
                      insert into EXPO_LIMITS(
                                    ID_LIMIT,
                                    TYPE_LIMIT,
                                    ID_EXPO,
                                    BEG_DATE,
                                    CODVAL,
                                    SUMLIMIT,
                                    STATUS,
                                    BEG_SYSDATE
                                  )
                           values ( nCashDoc,
                                    ExpoLimit_CashZapor,
                                    nvl( nIDExpo4Zapor, rec.IDExpo ),
                                    rec.Valior,
                                    rec.CodVal,
                                    rec.Amount,
                                    ZaporStat_Active,
                                    to_char( sysdate, Schema_GPSys.GPC_Parser.FORMAT_TRANSPORT_DATETIME )
                                   );

                      SetMaxTriggNumber( 'ID_LASTLIMIT', nvl( nIDExpo4Zapor, rec.IDExpo ) );
                    end if;
                  end loop;
                else
                  aParams.delete;
                  aParams( 1 ).ML_NAME   := 'CASH_DOC';
                  aParams( 1 ).ML_VALUE  := to_char( nCashDoc );
                  sError                 := Schema_GPSys.MLng.Str2( 'Не може да се заключи касов документ $CASH_DOC$',
                                                                    Schema_GPSys.MLng.ctxPayments,
                                                                    Schema_GPSys.MLng.lngBG,
                                                                    aParams
                                                                   );
                end if;

                exit when not bRet;
              end loop;
            end if;
          end if;
        end if;

        if ( bRet and
            aCredExpo.count > 0 ) then
          for ii in aCredExpo.first .. aCredExpo.last loop
            bRet  := Loans.ChangePadDate( aCredExpo( ii ).nIdExpo, aCredExpo( ii ).dValior, true );
            exit when not bRet;
          end loop;
        end if;

        if ( bRet ) then
          for recExpo in (  select sum( AMOUNT ) as AMOUNT,
                                   sum( MYSUM ) as MYSUM,
                                   ID_EXPO
                              from (select a.ExpoDt as ID_EXPO,
                                           -a.AmountDt as AMOUNT,
                                           decode( a.OperType, Cmd_Expo.Sch_Lihvi, 1, 0 ) as MYSUM
                                      from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                     where a.OperType not in (Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot)
                                    union all
                                    select a.ExpoKt as ID_EXPO,
                                           a.AmountKt as AMOUNT,
                                           decode( a.OperType, Cmd_Expo.Sch_Lihvi, 1, 0 ) as MYSUM
                                      from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                                     where a.OperType not in (Cmd_Expo.Sch_Preocenka, Cmd_Expo.Sch_ClearOborot))
                          group by ID_EXPO ) loop
            if ( case
                  when recExpo.MYSUM = 0 then recExpo.AMOUNT > 0
                  else recExpo.AMOUNT >= 0
                end ) then
              Expo.SetMaxTriggNumber( 'ID_EXPOMOVE', -recExpo.ID_EXPO );
            else
              Expo.SetMaxTriggNumber( 'ID_EXPOMOVE', recExpo.ID_EXPO );
            end if;
          end loop;
        end if;

        if ( bRet and
            aIDLimits1.count > 0 ) then
          for ii in aIDLimits1.first .. aIDLimits1.last loop
               update EXPO_LIMITS
                  set SUMLIMIT  = SUMLIMIT + aIDLimits2( ii )
                where rowid = aIDLimits1( ii )
            returning ID_EXPO
                 into nDummy;

            SetMaxTriggNumber( 'ID_LASTLIMIT', nDummy );
          end loop;
        end if;
      end if;
    end if;

    if ( bOldState is not null ) then
      bDummy  := SetSkipLimit( ModeSkip_Limit, bOldState );
    end if;

    if ( cOldActPass is not null ) then
      cDummy  := SetSkipActPass( cOldActPass );
    end if;

    return bRet;
  end ChkExpoOpers;

  --------------------------------------------------------------------------------
  function CanCloseExpo(
    nIDExpo     in integer,
    bSkipLoans  in boolean default false
  )
    return boolean is
    rExpoData              Schema_GPSys.EXPOSITION%rowtype;
    iqQ                    EmpCurTyp;
    nMain                  integer;
    nCards                 integer := 0;
    nDummy                 number;
    bRet                   boolean := true;
    sCurrentExpoTypes      varchar2( 4000 );
    sNoChk4TaxesExpoTypes  varchar2( 4000 );
    sMsg                   varchar2( 60 );
    aParams                Schema_RA.GPC_RA.tblErrParams;
  begin
    open iqQ for
      select ID_EXPO
        from CURRENT_EXPO
       where INT_EXPO = nIDExpo and
             ID_EXPO != INT_EXPO and
             STATUS = 'T'
      union all
      select ID_EXPO
        from CURRENT_EXPO
       where EXPO_TAX = nIDExpo and
             ID_EXPO != EXPO_TAX and
             STATUS = 'T';

    fetch iqQ
      into nMain;

    bRet  := iqQ%notfound;

    if ( not bRet ) then
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'ID_EXPO';
      aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
      aParams( 2 ).ML_NAME   := 'MAIN';
      aParams( 2 ).ML_VALUE  := to_char( nMain );
      Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $ID_EXPO$ е обвързана с експозиция $MAIN$', Schema_GPSys.MLng.ctxBudget, Schema_GPSys.MLng.lngBG, aParams );
    end if;

    close iqQ;

    if ( bRet ) then
      open iqQ for
        select ID_EXPO
          from DEPOSIT_EXPO
         where INT_EXPO = nIDExpo and
               ID_EXPO != INT_EXPO and
               STATUS = 'T'
        union all
        select ID_EXPO
          from DEPOSIT_EXPO
         where EXPO_TAX = nIDExpo and
               ID_EXPO != EXPO_TAX and
               STATUS = 'T'
        union all
        select ID_EXPO
          from DEPOSIT_EXPO
         where CLOSE_EXPO = nIDExpo and
               ID_EXPO != CLOSE_EXPO and
               STATUS = 'T';

      fetch iqQ
        into nMain;

      bRet  := iqQ%notfound;

      if ( not bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO';
        aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
        aParams( 2 ).ML_NAME   := 'MAIN';
        aParams( 2 ).ML_VALUE  := to_char( nMain );
        Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $ID_EXPO$ е обвързана с експозиция $MAIN$', Schema_GPSys.MLng.ctxBudget, Schema_GPSys.MLng.lngBG, aParams );
      end if;

      close iqQ;
    end if;

    if ( bRet and
        ( not bSkipLoans ) ) then
      open iqQ for
        select a.ID_CRED_ENGAGE
          from LOAN_EXPOSITION a,
               LOAN_CREDIT b
         where a.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
               a.ID_EXPO = nIDExpo and
               a.ID_CRED_ENGAGE = b.ID_CRED_ENGAGE and
               b.STATUS = 'T';

      fetch iqQ
        into nMain;

      bRet  := iqQ%notfound;

      if ( not bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO';
        aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
        aParams( 2 ).ML_NAME   := 'MAIN';
        aParams( 2 ).ML_VALUE  := to_char( nMain );
        Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $ID_EXPO$ е обвързана с кредит $MAIN$', Schema_GPSys.MLng.ctxBudget, Schema_GPSys.MLng.lngBG, aParams );
      end if;

      close iqQ;
    end if;

    if ( bRet ) then
      open iqQ for
        select a.ID_CRED_ENGAGE
          from LOAN_EXPOSITION a,
               LOAN_ENGAGE b
         where a.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpEngage and
               a.ID_EXPO = nIDExpo and
               a.ID_CRED_ENGAGE = b.ID_CRED_ENGAGE and
               b.STATUS = 'T';

      fetch iqQ
        into nMain;

      bRet  := iqQ%notfound;

      if ( not bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO';
        aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
        aParams( 2 ).ML_NAME   := 'MAIN';
        aParams( 2 ).ML_VALUE  := to_char( nMain );
        Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $ID_EXPO$ е обвързана с ангажимент $MAIN$', Schema_GPSys.MLng.ctxBudget, Schema_GPSys.MLng.lngBG, aParams );
      end if;

      close iqQ;
    end if;

    if ( bRet ) then
      open iqQ for
        select ID_MKU
          from LOAN_MKU
         where nIDExpo in (nvl( ID_EXPO, 0 ), nvl( ID_EXPO1, 0 ), nvl( ID_EXPO2, 0 ), nvl( ID_EXPO3, 0 )) and
               STATUS = Loans.LoanStat_Active;

      fetch iqQ
        into nMain;

      bRet  := iqQ%notfound;

      if ( not bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO';
        aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
        aParams( 2 ).ML_NAME   := 'MAIN';
        aParams( 2 ).ML_VALUE  := to_char( nMain );
        Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $ID_EXPO$ е обвързана с МКУ $MAIN$', Schema_GPSys.MLng.ctxBudget, Schema_GPSys.MLng.lngBG, aParams );
      end if;

      close iqQ;
    end if;

    if ( bRet ) then
      open iqQ for
        select ID_EXPO
          from EXPO_LIMITS
         where ID_EXPO = nIDExpo and
               ( TYPE_LIMIT in
                  ( ExpoLimit_CashZapor,
                   ExpoLimit_CredPadej,
                   ExpoLimit_NormalZapor,
                   ExpoLimit_NormalZapor1,
                   ExpoLimit_NormalZapor2,
                   ExpoLimit_NormalZapor3,
                   ExpoLimit_NormalZapor4,
                   ExpoLimit_NormalZapor5,
                   ExpoLimit_NormalZapor6,
                   ExpoLimit_NormalZapor7,
                   ExpoLimit_NormalZapor8,
                   ExpoLimit_NormalZapor9,
                   ExpoLimit_SudebenZapor,
                   ExpoLimit_SudebenPrc,
                   ExpoLimit_ContrFinCover,
                   ExpoLimit_SudebenIntrnl,
                   ExpoLimit_SudebenExtrnl ) or
                IsZaporInternal( TYPE_LIMIT, 1 ) = 'T' ) and
               STATUS = ZaporStat_Active;

      fetch iqQ
        into nMain;

      bRet  := iqQ%notfound;

      $if ( Schema_GPSys.OraSys.VerTFS ) $then
      if ( bRet ) then
        select count( 1 )
          into nDummy
          from Schema_ImportExport.EXPO_LIMITS_EXT
         where ID_EXPO = nIDExpo and
               STATUS in (ZaporStat_Active, 'c');

        bRet  := nDummy = 0;
      end if;

      $end
      --
      if ( not bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO';
        aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
        Schema_RA.GPC_RA.RespSetErrorText( 'Активни запори по експозиция $ID_EXPO$', Schema_GPSys.MLng.ctxBudget, Schema_GPSys.MLng.lngBG, aParams );
      end if;

      close iqQ;
    end if;

    if ( bRet ) then
      open iqQ for
        select /*+ index( a loantaxes_id ) index( b loantaxes_plan_idtax )*/
              a.IDTAXEXPO
          from LOANTAXES a,
               LOANTAXES_PLAN b
         where a.IDTAXEXPO = nIDExpo and
               a.STATUS = Cmd_LoanTaxes.LoanTaxStatus_Oschetovodena and
               a.IDTAX = b.IDTAX and
               b.STATUS in (Cmd_LoanTaxes.LoanTaxPlanStatus_Oschetovoden, Cmd_LoanTaxes.LoanTaxPlanStatus_Registriran);

      fetch iqQ
        into nMain;

      bRet  := iqQ%notfound;

      if ( not bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO';
        aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
        Schema_RA.GPC_RA.RespSetErrorText( 'Активни такси по кредит/ангажимент към експозиция $ID_EXPO$',
                                           Schema_GPSys.MLng.ctxBudget,
                                           Schema_GPSys.MLng.lngBG,
                                           aParams
                                          );
      end if;

      close iqQ;
    end if;

    if ( bRet ) then
      if ( Schema_GPSys.OraSys.bModule_Cards ) then
        execute immediate 'begin Schema_Cards.BORICA.CalcBoricaCards4Expo (:1, :2); end;' using in nIDExpo, out nCards;

        if ( nCards > 0 ) then
          bRet                   := false;
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ID_EXPO';
          aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
          Schema_RA.GPC_RA.RespSetErrorText( 'Активни карти по експозиция $ID_EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
        end if;

        if ( bRet ) then
          execute immediate 'begin Schema_Cards.BORICA.IsPartOfBuyAndSaveService (:1, :2, :3 ); end;' using in nIDExpo, out nCards, in 'F';

          if ( nCards > 0 ) then
            bRet                   := false;
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
            Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $ID_EXPO$ участва в услугата „КУПИ И СПЕСТИ”',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;
        end if;

        if ( bRet ) then
          execute immediate 'begin Schema_Cards.BORICA.IsExpoConnToBlockCard (:1, :2); end;' using in nIDExpo, out nCards;

          if ( nCards > 0 ) then
            bRet                   := false;
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
            aParams( 2 ).ML_NAME   := 'CARDS';
            aParams( 2 ).ML_VALUE  := to_char( nCards );
            Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $ID_EXPO$ е свързана с блокирана на закриване карта No$CARDS$ с неизтекъл срок за освобождаване на експозицията',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;
        end if;
      end if;
    end if;

    if ( bRet ) then
      if ( Schema_GPSys.OraSys.bModule_Payments ) then
        begin
          execute immediate 'SELECT count(1) FROM Schema_Payments.PAYS_DATA4PREVOD WHERE EXPO_RCV = :1 and STATUS = :2' into nCards using nIDExpo, 'T';

          if ( nCards = 0 ) then
            execute immediate 'SELECT count(1) FROM Schema_Payments.PAYS_DATA4PREVOD WHERE ID_EXPO  = :1 and STATUS = :2' into nCards using nIDExpo, 'T';
          end if;
        exception
          when others then
            nCards  := 0;
        end;

        if ( nCards > 0 ) then
          bRet                   := false;
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ID_EXPO';
          aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
          Schema_RA.GPC_RA.RespSetErrorText( 'Активни шаблони за преводи по експозиция $ID_EXPO$',
                                             Schema_GPSys.MLng.ctxAccounting,
                                             Schema_GPSys.MLng.lngBG,
                                             aParams
                                            );
        end if;
      end if;
    end if;

    if ( bRet ) then
      rExpoData  := Schema_GPSys.HeadExpo.IDExpo2ExpoData( nIDExpo );

      if ( rExpoData.ID_CUST > 0 ) then
        nCards                 := 0;
        sNoChk4TaxesExpoTypes  := Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'NOCHK4TAXES_EXPO_TYPES', '0' );

        if ( not ( sNoChk4TaxesExpoTypes like '%&' || to_char( rExpoData.TYPE_EXPO ) || '&%' ) ) then
          sMsg  := Schema_GPSys.MLng.Str2( 'Активни дължими такси', Schema_GPSys.MLng.ctxTaxes, Schema_GPSys.MLng.lngBG );

          select count( 1 )
            into nCards
            from (select ID_PAYTAX as ID_TAX
                    from TAXES_TAXLIST
                   where ID_CUST = rExpoData.ID_CUST and
                         TAX_STATUS = Taxes.TaxStateNoSch
                  union all
                  select ID_TAX as ID_TAX
                    from TAXES_REGISTER
                   where ID_CUST = rExpoData.ID_CUST and
                         TAX_STATUS = Taxes.TaxStateNoSch);
        end if;

        sCurrentExpoTypes      := Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'CURRENT_EXPO_TYPES', '0' );

        if ( nCards = 0 and
            sCurrentExpoTypes like '%&' || to_char( rExpoData.TYPE_EXPO ) || '&%' ) then
          sMsg  := Schema_GPSys.MLng.Str2( 'Aктивна регистрация за Коменс Брокер', Schema_GPSys.MLng.ctxBudget, Schema_GPSys.MLng.lngBG );

          select count( 1 )
            into nCards
            from Schema_GPSys.MSGCONF
           where ID_OBJECT = rExpoData.ID_CUST and
                 MODE_OBJECT = Schema_GPSys.Cmd_OraGPSys.nModeObj_Cust and
                 TECHNOLOGY = Schema_GPSys.Cmd_OraGPSys.nModeTech_Comens and
                 ACTIVE = 'T';
        end if;

        if ( nCards > 0 ) then
          select count( 1 )
            into nCards
            from Schema_GPSys.EXPOSITION a
           where a.ID_CUST = rExpoData.ID_CUST and
                 a.ID_EXPO != nIDExpo and
                 a.STATUS = 'T' and
                 sCurrentExpoTypes like '%&' || to_char( a.TYPE_EXPO ) || '&%';

          bRet  := nCards > 0;

          if ( not bRet ) then
            Schema_RA.GPC_RA.RespSetErrorText_NoML( sMsg );
          end if;
        end if;
      end if;
    end if;

    return bRet;
  end CanCloseExpo;

  --------------------------------------------------------------------------------
  function ESysSaldoDate(
    nIDExpo    in     integer,
    dToDate    in     date,
    bValior    in     boolean,
    nOborDt    in out number,
    nOborKt    in out number,
    bSkipOper  in     boolean default false
  )
    return number is
    nOper  pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    nOborDt  := 0;
    nOborKt  := 0;

    if ( bValior ) then
      select sum( ObDT ),
             sum( ObKT )
        into nOborDt,
             nOborKt
        from (select nvl( SYS_OBOR_DT, 0 ) as ObDT,
                     nvl( SYS_OBOR_KT, 0 ) as ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
              union all
              select sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     VALIOR > dToDate and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));
    else
      select sum( ObDT ),
             sum( ObKT )
        into nOborDt,
             nOborKt
        from (select nvl( SYS_OBOR_DT, 0 ) as ObDT,
                     nvl( SYS_OBOR_KT, 0 ) as ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
              union all
              select sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     SCH_DATE > dToDate and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));
    end if;

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );
    return nOborKt - nOborDt;
  end ESysSaldoDate;

  --------------------------------------------------------------------------------
  function EAddSaldoDate(
    nIDExpo    in     integer,
    dToDate    in     date,
    bValior    in     boolean,
    nOborDt    in out number,
    nOborKt    in out number,
    bSkipOper  in     boolean default false
  )
    return number is
    nOper  pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    nOborDt  := 0;
    nOborKt  := 0;

    if ( bValior ) then
      select sum( ObDT ),
             sum( ObKT )
        into nOborDt,
             nOborKt
        from (select nvl( ADD_OBOR_DT, 0 ) as ObDT,
                     nvl( ADD_OBOR_KT, 0 ) as ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select sum( decode( DT_KT, 'D', ADD_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', ADD_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
              union all
              select sum( decode( DT_KT, 'D', -ADD_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -ADD_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     VALIOR > dToDate and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));
    else
      select sum( ObDT ),
             sum( ObKT )
        into nOborDt,
             nOborKt
        from (select nvl( ADD_OBOR_DT, 0 ) as ObDT,
                     nvl( ADD_OBOR_KT, 0 ) as ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select sum( decode( DT_KT, 'D', ADD_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', ADD_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
              union all
              select sum( decode( DT_KT, 'D', -ADD_AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -ADD_AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     SCH_DATE > dToDate and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));
    end if;

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );
    return nOborKt - nOborDt;
  end EAddSaldoDate;

  --------------------------------------------------------------------------------
  function CalcESysSaldo(
    nIDExpo   in integer,
    dToDate   in date,
    bValior   in boolean default false,
    bVPeriod  in boolean default false
  )
    return number is
    nSaldo  number := 0;
  begin
    if ( bValior ) then
      if ( bVPeriod ) then
        select sum( Amn )
          into nSaldo
          from (select nvl( SYS_OBOR_KT, 0 ) - nvl( SYS_OBOR_DT, 0 ) as Amn
                  from EXPO_STATE
                 where ID_EXPO = nIDExpo
                union all
                select sum( decode( DT_KT, 'D', -SYS_AMOUNT, SYS_AMOUNT ) ) as Amn
                  from EXPO_MOVES
                 where ID_EXPO = nIDExpo and
                       CH_STAMP = 0
                union all
                select sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as Amn
                  from EXPO_MOVES
                 where ID_EXPO = nIDExpo and
                       VALIOR_PERIOD > dToDate);
      else
        select sum( Amn )
          into nSaldo
          from (select nvl( SYS_OBOR_KT, 0 ) - nvl( SYS_OBOR_DT, 0 ) as Amn
                  from EXPO_STATE
                 where ID_EXPO = nIDExpo
                union all
                select sum( decode( DT_KT, 'D', -SYS_AMOUNT, SYS_AMOUNT ) ) as Amn
                  from EXPO_MOVES
                 where ID_EXPO = nIDExpo and
                       CH_STAMP = 0
                union all
                select sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as Amn
                  from EXPO_MOVES
                 where ID_EXPO = nIDExpo and
                       VALIOR > dToDate);
      end if;
    else
      select sum( Amn )
        into nSaldo
        from (select nvl( SYS_OBOR_KT, 0 ) - nvl( SYS_OBOR_DT, 0 ) as Amn
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select sum( decode( DT_KT, 'D', -SYS_AMOUNT, SYS_AMOUNT ) ) as Amn
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0
              union all
              select sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as Amn
                from EXPO_MOVES
               where ID_EXPO = nIDExpo and
                     SCH_DATE > dToDate);
    end if;

    return nvl( nSaldo, 0 );
  end CalcESysSaldo;

  --------------------------------------------------------------------------------
  function EAllSaldoDate(
    nIDExpo         in     integer,
    dToDate         in     date,
    bValior         in     boolean,
    nOrgOborDt      in out number,
    nOrgOborKt      in out number,
    nSysOborDt      in out number,
    nSysOborKt      in out number,
    bSkipOper       in     boolean default false,
    bValiorPeriod   in     boolean default false,
    bNoStornoMoves  in     boolean default false
  )
    return number is
    nOper              pls_integer := 0;
    nNoStorno          pls_integer := 0;
    pSkipImportOborot  varchar2( 1 ) := sSkipImportOborot;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    if ( bNoStornoMoves ) then
      nNoStorno  := 1;
    end if;

    nOrgOborDt  := 0;
    nOrgOborKt  := 0;
    nSysOborDt  := 0;
    nSysOborKt  := 0;

    if ( bValior ) then
      if ( bValiorPeriod ) then
        select sum( ORG_ObDT ),
               sum( ORG_ObKT ),
               sum( SYS_ObDT ),
               sum( SYS_ObKT )
          into nOrgOborDt,
               nOrgOborKt,
               nSysOborDt,
               nSysOborKt
          from (select /*+ index( expo_state expo_state )*/
                      nvl( OBOR_DT, 0 ) as ORG_ObDT,
                       nvl( OBOR_KT, 0 ) as ORG_ObKT,
                       nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                       nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT
                  from EXPO_STATE
                 where ID_EXPO = nIDExpo
                union all
                select /*+ index( a expo_moves_ch )*/
                      sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       CH_STAMP = 0 and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot )
                union all
                select /*+ index( a expo_moves_epeiod )*/
                      sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as SYS_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       VALIOR_PERIOD > dToDate and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot ));
      else
        select sum( ORG_ObDT ),
               sum( ORG_ObKT ),
               sum( SYS_ObDT ),
               sum( SYS_ObKT )
          into nOrgOborDt,
               nOrgOborKt,
               nSysOborDt,
               nSysOborKt
          from (select /*+ index( expo_state expo_state )*/
                      nvl( OBOR_DT, 0 ) as ORG_ObDT,
                       nvl( OBOR_KT, 0 ) as ORG_ObKT,
                       nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                       nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT
                  from EXPO_STATE
                 where ID_EXPO = nIDExpo
                union all
                select /*+ index( a expo_moves_ch )*/
                      sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       CH_STAMP = 0 and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot )
                union all
                select /*+ index( a expo_moves_valior )*/
                      sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as SYS_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       VALIOR > dToDate and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot ));
      end if;
    else
      select sum( ORG_ObDT ),
             sum( ORG_ObKT ),
             sum( SYS_ObDT ),
             sum( SYS_ObKT )
        into nOrgOborDt,
             nOrgOborKt,
             nSysOborDt,
             nSysOborKt
        from (select /*+ index( expo_state expo_state )*/
                    nvl( OBOR_DT, 0 ) as ORG_ObDT,
                     nvl( OBOR_KT, 0 ) as ORG_ObKT,
                     nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                     nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select /*+ index( a expo_moves_ch )*/
                    sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     ( pSkipImportOborot = 'F' or
                      OPER_TYPE != Cmd_Expo.Sch_ImportOborot )
              union all
              select /*+ index( a expo_moves_date )*/
                    sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as SYS_ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     SCH_DATE > dToDate and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     ( pSkipImportOborot = 'F' or
                      OPER_TYPE != Cmd_Expo.Sch_ImportOborot ));
    end if;

    nOrgOborDt  := nvl( nOrgOborDt, 0 );
    nOrgOborKt  := nvl( nOrgOborKt, 0 );
    nSysOborDt  := nvl( nSysOborDt, 0 );
    nSysOborKt  := nvl( nSysOborKt, 0 );
    return nOrgOborKt - nOrgOborDt;
  end EAllSaldoDate;

  --------------------------------------------------------------------------------
  function EAllSaldoDate(
    nIDExpo         in     integer,
    dToDate         in     date,
    bValior         in     boolean,
    nOrgOborDt      in out number,
    nOrgOborKt      in out number,
    nSysOborDt      in out number,
    nSysOborKt      in out number,
    nAddOborDt      in out number,
    nAddOborKt      in out number,
    bSkipOper       in     boolean default false,
    bValiorPeriod   in     boolean default false,
    bNoStornoMoves  in     boolean default false
  )
    return number is
    nOper              pls_integer := 0;
    nNoStorno          pls_integer := 0;
    pSkipImportOborot  varchar2( 1 ) := sSkipImportOborot;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    if ( bNoStornoMoves ) then
      nNoStorno  := 1;
    end if;

    nOrgOborDt  := 0;
    nOrgOborKt  := 0;
    nSysOborDt  := 0;
    nSysOborKt  := 0;
    nAddOborDt  := 0;
    nAddOborKt  := 0;

    if ( bValior ) then
      if ( bValiorPeriod ) then
        select sum( ORG_ObDT ),
               sum( ORG_ObKT ),
               sum( SYS_ObDT ),
               sum( SYS_ObKT ),
               sum( ADD_ObDT ),
               sum( ADD_ObKT )
          into nOrgOborDt,
               nOrgOborKt,
               nSysOborDt,
               nSysOborKt,
               nAddOborDt,
               nAddOborKt
          from (select /*+ index( expo_state expo_state )*/
                      nvl( OBOR_DT, 0 ) as ORG_ObDT,
                       nvl( OBOR_KT, 0 ) as ORG_ObKT,
                       nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                       nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT,
                       nvl( ADD_OBOR_DT, 0 ) as ADD_ObDT,
                       nvl( ADD_OBOR_KT, 0 ) as ADD_ObKT
                  from EXPO_STATE
                 where ID_EXPO = nIDExpo
                union all
                select /*+ index( a expo_moves_ch )*/
                      sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_ObKT,
                       sum( decode( DT_KT, 'D', ADD_AMOUNT, 0 ) ) as ADD_ObDT,
                       sum( decode( DT_KT, 'K', ADD_AMOUNT, 0 ) ) as ADD_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       CH_STAMP = 0 and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot )
                union all
                select /*+ index( a expo_moves_epeiod )*/
                      sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as SYS_ObKT,
                       sum( decode( DT_KT, 'D', -ADD_AMOUNT, 0 ) ) as ADD_ObDT,
                       sum( decode( DT_KT, 'K', -ADD_AMOUNT, 0 ) ) as ADD_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       VALIOR_PERIOD > dToDate and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot ));
      else
        select sum( ORG_ObDT ),
               sum( ORG_ObKT ),
               sum( SYS_ObDT ),
               sum( SYS_ObKT ),
               sum( ADD_ObDT ),
               sum( ADD_ObKT )
          into nOrgOborDt,
               nOrgOborKt,
               nSysOborDt,
               nSysOborKt,
               nAddOborDt,
               nAddOborKt
          from (select /*+ index( expo_state expo_state )*/
                      nvl( OBOR_DT, 0 ) as ORG_ObDT,
                       nvl( OBOR_KT, 0 ) as ORG_ObKT,
                       nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                       nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT,
                       nvl( ADD_OBOR_DT, 0 ) as ADD_ObDT,
                       nvl( ADD_OBOR_KT, 0 ) as ADD_ObKT
                  from EXPO_STATE
                 where ID_EXPO = nIDExpo
                union all
                select /*+ index( a expo_moves_ch )*/
                      sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_ObKT,
                       sum( decode( DT_KT, 'D', ADD_AMOUNT, 0 ) ) as ADD_ObDT,
                       sum( decode( DT_KT, 'K', ADD_AMOUNT, 0 ) ) as ADD_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       CH_STAMP = 0 and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot )
                union all
                select /*+ index( a expo_moves_valior )*/
                      sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                       sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT,
                       sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                       sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as SYS_ObKT,
                       sum( decode( DT_KT, 'D', -ADD_AMOUNT, 0 ) ) as ADD_ObDT,
                       sum( decode( DT_KT, 'K', -ADD_AMOUNT, 0 ) ) as ADD_ObKT
                  from EXPO_MOVES a
                 where ID_EXPO = nIDExpo and
                       VALIOR > dToDate and
                       ( nNoStorno = 0 or
                        ( not exists
                           (select 1
                              from EXPO_STRNMOVES b
                             where b.ID_MOVE_NEW = a.ID_MOVE) and
                         not exists
                           (select 1
                              from EXPO_STRNMOVES c
                             where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                       ( pSkipImportOborot = 'F' or
                        OPER_TYPE != Cmd_Expo.Sch_ImportOborot ));
      end if;
    else
      select sum( ORG_ObDT ),
             sum( ORG_ObKT ),
             sum( SYS_ObDT ),
             sum( SYS_ObKT ),
             sum( ADD_ObDT ),
             sum( ADD_ObKT )
        into nOrgOborDt,
             nOrgOborKt,
             nSysOborDt,
             nSysOborKt,
             nAddOborDt,
             nAddOborKt
        from (select /*+ index( expo_state expo_state )*/
                    nvl( OBOR_DT, 0 ) as ORG_ObDT,
                     nvl( OBOR_KT, 0 ) as ORG_ObKT,
                     nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                     nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT,
                     nvl( ADD_OBOR_DT, 0 ) as ADD_ObDT,
                     nvl( ADD_OBOR_KT, 0 ) as ADD_ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select /*+ index( a expo_moves_ch )*/
                    sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_ObKT,
                     sum( decode( DT_KT, 'D', ADD_AMOUNT, 0 ) ) as ADD_ObDT,
                     sum( decode( DT_KT, 'K', ADD_AMOUNT, 0 ) ) as ADD_ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     ( pSkipImportOborot = 'F' or
                      OPER_TYPE != Cmd_Expo.Sch_ImportOborot )
              union all
              select /*+ index( a expo_moves_date )*/
                    sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( DT_KT, 'D', -SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( DT_KT, 'K', -SYS_AMOUNT, 0 ) ) as SYS_ObKT,
                     sum( decode( DT_KT, 'D', -ADD_AMOUNT, 0 ) ) as ADD_ObDT,
                     sum( decode( DT_KT, 'K', -ADD_AMOUNT, 0 ) ) as ADD_ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     SCH_DATE > dToDate and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     ( pSkipImportOborot = 'F' or
                      OPER_TYPE != Cmd_Expo.Sch_ImportOborot ));
    end if;

    nOrgOborDt  := nvl( nOrgOborDt, 0 );
    nOrgOborKt  := nvl( nOrgOborKt, 0 );
    nSysOborDt  := nvl( nSysOborDt, 0 );
    nSysOborKt  := nvl( nSysOborKt, 0 );
    nAddOborDt  := nvl( nAddOborDt, 0 );
    nAddOborKt  := nvl( nAddOborKt, 0 );
    return nOrgOborKt - nOrgOborDt;
  end EAllSaldoDate;

  --------------------------------------------------------------------------------
  function EBDGAllSaldoDate(
    nIDExpo       in     integer,
    sBDGClassif   in     varchar2,
    sBDGFunction  in     varchar2,
    sBDGObject    in     varchar2,
    dToDate       in     date,
    bValior       in     boolean,
    nOrgOborDt    in out number,
    nOrgOborKt    in out number,
    nSysOborDt    in out number,
    nSysOborKt    in out number,
    bSkipOper     in     boolean default false
  )
    return number is
    nOper  pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    nOrgOborDt  := 0;
    nOrgOborKt  := 0;
    nSysOborDt  := 0;
    nSysOborKt  := 0;

    if ( bValior ) then
      select sum( ORG_ObDT ),
             sum( ORG_ObKT ),
             sum( SYS_ObDT ),
             sum( SYS_ObKT )
        into nOrgOborDt,
             nOrgOborKt,
             nSysOborDt,
             nSysOborKt
        from (select nvl( OBOR_DT, 0 ) as ORG_ObDT,
                     nvl( OBOR_KT, 0 ) as ORG_ObKT,
                     nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                     nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT
                from BDG_EXPO_STATE
               where ID_EXPO = nIDExpo and
                     BDG_CLASSIF = sBDGClassif and
                     BDG_FUNCTION = sBDGFunction and
                     BDG_OBJECT = sBDGObject
              union all
              select sum( decode( a.DT_KT, 'D', a.AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( a.DT_KT, 'K', a.AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( a.DT_KT, 'D', a.SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( a.DT_KT, 'K', a.SYS_AMOUNT, 0 ) ) as SYS_ObKT
                from BDG_MOVES b,
                     EXPO_MOVES a
               where a.ID_EXPO = nIDExpo and
                     a.ID_MOVE = b.ID_MOVE and
                     a.ORDROWNUM = b.ORDROWNUM and
                     b.BDG_CLASSIF = sBDGClassif and
                     b.BDG_FUNCTION = sBDGFunction and
                     b.BDG_OBJECT = sBDGObject and
                     a.CH_STAMP = 0 and
                     ( nOper = 0 or
                      a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
              union all
              select sum( decode( a.DT_KT, 'D', -a.AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( a.DT_KT, 'K', -a.AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( a.DT_KT, 'D', -a.SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( a.DT_KT, 'K', -a.SYS_AMOUNT, 0 ) ) as SYS_ObKT
                from BDG_MOVES b,
                     EXPO_MOVES a
               where a.ID_EXPO = nIDExpo and
                     a.ID_MOVE = b.ID_MOVE and
                     a.ORDROWNUM = b.ORDROWNUM and
                     b.BDG_CLASSIF = sBDGClassif and
                     b.BDG_FUNCTION = sBDGFunction and
                     b.BDG_OBJECT = sBDGObject and
                     a.VALIOR > dToDate and
                     ( nOper = 0 or
                      a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));
    else
      select sum( ORG_ObDT ),
             sum( ORG_ObKT ),
             sum( SYS_ObDT ),
             sum( SYS_ObKT )
        into nOrgOborDt,
             nOrgOborKt,
             nSysOborDt,
             nSysOborKt
        from (select nvl( OBOR_DT, 0 ) as ORG_ObDT,
                     nvl( OBOR_KT, 0 ) as ORG_ObKT,
                     nvl( SYS_OBOR_DT, 0 ) as SYS_ObDT,
                     nvl( SYS_OBOR_KT, 0 ) as SYS_ObKT
                from BDG_EXPO_STATE
               where ID_EXPO = nIDExpo and
                     BDG_CLASSIF = sBDGClassif and
                     BDG_FUNCTION = sBDGFunction and
                     BDG_OBJECT = sBDGObject
              union all
              select sum( decode( a.DT_KT, 'D', a.AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( a.DT_KT, 'K', a.AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( a.DT_KT, 'D', a.SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( a.DT_KT, 'K', a.SYS_AMOUNT, 0 ) ) as SYS_ObKT
                from BDG_MOVES b,
                     EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     a.ID_MOVE = b.ID_MOVE and
                     a.ORDROWNUM = b.ORDROWNUM and
                     b.BDG_CLASSIF = sBDGClassif and
                     b.BDG_FUNCTION = sBDGFunction and
                     b.BDG_OBJECT = sBDGObject and
                     a.CH_STAMP = 0 and
                     ( nOper = 0 or
                      a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
              union all
              select sum( decode( a.DT_KT, 'D', -a.AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( a.DT_KT, 'K', -a.AMOUNT, 0 ) ) as ORG_ObKT,
                     sum( decode( a.DT_KT, 'D', -a.SYS_AMOUNT, 0 ) ) as SYS_ObDT,
                     sum( decode( a.DT_KT, 'K', -a.SYS_AMOUNT, 0 ) ) as SYS_ObKT
                from BDG_MOVES b,
                     EXPO_MOVES a
               where a.ID_EXPO = nIDExpo and
                     a.ID_MOVE = b.ID_MOVE and
                     a.ORDROWNUM = b.ORDROWNUM and
                     b.BDG_CLASSIF = sBDGClassif and
                     b.BDG_FUNCTION = sBDGFunction and
                     b.BDG_OBJECT = sBDGObject and
                     a.SCH_DATE > dToDate and
                     ( nOper = 0 or
                      a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));
    end if;

    nOrgOborDt  := nvl( nOrgOborDt, 0 );
    nOrgOborKt  := nvl( nOrgOborKt, 0 );
    return nOrgOborKt - nOrgOborDt;
  end EBDGAllSaldoDate;

  --------------------------------------------------------------------------------
  function EAddAllSaldoDate(
    nIDExpo         in     integer,
    sAddClassif     in     varchar2,
    dToDate         in     date,
    bValior         in     boolean,
    nOrgOborDt      in out number,
    nOrgOborKt      in out number,
    bNoStornoMoves  in     boolean default false
  )
    return number is
    nNoStorno  pls_integer := 0;
  begin
    if ( bNoStornoMoves ) then
      nNoStorno  := 1;
    end if;

    nOrgOborDt  := 0;
    nOrgOborKt  := 0;

    if ( bValior ) then
      select sum( ORG_ObDT ),
             sum( ORG_ObKT )
        into nOrgOborDt,
             nOrgOborKt
        from (select /*+ index( add_expo_state add_expo_state )*/
                    nvl( OBOR_DT, 0 ) as ORG_ObDT,
                     nvl( OBOR_KT, 0 ) as ORG_ObKT
                from ADD_EXPO_STATE
               where ID_EXPO = nIDExpo and
                     ADD_CLASSIF = sAddClassif
              union all
              select /*+ index( a add_moves_stamp )*/
                    sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT
                from ADD_MOVES a
               where ID_EXPO = nIDExpo and
                     ADD_CLASSIF = sAddClassif and
                     CH_STAMP = 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) )
              union all
              select /*+ index( a add_moves_valior )*/
                    sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT
                from ADD_MOVES a
               where ID_EXPO = nIDExpo and
                     ADD_CLASSIF = sAddClassif and
                     VALIOR > dToDate and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ));
    else
      select sum( ORG_ObDT ),
             sum( ORG_ObKT )
        into nOrgOborDt,
             nOrgOborKt
        from (select /*+ index( add_expo_state add_expo_state )*/
                    nvl( OBOR_DT, 0 ) as ORG_ObDT,
                     nvl( OBOR_KT, 0 ) as ORG_ObKT
                from ADD_EXPO_STATE
               where ID_EXPO = nIDExpo and
                     ADD_CLASSIF = sAddClassif
              union all
              select /*+ index( a add_moves_stamp )*/
                    sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_ObKT
                from ADD_MOVES a
               where ID_EXPO = nIDExpo and
                     ADD_CLASSIF = sAddClassif and
                     CH_STAMP = 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) )
              union all
              select /*+ index( a add_moves_date )*/
                    sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ORG_ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ORG_ObKT
                from ADD_MOVES a
               where ID_EXPO = nIDExpo and
                     ADD_CLASSIF = sAddClassif and
                     SCH_DATE > dToDate and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ));
    end if;

    nOrgOborDt  := nvl( nOrgOborDt, 0 );
    nOrgOborKt  := nvl( nOrgOborKt, 0 );
    return nOrgOborKt - nOrgOborDt;
  end EAddAllSaldoDate;

  --------------------------------------------------------------------------------
  function ExpoSaldoDate(
    nIDExpo         in     integer,
    dToDate         in     date,
    bValior         in     boolean,
    nOborDt         in out number,
    nOborKt         in out number,
    bSkipOper       in     boolean default false,
    bNoStornoMoves  in     boolean default false
  )
    return number is
    nOper      pls_integer := 0;
    nNoStorno  pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    if ( bNoStornoMoves ) then
      nNoStorno  := 1;
    end if;

    nOborDt  := 0;
    nOborKt  := 0;

    if ( bValior ) then
      select sum( ObDT ),
             sum( ObKT )
        into nOborDt,
             nOborKt
        from (select nvl( OBOR_DT, 0 ) as ObDT,
                     nvl( OBOR_KT, 0 ) as ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select /*+ index( a EXPO_MOVES_STAMP ) */
                    sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     AMOUNT != 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     OPER_TYPE != Cmd_Expo.Sch_ImportOborot
              union all
              select /*+ index( a EXPO_MOVES_VALIOR ) */
                    sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     VALIOR > dToDate and
                     AMOUNT != 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     OPER_TYPE != Cmd_Expo.Sch_ImportOborot
              union all
              select sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES_OLD a
               where ID_EXPO = nIDExpo and
                     VALIOR > dToDate);
    else
      select sum( ObDT ),
             sum( ObKT )
        into nOborDt,
             nOborKt
        from (select nvl( OBOR_DT, 0 ) as ObDT,
                     nvl( OBOR_KT, 0 ) as ObKT
                from EXPO_STATE
               where ID_EXPO = nIDExpo
              union all
              select /*+ index( a EXPO_MOVES_STAMP ) */
                    sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     CH_STAMP = 0 and
                     AMOUNT != 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     OPER_TYPE != Cmd_Expo.Sch_ImportOborot
              union all
              select /*+ index( a EXPO_MOVES_DATE ) */
                    sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES a
               where ID_EXPO = nIDExpo and
                     SCH_DATE > dToDate and
                     AMOUNT != 0 and
                     ( nNoStorno = 0 or
                      ( not exists
                         (select 1
                            from EXPO_STRNMOVES b
                           where b.ID_MOVE_NEW = a.ID_MOVE) and
                       not exists
                         (select 1
                            from EXPO_STRNMOVES c
                           where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                     ( nOper = 0 or
                      OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ) and
                     OPER_TYPE != Cmd_Expo.Sch_ImportOborot
              union all
              select sum( decode( DT_KT, 'D', -AMOUNT, 0 ) ) as ObDT,
                     sum( decode( DT_KT, 'K', -AMOUNT, 0 ) ) as ObKT
                from EXPO_MOVES_OLD a
               where ID_EXPO = nIDExpo and
                     SCH_DATE > dToDate);
    end if;

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );
    return nOborKt - nOborDt;
  end ExpoSaldoDate;

  --------------------------------------------------------------------------------
  function ExpoSaldoPeriod(
    nIDExpo    in     integer,
    dFrDate    in     date,
    dToDate    in     date,
    bValior    in     boolean,
    nOborDt    in out number,
    nOborKt    in out number,
    bSkipOper  in     boolean default false
  )
    return number is
    nTempDt  number;
    nTempKt  number;
    bDummy   boolean := false;

    cursor SaldoValior(
      nExpo   in integer,
      dFDate  in date,
      dTDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', AMOUNT, 0 ) as AMOUNTKT,
             VALIOR as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             VALIOR >= dFDate and
             AMOUNT != 0 and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoDate(
      nExpo   in integer,
      dFDate  in date,
      dTDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', AMOUNT, 0 ) as AMOUNTKT,
             SCH_DATE as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             SCH_DATE >= dFDate and
             AMOUNT != 0 and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    nOper    pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    nOborDt  := 0;
    nOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborDt,
           nOborKt
      from (select nvl( OBOR_DT, 0 ) as ObDT,
                   nvl( OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0 and
                   AMOUNT != 0 and
                   ( nOper = 0 or
                    OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );

    if ( bValior ) then
      for rec in SaldoValior( nIDExpo, dFrDate, dToDate, nOper ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nTempDt  := nOborDt;
          nTempKt  := nOborKt;
          bDummy   := true;
        end if;

        nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
        nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    else
      for rec in SaldoDate( nIDExpo, dFrDate, dToDate, nOper ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nTempDt  := nOborDt;
          nTempKt  := nOborKt;
          bDummy   := true;
        end if;

        nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
        nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    end if;

    nOborDt  := nvl( nTempDt, 0 ) - nOborDt;
    nOborKt  := nvl( nTempKt, 0 ) - nOborKt;
    return nOborKt - nOborDt;
  end ExpoSaldoPeriod;

  --------------------------------------------------------------------------------
  function ESysSaldoPeriod(
    nIDExpo    in     integer,
    dFrDate    in     date,
    dToDate    in     date,
    bValior    in     boolean,
    nOborDt    in out number,
    nOborKt    in out number,
    bSkipOper  in     boolean default false
  )
    return number is
    nTempDt  number;
    nTempKt  number;
    bDummy   boolean := false;

    cursor SaldoValior(
      nExpo   in integer,
      dFDate  in date,
      dTDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', SYS_AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', SYS_AMOUNT, 0 ) as AMOUNTKT,
             VALIOR as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             VALIOR >= dFDate and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoDate(
      nExpo   in integer,
      dFDate  in date,
      dTDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', SYS_AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', SYS_AMOUNT, 0 ) as AMOUNTKT,
             SCH_DATE as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             SCH_DATE >= dFDate and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    nOper    pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    nOborDt  := 0;
    nOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborDt,
           nOborKt
      from (select nvl( SYS_OBOR_DT, 0 ) as ObDT,
                   nvl( SYS_OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0 and
                   ( nOper = 0 or
                    OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );

    if ( bValior ) then
      for rec in SaldoValior( nIDExpo, dFrDate, dToDate, nOper ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nTempDt  := nOborDt;
          nTempKt  := nOborKt;
          bDummy   := true;
        end if;

        nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
        nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    else
      for rec in SaldoDate( nIDExpo, dFrDate, dToDate, nOper ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nTempDt  := nOborDt;
          nTempKt  := nOborKt;
          bDummy   := true;
        end if;

        nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
        nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    end if;

    nOborDt  := nvl( nTempDt, 0 ) - nOborDt;
    nOborKt  := nvl( nTempKt, 0 ) - nOborKt;
    return nOborKt - nOborDt;
  end ESysSaldoPeriod;

  --------------------------------------------------------------------------------
  function EAddSaldoPeriod(
    nIDExpo    in     integer,
    dFrDate    in     date,
    dToDate    in     date,
    bValior    in     boolean,
    nOborDt    in out number,
    nOborKt    in out number,
    bSkipOper  in     boolean default false
  )
    return number is
    nTempDt  number;
    nTempKt  number;
    bDummy   boolean := false;

    cursor SaldoValior(
      nExpo   in integer,
      dFDate  in date,
      dTDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', ADD_AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', ADD_AMOUNT, 0 ) as AMOUNTKT,
             VALIOR as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             VALIOR >= dFDate and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoDate(
      nExpo   in integer,
      dFDate  in date,
      dTDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', ADD_AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', ADD_AMOUNT, 0 ) as AMOUNTKT,
             SCH_DATE as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             SCH_DATE >= dFDate and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    nOper    pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    nOborDt  := 0;
    nOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborDt,
           nOborKt
      from (select nvl( ADD_OBOR_DT, 0 ) as ObDT,
                   nvl( ADD_OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', ADD_AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', ADD_AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0 and
                   ( nOper = 0 or
                    OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );

    if ( bValior ) then
      for rec in SaldoValior( nIDExpo, dFrDate, dToDate, nOper ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nTempDt  := nOborDt;
          nTempKt  := nOborKt;
          bDummy   := true;
        end if;

        nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
        nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    else
      for rec in SaldoDate( nIDExpo, dFrDate, dToDate, nOper ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nTempDt  := nOborDt;
          nTempKt  := nOborKt;
          bDummy   := true;
        end if;

        nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
        nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    end if;

    nOborDt  := nvl( nTempDt, 0 ) - nOborDt;
    nOborKt  := nvl( nTempKt, 0 ) - nOborKt;
    return nOborKt - nOborDt;
  end EAddSaldoPeriod;

  --------------------------------------------------------------------------------
  procedure ExpoOborotPeriod(
    nIDExpo         in     integer,
    dFrDate         in     date,
    dToDate         in     date,
    bValior         in     boolean,
    nOborBegDt      in out number,
    nOborBegKt      in out number,
    nOborEndDt      in out number,
    nOborEndKt      in out number,
    bSkipOper       in     boolean default false,
    bValiorPeriod   in     boolean default false,
    bNoStornoMoves  in     boolean default false
  ) is
    bDummy     boolean := false;

    cursor SaldoValior(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select /*+ index( a EXPO_MOVES_VALIOR ) */
            decode( a.DT_KT, 'D', a.AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.AMOUNT, 0 ) as AMOUNTKT,
             a.VALIOR as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.VALIOR >= dFDate and
             a.AMOUNT != 0 and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoValiorPeriod(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select /*+ index( a EXPO_MOVES_EPEIOD ) */
            decode( a.DT_KT, 'D', a.AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.AMOUNT, 0 ) as AMOUNTKT,
             a.VALIOR_PERIOD as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.VALIOR_PERIOD >= dFDate and
             a.AMOUNT != 0 and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoDate(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select /*+ index( a EXPO_MOVES_DATE ) */
            decode( a.DT_KT, 'D', a.AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.AMOUNT, 0 ) as AMOUNTKT,
             a.SCH_DATE as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.SCH_DATE >= dFDate and
             a.AMOUNT != 0 and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    nOper      pls_integer := 0;
    nNoStorno  pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    if ( bNoStornoMoves ) then
      nNoStorno  := 1;
    end if;

    nOborBegDt  := 0;
    nOborBegKt  := 0;
    nOborEndDt  := 0;
    nOborEndKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborBegDt,
           nOborBegKt
      from (select nvl( OBOR_DT, 0 ) as ObDT,
                   nvl( OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( a.DT_KT, 'D', a.AMOUNT, 0 ) ) as ObDT,
                   sum( decode( a.DT_KT, 'K', a.AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES a
             where a.ID_EXPO = nIDExpo and
                   a.CH_STAMP = 0 and
                   a.AMOUNT != 0 and
                   ( nNoStorno = 0 or
                    ( not exists
                       (select 1
                          from EXPO_STRNMOVES b
                         where b.ID_MOVE_NEW = a.ID_MOVE) and
                     not exists
                       (select 1
                          from EXPO_STRNMOVES c
                         where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                   ( nOper = 0 or
                    a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));

    nOborBegDt  := nvl( nOborBegDt, 0 );
    nOborBegKt  := nvl( nOborbegKt, 0 );

    if ( bValior ) then
      if ( not bValiorPeriod ) then
        for rec in SaldoValior( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
          if ( not bDummy and
              rec.DDATE = dToDate ) then
            nOborEndDt  := nOborBegDt;
            nOborEndKt  := nOborBegKt;
            bDummy      := true;
          end if;

          nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
          nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
        end loop;
      else
        for rec in SaldoValiorPeriod( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
          if ( not bDummy and
              rec.DDATE = dToDate ) then
            nOborEndDt  := nOborBegDt;
            nOborEndKt  := nOborBegKt;
            bDummy      := true;
          end if;

          nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
          nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
        end loop;
      end if;
    else
      for rec in SaldoDate( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nOborEndDt  := nOborBegDt;
          nOborEndKt  := nOborBegKt;
          bDummy      := true;
        end if;

        nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
        nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    end if;
  end ExpoOborotPeriod;

  --------------------------------------------------------------------------------
  procedure ESysOborotPeriod(
    nIDExpo         in     integer,
    dFrDate         in     date,
    dToDate         in     date,
    bValior         in     boolean,
    nOborBegDt      in out number,
    nOborBegKt      in out number,
    nOborEndDt      in out number,
    nOborEndKt      in out number,
    bSkipOper       in     boolean default false,
    bValiorPeriod   in     boolean default false,
    bNoStornoMoves  in     boolean default false
  ) is
    bDummy     boolean := false;

    cursor SaldoValior(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select decode( a.DT_KT, 'D', a.SYS_AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.SYS_AMOUNT, 0 ) as AMOUNTKT,
             a.VALIOR as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.VALIOR >= dFDate and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoDate(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select decode( a.DT_KT, 'D', a.SYS_AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.SYS_AMOUNT, 0 ) as AMOUNTKT,
             a.SCH_DATE as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.SCH_DATE >= dFDate and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoValiorPeriod(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select decode( a.DT_KT, 'D', a.SYS_AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.SYS_AMOUNT, 0 ) as AMOUNTKT,
             a.VALIOR_PERIOD as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.VALIOR_PERIOD >= dFDate and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    nOper      pls_integer := 0;
    nNoStorno  pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    if ( bNoStornoMoves ) then
      nNoStorno  := 1;
    end if;

    nOborBegDt  := 0;
    nOborBegKt  := 0;
    nOborEndDt  := 0;
    nOborEndKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborBegDt,
           nOborBegKt
      from (select nvl( SYS_OBOR_DT, 0 ) as ObDT,
                   nvl( SYS_OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( a.DT_KT, 'D', a.SYS_AMOUNT, 0 ) ) as ObDT,
                   sum( decode( a.DT_KT, 'K', a.SYS_AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES a
             where a.ID_EXPO = nIDExpo and
                   a.CH_STAMP = 0 and
                   ( nNoStorno = 0 or
                    ( not exists
                       (select 1
                          from EXPO_STRNMOVES b
                         where b.ID_MOVE_NEW = a.ID_MOVE) and
                     not exists
                       (select 1
                          from EXPO_STRNMOVES c
                         where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                   ( nOper = 0 or
                    a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));

    nOborBegDt  := nvl( nOborBegDt, 0 );
    nOborBegKt  := nvl( nOborbegKt, 0 );

    if ( bValior ) then
      if ( bValiorPeriod ) then
        for rec in SaldoValiorPeriod( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
          if ( not bDummy and
              rec.DDATE = dToDate ) then
            nOborEndDt  := nOborBegDt;
            nOborEndKt  := nOborBegKt;
            bDummy      := true;
          end if;

          nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
          nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
        end loop;
      else
        for rec in SaldoValior( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
          if ( not bDummy and
              rec.DDATE = dToDate ) then
            nOborEndDt  := nOborBegDt;
            nOborEndKt  := nOborBegKt;
            bDummy      := true;
          end if;

          nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
          nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
        end loop;
      end if;
    else
      for rec in SaldoDate( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nOborEndDt  := nOborBegDt;
          nOborEndKt  := nOborBegKt;
          bDummy      := true;
        end if;

        nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
        nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    end if;
  end ESysOborotPeriod;

  --------------------------------------------------------------------------------
  procedure EAddOborotPeriod(
    nIDExpo         in     integer,
    dFrDate         in     date,
    dToDate         in     date,
    bValior         in     boolean,
    nOborBegDt      in out number,
    nOborBegKt      in out number,
    nOborEndDt      in out number,
    nOborEndKt      in out number,
    bSkipOper       in     boolean default false,
    bValiorPeriod   in     boolean default false,
    bNoStornoMoves  in     boolean default false
  ) is
    bDummy     boolean := false;

    cursor SaldoValior(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select decode( a.DT_KT, 'D', a.ADD_AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.ADD_AMOUNT, 0 ) as AMOUNTKT,
             a.VALIOR as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.VALIOR >= dFDate and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoDate(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select decode( a.DT_KT, 'D', a.ADD_AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.ADD_AMOUNT, 0 ) as AMOUNTKT,
             a.SCH_DATE as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.SCH_DATE >= dFDate and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    cursor SaldoValiorPeriod(
      nExpo       in integer,
      dFDate      in date,
      dTDate      in date,
      nOpr        in pls_integer,
      pnNoStorno  in integer
    ) is
      select decode( a.DT_KT, 'D', a.ADD_AMOUNT, 0 ) as AMOUNTDT,
             decode( a.DT_KT, 'K', a.ADD_AMOUNT, 0 ) as AMOUNTKT,
             a.VALIOR_PERIOD as DDATE
        from EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.VALIOR_PERIOD >= dFDate and
             ( pnNoStorno = 0 or
              ( not exists
                 (select 1
                    from EXPO_STRNMOVES b
                   where b.ID_MOVE_NEW = a.ID_MOVE) and
               not exists
                 (select 1
                    from EXPO_STRNMOVES c
                   where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
             ( nOpr = 0 or
              a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dTDate as DDATE
        from dual
      order by 3 desc;

    nOper      pls_integer := 0;
    nNoStorno  pls_integer := 0;
  begin
    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    if ( bNoStornoMoves ) then
      nNoStorno  := 1;
    end if;

    nOborBegDt  := 0;
    nOborBegKt  := 0;
    nOborEndDt  := 0;
    nOborEndKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborBegDt,
           nOborBegKt
      from (select nvl( ADD_OBOR_DT, 0 ) as ObDT,
                   nvl( ADD_OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( a.DT_KT, 'D', a.ADD_AMOUNT, 0 ) ) as ObDT,
                   sum( decode( a.DT_KT, 'K', a.ADD_AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES a
             where a.ID_EXPO = nIDExpo and
                   a.CH_STAMP = 0 and
                   ( nNoStorno = 0 or
                    ( not exists
                       (select 1
                          from EXPO_STRNMOVES b
                         where b.ID_MOVE_NEW = a.ID_MOVE) and
                     not exists
                       (select 1
                          from EXPO_STRNMOVES c
                         where c.ID_MOVE_OLD = a.ID_MOVE) ) ) and
                   ( nOper = 0 or
                    a.OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));

    nOborBegDt  := nvl( nOborBegDt, 0 );
    nOborBegKt  := nvl( nOborbegKt, 0 );

    if ( bValior ) then
      if ( bValiorPeriod ) then
        for rec in SaldoValiorPeriod( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
          if ( not bDummy and
              rec.DDATE = dToDate ) then
            nOborEndDt  := nOborBegDt;
            nOborEndKt  := nOborBegKt;
            bDummy      := true;
          end if;

          nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
          nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
        end loop;
      else
        for rec in SaldoValior( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
          if ( not bDummy and
              rec.DDATE = dToDate ) then
            nOborEndDt  := nOborBegDt;
            nOborEndKt  := nOborBegKt;
            bDummy      := true;
          end if;

          nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
          nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
        end loop;
      end if;
    else
      for rec in SaldoDate( nIDExpo, dFrDate, dToDate, nOper, nNoStorno ) loop
        if ( not bDummy and
            rec.DDATE = dToDate ) then
          nOborEndDt  := nOborBegDt;
          nOborEndKt  := nOborBegKt;
          bDummy      := true;
        end if;

        nOborBegDt  := nOborBegDt - nvl( rec.AMOUNTDT, 0 );
        nOborBegKt  := nOborBegKt - nvl( rec.AMOUNTKT, 0 );
      end loop;
    end if;
  end EAddOborotPeriod;

  --------------------------------------------------------------------------------
  function BeginDateSaldo(
    nIDExpo   in integer,
    dForDate  in date,
    bValior   in boolean
  )
    return date is
    dBegDate    date := dForDate;
    nSaldo      number := 0;
    nCorrSaldo  number := 0;
    bFirst      boolean := true;
    nIDMove     integer;

    cursor SaldoValiorA(
      nExpo  in integer,
      dDate  in date
    ) is
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.VALIOR as DDATE,
             a.DT_KT,
             a.ID_MOVE
        from EXPO_STRNMOVES c,
             EXPO_STRNMOVES b,
             EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.AMOUNT != 0 and
             a.OPER_TYPE not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot) and
             a.ID_MOVE = b.ID_MOVE_NEW(+) and
             b.ID_MOVE_NEW is null and
             a.ID_MOVE = c.ID_MOVE_OLD(+) and
             c.ID_MOVE_OLD is null
      union all
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.VALIOR as DDATE,
             a.DT_KT,
             0 as ID_MOVE
        from EXPO_MOVES_OLD a
       where a.ID_EXPO = nExpo
      union all
      select 0 as AMOUNT,
             dDate as DDATE,
             'D' as DT_KT,
             0 as ID_MOVE
        from dual
      order by 2 desc,
               3 asc,
               4 desc;

    cursor SaldoDateA(
      nExpo  in integer,
      dDate  in date
    ) is
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.SCH_DATE as DDATE,
             a.DT_KT,
             a.ID_MOVE
        from EXPO_STRNMOVES c,
             EXPO_STRNMOVES b,
             EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.AMOUNT != 0 and
             a.OPER_TYPE not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot) and
             a.ID_MOVE = b.ID_MOVE_NEW(+) and
             b.ID_MOVE_NEW is null and
             a.ID_MOVE = c.ID_MOVE_OLD(+) and
             c.ID_MOVE_OLD is null
      union all
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.SCH_DATE as DDATE,
             a.DT_KT,
             0 as ID_MOVE
        from EXPO_MOVES_OLD a
       where a.ID_EXPO = nExpo
      union all
      select 0 as AMOUNT,
             dDate as DDATE,
             'D' as DT_KT,
             0 as ID_MOVE
        from dual
      order by 2 desc,
               3 asc,
               4 desc;

    cursor SaldoValiorP(
      nExpo  in integer,
      dDate  in date
    ) is
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.VALIOR as DDATE,
             a.DT_KT,
             a.ID_MOVE
        from EXPO_STRNMOVES c,
             EXPO_STRNMOVES b,
             EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.AMOUNT != 0 and
             a.OPER_TYPE not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot) and
             a.ID_MOVE = b.ID_MOVE_NEW(+) and
             b.ID_MOVE_NEW is null and
             a.ID_MOVE = c.ID_MOVE_OLD(+) and
             c.ID_MOVE_OLD is null
      union all
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.VALIOR as DDATE,
             a.DT_KT,
             0 as ID_MOVE
        from EXPO_MOVES_OLD a
       where a.ID_EXPO = nExpo
      union all
      select 0 as AMOUNT,
             dDate as DDATE,
             'D' as DT_KT,
             0 as ID_MOVE
        from dual
      order by 2 desc,
               3 desc,
               4 desc;

    cursor SaldoDateP(
      nExpo  in integer,
      dDate  in date
    ) is
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.SCH_DATE as DDATE,
             a.DT_KT,
             a.ID_MOVE
        from EXPO_STRNMOVES c,
             EXPO_STRNMOVES b,
             EXPO_MOVES a
       where a.ID_EXPO = nExpo and
             a.AMOUNT != 0 and
             a.OPER_TYPE not in (Cmd_Expo.Sch_ImportOborot, Cmd_Expo.Sch_ClearOborot) and
             a.ID_MOVE = b.ID_MOVE_NEW(+) and
             b.ID_MOVE_NEW is null and
             a.ID_MOVE = c.ID_MOVE_OLD(+) and
             c.ID_MOVE_OLD is null
      union all
      select decode( a.DT_KT, 'D', a.AMOUNT, -a.AMOUNT ) as AMOUNT,
             a.SCH_DATE as DDATE,
             a.DT_KT,
             0 as ID_MOVE
        from EXPO_MOVES_OLD a
       where a.ID_EXPO = nExpo
      union all
      select 0 as AMOUNT,
             dDate as DDATE,
             'D' as DT_KT,
             0 as ID_MOVE
        from dual
      order by 2 desc,
               3 desc,
               4 desc;

  begin
    nIDMove  := OtherExpo.GetExpoMoveLast( nIDExpo, nCorrSaldo );

    if ( GetExpoHotSaldo( nIDExpo, nSaldo ) ) then
      if ( Schema_GPSys.HeadExpo.IsItActiveExpo( nIDExpo ) or
          nSaldo < 0 ) then
        if ( bValior ) then
          for rec in SaldoValiorA( nIDExpo, dForDate ) loop
            if ( bFirst and
                rec.ID_MOVE < nIDMove ) then
              bFirst  := false;
              nSaldo  := nSaldo + nCorrSaldo;
            end if;

            nSaldo  := nSaldo + rec.AMOUNT;

            if ( rec.DDATE <= dForDate ) then
              dBegDate  := rec.DDATE;
              exit when nSaldo >= 0;
            end if;
          end loop;
        else
          for rec in SaldoDateA( nIDExpo, dForDate ) loop
            if ( bFirst and
                rec.ID_MOVE < nIDMove ) then
              bFirst  := false;
              nSaldo  := nSaldo + nCorrSaldo;
            end if;

            nSaldo  := nSaldo + rec.AMOUNT;

            if ( rec.DDATE <= dForDate ) then
              dBegDate  := rec.DDATE;
              exit when nSaldo >= 0;
            end if;
          end loop;
        end if;
      else
        if ( bValior ) then
          for rec in SaldoValiorP( nIDExpo, dForDate ) loop
            if ( bFirst and
                rec.ID_MOVE < nIDMove ) then
              bFirst  := false;
              nSaldo  := nSaldo + nCorrSaldo;
            end if;

            nSaldo  := nSaldo + rec.AMOUNT;

            if ( rec.DDATE <= dForDate ) then
              dBegDate  := rec.DDATE;
              exit when nSaldo <= 0;
            end if;
          end loop;
        else
          for rec in SaldoDateP( nIDExpo, dForDate ) loop
            if ( bFirst and
                rec.ID_MOVE < nIDMove ) then
              bFirst  := false;
              nSaldo  := nSaldo + nCorrSaldo;
            end if;

            nSaldo  := nSaldo + rec.AMOUNT;

            if ( rec.DDATE <= dForDate ) then
              dBegDate  := rec.DDATE;
              exit when nSaldo <= 0;
            end if;
          end loop;
        end if;
      end if;
    end if;

    return dBegDate;
  end BeginDateSaldo;

  --------------------------------------------------------------------------------
  function CalcExpoSaldo(
    nIDExpo     in integer,
    dToDate     in date,
    bValior     in boolean,
    bRealSaldo  in boolean default false
  )
    return number is
    nSaldo      number := 0;
    nCorrSaldo  number := 0;
    bFirst      boolean := true;
    nIDMove     integer;
  begin
    nIDMove  := OtherExpo.GetExpoMoveLast( nIDExpo, nCorrSaldo );

    if ( GetExpoHotSaldo( nIDExpo, nSaldo ) ) then
      if ( bValior ) then
        for rec in (  select *
                        from (select /*+ index( EXPO_MOVES EXPO_MOVES_VALIOR ) */
                                    decode( DT_KT, 'D', AMOUNT, -AMOUNT ) as AMOUNT,
                                     ID_MOVE
                                from EXPO_MOVES
                               where ID_EXPO = nIDExpo and
                                     VALIOR > dToDate and
                                     AMOUNT != 0 and
                                     OPER_TYPE != Cmd_Expo.Sch_ImportOborot
                              union all
                              select decode( DT_KT, 'D', AMOUNT, -AMOUNT ) as AMOUNT,
                                     0 as ID_MOVE
                                from EXPO_MOVES_OLD
                               where ID_EXPO = nIDExpo and
                                     VALIOR > dToDate)
                    order by ID_MOVE desc ) loop
          if ( bFirst and
              rec.ID_MOVE < nIDMove ) then
            bFirst  := false;
            nSaldo  := nSaldo + nCorrSaldo;
          end if;

          nSaldo  := nSaldo + rec.AMOUNT;
        end loop;
      else
        for rec in (  select *
                        from (select /*+ index( EXPO_MOVES EXPO_MOVES_DATE ) */
                                    decode( DT_KT, 'D', AMOUNT, -AMOUNT ) as AMOUNT,
                                     ID_MOVE
                                from EXPO_MOVES
                               where ID_EXPO = nIDExpo and
                                     SCH_DATE > dToDate and
                                     AMOUNT != 0 and
                                     OPER_TYPE != Cmd_Expo.Sch_ImportOborot
                              union all
                              select decode( DT_KT, 'D', AMOUNT, -AMOUNT ) as AMOUNT,
                                     0 as ID_MOVE
                                from EXPO_MOVES_OLD
                               where ID_EXPO = nIDExpo and
                                     SCH_DATE > dToDate)
                    order by ID_MOVE desc ) loop
          if ( bFirst and
              rec.ID_MOVE < nIDMove ) then
            bFirst  := false;
            nSaldo  := nSaldo + nCorrSaldo;
          end if;

          nSaldo  := nSaldo + rec.AMOUNT;
        end loop;
      end if;
    end if;

    return case
             when bRealSaldo or
                  bFirst then
               nSaldo
             else
               Schema_GPSys.OraGPSys.nTruncSet( nSaldo / Schema_GPSys.OraGPSys.EURORate, Schema_GPSys.OraGPSys.EUR_CURR )
           end;
  end CalcExpoSaldo;

  --------------------------------------------------------------------------------
  function CalcExpoSaldoDate(
    nIDExpo  in integer,
    dToDate  in date
  )
    return number is
  begin
    return CalcExpoSaldo( nIDExpo, dToDate, false );
  end CalcExpoSaldoDate;

  --------------------------------------------------------------------------------
  function ApplyLimits(
    nIDExpo     in     integer,
    dValior     in     date,
    nSaldo      in out number,
    dSchDate    in     date default null,
    bAllLimits  in     boolean default false,
    dToDate     in     date default null
  )
    return number is
    RecExpo  Schema_GPSys.EXPOSITION%rowtype;
    nTemp1   integer;
    nTemp2   integer;
    nAmount  number := 0;
    bFull    boolean := false;
  begin
    select nvl( sum( decode( FULL_LIMIT, 'T', 1, 0 ) ), 0 ),
           nvl( sum( decode( FULL_LIMIT, 'F', 1, 0 ) ), 0 )
      into nTemp1,
           nTemp2
      from EXPO_LIMITS
     where ID_EXPO = nIDExpo and
           ( BEG_DATE is null or
            ( BEG_DATE <= dValior and
             ( dSchDate is null or
              BEG_DATE <= dSchDate ) ) ) and
           ( END_DATE is null or
            dValior <= END_DATE ) and
           STATUS = ZaporStat_Active;

    if ( nTemp1 > 0 or
        nTemp2 > 0 ) then
      select *
        into RecExpo
        from Schema_GPSys.EXPOSITION
       where ID_EXPO = nIDExpo;

      if ( nTemp1 > 0 ) then
        for rec in ( select *
                       from EXPO_LIMITS
                      where ID_EXPO = nIDExpo and
                            ( BEG_DATE is null or
                             ( BEG_DATE <= dValior and
                              ( dSchDate is null or
                               BEG_DATE <= dSchDate ) ) ) and
                            ( END_DATE is null or
                             dValior <= END_DATE ) and
                            STATUS = ZaporStat_Active and
                            FULL_LIMIT = 'T' ) loop
          if ( bAllLimits or
              not SkipTheLimit( rec.TYPE_LIMIT, RecExpo.TYPE_EXPO ) ) then
            nSaldo  := -Schema_GPSys.OraGPSys.nMaxMoney;
            bFull   := true;
            exit;
          end if;
        end loop;
      end if;

      if ( nTemp2 > 0 and
          not bFull ) then
        for rec in ( select *
                       from EXPO_LIMITS
                      where ID_EXPO = nIDExpo and
                            ( BEG_DATE is null or
                             ( BEG_DATE <= dValior and
                              ( dSchDate is null or
                               BEG_DATE <= dSchDate ) and
                              ( dToDate is null or
                               TYPE_LIMIT != ExpoLimit_CashZapor or
                               BEG_DATE <= dToDate ) ) ) and
                            ( END_DATE is null or
                             dValior <= END_DATE ) and
                            STATUS = ZaporStat_Active and
                            FULL_LIMIT = 'F' ) loop
          if ( bAllLimits or
              not SkipTheLimit( rec.TYPE_LIMIT, RecExpo.TYPE_EXPO ) ) then
            nAmount  := nAmount + nvl( Schema_GPSys.XchgRates.GetExactSum( rec.SUMLIMIT, RecExpo.UNIQCODE, dValior, rec.CODVAL, RecExpo.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing ), 0 );
          end if;
        end loop;

        if ( bAllLimits or
            nAmount > 0 ) then
          nSaldo  := nSaldo - nAmount;
        end if;
      end if;
    end if;

    return nSaldo;
  exception
    when no_data_found then
      return nSaldo;
  end ApplyLimits;

  --------------------------------------------------------------------------------
  function ExpoSumAvailable(
    nIDExpo   in integer,
    dToDate   in date,
    bRealSum  in boolean default false,
    nMode     in integer default 0
  )
    return number is
    nAmount    number := 0;
    nHotSaldo  number := 0;
    nSaldo     number := 0;
    nOperSum   number := 0;
    nOborDT    number := 0;
    nOborKT    number := 0;
    dSchDate   date := Schema_RA.GPC_Tools.GetSchDate( null );

    cursor iqQ(
      nExpo  in integer,
      dDate  in date
    ) is
        select sum( OBORDT ) as OBORDT,
               sum( OBORKT ) as OBORKT,
               VALIOR
          from ((  select /*+ index( EXPO_MOVES EXPO_MOVES_VALIOR ) */
                         sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as OBORDT,
                          sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as OBORKT,
                          VALIOR
                     from EXPO_MOVES
                    where ID_EXPO = nExpo and
                          VALIOR > dDate and
                          AMOUNT != 0
                 group by Valior )
                union all
                ( select 0,
                         0,
                         dDate
                    from dual )
                union all
                ( select 0,
                         0,
                         to_date( '01.01.3000', 'dd.mm.yyyy' )
                    from dual ))
      group by Valior
      order by Valior desc;

  begin
    if ( GetExpoHotSaldo( nIDExpo, nSaldo ) and
        ( bRealSum or
         nSaldo > 0 ) ) then
      nHotSaldo  := nSaldo;
      nAmount    := nSaldo;

      for rec in iqQ( nIDExpo, dToDate ) loop
        if ( nMode = 0 or
            nMode > 3 ) then
          nSaldo  := nSaldo + rec.OBORDT - rec.OBORKT;
        elsif ( nMode = 1 ) then
          nOborDT  := nOborDT + rec.OBORDT;
          nOborKT  := nOborKT + rec.OBORKT;
          nSaldo   := least( nHotSaldo + ( nOborDT - nOborKT ), nSaldo );
        elsif ( nMode = 2 ) then
          nSaldo  := nSaldo - rec.OBORKT;
        elsif ( nMode = 3 ) then
          nSaldo  := nSaldo + rec.OBORDT;
        end if;

        nOperSum  := nSaldo;
        nOperSum  := ApplyLimits( nIDExpo, rec.VALIOR, nOperSum, dSchDate, false, dToDate );
        nAmount   := least( nAmount, nOperSum );

        if ( not ( bRealSum or
                  nAmount > 0 ) ) then
          nAmount  := 0;
          exit;
        end if;
      end loop;
    end if;

    return nAmount;
  end ExpoSumAvailable;

  --------------------------------------------------------------------------------
  function GetEAllHotSaldo(
    nIDExpo    in     integer,
    nOrgSaldo  in out number,
    nSysSaldo  in out number
  )
    return boolean is
  begin
    nOrgSaldo  := 0;
    nSysSaldo  := 0;

    select sum( ORG_AMOUNT ),
           sum( SYS_AMOUNT )
      into nOrgSaldo,
           nSysSaldo
      from (select nvl( OBOR_KT, 0 ) - nvl( OBOR_DT, 0 ) as ORG_AMOUNT,
                   nvl( SYS_OBOR_KT, 0 ) - nvl( SYS_OBOR_DT, 0 ) as SYS_AMOUNT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', -AMOUNT, AMOUNT ) ) as ORG_AMOUNT,
                   sum( decode( DT_KT, 'D', -SYS_AMOUNT, SYS_AMOUNT ) ) as SYS_AMOUNT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0);

    nOrgSaldo  := nvl( nOrgSaldo, 0 );
    nSysSaldo  := nvl( nSysSaldo, 0 );
    return true;
  end GetEAllHotSaldo;

  --------------------------------------------------------------------------------
  function GetExpoHotSaldo(
    nIDExpo  in     integer,
    nSaldo   in out number
  )
    return boolean is
  begin
    nSaldo  := 0;

    select sum( Amn )
      into nSaldo
      from (select nvl( OBOR_KT, 0 ) - nvl( OBOR_DT, 0 ) as Amn
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', -AMOUNT, AMOUNT ) ) as Amn
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0 and
                   AMOUNT != 0);

    nSaldo  := nvl( nSaldo, 0 );
    return true;
  end GetExpoHotSaldo;

  --------------------------------------------------------------------------------
  function GetExpoAddHotSaldo(
    nIDExpo      in     integer,
    sAddClassif  in     varchar2,
    nSaldo       in out number
  )
    return boolean is
  begin
    nSaldo  := 0;

    select sum( Amn )
      into nSaldo
      from (select nvl( OBOR_KT, 0 ) - nvl( OBOR_DT, 0 ) as Amn
              from ADD_EXPO_STATE
             where ID_EXPO = nIDExpo and
                   ADD_CLASSIF = sAddClassif
            union all
            select sum( decode( DT_KT, 'D', -AMOUNT, AMOUNT ) ) as Amn
              from ADD_MOVES
             where ID_EXPO = nIDExpo and
                   ADD_CLASSIF = sAddClassif and
                   CH_STAMP = 0 and
                   AMOUNT != 0);

    nSaldo  := nvl( nSaldo, 0 );
    return true;
  end GetExpoAddHotSaldo;

  --------------------------------------------------------------------------------
  function GetESysHotSaldo(
    nIDExpo  in     integer,
    nSaldo   in out number
  )
    return boolean is
  begin
    nSaldo  := 0;

    select sum( Amn )
      into nSaldo
      from (select nvl( SYS_OBOR_KT, 0 ) - nvl( SYS_OBOR_DT, 0 ) as Amn
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', -SYS_AMOUNT, SYS_AMOUNT ) ) as Amn
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0);

    nSaldo  := nvl( nSaldo, 0 );
    return true;
  end GetESysHotSaldo;

  --------------------------------------------------------------------------------
  function GetExpoHotOborot(
    nIDExpo  in     integer,
    nOborDt  in out number,
    nOborKt  in out number
  )
    return boolean is
  begin
    nOborDt  := 0;
    nOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborDt,
           nOborKt
      from (select nvl( OBOR_DT, 0 ) as ObDT,
                   nvl( OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0 and
                   AMOUNT != 0);

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );
    return true;
  end GetExpoHotOborot;

  --------------------------------------------------------------------------------
  function GetExpoAddHotOborot(
    nIDExpo      in     integer,
    sAddClassif  in     varchar2,
    nOborDt      in out number,
    nOborKt      in out number
  )
    return boolean is
  begin
    nOborDt  := 0;
    nOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborDt,
           nOborKt
      from (select nvl( OBOR_DT, 0 ) as ObDT,
                   nvl( OBOR_KT, 0 ) as ObKT
              from ADD_EXPO_STATE
             where ID_EXPO = nIDExpo and
                   ADD_CLASSIF = sAddClassif
            union all
            select sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ObKT
              from ADD_MOVES
             where ID_EXPO = nIDExpo and
                   ADD_CLASSIF = sAddClassif and
                   CH_STAMP = 0 and
                   AMOUNT != 0);

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );
    return true;
  end GetExpoAddHotOborot;

  --------------------------------------------------------------------------------
  function GetESysHotOborot(
    nIDExpo  in     integer,
    nOborDt  in out number,
    nOborKt  in out number
  )
    return boolean is
  begin
    nOborDt  := 0;
    nOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT )
      into nOborDt,
           nOborKt
      from (select nvl( SYS_OBOR_DT, 0 ) as ObDT,
                   nvl( SYS_OBOR_KT, 0 ) as ObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as ObKT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0);

    nOborDt  := nvl( nOborDt, 0 );
    nOborKt  := nvl( nOborKt, 0 );
    return true;
  end GetESysHotOborot;

  --------------------------------------------------------------------------------
  function GetEAllHotOborot(
    nIDExpo     in     integer,
    nOborDt     in out number,
    nOborKt     in out number,
    nSysOborDt  in out number,
    nSysOborKt  in out number
  )
    return boolean is
  begin
    nOborDt     := 0;
    nOborKt     := 0;
    nSysOborDt  := 0;
    nSysOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT ),
           sum( SysObDT ),
           sum( SysObKT )
      into nOborDt,
           nOborKt,
           nSysOborDt,
           nSysOborKt
      from (select nvl( OBOR_DT, 0 ) as ObDT,
                   nvl( OBOR_KT, 0 ) as ObKT,
                   nvl( SYS_OBOR_DT, 0 ) as SysObDT,
                   nvl( SYS_OBOR_KT, 0 ) as SysObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ObKT,
                   sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SysObDT,
                   sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SysObKT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0);

    nOborDt     := nvl( nOborDt, 0 );
    nOborKt     := nvl( nOborKt, 0 );
    nSysOborDt  := nvl( nSysOborDt, 0 );
    nSysOborKt  := nvl( nSysOborKt, 0 );
    return true;
  end GetEAllHotOborot;

  --------------------------------------------------------------------------------
  function GetEAllHotOborot(
    nIDExpo     in     integer,
    nOborDt     in out number,
    nOborKt     in out number,
    nSysOborDt  in out number,
    nSysOborKt  in out number,
    nAddOborDt  in out number,
    nAddOborKt  in out number
  )
    return boolean is
  begin
    nOborDt     := 0;
    nOborKt     := 0;
    nSysOborDt  := 0;
    nSysOborKt  := 0;
    nAddOborDt  := 0;
    nAddOborKt  := 0;

    select sum( ObDT ),
           sum( ObKT ),
           sum( SysObDT ),
           sum( SysObKT ),
           sum( AddObDT ),
           sum( AddObKT )
      into nOborDt,
           nOborKt,
           nSysOborDt,
           nSysOborKt,
           nAddOborDt,
           nAddOborKt
      from (select nvl( OBOR_DT, 0 ) as ObDT,
                   nvl( OBOR_KT, 0 ) as ObKT,
                   nvl( SYS_OBOR_DT, 0 ) as SysObDT,
                   nvl( SYS_OBOR_KT, 0 ) as SysObKT,
                   nvl( ADD_OBOR_DT, 0 ) as AddObDT,
                   nvl( ADD_OBOR_KT, 0 ) as AddObKT
              from EXPO_STATE
             where ID_EXPO = nIDExpo
            union all
            select sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ObDT,
                   sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ObKT,
                   sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SysObDT,
                   sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SysObKT,
                   sum( decode( DT_KT, 'D', ADD_AMOUNT, 0 ) ) as AddObDT,
                   sum( decode( DT_KT, 'K', ADD_AMOUNT, 0 ) ) as AddObKT
              from EXPO_MOVES
             where ID_EXPO = nIDExpo and
                   CH_STAMP = 0);

    nOborDt     := nvl( nOborDt, 0 );
    nOborKt     := nvl( nOborKt, 0 );
    nSysOborDt  := nvl( nSysOborDt, 0 );
    nSysOborKt  := nvl( nSysOborKt, 0 );
    nAddOborDt  := nvl( nAddOborDt, 0 );
    nAddOborKt  := nvl( nAddOborKt, 0 );
    return true;
  end GetEAllHotOborot;

  --------------------------------------------------------------------------------
  function GetExpoCodVal(
    nIDExpo  in     integer,
    sCodVal  in out varchar2
  )
    return boolean is
    aParams  Schema_RA.GPC_RA.tblErrParams;
  begin
    select CODVAL
      into sCodVal
      from Schema_GPSys.EXPOSITION
     where ID_EXPO = nIDExpo and
           STATUS = 'T';

    return true;
  exception
    when no_data_found then
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'ID_EXPO';
      aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
      Schema_RA.GPC_RA.RespSetErrorText( 'Несъществуваща експозиция номер $ID_EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
      return false;
  end GetExpoCodVal;

  --------------------------------------------------------------------------------
  function ZaporInternal(
    TypeZapor  in varchar2,
    nMode      in integer default 0
  )
    return boolean is
  begin
    return IsZaporInternal( TypeZapor, nMode ) = 'T';
  end ZaporInternal;

  --------------------------------------------------------------------------------
  function IsZaporInternal(
    TypeZapor  in varchar2,
    nMode      in integer default 0
  )
    return varchar2 is
    bType1  boolean;
    bType2  boolean;
  begin
    bType1      := TypeZapor in (ExpoLimit_Limit, ExpoLimit_CashZapor, ExpoLimit_CredPadej);
    bType2      := TypeZapor in
                     ( ExpoLimit_Payment,
                      ExpoLimit_Cover,
                      ExpoLimit_DueAmn,
                      ExpoLimit_CardAuth,
                      ExpoLimit_DealOper,
                      ExpoLimit_CardMNO,
                      ExpoLimit_DealOrder,
                      ExpoLimit_CardMPV,
                      ExpoLimit_CommunalPay,
                      ExpoLimit_CardHOLD,
                      ExpoLimit_ForApproval );
    return case
             when ( nMode = 0 and
                   ( bType1 or
                    bType2 ) ) or
                  ( nMode = 1 and
                   bType2 ) then
               'T'
             else
               'F'
           end;
  end IsZaporInternal;

  --------------------------------------------------------------------------------
  function GetExpoData(
    nIDExpo    in     integer,
    sBankAcc   in out varchar2,
    sExpoName  in out varchar2
  )
    return boolean is
    RecExpo  Schema_GPSys.EXPOSITION%rowtype;
    aParams  Schema_RA.GPC_RA.tblErrParams;
  begin
    select *
      into RecExpo
      from Schema_GPSys.EXPOSITION
     where ID_EXPO = nIDExpo;

    sBankAcc   := RecExpo.BANKACC;
    sExpoName  := RecExpo.EXPO_NAME;
    return true;
  exception
    when no_data_found then
      sBankAcc               := null;
      sExpoName              := null;
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'ID_EXPO';
      aParams( 1 ).ML_VALUE  := to_char( nIDExpo );
      Schema_RA.GPC_RA.RespSetErrorText( 'Липсва досие на експозиция с номер: $ID_EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
      return false;
  end GetExpoData;

  --------------------------------------------------------------------------------
  function Expo2BNBCode(
    nPattWork      in     integer,
    rExpoOpenData  in     Schema_GPSys.Cmd_HeadExpo.recExpoOpenData,
    RecBNBConf     in out BNB_CODECONF%rowtype
  )
    return boolean is
    iqQ           Schema_GPSys.OraGPSys.EmpCurTyp;
    RecOtherCode  BNB_OTHRCODE%rowtype;
    bDummy        boolean;
    bRet          boolean;
    nBaseType     integer;
    nID           integer;
    nTypeExept    integer;
    sLoanTypes    varchar2( 3000 );
    aParams       Schema_RA.GPC_RA.tblErrParams;
  begin
    open iqQ for
      select BASE_TYPE
        from Schema_GPSys.EXPOTYPES
       where TYPE_EXPO = rExpoOpenData.TypeExpo;

    fetch iqQ
      into nBaseType;

    bRet  := iqQ%found;

    close iqQ;

    if ( bRet ) then
      open iqQ for
        select SHIFAR
          from BNB_EXPO2CODE
         where PATTERN = nPattWork and
               ID_EXPO = rExpoOpenData.IDExpo;

      fetch iqQ
        into RecBNBConf.SHIFAR;

      bDummy  := iqQ%notfound;

      close iqQ;

      if ( bDummy ) then
        open iqQ for
          select OTHRCODE,
                 FLDSROK,
                 1
            from BNB_OTHRCODE
           where FLDMODE = 'TYPE_EXPO' and
                 FLDVALUE = to_char( rExpoOpenData.TypeExpo ) and
                 PATTERN = nPattWork
          union all
          select OTHRCODE,
                 FLDSROK,
                 2
            from BNB_OTHRCODE
           where FLDMODE = 'TYPE_EXPO' and
                 FLDVALUE = to_char( rExpoOpenData.TypeExpo ) and
                 nvl( PATTERN, 0 ) = 0
          order by 3;

        fetch iqQ
          into RecBNBConf.TYPEXP_CODE, nTypeExept, nId;

        if ( iqQ%notfound ) then
          RecBNBConf.TYPEXP_CODE  := -1;
          nTypeExept              := null;
        end if;

        close iqQ;

        ---
        open iqQ for
          select OTHRCODE,
                 1
            from BNB_OTHRCODE
           where FLDMODE = 'CODVAL' and
                 FLDVALUE = rExpoOpenData.CodVal and
                 PATTERN = nPattWork
          union all
          select OTHRCODE,
                 2
            from BNB_OTHRCODE
           where FLDMODE = 'CODVAL' and
                 FLDVALUE = rExpoOpenData.CodVal and
                 nvl( PATTERN, 0 ) = 0
          order by 2;

        fetch iqQ
          into RecBNBConf.CODVAL_CODE, nId;

        if ( iqQ%notfound ) then
          RecBNBConf.CODVAL_CODE  := -1;
        end if;

        close iqQ;

        ---
        if ( nTypeExept is null and
            nvl( rExpoOpenData.IDCust, 0 ) > 0 ) then
          open iqQ for
            select CUSTCODE,
                   1
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE = rExpoOpenData.FType and
                   SECTORNA = rExpoOpenData.Sectorna and
                   OTRASLOVA = rExpoOpenData.Otraslova and
                   PATTERN = nPattWork
            union all
            select CUSTCODE,
                   2
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE = rExpoOpenData.FType and
                   SECTORNA = rExpoOpenData.Sectorna and
                   OTRASLOVA is null and
                   PATTERN = nPattWork
            union all
            select CUSTCODE,
                   3
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE = rExpoOpenData.FType and
                   SECTORNA is null and
                   OTRASLOVA is null and
                   PATTERN = nPattWork
            union all
            select CUSTCODE,
                   4
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE is null and
                   SECTORNA is null and
                   OTRASLOVA is null and
                   PATTERN = nPattWork
            union all
            select CUSTCODE,
                   5
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE = rExpoOpenData.FType and
                   SECTORNA = rExpoOpenData.Sectorna and
                   OTRASLOVA = rExpoOpenData.Otraslova and
                   nvl( PATTERN, 0 ) = 0
            union all
            select CUSTCODE,
                   6
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE = rExpoOpenData.FType and
                   SECTORNA = rExpoOpenData.Sectorna and
                   OTRASLOVA is null and
                   nvl( PATTERN, 0 ) = 0
            union all
            select CUSTCODE,
                   7
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE = rExpoOpenData.FType and
                   SECTORNA is null and
                   OTRASLOVA is null and
                   nvl( PATTERN, 0 ) = 0
            union all
            select CUSTCODE,
                   8
              from BNB_CUSTCODE
             where CLITYPE = rExpoOpenData.CliType and
                   FTYPE is null and
                   SECTORNA is null and
                   OTRASLOVA is null and
                   nvl( PATTERN, 0 ) = 0
            order by 2;

          fetch iqQ
            into RecBNBConf.CUSTOM_CODE, nId;

          if ( iqQ%notfound ) then
            RecBNBConf.CUSTOM_CODE  := -1;
          end if;

          close iqQ;
        else
          RecBNBConf.CUSTOM_CODE  := 0;
        end if;

        ---
        if ( rExpoOpenData.FldGroup = Schema_GPSys.HeadExpo.ExpoGrpDeposit or
            rExpoOpenData.LoanMode = 'Credit' ) then
          if ( rExpoOpenData.FldGroup = Schema_GPSys.HeadExpo.ExpoGrpDeposit ) then
            if ( rExpoOpenData.VidSrok = Schema_GPSys.HeadExpo.DepositVidSrok_Days ) then
              RecOtherCode.FLDMODE  := 'Days';
            elsif ( rExpoOpenData.VidSrok = Schema_GPSys.HeadExpo.DepositVidSrok_Months ) then
              RecOtherCode.FLDMODE  := 'Months';
            end if;

            RecOtherCode.FLDSROK  := rExpoOpenData.Srok;
          elsif ( rExpoOpenData.LoanMode = 'Credit' ) then
            sLoanTypes  := Schema_GPSys.OraGPSys.GetIniValueInt( rExpoOpenData.UniqCode, 'LOANS', 'TYPES4PERIOD_CODE', '~' );

            if ( nBaseType in (Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg, Schema_GPSys.HeadExpo.ExpoCred_ProsrochenDulg) or
                sLoanTypes like '%&' || to_char( nBaseType ) || '&%' ) then
              RecOtherCode.FLDMODE  := 'Days';
              RecOtherCode.FLDSROK  := rExpoOpenData.CredExpDate - rExpoOpenData.CredOpenDate;
            else
              RecOtherCode.FLDMODE  := null;
            end if;

            open iqQ for
              select CREDCODE,
                     1
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     2
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     3
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     4
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     5
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     6
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF is null and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     7
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     8
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     9
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     10
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     11
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     12
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE is null and
                     CLASSIF is null and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     13
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF is null and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     14
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     15
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA is null and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     PATTERN = nPattWork
              union all
              select CREDCODE,
                     16
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     17
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     18
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     19
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     20
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     21
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF is null and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     22
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     23
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     24
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     25
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     26
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     27
                from BNB_CREDCODE
               where CRED_AIM = rExpoOpenData.CredEngCoverType and
                     PROGRAMA is null and
                     PLAN_TYPE is null and
                     CLASSIF is null and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     28
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA = rExpoOpenData.CredPrograma and
                     PLAN_TYPE is null and
                     CLASSIF is null and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     29
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA is null and
                     PLAN_TYPE = rExpoOpenData.CredPlanType and
                     CLASSIF is null and
                     nvl( PATTERN, 0 ) = 0
              union all
              select CREDCODE,
                     30
                from BNB_CREDCODE
               where CRED_AIM is null and
                     PROGRAMA is null and
                     PLAN_TYPE is null and
                     CLASSIF = rExpoOpenData.CredClassif and
                     nvl( PATTERN, 0 ) = 0
              order by 2;

            fetch iqQ
              into RecBNBConf.TYPOBJ_CODE, nId;

            if ( iqQ%notfound ) then
              RecBNBConf.TYPOBJ_CODE  := -1;
            end if;

            close iqQ;
          end if;

          if ( RecOtherCode.FLDMODE is null ) then
            RecBNBConf.PERIOD_CODE  := 0;
          else
            open iqQ for
              select OTHRCODE,
                     FLDSROK,
                     1
                from BNB_OTHRCODE
               where FLDMODE = ('PERIOD_' || RecOtherCode.FLDMODE) and
                     FLDSROK <= RecOtherCode.FLDSROK and
                     PATTERN = nPattWork
              union all
              select OTHRCODE,
                     FLDSROK,
                     2
                from BNB_OTHRCODE
               where FLDMODE = ('PERIOD_' || RecOtherCode.FLDMODE) and
                     FLDSROK <= RecOtherCode.FLDSROK and
                     nvl( PATTERN, 0 ) = 0
              order by 3 asc,
                       2 desc;

            fetch iqQ
              into RecBNBConf.PERIOD_CODE, RecOtherCode.FLDSROK, nId;

            if ( iqQ%notfound ) then
              RecBNBConf.PERIOD_CODE  := -1;
            end if;

            close iqQ;
          end if;
        else
          RecBNBConf.PERIOD_CODE  := 0;
        end if;

        ---
        if ( rExpoOpenData.FldGroup in (Schema_GPSys.HeadExpo.ExpoGrpEngage, Schema_GPSys.HeadExpo.ExpoGrpCover) ) then
          open iqQ for
            select OTHRCODE,
                   1
              from BNB_OTHRCODE
             where FLDMODE = ('TYPOBJ_' || rExpoOpenData.LoanMode) and
                   FLDVALUE = rExpoOpenData.CredEngCoverType and
                   PATTERN = nPattWork
            union all
            select OTHRCODE,
                   2
              from BNB_OTHRCODE
             where FLDMODE = ('TYPOBJ_' || rExpoOpenData.LoanMode) and
                   FLDVALUE = rExpoOpenData.CredEngCoverType and
                   nvl( PATTERN, 0 ) = 0
            order by 2;

          fetch iqQ
            into RecBNBConf.TYPOBJ_CODE, nId;

          if ( iqQ%notfound ) then
            RecBNBConf.TYPOBJ_CODE  := -1;
          end if;

          close iqQ;
        elsif ( rExpoOpenData.FldGroup != Schema_GPSys.HeadExpo.ExpoGrpCredit ) then
          RecBNBConf.TYPOBJ_CODE  := 0;
        end if;

        ---
        open iqQ for
          select SHIFAR,
                 1
            from BNB_CODECONF
           where PATTERN = nPattWork and
                 TYPEXP_CODE = RecBNBConf.TYPEXP_CODE and
                 CODVAL_CODE = RecBNBConf.CODVAL_CODE and
                 CUSTOM_CODE = RecBNBConf.CUSTOM_CODE and
                 PERIOD_CODE = RecBNBConf.PERIOD_CODE and
                 TYPOBJ_CODE = RecBNBConf.TYPOBJ_CODE
          union all
          select SHIFAR,
                 2
            from BNB_CODECONF
           where PATTERN = nPattWork and
                 TYPEXP_CODE = RecBNBConf.TYPEXP_CODE and
                 CODVAL_CODE = RecBNBConf.CODVAL_CODE and
                 CUSTOM_CODE = RecBNBConf.CUSTOM_CODE and
                 PERIOD_CODE = RecBNBConf.PERIOD_CODE and
                 TYPOBJ_CODE = 0
          union all
          select SHIFAR,
                 3
            from BNB_CODECONF
           where PATTERN = nPattWork and
                 TYPEXP_CODE = RecBNBConf.TYPEXP_CODE and
                 CODVAL_CODE = RecBNBConf.CODVAL_CODE and
                 CUSTOM_CODE = RecBNBConf.CUSTOM_CODE and
                 PERIOD_CODE = 0 and
                 TYPOBJ_CODE = RecBNBConf.TYPOBJ_CODE
          union all
          select SHIFAR,
                 4
            from BNB_CODECONF
           where PATTERN = nPattWork and
                 TYPEXP_CODE = RecBNBConf.TYPEXP_CODE and
                 CODVAL_CODE = RecBNBConf.CODVAL_CODE and
                 CUSTOM_CODE = 0 and
                 PERIOD_CODE = 0 and
                 TYPOBJ_CODE = RecBNBConf.TYPOBJ_CODE
          union all
          select SHIFAR,
                 5
            from BNB_CODECONF
           where PATTERN = nPattWork and
                 TYPEXP_CODE = RecBNBConf.TYPEXP_CODE and
                 CODVAL_CODE = RecBNBConf.CODVAL_CODE and
                 CUSTOM_CODE = 0 and
                 PERIOD_CODE = 0 and
                 TYPOBJ_CODE = 0
          order by 2;

        fetch iqQ
          into RecBNBConf.SHIFAR, nId;

        if ( iqQ%notfound ) then
          RecBNBConf.SHIFAR  := 'ERROR_CODE';
        end if;

        close iqQ;
      end if;
    else
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'TYPE_EXPO';
      aParams( 1 ).ML_VALUE  := to_char( rExpoOpenData.TypeExpo );
      Schema_RA.GPC_RA.RespSetErrorText( 'Непознат тип експозиция $TYPE_EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
    end if;

    return bRet;
  end Expo2BNBCode;

  --------------------------------------------------------------------------------
  function GetShablon4FS_BK(
    rExpoOpenData  in out Schema_GPSys.Cmd_HeadExpo.recExpoOpenData,
    sSchCode       in out BNB_CODECONF.SHIFAR%type
  )
    return boolean is
    RecBNBConf  BNB_CODECONF%rowtype;
    iqQ         Schema_GPSys.OraGPSys.EmpCurTyp;
    sActPass    Schema_GPSys.EXPOTYPES.ACTPASS%type;
    nPattWork   integer;
    bRet        boolean := false;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    nPattWork  := Schema_GPSys.OraGPSys.GetIniValueInt( rExpoOpenData.UniqCode, 'EXPOSITION', 'PATTERN4FS_BK', null );

    open iqQ for
      select FLDGROUP,
             ACTPASS
        from Schema_GPSys.EXPOTYPES
       where TYPE_EXPO = rExpoOpenData.TypeExpo and
             nvl( PATTERN, 0 ) in (0, nPattWork);

    fetch iqQ
      into rExpoOpenData.FldGroup, sActPass;

    bRet       := iqQ%found;

    close iqQ;

    if ( bRet ) then
      if ( nvl( rExpoOpenData.IDCust, 0 ) > 0 ) then
        open iqQ for
          select CLITYPE,
                 FTYPE,
                 SECTORNA,
                 OTRASLOVA
            from Schema_Cust.CUSTOMS
           where id = rExpoOpenData.IDCust;

        fetch iqQ
          into rExpoOpenData.CliType, rExpoOpenData.FType, rExpoOpenData.Sectorna, rExpoOpenData.Otraslova;

        close iqQ;
      end if;

      bRet  := Expo2BNBCode( nvl( nPattWork, BnbPattern_Shablon4FS_BK ), rExpoOpenData, RecBNBConf );

      if ( bRet ) then
        if ( nvl( RecBNBConf.SHIFAR, 'ERROR_CODE' ) = 'ERROR_CODE' ) then
          sSchCode  := '-1';
          bRet      := Schema_GPSys.OraGPSys.My_to_number( Schema_GPSys.OraGPSys.GetIniValue( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'MODE_ACCOUNT', '0' ) ) = 3;

          if ( not bRet ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'TYPE_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( rExpoOpenData.TypeExpo );
            Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $TYPE_EXPO$ не намира позиция в сметкоплана',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;
        else
          if ( sActPass = '*' ) then
            sSchCode  := RecBNBConf.SHIFAR || '1';
          else
            sSchCode  := RecBNBConf.SHIFAR || '0';
          end if;
        end if;
      end if;
    else
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'TYPE_EXPO';
      aParams( 1 ).ML_VALUE  := to_char( rExpoOpenData.TypeExpo );
      Schema_RA.GPC_RA.RespSetErrorText( 'Непознат тип експозиция $TYPE_EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
    end if;

    return bRet;
  end GetShablon4FS_BK;

  --------------------------------------------------------------------------------
  function Expo2ExtCode(
    nIDExpo    in integer,
    nPattWork  in integer default BnbPattern_OraMFS2EQ
  )
    return varchar2 is
    RecBNBConf     BNB_CODECONF%rowtype;
    rExpoOpenData  Schema_GPSys.Cmd_HeadExpo.recExpoOpenData;
    bDummy         boolean := true;

    cursor qExpo( pExpo in integer ) is
      select a.ID_EXPO,
             a.UNIQCODE,
             a.ID_CUST,
             a.TYPE_EXPO,
             a.CODVAL,
             '_' as VID_SROK,
             0 as SROK,
             b.FLDGROUP,
             c.CLITYPE,
             c.FTYPE,
             c.SECTORNA,
             c.OTRASLOVA,
             d.EXPO_CODE
        from Schema_GPSys.EXPOSITION d,
             Schema_Cust.CUSTOMS c,
             Schema_GPSys.EXPOTYPES b,
             OTHER_EXPO a
       where a.ID_EXPO = pExpo and
             a.TYPE_EXPO = b.TYPE_EXPO and
             a.ID_CUST = c.id(+) and
             a.ID_EXPO = d.ID_EXPO
      union all
      select a.ID_EXPO,
             a.UNIQCODE,
             a.ID_CUST,
             a.TYPE_EXPO,
             a.CODVAL,
             '_' as VID_SROK,
             0 as SROK,
             b.FLDGROUP,
             c.CLITYPE,
             c.FTYPE,
             c.SECTORNA,
             c.OTRASLOVA,
             d.EXPO_CODE
        from Schema_GPSys.EXPOSITION d,
             Schema_Cust.CUSTOMS c,
             Schema_GPSys.EXPOTYPES b,
             CURRENT_EXPO a
       where a.ID_EXPO = pExpo and
             a.TYPE_EXPO = b.TYPE_EXPO and
             a.ID_CUST = c.id(+) and
             a.ID_EXPO = d.ID_EXPO
      union all
      select a.ID_EXPO,
             a.UNIQCODE,
             a.ID_CUST,
             a.TYPE_EXPO,
             a.CODVAL,
             a.VID_SROK,
             a.SROK,
             b.FLDGROUP,
             c.CLITYPE,
             c.FTYPE,
             c.SECTORNA,
             c.OTRASLOVA,
             d.EXPO_CODE
        from Schema_GPSys.EXPOSITION d,
             Schema_Cust.CUSTOMS c,
             Schema_GPSys.EXPOTYPES b,
             DEPOSIT_EXPO a
       where a.ID_EXPO = pExpo and
             a.TYPE_EXPO = b.TYPE_EXPO and
             a.ID_CUST = c.id(+) and
             a.ID_EXPO = d.ID_EXPO;

  begin
    open qExpo( nIDExpo );

    fetch qExpo
      into rExpoOpenData.IDExpo,
           rExpoOpenData.UniqCode,
           rExpoOpenData.IDCust,
           rExpoOpenData.TypeExpo,
           rExpoOpenData.CodVal,
           rExpoOpenData.VidSrok,
           rExpoOpenData.Srok,
           rExpoOpenData.FldGroup,
           rExpoOpenData.CliType,
           rExpoOpenData.FType,
           rExpoOpenData.Sectorna,
           rExpoOpenData.Otraslova,
           rExpoOpenData.ExpoCode;

    close qExpo;

    if ( rExpoOpenData.FldGroup in (Schema_GPSys.HeadExpo.ExpoGrpCredit, Schema_GPSys.HeadExpo.ExpoGrpEngage, Schema_GPSys.HeadExpo.ExpoGrpCover) ) then
      bDummy  := GetOthrExpoTypes( rExpoOpenData.FldGroup, rExpoOpenData.IDExpo, rExpoOpenData.CredEngCoverType, rExpoOpenData.LoanMode, rExpoOpenData.CredPrograma );
    end if;

    if ( bDummy ) then
      bDummy  := Expo2BNBCode( nPattWork, rExpoOpenData, RecBNBConf );
    end if;

    return RecBNBConf.SHIFAR;
  end Expo2ExtCode;

  --------------------------------------------------------------------------------
  function FillBNBCodes(
    nUniqCode  in integer,
    nPattern   in integer,
    dToDate    in date
  )
    return boolean is
    iqQ            Schema_GPSys.OraGPSys.EmpCurTyp;
    rExpoOpenData  Schema_GPSys.Cmd_HeadExpo.recExpoOpenData;
    RecBNBConf     BNB_CODECONF%rowtype;
    RecBNBLog      BNB_CODE_LOG%rowtype;
    bRet           boolean;
    bDummy         boolean;
    nUniqWork      integer;
    nPattWork      integer;
    nUserID        integer;
    nID            integer;
    nSaldoDt       number;
    nSaldoKt       number;
    nOborDt        number;
    nOborKt        number;
    nDiffer        number;
    aParams        Schema_RA.GPC_RA.tblErrParams;
  begin
    nUniqWork  := nvl( nUniqCode, -1 );
    nPattWork  := nvl( nPattern, 0 );
    nUserID    := nvl( Schema_RA.GPC_RA.nCurrentUserID, 0 );
    bRet       := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqWork );

    if ( bRet ) then
      delete from BNB_CODE_LOG
            where UNIQCODE = nUniqWork and
                  PATTERN = nPattWork and
                  TODATE = dToDate;

      commit;

      for rec in ( select a.ID_EXPO,
                          a.UNIQCODE,
                          a.ID_CUST,
                          a.TYPE_EXPO,
                          a.CODVAL,
                          '_' as VID_SROK,
                          0 as SROK,
                          b.FLDGROUP,
                          c.CLITYPE,
                          c.FTYPE,
                          c.SECTORNA,
                          c.OTRASLOVA,
                          d.EXPO_CODE
                     from OTHER_EXPO a,
                          Schema_GPSys.EXPOTYPES b,
                          Schema_Cust.CUSTOMS c,
                          Schema_GPSys.EXPOSITION d
                    where ( nUniqWork = -1 or
                           a.UNIQCODE = nUniqWork ) and
                          ( a.CLOSE_DATE is null or
                           a.CLOSE_DATE > dToDate ) and
                          a.TYPE_EXPO = b.TYPE_EXPO and
                          a.ID_CUST = c.id(+) and
                          a.ID_EXPO = d.ID_EXPO
                  union all
                  select a.ID_EXPO,
                         a.UNIQCODE,
                         a.ID_CUST,
                         a.TYPE_EXPO,
                         a.CODVAL,
                         '_' as VID_SROK,
                         0 as SROK,
                         b.FLDGROUP,
                         c.CLITYPE,
                         c.FTYPE,
                         c.SECTORNA,
                         c.OTRASLOVA,
                         d.EXPO_CODE
                    from CURRENT_EXPO a,
                         Schema_GPSys.EXPOTYPES b,
                         Schema_Cust.CUSTOMS c,
                         Schema_GPSys.EXPOSITION d
                   where ( nUniqWork = -1 or
                          a.UNIQCODE = nUniqWork ) and
                         ( a.CLOSE_DATE is null or
                          a.CLOSE_DATE > dToDate ) and
                         a.TYPE_EXPO = b.TYPE_EXPO and
                         a.ID_CUST = c.id(+) and
                         a.ID_EXPO = d.ID_EXPO
                  union all
                  select a.ID_EXPO,
                         a.UNIQCODE,
                         a.ID_CUST,
                         a.TYPE_EXPO,
                         a.CODVAL,
                         a.VID_SROK,
                         a.SROK,
                         b.FLDGROUP,
                         c.CLITYPE,
                         c.FTYPE,
                         c.SECTORNA,
                         c.OTRASLOVA,
                         d.EXPO_CODE
                    from DEPOSIT_EXPO a,
                         Schema_GPSys.EXPOTYPES b,
                         Schema_Cust.CUSTOMS c,
                         Schema_GPSys.EXPOSITION d
                   where ( nUniqWork = -1 or
                          a.UNIQCODE = nUniqWork ) and
                         ( a.CLOSE_DATE is null or
                          a.CLOSE_DATE > dToDate ) and
                         a.TYPE_EXPO = b.TYPE_EXPO and
                         a.ID_CUST = c.id(+) and
                         a.ID_EXPO = d.ID_EXPO ) loop
        RecBNBConf               := null;
        RecBNBLog                := null;
        rExpoOpenData            := null;

        if ( Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( rec.UNIQCODE, 'Счетоводство', 'ПреоценкаЕкспозиции', 'T' ) ) ) then
          nSaldoKt  := ESysSaldoDate( rec.ID_EXPO, dToDate, false, nOborDt, nOborKt );
        else
          nSaldoKt  := ExpoSaldoDate( rec.ID_EXPO, dToDate, false, nOborDt, nOborKt );

          if ( rec.CODVAL != Schema_GPSys.OraGPSys.SYS_CURR ) then
            nOborDt   := Schema_GPSys.XchgRates.GetExactSum( nOborDt, rec.UNIQCODE, dToDate, rec.CODVAL, Schema_GPSys.OraGPSys.SYS_CURR, Schema_GPSys.XchgRates.XchgRateType_Fixing );
            nOborKt   := Schema_GPSys.XchgRates.GetExactSum( nOborKt, rec.UNIQCODE, dToDate, rec.CODVAL, Schema_GPSys.OraGPSys.SYS_CURR, Schema_GPSys.XchgRates.XchgRateType_Fixing );
            nSaldoKt  := nOborKt - nOborDt;
          end if;
        end if;

        if ( nSaldoKt < 0 ) then
          nSaldoDt  := -nSaldoKt;
          nSaldoKt  := 0;
        else
          nSaldoDt  := 0;
        end if;

        rExpoOpenData.IDExpo     := rec.ID_EXPO;
        rExpoOpenData.IDCust     := rec.ID_CUST;
        rExpoOpenData.TypeExpo   := rec.TYPE_EXPO;
        rExpoOpenData.CodVal     := rec.CODVAL;
        rExpoOpenData.CliType    := rec.CLITYPE;
        rExpoOpenData.FType      := rec.FTYPE;
        rExpoOpenData.Sectorna   := rec.SECTORNA;
        rExpoOpenData.Otraslova  := rec.OTRASLOVA;
        rExpoOpenData.FldGroup   := rec.FLDGROUP;
        rExpoOpenData.VidSrok    := rec.VID_SROK;
        rExpoOpenData.Srok       := rec.SROK;

        if ( rec.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit ) then
          nId                     := Loans.IDExpo2IDCredEngage( rec.ID_EXPO );
          rExpoOpenData.LoanMode  := 'Credit';

          open iqQ for
            select CRED_AIM,
                   PROGRAMA,
                   PLAN_TYPE,
                   CLASSIF,
                   OPEN_DATE,
                   EXP_DATE
              from LOAN_CREDIT
             where ID_CRED_ENGAGE = nID
            union all
            select CRED_AIM,
                   PROGRAMA,
                   PLAN_TYPE,
                   CLASSIF,
                   OPEN_DATE,
                   EXP_DATE
              from LOAN_CREDIT_DEP
             where ID_CRED_ENGAGE = nID;

          fetch iqQ
            into rExpoOpenData.CredEngCoverType, rExpoOpenData.CredPrograma, rExpoOpenData.CredPlanType, rExpoOpenData.CredClassif, rExpoOpenData.CredOpenDate, rExpoOpenData.CredExpDate;

          bDummy                  := iqQ%found;

          close iqQ;

          if ( bDummy ) then
            begin
              select OPEN_DATE,
                     EXP_DATE
                into rExpoOpenData.CredOpenDate,
                     rExpoOpenData.CredExpDate
                from (select OPEN_DATE,
                             EXP_DATE
                        from LOAN_CREDIT_A
                       where ID_CRED_ENGAGE = nID and
                             ARC_DATE = (select min( ARC_DATE )
                                           from LOAN_CREDIT_A
                                          where ID_CRED_ENGAGE = nID and
                                                STATUS = Loans.LoanStat_Active)
                      union all
                      select OPEN_DATE,
                             EXP_DATE
                        from LOAN_CREDIT_DEP_A
                       where ID_CRED_ENGAGE = nID and
                             ARC_DATE = (select min( ARC_DATE )
                                           from LOAN_CREDIT_DEP_A
                                          where ID_CRED_ENGAGE = nID and
                                                STATUS = Loans.LoanStat_Active));
            exception
              when no_data_found then
                null;
            end;
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( rec.ID_EXPO );
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсващо досие на кредит за експозиция $ID_EXPO$', Schema_GPSys.MLng.ctxLoans, Schema_GPSys.MLng.lngBG, aParams );
          end if;
        elsif ( rec.FLDGROUP in (Schema_GPSys.HeadExpo.ExpoGrpEngage, Schema_GPSys.HeadExpo.ExpoGrpCover) ) then
          bDummy  := GetOthrExpoTypes( rec.FLDGROUP, rec.ID_EXPO, rExpoOpenData.CredEngCoverType, rExpoOpenData.LoanMode, rExpoOpenData.CredPrograma );
        else
          bDummy  := true;
        end if;

        if ( bDummy ) then
          bRet  := Expo2BNBCode( nPattWork, rExpoOpenData, RecBNBConf );
        else
          RecBNBConf.SHIFAR  := 'ERROR_DOSIE';
        end if;

        if ( bRet ) then
          insert into BNB_CODE_LOG(
                        USERID,
                        UNIQCODE,
                        PATTERN,
                        TODATE,
                        ID_EXPO,
                        TYPEXP_CODE,
                        CODVAL_CODE,
                        CUSTOM_CODE,
                        PERIOD_CODE,
                        TYPOBJ_CODE,
                        SHIFAR,
                        SALDO_DT,
                        SALDO_KT,
                        OBOROT_DT,
                        OBOROT_KT,
                        TYPE_EXPO,
                        CODVAL,
                        EXPO_CODE,
                        CLITYPE,
                        FTYPE,
                        SECTORNA,
                        OTRASLOVA,
                        CRED_AIM,
                        PROGRAMA,
                        PLAN_TYPE,
                        CLASSIF,
                        VID_SROK,
                        SROK,
                        LOANMODE
                      )
               values ( nUserID,
                        nUniqWork,
                        nPattWork,
                        dToDate,
                        rec.ID_EXPO,
                        RecBNBConf.TYPEXP_CODE,
                        RecBNBConf.CODVAL_CODE,
                        RecBNBConf.CUSTOM_CODE,
                        RecBNBConf.PERIOD_CODE,
                        RecBNBConf.TYPOBJ_CODE,
                        RecBNBConf.SHIFAR,
                        nSaldoDt,
                        nSaldoKt,
                        nOborDt,
                        nOborKt,
                        rExpoOpenData.TypeExpo,
                        rExpoOpenData.CodVal,
                        rec.EXPO_CODE,
                        rExpoOpenData.CliType,
                        rExpoOpenData.FType,
                        rExpoOpenData.Sectorna,
                        rExpoOpenData.Otraslova,
                        rExpoOpenData.CredEngCoverType,
                        rExpoOpenData.CredPrograma,
                        rExpoOpenData.CredPlanType,
                        rExpoOpenData.CredClassif,
                        rExpoOpenData.VidSrok,
                        rExpoOpenData.Srok,
                        rExpoOpenData.LoanMode
                       );

          commit;
        end if;

        exit when not bRet;
      end loop;

      if ( bRet ) then
        select sum( OBOROT_DT ),
               sum( OBOROT_KT )
          into nOborDt,
               nOborKt
          from BNB_CODE_LOG
         where UNIQCODE = nUniqWork and
               PATTERN = nPattWork and
               TODATE = dToDate;

        nDiffer  := nvl( nOborKt, 0 ) - nvl( nOborKt, 0 );

        if ( nDiffer != 0 ) then
          if ( nDiffer > 0 ) then
            open iqQ for
                select ID_EXPO,
                       SALDO_DT,
                       SALDO_KT,
                       OBOROT_DT,
                       OBOROT_KT
                  from BNB_CODE_LOG
                 where UNIQCODE = nUniqWork and
                       PATTERN = nPattWork and
                       TODATE = dToDate
              order by 5 desc;

            fetch iqQ
              into nID, nSaldoDt, nSaldoKt, nOborDt, nOborKt;

            close iqQ;

            nOborKt  := nOborKt - nDiffer;
          else
            open iqQ for
                select ID_EXPO,
                       SALDO_DT,
                       SALDO_KT,
                       OBOROT_DT,
                       OBOROT_KT
                  from BNB_CODE_LOG
                 where UNIQCODE = nUniqWork and
                       PATTERN = nPattWork and
                       TODATE = dToDate
              order by 4 desc;

            fetch iqQ
              into nID, nSaldoDt, nSaldoKt, nOborDt, nOborKt;

            close iqQ;

            nOborDt  := nOborDt + nDiffer;
          end if;

          nSaldoKt  := nOborKt - nOborDt;

          if ( nSaldoKt < 0 ) then
            nSaldoDt  := -nSaldoKt;
            nSaldoKt  := 0;
          end if;

          update BNB_CODE_LOG
             set SALDO_DT   = nSaldoDt,
                 SALDO_KT   = nSaldoKt,
                 OBOROT_DT  = nOborDt,
                 OBOROT_KT  = nOborKt
           where UNIQCODE = nUniqWork and
                 PATTERN = nPattWork and
                 TODATE = dToDate and
                 ID_EXPO = nID;
        end if;
      end if;

      bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqWork );
    else
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'UNIQWORK';
      aParams( 1 ).ML_VALUE  := to_char( nUniqWork );
      Schema_RA.GPC_RA.RespSetErrorText( 'Неуспешен опит за забрана на счетоводни операции в поделение $UNIQWORK$',
                                         Schema_GPSys.MLng.ctxAccounting,
                                         Schema_GPSys.MLng.lngBG,
                                         aParams
                                        );
    end if;

    return bRet;
  end FillBNBCodes;

  --------------------------------------------------------------------------------
  function GetOthrExpoTypes(
    nExpoGrp      in     integer,
    nIdExpo       in     integer,
    sCredEngType  in out varchar2,
    sMode         in out varchar2,
    sCredProgram  in out varchar2
  )
    return boolean is
    bRet     boolean := false;
    nId      integer;
    aParams  Schema_RA.GPC_RA.tblErrParams;
  begin
    sMode         := null;
    sCredEngType  := null;
    sCredProgram  := null;

    if ( nExpoGrp in (Schema_GPSys.HeadExpo.ExpoGrpCredit, Schema_GPSys.HeadExpo.ExpoGrpEngage, Schema_GPSys.HeadExpo.ExpoGrpCover) ) then
      if ( nExpoGrp = Schema_GPSys.HeadExpo.ExpoGrpCredit ) then
        nId    := Loans.IDExpo2IDCredEngage( nIdExpo );
        sMode  := 'Credit';

        begin
          select CRED_AIM,
                 PROGRAMA
            into sCredEngType,
                 sCredProgram
            from LOAN_CREDIT
           where ID_CRED_ENGAGE = nID;

          bRet  := true;
        exception
          when no_data_found then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( nIdExpo );
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсващо досие на кредит за експозиция $ID_EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
        end;
      elsif ( nExpoGrp = Schema_GPSys.HeadExpo.ExpoGrpEngage ) then
        nId    := Loans.IDExpo2IDCredEngage( nIdExpo );
        sMode  := 'Engage';

        begin
          select ENGAGE_TYPE,
                 ENGAGE_AIM
            into sCredEngType,
                 sCredProgram
            from LOAN_ENGAGE
           where ID_CRED_ENGAGE = nID;

          bRet  := true;
        exception
          when no_data_found then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( nIdExpo );
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсващо досие на ангажимент за експозиция $ID_EXPO$',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
        end;
      elsif ( nExpoGrp = Schema_GPSys.HeadExpo.ExpoGrpCover ) then
        sMode  := 'Cover';

        begin
          select COVER_MODE
            into sCredEngType
            from LOAN_COVER
           where ID_EXPO = nIdExpo and
                 rownum < 2;

          bRet  := true;
        exception
          when no_data_found then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( nIdExpo );
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсващо досие на обезпечение за експозиция $ID_EXPO$',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
        end;
      end if;
    end if;

    return bRet;
  end GetOthrExpoTypes;

  --------------------------------------------------------------------------------
  function CalcEAllAverageSaldo(
    nIDExpo        in     integer,
    dBegDate       in     date,
    dEndDate       in     date,
    bValior        in     boolean,
    nSysSaldo      in out number,
    cSynt          in     varchar2 default null,
    bValiorPeriod  in     boolean default false
  )
    return number is
    nOrgSaldo   number := 0;
    nSaldoDt    number;
    nSaldoKt    number;
    ii          pls_integer := 0;
    dNextDate   date;

    type rSaldoDate is record(
      dWrkDate   date,
      nOrgSaldo  number,
      nSysSaldo  number
    );

    type taSaldoDate is table of rSaldoDate
      index by binary_integer;

    aSaldoDate  taSaldoDate;

    cursor qAverageV(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date
    ) is
        select sum( ORG_AMOUNT ) as ORG_AMOUNT,
               sum( SYS_AMOUNT ) as SYS_AMOUNT,
               VALIOR
          from ((  select sum( decode( DT_KT, 'D', AMOUNT, -AMOUNT ) ) as ORG_AMOUNT,
                          sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as SYS_AMOUNT,
                          VALIOR
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          VALIOR >= dqBegDate
                 group by VALIOR )
                union all
                ( select 0 as ORG_AMOUNT,
                         0 as SYS_AMOUNT,
                         dqBegDate as VALIOR
                    from dual )
                union all
                ( select 0 as ORG_AMOUNT,
                         0 as SYS_AMOUNT,
                         dqEndDate as VALIOR
                    from dual ))
      group by VALIOR
      order by VALIOR desc;

    cursor qAverageVP(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date
    ) is
        select sum( ORG_AMOUNT ) as ORG_AMOUNT,
               sum( SYS_AMOUNT ) as SYS_AMOUNT,
               VALIOR_PERIOD
          from ((  select sum( decode( DT_KT, 'D', AMOUNT, -AMOUNT ) ) as ORG_AMOUNT,
                          sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as SYS_AMOUNT,
                          VALIOR_PERIOD
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          VALIOR_PERIOD >= dqBegDate
                 group by VALIOR_PERIOD )
                union all
                ( select 0 as ORG_AMOUNT,
                         0 as SYS_AMOUNT,
                         dqBegDate as VALIOR_PERIOD
                    from dual )
                union all
                ( select 0 as ORG_AMOUNT,
                         0 as SYS_AMOUNT,
                         dqEndDate as VALIOR_PERIOD
                    from dual ))
      group by VALIOR_PERIOD
      order by VALIOR_PERIOD desc;

    cursor qAverageD(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date
    ) is
        select sum( ORG_AMOUNT ) as ORG_AMOUNT,
               sum( SYS_AMOUNT ) as SYS_AMOUNT,
               SCH_DATE
          from ((  select sum( decode( DT_KT, 'D', AMOUNT, -AMOUNT ) ) as ORG_AMOUNT,
                          sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as SYS_AMOUNT,
                          SCH_DATE
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          SCH_DATE >= dqBegDate
                 group by SCH_DATE )
                union all
                ( select 0 as ORG_AMOUNT,
                         0 as SYS_AMOUNT,
                         dqBegDate as SCH_DATE
                    from dual )
                union all
                ( select 0 as ORG_AMOUNT,
                         0 as SYS_AMOUNT,
                         dqEndDate as SCH_DATE
                    from dual ))
      group by SCH_DATE
      order by SCH_DATE desc;

  begin
    nSysSaldo  := 0;

    if ( dBegDate <= dEndDate and
        GetEAllHotSaldo( nIDExpo, nOrgSaldo, nSysSaldo ) ) then
      if ( bValior ) then
        if ( bValiorPeriod ) then
          for Rec in qAverageVP( nIdExpo, dBegDate, dEndDate ) loop
            if ( Rec.VALIOR_PERIOD <= dEndDate ) then
              ii                          := ii + 1;
              aSaldoDate( ii ).dWrkDate   := Rec.VALIOR_PERIOD;
              aSaldoDate( ii ).nOrgSaldo  := nOrgSaldo;
              aSaldoDate( ii ).nSysSaldo  := nSysSaldo;
            end if;

            nOrgSaldo  := nOrgSaldo + Rec.ORG_AMOUNT;
            nSysSaldo  := nSysSaldo + Rec.SYS_AMOUNT;
          end loop;
        else
          for Rec in qAverageV( nIdExpo, dBegDate, dEndDate ) loop
            if ( Rec.VALIOR <= dEndDate ) then
              ii                          := ii + 1;
              aSaldoDate( ii ).dWrkDate   := Rec.VALIOR;
              aSaldoDate( ii ).nOrgSaldo  := nOrgSaldo;
              aSaldoDate( ii ).nSysSaldo  := nSysSaldo;
            end if;

            nOrgSaldo  := nOrgSaldo + Rec.ORG_AMOUNT;
            nSysSaldo  := nSysSaldo + Rec.SYS_AMOUNT;
          end loop;
        end if;
      else
        for Rec in qAverageD( nIdExpo, dBegDate, dEndDate ) loop
          if ( Rec.SCH_DATE <= dEndDate ) then
            ii                          := ii + 1;
            aSaldoDate( ii ).dWrkDate   := Rec.SCH_DATE;
            aSaldoDate( ii ).nOrgSaldo  := nOrgSaldo;
            aSaldoDate( ii ).nSysSaldo  := nSysSaldo;
          end if;

          nOrgSaldo  := nOrgSaldo + Rec.ORG_AMOUNT;
          nSysSaldo  := nSysSaldo + Rec.SYS_AMOUNT;
        end loop;
      end if;

      nOrgSaldo  := 0;
      nSysSaldo  := 0;

      for jj in reverse aSaldoDate.first .. aSaldoDate.last loop
        if ( cSynt is not null and
            aSaldoDate( jj ).nSysSaldo != 0 ) then
          dNextDate  := aSaldoDate( jj ).dWrkDate;

          if ( aSaldoDate( jj ).nSysSaldo < 0 ) then
            nSaldoDt  := -aSaldoDate( jj ).nSysSaldo;
            nSaldoKt  := 0;
          else
            nSaldoKt  := aSaldoDate( jj ).nSysSaldo;
            nSaldoDt  := 0;
          end if;

          while ( ( dNextDate = dEndDate and
                   jj = 1 ) or
                 ( jj > 1 and
                  dNextDate < aSaldoDate( jj - 1 ).dWrkDate ) ) loop
            update AVRSALDODATE
               set SALDODT  = SALDODT + nSaldoDt,
                   SALDOKT  = SALDOKT + nSaldoKt
             where EXPO_CODE = cSynt and
                   DDATE = dNextDate;

            if ( sql%rowcount = 0 ) then
              insert into AVRSALDODATE(
                            EXPO_CODE,
                            DDATE,
                            SALDODT,
                            SALDOKT
                          )
                   values ( cSynt,
                            dNextDate,
                            nSaldoDt,
                            nSaldoKt
                           );
            end if;

            dNextDate  := dNextDate + 1;
          end loop;
        end if;

        if ( aSaldoDate( jj ).dWrkDate = dEndDate ) then
          nOrgSaldo  := nOrgSaldo + aSaldoDate( jj ).nOrgSaldo;
          nSysSaldo  := nSysSaldo + aSaldoDate( jj ).nSysSaldo;
          exit;
        else
          nOrgSaldo  := nOrgSaldo + ( aSaldoDate( jj ).nOrgSaldo * ( aSaldoDate( jj - 1 ).dWrkDate - aSaldoDate( jj ).dWrkDate ) );
          nSysSaldo  := nSysSaldo + ( aSaldoDate( jj ).nSysSaldo * ( aSaldoDate( jj - 1 ).dWrkDate - aSaldoDate( jj ).dWrkDate ) );
        end if;
      end loop;

      nOrgSaldo  := nOrgSaldo / ( dEndDate - dBegDate + 1 );
      nSysSaldo  := nSysSaldo / ( dEndDate - dBegDate + 1 );
    end if;

    return nOrgSaldo;
  end CalcEAllAverageSaldo;

  --------------------------------------------------------------------------------
  function CalcExpoAverageSaldo(
    nIDExpo   in integer,
    dBegDate  in date,
    dEndDate  in date,
    bValior   in boolean
  )
    return number is
    nSaldo      number := 0;
    ii          pls_integer := 0;

    type rSaldoDate is record(
      dWrkDate  date,
      nSaldo    number
    );

    type taSaldoDate is table of rSaldoDate
      index by binary_integer;

    aSaldoDate  taSaldoDate;

    cursor qAverageV(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date
    ) is
        select sum( AMOUNT ) as AMOUNT,
               VALIOR
          from ((  select sum( decode( DT_KT, 'D', AMOUNT, -AMOUNT ) ) as AMOUNT,
                          VALIOR
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          VALIOR >= dqBegDate and
                          AMOUNT != 0
                 group by VALIOR )
                union all
                ( select 0 as AMOUNT,
                         dqBegDate as VALIOR
                    from dual )
                union all
                ( select 0 as AMOUNT,
                         dqEndDate as VALIOR
                    from dual ))
      group by VALIOR
      order by VALIOR desc;

    cursor qAverageD(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date
    ) is
        select sum( AMOUNT ) as AMOUNT,
               SCH_DATE
          from ((  select sum( decode( DT_KT, 'D', AMOUNT, -AMOUNT ) ) as AMOUNT,
                          SCH_DATE
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          SCH_DATE >= dqBegDate and
                          AMOUNT != 0
                 group by SCH_DATE )
                union all
                ( select 0 as AMOUNT,
                         dqBegDate as SCH_DATE
                    from dual )
                union all
                ( select 0 as AMOUNT,
                         dqEndDate as SCH_DATE
                    from dual ))
      group by SCH_DATE
      order by SCH_DATE desc;

  begin
    if ( dBegDate <= dEndDate and
        GetExpoHotSaldo( nIDExpo, nSaldo ) ) then
      if ( bValior ) then
        for Rec in qAverageV( nIdExpo, dBegDate, dEndDate ) loop
          if ( Rec.VALIOR <= dEndDate ) then
            ii                         := ii + 1;
            aSaldoDate( ii ).dWrkDate  := Rec.VALIOR;
            aSaldoDate( ii ).nSaldo    := nSaldo;
          end if;

          nSaldo  := nSaldo + Rec.AMOUNT;
        end loop;
      else
        for Rec in qAverageD( nIdExpo, dBegDate, dEndDate ) loop
          if ( Rec.SCH_DATE <= dEndDate ) then
            ii                         := ii + 1;
            aSaldoDate( ii ).dWrkDate  := Rec.SCH_DATE;
            aSaldoDate( ii ).nSaldo    := nSaldo;
          end if;

          nSaldo  := nSaldo + Rec.AMOUNT;
        end loop;
      end if;

      nSaldo  := 0;

      for jj in reverse aSaldoDate.first .. aSaldoDate.last loop
        if ( aSaldoDate( jj ).dWrkDate = dEndDate ) then
          nSaldo  := nSaldo + aSaldoDate( jj ).nSaldo;
          exit;
        else
          nSaldo  := nSaldo + ( aSaldoDate( jj ).nSaldo * ( aSaldoDate( jj - 1 ).dWrkDate - aSaldoDate( jj ).dWrkDate ) );
        end if;
      end loop;

      nSaldo  := nSaldo / ( dEndDate - dBegDate + 1 );
    end if;

    return nSaldo;
  end CalcExpoAverageSaldo;

  --------------------------------------------------------------------------------
  function CalcESysAverageSaldo(
    nIDExpo   in integer,
    dBegDate  in date,
    dEndDate  in date,
    bValior   in boolean
  )
    return number is
    nSaldo      number := 0;
    ii          pls_integer := 0;

    type rSaldoDate is record(
      dWrkDate  date,
      nSaldo    number
    );

    type taSaldoDate is table of rSaldoDate
      index by binary_integer;

    aSaldoDate  taSaldoDate;

    cursor qAverageV(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date
    ) is
        select sum( SYS_AMOUNT ) as SYS_AMOUNT,
               VALIOR
          from ((  select sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as SYS_AMOUNT,
                          VALIOR
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          VALIOR >= dqBegDate
                 group by VALIOR )
                union all
                ( select 0 as SYS_AMOUNT,
                         dqBegDate as VALIOR
                    from dual )
                union all
                ( select 0 as SYS_AMOUNT,
                         dqEndDate as VALIOR
                    from dual ))
      group by VALIOR
      order by VALIOR desc;

    cursor qAverageD(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date
    ) is
        select sum( SYS_AMOUNT ) as SYS_AMOUNT,
               SCH_DATE
          from ((  select sum( decode( DT_KT, 'D', SYS_AMOUNT, -SYS_AMOUNT ) ) as SYS_AMOUNT,
                          SCH_DATE
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          SCH_DATE >= dqBegDate
                 group by SCH_DATE )
                union all
                ( select 0 as SYS_AMOUNT,
                         dqBegDate as SCH_DATE
                    from dual )
                union all
                ( select 0 as SYS_AMOUNT,
                         dqEndDate as SCH_DATE
                    from dual ))
      group by SCH_DATE
      order by SCH_DATE desc;

  begin
    if ( dBegDate <= dEndDate and
        GetESysHotSaldo( nIDExpo, nSaldo ) ) then
      if ( bValior ) then
        for Rec in qAverageV( nIdExpo, dBegDate, dEndDate ) loop
          if ( Rec.VALIOR <= dEndDate ) then
            ii                         := ii + 1;
            aSaldoDate( ii ).dWrkDate  := Rec.VALIOR;
            aSaldoDate( ii ).nSaldo    := nSaldo;
          end if;

          nSaldo  := nSaldo + Rec.SYS_AMOUNT;
        end loop;
      else
        for Rec in qAverageD( nIdExpo, dBegDate, dEndDate ) loop
          if ( Rec.SCH_DATE <= dEndDate ) then
            ii                         := ii + 1;
            aSaldoDate( ii ).dWrkDate  := Rec.SCH_DATE;
            aSaldoDate( ii ).nSaldo    := nSaldo;
          end if;

          nSaldo  := nSaldo + Rec.SYS_AMOUNT;
        end loop;
      end if;

      nSaldo  := 0;

      for jj in reverse aSaldoDate.first .. aSaldoDate.last loop
        if ( aSaldoDate( jj ).dWrkDate = dEndDate ) then
          nSaldo  := nSaldo + aSaldoDate( jj ).nSaldo;
          exit;
        else
          nSaldo  := nSaldo + ( aSaldoDate( jj ).nSaldo * ( aSaldoDate( jj - 1 ).dWrkDate - aSaldoDate( jj ).dWrkDate ) );
        end if;
      end loop;

      nSaldo  := nSaldo / ( dEndDate - dBegDate + 1 );
    end if;

    return nSaldo;
  end CalcESysAverageSaldo;

  --------------------------------------------------------------------------------
  function GetExpoOpenDate( nIDExpo in integer )
    return date is
    dOpenDate  date;

    cursor iqQ( nExpo in integer ) is
      select OPEN_DATE
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union all
      select OPEN_DATE
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo
      union all
      select OPEN_DATE
        from OTHER_EXPO
       where ID_EXPO = nExpo;

  begin
    open iqQ( nIDExpo );

    fetch iqQ
      into dOpenDate;

    close iqQ;

    return dOpenDate;
  end GetExpoOpenDate;

  --------------------------------------------------------------------------------
  function GetExpoCloseDate( nIDExpo in integer )
    return date is
    dCloseDate  date;

    cursor iqQ( nExpo in integer ) is
      select CLOSE_DATE
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union all
      select CLOSE_DATE
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo
      union all
      select CLOSE_DATE
        from OTHER_EXPO
       where ID_EXPO = nExpo;

  begin
    open iqQ( nIDExpo );

    fetch iqQ
      into dCloseDate;

    close iqQ;

    return dCloseDate;
  end GetExpoCloseDate;

  --------------------------------------------------------------------------------
  function GetExpoPreferMode( nIDExpo in integer )
    return integer is
    nPreferMode  integer;

    cursor iqQ( nExpo in integer ) is
      select PREFER_MODE
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union all
      select PREFER_MODE
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo
      union all
      select PREFER_MODE
        from OTHER_EXPO
       where ID_EXPO = nExpo;

  begin
    open iqQ( nIDExpo );

    fetch iqQ
      into nPreferMode;

    close iqQ;

    return nvl( nPreferMode, 0 );
  end GetExpoPreferMode;

  --------------------------------------------------------------------------------
  function Check4CashZapor( nIDMove in integer )
    return boolean is
    xxx  integer;
  begin
    select count( 1 )
      into xxx
      from EXPO_LIMITS
     where ID_LIMIT = nIDMove and
           TYPE_LIMIT = ExpoLimit_CashZapor and
           STATUS = ZaporStat_Active;

    return nvl( xxx, 0 ) > 0;
  end Check4CashZapor;

  --------------------------------------------------------------------------------
  function CheckExpo4Limit(
    nIDExpo     in integer,
    dToDate     in date,
    sTypeLimit  in varchar2
  )
    return boolean is
    ii  integer := 0;
  begin
    select count( 1 )
      into ii
      from EXPO_LIMITS
     where ID_EXPO = nIDExpo and
           TYPE_LIMIT = sTypeLimit and
           ( BEG_DATE is null or
            BEG_DATE <= dToDate ) and
           ( END_DATE is null or
            dToDate <= END_DATE ) and
           STATUS = ZaporStat_Active;

    return ii > 0;
  end CheckExpo4Limit;

  --------------------------------------------------------------------------------
  function Check4Limits(
    nIDExpo  in integer,
    dDate    in date
  )
    return varchar2 is
    cSymbol  varchar2( 11 ) := '___________';

    cursor qLimit(
      nExpo    in integer,
      dToDate  in date
    ) is
      select TYPE_LIMIT
        from EXPO_LIMITS
       where ID_EXPO = nExpo and
             ( BEG_DATE is null or
              BEG_DATE <= dToDate ) and
             ( END_DATE is null or
              dToDate <= END_DATE ) and
             STATUS = ZaporStat_Active;

  begin
    for rec in qLimit( nIDExpo, dDate ) loop
      if ( rec.TYPE_LIMIT in (ExpoLimit_Limit, ExpoLimit_CardMNO) ) then
        cSymbol  := 'L' || substr( cSymbol, 2 );
      elsif ( rec.TYPE_LIMIT = ExpoLimit_CashZapor ) then
        cSymbol  := substr( cSymbol, 1, 1 ) || 'C' || substr( cSymbol, 3 );
      elsif ( rec.TYPE_LIMIT = ExpoLimit_NormalZapor ) then
        cSymbol  := substr( cSymbol, 1, 2 ) || 'Z' || substr( cSymbol, 4 );
      elsif ( rec.TYPE_LIMIT in (ExpoLimit_SudebenZapor, ExpoLimit_SudebenIntrnl, ExpoLimit_SudebenExtrnl, ExpoLimit_ForbiddenKT) ) then
        cSymbol  := substr( cSymbol, 1, 4 ) || 'D' || substr( cSymbol, 6 );
      elsif ( rec.TYPE_LIMIT = ExpoLimit_NormalZapor1 ) then
        cSymbol  := substr( cSymbol, 1, 5 ) || 'F' || substr( cSymbol, 7 );
      elsif ( rec.TYPE_LIMIT in
               ( ExpoLimit_NormalZapor2,
                ExpoLimit_NormalZapor3,
                ExpoLimit_NormalZapor4,
                ExpoLimit_NormalZapor5,
                ExpoLimit_NormalZapor6,
                ExpoLimit_NormalZapor7,
                ExpoLimit_NormalZapor8,
                ExpoLimit_NormalZapor9 ) ) then
        cSymbol  := substr( cSymbol, 1, 6 ) || 'K' || substr( cSymbol, 8 );
      elsif ( rec.TYPE_LIMIT = ExpoLimit_CardAuth ) then
        cSymbol  := substr( cSymbol, 1, 7 ) || 'A' || substr( cSymbol, 9 );
      elsif ( rec.TYPE_LIMIT = ExpoLimit_SudebenPrc ) then
        cSymbol  := substr( cSymbol, 1, 8 ) || 'P' || substr( cSymbol, 10 );
      elsif ( rec.TYPE_LIMIT = ExpoLimit_ContrFinCover ) then
        cSymbol  := substr( cSymbol, 1, 9 ) || 'G' || substr( cSymbol, 11 );
      elsif ( rec.TYPE_LIMIT = ExpoLimit_CardMPV ) then
        cSymbol  := substr( cSymbol, 1, 10 ) || 'M' || substr( cSymbol, 12 );
      else
        cSymbol  := substr( cSymbol, 1, 3 ) || 'S' || substr( cSymbol, 5 );
      end if;
    end loop;

    return cSymbol;
  end Check4Limits;

  --------------------------------------------------------------------------------
  function IsStornoBeforeDate(
    nIdMove  in integer,
    dToDate  in date
  )
    return boolean is
    nDummy  integer;
  begin
    select count( 1 )
      into nDummy
      from EXPO_STRNMOVES a,
           EXPO_MOVES b
     where a.ID_MOVE_OLD = nIdMove and
           a.ID_MOVE_NEW = b.ID_MOVE and
           b.VALIOR <= dToDate;

    return nvl( nDummy, 0 ) = 0;
  end IsStornoBeforeDate;

  --------------------------------------------------------------------------------
  function IsStorno( nIdMove in integer )
    return boolean is
    nId   integer;
    bRet  boolean := false;

    cursor Storno( nMove in integer ) is
      select ID_MOVE_NEW as ID_MOVE
        from EXPO_STRNMOVES
       where ID_MOVE_NEW = nMove
      union all
      select ID_MOVE_OLD as ID_MOVE
        from EXPO_STRNMOVES
       where ID_MOVE_OLD = nMove;

  begin
    open Storno( nIdMove );

    fetch Storno
      into nId;

    bRet  := Storno%found;

    close Storno;

    return bRet;
  end IsStorno;

  --------------------------------------------------------------------------------
  function GetExpoBankCode( nIdExpo in integer )
    return varchar2 is
    BankCode  Schema_RA.CONFIG.FLDBANKCODE%type;
  begin
    select b.FLDBANKCODE
      into BankCode
      from Schema_GPSys.EXPOSITION a,
           Schema_RA.CONFIG b
     where a.ID_EXPO = nIdExpo and
           a.UNIQCODE = b.FLDUNIQCODE;

    return BankCode;
  exception
    when no_data_found then
      return null;
  end GetExpoBankCode;

  --------------------------------------------------------------------------------
  function GetExpoBAE6( nIdExpo in integer )
    return varchar2 is
    sBAE6  Schema_RA.CONFIG.FLDBAE6%type;
  begin
    select b.FLDBAE6
      into sBAE6
      from Schema_GPSys.EXPOSITION a,
           Schema_RA.CONFIG b
     where a.ID_EXPO = nIdExpo and
           a.UNIQCODE = b.FLDUNIQCODE;

    return sBAE6;
  exception
    when no_data_found then
      return null;
  end GetExpoBAE6;

  --------------------------------------------------------------------------------
  function DocDate2IDMove(
    nUniqCode  in integer,
    dSchDate   in date,
    nSchDoc    in integer
  )
    return integer is
    nIDMove  integer;

    cursor iqQ(
      nUCode  in integer,
      dSDate  in date,
      nSDoc   in integer
    ) is
      select ID_MOVE
        from EXPO_MOVES
       where UNIQCODE = nUCode and
             SCH_DATE = dSDate and
             SCH_DOC = nSDoc;

  begin
    open iqQ( nUniqCode, dSchDate, nSchDoc );

    fetch iqQ
      into nIDMove;

    close iqQ;

    return nIDMove;
  end DocDate2IDMove;

  --------------------------------------------------------------------------------
  function IDMove2UniqCode( nIDMove in integer )
    return integer is
    nUniqCode  integer;

    cursor iqQ( nMove in integer ) is
      select UNIQCODE
        from EXPO_MOVES
       where ID_MOVE = nMove;

  begin
    open iqQ( nIDMove );

    fetch iqQ
      into nUniqCode;

    close iqQ;

    return nUniqCode;
  end IDMove2UniqCode;

  --------------------------------------------------------------------------------
  function IDMove2DocDate(
    nIDMove    in     integer,
    nUniqCode     out integer,
    dDocDate      out date,
    nDocNo        out integer
  )
    return boolean is
    bRet  boolean;

    cursor iqQ( nMove in integer ) is
      select UNIQCODE,
             SCH_DATE,
             SCH_DOC
        from EXPO_MOVES
       where ID_MOVE = nMove;

  begin
    open iqQ( nIDMove );

    fetch iqQ
      into nUniqCode, dDocDate, nDocNo;

    bRet  := iqQ%found;

    close iqQ;

    return bRet;
  end IDMove2DocDate;

  --------------------------------------------------------------------------------
  function GetExpo4Lihvi( nIDExpo in integer )
    return integer is
    nIDLihvi  integer := 0;

    cursor iqQ( nExpo in integer ) is
      select INT_EXPO
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union all
      select INT_EXPO
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo;

  begin
    open iqQ( nIDExpo );

    fetch iqQ
      into nIDLihvi;

    close iqQ;

    if ( nvl( nIDLihvi, 0 ) = 0 or
        Schema_GPSys.HeadExpo.IsItCurrentChildSave( nIDLihvi ) or
        Schema_GPSys.HeadExpo.IsItSavingExpo( nIDLihvi ) ) then
      nIDLihvi  := nIDExpo;
    end if;

    return nvl( nIDLihvi, nIDExpo );
  end GetExpo4Lihvi;

  --------------------------------------------------------------------------------
  function GetExpoLihDate(
    nIDExpo     in integer,
    bStartDate  in boolean default false
  )
    return date is
    dDate  date;

    cursor iqQL( nExpo in integer ) is
      select LIHDATE
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union all
      select LIHDATE
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo;

    cursor iqQS( nExpo in integer ) is
      select START_DATE
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union all
      select START_DATE
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo;

  begin
    if ( bStartDate ) then
      open iqQS( nIDExpo );

      fetch iqQS
        into dDate;

      close iqQS;
    else
      open iqQL( nIDExpo );

      fetch iqQL
        into dDate;

      close iqQL;
    end if;

    return dDate;
  end GetExpoLihDate;

  --------------------------------------------------------------------------------
  procedure GetLihDates(
    nIDExpo   in     integer,
    dForDate  in     date,
    dBegDate     out date,
    dEndDate     out date
  ) is
  begin
    select nvl( max( LIHDATE ), dForDate )
      into dEndDate
      from (select LIHDATE
              from CURRENT_EXPO
             where ID_EXPO = nIDExpo and
                   LIHDATE <= dForDate
            union all
            select max( a.LIHDATE ) as LIHDATE
              from EXPO_STRNMOVES c,
                   EXPO_STRNMOVES b,
                   CURRENT_EXPO_A a
             where a.ID_EXPO = nIDExpo and
                   a.LIHDATE <= dForDate and
                   a.ID_MOVE = b.ID_MOVE_NEW(+) and
                   b.ID_MOVE_NEW is null and
                   a.ID_MOVE = c.ID_MOVE_OLD(+) and
                   c.ID_MOVE_OLD is null
            union all
            select LIHDATE
              from DEPOSIT_EXPO
             where ID_EXPO = nIDExpo and
                   LIHDATE <= dForDate
            union all
            select max( a.LIHDATE ) as LIHDATE
              from EXPO_STRNMOVES c,
                   EXPO_STRNMOVES b,
                   DEPOSIT_EXPO_A a
             where a.ID_EXPO = nIDExpo and
                   a.LIHDATE <= dForDate and
                   a.ID_MOVE = b.ID_MOVE_NEW(+) and
                   b.ID_MOVE_NEW is null and
                   a.ID_MOVE = c.ID_MOVE_OLD(+) and
                   c.ID_MOVE_OLD is null);

    select nvl( max( LIHDATE ), dEndDate )
      into dBegDate
      from (select max( a.LIHDATE ) as LIHDATE
              from EXPO_STRNMOVES c,
                   EXPO_STRNMOVES b,
                   CURRENT_EXPO_A a
             where a.ID_EXPO = nIDExpo and
                   a.LIHDATE < dEndDate and
                   a.ID_MOVE = b.ID_MOVE_NEW(+) and
                   b.ID_MOVE_NEW is null and
                   a.ID_MOVE = c.ID_MOVE_OLD(+) and
                   c.ID_MOVE_OLD is null
            union all
            select max( a.LIHDATE ) as LIHDATE
              from EXPO_STRNMOVES c,
                   EXPO_STRNMOVES b,
                   DEPOSIT_EXPO_A a
             where a.ID_EXPO = nIDExpo and
                   a.LIHDATE < dEndDate and
                   a.ID_MOVE = b.ID_MOVE_NEW(+) and
                   b.ID_MOVE_NEW is null and
                   a.ID_MOVE = c.ID_MOVE_OLD(+) and
                   c.ID_MOVE_OLD is null);
  end GetLihDates;

  --------------------------------------------------------------------------------
  function NewDepozitOpen(
    nIdExpoOld  in     integer,
    sNewVal     in     varchar2,
    nIdExpoNew     out integer,
    nInQueue    in     pls_integer default Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work
  )
    return boolean is
    rNewOpenData  Schema_GPSys.Cmd_HeadExpo.recExpoOpenData;
    tIntList      Schema_GPSys.tblExpoIntRate;
    rGroupObj     OBJ_GROUP_REL%rowtype;
    sCodVal       varchar2( 3 );
    bRet          boolean := true;
    aParams       Schema_RA.GPC_RA.tblErrParams;
  begin
    begin
      select a.UNIQCODE,
             a.ID_CUST,
             a.TYPE_EXPO,
             a.OPEN_DATE,
             a.LIHDATE,
             a.SROK,
             a.VID_SROK,
             a.CODVAL,
             a.EXPO_MODE,
             trim( trim( b.FIRSTNAME ) || ' ' || trim( b.MIDLENAME ) || ' ' || trim( b.LASTNAME ) ),
             b.CLITYPE,
             b.FTYPE
        into rNewOpenData.UniqCode,
             rNewOpenData.IDCust,
             rNewOpenData.TypeExpo,
             rNewOpenData.OpenDate,
             rNewOpenData.LihDate,
             rNewOpenData.Srok,
             rNewOpenData.VidSrok,
             sCodVal,
             rNewOpenData.ExpoMode,
             rNewOpenData.ExpoName,
             rNewOpenData.CliType,
             rNewOpenData.FType
        from DEPOSIT_EXPO a,
             Schema_Cust.CUSTOMS b
       where a.ID_EXPO = nIdExpoOld and
             a.ID_CUST = b.id;
    exception
      when others then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_EXPO_OLD';
        aParams( 1 ).ML_VALUE  := to_char( nIdExpoOld );
        Schema_RA.GPC_RA.RespSetErrorText( 'Не съществува депозит с номер $ID_EXPO_OLD$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
        bRet                   := false;
    end;

    if ( bRet ) then
      if ( Otherexpo.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHameleon, rNewOpenData.TypeExpo ) or
          Otherexpo.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHamelPref, rNewOpenData.TypeExpo ) or
          Otherexpo.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHamelTriple, rNewOpenData.TypeExpo ) ) then
        rNewOpenData.CodVal  := sNewVal;
        bRet                 := Schema_GPSys.Cmd_HeadExpo.FillInterestList( rNewOpenData.TypeExpo,
                                                                            rNewOpenData.CodVal,
                                                                            rNewOpenData.CliType,
                                                                            rNewOpenData.FType,
                                                                            rNewOpenData.OpenDate,
                                                                            rNewOpenData.VidSrok,
                                                                            rNewOpenData.Srok,
                                                                            rNewOpenData.IDExpo,
                                                                            tIntList,
                                                                            rNewOpenData
                                                                           ) and
                                Schema_GPSys.Cmd_HeadExpo.OpenNewExpo( rNewOpenData, tIntList, nInQueue );

        if ( bRet ) then
          nIdExpoNew           := rNewOpenData.IDExpo;
          rGroupObj.ID_CUST    := rNewOpenData.IDCust;
          rGroupObj.UNIQCODE   := rNewOpenData.UniqCode;
          rGroupObj.ID_OBJ1    := nIdExpoOld;
          rGroupObj.TYPE_OBJ1  := Schema_GPSys.HeadExpo.ExpoGrpDeposit;
          rGroupObj.ID_OBJ2    := nIdExpoNew;
          rGroupObj.TYPE_OBJ2  := Schema_GPSys.HeadExpo.ExpoGrpDeposit;
          bRet                 := SaveGroupObjRel( rGroupObj );
        end if;
      else
        Schema_RA.GPC_RA.RespSetErrorText( 'Депозита трябва да е от тип Хамелеон', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
        bRet  := false;
      end if;
    end if;

    return bRet;
  end NewDepozitOpen;

  --------------------------------------------------------------------------------
  function GetExpoBKAcc(
    nIDExpo  in integer,
    nDocNum  in integer default null,
    bWork    in boolean default true
  )
    return varchar2 is
    nTemp   integer;
    sBKAcc  varchar2( 100 );
    sSynt   varchar2( 100 );

    cursor iqQ( nExpo in integer ) is
      select DOC_NUM
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union all
      select DOC_NUM
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo
      union all
      select DOC_NUM
        from OTHER_EXPO
       where ID_EXPO = nExpo;

  begin
    if ( bWork ) then
      if ( bHaveFS_BK is null ) then
        bHaveFS_BK  := Schema_GPSys.HeadExpo.INI_EXPO2FS_BK;
        nModeAcc    := Schema_GPSys.OraGPSys.My_to_number( Schema_GPSys.OraGPSys.GetIniValue( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'MODE_ACCOUNT', '0' ) );
      end if;

      if ( bHaveFS_BK ) then
        if ( nvl( nDocNum, 0 ) > 0 ) then
          nTemp  := nDocNum;
        else
          open iqQ( nIDExpo );

          fetch iqQ
            into nTemp;

          close iqQ;
        end if;

        execute immediate
          'select b.ACCOUNT from Schema_FS.FS_OPENDOCMAP a, Schema_BK.BK_RECAP b ' ||
          'where a.MAP_DOC_ID = :1     and ' ||
          'b.FS_COUNT_ID = a.COUNT_ID  and ' ||
          'b.FS_ITEM_ID = a.FS_ITEM_ID and rownum < 2'
          into sBKAcc
          using nTemp;
      elsif ( nModeAcc = 0 ) then
        select SCHACCOUNT
          into sBKAcc
          from Schema_GPSys.EXPOSITION
         where ID_EXPO = nIDExpo;
      elsif ( nModeAcc in (1, 2) ) then
        select EXPO_CODE,
               AN_FEAT
          into sSynt,
               sBKAcc
          from Schema_GPSys.EXPOSITION
         where ID_EXPO = nIDExpo;

        sSynt  := Schema_GPSys.OraGPSys.GetSynt( sSynt );

        if ( sBKAcc is null ) then
          sBKAcc  := sSynt;
        else
          sBKAcc  := sSynt || ',' || sBKAcc;
        end if;

        if ( nModeAcc = 1 ) then
          sBKAcc  := replace( sBKAcc, ',', '' );
        end if;
      end if;
    end if;

    return sBKAcc;
  exception
    when others then
      return null;
  end GetExpoBKAcc;

  --------------------------------------------------------------------------------
  procedure SetMaxTriggNumber(
    Object_Name  in varchar2,
    nCounter     in integer,
    nCounterAdd  in integer default null
  ) is
  begin
    update TRIGG_NUMBERS
       set NUM      = nvl( nCounter, NUM ),
           NUM_ADD  = nvl( nCounterAdd, NUM_ADD )
     where OBJ_NAME = Object_Name;

    if ( sql%rowcount = 0 ) then
      insert into TRIGG_NUMBERS(
                    OBJ_NAME,
                    NUM,
                    NUM_ADD
                  )
           values ( Object_Name,
                    nvl( nCounter, 0 ),
                    nvl( nCounterAdd, 0 )
                   );
    end if;
  end SetMaxTriggNumber;

  --------------------------------------------------------------------------------
  function CalcEAllAverageSaldoAndOb(
    nIDExpo     in     integer,
    dBegDate    in     date,
    dEndDate    in     date,
    bValior     in     boolean,
    nSysSaldo      out number,
    cSynt       in     varchar2 default null,
    nOborDt        out number,
    nOborKt        out number,
    nSysOborDt     out number,
    nSysOborKt     out number,
    nMaxDays       out integer,
    bSkipOper   in     boolean default false
  )
    return number is
    nOrgSaldo    number := 0;
    nSaldoDt     number;
    nSaldoKt     number;
    nCurrPeriod  integer := 0;
    ii           pls_integer := 0;
    nOper        pls_integer := 0;
    dNextDate    date;

    type rSaldoDate is record(
      dWrkDate   date,
      nOrgSaldo  number,
      nSysSaldo  number
    );

    type taSaldoDate is table of rSaldoDate
      index by binary_integer;

    aSaldoDate   taSaldoDate;

    cursor qAverageV(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date,
      nqOper     in integer
    ) is
        select sum( ORG_OBOR_DT ) as ORG_OBOR_DT,
               sum( ORG_OBOR_KT ) as ORG_OBOR_KT,
               sum( SYS_OBOR_DT ) as SYS_OBOR_DT,
               sum( SYS_OBOR_KT ) as SYS_OBOR_KT,
               VALIOR
          from ((  select sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_OBOR_DT,
                          sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_OBOR_KT,
                          sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_OBOR_DT,
                          sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_OBOR_KT,
                          VALIOR
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          VALIOR >= dqBegDate and
                          ( nqOper = 0 or
                           OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
                 group by VALIOR )
                union all
                ( select 0 as ORG_OBOR_DT,
                         0 as ORG_OBOR_KT,
                         0 as SYS_OBOR_DT,
                         0 as SYS_OBOR_KT,
                         dqBegDate as VALIOR
                    from dual )
                union all
                ( select 0 as ORG_OBOR_DT,
                         0 as ORG_OBOR_KT,
                         0 as SYS_OBOR_DT,
                         0 as SYS_OBOR_KT,
                         dqEndDate as VALIOR
                    from dual ))
      group by VALIOR
      order by VALIOR desc;

    cursor qAverageD(
      nqIdExpo   in integer,
      dqBegDate  in date,
      dqEndDate  in date,
      nqOper     in integer
    ) is
        select sum( ORG_OBOR_DT ) as ORG_OBOR_DT,
               sum( ORG_OBOR_KT ) as ORG_OBOR_KT,
               sum( SYS_OBOR_DT ) as SYS_OBOR_DT,
               sum( SYS_OBOR_KT ) as SYS_OBOR_KT,
               SCH_DATE
          from ((  select sum( decode( DT_KT, 'D', AMOUNT, 0 ) ) as ORG_OBOR_DT,
                          sum( decode( DT_KT, 'K', AMOUNT, 0 ) ) as ORG_OBOR_KT,
                          sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as SYS_OBOR_DT,
                          sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as SYS_OBOR_KT,
                          SCH_DATE
                     from EXPO_MOVES
                    where ID_EXPO = nqIdExpo and
                          SCH_DATE >= dqBegDate and
                          ( nqOper = 0 or
                           OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
                 group by SCH_DATE )
                union all
                ( select 0 as ORG_OBOR_DT,
                         0 as ORG_OBOR_KT,
                         0 as SYS_OBOR_DT,
                         0 as SYS_OBOR_KT,
                         dqBegDate as SCH_DATE
                    from dual )
                union all
                ( select 0 as ORG_OBOR_DT,
                         0 as ORG_OBOR_KT,
                         0 as SYS_OBOR_DT,
                         0 as SYS_OBOR_KT,
                         dqEndDate as SCH_DATE
                    from dual ))
      group by SCH_DATE
      order by SCH_DATE desc;

  begin
    nOborDt     := 0;
    nOborKt     := 0;
    nSysOborDt  := 0;
    nSysOborKt  := 0;
    nSysSaldo   := 0;

    if ( bSkipOper ) then
      nOper  := 1;
    end if;

    if ( dBegDate <= dEndDate and
        GetEAllHotSaldo( nIDExpo, nOrgSaldo, nSysSaldo ) ) then
      if ( bValior ) then
        for Rec in qAverageV( nIdExpo, dBegDate, dEndDate, nOper ) loop
          if ( Rec.VALIOR <= dEndDate ) then
            ii                          := ii + 1;
            aSaldoDate( ii ).dWrkDate   := Rec.VALIOR;
            nOborKt                     := nOborKt + Rec.ORG_OBOR_KT;
            nOborDt                     := nOborDt + Rec.ORG_OBOR_DT;
            nSysOborKt                  := nSysOborKt + Rec.Sys_OBOR_KT;
            nSysOborDt                  := nSysOborDt + Rec.Sys_OBOR_DT;
            aSaldoDate( ii ).nOrgSaldo  := nOrgSaldo;
            aSaldoDate( ii ).nSysSaldo  := nSysSaldo;
          end if;

          nOrgSaldo  := nOrgSaldo + ( Rec.ORG_OBOR_DT - Rec.ORG_OBOR_KT );
          nSysSaldo  := nSysSaldo + ( Rec.Sys_OBOR_DT - Rec.Sys_OBOR_KT );
        end loop;
      else
        for Rec in qAverageD( nIdExpo, dBegDate, dEndDate, nOper ) loop
          if ( Rec.SCH_DATE <= dEndDate ) then
            ii                          := ii + 1;
            aSaldoDate( ii ).dWrkDate   := Rec.SCH_DATE;
            aSaldoDate( ii ).nOrgSaldo  := nOrgSaldo;
            aSaldoDate( ii ).nSysSaldo  := nSysSaldo;
            nOborKt                     := nOborKt + Rec.ORG_OBOR_KT;
            nOborDt                     := nOborDt + Rec.ORG_OBOR_DT;
            nSysOborKt                  := nSysOborKt + Rec.Sys_OBOR_KT;
            nSysOborDt                  := nSysOborDt + Rec.Sys_OBOR_DT;
          end if;

          nOrgSaldo  := nOrgSaldo + ( Rec.ORG_OBOR_DT - Rec.ORG_OBOR_KT );
          nSysSaldo  := nSysSaldo + ( Rec.Sys_OBOR_DT - Rec.Sys_OBOR_KT );
        end loop;
      end if;

      nOrgSaldo  := 0;
      nSysSaldo  := 0;
      nMaxDays   := 0;

      for jj in reverse aSaldoDate.first .. aSaldoDate.last loop
        if ( cSynt is not null and
            aSaldoDate( jj ).nSysSaldo != 0 ) then
          dNextDate  := aSaldoDate( jj ).dWrkDate;

          if ( aSaldoDate( jj ).nSysSaldo < 0 ) then
            nSaldoDt  := -aSaldoDate( jj ).nSysSaldo;
            nSaldoKt  := 0;
          else
            nSaldoKt  := aSaldoDate( jj ).nSysSaldo;
            nSaldoDt  := 0;
          end if;

          while ( ( dNextDate = dEndDate and
                   jj = 1 ) or
                 ( jj > 1 and
                  dNextDate < aSaldoDate( jj - 1 ).dWrkDate ) ) loop
            update AVRSALDODATE
               set SALDODT  = SALDODT + nSaldoDt,
                   SALDOKT  = SALDOKT + nSaldoKt
             where EXPO_CODE = cSynt and
                   DDATE = dNextDate;

            if ( sql%rowcount = 0 ) then
              insert into AVRSALDODATE(
                            EXPO_CODE,
                            DDATE,
                            SALDODT,
                            SALDOKT
                          )
                   values ( cSynt,
                            dNextDate,
                            nSaldoDt,
                            nSaldoKt
                           );
            end if;

            dNextDate  := dNextDate + 1;
          end loop;
        end if;

        if ( aSaldoDate( jj ).dWrkDate = dEndDate ) then
          nOrgSaldo  := nOrgSaldo + aSaldoDate( jj ).nOrgSaldo;
          nSysSaldo  := nSysSaldo + aSaldoDate( jj ).nSysSaldo;
          exit;
        else
          nOrgSaldo  := nOrgSaldo + ( aSaldoDate( jj ).nOrgSaldo * ( aSaldoDate( jj - 1 ).dWrkDate - aSaldoDate( jj ).dWrkDate ) );
          nSysSaldo  := nSysSaldo + ( aSaldoDate( jj ).nSysSaldo * ( aSaldoDate( jj - 1 ).dWrkDate - aSaldoDate( jj ).dWrkDate ) );
        end if;

        if ( aSaldoDate( jj ).nOrgSaldo = 0 ) then
          if ( nMaxDays < nCurrPeriod ) then
            nMaxDays     := nCurrPeriod;
            nCurrPeriod  := 0;
          end if;
        elsif ( aSaldoDate( jj - 1 ).nOrgSaldo != 0 ) then
          nCurrPeriod  := nCurrPeriod + ( aSaldoDate( jj - 1 ).dWrkDate - aSaldoDate( jj ).dWrkDate );
        end if;
      end loop;

      nOrgSaldo  := nOrgSaldo / ( dEndDate - dBegDate + 1 );
      nSysSaldo  := nSysSaldo / ( dEndDate - dBegDate + 1 );
    end if;

    return nOrgSaldo;
  end CalcEAllAverageSaldoAndOb;

  --------------------------------------------------------------------------------
  procedure BKAccToExpos(
    sBKAcc  in            varchar2,
    aExpos  in out nocopy Schema_GPSys.OraGPSys.aNumbers
  ) is
    aExpoNums  Schema_GPSys.NumbersCollectionType;
  begin
    if ( sBKAcc is not null ) then
      if ( bHaveFS_BK is null ) then
        bHaveFS_BK  := Schema_GPSys.HeadExpo.INI_EXPO2FS_BK;
      end if;

      if ( bHaveFS_BK ) then
        execute immediate
          'select nvl(c.ID_EXPO,nvl(d.ID_EXPO,e.ID_EXPO)) as ID_EXPO' ||
          'from Schema_FS.FS_OPENDOCMAP a,' ||
          'Schema_BK.BK_RECAP b,' ||
          'CURRENT_EXPO c,' ||
          'DEPOSIT_EXPO d,' ||
          'OTHER_EXPO e' ||
          'where b.account = sBKAcc and' ||
          'b.FS_COUNT_ID = a.COUNT_ID and' ||
          'b.FS_ITEM_ID = a.FS_ITEM_ID and' ||
          'a.MAP_DOC_ID = c.DOC_NUM(+) and' ||
          'a.MAP_DOC_ID = d.DOC_NUM(+)and' ||
          'a.MAP_DOC_ID = e.DOC_NUM(+)'
          bulk collect into aExpoNums
          using sBKAcc;

        if ( aExpoNums.count > 0 ) then
          for ii in aExpoNums.first .. aExpoNums.last loop
            Schema_GPSys.OraGPSys.Add2UniqArr( aExpos, aExpoNums( ii ) );
          end loop;
        end if;
      end if;
    end if;
  exception
    when others then
      null;
  end BKAccToExpos;

  --------------------------------------------------------------------------------
  function IDMove2OrdText(
    nIDMove  in integer,
    bOrd     in boolean default true
  )
    return varchar2 is
    sText  EXPO_MOVE_TEXT.ORD_TEXT%type;
  begin
    if ( bOrd ) then
      select ORD_TEXT
        into sText
        from EXPO_MOVE_TEXT
       where ID_MOVE = nIDMove;
    else
      select SYS_TEXT
        into sText
        from EXPO_MOVE_TEXT
       where ID_MOVE = nIDMove;
    end if;

    return sText;
  exception
    when no_data_found then
      return null;
  end IDMove2OrdText;

  --------------------------------------------------------------------------------
  function GetExpo4Taxes( nIDExpo in integer )
    return integer is
    nIDTaxes  integer := 0;

    cursor iqQ( nExpo in integer ) is
      select EXPO_TAX
        from CURRENT_EXPO
       where ID_EXPO = nExpo
      union
      select EXPO_TAX
        from DEPOSIT_EXPO
       where ID_EXPO = nExpo;

  begin
    if ( Schema_GPSys.HeadExpo.IsItUnionbankWise( nIDExpo ) ) then
      nIDTaxes  := nIDExpo;
    else
      open iqQ( nIDExpo );

      fetch iqQ
        into nIDTaxes;

      close iqQ;

      if ( nvl( nIDTaxes, 0 ) = 0 or
          Schema_GPSys.HeadExpo.IsItCurrentChildSave( nIDTaxes ) or
          Schema_GPSys.HeadExpo.IsItSavingExpo( nIDTaxes ) ) then
        nIDTaxes  := nIDExpo;
      end if;
    end if;

    return nIDTaxes;
  end GetExpo4Taxes;

  --------------------------------------------------------------------------------
  function GetSkipedLimits(
    nIDExpo   in integer,
    sValExpo  in varchar2
  )
    return number is
    nLimit     number := 0;
    nTypeExpo  integer;
    sCodVal    varchar2( 3 );
    dSchDate   date := Schema_RA.GPC_Tools.GetSchDate( null );

    cursor iqq(
      qnIDExpo   in integer,
      qsCodVal   in varchar2,
      qdSchDate  in date
    ) is
        select nvl( sum( SUMLIMIT ), 0 ) as AMOUNT,
               CODVAL,
               TYPE_LIMIT
          from EXPO_LIMITS
         where ID_EXPO = qnIDExpo and
               FULL_LIMIT = 'F' and
               qdSchDate between nvl( BEG_DATE, qdSchDate ) and nvl( END_DATE, qdSchDate ) and
               STATUS = ZaporStat_Active and
               TYPE_LIMIT != ExpoLimit_CardAuth
      group by CODVAL,
               TYPE_LIMIT;

  begin
    sCodVal    := nvl( sValExpo, Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpo ) );
    nTypeExpo  := Schema_GPSys.HeadExpo.IDExpo2TypeExpo( nIDExpo );

    for rec in iqq( nIDExpo, sCodVal, dSchDate ) loop
      if ( SkipTheLimit( rec.TYPE_LIMIT, nTypeExpo ) ) then
        if ( rec.CODVAL = sCodVal ) then
          nLimit  := nLimit + rec.AMOUNT;
        else
          nLimit  := nLimit + Schema_GPSys.XchgRates.GetExactSum( rec.AMOUNT, null, dSchDate, rec.CODVAL, sCodVal, Schema_GPSys.XchgRates.XchgRateType_Fixing );
        end if;
      end if;
    end loop;

    return nLimit;
  end GetSkipedLimits;

  --------------------------------------------------------------------------------
  function GetExpoBalance(
    nIDExpo     in integer,
    sValExpo    in varchar2,
    sAllLimits  in varchar2 default 'T'
  )
    return number is
    sCodVal     varchar2( 3 );
    dSchDate    date := Schema_RA.GPC_Tools.GetSchDate( null );
    bFullLimit  boolean := false;

    cursor iqq(
      qnIDExpo   in integer,
      qsCodVal   in varchar2,
      qdSchDate  in date
    ) is
        select nvl( sum( SALDO ), 0 ) as SALDO,
               nvl( sum( LIMITS ), 0 ) as LIMITS,
               nvl( sum( ALLOW_OVRDR ), 0 ) as ALLOW_OVRDR,
               nvl( sum( OVRDR ), 0 ) as OVRDR,
               CODVAL,
               FULL_LIMIT
          from (( select nvl( sum( AMN ), 0 ) as SALDO,
                         0 as LIMITS,
                         0 as ALLOW_OVRDR,
                         0 as OVRDR,
                         qsCodVal as CODVAL,
                         'F' as FULL_LIMIT
                    from (select nvl( OBOR_KT - OBOR_DT, 0 ) as AMN
                            from EXPO_STATE
                           where ID_EXPO = qnIDExpo
                          union all
                          select sum( decode( DT_KT, 'D', -AMOUNT, AMOUNT ) ) as AMN
                            from EXPO_MOVES
                           where ID_EXPO = qnIDExpo and
                                 CH_STAMP = 0 and
                                 AMOUNT != 0) )
                union all
                (  select 0 as SALDO,
                          nvl( sum( SUMLIMIT ), 0 ) as LIMITS,
                          0 as ALLOW_OVRDR,
                          0 as OVRDR,
                          CODVAL,
                          FULL_LIMIT
                     from EXPO_LIMITS
                    where ID_EXPO = qnIDExpo and
                          qdSchDate between nvl( BEG_DATE, qdSchDate ) and nvl( END_DATE, qdSchDate ) and
                          STATUS = ZaporStat_Active and
                          TYPE_LIMIT not in (ExpoLimit_CardMPV, ExpoLimit_CardHOLD) and
                          ( sAllLimits = 'T' or
                           TYPE_LIMIT != ExpoLimit_CardAuth )
                 group by CODVAL,
                          FULL_LIMIT )
                union all
                (  select 0 as SALDO,
                          nvl( sum( SUMLIMIT ), 0 ) as LIMITS,
                          0 as ALLOW_OVRDR,
                          0 as OVRDR,
                          CODVAL,
                          'MPV' as FULL_LIMIT
                     from EXPO_LIMITS
                    where ID_EXPO = qnIDExpo and
                          qdSchDate between nvl( BEG_DATE, qdSchDate ) and nvl( END_DATE, qdSchDate ) and
                          STATUS = ZaporStat_Active and
                          TYPE_LIMIT = ExpoLimit_CardMPV
                 group by CODVAL )
                union all
                (  select 0 as SALDO,
                          nvl( sum( SUMLIMIT ), 0 ) as LIMITS,
                          0 as ALLOW_OVRDR,
                          0 as OVRDR,
                          CODVAL,
                          'HOLD' as FULL_LIMIT
                     from EXPO_LIMITS
                    where ID_EXPO = qnIDExpo and
                          qdSchDate between nvl( BEG_DATE, qdSchDate ) and nvl( END_DATE, qdSchDate ) and
                          STATUS = ZaporStat_Active and
                          TYPE_LIMIT = ExpoLimit_CardHOLD
                 group by CODVAL )
                union all
                  select nvl( sum( SALDO ), 0 ) as SALDO,
                         nvl( sum( LIMITS ), 0 ) as LIMITS,
                         nvl( sum( nvl( g.ALLOW_OVRDR, 0 ) ), 0 ) as ALLOW_OVRDR,
                         nvl( sum( greatest( g.ALLOW_OVRDR + g.USED_OVRDR, 0 ) ), 0 ) as OVRDR,
                         g.CODVAL,
                         'F' as FULL_LIMIT
                    from (select /*+ LEADING( a b c d e ) USE_NL( b c d e ) */
                                0 as SALDO,
                                 0 as LIMITS,
                                 nvl( ( select sum( g.AMOUNT - nvl( g.LIH_AMOUNT, 0 ) )
                                          from LOAN_CRED_PLAN g
                                         where g.ID_CRED_ENGAGE = b.ID_CRED_ENGAGE and
                                               g.TYPE_PADEJ = Loans.LoanPadejType_Limit and
                                               g.BEG_DATE = (select max( h.BEG_DATE )
                                                               from LOAN_CRED_PLAN h
                                                              where h.ID_CRED_ENGAGE = b.ID_CRED_ENGAGE and
                                                                    h.TYPE_PADEJ = Loans.LoanPadejType_Limit and
                                                                    h.BEG_DATE <= qdSchDate) ),
                                      b.AMOUNT
                                     )
                                   as ALLOW_OVRDR,
                                 nvl( e.OBOR_KT - e.OBOR_DT, 0 ) +
                                 nvl( ( select sum( decode( f.DT_KT, 'D', -f.AMOUNT, f.AMOUNT ) )
                                          from EXPO_MOVES f
                                         where f.ID_EXPO = e.ID_EXPO and
                                               f.CH_STAMP = 0 and
                                               f.AMOUNT != 0 ),
                                      0
                                     )
                                   as USED_OVRDR,
                                 b.CODVAL
                            from EXPO_STATE e,
                                 LOAN_EXPOSITION d,
                                 Schema_RA.NOM_DATA c,
                                 LOAN_CREDIT b,
                                 LOAN_EXPOSITION a
                           where a.ID_EXPO = qnIDExpo and
                                 a.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                                 a.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_Obsujvashta and
                                 b.ID_CRED_ENGAGE = a.ID_CRED_ENGAGE and
                                 b.STATUS = Loans.LoanStat_Active and
                                 b.LAST_USE_DATE > qdSchDate and
                                 c.NOM_TYPE = Loans.LoanPlan_NomType and
                                 c.NOM_ID = b.PLAN_TYPE and
                                 c.NOM_ADD1 = Loans.LoanPlan_SLimiti and
                                 d.ID_CRED_ENGAGE = b.ID_CRED_ENGAGE and
                                 d.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                                 d.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg and
                                 e.ID_EXPO = d.ID_EXPO
                          $if ( not Schema_GPSys.OraSys.VerBankTokuda and
                               not Schema_GPSys.OraSys.VerBankDBank ) $then
                          union all
                          select nvl( e.OBOR_KT - e.OBOR_DT, 0 ) +
                                 nvl( ( select sum( decode( f.DT_KT, 'D', -f.AMOUNT, f.AMOUNT ) )
                                          from EXPO_MOVES f
                                         where f.ID_EXPO = e.ID_EXPO and
                                               f.CH_STAMP = 0 and
                                               f.AMOUNT != 0 ),
                                      0
                                     )
                                   as SLADO,
                                 0 as LIMITS,
                                 0 as ALLOW_OVRDR,
                                 0 as USED_OVRDR,
                                 b.CODVAL
                            from EXPO_STATE e,
                                 LOAN_EXPOSITION d,
                                 Schema_RA.NOM_DATA c,
                                 LOAN_CREDIT b,
                                 LOAN_EXPOSITION a
                           where a.ID_EXPO = qnIDExpo and
                                 a.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                                 a.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_Obsujvashta and
                                 b.ID_CRED_ENGAGE = a.ID_CRED_ENGAGE and
                                 b.STATUS = Loans.LoanStat_Active and
                                 b.LAST_USE_DATE <= qdSchDate and
                                 c.NOM_TYPE = Loans.LoanPlan_NomType and
                                 c.NOM_ID = b.PLAN_TYPE and
                                 c.NOM_ADD1 = Loans.LoanPlan_SLimiti and
                                 d.ID_CRED_ENGAGE = b.ID_CRED_ENGAGE and
                                 d.EXPO_GROUP = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                                 d.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg and
                                 e.ID_EXPO = d.ID_EXPO  $end
                                                      ) g
                group by g.CODVAL)
      group by CODVAL,
               FULL_LIMIT;

  begin
    rExpoBalance.nBalance     := 0;
    rExpoBalance.nSaldo       := 0;
    rExpoBalance.nLimits      := 0;
    rExpoBalance.nMPVLimit    := 0;
    rExpoBalance.nHOLDLimit   := 0;
    rExpoBalance.nOvrdr       := 0;
    rExpoBalance.nAllowOvrdr  := 0;

    if ( sValExpo is null ) then
      sCodVal  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpo );
    else
      sCodVal  := sValExpo;
    end if;

    for rec in iqq( nIDExpo, sCodVal, dSchDate ) loop
      rExpoBalance.nSaldo  := rExpoBalance.nSaldo + rec.SALDO;

      if ( rec.CODVAL = sCodVal ) then
        rExpoBalance.nOvrdr       := rExpoBalance.nOvrdr + rec.OVRDR;
        rExpoBalance.nAllowOvrdr  := rExpoBalance.nAllowOvrdr + rec.ALLOW_OVRDR;
      else
        rExpoBalance.nOvrdr       := rExpoBalance.nOvrdr + Schema_GPSys.XchgRates.GetExactSum( rec.OVRDR, null, dSchDate, rec.CODVAL, sCodVal, Schema_GPSys.XchgRates.XchgRateType_Fixing );
        rExpoBalance.nAllowOvrdr  := rExpoBalance.nAllowOvrdr + Schema_GPSys.XchgRates.GetExactSum( rec.ALLOW_OVRDR, null, dSchDate, rec.CODVAL, sCodVal, Schema_GPSys.XchgRates.XchgRateType_Fixing );
      end if;

      if ( not bFullLimit ) then
        if ( rec.FULL_LIMIT = 'T' ) then
          bFullLimit  := true;
        elsif ( rec.FULL_LIMIT = 'MPV' ) then
          if ( rec.CODVAL = sCodVal ) then
            rExpoBalance.nMPVLimit  := rExpoBalance.nMPVLimit + rec.LIMITS;
          else
            rExpoBalance.nMPVLimit  := rExpoBalance.nMPVLimit + Schema_GPSys.XchgRates.GetExactSum( rec.LIMITS, null, dSchDate, rec.CODVAL, sCodVal, Schema_GPSys.XchgRates.XchgRateType_Fixing );
          end if;
        elsif ( rec.FULL_LIMIT = 'HOLD' ) then
          if ( rec.CODVAL = sCodVal ) then
            rExpoBalance.nHOLDLimit  := rExpoBalance.nHOLDLimit + rec.LIMITS;
          else
            rExpoBalance.nHOLDLimit  := rExpoBalance.nHOLDLimit + Schema_GPSys.XchgRates.GetExactSum( rec.LIMITS, null, dSchDate, rec.CODVAL, sCodVal, Schema_GPSys.XchgRates.XchgRateType_Fixing );
          end if;
        else
          if ( rec.CODVAL = sCodVal ) then
            rExpoBalance.nLimits  := rExpoBalance.nLimits + rec.LIMITS;
          else
            rExpoBalance.nLimits  := rExpoBalance.nLimits + Schema_GPSys.XchgRates.GetExactSum( rec.LIMITS, null, dSchDate, rec.CODVAL, sCodVal, Schema_GPSys.XchgRates.XchgRateType_Fixing );
          end if;
        end if;
      end if;
    end loop;

    if ( bFullLimit ) then
      rExpoBalance.nBalance  := 0;
      rExpoBalance.nLimits   := Schema_GPSys.OraGPSys.nMaxMoney;
    else
      rExpoBalance.nBalance  := greatest( rExpoBalance.nSaldo - rExpoBalance.nMPVLimit, 0 ) - rExpoBalance.nHOLDLimit - rExpoBalance.nLimits + rExpoBalance.nOvrdr;
    end if;

    return rExpoBalance.nBalance;
  end GetExpoBalance;

  --------------------------------------------------------------------------------
  procedure ExpoAddIntrate_UpdRegister(
    rExpoAddIntrate  in EXPO_ADDINTRATE%rowtype,
    nDocNum          in integer,
    nChStamp         in integer
  ) is
    bDummy  boolean;
  begin
    update EXPO_ADDINTRATE
       set ID_EXPO       = rExpoAddIntrate.ID_EXPO,
           BEGDATE       = rExpoAddIntrate.BEGDATE,
           LIHPROC       = rExpoAddIntrate.LIHPROC,
           LOWPROC       = rExpoAddIntrate.LOWPROC,
           REASON        = rExpoAddIntrate.REASON,
           STATUS        = rExpoAddIntrate.STATUS,
           ENDDATE       = rExpoAddIntrate.ENDDATE,
           TYPE_PRODUCT  = rExpoAddIntrate.TYPE_PRODUCT,
           CH_OPER       = rExpoAddIntrate.CH_OPER,
           DOC_NUM       = nDocNum,
           CH_STAMP      = nChStamp
     where REGID = rExpoAddIntrate.REGID;

    if ( sql%rowcount = 0 ) then
      insert into EXPO_ADDINTRATE(
                    REGID,
                    ID_EXPO,
                    BEGDATE,
                    ENDDATE,
                    LIHPROC,
                    LOWPROC,
                    REASON,
                    STATUS,
                    TYPE_PRODUCT,
                    CH_OPER,
                    DOC_NUM,
                    CH_STAMP
                  )
           values ( rExpoAddIntrate.REGID,
                    rExpoAddIntrate.ID_EXPO,
                    rExpoAddIntrate.BEGDATE,
                    rExpoAddIntrate.ENDDATE,
                    rExpoAddIntrate.LIHPROC,
                    rExpoAddIntrate.LOWPROC,
                    rExpoAddIntrate.REASON,
                    rExpoAddIntrate.STATUS,
                    rExpoAddIntrate.TYPE_PRODUCT,
                    rExpoAddIntrate.CH_OPER,
                    nDocNum,
                    nChStamp
                   );
    end if;

    if ( nvl( nDocNum, 0 ) != 0 ) then
      bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoAddIntrate, rExpoAddIntrate.REGID );
    end if;
  end ExpoAddIntrate_UpdRegister;

  --------------------------------------------------------------------------------
  function GetMaxExpoNumber( Object_Name in varchar2 )
    return integer is
    ii  integer;
  begin
    begin
      select NUM
        into ii
        from EXPO_NUMBERS
       where OBJ_NAME = Object_Name;
    exception
      when others then
        ii  := 0;
    end;

    return ii;
  end GetMaxExpoNumber;

  --------------------------------------------------------------------------------
  procedure XX00 is
    sError       varchar2( 256 );
    IDMove       integer;
    oOpers       Schema_GPSys.TblSchOper;
    aClosedExpo  Schema_GPSys.OraGPSys.aNumbers;
    bRet         boolean;
  begin
    oOpers                      := Schema_GPSys.TblSchOper( );
    oOpers.extend;
    oOpers( oOpers.count )      := Schema_GPSys.TSchOper( null,
                                                          3,
                                                          Schema_GPSys.OraGPSys.SYS_CURR,
                                                          200,
                                                          200,
                                                          Schema_GPSys.OraGPSys.SYS_CURR,
                                                          1,
                                                          to_date( '01.10.2002', 'dd.mm.yyyy' ),
                                                          200,
                                                          null,
                                                          null,
                                                          null
                                                         );
    oOpers.extend;
    oOpers( oOpers.count )      := Schema_GPSys.TSchOper( null,
                                                          3,
                                                          Schema_GPSys.OraGPSys.SYS_CURR,
                                                          100,
                                                          100,
                                                          Schema_GPSys.OraGPSys.SYS_CURR,
                                                          4,
                                                          to_date( '01.01.2003', 'dd.mm.yyyy' ),
                                                          100,
                                                          null,
                                                          null,
                                                          null
                                                         );
    bRet                        := ChkExpoOpers( sError, IDMove, 100, 0, oOpers, to_date( '01.01.2003', 'dd.mm.yyyy' ), null, aClosedExpo );

    if ( bRet ) then
      dbms_output.PUT_LINE( 'true' );
    else
      dbms_output.PUT_LINE( 'false' );
    end if;

    dbms_output.PUT_LINE( sError );
  end XX00;

  --------------------------------------------------------------------------------
  procedure SaldoPeriodTmpSave(
    nIDExpo  in integer,
    dDATE    in date,
    nSlado   in number,
    nOborKt  in number,
    nOborDt  in number
  ) is
  begin
    insert into TMP_SYSSALDOPERIOD(
                  ENDDATE,
                  ID_EXPO,
                  SALDO,
                  OB_DT,
                  OB_KT
                )
         values ( dDATE,
                  nIDExpo,
                  nSlado,
                  nOborDt,
                  nOborKt
                 );
  end SaldoPeriodTmpSave;

  --------------------------------------------------------------------------------
  procedure ExpoSysSaldoPeriods(
    nIDExpo      in     integer,
    bValior      in     boolean,
    nOborDt      in out number,
    nOborKt      in out number,
    aRangeDates  in     Schema_GPSys.Tbl1Date,
    bSkipOper    in     boolean default false
  ) is
    nTempDt  number;
    nTempKt  number;
    bDummy   boolean := false;
    dFrDate  date;
    dToDate  date;
    nPeriod  integer;

    cursor SaldoValior(
      nExpo   in integer,
      dFDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', SYS_AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', SYS_AMOUNT, 0 ) as AMOUNTKT,
             VALIOR as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             VALIOR >= dFDate and
             AMOUNT != 0 and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dDate as DDATE
        from table( cast( aRangeDates as Schema_GPSys.Tbl1Date ) )
      order by 3 desc;

    cursor SaldoDate(
      nExpo   in integer,
      dFDate  in date,
      nOpr    in pls_integer
    ) is
      select decode( DT_KT, 'D', SYS_AMOUNT, 0 ) as AMOUNTDT,
             decode( DT_KT, 'K', SYS_AMOUNT, 0 ) as AMOUNTKT,
             SCH_DATE as DDATE
        from EXPO_MOVES
       where ID_EXPO = nExpo and
             SCH_DATE >= dFDate and
             AMOUNT != 0 and
             ( nOpr = 0 or
              OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot )
      union all
      select 0 as AMOUNTDT,
             0 as AMOUNTKT,
             dDate as DDATE
        from table( cast( aRangeDates as Schema_GPSys.Tbl1Date ) )
      order by 3 desc;

    nOper    pls_integer := 0;
  begin
    if ( aRangeDates is not null and
        aRangeDates.count >= 2 ) then
      dFrDate  := aRangeDates( aRangeDates.first ).dDate;
      dToDate  := aRangeDates( aRangeDates.last ).dDate;

      if ( bSkipOper ) then
        nOper  := 1;
      end if;

      nOborDt  := 0;
      nOborKt  := 0;

      begin
        select sum( ObDT ),
               sum( ObKT )
          into nOborDt,
               nOborKt
          from (select nvl( SYS_OBOR_DT, 0 ) as ObDT,
                       nvl( SYS_OBOR_KT, 0 ) as ObKT
                  from EXPO_STATE
                 where ID_EXPO = nIDExpo
                union all
                select sum( decode( DT_KT, 'D', SYS_AMOUNT, 0 ) ) as ObDT,
                       sum( decode( DT_KT, 'K', SYS_AMOUNT, 0 ) ) as ObKT
                  from EXPO_MOVES
                 where ID_EXPO = nIDExpo and
                       CH_STAMP = 0 and
                       AMOUNT != 0 and
                       ( nOper = 0 or
                        OPER_TYPE != Schema_Expo.Cmd_Expo.Sch_ClearOborot ));

        nOborDt  := nvl( nOborDt, 0 );
        nOborKt  := nvl( nOborKt, 0 );

        if ( bValior ) then
          for rec in SaldoValior( nIDExpo, dFrDate, nOper ) loop
            if ( not bDummy and
                rec.DDATE = dToDate ) then
              nTempDt  := nOborDt;
              nTempKt  := nOborKt;
              bDummy   := true;
            end if;

            nPeriod  := 0;

            begin
              select 1
                into nPeriod
                from dual
               where exists
                       (select dDate
                          from table( cast( aRangeDates as Schema_GPSys.Tbl1Date ) )
                         where dDate = rec.DDATE and
                               dDate < dToDate);

              nOborDt  := nvl( nTempDt, 0 ) - nOborDt;
              nOborKt  := nvl( nTempKt, 0 ) - nOborKt;
              SaldoPeriodTmpSave( nIDExpo, dToDate, nOborKt - nOborDt, nOborKt, nOborDt );
              nTempDt  := nOborDt;
              nTempKt  := nOborKt;
              dToDate  := rec.DDATE;
            exception
              when no_data_found then
                null;
            end;

            nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
            nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
          end loop;
        else
          for rec in SaldoDate( nIDExpo, dFrDate, nOper ) loop
            if ( not bDummy and
                rec.DDATE = dToDate ) then
              nTempDt  := nOborDt;
              nTempKt  := nOborKt;
              bDummy   := true;
            end if;

            begin
              select 1
                into nPeriod
                from dual
               where exists
                       (select dDate
                          from table( cast( aRangeDates as Schema_GPSys.Tbl1Date ) )
                         where dDate = rec.DDATE and
                               dDate < dToDate);

              nOborDt  := nvl( nTempDt, 0 ) - nOborDt;
              nOborKt  := nvl( nTempKt, 0 ) - nOborKt;
              SaldoPeriodTmpSave( nIDExpo, dToDate, nOborKt - nOborDt, nOborKt, nOborDt );
              nTempDt  := nOborDt;
              nTempKt  := nOborKt;
              dToDate  := rec.DDATE;
            exception
              when no_data_found then
                null;
            end;

            nOborDt  := nOborDt - nvl( rec.AMOUNTDT, 0 );
            nOborKt  := nOborKt - nvl( rec.AMOUNTKT, 0 );
          end loop;
        end if;
      exception
        when no_data_found then
          null;
      end;
    end if;
  end ExpoSysSaldoPeriods;

  --------------------------------------------------------------------------------
  function IsReNewedExpo( nIDExpo in integer )
    return boolean is
    nCount  integer := 0;
  begin
    select count( 1 )
      into nCount
      from (select 1
              from CURRENT_EXPO
             where ID_EXPO = nIDExpo and
                   START_DATE > OPEN_DATE
            union all
            select 1
              from DEPOSIT_EXPO
             where ID_EXPO = nIDExpo and
                   START_DATE > OPEN_DATE);

    return nCount > 0;
  end IsReNewedExpo;

  --------------------------------------------------------------------------------
  function GetExpiryDate( nIDExpo in integer )
    return date is
    dExpDate  date;
  begin
    for expodata in ( select *
                        from DEPOSIT_EXPO
                       where ID_EXPO = nIDExpo ) loop
      if ( Schema_GPSys.HeadExpo.IsItOverNightDepo( expodata.ID_EXPO, expodata.TYPE_EXPO ) ) then
        dExpDate  := CALCLIH.ExpiryDate( expodata.START_DATE, Schema_GPSys.HeadExpo.DepositVidSrok_Days, 1, expodata.TODATE1 );
      else
        dExpDate  := Calclih.ExpiryDate( expodata.START_DATE, expodata.VID_SROK, expodata.SROK, expodata.TODATE1 );
      end if;
    end loop;

    return dExpDate;
  end GetExpiryDate;

  --------------------------------------------------------------------------------
  function IsAvanLihExpo( nIDExpo in integer )
    return boolean is
    nCount  integer := 0;
  begin
    select count( 1 )
      into nCount
      from DEPOSIT_EXPO
     where ID_EXPO = nIDExpo and
           nvl( AVANS_LIH, 'F' ) = 'T';

    return nCount > 0;
  end IsAvanLihExpo;

  --------------------------------------------------------------------------------
  procedure SaveGroupLimitsDataDocIntoReg(
    nDocType  in integer,
    oDoc      in Schema_GPSys.DocSysIQType,
    nDocNum   in integer,
    nChStamp  in integer
  ) is
    oList            Schema_GPSys.DocSysList;
    oDocSubLimits    Schema_GPSys.RecDocSysType;
    rGroupLimits     GROUP_LIMITS%rowtype;
    rGroupSubLimits  GROUP_SUBLIMITS%rowtype;
    nChSt            integer;
    nSubLimit        integer;
    bDummy           boolean;
  begin
    for rec in ( select a.FieldType,
                        a.nv,
                        a.sv,
                        a.dv,
                        a.mvc,
                        a.mva,
                        b.MATTER_ID
                   from table( cast( oDoc as Schema_GPSys.DocSysIQType ) ) a,
                        EXPO_SERVICEDOC b
                  where b.DOC_TYPE = nDocType and
                        b.FIELD_TYPE = a.FieldType ) loop
      if ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_ID_LIMIT' ) then
        rGroupLimits.ID_LIMIT  := rec.nv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_ID_GROUP' ) then
        rGroupLimits.ID_GROUP  := rec.nv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_BEG_DATE' ) then
        rGroupLimits.BEG_DATE  := rec.dv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_END_DATE' ) then
        rGroupLimits.END_DATE  := rec.dv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_SUMLIMIT' ) then
        rGroupLimits.SUMLIMIT  := rec.nv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_STATUS' ) then
        rGroupLimits.STATUS  := rec.sv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_APPROVED_BY' ) then
        rGroupLimits.APPROVED_BY  := rec.nv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_SUB_LIMITS' ) then
        nSubLimit  := rec.nv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_CH_OPER' ) then
        rGroupLimits.CH_OPER  := rec.nv;
      elsif ( rec.MATTER_ID = 'EXPO_GROUPLIMIT_CONFIRM_LVL' ) then
        rGroupLimits.CONFIRM_LVL  := rec.sv;
      end if;
    end loop;

    delete from GROUP_SUBLIMITS
          where ID_LIMIT = rGroupLimits.ID_LIMIT;

    if ( nDocNum is not null and
        nSubLimit is not null ) then
      oDocSubLimits  := Schema_GPSys.RecDocSysType( );
      Schema_DocSys.DocSys.GetList( nSubLimit, oList );

      for ii in oList.first .. oList.last loop
        rGroupSubLimits  := null;
        Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDocSubLimits );

        for rec in ( select a.FLDType,
                            a.nv,
                            a.sv,
                            a.dv,
                            a.mvc,
                            a.mva,
                            b.MATTER_ID
                       from table( cast( oDocSubLimits as Schema_GPSys.RecDocSysType ) ) a,
                            EXPO_SERVICEDOC b
                      where b.DOC_TYPE = oList( ii ).DocType and
                            b.FIELD_TYPE = a.FLDType ) loop
          if ( rec.MATTER_ID = 'EXPO_GROUPSUBLIMIT_ID_CUST' ) then
            rGroupSubLimits.ID_CUST  := rec.nv;
          elsif ( rec.MATTER_ID = 'EXPO_GROUPSUBLIMIT_TERM_LIMIT' ) then
            rGroupSubLimits.TERM_LIMIT  := rec.nv;
          elsif ( rec.MATTER_ID = 'EXPO_GROUPSUBLIMIT_PRODUCT_LIMIT' ) then
            rGroupSubLimits.PRODUCT_LIMIT  := rec.nv;
          elsif ( rec.MATTER_ID = 'EXPO_GROUPSUBLIMIT_SUMLIMIT' ) then
            rGroupSubLimits.SUMLIMIT  := rec.nv;
          end if;
        end loop;

        begin
          insert into GROUP_SUBLIMITS(
                        ID_LIMIT,
                        ID_CUST,
                        TERM_LIMIT,
                        PRODUCT_LIMIT,
                        SUMLIMIT
                      )
               values ( rGroupLimits.ID_LIMIT,
                        rGroupSubLimits.ID_CUST,
                        rGroupSubLimits.TERM_LIMIT,
                        rGroupSubLimits.PRODUCT_LIMIT,
                        rGroupSubLimits.SUMLIMIT
                       );
        exception
          when dup_val_on_index then
            null;
        end;
      end loop;
    end if;

    if ( nDocNum is null ) then
      nChSt  := 0;
    else
      bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj3( Schema_GPSys.OraGPSys.LockTypeGroupLimits, rGroupLimits.ID_LIMIT );
      nChSt   := nChStamp;
      Expo.SetMaxExpoNumber( 'IDGroupLimits', rGroupLimits.ID_LIMIT );
    end if;

    update GROUP_LIMITS
       set ID_GROUP     = rGroupLimits.ID_GROUP,
           ID_LIMIT     = rGroupLimits.ID_LIMIT,
           BEG_DATE     = rGroupLimits.BEG_DATE,
           END_DATE     = rGroupLimits.END_DATE,
           SUMLIMIT     = rGroupLimits.SUMLIMIT,
           STATUS       = rGroupLimits.STATUS,
           APPROVED_BY  = rGroupLimits.APPROVED_BY,
           CONFIRM_LVL  = rGroupLimits.CONFIRM_LVL,
           CH_OPER      = rGroupLimits.CH_OPER,
           DOC_NUM      = nDocNum,
           CH_STAMP     = nChSt
     where ID_LIMIT = rGroupLimits.ID_LIMIT;

    if ( sql%rowcount = 0 ) then
      insert into GROUP_LIMITS(
                    ID_GROUP,
                    ID_LIMIT,
                    BEG_DATE,
                    END_DATE,
                    SUMLIMIT,
                    STATUS,
                    APPROVED_BY,
                    CONFIRM_LVL,
                    CH_OPER,
                    DOC_NUM,
                    CH_STAMP
                  )
           values ( rGroupLimits.ID_GROUP,
                    rGroupLimits.ID_LIMIT,
                    rGroupLimits.BEG_DATE,
                    rGroupLimits.END_DATE,
                    rGroupLimits.SUMLIMIT,
                    rGroupLimits.STATUS,
                    rGroupLimits.APPROVED_BY,
                    rGroupLimits.CONFIRM_LVL,
                    rGroupLimits.CH_OPER,
                    nDocNum,
                    nChSt
                   );
    end if;
  end SaveGroupLimitsDataDocIntoReg;

  --------------------------------------------------------------------------------
  function GetPeriodCode(
    sMode     in varchar2,
    nSrok     in integer,
    nPattern  in integer default 0
  )
    return integer is
    iqQ         Schema_GPSys.OraGPSys.EmpCurTyp;
    rOtherCode  BNB_OTHRCODE%rowtype;
  begin
    open iqQ for
        select OTHRCODE,
               FLDSROK
          from BNB_OTHRCODE
         where FLDMODE = sMode and
               FLDSROK <= nSrok and
               nvl( PATTERN, 0 ) = nPattern
      order by FLDSROK desc;

    fetch iqQ
      into rOtherCode.OTHRCODE, rOtherCode.FLDSROK;

    if ( iqQ%notfound ) then
      rOtherCode.OTHRCODE  := -1;
    end if;

    close iqQ;

    return rOtherCode.OTHRCODE;
  end GetPeriodCode;

  --------------------------------------------------------------------------------
  function IsForbiddenKT( nExpo in integer )
    return boolean is
    nDummy  integer;
  begin
    select count( 1 )
      into nDummy
      from EXPO_LIMITS
     where ID_EXPO = nExpo and
           STATUS = ZaporStat_Active and
           TYPE_LIMIT = ExpoLimit_ForbiddenKT and
           rownum < 2;

    return nDummy > 0;
  end IsForbiddenKT;

  --------------------------------------------------------------------------------
  procedure XX01 is
    sError       varchar2( 256 );
    bRet         boolean;
    nSum         number;
    recObjGroup  OBJ_GROUP_REL%rowtype;
  begin
    --    bRet  := FillBNBCodes( -1, 0, to_date('09.03.2003' , 'dd.mm.yyyy' ));
    --nSum  := CalcExpoAverageSaldo( 75, to_date( '01.09.2003', 'dd.mm.yyyy' ), to_date( '08.09.2003', 'dd.mm.yyyy' ), false );
    /*
        if ( bRet ) then
          dbms_output.put_line( 'true' );
        else
          dbms_output.put_line( 'false' );
        end if;

        dbms_output.put_line( sError );*/
    recObjGroup.ID_GROUP   := 4;
    recObjGroup.TYPE_OBJ1  := 2;
    recObjGroup.ID_OBJ1    := 82;
    recObjGroup.TYPE_OBJ2  := 2;
    recObjGroup.ID_OBJ2    := 83;
    recObjGroup.STATUS     := 'F';
    bRet                   := Loans.ChangePadDate( 4, sysdate, true );
  end XX01;
--------------------------------------------------------------------------------
end Expo;
/
