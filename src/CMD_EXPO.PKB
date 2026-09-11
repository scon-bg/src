create or replace package body Cmd_Expo as
  --------------------------------------------------------------------------------
  type tblSaldaConf is table of END_SALDA_CONF%rowtype
    index by binary_integer;

  bNoRateDiffer4Cash      boolean;
  bINI_CheckPeriodValior  boolean;
  bIniStornoFirstOrgText  boolean;
  --
  sRateDifferType         varchar2( 64 );
  sRateDifferSubType      varchar2( 64 );
  --
  aAddTaxKey              Schema_GPSys.OraGPSys.aStrings;
  --
  sForApproval            varchar2( 3000 );
  --
  nMaxOperSum             number;

  --------------------------------------------------------------------------------
  function GetMaxOperSum
    return number is
  begin
    if ( nMaxOperSum is null ) then
      nMaxOperSum  := Schema_GPSys.OraGPSys.My_to_number( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'MAXOPERSUM', '0' ) );
    end if;

    return case
             when nMaxOperSum <= 0 then Schema_GPSys.OraGPSys.nMaxMoney
             else nMaxOperSum
           end;
  end GetMaxOperSum;

  --------------------------------------------------------------------------------
  procedure SetAddTaxKey(
    sType  in varchar2,
    nMode  in integer
  ) is
  begin
    if ( nMode is not null ) then
      aAddTaxKey( nMode )  := sType;
    end if;
  end SetAddTaxKey;

  --------------------------------------------------------------------------------
  function GetAddTaxKey( nMode in integer )
    return varchar2 is
    kk  integer;
  begin
    kk  := aAddTaxKey.first;

    if ( kk is not null and
        aAddTaxKey.exists( nMode ) ) then
      return aAddTaxKey( nMode );
    else
      return null;
    end if;
  end GetAddTaxKey;

  --------------------------------------------------------------------------------
  procedure ClrAddTaxKey is
  begin
    aAddTaxKey.delete;
  end ClrAddTaxKey;

  --------------------------------------------------------------------------------
  procedure SetRateDifferType(
    sType  in varchar2,
    nMode  in integer default 0
  ) is
  begin
    if ( nMode in (0, 1) ) then
      sRateDifferType  := sType;
    else
      sRateDifferSubType  := sType;
    end if;
  end SetRateDifferType;

  --------------------------------------------------------------------------------
  function GetRateDifferType( nMode in integer default 0 )
    return varchar2 is
  begin
    if ( nMode in (0, 1) ) then
      return sRateDifferType;
    else
      return sRateDifferSubType;
    end if;
  end GetRateDifferType;

  --------------------------------------------------------------------------------
  procedure ClrRateDifferType( nMode in integer default 0 ) is
  begin
    if ( nMode in (0, 1) ) then
      sRateDifferType  := null;
    end if;

    if ( nMode in (0, 2) ) then
      sRateDifferSubType  := null;
    end if;
  end ClrRateDifferType;

  --------------------------------------------------------------------------------
  function NoRateDiffer4Cash
    return boolean is
  begin
    if ( bNoRateDiffer4Cash is null ) then
      bNoRateDiffer4Cash      := nvl( Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All,
                                                                                                               'Счетоводство',
                                                                                                               'CASH_NORATEDIFFER',
                                                                                                               'F'
                                                                                                              )
                                                                        ),
                                      false
                                     );
    end if;

    return bNoRateDiffer4Cash;
  end NoRateDiffer4Cash;

  --------------------------------------------------------------------------------
  function GetINI_CheckPeriodValior
    return boolean is
  begin
    if ( bINI_CheckPeriodValior is null ) then
      bINI_CheckPeriodValior  := Schema_GPSys.OraGPSys.OracleBoolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_RA.GPC_RA.nCurrentUniqCode, 'Счетоводство', 'CheckPeriodValior', 'F' ) );
    end if;

    return bINI_CheckPeriodValior;
  end GetINI_CheckPeriodValior;

  --------------------------------------------------------------------------------
  function GetOperTaxSum(
    sTaxKey       in     varchar2,
    sCodVal       in     varchar2,
    dForDate      in     date,
    nToAmount     in     number,
    nUniqCode     in     integer,
    sTaxVal       in out varchar2,
    nTaxSum       in out number,
    nRealAmount   in     number default null,
    sAddKey       in     varchar2 default null,
    nTaxedClient  in     integer default 0,
    nIDExpo       in     integer default 0
  )
    return boolean is
    sValTax  varchar2( 3 );
    nSumTax  number;
    nTSum    number;
    nRSum    number;
    nMinSum  number;
    nMaxSum  number;

    cursor qTaxes(
      sKey      in varchar2,
      sAdd      in varchar2,
      sVal      in varchar2,
      dDate     in date,
      nUCode    in integer,
      nTClient  in integer
    ) is
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             1 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sKey and
             CODVAL = sVal and
             FROM_DATE <= dDate and
             UNIQCODE = -nTClient
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             2 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sKey and
             CODVAL = 'val' and
             FROM_DATE <= dDate and
             UNIQCODE = -nTClient
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             3 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sAdd and
             CODVAL = sVal and
             FROM_DATE <= dDate and
             UNIQCODE = -nTClient
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             4 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sAdd and
             CODVAL = 'val' and
             FROM_DATE <= dDate and
             UNIQCODE = -nTClient
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             5 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sKey and
             CODVAL = sVal and
             FROM_DATE <= dDate and
             UNIQCODE = nUCode
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             6 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sKey and
             CODVAL = 'val' and
             FROM_DATE <= dDate and
             UNIQCODE = nUCode
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             7 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sAdd and
             CODVAL = sVal and
             FROM_DATE <= dDate and
             UNIQCODE = nUCode
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             8 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sAdd and
             CODVAL = 'val' and
             FROM_DATE <= dDate and
             UNIQCODE = nUCode
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             9 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sKey and
             CODVAL = sVal and
             FROM_DATE <= dDate and
             UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             10 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sKey and
             CODVAL = 'val' and
             FROM_DATE <= dDate and
             UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             11 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sAdd and
             CODVAL = sVal and
             FROM_DATE <= dDate and
             UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All
      union all
      select UNIQCODE,
             TAX_KEY,
             CODVAL,
             TAXVAL,
             FROM_DATE,
             AMN_TO,
             percent,
             OFFSET,
             MIN_SUM,
             MAX_SUM,
             OFFSETVAL,
             MINMAX_VAL,
             INT_CODE,
             12 as nLevel
        from EXPO_TAXES
       where TAX_KEY = sAdd and
             CODVAL = 'val' and
             FROM_DATE <= dDate and
             UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All
      order by nLevel asc,
               FROM_DATE desc,
               AMN_TO asc;

  begin
    sTaxVal        := Schema_GPSys.OraGPSys.SYS_CURR;
    nTaxSum        := 0;
    Taxes.rTarifa  := null;

    for Rec in qTaxes( sTaxKey, sAddKey, sCodVal, dForDate, nUniqCode, nTaxedClient ) loop
      nTSum  := Schema_GPSys.XchgRates.GetExactSum( nToAmount, nUniqCode, dForDate, sCodVal, Rec.TAXVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );

      if ( Rec.AMN_TO >= nTSum ) then
        if ( nRealAmount is null ) then
          nRSum  := nTSum;
        else
          nRSum  := Schema_GPSys.XchgRates.GetExactSum( nRealAmount, nUniqCode, dForDate, sCodVal, Rec.TAXVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
        end if;

        sTaxVal      := Rec.TAXVAL;
        nMinSum      := nvl( Rec.MIN_SUM, 0 );

        if ( nMinSum != 0 and
            nvl( Rec.MINMAX_VAL, Rec.TAXVAL ) != Rec.TAXVAL ) then
          nMinSum  := Schema_GPSys.XchgRates.GetExactSum( nMinSum, nUniqCode, dForDate, Rec.MINMAX_VAL, Rec.TAXVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
        end if;

        nMaxSum      := nvl( Rec.MAX_SUM, 0 );

        if ( nMaxSum != 0 and
            nvl( Rec.MINMAX_VAL, Rec.TAXVAL ) != Rec.TAXVAL ) then
          nMaxSum  := Schema_GPSys.XchgRates.GetExactSum( nMaxSum, nUniqCode, dForDate, Rec.MINMAX_VAL, Rec.TAXVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
        end if;

        nTaxSum      := greatest( nRSum * nvl( Rec.percent, 0 ) / 100 +
                                  Schema_GPSys.XchgRates.GetExactSum( nvl( Rec.OFFSET, 0 ),
                                                                      nUniqCode,
                                                                      dForDate,
                                                                      nvl( Rec.OFFSETVAL, Rec.TAXVAL ),
                                                                      Rec.TAXVAL,
                                                                      Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                     ),
                                  nMinSum
                                 );

        if ( nMaxSum > 0 ) then
          nTaxSum  := least( nTaxSum, nMaxSum );
        end if;

        nTaxSum      := Schema_GPSys.OraGPSys.nTruncSet( nTaxSum, sTaxVal );

        if ( nRealAmount is null ) then
          if ( Taxes.GetTarifaTaxSum( Rec.INT_CODE, sCodVal, dForDate, nToAmount, nUniqCode, nTaxedClient, sValTax, nSumTax, null, 0, nIDExpo ) ) then
            sTaxVal  := sValTax;
            nTaxSum  := nSumTax;
          end if;
        else
          if ( Taxes.GetTarifaTaxSum( Rec.INT_CODE, sCodVal, dForDate, nRealAmount, nUniqCode, nTaxedClient, sValTax, nSumTax, null, 0, nIDExpo ) ) then
            sTaxVal  := sValTax;
            nTaxSum  := nSumTax;
          end if;
        end if;

        exit;
      end if;
    end loop;

    return nvl( nTaxSum, 0 ) > 0;
  end GetOperTaxSum;

  --------------------------------------------------------------------------------
  function CreateSchTrans(
    oDoc          in out nocopy Schema_GPSys.DocSysIQType,
    nDocID        in out nocopy pls_integer,
    nOpersID      in out nocopy pls_integer,
    oOpers        in out nocopy Schema_GPSys.TblSchOper,
    DealOper      in            Schema_GPSys.tblDealOper,
    sError        in out nocopy varchar2,
    nUniqCode     in            integer,
    nIDCust       in            integer,
    dSchDate      in            date,
    DealType      in            pls_integer,
    nExpoDt       in            integer,
    AmountDt      in            number,
    AmountKt      in            number,
    nExpoKt       in            integer,
    ValiorDt      in            date,
    ValiorKt      in            date,
    cUseTaxes     in            varchar2,
    AmountSys     in            number,
    bZBalSpot     in            boolean,
    bCashReq      in            boolean,
    CloseExpo     in            integer,
    bLastDeal     in            boolean,
    bExistBudget  in            boolean,
    BdgRows       in out nocopy tblBdgOpers,
    nCurrDeal     in            integer,
    aTaxedExpo    in out nocopy Schema_GPSys.OraGPSys.aNumbers,
    RegTaxes      in out nocopy Taxes.tblRegTaxes
  )
    return boolean is
    oDocRow             Schema_GPSys.DocSysIQRecType;
    oOper               Schema_GPSys.TSchOper;
    aCredExpo           Schema_GPSys.OraGPSys.aNumbers;
    rCustData           Schema_Cust.GPC_Customs.recCustData;
    nFirstOper          pls_integer;
    ii                  pls_integer;
    rBDGData            BDG_MOVES%rowtype;
    RecExpoDt           Schema_GPSys.EXPOSITION%rowtype;
    RecExpoKt           Schema_GPSys.EXPOSITION%rowtype;
    RecTypeDt           Schema_GPSys.EXPOTYPES%rowtype;
    RecTypeKt           Schema_GPSys.EXPOTYPES%rowtype;
    rTaxRegDt           TAXES_REGISTER%rowtype;
    rTaxRegKt           TAXES_REGISTER%rowtype;
    rTarifaDt           Taxes.recTarifa;
    rTarifaKt           Taxes.recTarifa;
    nAmountDt           number;
    nAmountKt           number;
    nAmountSys          number;
    nSysAmountDt        number;
    nSysAmountKt        number;
    nSysDiff            number;
    nValDiff            number;
    nBdgDiff            number;
    nDaySum             number;
    nScale              number;
    nTaxedSum           number;
    nExpoCR             integer;
    sCValCR             Schema_GPSys.EXPOSITION.CODVAL%type;
    IDEZBalA            integer;
    ValZBalA            Schema_GPSys.EXPOSITION.CODVAL%type;
    IDEZBalP            integer;
    ValZBalP            Schema_GPSys.EXPOSITION.CODVAL%type;
    IDESpotBuy          integer;
    ValSpotBuy          Schema_GPSys.EXPOSITION.CODVAL%type;
    IDESpotSell         integer;
    ValSpotSell         Schema_GPSys.EXPOSITION.CODVAL%type;
    RealDt              integer;
    sTaxKeyDt1          varchar2( 64 );
    sTaxKeyDt2          varchar2( 64 );
    sTaxKeyKt1          varchar2( 64 );
    sTaxKeyKt2          varchar2( 64 );
    sType               varchar2( 64 ) := GetRateDifferType;
    sSubType            varchar2( 64 );
    sCashRequest        varchar2( 1 ) := 'F';
    sTaxValDt           Schema_GPSys.EXPOSITION.CODVAL%type;
    nTaxSumDt           number;
    sTaxValKt           Schema_GPSys.EXPOSITION.CODVAL%type;
    nTaxSumKt           number;
    nTaxDt              number; -- use this variabe carefully
    nTemp               number;
    nIdEPrihod          integer;
    nIDExpoTax          integer;
    nIDExpoCash         integer;
    ValExpoCash         Schema_GPSys.EXPOSITION.CODVAL%type;
    nModePrivilege      integer;
    nDummy              integer;
    cValPrihod          Schema_GPSys.EXPOSITION.CODVAL%type;
    cValDummy           Schema_GPSys.EXPOSITION.CODVAL%type;
    cc                  varchar2( 128 );
    sCodValTax          varchar2( 3 );
    sExclSyntCode       varchar2( 4000 );
    dValior             date;
    dValiorNextWrkDate  date;
    dBegDate            date;
    dWrkDate            date;
    bUseKTAmount        boolean := false;
    bNoRateDiffer       boolean;
    bCashExpo           boolean;
    bDummy              boolean := true;
    bRet                boolean := false;
    aParams             Schema_RA.GPC_RA.tblErrParams;
  begin
    sError         := Schema_GPSys.MLng.Str2( 'Непознат тип счетоводство', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
    cc             := Schema_GPSys.OraGPSys.IntToS( nExpoDt )||
                      ' ' ||
                      Schema_GPSys.MLng.Str2( 'и', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG )||
                      ' ' ||
                      Schema_GPSys.OraGPSys.IntToS( nExpoKt );
    bNoRateDiffer  := Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'NORATE_DIFFER', null ) );
    bNoRateDiffer  := nvl( bNoRateDiffer, Schema_RA.GPC_Tools.IsFirmSch( nUniqCode ) );
    bDummy         := bNoRateDiffer is not null;

    if ( bDummy ) then
      begin
        select a.UNIQCODE,
               a.CODVAL,
               a.ID_CUST,
               a.TYPE_EXPO,
               a.EXPO_CODE,
               a.SYNT_CODE,
               a.AN_FEAT,
               b.IN_BALANCE,
               b.BASE_TYPE
          into RecExpoDt.UNIQCODE,
               RecExpoDt.CODVAL,
               RecExpoDt.ID_CUST,
               RecExpoDt.TYPE_EXPO,
               RecExpoDt.EXPO_CODE,
               RecExpoDt.SYNT_CODE,
               RecExpoDt.AN_FEAT,
               RecTypeDt.IN_BALANCE,
               RecTypeDt.BASE_TYPE
          from Schema_GPSys.EXPOSITION a,
               Schema_GPSys.EXPOTYPES b
         where a.ID_EXPO = nExpoDt and
               b.TYPE_EXPO = a.TYPE_EXPO;

        if ( not bExistBudget ) then
          select count( 1 )
            into nTemp
            from Schema_GPSys.CONFSYSTEM
           where FLDSECTION = 'EXPOSITION' and
                 FLDITEM = 'BUDGET_EXPO_TYPES' and
                 UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                 FLDVALUE like '%&' || to_char( RecExpoDt.TYPE_EXPO ) || '&%';

          if ( nTemp > 0 ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'EXPO_DT';
            aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoDt );
            sError                 := Schema_GPSys.MLng.Str2( 'Липсва бюджетна класификация по експозиция $EXPO_DT$',
                                                              Schema_GPSys.MLng.ctxAccounting,
                                                              Schema_GPSys.MLng.lngBG,
                                                              aParams
                                                             );
            bDummy                 := false;
          end if;
        end if;
      exception
        when no_data_found then
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'EXPO_DT';
          aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoDt );
          sError                 := Schema_GPSys.MLng.Str2( 'Непозната експозиция $EXPO_DT$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
          bDummy                 := false;
      end;
    end if;

    if ( bDummy ) then
      begin
        select a.UNIQCODE,
               a.CODVAL,
               a.ID_CUST,
               a.TYPE_EXPO,
               a.EXPO_CODE,
               a.SYNT_CODE,
               a.AN_FEAT,
               b.IN_BALANCE,
               b.BASE_TYPE
          into RecExpoKt.UNIQCODE,
               RecExpoKt.CODVAL,
               RecExpoKt.ID_CUST,
               RecExpoKt.TYPE_EXPO,
               RecExpoKt.EXPO_CODE,
               RecExpoKt.SYNT_CODE,
               RecExpoKt.AN_FEAT,
               RecTypeKt.IN_BALANCE,
               RecTypeKt.BASE_TYPE
          from Schema_GPSys.EXPOSITION a,
               Schema_GPSys.EXPOTYPES b
         where a.ID_EXPO = nExpoKt and
               b.TYPE_EXPO = a.TYPE_EXPO;

        if ( not bExistBudget ) then
          select count( 1 )
            into nTemp
            from Schema_GPSys.CONFSYSTEM
           where FLDSECTION = 'EXPOSITION' and
                 FLDITEM = 'BUDGET_EXPO_TYPES' and
                 UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                 FLDVALUE like '%&' || to_char( RecExpoKt.TYPE_EXPO ) || '&%';

          if ( nTemp > 0 ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'EXPO_KT';
            aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoKt );
            sError                 := Schema_GPSys.MLng.Str2( 'Липсва бюджетна класификация по експозиция $EXPO_KT$',
                                                              Schema_GPSys.MLng.ctxAccounting,
                                                              Schema_GPSys.MLng.lngBG,
                                                              aParams
                                                             );
            bDummy                 := false;
          end if;
        end if;
      exception
        when no_data_found then
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'EXPO_KT';
          aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoKt );
          sError                 := Schema_GPSys.MLng.Str2( 'Непозната експозиция $EXPO_KT$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
          bDummy                 := false;
      end;
    end if;

    if ( bDummy ) then
      $if ( Schema_GPSys.OraSys.VerBankTransact or
           Schema_GPSys.OraSys.VerPaynetics ) $then
      sExclSyntCode      := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'PreocExclSyntCode', '~' );
      bUseKTAmount       := instr( sExclSyntCode, '&' || RecExpoKt.SYNT_CODE || '&' ) != 0;
      bNoRateDiffer      := instr( sExclSyntCode, '&' || RecExpoDt.SYNT_CODE || '&' ) != 0 or
                            bUseKTAmount;

      $end
      if ( ( nUniqCode = RecExpoDt.UNIQCODE and
            nUniqCode = RecExpoKt.UNIQCODE ) or
          not Expo.IsSystemHaveBalances ) then
        if ( RecTypeDt.IN_BALANCE = RecTypeKt.IN_BALANCE ) then
          nAmountDt  := Schema_GPSys.OraGPSys.nTruncSet( AmountDt, RecExpoDt.CODVAL );
          nAmountKt  := Schema_GPSys.OraGPSys.nTruncSet( AmountKt, RecExpoKt.CODVAL );

          if ( RecExpoDt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
            nAmountSys  := nAmountDt;
            sSubType    := 'Sell';
          elsif ( RecExpoKt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
            nAmountSys  := nAmountKt;
            sSubType    := 'Buy';
          else
            nAmountSys  := Schema_GPSys.OraGPSys.nTruncSet( nvl( AmountSys, 0 ), Schema_GPSys.OraGPSys.SYS_CURR );
            sSubType    := 'Arb';
          end if;

          if ( RecExpoDt.CODVAL = RecExpoKt.CODVAL ) then
            if ( DealType = Sch_CashDeal ) then
              sType  := 'CashDeal';
            else
              sType  := 'Cash';
            end if;

            sSubType  := RecExpoDt.CODVAL;
          end if;

          if ( ( RecExpoDt.CODVAL != RecExpoKt.CODVAL or
                DealType in (Sch_Deal, Sch_CashDeal) or
                nAmountDt = nAmountKt ) and
              ( DealType in (Sch_Preocenka, Sch_ClearOborot) or
               ( nAmountDt * nAmountKt ) > 0 or
               -- да се допуска в случай на прехвърляне(по оборотно) на експозиции между поделения и има наличен оборот в системна валута, а няма такъв в оригинална валута
               ( DealType = Sch_ImportOborot and
                nAmountSys != 0 and
                ( ( nAmountDt = nAmountSys and
                   nAmountKt = 0 ) or
                 ( nAmountKt = nAmountSys and
                  nAmountDt = 0 ) ) ) --
                                      ) and
              ( nAmountSys = 0 or
               ( ( nAmountDt = 0 or
                  ( nAmountDt * nAmountSys ) > 0 ) and
                ( nAmountKt = 0 or
                 ( nAmountKt * nAmountSys ) > 0 ) ) ) ) then
            nFirstOper  := oOpers.count + 1;

            select count( 1 )
              into ii
              from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
             where a.ExpoDt = nExpoDt and
                   a.ExpoKt = nExpoKt;

            if ( ii = 0 and
                nvl( cUseTaxes, 'T' ) in ('T', 'D', 'K', 'I') and
                RecTypeDt.IN_BALANCE = 'T' and
                ( RecExpoDt.CODVAL = RecExpoKt.CODVAL or
                 Schema_GPSys.OraSys.VerBankUnion or
                 Schema_GPSys.OraSys.VerBankDBank or
                 Schema_GPSys.OraSys.VerBankSAS or
                 Schema_GPSys.OraSys.VerBankTransact or
                 Schema_GPSys.OraSys.VerBankTokuda or
                 Schema_GPSys.OraSys.VerPaynetics ) and
                ( not DealType in
                        ( Sch_ImportOborot,
                         Sch_ClearOborot,
                         Sch_Storno,
                         Sch_AvanLihvi,
                         Sch_AvanTranLih,
                         Sch_CommLih,
                         Sch_Lihvi,
                         Sch_TranLih,
                         Sch_TaxLihvi,
                         Sch_PlanLihvi,
                         Sch_RateDiffer,
                         Sch_Preocenka,
                         Sch_CredEngagement,
                         Sch_ZBalPpv,
                         Sch_ForSch,
                         Sch_ZadBalDeal,
                         Sch_Deal,
                         Sch_Budget,
                         Sch_MMarket,
                         Sch_DMA ) ) and
                ( not Taxes.bIsOperTypeTax( DealType ) ) and
                ( RecExpoDt.ID_CUST != RecExpoKt.ID_CUST or
                 Schema_GPSys.HeadExpo.IsItVisaVirtu( nExpoKt, RecExpoKt.TYPE_EXPO ) ) and
                ( RecExpoDt.ID_CUST > 0 or
                 RecExpoKt.ID_CUST > 0 ) ) then
              if ( nvl( cUseTaxes, 'T' ) in ('T', 'D', 'I') and
                  RecExpoDt.ID_CUST != RecExpoKt.ID_CUST and
                  RecExpoDt.ID_CUST > 0 and
                  ( Expo.GetSkipLimit( EXPO.ModeSkip_CustInConfig ) or
                   not Schema_RA.GPC_Tools.IsIdCustInConfig( RecExpoDt.ID_CUST ) ) and
                  nAmountDt > 0 ) then
                bDummy            := true;

                if ( Schema_GPSys.HeadExpo.IsItDepositExpo( nExpoDt ) ) then
                  dBegDate  := Expo.GetExpoLihDate( nExpoDt, true );

                  for recPer in (  select *
                                     from DEPOSIT_PERIODS
                                    where TYPE_EXPO = RecExpoDt.TYPE_EXPO and
                                          CODVAL in ('*', RecExpoDt.CODVAL)
                                 order by VID_SROK,
                                          SROK ) loop
                    dValior             := Calclih.ExpiryDate( dBegDate, recPer.VID_SROK, recPer.SROK, 0 );
                    dValiorNextWrkDate  := Schema_GPSys.OraGPSys.SeekWorkDay( dValior );
                    bDummy              := not ( ValiorDt between dValior and dValiorNextWrkDate );
                    exit when ( dValiorNextWrkDate >= ValiorDt ) or
                              ( not bDummy );
                  end loop;

                  if ( bDummy and
                      ( Schema_GPSys.OraSys.VerBankTokuda or
                       Schema_GPSys.OraSys.VerBankDBank ) ) then
                    dWrkDate    := nvl( Expo.GetExpiryDate( nExpoDt ), dBegDate );
                    bDummy      := not ( ValiorDt between dBegDate and Schema_GPSys.OraGPSys.SeekWorkDay( dBegDate ) ) and
                                   not ( ValiorDt between dWrkDate and Schema_GPSys.OraGPSys.SeekWorkDay( dWrkDate ) );
                  end if;
                end if;

                rCustData.IDCust  := RecExpoDt.ID_CUST;

                if ( bDummy and
                    Schema_Cust.GPC_Customs.GetCustData( rCustData, true ) ) then
                  sTaxKeyDt1    := 'OPERDT_';
                  sCashRequest  := 'F';
                  bCashExpo     := Schema_GPSys.HeadExpo.IsItCashExpo( nExpoKt );

                  if ( bCashReq ) then
                    sTaxKeyDt1  := sTaxKeyDt1 || 'REQ_' || GetAddTaxKey( 1 );
                  elsif ( ( Schema_GPSys.OraSys.VerBankTokuda or
                           Schema_GPSys.OraSys.VerBankDBank ) and
                         bCashExpo ) then
                    select /*+ LEADING( a b c d e ) USE_NL( b c d e )*/
                          count( 1 )
                      into nDummy
                      from CASH_REQUEST e,
                           Schema_GPSys.EXPOTYPES d,
                           Schema_GPSys.EXPOSITION c,
                           EXPO_MOVES b,
                           EXPO_MOVES a
                     where a.ID_EXPO = nExpoDt and
                           a.VALIOR = ValiorDt and
                           a.DT_KT = 'D' and
                           a.ID_MOVE = b.ID_MOVE and
                           a.ORDROWNUM = b.ORDROWNUM and
                           a.DT_KT != b.DT_KT and
                           b.ID_EXPO = c.ID_EXPO and
                           c.TYPE_EXPO = d.TYPE_EXPO and
                           d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash and
                           e.ID_MOVE = a.ID_MOVE and
                           e.ID_EXPO = nExpoDt;

                    if ( nDummy > 0 ) then
                      sTaxKeyDt1  := sTaxKeyDt1 || 'REQ_ADD_';

                      if ( not Schema_GPSys.OraSys.VerBankTokuda ) then
                        sCashRequest  := 'T';
                      end if;
                    end if;
                  end if;

                  if ( nvl( Expo.rMemoOrderAdd.nModeOrigin, Expo.ModeCashBigOpers ) in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins) ) then
                    sTaxKeyDt1  := sTaxKeyDt1 || 'ORG' || to_char( Expo.rMemoOrderAdd.nModeOrigin ) || '_';
                  end if;

                  sTaxKeyDt2    := sTaxKeyDt1 || rCustData.CliType || '_' || to_char( RecExpoDt.TYPE_EXPO ) || '_' || to_char( RecExpoKt.TYPE_EXPO );
                  sTaxKeyDt1    := sTaxKeyDt1 || rCustData.FType || '_' || to_char( RecExpoDt.TYPE_EXPO ) || '_' || to_char( RecExpoKt.TYPE_EXPO );
                  --
                  nTaxedSum     := 0;
                  nDaySum       := 0;

                  if ( Schema_GPSys.OraSys.VerBankTokuda and
                      bCashExpo ) then
                    if ( bCashReq ) then
                      select nvl( sum( AMOUNT_KT ), 0 )
                        into nTaxedSum
                        from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                       where a.EXPO_DT = nExpoDt and
                             a.EXPO_KT = nExpoKt and
                             a.DEAL_TYPE not in (Sch_FreeTaxes) and
                             nvl( a.USE_TAXES, 'F' ) in ('T', 'I');
                    else
                      select nvl( sum( AMOUNT_KT ), 0 )
                        into nTaxedSum
                        from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                       where a.EXPO_DT = nExpoDt and
                             a.EXPO_KT = nExpoKt and
                             a.DEAL_TYPE not in (Sch_FreeTaxes);
                    end if;

                    if ( nvl( Expo.rMemoOrderAdd.nModeOrigin, Expo.ModeCashBigOpers ) not in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins) ) then
                      select nvl( sum( a.SYS_AMOUNT ), 0 )
                        into nDaySum
                        from Schema_GPSys.EXPOTYPES d,
                             Schema_GPSys.EXPOSITION c,
                             EXPO_MOVES b,
                             EXPO_MOVES a
                       where a.ID_EXPO = nExpoDt and
                             a.VALIOR = ValiorDt and
                             a.DT_KT = 'D' and
                             ( sCashRequest = 'F' or
                              not exists
                                (select 1
                                   from CASH_REQUEST e
                                  where e.ID_MOVE = a.ID_MOVE and
                                        e.STATUS = Cash.CashDoc_Confirmed and
                                        a.ORDROWNUM = 1) ) and
                             not exists
                               (select 1
                                  from CASH_BIG_OPERS x
                                 where x.ID_MOVE = a.ID_MOVE and
                                       x.ORIGIN in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins)) and
                             a.ID_MOVE = b.ID_MOVE and
                             a.ORDROWNUM = b.ORDROWNUM and
                             a.DT_KT != b.DT_KT and
                             b.ID_EXPO = c.ID_EXPO and
                             c.TYPE_EXPO = d.TYPE_EXPO and
                             d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;

                      nDaySum  := Schema_GPSys.XchgRates.GetExactSum( nDaySum, nUniqCode, ValiorDt, Schema_GPSys.OraGPSys.SYS_CURR, RecExpoKt.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                    end if;

                    sCodValTax  := RecExpoKt.CODVAL;
                  elsif ( RecExpoDt.CODVAL = RecExpoKt.CODVAL ) then
                    if ( bCashExpo ) then
                      if ( bCashReq ) then
                        select nvl( sum( AMOUNT_DT ), 0 )
                          into nTaxedSum
                          from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                         where a.EXPO_DT = nExpoDt and
                               a.EXPO_KT = nExpoKt and
                               a.DEAL_TYPE not in (Sch_FreeTaxes) and
                               nvl( a.USE_TAXES, 'F' ) in ('T', 'I');
                      else
                        select nvl( sum( AMOUNT_DT ), 0 )
                          into nTaxedSum
                          from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                         where a.EXPO_DT = nExpoDt and
                               a.EXPO_KT = nExpoKt and
                               a.DEAL_TYPE not in (Sch_FreeTaxes);
                      end if;

                      nModePrivilege  := Taxes.GetModePrivilege( nExpoDt, ValiorDt, dBegDate, true );

                      if ( nModePrivilege = 0 ) then
                        begin
                          select 1
                            into nDummy
                            from Schema_GPSys.EXPOSITION a
                           where a.ID_EXPO = nExpoDt and
                                 exists
                                   (select 1
                                      from Schema_GPSys.CONFSYSTEM g
                                     where g.FLDSECTION = 'EXPOSITION' and
                                           g.FLDITEM = 'CASHTOTSUM_DT_PRIV8' and
                                           g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                           g.FLDVALUE like '%&' || to_char( a.TYPE_EXPO ) || '&%');
                        exception
                          when no_data_found then
                            nDummy  := 0;
                        end;

                        if ( nDummy > 0 ) then
                          for rExpo in ( select ID_EXPO
                                           from Schema_GPSys.EXPOSITION
                                          where ID_CUST = RecExpoDt.ID_CUST and
                                                STATUS = 'T' ) loop
                            if ( Taxes.GetModePrivilege( rExpo.ID_EXPO, ValiorDt, dBegDate, true ) = Taxes.ModeTaxPrivilege8 ) then
                              nModePrivilege  := Taxes.ModeTaxPrivilege8;
                              exit;
                            end if;
                          end loop;
                        end if;
                      end if;

                      if ( nModePrivilege in ( /*Taxes.ModeTaxPrivilege1, Taxes.ModeTaxPrivilege2,*/
                                              Taxes.ModeTaxPrivilege3, Taxes.ModeTaxPrivilege4, Taxes.ModeTaxPrivilege5, Taxes.ModeTaxPrivilege8, Taxes.ModeTaxPrivilege10) ) then
                        if ( nModePrivilege = Taxes.ModeTaxPrivilege8 ) then
                          select nvl( sum( a.AMOUNT ), 0 )
                            into nDaySum
                            from Schema_GPSys.EXPOTYPES d,
                                 Schema_GPSys.EXPOSITION c,
                                 EXPO_MOVES b,
                                 EXPO_MOVES a
                           where a.ID_EXPO in (select e.ID_EXPO
                                                 from Schema_GPSys.EXPOSITION e
                                                where e.ID_CUST = RecExpoDt.ID_CUST and
                                                      e.CODVAL = RecExpoDt.CODVAL and
                                                      exists
                                                        (select 1
                                                           from Schema_GPSys.CONFSYSTEM g
                                                          where g.FLDSECTION = 'EXPOSITION' and
                                                                g.FLDITEM = 'CASHTOTSUM_DT_PRIV8' and
                                                                g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                                                g.FLDVALUE like '%&' || to_char( e.TYPE_EXPO ) || '&%')) and
                                 a.VALIOR = ValiorDt and
                                 a.DT_KT = 'D' and
                                 a.ID_MOVE = b.ID_MOVE and
                                 a.ORDROWNUM = b.ORDROWNUM and
                                 a.DT_KT != b.DT_KT and
                                 b.ID_EXPO = c.ID_EXPO and
                                 c.TYPE_EXPO = d.TYPE_EXPO and
                                 d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;
                        else
                          select nvl( sum( a.AMOUNT ), 0 )
                            into nDaySum
                            from EXPO_MOVES a,
                                 EXPO_MOVES b,
                                 Schema_GPSys.EXPOSITION c,
                                 Schema_GPSys.EXPOTYPES d
                           where a.ID_EXPO = nExpoDt and
                                 a.VALIOR = ValiorDt and
                                 a.DT_KT = 'D' and
                                 a.ID_MOVE = b.ID_MOVE and
                                 a.ORDROWNUM = b.ORDROWNUM and
                                 a.DT_KT != b.DT_KT and
                                 b.ID_EXPO = c.ID_EXPO and
                                 c.TYPE_EXPO = d.TYPE_EXPO and
                                 d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;
                        end if;

                        if ( nModePrivilege = Taxes.ModeTaxPrivilege1 ) then
                          sTaxKeyDt1  := 'PRIV1' || sTaxKeyDt1;
                          sTaxKeyDt2  := 'PRIV1' || sTaxKeyDt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege2 ) then
                          sTaxKeyDt1  := 'PRIV2' || sTaxKeyDt1;
                          sTaxKeyDt2  := 'PRIV2' || sTaxKeyDt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege3 ) then
                          sTaxKeyDt1  := 'PRIV3' || sTaxKeyDt1;
                          sTaxKeyDt2  := 'PRIV3' || sTaxKeyDt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege4 ) then
                          sTaxKeyDt1  := 'PRIV4' || sTaxKeyDt1;
                          sTaxKeyDt2  := 'PRIV4' || sTaxKeyDt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege5 ) then
                          sTaxKeyDt1  := 'PRIV5' || sTaxKeyDt1;
                          sTaxKeyDt2  := 'PRIV5' || sTaxKeyDt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege8 ) then
                          sTaxKeyDt1  := 'PRIV8' || sTaxKeyDt1;
                          sTaxKeyDt2  := 'PRIV8' || sTaxKeyDt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege10 ) then
                          sTaxKeyDt1  := 'PRIV10' || sTaxKeyDt1;
                          sTaxKeyDt2  := 'PRIV10' || sTaxKeyDt2;
                        end if;
                      elsif ( nvl( Expo.rMemoOrderAdd.nModeOrigin, Expo.ModeCashBigOpers ) not in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins) ) then
                        if ( bCashReq and
                            false /*Schema_GPSys.OraSys.VerBankTokuda*/
                                  ) then
                          select /*+ LEADING( a b c d e ) USE_NL( b c d e )*/
                                nvl( sum( a.AMOUNT ), 0 )
                            into nDaySum
                            from CASH_REQUEST e,
                                 Schema_GPSys.EXPOTYPES d,
                                 Schema_GPSys.EXPOSITION c,
                                 EXPO_MOVES b,
                                 EXPO_MOVES a
                           where a.ID_EXPO = nExpoDt and
                                 a.VALIOR = ValiorDt and
                                 a.DT_KT = 'D' and
                                 a.ID_MOVE = b.ID_MOVE and
                                 a.ORDROWNUM = b.ORDROWNUM and
                                 a.DT_KT != b.DT_KT and
                                 b.ID_EXPO = c.ID_EXPO and
                                 c.TYPE_EXPO = d.TYPE_EXPO and
                                 d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash and
                                 e.ID_MOVE = a.ID_MOVE and
                                 e.ID_EXPO = nExpoDt and
                                 e.STATUS = Cash.CashDoc_Confirmed;
                        else
                          select count( 1 )
                            into ii
                            from Schema_GPSys.CONFSYSTEM g
                           where g.FLDSECTION = 'EXPOSITION' and
                                 g.FLDITEM = 'CASHNOTSUM_DT_GROUP' and
                                 g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                 g.FLDVALUE like '%&' || rCustData.CliType || to_char( RecExpoDt.TYPE_EXPO ) || RecExpoDt.CODVAL || '&%';

                          if ( ii = 0 and
                              ( Schema_GPSys.OraSys.VerBankUnion or
                               Schema_GPSys.OraSys.VerBankDBank or
                               Schema_GPSys.OraSys.VerBankSAS or
                               Schema_GPSys.OraSys.VerBankTokuda ) ) then
                            for recGroup in (  select *
                                                 from (select '1' as SGROUP
                                                         from dual
                                                       union all
                                                       select '2' as SGROUP
                                                         from dual
                                                       union all
                                                       select '3' as SGROUP
                                                         from dual)
                                             order by 1 ) loop
                              select count( 1 )
                                into ii
                                from Schema_GPSys.CONFSYSTEM g
                               where g.FLDSECTION = 'EXPOSITION' and
                                     g.FLDITEM = 'CASHTOTSUM_DT_GROUP' || recGroup.SGROUP and
                                     g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                     g.FLDVALUE like '%&' || rCustData.CliType || to_char( RecExpoDt.TYPE_EXPO ) || RecExpoDt.CODVAL || '&%';

                              if ( ii > 0 ) then
                                select nvl( sum( a.AMOUNT ), 0 )
                                  into nDaySum
                                  from Schema_GPSys.EXPOTYPES d,
                                       Schema_GPSys.EXPOSITION c,
                                       EXPO_MOVES b,
                                       EXPO_MOVES a
                                 where a.ID_EXPO in (select e.ID_EXPO
                                                       from Schema_GPSys.EXPOSITION e
                                                      where e.ID_CUST = RecExpoDt.ID_CUST and
                                                            e.CODVAL = RecExpoDt.CODVAL and
                                                            exists
                                                              (select 1
                                                                 from Schema_GPSys.CONFSYSTEM g
                                                                where g.FLDSECTION = 'EXPOSITION' and
                                                                      g.FLDITEM = 'CASHTOTSUM_DT_GROUP' || recGroup.SGROUP and
                                                                      g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                                                      g.FLDVALUE like '%&' || rCustData.CliType || to_char( e.TYPE_EXPO ) || e.CODVAL || '&%')) and
                                       a.VALIOR = ValiorDt and
                                       a.DT_KT = 'D' and
                                       ( sCashRequest = 'F' or
                                        not exists
                                          (select 1
                                             from CASH_REQUEST e
                                            where e.ID_MOVE = a.ID_MOVE and
                                                  e.STATUS = Cash.CashDoc_Confirmed and
                                                  a.ORDROWNUM = 1) ) and
                                       not exists
                                         (select 1
                                            from CASH_BIG_OPERS x
                                           where x.ID_MOVE = a.ID_MOVE and
                                                 x.ORIGIN in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins)) and
                                       a.ID_MOVE = b.ID_MOVE and
                                       a.ORDROWNUM = b.ORDROWNUM and
                                       a.DT_KT != b.DT_KT and
                                       b.ID_EXPO = c.ID_EXPO and
                                       c.TYPE_EXPO = d.TYPE_EXPO and
                                       d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;
                              end if;

                              exit when ii > 0;
                            end loop;
                          else
                            select nvl( sum( a.AMOUNT ), 0 )
                              into nDaySum
                              from Schema_GPSys.EXPOTYPES d,
                                   Schema_GPSys.EXPOSITION c,
                                   EXPO_MOVES b,
                                   EXPO_MOVES a
                             where a.ID_EXPO = nExpoDt and
                                   a.VALIOR = ValiorDt and
                                   a.DT_KT = 'D' and
                                   ( sCashRequest = 'F' or
                                    not exists
                                      (select 1
                                         from CASH_REQUEST e
                                        where e.ID_MOVE = a.ID_MOVE and
                                              e.STATUS = Cash.CashDoc_Confirmed and
                                              a.ORDROWNUM = 1) ) and
                                   not exists
                                     (select 1
                                        from CASH_BIG_OPERS x
                                       where x.ID_MOVE = a.ID_MOVE and
                                             x.ORIGIN in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins)) and
                                   a.ID_MOVE = b.ID_MOVE and
                                   a.ORDROWNUM = b.ORDROWNUM and
                                   a.DT_KT != b.DT_KT and
                                   b.ID_EXPO = c.ID_EXPO and
                                   c.TYPE_EXPO = d.TYPE_EXPO and
                                   d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;
                          end if;
                        end if;
                      end if;
                    else
                      nTaxedSum  := nAmountDt;
                    end if;

                    sCodValTax  := RecExpoDt.CODVAL;
                  else
                    nTaxedSum   := nAmountKt;
                    sCodValTax  := RecExpoKt.CODVAL;
                  end if;

                  nDaySum       := greatest( nvl( nDaySum, 0 ), 0 );
                  nTaxedSum     := greatest( nvl( nTaxedSum, 0 ), 0 );
                  bDummy        := ( nTaxedSum + nDaySum ) > 0 and
                                   GetOperTaxSum( sTaxKeyDt1, sCodValTax, ValiorDt, nTaxedSum + nDaySum, nUniqCode, sTaxValDt, nTaxSumDt, null, sTaxKeyDt2, RecExpoDt.ID_CUST, RecExpoDt.ID_EXPO );

                  if ( bDummy ) then
                    rTarifaDt           := Taxes.rTarifa;
                    Taxes.rTarifa       := null;

                    if ( nDaySum > 0 ) then
                      bDummy  := GetOperTaxSum( sTaxKeyDt1, sCodValTax, ValiorDt, nDaySum, nUniqCode, cValDummy, nTemp, null, sTaxKeyDt2, RecExpoDt.ID_CUST, RecExpoDt.ID_EXPO );

                      if ( bDummy ) then
                        nTaxSumDt  := nTaxSumDt - nTemp;
                      end if;
                    end if;

                    rTaxRegDt.UNIQCODE  := nUniqCode;
                    rTaxRegDt.ID_CUST   := RecExpoDt.ID_CUST;
                    rTaxRegDt.EXT_CODE  := rTarifaDt.sExtCode;
                    rTaxRegDt.INT_CODE  := rTarifaDt.sIntCode;
                    rTaxRegDt.TAXVAL    := sTaxValDt;
                    rTaxRegDt.TAXSUM    := nTaxSumDt;
                    rTaxRegDt.TRFSUM    := rTarifaDt.nTrfSum - nvl( Taxes.rTarifa.nTrfSum, 0 );
                    rTaxRegDt.AMOUNT    := rTarifaDt.nAmount;
                    rTaxRegDt.CODVAL    := rTarifaDt.sCodVal;
                  end if;
                end if;
              end if;

              if ( nvl( nTaxSumDt, 0 ) > 0 and
                  DealType = Sch_CloseExpo ) then
                nTaxDt  := Schema_GPSys.XchgRates.GetExactSum( nTaxSumDt, nUniqCode, ValiorDt, sTaxValDt, RecExpoDt.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );

                if ( nAmountDt > nTaxDt ) then
                  nAmountDt  := nAmountDt - nTaxDt;
                  --
                  nTemp      := Schema_GPSys.XchgRates.GetExactSum( nTaxSumDt, nUniqCode, ValiorDt, sTaxValDt, RecExpoKt.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                  nAmountKt  := nAmountKt - nTemp;
                else
                  nTaxSumDt  := 0;
                end if;
              end if;

              if ( nvl( cUseTaxes, 'T' ) in ('T', 'K', 'I') and
                  RecExpoKt.ID_CUST > 0 and
                  ( Expo.GetSkipLimit( EXPO.ModeSkip_CustInConfig ) or
                   not Schema_RA.GPC_Tools.IsIdCustInConfig( RecExpoKt.ID_CUST ) ) and
                  nAmountKt > 0 ) then
                rCustData.IDCust  := RecExpoKt.ID_CUST;

                if ( Schema_Cust.GPC_Customs.GetCustData( rCustData, true ) ) then
                  sTaxKeyKt1    := 'OPERKT_';
                  sCashRequest  := 'F';
                  bCashExpo     := Schema_GPSys.HeadExpo.IsItCashExpo( nExpoDt );

                  if ( bCashReq ) then -- v Tokuda niamalo kasovi zaiavki za vnoski na kasa
                    sTaxKeyKt1  := sTaxKeyKt1 || 'REQ_' || GetAddTaxKey( 1 );
                  elsif ( ( Schema_GPSys.OraSys.VerBankTokuda or
                           Schema_GPSys.OraSys.VerBankDBank ) and
                         bCashExpo ) then
                    select /*+ LEADING( a b c d e ) USE_NL( b c d e )*/
                          count( 1 )
                      into nDummy
                      from CASH_REQUEST e,
                           Schema_GPSys.EXPOTYPES d,
                           Schema_GPSys.EXPOSITION c,
                           EXPO_MOVES b,
                           EXPO_MOVES a
                     where a.ID_EXPO = nExpoKt and
                           a.VALIOR = ValiorKt and
                           a.DT_KT = 'K' and
                           a.ID_MOVE = b.ID_MOVE and
                           a.ORDROWNUM = b.ORDROWNUM and
                           a.DT_KT != b.DT_KT and
                           b.ID_EXPO = c.ID_EXPO and
                           c.TYPE_EXPO = d.TYPE_EXPO and
                           d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash and
                           e.ID_MOVE = a.ID_MOVE and
                           e.ID_EXPO = nExpoKt;

                    if ( nDummy > 0 ) then
                      sTaxKeyKt1  := sTaxKeyKt1 || 'REQ_ADD_';

                      if ( not Schema_GPSys.OraSys.VerBankTokuda ) then
                        sCashRequest  := 'T';
                      end if;
                    end if;
                  end if;

                  if ( nvl( Expo.rMemoOrderAdd.nModeOrigin, Expo.ModeCashBigOpers ) in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins) ) then
                    sTaxKeyKt1  := sTaxKeyKt1 || 'ORG' || to_char( Expo.rMemoOrderAdd.nModeOrigin ) || '_';
                  end if;

                  sTaxKeyKt2    := sTaxKeyKt1 || rCustData.CliType || '_' || to_char( RecExpoKt.TYPE_EXPO ) || '_' || to_char( RecExpoDt.TYPE_EXPO );
                  sTaxKeyKt1    := sTaxKeyKt1 || rCustData.FType || '_' || to_char( RecExpoKt.TYPE_EXPO ) || '_' || to_char( RecExpoDt.TYPE_EXPO );
                  --
                  nTaxedSum     := 0;
                  nDaySum       := 0;

                  if ( Schema_GPSys.OraSys.VerBankTokuda and
                      bCashExpo ) then
                    if ( bCashReq ) then
                      select nvl( sum( AMOUNT_DT ), 0 )
                        into nTaxedSum
                        from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                       where a.EXPO_DT = nExpoDt and
                             a.EXPO_KT = nExpoKt and
                             a.DEAL_TYPE not in (Sch_FreeTaxes) and
                             nvl( a.USE_TAXES, 'F' ) in ('T', 'I');
                    else
                      select nvl( sum( AMOUNT_DT ), 0 )
                        into nTaxedSum
                        from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                       where a.EXPO_DT = nExpoDt and
                             a.EXPO_KT = nExpoKt and
                             a.DEAL_TYPE not in (Sch_FreeTaxes);
                    end if;

                    if ( nvl( Expo.rMemoOrderAdd.nModeOrigin, Expo.ModeCashBigOpers ) not in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins) ) then
                      select nvl( sum( a.SYS_AMOUNT ), 0 )
                        into nDaySum
                        from EXPO_MOVES a,
                             EXPO_MOVES b,
                             Schema_GPSys.EXPOSITION c,
                             Schema_GPSys.EXPOTYPES d
                       where a.ID_EXPO = nExpoKt and
                             a.VALIOR = ValiorKt and
                             a.DT_KT = 'K' and
                             ( sCashRequest = 'F' or
                              not exists
                                (select 1
                                   from CASH_REQUEST e
                                  where e.ID_MOVE = a.ID_MOVE and
                                        e.STATUS = Cash.CashDoc_Confirmed and
                                        a.ORDROWNUM = 1) ) and
                             not exists
                               (select 1
                                  from CASH_BIG_OPERS x
                                 where x.ID_MOVE = a.ID_MOVE and
                                       x.ORIGIN in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins)) and
                             a.ID_MOVE = b.ID_MOVE and
                             a.ORDROWNUM = b.ORDROWNUM and
                             a.DT_KT != b.DT_KT and
                             b.ID_EXPO = c.ID_EXPO and
                             c.TYPE_EXPO = d.TYPE_EXPO and
                             d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;

                      nDaySum  := Schema_GPSys.XchgRates.GetExactSum( nDaySum, nUniqCode, ValiorKt, Schema_GPSys.OraGPSys.SYS_CURR, RecExpoDt.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                    end if;

                    sCodValTax  := RecExpoDt.CODVAL;
                  elsif ( RecExpoDt.CODVAL = RecExpoKt.CODVAL ) then
                    if ( bCashExpo ) then
                      if ( bCashReq ) then
                        select nvl( sum( AMOUNT_KT ), 0 )
                          into nTaxedSum
                          from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                         where a.EXPO_DT = nExpoDt and
                               a.EXPO_KT = nExpoKt and
                               a.DEAL_TYPE not in (Sch_FreeTaxes) and
                               nvl( a.USE_TAXES, 'F' ) in ('T', 'I');
                      else
                        select nvl( sum( AMOUNT_KT ), 0 )
                          into nTaxedSum
                          from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                         where a.EXPO_DT = nExpoDt and
                               a.EXPO_KT = nExpoKt and
                               a.DEAL_TYPE not in (Sch_FreeTaxes);
                      end if;

                      nModePrivilege  := Taxes.GetModePrivilege( nExpoKt, ValiorKt, dBegDate );

                      if ( nModePrivilege in (Taxes.ModeTaxPrivilege1, Taxes.ModeTaxPrivilege2, Taxes.ModeTaxPrivilege3, Taxes.ModeTaxPrivilege4, Taxes.ModeTaxPrivilege5, Taxes.ModeTaxPrivilege8) ) then
                        select nvl( sum( a.AMOUNT ), 0 )
                          into nDaySum
                          from EXPO_MOVES a,
                               EXPO_MOVES b,
                               Schema_GPSys.EXPOSITION c,
                               Schema_GPSys.EXPOTYPES d
                         where a.ID_EXPO = nExpoKt and
                               a.VALIOR = ValiorKt and
                               a.DT_KT = 'K' and
                               a.ID_MOVE = b.ID_MOVE and
                               a.ORDROWNUM = b.ORDROWNUM and
                               a.DT_KT != b.DT_KT and
                               b.ID_EXPO = c.ID_EXPO and
                               c.TYPE_EXPO = d.TYPE_EXPO and
                               d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;

                        if ( nModePrivilege = Taxes.ModeTaxPrivilege1 ) then
                          sTaxKeyKt1  := 'PRIV1' || sTaxKeyKt1;
                          sTaxKeyKt2  := 'PRIV1' || sTaxKeyKt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege2 ) then
                          sTaxKeyKt1  := 'PRIV2' || sTaxKeyKt1;
                          sTaxKeyKt2  := 'PRIV2' || sTaxKeyKt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege3 ) then
                          sTaxKeyKt1  := 'PRIV3' || sTaxKeyKt1;
                          sTaxKeyKt2  := 'PRIV3' || sTaxKeyKt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege4 ) then
                          sTaxKeyKt1  := 'PRIV4' || sTaxKeyKt1;
                          sTaxKeyKt2  := 'PRIV4' || sTaxKeyKt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege5 ) then
                          sTaxKeyKt1  := 'PRIV5' || sTaxKeyKt1;
                          sTaxKeyKt2  := 'PRIV5' || sTaxKeyKt2;
                        elsif ( nModePrivilege = Taxes.ModeTaxPrivilege8 ) then
                          sTaxKeyKt1  := 'PRIV8' || sTaxKeyKt1;
                          sTaxKeyKt2  := 'PRIV8' || sTaxKeyKt2;
                        end if;
                      else
                        nModePrivilege  := Taxes.GetModePrivilege( nExpoKt, ValiorKt, dBegDate, true );

                        if ( nModePrivilege in (Taxes.ModeTaxPrivilege10) ) then
                          select nvl( sum( a.AMOUNT ), 0 )
                            into nDaySum
                            from EXPO_MOVES a,
                                 EXPO_MOVES b,
                                 Schema_GPSys.EXPOSITION c,
                                 Schema_GPSys.EXPOTYPES d
                           where a.ID_EXPO = nExpoKt and
                                 a.VALIOR = ValiorKt and
                                 a.DT_KT = 'K' and
                                 a.ID_MOVE = b.ID_MOVE and
                                 a.ORDROWNUM = b.ORDROWNUM and
                                 a.DT_KT != b.DT_KT and
                                 b.ID_EXPO = c.ID_EXPO and
                                 c.TYPE_EXPO = d.TYPE_EXPO and
                                 d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;

                          if ( nModePrivilege = Taxes.ModeTaxPrivilege10 ) then
                            sTaxKeyKt1  := 'PRIV10' || sTaxKeyKt1;
                            sTaxKeyKt2  := 'PRIV10' || sTaxKeyKt2;
                          end if;
                        elsif ( nvl( Expo.rMemoOrderAdd.nModeOrigin, Expo.ModeCashBigOpers ) not in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins) ) then
                          if ( bCashReq and
                              false /*Schema_GPSys.OraSys.VerBankTokuda*/
                                    ) then
                            select /*+ LEADING( a b c d e ) USE_NL( b c d e )*/
                                  nvl( sum( a.AMOUNT ), 0 )
                              into nDaySum
                              from CASH_REQUEST e,
                                   Schema_GPSys.EXPOTYPES d,
                                   Schema_GPSys.EXPOSITION c,
                                   EXPO_MOVES b,
                                   EXPO_MOVES a
                             where a.ID_EXPO = nExpoKt and
                                   a.VALIOR = ValiorKt and
                                   a.DT_KT = 'K' and
                                   a.ID_MOVE = b.ID_MOVE and
                                   a.ORDROWNUM = b.ORDROWNUM and
                                   a.DT_KT != b.DT_KT and
                                   b.ID_EXPO = c.ID_EXPO and
                                   c.TYPE_EXPO = d.TYPE_EXPO and
                                   d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash and
                                   e.ID_MOVE = a.ID_MOVE and
                                   e.ID_EXPO = nExpoKt and
                                   e.STATUS = Cash.CashDoc_Confirmed;
                          else
                            select count( 1 )
                              into ii
                              from Schema_GPSys.CONFSYSTEM g
                             where g.FLDSECTION = 'EXPOSITION' and
                                   g.FLDITEM = 'CASHNOTSUM_KT_GROUP' and
                                   g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                   g.FLDVALUE like '%&' || rCustData.CliType || to_char( RecExpoKt.TYPE_EXPO ) || RecExpoKt.CODVAL || '&%';

                            if ( ii = 0 and
                                ( Schema_GPSys.OraSys.VerBankUnion or
                                 Schema_GPSys.OraSys.VerBankDBank or
                                 Schema_GPSys.OraSys.VerBankSAS or
                                 Schema_GPSys.OraSys.VerBankTokuda ) ) then
                              for recGroup in (  select *
                                                   from (select '1' as SGROUP
                                                           from dual
                                                         union all
                                                         select '2' as SGROUP
                                                           from dual
                                                         union all
                                                         select '3' as SGROUP
                                                           from dual)
                                               order by 1 ) loop
                                select count( 1 )
                                  into ii
                                  from Schema_GPSys.CONFSYSTEM g
                                 where g.FLDSECTION = 'EXPOSITION' and
                                       g.FLDITEM = 'CASHTOTSUM_KT_GROUP' || recGroup.SGROUP and
                                       g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                       g.FLDVALUE like '%&' || rCustData.CliType || to_char( RecExpoKt.TYPE_EXPO ) || RecExpoKt.CODVAL || '&%';

                                if ( ii > 0 ) then
                                  select nvl( sum( a.AMOUNT ), 0 )
                                    into nDaySum
                                    from Schema_GPSys.EXPOTYPES d,
                                         Schema_GPSys.EXPOSITION c,
                                         EXPO_MOVES b,
                                         EXPO_MOVES a
                                   where a.ID_EXPO in (select e.ID_EXPO
                                                         from Schema_GPSys.EXPOSITION e
                                                        where e.ID_CUST = RecExpoKt.ID_CUST and
                                                              e.CODVAL = RecExpoKt.CODVAL and
                                                              exists
                                                                (select 1
                                                                   from Schema_GPSys.CONFSYSTEM g
                                                                  where g.FLDSECTION = 'EXPOSITION' and
                                                                        g.FLDITEM = 'CASHTOTSUM_KT_GROUP' || recGroup.SGROUP and
                                                                        g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                                                        g.FLDVALUE like '%&' || rCustData.CliType || to_char( e.TYPE_EXPO ) || e.CODVAL || '&%')) and
                                         a.VALIOR = ValiorKt and
                                         a.DT_KT = 'K' and
                                         ( sCashRequest = 'F' or
                                          not exists
                                            (select 1
                                               from CASH_REQUEST e
                                              where e.ID_MOVE = a.ID_MOVE and
                                                    e.STATUS = Cash.CashDoc_Confirmed and
                                                    a.ORDROWNUM = 1) ) and
                                         not exists
                                           (select 1
                                              from CASH_BIG_OPERS x
                                             where x.ID_MOVE = a.ID_MOVE and
                                                   x.ORIGIN in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins)) and
                                         a.ID_MOVE = b.ID_MOVE and
                                         a.ORDROWNUM = b.ORDROWNUM and
                                         a.DT_KT != b.DT_KT and
                                         b.ID_EXPO = c.ID_EXPO and
                                         c.TYPE_EXPO = d.TYPE_EXPO and
                                         d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;
                                end if;

                                exit when ii > 0;
                              end loop;
                            else
                              select nvl( sum( a.AMOUNT ), 0 )
                                into nDaySum
                                from EXPO_MOVES a,
                                     EXPO_MOVES b,
                                     Schema_GPSys.EXPOSITION c,
                                     Schema_GPSys.EXPOTYPES d
                               where a.ID_EXPO = nExpoKt and
                                     a.VALIOR = ValiorKt and
                                     a.DT_KT = 'K' and
                                     ( sCashRequest = 'F' or
                                      not exists
                                        (select 1
                                           from CASH_REQUEST e
                                          where e.ID_MOVE = a.ID_MOVE and
                                                e.STATUS = Cash.CashDoc_Confirmed and
                                                a.ORDROWNUM = 1) ) and
                                     not exists
                                       (select 1
                                          from CASH_BIG_OPERS x
                                         where x.ID_MOVE = a.ID_MOVE and
                                               x.ORIGIN in (Expo.ModeCashOtherClient, Expo.ModeCashExternalClient, Expo.ModeCashCoins)) and
                                     a.ID_MOVE = b.ID_MOVE and
                                     a.ORDROWNUM = b.ORDROWNUM and
                                     a.DT_KT != b.DT_KT and
                                     b.ID_EXPO = c.ID_EXPO and
                                     c.TYPE_EXPO = d.TYPE_EXPO and
                                     d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;
                            end if;
                          end if;
                        end if;
                      end if;
                    else
                      nTaxedSum  := nAmountKt;
                    end if;

                    sCodValTax  := RecExpoKt.CODVAL;
                  else
                    nTaxedSum   := nAmountDt;
                    sCodValTax  := RecExpoDt.CODVAL;
                  end if;

                  nDaySum       := greatest( nvl( nDaySum, 0 ), 0 );
                  nTaxedSum     := greatest( nvl( nTaxedSum, 0 ), 0 );
                  bDummy        := ( nTaxedSum + nDaySum ) > 0 and
                                   GetOperTaxSum( sTaxKeyKt1, sCodValTax, ValiorKt, nTaxedSum + nDaySum, nUniqCode, sTaxValKt, nTaxSumKt, null, sTaxKeyKt2, RecExpoKt.ID_CUST, RecExpoKt.ID_EXPO );

                  if ( bDummy ) then
                    rTarifaKt           := Taxes.rTarifa;
                    Taxes.rTarifa       := null;

                    if ( nDaySum > 0 ) then
                      bDummy  := GetOperTaxSum( sTaxKeyKt1, sCodValTax, ValiorKt, nDaySum, nUniqCode, cValDummy, nTemp, null, sTaxKeyKt2, RecExpoKt.ID_CUST, RecExpoKt.ID_EXPO );

                      if ( bDummy ) then
                        nTaxSumKt  := nTaxSumKt - nTemp;
                      end if;
                    end if;

                    rTaxRegKt.UNIQCODE  := nUniqCode;
                    rTaxRegKt.ID_CUST   := RecExpoKt.ID_CUST;
                    rTaxRegKt.EXT_CODE  := rTarifaKt.sExtCode;
                    rTaxRegKt.INT_CODE  := rTarifaKt.sIntCode;
                    rTaxRegKt.TAXVAL    := sTaxValKt;
                    rTaxRegKt.TAXSUM    := nTaxSumKt;
                    rTaxRegKt.TRFSUM    := rTarifaKt.nTrfSum - nvl( Taxes.rTarifa.nTrfSum, 0 );
                    rTaxRegKt.AMOUNT    := rTarifaKt.nAmount;
                    rTaxRegKt.CODVAL    := rTarifaKt.sCodVal;
                  end if;
                end if;
              end if;
            end if;

            if ( nvl( cUseTaxes, 'T' ) in ('O') and
                RecTypeDt.IN_BALANCE = 'T' and
                nAmountDt > 0 ) then
              sTaxKeyKt1  := 'OPER_' || to_char( DealType );
              sTaxKeyKt2  := sTaxKeyKt1;
              --
              nTaxedSum   := nAmountDt;
              sCodValTax  := RecExpoDt.CODVAL;
              --
              bDummy      := GetOperTaxSum( sTaxKeyKt1, sCodValTax, ValiorKt, nTaxedSum, nUniqCode, sTaxValKt, nTaxSumKt, null, sTaxKeyKt2, nIDCust );

              if ( bDummy ) then
                rTarifaKt           := Taxes.rTarifa;
                --
                rTaxRegKt.UNIQCODE  := nUniqCode;
                rTaxRegKt.ID_CUST   := nIDCust;
                rTaxRegKt.EXT_CODE  := rTarifaKt.sExtCode;
                rTaxRegKt.INT_CODE  := rTarifaKt.sIntCode;
                rTaxRegKt.TAXVAL    := sTaxValKt;
                rTaxRegKt.TAXSUM    := nTaxSumKt;
                rTaxRegKt.TRFSUM    := rTarifaKt.nTrfSum;
                rTaxRegKt.AMOUNT    := rTarifaKt.nAmount;
                rTaxRegKt.CODVAL    := rTarifaKt.sCodVal;
              end if;
            end if;

            if ( RecTypeDt.IN_BALANCE = 'F' or
                ValiorDt = ValiorKt ) then
              RealDt  := nExpoDt;
              bRet    := true;
            else
              bRet      := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'ValiorDiffer', RecExpoDt.CODVAL, null, null, null, null, RealDt, sCValCR ) and
                           sCValCR = RecExpoDt.CODVAL;

              if ( bRet ) then
                if ( RecExpoDt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                  nSysAmountDt  := nAmountDt;
                else
                  nSysAmountDt  := Schema_GPSys.XchgRates.GetExactSum( nAmountDt, nUniqCode, ValiorDt, RecExpoDt.CODVAL, Schema_GPSys.OraGPSys.SYS_CURR, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                end if;

                oOper                  := Schema_GPSys.TSchOper( DealType, nExpoDt, RecExpoDt.CODVAL, nAmountDt, nAmountDt, RecExpoDt.CODVAL, RealDt, ValiorDt, nSysAmountDt, dSchDate, null, null );
                oOpers.extend;
                oOpers( oOpers.last )  := oOper;
              else
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'CURRENCY';
                aParams( 1 ).ML_VALUE  := RecExpoDt.CODVAL;
                sError                 := Schema_GPSys.MLng.Str2( 'Липсва експозиция за разлика от вальори във валута $CURRENCY$',
                                                                  Schema_GPSys.MLng.ctxAccounting,
                                                                  Schema_GPSys.MLng.lngBG,
                                                                  aParams
                                                                 );
              end if;
            end if;

            if ( bRet and
                DealType = Sch_CloseExpo and
                RecExpoKt.CODVAL != Schema_GPSys.OraGPSys.SYS_CURR and
                Schema_GPSys.HeadExpo.IsItCashExpo( nExpoKt ) ) then
              nTemp  := mod( nAmountKt, Schema_GPSys.OraGPSys.GetMinCopure( RecExpoKt.CODVAL ) );

              if ( nTemp > 0 ) then
                select nvl( min( b.ID_EXPO ), 0 )
                  into nIDExpoCash
                  from Schema_GPSys.EXPO_CONF b
                 where b.FLDMODE = 'Cash' and
                       b.PARAM1 in (select a.PARAM1
                                      from Schema_GPSys.EXPO_CONF a
                                     where a.ID_EXPO = nExpoKt and
                                           a.FLDMODE = 'Cash') and
                       b.UNIQCODE = RecExpoKt.UNIQCODE and
                       b.PARAM2 = Schema_GPSys.OraGPSys.SYS_CURR;

                if ( nIDExpoCash > 0 ) then
                  nAmountKt              := nAmountKt - nTemp;
                  nTemp                  := Schema_GPSys.XchgRates.GetExactSum( nTemp, nUniqCode, ValiorDt, RecExpoKt.CODVAL, RecExpoDt.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                  nAmountDt              := nAmountDt - nTemp;
                  --
                  ValExpoCash            := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoCash );
                  oOper                  := Schema_GPSys.TSchOper( DealType,
                                                                   RealDt,
                                                                   RecExpoDt.CODVAL,
                                                                   nTemp,
                                                                   Schema_GPSys.XchgRates.GetExactSum( nTemp, nUniqCode, ValiorDt, RecExpoDt.CODVAL, ValExpoCash, Schema_GPSys.XchgRates.XchgRateType_Fixing ),
                                                                   ValExpoCash,
                                                                   nIDExpoCash,
                                                                   ValiorDt,
                                                                   Schema_GPSys.XchgRates.GetExactSum( nTemp,
                                                                                                       nUniqCode,
                                                                                                       ValiorDt,
                                                                                                       RecExpoDt.CODVAL,
                                                                                                       Schema_GPSys.OraGPSys.SYS_CURR,
                                                                                                       Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                      ),
                                                                   dSchDate,
                                                                   null,
                                                                   null
                                                                  );
                  oOpers.extend;
                  oOpers( oOpers.last )  := oOper;
                end if;
              end if;
            end if;

            if ( bRet ) then
              if ( DealType = Sch_Preocenka ) then
                if ( RecExpoDt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                  nSysAmountDt  := nAmountDt;
                  nSysAmountKt  := nAmountDt;
                else
                  nSysAmountDt  := nAmountKt;
                  nSysAmountKt  := nAmountKt;
                end if;
              else
                if ( RecTypeDt.IN_BALANCE = 'F' or
                    DealType in (Sch_EndSaldo, Sch_ClearOborot) or
                    bNoRateDiffer or
                    ( NoRateDiffer4Cash and
                     ( Schema_GPSys.HeadExpo.IsItCashExpo( nExpoDt ) or
                      Schema_GPSys.HeadExpo.IsItCashExpo( nExpoKt ) ) ) ) then
                  if ( RecExpoDt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                    nSysAmountDt  := nAmountDt;
                    nSysAmountKt  := nAmountDt;
                  elsif ( RecExpoKt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                    nSysAmountDt  := nAmountKt;
                    nSysAmountKt  := nAmountKt;
                  elsif ( nAmountSys != 0 ) then
                    nSysAmountDt  := nAmountSys;
                    nSysAmountKt  := nAmountSys;
                  else
                    if ( bUseKTAmount ) then
                      nSysAmountDt      := Schema_GPSys.XchgRates.GetExactSum( nAmountKt,
                                                                               nUniqCode,
                                                                               ValiorKt,
                                                                               RecExpoKt.CODVAL,
                                                                               Schema_GPSys.OraGPSys.SYS_CURR,
                                                                               Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                              );
                    else
                      nSysAmountDt      := Schema_GPSys.XchgRates.GetExactSum( nAmountDt,
                                                                               nUniqCode,
                                                                               ValiorKt,
                                                                               RecExpoDt.CODVAL,
                                                                               Schema_GPSys.OraGPSys.SYS_CURR,
                                                                               Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                              );
                    end if;

                    nSysAmountKt  := nSysAmountDt;
                  end if;
                else
                  if ( RecExpoDt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                    nSysAmountDt  := nAmountDt;
                  else
                    nSysAmountDt  := Schema_GPSys.XchgRates.GetExactSum( nAmountDt, nUniqCode, ValiorKt, RecExpoDt.CODVAL, Schema_GPSys.OraGPSys.SYS_CURR, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                  end if;

                  if ( RecExpoKt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                    nSysAmountKt  := nAmountKt;
                  else
                    nSysAmountKt  := Schema_GPSys.XchgRates.GetExactSum( nAmountKt, nUniqCode, ValiorKt, RecExpoKt.CODVAL, Schema_GPSys.OraGPSys.SYS_CURR, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                  end if;
                end if;
              end if;

              bRet  := ( nSysAmountDt * nSysAmountKt ) > 0;

              if ( bRet ) then
                nSysDiff  := nSysAmountDt - nSysAmountKt;
                nBdgDiff  := 0;
                nScale    := Schema_GPSys.OraGPSys.GetCurrencyScale( Schema_GPSys.OraGPSys.SYS_CURR );
                nScale    := power( 10, nScale );
                nScale    := Schema_GPSys.OraGPSys.nTruncSet( nScale );

                if ( abs( nSysDiff ) <= nScale ) then
                  nSysDiff  := 0;

                  if ( RecExpoKt.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                    nSysAmountDt  := nAmountKt;
                  end if;
                end if;

                if ( nSysDiff = 0 ) then
                  oOper                  := Schema_GPSys.TSchOper( DealType, RealDt, RecExpoDt.CODVAL, nAmountDt, nAmountKt, RecExpoKt.CODVAL, nExpoKt, ValiorKt, nSysAmountDt, dSchDate, null, null );
                  oOpers.extend;
                  oOpers( oOpers.last )  := oOper;
                elsif ( nSysDiff > 0 ) then
                  bRet      := ( Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode,
                                                                  'RateDifferOpers',
                                                                  Schema_GPSys.OraGPSys.SYS_CURR,
                                                                  'Prihod',
                                                                  sType,
                                                                  nvl( GetRateDifferType( 2 ), to_char( DealType ) ),
                                                                  sSubType,
                                                                  nExpoCR,
                                                                  sCValCR
                                                                 ) or
                                Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode,
                                                                 'RateDifferOpers',
                                                                 Schema_GPSys.OraGPSys.SYS_CURR,
                                                                 'Prihod',
                                                                 RecExpoDt.EXPO_CODE || '_' || substr( RecExpoDt.AN_FEAT, 1, 1 ),
                                                                 RecExpoDt.CODVAL,
                                                                 RecExpoDt.SYNT_CODE,
                                                                 nExpoCR,
                                                                 sCValCR
                                                                ) ) and
                               sCValCR = Schema_GPSys.OraGPSys.SYS_CURR;

                  if ( bRet ) then
                    if ( RecExpoDt.CODVAL = sCValCR ) then
                      nValDiff  := nSysDiff;
                      nBdgDiff  := -nSysDiff;
                    else
                      nValDiff  := Schema_GPSys.XchgRates.GetExactSum( nSysDiff, nUniqCode, ValiorKt, Schema_GPSys.OraGPSys.SYS_CURR, RecExpoDt.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                    end if;

                    oOper                  := Schema_GPSys.TSchOper( DealType, RealDt, RecExpoDt.CODVAL, nAmountDt - nValDiff, nAmountKt, RecExpoKt.CODVAL, nExpoKt, ValiorKt, nSysAmountKt, dSchDate, null, null );
                    oOpers.extend;
                    oOpers( oOpers.last )  := oOper;
                    --
                    oOper                  := Schema_GPSys.TSchOper( Sch_RateDiffer, RealDt, RecExpoDt.CODVAL, nValDiff, nSysDiff, sCValCR, nExpoCR, ValiorKt, nSysDiff, dSchDate, null, null );
                    oOpers.extend;
                    oOpers( oOpers.last )  := oOper;
                  --
                  else
                    sError      := Schema_GPSys.MLng.Str2( 'Липсва експозиция за приходи от курсови разлики',
                                                           Schema_GPSys.MLng.ctxAccounting,
                                                           Schema_GPSys.MLng.lngBG
                                                          );
                  end if;
                else
                  bRet      := ( Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode,
                                                                  'RateDifferOpers',
                                                                  Schema_GPSys.OraGPSys.SYS_CURR,
                                                                  'Razhod',
                                                                  sType,
                                                                  nvl( GetRateDifferType( 2 ), to_char( DealType ) ),
                                                                  sSubType,
                                                                  nExpoCR,
                                                                  sCValCR
                                                                 ) or
                                Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode,
                                                                 'RateDifferOpers',
                                                                 Schema_GPSys.OraGPSys.SYS_CURR,
                                                                 'Razhod',
                                                                 RecExpoKt.EXPO_CODE || '_' || substr( RecExpoKt.AN_FEAT, 1, 1 ),
                                                                 RecExpoKt.CODVAL,
                                                                 RecExpoKt.SYNT_CODE,
                                                                 nExpoCR,
                                                                 sCValCR
                                                                ) ) and
                               sCValCR = Schema_GPSys.OraGPSys.SYS_CURR;

                  if ( bRet ) then
                    if ( RecExpoKt.CODVAL = sCValCR ) then
                      nValDiff  := -nSysDiff;
                      nBdgDiff  := nSysDiff;
                    else
                      nValDiff  := Schema_GPSys.XchgRates.GetExactSum( -nSysDiff, nUniqCode, ValiorKt, Schema_GPSys.OraGPSys.SYS_CURR, RecExpoKt.CODVAL, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                    end if;

                    oOper                  := Schema_GPSys.TSchOper( DealType, RealDt, RecExpoDt.CODVAL, nAmountDt, nAmountKt - nValDiff, RecExpoKt.CODVAL, nExpoKt, ValiorKt, nSysAmountDt, dSchDate, null, null );
                    oOpers.extend;
                    oOpers( oOpers.last )  := oOper;
                    --
                    oOper                  := Schema_GPSys.TSchOper( Sch_RateDiffer, nExpoCR, sCValCR, -nSysDiff, nValDiff, RecExpoKt.CODVAL, nExpoKt, ValiorKt, -nSysDiff, dSchDate, null, null );
                    oOpers.extend;
                    oOpers( oOpers.last )  := oOper;
                  --
                  else
                    sError      := Schema_GPSys.MLng.Str2( 'Липсва експозиция за разходи от курсови разлики',
                                                           Schema_GPSys.MLng.ctxAccounting,
                                                           Schema_GPSys.MLng.lngBG
                                                          );
                  end if;
                end if;

                if ( nSysDiff != 0 ) then
                  rBDGData.BDG_CLASSIF  := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_CLASSIF_CR', null );

                  if ( rBDGData.BDG_CLASSIF is not null ) then
                    rBDGData.BDG_FUNCTION       := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_FUNCTION_CR', null );
                    rBDGData.BDG_OBJECT         := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_OBJECT_CR', null );
                    rBDGData.DT_KT              := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_DT_KT_CR', 'K' );

                    if ( bExistBudget and
                        nBdgDiff != 0 ) then
                      BdgRows( nCurrDeal ).AMOUNT      := BdgRows( nCurrDeal ).AMOUNT +
                                                          Schema_GPSys.XchgRates.GetExactSum( nBdgDiff,
                                                                                              nUniqCode,
                                                                                              BdgRows( nCurrDeal ).VALIOR,
                                                                                              Schema_GPSys.OraGPSys.SYS_CURR,
                                                                                              BdgRows( nCurrDeal ).CODVAL,
                                                                                              Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                             );
                      BdgRows( nCurrDeal ).SYS_AMOUNT  := BdgRows( nCurrDeal ).SYS_AMOUNT + nBdgDiff;
                    end if;

                    ii                          := BdgRows.count + 1;
                    BdgRows( ii ).BDG_CLASSIF   := rBDGData.BDG_CLASSIF;
                    BdgRows( ii ).BDG_FUNCTION  := rBDGData.BDG_FUNCTION;
                    BdgRows( ii ).BDG_OBJECT    := rBDGData.BDG_OBJECT;
                    BdgRows( ii ).DT_KT         := rBDGData.DT_KT;
                    BdgRows( ii ).CODVAL        := Schema_GPSys.OraGPSys.SYS_CURR;
                    BdgRows( ii ).AMOUNT        := nSysDiff;
                    BdgRows( ii ).SYS_AMOUNT    := nSysDiff;
                    BdgRows( ii ).VALIOR        := ValiorKt;
                    BdgRows( ii ).ORDROWNUM     := oOpers.last;
                  end if;
                end if;
              else
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'EXPO_DT';
                aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoDt );
                aParams( 2 ).ML_NAME   := 'SYS_AMOUNT_DT';
                aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSysAmountDt );
                aParams( 3 ).ML_NAME   := 'EXPO_KT';
                aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoKt );
                aParams( 4 ).ML_NAME   := 'SYS_AMOUNT_KT';
                aParams( 4 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nSysAmountKt );
                sError                 := Schema_GPSys.MLng.Str2( 'Некоректна равностойност в системна валута Dt: $EXPO_DT$ ($SYS_AMOUNT_DT$) -> Kt: $EXPO_KT$ ($SYS_AMOUNT_KT$)',
                                                                  Schema_GPSys.MLng.ctxAccounting,
                                                                  Schema_GPSys.MLng.lngBG,
                                                                  aParams
                                                                 );
              end if;
            end if;

            if ( bRet and
                nvl( nTaxSumDt, 0 ) > 0 ) then
              sTaxKeyDt1  := 'OPRTAXES';

              if ( not Schema_GPSys.HeadExpo.IsItCashExpo( nExpoDt ) and
                  not Schema_GPSys.HeadExpo.IsItCashExpo( nExpoKt ) ) then
                sTaxKeyDt1  := sTaxKeyDt1 || '_ACC';
              end if;

              if ( rTarifaDt.nExpoTax > 0 ) then
                nIdEPrihod  := rTarifaDt.nExpoTax;
                cValPrihod  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIdEPrihod );
              else
                bRet  := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, sTaxKeyDt1, RecExpoDt.CODVAL, to_char( DealType ), null, null, null, nIdEPrihod, cValPrihod );
              end if;

              if ( bRet ) then
                if ( DealType = Sch_CloseExpo ) then
                  nIDExpoTax  := nExpoDt;
                  sCodValTax  := RecExpoDt.CODVAL;
                else
                  if ( nvl( cUseTaxes, 'T' ) = 'I' and
                      Schema_GPSys.HeadExpo.IsItCashExpo( nExpoKt ) ) then
                    nIDExpoTax  := nExpoKt;
                    sCodValTax  := RecExpoKt.CODVAL;

                    if ( RecExpoKt.CODVAL != Schema_GPSys.OraGPSys.SYS_CURR ) then
                      select nvl( min( b.ID_EXPO ), 0 )
                        into nIDExpoCash
                        from Schema_GPSys.EXPO_CONF b
                       where b.FLDMODE = 'Cash' and
                             b.PARAM1 in (select a.PARAM1
                                            from Schema_GPSys.EXPO_CONF a
                                           where a.ID_EXPO = nExpoKt and
                                                 a.FLDMODE = 'Cash') and
                             b.UNIQCODE = RecExpoKt.UNIQCODE and
                             b.PARAM2 = Schema_GPSys.OraGPSys.SYS_CURR;

                      if ( nIDExpoCash > 0 ) then
                        nIDExpoTax  := nIDExpoCash;
                        sCodValTax  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoTax );
                      end if;
                    end if;
                  elsif ( Schema_GPSys.HeadExpo.IsItVatExpo( RealDt ) ) then
                    nIDExpoTax  := Expo.GetExpo4Lihvi( RealDt );
                    sCodValTax  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoTax );
                  else
                    nIDExpoTax  := Expo.GetExpo4Taxes( RealDt );
                    sCodValTax  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoTax );
                  end if;

                  nTaxDt  := Schema_GPSys.XchgRates.GetExactSum( nTaxSumDt, nUniqCode, ValiorDt, sTaxValDt, sCodValTax, Schema_GPSys.XchgRates.XchgRateType_Fixing );
                end if;

                oOper                  := Schema_GPSys.TSchOper( Sch_OperTaxes,
                                                                 nIDExpoTax,
                                                                 sCodValTax,
                                                                 nTaxDt,
                                                                 Schema_GPSys.XchgRates.GetExactSum( nTaxSumDt, nUniqCode, ValiorDt, sTaxValDt, cValPrihod, Schema_GPSys.XchgRates.XchgRateType_Fixing ),
                                                                 cValPrihod,
                                                                 nIdEPrihod,
                                                                 ValiorDt,
                                                                 Schema_GPSys.XchgRates.GetExactSum( nTaxSumDt,
                                                                                                     nUniqCode,
                                                                                                     ValiorDt,
                                                                                                     sTaxValDt,
                                                                                                     Schema_GPSys.OraGPSys.SYS_CURR,
                                                                                                     Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                    ),
                                                                 dSchDate,
                                                                 null,
                                                                 null
                                                                );
                oOpers.extend;
                oOpers( oOpers.last )  := oOper;

                if ( not Schema_GPSys.OraGPSys.SearchNumberInArray( aTaxedExpo, nIDExpoTax ) ) then
                  aTaxedExpo( aTaxedExpo.count + 1 )  := nIDExpoTax;
                end if;

                --
                rTaxRegDt.DT_EXPO      := nIDExpoTax;
                rTaxRegDt.KT_EXPO      := nIdEPrihod;
                rTaxRegDt.KIND_TECH    := Taxes.KindTechExpo;
                rTaxRegDt.ID_PAYTAX    := nCurrDeal;
                Taxes.RegTaxes2Buffer( rTaxRegDt, RegTaxes );
              else
                sError  := Schema_GPSys.MLng.Str2( 'Липсва експозиция за приходи от такси', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
              end if;
            end if;

            if ( bRet and
                nvl( nTaxSumKt, 0 ) > 0 ) then
              sTaxKeyKt1  := 'OPRTAXES';

              if ( not Schema_GPSys.HeadExpo.IsItCashExpo( nExpoDt ) and
                  not Schema_GPSys.HeadExpo.IsItCashExpo( nExpoKt ) ) then
                sTaxKeyKt1  := sTaxKeyKt1 || '_ACC';
              end if;

              if ( rTarifaKt.nExpoTax > 0 ) then
                nIdEPrihod  := rTarifaKt.nExpoTax;
                cValPrihod  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIdEPrihod );
              else
                bRet  := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, sTaxKeyKt1, RecExpoKt.CODVAL, to_char( DealType ), null, null, null, nIdEPrihod, cValPrihod );
              end if;

              if ( bRet ) then
                nDummy                 := Sch_OperTaxes;

                if ( nvl( cUseTaxes, 'T' ) = 'I' ) then
                  nIDExpoTax  := nExpoDt;
                  sCodValTax  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoTax );
                  nDummy      := Sch_FreeTaxes;

                  if ( Schema_GPSys.HeadExpo.IsItCashExpo( nExpoDt ) and
                      RecExpoDt.CODVAL != Schema_GPSys.OraGPSys.SYS_CURR ) then
                    select nvl( min( b.ID_EXPO ), 0 )
                      into nIDExpoCash
                      from Schema_GPSys.EXPO_CONF b
                     where b.FLDMODE = 'Cash' and
                           b.PARAM1 in (select a.PARAM1
                                          from Schema_GPSys.EXPO_CONF a
                                         where a.ID_EXPO = nExpoDt and
                                               a.FLDMODE = 'Cash') and
                           b.UNIQCODE = RecExpoDt.UNIQCODE and
                           b.PARAM2 = Schema_GPSys.OraGPSys.SYS_CURR;

                    if ( nIDExpoCash > 0 ) then
                      nIDExpoTax  := nIDExpoCash;
                      sCodValTax  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoTax );
                    end if;
                  end if;
                elsif ( Schema_GPSys.HeadExpo.IsItVatExpo( nExpoKt ) ) then
                  nIDExpoTax  := Expo.GetExpo4Lihvi( nExpoKt );
                  sCodValTax  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoTax );
                else
                  nIDExpoTax  := Expo.GetExpo4Taxes( nExpoKt );
                  sCodValTax  := Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpoTax );
                end if;

                oOper                  := Schema_GPSys.TSchOper( nDummy,
                                                                 nIDExpoTax,
                                                                 sCodValTax,
                                                                 Schema_GPSys.XchgRates.GetExactSum( nTaxSumKt, nUniqCode, ValiorKt, sTaxValKt, sCodValTax, Schema_GPSys.XchgRates.XchgRateType_Fixing ),
                                                                 Schema_GPSys.XchgRates.GetExactSum( nTaxSumKt, nUniqCode, ValiorKt, sTaxValKt, cValPrihod, Schema_GPSys.XchgRates.XchgRateType_Fixing ),
                                                                 cValPrihod,
                                                                 nIdEPrihod,
                                                                 ValiorKt,
                                                                 Schema_GPSys.XchgRates.GetExactSum( nTaxSumKt,
                                                                                                     nUniqCode,
                                                                                                     ValiorKt,
                                                                                                     sTaxValKt,
                                                                                                     Schema_GPSys.OraGPSys.SYS_CURR,
                                                                                                     Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                    ),
                                                                 dSchDate,
                                                                 null,
                                                                 null
                                                                );
                oOpers.extend;
                oOpers( oOpers.last )  := oOper;

                if ( not Schema_GPSys.OraGPSys.SearchNumberInArray( aTaxedExpo, nIDExpoTax ) ) then
                  aTaxedExpo( aTaxedExpo.count + 1 )  := nIDExpoTax;
                end if;

                --
                rTaxRegKt.DT_EXPO      := nIDExpoTax;
                rTaxRegKt.KT_EXPO      := nIdEPrihod;
                rTaxRegKt.KIND_TECH    := Taxes.KindTechExpo;
                rTaxRegKt.ID_PAYTAX    := nCurrDeal;
                Taxes.RegTaxes2Buffer( rTaxRegKt, RegTaxes );
              else
                sError  := Schema_GPSys.MLng.Str2( 'Липсва експозиция за приходи от такси', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
              end if;
            end if;

            if ( bRet and
                bLastDeal ) then
              if ( aTaxedExpo.count > 0 ) then
                for kk in aTaxedExpo.first .. aTaxedExpo.last loop
                  select nvl( sum( decode( a.ExpoDt, aTaxedExpo( kk ), a.AmountDt, 0 ) - decode( a.ExpoKt, aTaxedExpo( kk ), a.AmountKt, 0 ) ), 0 ),
                         min( a.Valior )
                    into nTemp,
                         dValior
                    from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                   where aTaxedExpo( kk ) in (a.ExpoDt, a.ExpoKt);

                  if ( nTemp > 0 ) then
                    bRet  := Loans.GetFromAutoUseLoan( aTaxedExpo( kk ), Schema_GPSys.HeadExpo.IDExpo2CodVal( aTaxedExpo( kk ) ), dValior, dSchDate, nTemp, oOpers );

                    if ( not bRet ) then
                      sError  := Schema_RA.GPC_RA.RespGetErrorText;
                    end if;
                  end if;

                  exit when not bRet;
                end loop;
              end if;

              if ( ( Schema_GPSys.OraSys.VerBankTokuda or
                    Schema_GPSys.OraSys.VerBankDBank ) and
                  nvl( CloseExpo, 0 ) <= 0 ) then
                select distinct ID_EXPO
                  bulk collect into aCredExpo
                  from (select /*+ LEADING( a b c ) USE_NL( b c ) */
                              a.EXPODT as ID_EXPO
                          from Schema_GPSys.EXPOTYPES c,
                               Schema_GPSys.EXPOSITION b,
                               table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                         where a.OPERTYPE not in (Sch_ImportOborot, Sch_Preocenka, Sch_ClearOborot) and
                               b.ID_EXPO = a.EXPODT and
                               b.ID_CUST > 0 and
                               c.TYPE_EXPO = b.TYPE_EXPO and
                               c.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg
                        union all
                        select /*+ LEADING( a b c ) USE_NL( b c ) */
                              a.EXPOKT as ID_EXPO
                          from Schema_GPSys.EXPOTYPES c,
                               Schema_GPSys.EXPOSITION b,
                               table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                         where a.OPERTYPE not in (Sch_ImportOborot, Sch_Preocenka, Sch_ClearOborot) and
                               b.ID_EXPO = a.EXPOKT and
                               b.ID_CUST > 0 and
                               c.TYPE_EXPO = b.TYPE_EXPO and
                               c.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg);
              end if;

              if ( aCredExpo.count > 0 ) then
                for kk in aCredExpo.first .. aCredExpo.last loop
                  select nvl( sum( decode( a.ExpoDt, aCredExpo( kk ), a.AmountDt, 0 ) - decode( a.ExpoKt, aCredExpo( kk ), a.AmountKt, 0 ) ), 0 ),
                         max( a.Valior )
                    into nTemp,
                         dValior
                    from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                   where aCredExpo( kk ) in (a.ExpoDt, a.ExpoKt);

                  if ( nTemp != 0 ) then
                    bRet  := Loans.CorrCreditEngagement( aCredExpo( kk ), dValior, dSchDate, nTemp, oOpers );

                    if ( not bRet ) then
                      sError  := Schema_RA.GPC_RA.RespGetErrorText;
                    end if;
                  end if;

                  exit when not bRet;
                end loop;
              end if;

              if ( bRet and
                  nvl( CloseExpo, 0 ) > 0 ) then
                bRet  := Expo.GetExpoCodVal( CloseExpo, cValPrihod );

                if ( bRet and
                    cValPrihod != Schema_GPSys.OraGPSys.SYS_CURR ) then
                  bRet  := Expo.GetESysHotSaldo( CloseExpo, nSysDiff );

                  if ( bRet ) then
                    select sum( decode( a.ExpoDt, CloseExpo, -a.SysAmount, 0 ) + decode( a.ExpoKt, CloseExpo, a.SysAmount, 0 ) )
                      into nTemp
                      from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
                     where CloseExpo in (a.ExpoDt, a.ExpoKt);

                    nSysDiff  := nSysDiff + nvl( nTemp, 0 );

                    if ( nSysDiff != 0 ) then
                      if ( Schema_GPSys.HeadExpo.IsExpoInBalance( CloseExpo ) ) then
                        if ( nSysDiff > 0 ) then
                          sError      := Schema_GPSys.MLng.Str2( 'Липсва експозиция за приходи от преоценка',
                                                                 Schema_GPSys.MLng.ctxAccounting,
                                                                 Schema_GPSys.MLng.lngBG
                                                                );
                          sType       := 'Prihod';
                        else
                          sError      := Schema_GPSys.MLng.Str2( 'Липсва експозиция за разходи от преоценка',
                                                                 Schema_GPSys.MLng.ctxAccounting,
                                                                 Schema_GPSys.MLng.lngBG
                                                                );
                          sType       := 'Razhod';
                        end if;

                        bRet      := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode,
                                                                      'RateDifferPreocenka',
                                                                      Schema_GPSys.OraGPSys.SYS_CURR,
                                                                      sType,
                                                                      null,
                                                                      cValPrihod,
                                                                      Schema_GPSys.OraGPSys.GetSynt( Schema_GPSys.HeadExpo.IDExpo2ExpoCode( CloseExpo ) ),
                                                                      nExpoCR,
                                                                      sCValCR
                                                                     ) and
                                     sCValCR = Schema_GPSys.OraGPSys.SYS_CURR;
                      else
                        if ( nSysDiff > 0 ) then
                          sError      := Schema_GPSys.MLng.Str2( 'Липсва обща активна задбалансова експозиция',
                                                                 Schema_GPSys.MLng.ctxAccounting,
                                                                 Schema_GPSys.MLng.lngBG
                                                                );
                          sType       := 'Active';
                        else
                          sError      := Schema_GPSys.MLng.Str2( 'Липсва обща пасивна задбалансова експозиция',
                                                                 Schema_GPSys.MLng.ctxAccounting,
                                                                 Schema_GPSys.MLng.lngBG
                                                                );
                          sType       := 'Passive';
                        end if;

                        bRet      := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'Common_Zadbalance', Schema_GPSys.OraGPSys.SYS_CURR, sType, 'Preocenka', null, null, nExpoCR, sCValCR ) and
                                     sCValCR = Schema_GPSys.OraGPSys.SYS_CURR;
                      end if;

                      if ( bRet ) then
                        if ( nSysDiff > 0 ) then
                          oOper  := Schema_GPSys.TSchOper( Sch_Preocenka, CloseExpo, cValPrihod, 0, nSysDiff, sCValCR, nExpoCR, dSchDate, nSysDiff, dSchDate, null, null );
                        else
                          oOper  := Schema_GPSys.TSchOper( Sch_Preocenka, nExpoCR, sCValCR, -nSysDiff, 0, cValPrihod, CloseExpo, dSchDate, -nSysDiff, dSchDate, null, null );
                        end if;

                        oOpers.extend;
                        oOpers( oOpers.last )  := oOper;
                      end if;
                    end if;
                  end if;
                end if;
              end if;
            end if;

            if ( bRet and
                bZBalSpot and
                ( not DealType in
                        ( Sch_ImportOborot,
                         Sch_ClearOborot,
                         Sch_Storno,
                         Sch_AvanLihvi,
                         Sch_AvanTranLih,
                         Sch_CommLih,
                         Sch_Lihvi,
                         Sch_TranLih,
                         Sch_TaxLihvi,
                         Sch_PlanLihvi,
                         Sch_RateDiffer,
                         Sch_Preocenka,
                         Sch_CredEngagement,
                         Sch_ZBalPpv,
                         Sch_ForSch,
                         Sch_ZadBalDeal,
                         Sch_Deal ) ) and
                ( not Taxes.bIsOperTypeTax( DealType ) ) and
                RecExpoDt.CODVAL != RecExpoKt.CODVAL and
                Schema_GPSys.HeadExpo.IsItSpecialSynt( RecExpoDt.EXPO_CODE, 'Prihod_Razhod' ) = Schema_GPSys.OraGPSys.DocSysFalse and
                Schema_GPSys.HeadExpo.IsItSpecialSynt( RecExpoKt.EXPO_CODE, 'Prihod_Razhod' ) = Schema_GPSys.OraGPSys.DocSysFalse and
                RecTypeDt.IN_BALANCE = 'T' and
                Expo.GetZBalancePpv( nUniqCode ) ) then
              bRet      := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'Common_Zadbalance', Schema_GPSys.OraGPSys.SYS_CURR, 'Active', 'PPV', null, null, IDEZBalA, ValZBalA ) and
                           ValZBalA = Schema_GPSys.OraGPSys.SYS_CURR;

              if ( bRet ) then
                bRet      := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'Common_Zadbalance', Schema_GPSys.OraGPSys.SYS_CURR, 'Passive', 'PPV', null, null, IDEZBalP, ValZBalP ) and
                             ValZBalP = Schema_GPSys.OraGPSys.SYS_CURR;

                if ( bRet ) then
                  bRet      := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'PPV_Zadbalance', RecExpoDt.CODVAL, 'SpotBuy', RecExpoKt.CODVAL, null, null, IDESpotBuy, ValSpotBuy ) and
                               ValSpotBuy = RecExpoDt.CODVAL;

                  if ( bRet ) then
                    bRet      := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'PPV_Zadbalance', RecExpoKt.CODVAL, 'SpotSell', RecExpoDt.CODVAL, null, null, IDESpotSell, ValSpotSell ) and
                                 ValSpotSell = RecExpoKt.CODVAL;

                    if ( bRet ) then
                      nSysAmountDt           := Schema_GPSys.XchgRates.GetExactSum( nAmountDt,
                                                                                    nUniqCode,
                                                                                    ValiorKt,
                                                                                    RecExpoDt.CODVAL,
                                                                                    Schema_GPSys.OraGPSys.SYS_CURR,
                                                                                    Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                   );
                      nSysAmountKt           := Schema_GPSys.XchgRates.GetExactSum( nAmountKt,
                                                                                    nUniqCode,
                                                                                    ValiorKt,
                                                                                    RecExpoKt.CODVAL,
                                                                                    Schema_GPSys.OraGPSys.SYS_CURR,
                                                                                    Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                   );
                      oOper                  := Schema_GPSys.TSchOper( Sch_ZBalPpv, IDESpotBuy, ValSpotBuy, nAmountDt, nSysAmountDt, ValZBalP, IDEZBalP, ValiorKt, nSysAmountDt, dSchDate, null, null );
                      oOpers.extend;
                      oOpers( oOpers.last )  := oOper;
                      --
                      oOper                  := Schema_GPSys.TSchOper( Sch_ZBalPpv,
                                                                       IDEZBalA,
                                                                       ValZBalA,
                                                                       nSysAmountKt,
                                                                       nAmountKt,
                                                                       ValSpotSell,
                                                                       IDESpotSell,
                                                                       ValiorKt,
                                                                       nSysAmountKt,
                                                                       dSchDate,
                                                                       null,
                                                                       null
                                                                      );
                      oOpers.extend;
                      oOpers( oOpers.last )  := oOper;
                      --
                      oOper                  := Schema_GPSys.TSchOper( Sch_ZBalPpv, IDEZBalP, ValZBalP, nSysAmountDt, nAmountDt, ValSpotBuy, IDESpotBuy, ValiorKt, nSysAmountDt, dSchDate, null, null );
                      oOpers.extend;
                      oOpers( oOpers.last )  := oOper;
                      --
                      oOper                  := Schema_GPSys.TSchOper( Sch_ZBalPpv,
                                                                       IDESpotSell,
                                                                       ValSpotSell,
                                                                       nAmountKt,
                                                                       nSysAmountKt,
                                                                       ValZBalA,
                                                                       IDEZBalA,
                                                                       ValiorKt,
                                                                       nSysAmountKt,
                                                                       dSchDate,
                                                                       null,
                                                                       null
                                                                      );
                      oOpers.extend;
                      oOpers( oOpers.last )  := oOper;
                    else
                      aParams.delete;
                      aParams( 1 ).ML_NAME   := 'CURRENCY';
                      aParams( 1 ).ML_VALUE  := RecExpoKt.CODVAL;
                      sError                 := Schema_GPSys.MLng.Str2( 'Липсва експозиция Spot Sell $CURRENCY$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
                    end if;
                  else
                    aParams.delete;
                    aParams( 1 ).ML_NAME   := 'CURRENCY';
                    aParams( 1 ).ML_VALUE  := RecExpoDt.CODVAL;
                    sError                 := Schema_GPSys.MLng.Str2( 'Липсва експозиция Spot Buy $CURRENCY$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
                  end if;
                else
                  sError  := Schema_GPSys.MLng.Str2( 'Липсва обща пасивна задбалансова експозиция', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                end if;
              else
                sError  := Schema_GPSys.MLng.Str2( 'Липсва обща активна задбалансова експозиция', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
              end if;
            end if;

            if ( bRet ) then
              if ( nFirstOper = 1 or
                  DealType not in (Sch_Preocenka, Sch_ClearOborot) ) then
                -- отгоре се разписват всички редове със счетоводни записвания
                -- отдолу се добавят в документа
                oDocRow            := Schema_GPSys.DocSysIQRecType( 2, -1, 1, 'S', nDocID, null, null, null, null, null, null );
                oDoc.extend( );
                oDoc( oDoc.last )  := oDocRow;
                --
                nDocID             := nDocID + 1;
                bDummy             := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '2.OPERS', nDocID - 1, nDocID );
                --
                nOpersID           := nDocID;
                nDocID             := nDocID + 1;
              end if;

              for i in nFirstOper .. oOpers.last loop
                bRet  := abs( oOpers( i ).SysAmount ) <= GetMaxOperSum;

                if ( bRet ) then
                  bRet      := ( oOpers( i ).ValDt != Schema_GPSys.OraGPSys.SYS_CURR or
                                oOpers( i ).AmountDt = oOpers( i ).SysAmount ) and
                               ( oOpers( i ).ValKt != Schema_GPSys.OraGPSys.SYS_CURR or
                                oOpers( i ).AmountKt = oOpers( i ).SysAmount );

                  if ( bRet ) then
                    oDocRow              := Schema_GPSys.DocSysIQRecType( nOpersID, -1, 1, 'S', nDocID, null, null, null, null, null, null );
                    oDoc.extend( );
                    oDoc( oDoc.last )    := oDocRow;
                    --
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder_Oper', 'OPER_TYPE', nDocID, oOpers( i ).OperType );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder_Oper', 'EXPO_DT', nDocID, oOpers( i ).ExpoDt );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdMoney( oDoc, 'SaveMemoOrder_Oper', 'MONEY_DT', nDocID, oOpers( i ).ValDt, oOpers( i ).AmountDt );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdMoney( oDoc, 'SaveMemoOrder_Oper', 'MONEY_KT', nDocID, oOpers( i ).ValKt, oOpers( i ).AmountKt );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder_Oper', 'EXPO_KT', nDocID, oOpers( i ).ExpoKt );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, 'SaveMemoOrder_Oper', 'VALIOR', nDocID, oOpers( i ).Valior );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdMoney( oDoc, 'SaveMemoOrder_Oper', 'SYS_MONEY', nDocID, Schema_GPSys.OraGPSys.SYS_CURR, oOpers( i ).SysAmount );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder_Oper', 'UNIQCODE', nDocID, nUniqCode );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, 'SaveMemoOrder_Oper', 'SCH_DATE', nDocID, oOpers( i ).SchDate );
                    bDummy               := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder_Oper', 'ROW_NUM', nDocID, i );
                    --
                    nDocID               := nDocID + 1;
                    --
                    oOpers( i ).DealNum  := nCurrDeal;
                  else
                    aParams.delete;
                    aParams( 1 ).ML_NAME   := 'ERR';
                    aParams( 1 ).ML_VALUE  := cc;
                    sError                 := Schema_GPSys.MLng.Str2( 'Вътрешна грешка при генерация на ордера - $ERR$',
                                                                      Schema_GPSys.MLng.ctxAccounting,
                                                                      Schema_GPSys.MLng.lngBG,
                                                                      aParams
                                                                     );
                  end if;
                else
                  aParams.delete;
                  aParams( 1 ).ML_NAME   := 'ERR';
                  aParams( 1 ).ML_VALUE  := cc;
                  sError                 := Schema_GPSys.MLng.Str2( 'Некоректна системна равностойност при генерация на ордера - $ERR$',
                                                                    Schema_GPSys.MLng.ctxAccounting,
                                                                    Schema_GPSys.MLng.lngBG,
                                                                    aParams
                                                                   );
                end if;

                exit when not bRet;
              end loop;
            end if;
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'EXPO_DT';
            aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoDt );
            aParams( 2 ).ML_NAME   := 'CURRENCY_DT';
            aParams( 2 ).ML_VALUE  := RecExpoDt.CODVAL;
            aParams( 3 ).ML_NAME   := 'AMOUNT_DT';
            aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmountDt );
            aParams( 4 ).ML_NAME   := 'AMOUNT_KT';
            aParams( 4 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmountKt );
            aParams( 5 ).ML_NAME   := 'CURRENCY_KT';
            aParams( 5 ).ML_VALUE  := RecExpoKt.CODVAL;
            aParams( 6 ).ML_NAME   := 'EXPO_KT';
            aParams( 6 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nExpoKt );
            aParams( 7 ).ML_NAME   := 'AMOUNT_SYS';
            aParams( 7 ).ML_VALUE  := Schema_GPSys.OraGPSys.AmountToS( nAmountSys );
            sError                 := Schema_GPSys.MLng.Str2( 'Некоректни суми в ордера - $EXPO_DT$ $CURRENCY_DT$ $AMOUNT_DT$ -> $AMOUNT_KT$ $CURRENCY_KT$ $EXPO_KT$; $AMOUNT_SYS$',
                                                              Schema_GPSys.MLng.ctxAccounting,
                                                              Schema_GPSys.MLng.lngBG,
                                                              aParams
                                                             );
          end if;
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ERR';
          aParams( 1 ).ML_VALUE  := cc;
          sError                 := Schema_GPSys.MLng.Str2( 'Некоректна контировка - $ERR$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
        end if;
      else
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ERR';
        aParams( 1 ).ML_VALUE  := cc;
        sError                 := Schema_GPSys.MLng.Str2( 'Контировка между експозиции в различни баланси - $ERR$',
                                                          Schema_GPSys.MLng.ctxAccounting,
                                                          Schema_GPSys.MLng.lngBG,
                                                          aParams
                                                         );
      end if;
    end if;

    return bRet;
  end CreateSchTrans;

  --------------------------------------------------------------------------------
  function SaveMemoOrder(
    MemoHeadData  in out nocopy Schema_GPSys.tMemoOrder,
    MemoRows      in out nocopy Schema_GPSys.tblDealOper,
    BdgRows       in            tblBdgOpers,
    bPreView      in            boolean,
    bZBalSpot     in            boolean,
    bCashReq      in            boolean,
    bCommit       in            boolean,
    AddRows       in            tblAddOpers default tAddOpers,
    CostRows      in            Schema_GPSys.tblCostOpers default tCostOpers
  )
    return boolean is
    aIDMoves  Schema_GPSys.OraGPSys.aIntegers;
    rExpoDT   Schema_GPSys.EXPOSITION%rowtype;
    rExpoKT   Schema_GPSys.EXPOSITION%rowtype;
    cDummy    varchar2( 16 );
    bDummy    boolean;
    bRet      boolean := true;
  begin
    if ( MemoRows.count = 1 and
        not bPreView ) then
      rExpoDT  := Schema_GPSys.HeadExpo.IDExpo2ExpoData( MemoRows( 1 ).EXPO_DT );
      rExpoKT  := Schema_GPSys.HeadExpo.IDExpo2ExpoData( MemoRows( 1 ).EXPO_KT );

      if ( rExpoDT.UNIQCODE != rExpoKT.UNIQCODE and
          Expo.IsSystemHaveBalances ) then
        bRet      := HierarchySaveMemOrder( aIDMoves,
                                            rExpoDT.UNIQCODE,
                                            rExpoDT.ID_EXPO,
                                            MemoRows( 1 ).AMOUNT_DT,
                                            MemoRows( 1 ).VALIOR_DT,
                                            rExpoKT.UNIQCODE,
                                            rExpoKT.ID_EXPO,
                                            MemoRows( 1 ).AMOUNT_KT,
                                            MemoRows( 1 ).VALIOR_KT,
                                            MemoHeadData.SCH_DATE,
                                            MemoHeadData.ORD_TEXT,
                                            MemoRows( 1 ).AMOUNT_DT,
                                            rExpoDT.CODVAL,
                                            MemoRows( 1 ).REFERENCIA,
                                            MemoRows( 1 ).AMOUNT_SYS,
                                            MemoRows( 1 ).DEAL_TYPE,
                                            BdgRows,
                                            AddRows,
                                            null,
                                            true,
                                            null,
                                            CostRows
                                           );
      end if;
    end if;

    if ( bRet ) then
      if ( aIDMoves.count > 0 ) then
        if ( rExpoDT.UNIQCODE = MemoHeadData.UNIQCODE ) then
          MemoHeadData.ID_MOVE  := aIDMoves( 1 );
        else
          MemoHeadData.ID_MOVE  := aIDMoves( aIDMoves.count );
        end if;
      else
        bRet  := Schema_GPSys.Cmd_HeadExpo.GenerateAvanLihDoc( MemoHeadData, MemoRows, false, bPreView, true, bCashReq );

        if ( bRet and
            nvl( MemoHeadData.ID_MOVE, 0 ) = 0 ) then
          bRet  := GenerateMemoOrder( MemoHeadData, MemoRows, bPreView, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, bZBalSpot, bCashReq, null, BdgRows, AddRows, CostRows );
        end if;
      end if;

      if ( bCommit or
          bPreView ) then
        if ( bRet and
            not bPreView ) then
          Schema_GPSys.GPC_Parser.RespAddArray( 1 );
          cDummy  := null;
          bDummy  := Schema_GPSys.GPC_Parser.WriteInteger( MemoHeadData.ID_MOVE, cDummy );
          Schema_GPSys.GPC_Parser.RespAddRow( cDummy );
          commit;
        else
          rollback;
        end if;
      else
        Schema_GPSys.GPC_Parser.nGlobalNumber  := MemoHeadData.ID_MOVE;
      end if;
    end if;

    return bRet;
  end SaveMemoOrder;

  --------------------------------------------------------------------------------
  function SchCredLawInterest(
    MemoHeadData  in out nocopy Schema_GPSys.tMemoOrder,
    tMemoRows     in            Schema_GPSys.tblDealOper,
    BdgRows       in            tblBdgOpers,
    bPreView      in            boolean,
    bZBalSpot     in            boolean,
    bCashReq      in            boolean,
    bCommit       in            boolean,
    AddRows       in            tblAddOpers default tAddOpers,
    CostRows      in            Schema_GPSys.tblCostOpers
  )
    return boolean is
    MemoRows          Schema_GPSys.tblDealOper;
    rCustData         Schema_Cust.GPC_Customs.recCustData;
    rExpoLawInterest  Schema_GPSys.EXPOSITION%rowtype;
    rExpoObsl         Schema_GPSys.EXPOSITION%rowtype;
    sCredType         LOAN_CREDIT.PROGRAMA%type;
    nExpoZadP         integer;
    nExpoRazchet      integer;
    nExpoPrihod       integer;
    sCValZadP         varchar2( 3 );
    sCodValRazchet    varchar2( 3 );
    sCodValPrihod     varchar2( 3 );
    bRet              boolean := true;
    aParams           Schema_RA.GPC_RA.tblErrParams;
  begin
    if ( tMemoRows.count = 1 and
        tMemoRows( 1 ).DEAL_TYPE = Sch_LawInterest ) then
      begin
        select a.PROGRAMA
          into sCredType
          from LOAN_CREDIT a
         where a.ID_CRED_ENGAGE = (select b.ID_CRED_ENGAGE
                                     from LOAN_EXPOSITION b
                                    where b.ID_EXPO = tMemoRows( 1 ).EXPO_KT and
                                          b.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_ZakonovaLihva);

        rExpoLawInterest  := Schema_GPSys.HeadExpo.IDExpo2ExpoData( tMemoRows( 1 ).EXPO_KT );
        rExpoObsl         := Schema_GPSys.HeadExpo.IDExpo2ExpoData( tMemoRows( 1 ).EXPO_DT );
      exception
        when no_data_found then
          bRet  := false;
          Schema_RA.GPC_RA.RespSetErrorText( 'Не е намерено досие на кредит за експозиция законова лихва',
                                             Schema_GPSys.MLng.ctxAccounting,
                                             Schema_GPSys.MLng.lngBG
                                            );
      end;

      if ( bRet ) then
        bRet      := Schema_GPSys.HeadExpo.Conf2Expo( rExpoLawInterest.UNIQCODE, 'Common_Zadbalance', Schema_GPSys.OraGPSys.SYS_CURR, 'Passive', 'ZadBal_Lihvi', null, null, nExpoZadP, sCValZadP ) and
                     sCValZadP = Schema_GPSys.OraGPSys.SYS_CURR;

        if ( not bRet ) then
          Schema_RA.GPC_RA.RespSetErrorText( 'Липсва обща пасивна задбалансова експозиция', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
        else
          bRet      := Schema_GPSys.HeadExpo.Conf2Expo( rExpoLawInterest.UNIQCODE,
                                                        'Razchet_LIHVI',
                                                        rExpoLawInterest.CODVAL,
                                                        'Delay',
                                                        null,
                                                        null,
                                                        nvl( sCredType, 'SYNT' || Schema_GPSys.OraGPSys.GetSynt( Schema_GPSys.HeadExpo.IDExpo2ExpoCode( rExpoLawInterest.ID_EXPO ) ) ),
                                                        nExpoRazchet,
                                                        sCodValRazchet
                                                       ) and
                       sCodValRazchet = rExpoLawInterest.CODVAL;

          if ( not bRet ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( rExpoLawInterest.ID_EXPO );
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за разчет за лихви на експозиция $ID_EXPO$',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          else
            rCustData.IDCust  := rExpoLawInterest.ID_CUST;
            bRet              := Schema_Cust.GPC_Customs.GetCustType( rCustData ) and
                                 Schema_GPSys.HeadExpo.Conf2Expo( rExpoLawInterest.UNIQCODE,
                                                                  'Result_LIHVI',
                                                                  rExpoLawInterest.CODVAL,
                                                                  'Prihod',
                                                                  'Moratory',
                                                                  rCustData.FType,
                                                                  nvl( sCredType, 'SYNT' || Schema_GPSys.OraGPSys.GetSynt( Schema_GPSys.HeadExpo.IDExpo2ExpoCode( rExpoLawInterest.ID_EXPO ) ) ),
                                                                  nExpoPrihod,
                                                                  sCodValPrihod
                                                                 );

            if ( not bRet ) then
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'ID_EXPO';
              aParams( 1 ).ML_VALUE  := to_char( rExpoLawInterest.ID_EXPO );
              Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за лихви на експозиция $ID_EXPO$',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;

            if ( bRet ) then
              MemoRows                       := Schema_GPSys.tblDealOper( );
              MemoRows.extend;
              MemoRows( MemoRows.last )      := Schema_GPSys.tDealOper( Cmd_Expo.Sch_LawInterest,
                                                                        nExpoZadP,
                                                                        Schema_GPSys.XchgRates.GetExactSum( tMemoRows( 1 ).AMOUNT_KT,
                                                                                                            null,
                                                                                                            tMemoRows( 1 ).VALIOR_KT,
                                                                                                            rExpoLawInterest.CODVAL,
                                                                                                            sCValZadP,
                                                                                                            Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                           ),
                                                                        tMemoRows( 1 ).AMOUNT_KT,
                                                                        rExpoLawInterest.ID_EXPO,
                                                                        tMemoRows( 1 ).VALIOR_KT,
                                                                        tMemoRows( 1 ).VALIOR_KT,
                                                                        rExpoLawInterest.ID_EXPO,
                                                                        'F',
                                                                        null,
                                                                        tMemoRows( 1 ).REFERENCIA,
                                                                        null,
                                                                        0,
                                                                        null
                                                                       );
              MemoRows.extend;
              MemoRows( MemoRows.last )      := Schema_GPSys.tDealOper( Cmd_Expo.Sch_LawInterest,
                                                                        nExpoRazchet,
                                                                        tMemoRows( 1 ).AMOUNT_KT,
                                                                        Schema_GPSys.XchgRates.GetExactSum( tMemoRows( 1 ).AMOUNT_KT,
                                                                                                            null,
                                                                                                            tMemoRows( 1 ).VALIOR_KT,
                                                                                                            rExpoLawInterest.CODVAL,
                                                                                                            sCodValPrihod,
                                                                                                            Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                           ),
                                                                        nExpoPrihod,
                                                                        tMemoRows( 1 ).VALIOR_KT,
                                                                        tMemoRows( 1 ).VALIOR_KT,
                                                                        nExpoRazchet,
                                                                        'F',
                                                                        null,
                                                                        tMemoRows( 1 ).REFERENCIA,
                                                                        null,
                                                                        0,
                                                                        null
                                                                       );
              MemoRows.extend;
              MemoRows( MemoRows.last )      := Schema_GPSys.tDealOper( Cmd_Expo.Sch_LawInterest,
                                                                        rExpoObsl.ID_EXPO,
                                                                        tMemoRows( 1 ).AMOUNT_DT,
                                                                        tMemoRows( 1 ).AMOUNT_KT,
                                                                        nExpoRazchet,
                                                                        tMemoRows( 1 ).VALIOR_DT,
                                                                        tMemoRows( 1 ).VALIOR_KT,
                                                                        rExpoObsl.ID_EXPO,
                                                                        'F',
                                                                        null,
                                                                        tMemoRows( 1 ).REFERENCIA,
                                                                        null,
                                                                        0,
                                                                        null
                                                                       );
              bRet                           := SaveMemoOrder( MemoHeadData, MemoRows, BdgRows, bPreView, bZBalSpot, bCashReq, bCommit, AddRows, CostRows );
            end if;
          end if;
        end if;
      end if;
    else
      bRet  := false;
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри при погасяване на законови лихви',
                                         Schema_GPSys.MLng.ctxAccounting,
                                         Schema_GPSys.MLng.lngBG
                                        );
    end if;

    return bRet;
  end SchCredLawInterest;

  --------------------------------------------------------------------------------
  function CmdSaveMemoOrder(
    aParamEntities3D  in Schema_GPSys.GPC_Parser.taParamEntities3D,
    bCommit           in boolean default true,
    bCashReqParam     in boolean default false
  )
    return boolean is
    aRowValues           Schema_GPSys.GPC_Parser.taParamStrings;
    MemoHeadData         Schema_GPSys.tMemoOrder;
    MemoRow              Schema_GPSys.TDealOper;
    MemoRows             Schema_GPSys.tblDealOper;
    arrExpoOpenDataDT    Schema_GPSys.Cmd_HeadExpo.tblExpoOpenData;
    arrExpoOpenDataKT    Schema_GPSys.Cmd_HeadExpo.tblExpoOpenData;
    BdgRows              tblBdgOpers;
    AddRows              tblAddOpers;
    CostRows             Schema_GPSys.tblCostOpers;
    recCostRow           Schema_GPSys.recCostOpers;
    rExpoOpenData        Schema_GPSys.Cmd_HeadExpo.recExpoOpenData;
    rExpoDT              Schema_GPSys.EXPOSITION%rowtype;
    rExpoKT              Schema_GPSys.EXPOSITION%rowtype;
    rExpo                Schema_GPSys.EXPOSITION%rowtype;
    ii                   integer;
    nState               integer := 0;
    nRowType             integer;
    nRate                number;
    CodVal               varchar2( 3 );
    sData                varchar2( 4000 );
    sName                varchar2( 1000 );
    dPrev                date;
    bOldState1           boolean;
    bOldState2           boolean;
    bCashDT              boolean;
    bCashKT              boolean;
    bError               boolean := false;
    bPreView             boolean := false;
    bZBalSpot            boolean := true;
    bRet                 boolean := true;
    bSchCredLawInterest  boolean := false;
    bCashReq             boolean := bCashReqParam;
    bDummy               boolean;
    aParams              Schema_RA.GPC_RA.tblErrParams;
  begin
    --!!!NOTE!!!
    --Ако се добавят нови параметри в тази команда същите трябва да се добавят и в:
    --CMD_BDG.CmdSchRequestWithMemoOrder
    --!!!!!!!!!!
    if ( bCommit ) then
      Schema_DocSys.DocSys_SaveInIQ.UseQueueWork;
    end if;

    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри ордер', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
    ii        := aParamEntities3D.first;
    CostRows  := Schema_GPSys.tblCostOpers( );
    Schema_RA.GPC_RA.BegTempResponces;

    while ( ii is not null and
           bRet ) loop
      nRowType  := aParamEntities3D( ii ).nRowType;
      bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues );

      if ( bRet ) then
        if ( nRowType = 1 ) then
          MemoHeadData           := Schema_GPSys.tMemoOrder( null, null, null, null, null, null, null, null, null, null, null );
          MemoRows               := Schema_GPSys.tblDealOper( );
          bRet                   := nState = 0 and
                                    aRowValues.count >= 6 and
                                    Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), MemoHeadData.UNIQCODE ) and
                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), MemoHeadData.ORD_TEXT ) and
                                    Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), MemoHeadData.SCH_DATE ) and
                                    Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), MemoHeadData.ID_STORNO ) and
                                    Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 5 ), MemoHeadData.ID_CUST ) and
                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), MemoHeadData.SYS_TEXT ) and
                                    ( ( not aRowValues.exists( 7 ) ) or
                                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 7 ), MemoHeadData.ORIGIN ) ) and
                                    ( ( not aRowValues.exists( 8 ) ) or
                                     Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 8 ), bPreView ) ) and
                                    ( ( not aRowValues.exists( 9 ) ) or
                                     Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 9 ), bZBalSpot ) );

          if ( bRet and
              aRowValues.count >= 11 ) then
            bRet      := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 10 ), Expo.rMemoOrderAdd.nIDRelatedCust ) and
                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 11 ), Expo.rMemoOrderAdd.nModeOrigin );
          end if;

          if ( bRet and
              aRowValues.count >= 12 ) then
            bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 12 ), bCashReq );
          end if;

          nState                 := nRowType;
          MemoHeadData.DATETIME  := sysdate;
          --
          MemoHeadData.UNIQCODE  := nvl( nGlobalUniqCode, MemoHeadData.UNIQCODE );
          nGlobalUniqCode        := null;
        elsif ( nRowType = 2 ) then
          MemoRow                     := Schema_GPSys.TDealOper( null, null, null, null, null, null, null, null, null, null, null, null, null, null );
          bRet                        := nState in (1, 2) and
                                         aRowValues.count >= 10 and
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), MemoRow.DEAL_TYPE ) and
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), MemoRow.EXPO_DT ) and
                                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 3 ), MemoRow.AMOUNT_DT ) and
                                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 4 ), MemoRow.AMOUNT_KT ) and
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 5 ), MemoRow.EXPO_KT ) and
                                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 6 ), MemoRow.VALIOR_DT ) and
                                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 7 ), MemoRow.VALIOR_KT ) and
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 8 ), MemoRow.MAIN_EXPO ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 9 ), MemoRow.REFERENCIA ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 10 ), MemoRow.USE_TAXES ) and
                                         ( ( not aRowValues.exists( 11 ) ) or
                                          Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 11 ), MemoRow.AMOUNT_SYS ) ) and
                                         ( ( not aRowValues.exists( 12 ) ) or
                                          Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 12 ), MemoRow.XCHG_RATE ) ) and
                                         true;

          if ( bRet and
              MemoRow.DEAL_TYPE in (Sch_CredPogasiava, Sch_LawInterest) ) then
            bOldState1           := Expo.SetSkipLimit( EXPO.ModeSkip_DueAmn, true );
            bOldState2           := Expo.SetSkipLimit( EXPO.ModeSkip_CardHOLD, true );
            bSchCredLawInterest  := MemoRow.DEAL_TYPE = Sch_LawInterest;
          end if;

          if ( MemoRow.AMOUNT_SYS = 0 ) then
            MemoRow.AMOUNT_SYS  := null;
          end if;

          if ( bRet and
              aRowValues.count >= 24 ) then
            bRet      := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 23 ), MemoRow.TECHNOLOGY ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 24 ), MemoRow.TECHNOLOGY_DATA );
          end if;

          bRet                        := Cmd_Loans_Add2.IsCredPayInOutOk( MemoRow.EXPO_DT, MemoRow.TECHNOLOGY, MemoRow.TECHNOLOGY_DATA ) and
                                         Cmd_Loans_Add2.IsCredPayInOutOk( MemoRow.EXPO_KT, MemoRow.TECHNOLOGY, MemoRow.TECHNOLOGY_DATA );

          $if ( Schema_GPSys.OraSys.VerBankTokuda ) $then
          if ( bRet ) then
            bCashDT  := Schema_GPSys.HeadExpo.IsItCashExpo( MemoRow.EXPO_DT );
            bCashKT  := Schema_GPSys.HeadExpo.IsItCashExpo( MemoRow.EXPO_KT );

            if ( bCashDT or
                bCashKT ) then
              if ( not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 39 ) ) then
                declare
                  nIDCust   integer := 0;
                  nIDExpo   integer := 0;
                  nAmount   number;
                  nAmount1  number;
                  sDTKT     varchar2( 1 );
                begin
                  if ( bCashDT ) then
                    nIDCust  := Schema_GPSys.HeadExpo.IDExpo2IDCust( MemoRow.EXPO_KT );
                    nIDExpo  := MemoRow.EXPO_KT;
                    sDTKT    := 'K';
                  else
                    nIDCust  := Schema_GPSys.HeadExpo.IDExpo2IDCust( MemoRow.EXPO_DT );
                    nIDExpo  := MemoRow.EXPO_DT;
                    sDTKT    := 'D';
                  end if;

                  if ( nIDCust > 0 ) then
                    for recConf in ( select a.*
                                       from AML_CHECK_CONF a
                                      where a.MODE_CHECK between 1 and 7 and
                                            not exists
                                              (select 1
                                                 from AML_WHITE_LISTS xx
                                                where xx.MODE_CHECK = a.MODE_CHECK and
                                                      xx.ID_CUST = nIDCust and
                                                      xx.STATUS = 'T') ) loop
                      if ( ( bCashDT and
                            recConf.MODE_CHECK = 1 ) or
                          ( bCashKT and
                           recConf.MODE_CHECK = 2 ) ) then
                        select count( 1 )
                          into nAmount
                          from EXPO_MOVES a,
                               EXPO_MOVES b,
                               Schema_GPSys.EXPOSITION c,
                               Schema_GPSys.EXPOTYPES d
                         where a.ID_EXPO = nIDExpo and
                               a.SCH_DATE between MemoHeadData.SCH_DATE - nvl( recConf.PERIOD, 0 ) and MemoHeadData.SCH_DATE and
                               a.SYS_AMOUNT >= recConf.AMOUNT and
                               a.DT_KT = sDTKT and
                               not exists
                                 (select 1
                                    from EXPO_STRNMOVES xx
                                   where xx.ID_MOVE_OLD = a.ID_MOVE) and
                               not exists
                                 (select 1
                                    from EXPO_STRNMOVES yy
                                   where yy.ID_MOVE_NEW = a.ID_MOVE) and
                               a.ID_MOVE = b.ID_MOVE and
                               a.ORDROWNUM = b.ORDROWNUM and
                               a.DT_KT != b.DT_KT and
                               b.ID_EXPO = c.ID_EXPO and
                               c.TYPE_EXPO = d.TYPE_EXPO and
                               d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;

                        bRet  := nAmount <= recConf.HOWMANYTIMES;
                      elsif ( ( bCashDT and
                               recConf.MODE_CHECK in (3, 5) ) or
                             ( bCashKT and
                              recConf.MODE_CHECK in (4, 6) ) ) then
                        select count( 1 )
                          into nAmount
                          from EXPO_MOVES a,
                               EXPO_MOVES b,
                               Schema_GPSys.EXPOSITION c,
                               Schema_GPSys.EXPOTYPES d
                         where a.ID_EXPO = nIDExpo and
                               a.SCH_DATE between MemoHeadData.SCH_DATE - nvl( recConf.PERIOD, 0 ) and MemoHeadData.SCH_DATE and
                               a.DT_KT = sDTKT and
                               not exists
                                 (select 1
                                    from EXPO_STRNMOVES xx
                                   where xx.ID_MOVE_OLD = a.ID_MOVE) and
                               not exists
                                 (select 1
                                    from EXPO_STRNMOVES yy
                                   where yy.ID_MOVE_NEW = a.ID_MOVE) and
                               a.ID_MOVE = b.ID_MOVE and
                               a.ORDROWNUM = b.ORDROWNUM and
                               a.DT_KT != b.DT_KT and
                               b.ID_EXPO = c.ID_EXPO and
                               c.TYPE_EXPO = d.TYPE_EXPO and
                               d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash;

                        bRet  := nAmount <= recConf.HOWMANYTIMES;
                      elsif ( bCashKT and
                             recConf.MODE_CHECK = 7 ) then
                        select count( 1 ),
                               nvl( sum( a.SYS_AMOUNT ), 0 )
                          into nAmount,
                               nAmount1
                          from EXPO_MOVES a,
                               EXPO_MOVES b,
                               Schema_GPSys.EXPOSITION c
                         where a.ID_EXPO = nIDExpo and
                               a.SCH_DATE = MemoHeadData.SCH_DATE and
                               a.DT_KT = 'K' and
                               not exists
                                 (select 1
                                    from EXPO_STRNMOVES xx
                                   where xx.ID_MOVE_OLD = a.ID_MOVE) and
                               not exists
                                 (select 1
                                    from EXPO_STRNMOVES yy
                                   where yy.ID_MOVE_NEW = a.ID_MOVE) and
                               a.ID_MOVE = b.ID_MOVE and
                               a.ORDROWNUM = b.ORDROWNUM and
                               a.DT_KT != b.DT_KT and
                               b.ID_EXPO = c.ID_EXPO and
                               c.ID_CUST > 0 and
                               c.ID_CUST != nIDCust;

                        bRet      := not ( nAmount > recConf.HOWMANYTIMES and
                                          nAmount1 > recConf.AMOUNT );

                        if ( bRet ) then
                          dPrev     := Schema_GPSys.OraGPSys.SeekWorkDay( MemoHeadData.SCH_DATE - 1, false );

                          select count( 1 ),
                                 nvl( sum( a.SYS_AMOUNT ), 0 )
                            into nAmount,
                                 nAmount1
                            from EXPO_MOVES a,
                                 EXPO_MOVES b,
                                 Schema_GPSys.EXPOSITION c
                           where a.ID_EXPO = nIDExpo and
                                 a.SCH_DATE = dPrev and
                                 a.DT_KT = 'K' and
                                 not exists
                                   (select 1
                                      from EXPO_STRNMOVES xx
                                     where xx.ID_MOVE_OLD = a.ID_MOVE) and
                                 not exists
                                   (select 1
                                      from EXPO_STRNMOVES yy
                                     where yy.ID_MOVE_NEW = a.ID_MOVE) and
                                 a.ID_MOVE = b.ID_MOVE and
                                 a.ORDROWNUM = b.ORDROWNUM and
                                 a.DT_KT != b.DT_KT and
                                 b.ID_EXPO = c.ID_EXPO and
                                 c.ID_CUST > 0 and
                                 c.ID_CUST != nIDCust;

                          bRet      := not ( nAmount > recConf.HOWMANYTIMES and
                                            nAmount1 > recConf.AMOUNT );
                        end if;
                      end if;

                      exit when not bRet;
                    end loop;
                  end if;

                  if ( not bRet ) then
                    Schema_RA.GPC_RA.RespSetErrorText( 'AML - Недопустима операция на каса', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                  end if;
                end;
              elsif ( not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 27 ) ) then
                bRet  := false;
                Schema_RA.GPC_RA.RespSetErrorText( 'Недопустима операция на каса', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
              end if;
            end if;
          end if;

          $end
          --
          MemoRows.extend;
          MemoRows( MemoRows.count )  := MemoRow;

          if ( bRet and
              aRowValues.count >= 18 ) then
            bRet      := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 12 ), BdgRows( MemoRows.count ).BDG_CLASSIF ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 13 ), BdgRows( MemoRows.count ).BDG_FUNCTION ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 14 ), BdgRows( MemoRows.count ).BDG_OBJECT ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 15 ), BdgRows( MemoRows.count ).DT_KT ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 16 ), BdgRows( MemoRows.count ).CODVAL ) and
                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 17 ), BdgRows( MemoRows.count ).AMOUNT ) and
                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 18 ), BdgRows( MemoRows.count ).SYS_AMOUNT );

            if ( BdgRows( MemoRows.count ).DT_KT = 'D' ) then
              BdgRows( MemoRows.count ).VALIOR  := MemoRow.VALIOR_DT;
            else
              BdgRows( MemoRows.count ).VALIOR  := MemoRow.VALIOR_KT;
            end if;
          end if;

          if ( bRet and
              aRowValues.count >= 20 ) then
            bRet      := Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 19 ), AddRows( MemoRows.count ).AMOUNT_DT ) and
                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 20 ), AddRows( MemoRows.count ).AMOUNT_KT );

            if ( bRet ) then
              if ( nvl( AddRows( MemoRows.count ).AMOUNT_DT, 0 ) != 0 ) then
                AddRows( MemoRows.count ).ADDCLASSIF_DT  := '_';
                AddRows( MemoRows.count ).VALIOR_DT      := MemoRow.VALIOR_DT;
              end if;

              if ( nvl( AddRows( MemoRows.count ).AMOUNT_KT, 0 ) != 0 ) then
                AddRows( MemoRows.count ).ADDCLASSIF_KT  := '_';
                AddRows( MemoRows.count ).VALIOR_KT      := MemoRow.VALIOR_KT;
              end if;
            end if;
          end if;

          recCostRow                  := Schema_GPSys.recCostOpers( null, null, null, null, null, null, null );

          if ( bRet and
              aRowValues.count >= 22 ) then
            bRet      := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 21 ), recCostRow.ID_Kind ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 22 ), recCostRow.ID_Cost );
          end if;

          if ( bRet ) then
            recCostRow.ID_EXPO_DT  := MemoRow.EXPO_DT;
          end if;

          CostRows.extend;
          CostRows( CostRows.count )  := recCostRow;
          --
          -- Last aRowValues.count = 24 = MemoRow.TECHNOLOGY_DATA
          --
          nState                      := nRowType;
        elsif ( nRowType = 3 ) then
          bRet      := nState in (2, 3, 4) and
                       aRowValues.count >= 2 and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), CodVal ) and
                       Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 2 ), nRate );

          if ( bRet ) then
            bRet      := nRate =
                           round( case
                                    when CodVal = Schema_GPSys.OraGPSys.BGN_CURR and
                                         Schema_GPSys.OraGPSys.GetSysCurrByDate( MemoHeadData.SCH_DATE ) = Schema_GPSys.OraGPSys.EUR_CURR then
                                      Schema_GPSys.OraGPSys.BGN2EURRate
                                    else
                                      Schema_GPSys.XchgRates.GetXchgRate( MemoHeadData.UNIQCODE,
                                                                          MemoHeadData.SCH_DATE,
                                                                          CodVal,
                                                                          Schema_GPSys.OraGPSys.GetSysCurrByDate( MemoHeadData.SCH_DATE ),
                                                                          Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                         )
                                  end,
                                  8
                                 );

            if ( not bRet ) then
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'RATE';
              aParams( 1 ).ML_VALUE  := to_char( nRate );
              aParams( 2 ).ML_NAME   := 'CURRENCY';
              aParams( 2 ).ML_VALUE  := CodVal;
              Schema_RA.GPC_RA.RespSetErrorText( 'Несъответствие на фиксинга $RATE$ за $CURRENCY$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
            end if;
          end if;

          nState    := nRowType;
        elsif ( nRowType = 4 ) then
          MemoRow                     := Schema_GPSys.TDealOper( null, null, null, null, null, null, null, null, null, null, null, null, null, null );
          bRet                        := nState in (1, 4) and
                                         aRowValues.count >= 26 and
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), MemoRow.DEAL_TYPE ) and
                                         --
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), rExpoDT.ID_CUST ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), rExpoDT.SYNT_CODE ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), rExpoDT.CODVAL ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 5 ), rExpoDT.AN1 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), rExpoDT.AN2 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 7 ), rExpoDT.AN3 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 8 ), rExpoDT.AN4 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 9 ), rExpoDT.AN5 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 10 ), rExpoDT.AN6 ) and
                                         --
                                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 11 ), MemoRow.AMOUNT_DT ) and
                                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 12 ), MemoRow.AMOUNT_KT ) and
                                         --
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 13 ), rExpoKT.ID_CUST ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 14 ), rExpoKT.SYNT_CODE ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 15 ), rExpoKT.CODVAL ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 16 ), rExpoKT.AN1 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 17 ), rExpoKT.AN2 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 18 ), rExpoKT.AN3 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 19 ), rExpoKT.AN4 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 20 ), rExpoKT.AN5 ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 21 ), rExpoKT.AN6 ) and
                                         --
                                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 22 ), MemoRow.VALIOR_DT ) and
                                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 23 ), MemoRow.VALIOR_KT ) and
                                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 24 ), MemoRow.MAIN_EXPO ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 25 ), MemoRow.REFERENCIA ) and
                                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 26 ), MemoRow.USE_TAXES ) and
                                         ( ( not aRowValues.exists( 27 ) ) or
                                          Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 27 ), MemoRow.AMOUNT_SYS ) ) and
                                         ( ( not aRowValues.exists( 28 ) ) or
                                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 28 ), rExpoDT.EXPO_NAME ) ) and
                                         ( ( not aRowValues.exists( 29 ) ) or
                                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 29 ), rExpoDT.EXPO_TEXT ) ) and
                                         ( ( not aRowValues.exists( 30 ) ) or
                                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 30 ), rExpoKT.EXPO_NAME ) ) and
                                         ( ( not aRowValues.exists( 31 ) ) or
                                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 31 ), rExpoKT.EXPO_TEXT ) );
          --
          MemoRows.extend;

          --
          begin
            select *
              into rExpo
              from Schema_GPSys.EXPOSITION
             where ID_EXPO = (select nvl( min( ID_EXPO ), 0 )
                                from Schema_GPSys.EXPOSITION
                               where UNIQCODE = MemoHeadData.UNIQCODE and
                                     ID_CUST = rExpoDT.ID_CUST and
                                     SYNT_CODE = rExpoDT.SYNT_CODE and
                                     nvl( AN1, '~' ) = nvl( rExpoDT.AN1, '~' ) and
                                     nvl( AN2, '~' ) = nvl( rExpoDT.AN2, '~' ) and
                                     nvl( AN3, '~' ) = nvl( rExpoDT.AN3, '~' ) and
                                     nvl( AN4, '~' ) = nvl( rExpoDT.AN4, '~' ) and
                                     nvl( AN5, '~' ) = nvl( rExpoDT.AN5, '~' ) and
                                     nvl( AN6, '~' ) = nvl( rExpoDT.AN6, '~' ));

            if ( rExpo.CODVAL = rExpoDT.CODVAL and
                rExpo.STATUS = 'T' ) then
              MemoRow.EXPO_DT  := rExpo.ID_EXPO;
            else
              MemoRow.EXPO_DT  := -1;
            end if;
          exception
            when no_data_found then
              MemoRow.EXPO_DT  := 0;
          end;

          if ( bRet and
              MemoRow.EXPO_DT = 0 and
              ( bPreView or
               rExpoDT.EXPO_NAME is not null ) ) then
            rExpoOpenData                        := null;
            rExpoOpenData.TypeExpo               := Schema_GPSys.OraGPSys.My_To_number( to_char( MemoHeadData.UNIQCODE ) || rpad( rExpoDT.SYNT_CODE, 4, '0' ) || '0' );
            rExpoOpenData.IDCust                 := rExpoDT.ID_CUST;
            rExpoOpenData.UniqCode               := MemoHeadData.UNIQCODE;
            rExpoOpenData.CodVal                 := rExpoDT.CODVAL;
            rExpoOpenData.SyntCode               := rExpoDT.SYNT_CODE;
            rExpoOpenData.AN1                    := rExpoDT.AN1;
            rExpoOpenData.AN2                    := rExpoDT.AN2;
            rExpoOpenData.AN3                    := rExpoDT.AN3;
            rExpoOpenData.AN4                    := rExpoDT.AN4;
            rExpoOpenData.AN5                    := rExpoDT.AN5;
            rExpoOpenData.AN6                    := rExpoDT.AN6;

            if ( rExpoDT.AN1 is not null ) then
              rExpoOpenData.AnFeat  := rExpoDT.AN1;

              if ( rExpoDT.AN2 is not null ) then
                rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoDT.AN2;

                if ( rExpoDT.AN3 is not null ) then
                  rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoDT.AN3;

                  if ( rExpoDT.AN4 is not null ) then
                    rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoDT.AN4;

                    if ( rExpoDT.AN5 is not null ) then
                      rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoDT.AN5;

                      if ( rExpoDT.AN6 is not null ) then
                        rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoDT.AN6;
                      end if;
                    end if;
                  end if;
                end if;
              end if;
            end if;

            rExpoOpenData.ExpoName               := nvl( rExpoDT.EXPO_NAME, Schema_Expo.Cmd_Expo_Add.GetAccName( MemoHeadData.UNIQCODE, rExpoDT.SYNT_CODE ) );
            rExpoOpenData.ExpoText               := rExpoDT.EXPO_TEXT;
            arrExpoOpenDataDT( MemoRows.count )  := rExpoOpenData;
            MemoRow.EXPO_DT                      := 9999999999;
          end if;

          --
          begin
            select *
              into rExpo
              from Schema_GPSys.EXPOSITION
             where ID_EXPO = (select nvl( min( ID_EXPO ), 0 )
                                from Schema_GPSys.EXPOSITION
                               where UNIQCODE = MemoHeadData.UNIQCODE and
                                     ID_CUST = rExpoKT.ID_CUST and
                                     SYNT_CODE = rExpoKT.SYNT_CODE and
                                     nvl( AN1, '~' ) = nvl( rExpoKT.AN1, '~' ) and
                                     nvl( AN2, '~' ) = nvl( rExpoKT.AN2, '~' ) and
                                     nvl( AN3, '~' ) = nvl( rExpoKT.AN3, '~' ) and
                                     nvl( AN4, '~' ) = nvl( rExpoKT.AN4, '~' ) and
                                     nvl( AN5, '~' ) = nvl( rExpoKT.AN5, '~' ) and
                                     nvl( AN6, '~' ) = nvl( rExpoKT.AN6, '~' ));

            if ( rExpo.CODVAL = rExpoKT.CODVAL and
                rExpo.STATUS = 'T' ) then
              MemoRow.EXPO_KT  := rExpo.ID_EXPO;
            else
              MemoRow.EXPO_KT  := -1;
            end if;
          exception
            when no_data_found then
              MemoRow.EXPO_KT  := 0;
          end;

          if ( bRet and
              MemoRow.EXPO_KT = 0 and
              ( bPreView or
               rExpoKT.EXPO_NAME is not null ) ) then
            rExpoOpenData                        := null;
            rExpoOpenData.TypeExpo               := Schema_GPSys.OraGPSys.My_To_number( to_char( MemoHeadData.UNIQCODE ) || rpad( rExpoKT.SYNT_CODE, 4, '0' ) || '0' );
            rExpoOpenData.IDCust                 := rExpoKT.ID_CUST;
            rExpoOpenData.UniqCode               := MemoHeadData.UNIQCODE;
            rExpoOpenData.CodVal                 := rExpoKT.CODVAL;
            rExpoOpenData.SyntCode               := rExpoKT.SYNT_CODE;
            rExpoOpenData.AN1                    := rExpoKT.AN1;
            rExpoOpenData.AN2                    := rExpoKT.AN2;
            rExpoOpenData.AN3                    := rExpoKT.AN3;
            rExpoOpenData.AN4                    := rExpoKT.AN4;
            rExpoOpenData.AN5                    := rExpoKT.AN5;
            rExpoOpenData.AN6                    := rExpoKT.AN6;

            if ( rExpoKT.AN1 is not null ) then
              rExpoOpenData.AnFeat  := rExpoKT.AN1;

              if ( rExpoKT.AN2 is not null ) then
                rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoKT.AN2;

                if ( rExpoKT.AN3 is not null ) then
                  rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoKT.AN3;

                  if ( rExpoKT.AN4 is not null ) then
                    rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoKT.AN4;

                    if ( rExpoKT.AN5 is not null ) then
                      rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoKT.AN5;

                      if ( rExpoKT.AN6 is not null ) then
                        rExpoOpenData.AnFeat  := rExpoOpenData.AnFeat || ',' || rExpoKT.AN6;
                      end if;
                    end if;
                  end if;
                end if;
              end if;
            end if;

            rExpoOpenData.ExpoName               := nvl( rExpoKT.EXPO_NAME, Schema_Expo.Cmd_Expo_Add.GetAccName( MemoHeadData.UNIQCODE, rExpoKT.SYNT_CODE ) );
            rExpoOpenData.ExpoText               := rExpoKT.EXPO_TEXT;
            arrExpoOpenDataKT( MemoRows.count )  := rExpoOpenData;
            MemoRow.EXPO_KT                      := 9999999999;
          end if;

          --
          MemoRows( MemoRows.count )  := MemoRow;
          nState                      := nRowType;

          --
          if ( bRet and
              MemoRow.EXPO_DT <= 0 ) then
            if ( not bError ) then
              Schema_GPSys.GPC_Parser.RespAddArray( 66, true );
              bError  := true;
            end if;

            sName     := nvl( Schema_Cust.GPC_Customs.FLD2Name( null, 'ID', rExpoDT.ID_CUST ), Schema_Expo.Cmd_Expo_Add.GetAccName( MemoHeadData.UNIQCODE, rExpoDT.SYNT_CODE ) );
            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rExpoDT.ID_CUST, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.SYNT_CODE, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.CODVAL, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.AN1, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.AN2, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.AN3, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.AN4, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.AN5, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoDT.AN6, sData ) and
                         Schema_GPSys.GPC_Parser.WriteInteger( MemoRow.EXPO_DT, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( 'D', sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( sName, sData );
            Schema_GPSys.GPC_Parser.RespAddRow( sData, true );
          end if;

          if ( bRet and
              MemoRow.EXPO_KT <= 0 ) then
            if ( not bError ) then
              Schema_GPSys.GPC_Parser.RespAddArray( 66, true );
              bError  := true;
            end if;

            sName     := nvl( Schema_Cust.GPC_Customs.FLD2Name( null, 'ID', rExpoKT.ID_CUST ), Schema_Expo.Cmd_Expo_Add.GetAccName( MemoHeadData.UNIQCODE, rExpoKT.SYNT_CODE ) );
            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rExpoKT.ID_CUST, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.SYNT_CODE, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.CODVAL, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.AN1, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.AN2, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.AN3, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.AN4, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.AN5, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( rExpoKT.AN6, sData ) and
                         Schema_GPSys.GPC_Parser.WriteInteger( MemoRow.EXPO_KT, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( 'K', sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( sName, sData );
            Schema_GPSys.GPC_Parser.RespAddRow( sData, true );
          end if;
        end if;
      end if;

      ii        := aParamEntities3D.next( ii );
    end loop;

    if ( bRet and
        ( not bError ) ) then
      if ( bSchCredLawInterest ) then
        bRet  := SchCredLawInterest( MemoHeadData, MemoRows, BdgRows, bPreView, bZBalSpot, bCashReq, bCommit, AddRows, CostRows );
      else
        ii        := arrExpoOpenDataDT.first;

        while ( ii is not null and
               bRet ) loop
          begin
            select ID_EXPO
              into arrExpoOpenDataDT( ii ).IDExpo
              from Schema_GPSys.EXPOSITION
             where ID_EXPO = (select nvl( min( ID_EXPO ), 0 )
                                from Schema_GPSys.EXPOSITION
                               where UNIQCODE = arrExpoOpenDataDT( ii ).UNIQCODE and
                                     ID_CUST = arrExpoOpenDataDT( ii ).IDCUST and
                                     SYNT_CODE = arrExpoOpenDataDT( ii ).SYNTCODE and
                                     nvl( AN1, '~' ) = nvl( arrExpoOpenDataDT( ii ).AN1, '~' ) and
                                     nvl( AN2, '~' ) = nvl( arrExpoOpenDataDT( ii ).AN2, '~' ) and
                                     nvl( AN3, '~' ) = nvl( arrExpoOpenDataDT( ii ).AN3, '~' ) and
                                     nvl( AN4, '~' ) = nvl( arrExpoOpenDataDT( ii ).AN4, '~' ) and
                                     nvl( AN5, '~' ) = nvl( arrExpoOpenDataDT( ii ).AN5, '~' ) and
                                     nvl( AN6, '~' ) = nvl( arrExpoOpenDataDT( ii ).AN6, '~' ));
          exception
            when no_data_found then
              bRet  := Schema_GPSys.Cmd_HeadExpo.OpenExposition( arrExpoOpenDataDT( ii ) );
          end;

          if ( bRet ) then
            MemoRows( ii ).EXPO_DT  := arrExpoOpenDataDT( ii ).IDExpo;

            if ( instr( Schema_GPSys.OraGPSys.GetIniValue( arrExpoOpenDataDT( ii ).UNIQCODE, 'Счетоводство', 'Синтетики Каси', null ), arrExpoOpenDataDT( ii ).SyntCode ) > 0 ) then
              bDummy  := Schema_RA.GPC_Nom.GenerateNomPackageByUC( 'EXPOS_CASH' );
            elsif ( instr( Schema_GPSys.OraGPSys.GetIniValue( arrExpoOpenDataDT( ii ).UNIQCODE, 'Счетоводство', 'Синтетики Банки', null ), arrExpoOpenDataDT( ii ).SyntCode ) >
                     0 ) then
              bDummy  := Schema_RA.GPC_Nom.GenerateNomPackageByUC( 'EXPOS_BANK' );
            end if;
          end if;

          ii  := arrExpoOpenDataDT.next( ii );
        end loop;

        ii        := arrExpoOpenDataKT.first;

        while ( ii is not null and
               bRet ) loop
          begin
            select ID_EXPO
              into arrExpoOpenDataKT( ii ).IDExpo
              from Schema_GPSys.EXPOSITION
             where ID_EXPO = (select nvl( min( ID_EXPO ), 0 )
                                from Schema_GPSys.EXPOSITION
                               where UNIQCODE = arrExpoOpenDataKT( ii ).UNIQCODE and
                                     ID_CUST = arrExpoOpenDataKT( ii ).IDCUST and
                                     SYNT_CODE = arrExpoOpenDataKT( ii ).SYNTCODE and
                                     nvl( AN1, '~' ) = nvl( arrExpoOpenDataKT( ii ).AN1, '~' ) and
                                     nvl( AN2, '~' ) = nvl( arrExpoOpenDataKT( ii ).AN2, '~' ) and
                                     nvl( AN3, '~' ) = nvl( arrExpoOpenDataKT( ii ).AN3, '~' ) and
                                     nvl( AN4, '~' ) = nvl( arrExpoOpenDataKT( ii ).AN4, '~' ) and
                                     nvl( AN5, '~' ) = nvl( arrExpoOpenDataKT( ii ).AN5, '~' ) and
                                     nvl( AN6, '~' ) = nvl( arrExpoOpenDataKT( ii ).AN6, '~' ));
          exception
            when no_data_found then
              bRet  := Schema_GPSys.Cmd_HeadExpo.OpenExposition( arrExpoOpenDataKT( ii ) );
          end;

          if ( bRet ) then
            MemoRows( ii ).EXPO_KT  := arrExpoOpenDataKT( ii ).IDExpo;

            if ( instr( Schema_GPSys.OraGPSys.GetIniValue( arrExpoOpenDataKT( ii ).UNIQCODE, 'Счетоводство', 'Синтетики Каси', null ), arrExpoOpenDataKT( ii ).SyntCode ) > 0 ) then
              bDummy  := Schema_RA.GPC_Nom.GenerateNomPackageByUC( 'EXPOS_CASH' );
            elsif ( instr( Schema_GPSys.OraGPSys.GetIniValue( arrExpoOpenDataKT( ii ).UNIQCODE, 'Счетоводство', 'Синтетики Банки', null ), arrExpoOpenDataKT( ii ).SyntCode ) >
                     0 ) then
              bDummy  := Schema_RA.GPC_Nom.GenerateNomPackageByUC( 'EXPOS_BANK' );
            end if;
          end if;

          ii  := arrExpoOpenDataKT.next( ii );
        end loop;

        bRet      := bRet and
                     SaveMemoOrder( MemoHeadData, MemoRows, BdgRows, bPreView, bZBalSpot, bCashReq, bCommit, AddRows, CostRows );
      end if;

      if ( bPreView ) then
        rollback;
      else
        if ( bCommit ) then
          if ( bRet ) then
            commit;
          else
            rollback;
          end if;
        end if;
      end if;
    end if;

    if ( bRet ) then
      Schema_RA.GPC_RA.EndTempResponces;
    else
      Schema_RA.GPC_RA.BegTempResponces;
    end if;

    if ( bOldState1 is not null ) then
      bPreView  := Expo.SetSkipLimit( EXPO.ModeSkip_DueAmn, bOldState1 );
    end if;

    if ( bOldState2 is not null ) then
      bPreView  := Expo.SetSkipLimit( EXPO.ModeSkip_CardHOLD, bOldState2 );
    end if;

    return bRet;
  end CmdSaveMemoOrder;

  --------------------------------------------------------------------------------
  function IniStornoFirstOrgText
    return boolean is
  begin
    if ( bIniStornoFirstOrgText is null ) then
      bIniStornoFirstOrgText      := nvl( Schema_GPSys.OraGPSys.OracleBoolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All,
                                                                                                                     'EXPOSITION',
                                                                                                                     'STORNO_FIRST_ORGTEXT',
                                                                                                                     null
                                                                                                                    )
                                                                              ),
                                          Schema_GPSys.OraSys.VerBankTokuda or
                                          Schema_GPSys.OraSys.VerBankDBank
                                         );
    end if;

    return bIniStornoFirstOrgText;
  end IniStornoFirstOrgText;

  --------------------------------------------------------------------------------
  function StornoMemoOrder(
    nID_Move       in out integer,
    nSch_UniqCode  in     integer,
    dSch_Date      in     date,
    nSch_Doc       in     integer,
    sOrdText       in     varchar2,
    dNewDate       in out date,
    nNewDoc        in out integer,
    nNewMove       in out integer,
    bChkOper       in     boolean,
    bTuneDate      in     boolean default false
  )
    return boolean is
    oDoc           Schema_GPSys.DocSysIQType;
    rExpoOpenData  Schema_GPSys.Cmd_HeadExpo.recExpoOpenData;
    iqQ            Schema_GPSys.OraGPSys.EmpCurTyp;
    aClosedExpo    Schema_GPSys.OraGPSys.aNumbers;
    aOpenedExpo    Schema_GPSys.OraGPSys.aNumbers;
    aWakeUpExpo    Schema_GPSys.OraGPSys.aNumbers;
    aExpo          Schema_GPSys.OraGPSys.aNumbers;
    aListFr        Schema_GPSys.OraGPSys.aStrings;
    aListTo        Schema_GPSys.OraGPSys.aStrings;
    rMoves         EXPO_MOVES%rowtype;
    rMovesText     EXPO_MOVE_TEXT%rowtype;
    rParams        Schema_GPSys.CMD_PARAMS%rowtype;
    nSaveOper      integer := 0;
    oOpers         Schema_GPSys.TblSchOper;
    bDummy         boolean;
    bRet           boolean;
    nDepence       integer := 0;
    kk             integer;
    nSaldo         number;
    dSchDate       date;
    dCurrDate      date := Schema_RA.GPC_Tools.GetSchDate( null );
    dDummy         date;
    sError         varchar2( 200 );
    cDummy         varchar2( 16 );
    aParams        Schema_RA.GPC_RA.tblErrParams;
  begin
    if ( nvl( nID_Move, 0 ) != 0 ) then
      open iqQ for
        select ID_MOVE,
               SCH_DATE,
               SCH_DOC,
               DOC_NUM,
               CH_STAMP
          from EXPO_MOVES
         where ID_MOVE = nID_Move;
    else
      open iqQ for
        select ID_MOVE,
               SCH_DATE,
               SCH_DOC,
               DOC_NUM,
               CH_STAMP
          from EXPO_MOVES
         where UNIQCODE = nSch_UniqCode and
               SCH_DATE = dSCH_DATE and
               SCH_DOC = nSCH_DOC;
    end if;

    fetch iqQ
      into rMoves.ID_MOVE, rMoves.SCH_DATE, rMoves.SCH_DOC, rMoves.DOC_NUM, rMoves.CH_STAMP;

    bRet      := iqQ%found and
                 rMoves.DOC_NUM is not null and
                 rMoves.CH_STAMP is not null;

    close iqQ;

    if ( bRet and
        nvl( rMoves.DOC_NUM, 0 ) > 0 ) then
      bRet  := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoMoves, rMoves.ID_MOVE );

      if ( bRet ) then
        oOpers    := Schema_GPSys.TblSchOper( );
        nID_Move  := rMoves.ID_MOVE;
        bRet      := not Expo.IsStorno( rMoves.ID_MOVE );

        if ( bRet ) then
          bRet      := CALCLIH.ChkLihvi4Storno( rMoves.ID_MOVE ) and
                       Cmd_LoanTaxes.ChkAmortSch4Storno( rMoves.ID_MOVE );

          if ( bRet and
              Schema_GPSys.ORASYS.bModule_Cards and
              ( not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 12 ) ) ) then
            execute immediate 'select count(1) from Schema_Cards.UBVISA_TRANSACS where ID_MOVE=:1' into kk using rMoves.ID_MOVE;

            bRet  := kk = 0;

            if ( not bRet ) then
              Schema_RA.GPC_RA.RespSetErrorText( 'Ордер подаден от СУКАРТ не се допуска да бъде сторниран',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG
                                                );
            end if;
          end if;

          $if ( Schema_GPSys.OraSys.VerCredito or
               Schema_GPSys.OraSys.VerFPMH ) $then
          select count( 1 )
            into kk
            from LOAN_DRAWNS
           where ID_MOVE = rMoves.ID_MOVE and
                 nvl( ID_MOVE1, 0 ) > 0 and
                 STATUS = Loans.LoanStat_Active;

          bRet      := kk = 0;

          if ( not bRet ) then
            Schema_RA.GPC_RA.RespSetErrorText( 'Ордер за усвояване по които е извършено плащане, не се допуска да бъде сторниран',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG
                                              );
          end if;

          $end
          if ( bRet ) then
            select /*+ LEADING( a b c d ) USE_NL( b c d )*/
                  nvl( max( d.CH_OPER ), 0 )
              into kk
              from EXPO_MOVE_TEXT d,
                   Schema_GPSys.EXPOTYPES c,
                   Schema_GPSys.EXPOSITION b,
                   EXPO_MOVES a
             where a.ID_MOVE = rMoves.ID_MOVE and
                   a.VALIOR != dCurrDate and
                   b.ID_EXPO = a.ID_EXPO and
                   c.TYPE_EXPO = b.TYPE_EXPO and
                   c.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash and
                   d.ID_MOVE = a.ID_MOVE;

            bRet      := kk = 0 or
                         ( kk != Schema_RA.GPC_RA.nCurrentUserID and
                          Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 21 ) );

            if ( not bRet ) then
              Schema_RA.GPC_RA.RespSetErrorText( 'Сторниране на МО в който е засегната каса с вальор',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG
                                                );
            end if;
          end if;

          if ( bRet and
              not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 27 ) ) then
            select count( * )
              into kk
              from CASH_ORDREG
             where ID_MOVE = rMoves.ID_MOVE;

            bRet  := kk = 0;

            if ( not bRet ) then
              Schema_RA.GPC_RA.RespSetErrorText( 'Не се допуска сторниране на касов ордер', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
            end if;
          end if;

          if ( bRet and
              bChkOper and
              Schema_GPSys.ORASYS.bModule_Payments ) then
            execute immediate 'begin :1 := Schema_Payments.Pays2.GetPaymentIDByCashIDMove( :2 ); end;' using out kk, in rMoves.ID_MOVE;

            bRet  := nvl( kk, 0 ) = 0;

            if ( not bRet ) then
              Schema_RA.GPC_RA.RespSetErrorText( 'Сторниране на МО засягащ касов превод', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
            end if;
          end if;

          if ( bRet ) then
            Expo.SetAllSkipLimit( true );
            Schema_DocSys.DocSys.GetJoinedDoc( rMoves.CH_STAMP, bDummy, oDoc );

            for rec in (  select a.depence,
                                 a.nv,
                                 a.dv,
                                 a.sv,
                                 a.mvc,
                                 a.mva,
                                 b.PARAM_NAME
                            from table( cast( oDoc as Schema_GPSys.DocSysIQType ) ) a,
                                 Schema_GPSys.CMD_PARAMS b
                           where b.CMD_NAME like 'SaveMemoOrder%' and
                                 b.DOC_TYPE = a.DocType and
                                 b.FIELD_TYPE = a.FieldType
                        order by 1,
                                 7 ) loop
              if ( rec.PARAM_NAME in ('EXPO_DT', 'MONEY_DT', 'MONEY_KT', 'EXPO_KT', 'VALIOR') and
                  nDepence != rec.depence ) then
                oOpers.extend;
                oOpers( oOpers.last )  := Schema_GPSys.TSchOper( null, null, null, null, null, null, null, null, null, null, null, null );
                nDepence               := rec.depence;
              end if;

              if ( rec.PARAM_NAME = '1.1' ) then
                rMoves.UNIQCODE  := rec.nv;
              elsif ( rec.PARAM_NAME = '1.5' ) then
                rMovesText.ID_CUST  := rec.nv;
              elsif ( rec.PARAM_NAME = '2.1' ) then
                nSaveOper  := rec.nv;

                if ( bRet and
                    bChkOper ) then
                  bRet      := rec.nv in
                                 ( Sch_Free,
                                  Sch_FreeTaxes,
                                  Sch_FreeTrans,
                                  Sch_AvanLihvi,
                                  Sch_AvanTranLih,
                                  Sch_CommLih,
                                  Sch_Lihvi,
                                  Sch_TranLih,
                                  Sch_TaxLihvi,
                                  Sch_PlanLihvi,
                                  Sch_CloseExpo,
                                  Sch_CredPadej,
                                  Sch_Change,
                                  Sch_RateDiffer,
                                  Sch_Preocenka,
                                  Sch_CredPogasiava,
                                  Sch_CredEngagement,
                                  Sch_ZBalPpv,
                                  Sch_RusoPensons,
                                  Sch_ExternSch,
                                  Sch_OpenExpo,
                                  Sch_TRCardM,
                                  Sch_TRCardC,
                                  Sch_TRCardV,
                                  Sch_Budget,
                                  Sch_TRCardIncaso,
                                  Sch_InsPolicyAgentOtchNach,
                                  Sch_ClearOborot,
                                  Sch_ImportOborot,
                                  Sch_EmployerSalary,
                                  Sch_Comens,
                                  Sch_LawInterest,
                                  Sch_CredSudebni,
                                  Sch_CredPriznati,
                                  Sch_DealingPlanLih,
                                  Sch_POSOper_Borica_Our,
                                  Sch_POSOper_Maestro_Our,
                                  Sch_POSOper_Mastercard_Our,
                                  Sch_POSOper_MCVisa_Othr,
                                  Sch_POSOper_DtCard_Othr,
                                  Sch_SharesBondPreoc,
                                  Sch_SharesBondAmort,
                                  Sch_SharesBondProv,
                                  Sch_MMarketNostroProv,
                                  Sch_SharesPlanLih,
                                  Sch_FreeLeasing,
                                  Sch_EndSaldo,
                                  Sch_OverdueTax,
                                  Sch_TEU_Settlement,
                                  Sch_ExpLoanDrawns );

                  if ( not bRet ) then
                    begin
                      select OPER_TYPE
                        into rec.nv
                        from PODELENIA_OPER_TYPE
                       where OPER_TYPE = rec.nv;

                      bRet  := true;
                    exception
                      when no_data_found then
                        bRet  := false;
                    end;

                    Schema_RA.GPC_RA.RespSetErrorText( 'Типът на ордера не допуска да бъде сторниран', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                  end if;
                end if;
              elsif ( rec.PARAM_NAME = '2.8' ) then
                if ( nSaveOper in (Sch_CloseExpo, Sch_ClearOborot, Sch_ImportOborot) and
                    nvl( rec.nv, 0 ) > 0 ) then
                  aClosedExpo( aClosedExpo.count + 1 )  := rec.nv;

                  if ( nSaveOper = Sch_CloseExpo ) then
                    aWakeUpExpo( aWakeUpExpo.count + 1 )  := rec.nv;
                  end if;

                  nSaveOper                             := 0;
                elsif ( nSaveOper = Sch_OpenExpo and
                       nvl( rec.nv, 0 ) > 0 ) then
                  aOpenedExpo( aOpenedExpo.count + 1 )  := rec.nv;
                  nSaveOper                             := 0;
                end if;
              elsif ( rec.PARAM_NAME = 'EXPO_DT' ) then
                oOpers( oOpers.last ).ExpoDt  := rec.nv;

                select nvl( max( ID_MOVE_LAST ), 0 )
                  into kk
                  from Schema_GPSys.EXPO_UNIQCODE_LOG
                 where ID_EXPO = rec.nv;

                bRet                          := kk < rMoves.ID_MOVE;

                if ( bRet ) then
                  select nvl( max( ID_MOVE_LAST ), 0 )
                    into kk
                    from Schema_GPSys.EXPO_CODVAL_LOG
                   where ID_EXPO = rec.nv;

                  bRet  := kk < rMoves.ID_MOVE;

                  if ( not bRet ) then
                    aParams.delete;
                    aParams( 1 ).ML_NAME   := 'EXPO_NV';
                    aParams( 1 ).ML_VALUE  := to_char( rec.nv );
                    Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $EXPO_NV$ e превалутирана', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
                  end if;
                else
                  aParams.delete;
                  aParams( 1 ).ML_NAME   := 'EXPO_NV';
                  aParams( 1 ).ML_VALUE  := to_char( rec.nv );
                  Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $EXPO_NV$ e прехвърлена в ново поделение',
                                                     Schema_GPSys.MLng.ctxAccounting,
                                                     Schema_GPSys.MLng.lngBG,
                                                     aParams
                                                    );
                end if;
              elsif ( rec.PARAM_NAME = 'MONEY_DT' ) then
                oOpers( oOpers.last ).AmountDt  := -rec.mva;
              elsif ( rec.PARAM_NAME = 'MONEY_KT' ) then
                oOpers( oOpers.last ).AmountKt  := -rec.mva;
              elsif ( rec.PARAM_NAME = 'EXPO_KT' ) then
                oOpers( oOpers.last ).ExpoKt  := rec.nv;

                select nvl( max( ID_MOVE_LAST ), 0 )
                  into kk
                  from Schema_GPSys.EXPO_UNIQCODE_LOG
                 where ID_EXPO = rec.nv;

                bRet                          := kk < rMoves.ID_MOVE;

                if ( bRet ) then
                  select nvl( max( ID_MOVE_LAST ), 0 )
                    into kk
                    from Schema_GPSys.EXPO_CODVAL_LOG
                   where ID_EXPO = rec.nv;

                  bRet  := kk < rMoves.ID_MOVE;

                  if ( not bRet ) then
                    aParams.delete;
                    aParams( 1 ).ML_NAME   := 'EXPO_NV';
                    aParams( 1 ).ML_VALUE  := to_char( rec.nv );
                    Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $EXPO_NV$ e превалутирана', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
                  end if;
                else
                  aParams.delete;
                  aParams( 1 ).ML_NAME   := 'EXPO_NV';
                  aParams( 1 ).ML_VALUE  := to_char( rec.nv );
                  Schema_RA.GPC_RA.RespSetErrorText( 'Експозиция $EXPO_NV$ e прехвърлена в ново поделение',
                                                     Schema_GPSys.MLng.ctxAccounting,
                                                     Schema_GPSys.MLng.lngBG,
                                                     aParams
                                                    );
                end if;
              elsif ( rec.PARAM_NAME = 'VALIOR' ) then
                oOpers( oOpers.last ).Valior  := rec.dv;
                bRet                          := not GetINI_CheckPeriodValior or
                                                 Schema_RA.GPC_Tools.Chk4ValidPeriod( rMoves.UNIQCODE, oOpers( oOpers.last ).Valior, Schema_RA.GPC_Tools.defValidPeriodType_Valior );

                if ( not bRet ) then
                  Schema_RA.GPC_RA.RespSetErrorText( 'Некоректен вальор', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                end if;
              elsif ( rec.PARAM_NAME = 'SYS_MONEY' ) then
                oOpers( oOpers.last ).SysAmount  := -rec.mva;
              elsif ( rec.PARAM_NAME = 'OPER_TYPE' ) then
                oOpers( oOpers.last ).OperType  := rec.nv;
              elsif ( rec.PARAM_NAME = 'ROW_NUM' ) then
                oOpers( oOpers.last ).OrdRowNum  := rec.nv;
              end if;

              exit when not bRet;
            end loop;

            for ii in 1 .. 2 loop
              if ( ii = 2 ) then
                aExpo  := aWakeUpExpo;
              else
                aExpo  := aOpenedExpo;
              end if;

              for jj in 1 .. aExpo.count loop
                for recExpo in ( select distinct ID_EXPO
                                   from (with Rel as
                                                (select a.ID_OBJ1
                                                   from OBJ_GROUP_REL a
                                                  where a.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                                        a.ID_OBJ2 = aExpo( jj ) and
                                                        a.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit)
                                         ( select ID_OBJ1 as ID_EXPO
                                             from Rel
                                          union
                                          select ID_OBJ1 as ID_EXPO
                                            from OBJ_GROUP_REL
                                           where TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                                 ID_OBJ1 = aExpo( jj ) and
                                                 TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit )
                                         union all
                                         select b.ID_OBJ2 as ID_EXPO
                                           from OBJ_GROUP_REL b
                                          where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                                b.ID_OBJ1 in (select ID_OBJ1 as MAINEXPO
                                                                from Rel) and
                                                b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit
                                         union all
                                         select b.ID_OBJ2 as ID_EXPO
                                           from OBJ_GROUP_REL b
                                          where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                                b.ID_OBJ1 = aExpo( jj ) and
                                                b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit) ) loop
                  if ( ii = 2 ) then
                    Schema_GPSys.OraGPSys.Add2UniqArr( aWakeUpExpo, recExpo.ID_EXPO );
                  else
                    Schema_GPSys.OraGPSys.Add2UniqArr( aOpenedExpo, recExpo.ID_EXPO );
                  end if;
                end loop;
              end loop;
            end loop;

            if ( bRet ) then
              bRet      := Schema_RA.GPC_Tools.AccountingAllowed( rMoves.UNIQCODE ) and
                           ( not Schema_GPSys.OraGPSys.IsSysObjLocked( Schema_GPSys.OraGPSys.LockTypeSchOpers, rMoves.UNIQCODE ) ) and
                           ( not Schema_GPSys.OraGPSys.IsSysObjLocked( Schema_GPSys.OraGPSys.LockTypeSchOpers, -1 ) );

              if ( bRet ) then
                if ( dNewDate is null ) then
                  dNewDate  := dCurrDate;
                end if;

                if ( bTuneDate ) then
                  dNewDate  := greatest( rMoves.SCH_DATE, dNewDate );
                end if;

                bRet  := rMoves.SCH_DATE <= dNewDate;

                if ( bRet ) then
                  if ( dNewDate != dCurrDate ) then
                    dSchDate  := Schema_DocSys.DOCSYS.GetWorkDay( dNewDate, dDummy );
                    bRet      := dSchDate is not null and
                                 dNewDate = dSchDate;
                  end if;

                  if ( bRet ) then
                    bRet  := Schema_RA.GPC_Tools.Chk4ValidPeriod( rMoves.UNIQCODE, dNewDate, Schema_RA.GPC_Tools.defValidPeriodType_SchDate );
                  end if;

                  if ( bRet ) then
                    if ( aClosedExpo.count > 0 and
                        ( not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 14 ) ) ) then
                      bRet  := rMoves.SCH_DATE = dNewDate;

                      if ( not bRet ) then
                        Schema_RA.GPC_RA.RespSetErrorText( 'Сторниране закриване на сметка направено с дата по-малка от текущата',
                                                           Schema_GPSys.MLng.ctxAccounting,
                                                           Schema_GPSys.MLng.lngBG
                                                          );
                      end if;
                    end if;

                    if ( bRet and
                        aOpenedExpo.count > 0 ) then
                      for jj in aOpenedExpo.first .. aOpenedExpo.last loop
                        bRet  := Calclih.GetPlanLihvi( aOpenedExpo( jj ) ) = 0;

                        if ( not bRet ) then
                          Schema_RA.GPC_RA.RespSetErrorText( 'Налични текущи лихви', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                        end if;

                        exit when not bRet;
                      end loop;
                    end if;

                    if ( bRet ) then
                      bRet  := Expo.ChkExpoOpers( sError, nNewMove, rMoves.UNIQCODE, rMovesText.ID_CUST, oOpers, dNewDate, rMoves.ID_MOVE, aClosedExpo );

                      if ( bRet ) then
                        for ii in oDoc.first .. oDoc.last loop
                          open iqQ for
                            select PARAM_NAME
                              from Schema_GPSys.CMD_PARAMS
                             where CMD_NAME like 'SaveMemoOrder%' and
                                   DOC_TYPE = oDoc( ii ).DocType and
                                   FIELD_TYPE = oDoc( ii ).FieldType;

                          fetch iqQ
                            into rParams.PARAM_NAME;

                          if ( iqQ%found ) then
                            if ( rParams.PARAM_NAME = '1.ID_MOVE' ) then
                              oDoc( ii ).nv       := nNewMove;
                              rMovesText.ID_MOVE  := oDoc( ii ).nv;
                            elsif ( rParams.PARAM_NAME = '1.2' ) then
                              if ( sOrdText is not null and
                                  not IniStornoFirstOrgText( ) ) then
                                oDoc( ii ).sv  := trim( sOrdText ) || chr( 13 );
                              elsif ( oDoc( ii ).sv is not null ) then
                                oDoc( ii ).sv  := oDoc( ii ).sv || chr( 13 );
                              end if;

                              cDummy                 := substr( oDoc( ii ).sv, -1, 1 );

                              if ( cDummy ~= chr( 13 ) ) then
                                oDoc( ii ).sv  := oDoc( ii ).sv || chr( 13 );
                              end if;

                              if ( Schema_GPSys.OraSys.VerBankTransact or
                                  Schema_GPSys.OraSys.VerPaynetics ) then
                                Schema_GPSys.MLng.SetLanguage( Schema_GPSys.MLng.lngEN );
                              end if;

                              aParams.delete;
                              aParams( 1 ).ML_NAME   := 'SCH_DOC';
                              aParams( 1 ).ML_VALUE  := to_char( rMoves.SCH_DOC );
                              aParams( 2 ).ML_NAME   := 'SCH_DATE';
                              aParams( 2 ).ML_VALUE  := to_char( rMoves.SCH_DATE, 'dd.mm.yyyy' );
                              oDoc( ii ).sv          := oDoc( ii ).sv ||
                                                        ' ' ||
                                                        Schema_GPSys.MLng.Str2( 'Сторно на документ номер: $SCH_DOC$ от дата: $SCH_DATE$',
                                                                                Schema_GPSys.MLng.ctxLoans,
                                                                                Schema_GPSys.MLng.lngBG,
                                                                                aParams
                                                                               );

                              if ( Schema_GPSys.OraSys.VerBankTransact or
                                  Schema_GPSys.OraSys.VerPaynetics ) then
                                Schema_GPSys.MLng.RevertLanguage;
                              end if;

                              if ( sOrdText is not null and
                                  IniStornoFirstOrgText( ) ) then
                                cDummy         := substr( oDoc( ii ).sv, -1, 1 );

                                if ( cDummy ~= chr( 13 ) ) then
                                  oDoc( ii ).sv  := oDoc( ii ).sv || chr( 13 );
                                end if;

                                oDoc( ii ).sv  := oDoc( ii ).sv || trim( sOrdText );
                              end if;

                              rMovesText.ORD_TEXT    := oDoc( ii ).sv;
                            elsif ( rParams.PARAM_NAME in ('1.3', 'SCH_DATE') ) then
                              oDoc( ii ).dv  := dNewDate;
                            elsif ( rParams.PARAM_NAME = '1.SCH_DOC' ) then
                              nNewDoc  := Expo.GetExpoNumberW( Expo.SchDocCntName( rMoves.UNIQCODE, dNewDate ) );
                              bRet     := nvl( nNewDoc, 0 ) > 0;

                              if ( bRet ) then
                                oDoc( ii ).nv  := nNewDoc;
                              end if;
                            elsif ( rParams.PARAM_NAME = '1.4' ) then
                              oDoc( ii ).nv  := rMoves.ID_MOVE;
                            elsif ( rParams.PARAM_NAME = '1.CHOPER' ) then
                              oDoc( ii ).nv       := Schema_RA.GPC_RA.nCurrentUserID;
                              rMovesText.CH_OPER  := oDoc( ii ).nv;
                            elsif ( rParams.PARAM_NAME in ('2.3', '2.4') ) then
                              oDoc( ii ).nv  := -oDoc( ii ).nv;
                            elsif ( rParams.PARAM_NAME in ('MONEY_DT', 'MONEY_KT', 'SYS_MONEY') ) then
                              oDoc( ii ).mva  := -oDoc( ii ).mva;
                            elsif ( rParams.PARAM_NAME = '1.6' ) then
                              rMovesText.SYS_TEXT  := oDoc( ii ).sv;
                            elsif ( rParams.PARAM_NAME = '1.7' ) then
                              rMovesText.ORIGIN  := oDoc( ii ).sv;
                            elsif ( rParams.PARAM_NAME = '1.8' ) then
                              oDoc( ii ).sv        := to_char( sysdate, Schema_GPSys.GPC_Parser.FORMAT_TRANSPORT_DATETIME );
                              rMovesText.DATETIME  := oDoc( ii ).sv;
                            elsif ( rParams.PARAM_NAME = '1.9' ) then
                              if ( Schema_GPSys.OraGPSys.SplitRanges( oDoc( ii ).sv, aListFr, aListTo, false ) ) then
                                oDoc( ii ).sv  := aListFr( 1 ); -- this is for field RecMoveText.FOLDER_NMBR to obtain automaticaly new value
                              end if;
                            end if;
                          end if;

                          close iqQ;

                          exit when not bRet;
                        end loop;

                        if ( bRet ) then
                          rMovesText.DOC_NUM    := null;
                          rMovesText.CH_STAMP   := null;
                          rMovesText.OPER_DATE  := null;

                          insert into EXPO_MOVE_TEXT
                               values rMovesText;
                        end if;

                        if ( bRet ) then
                          kk    := Schema_DocSys.DOCSYS_SaveInIQ.SaveDoc( oDoc, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work );
                          bRet  := kk = 0;

                          if ( not bRet ) then
                            aParams.delete;
                            aParams( 1 ).ML_NAME   := 'ERR';
                            aParams( 1 ).ML_VALUE  := to_char( kk );
                            Schema_RA.GPC_RA.RespSetErrorText( 'SaveDocInIQ() error: $ERR$', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngEN, aParams );
                          end if;
                        end if;

                        if ( bRet ) then
                          bRet  := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoMoves, nNewMove );

                          if ( bRet ) then
                            for ii in 1 .. 2 loop
                              if ( ii = 2 ) then
                                aExpo  := aWakeUpExpo;
                              else
                                aExpo  := aOpenedExpo;
                              end if;

                              for jj in 1 .. aExpo.count loop
                                if ( ii = 2 or
                                    ( Expo.GetExpoHotSaldo( aExpo( jj ), nSaldo ) and
                                     nSaldo = 0 ) ) then
                                  rExpoOpenData.IDExpo      := aExpo( jj );
                                  rExpoOpenData.Technology  := Schema_GPSys.HeadExpo.IDExpo2Technology( aExpo( jj ) );

                                  if ( ii = 2 ) then
                                    rExpoOpenData.CloseDate  := to_date( '01.01.3000', 'dd.mm.yyyy' );
                                  else
                                    rExpoOpenData.CloseDate  := dNewDate;
                                  end if;

                                  bRet                      := Schema_GPSys.Cmd_HeadExpo.ChangeExpo( rExpoOpenData, null, nNewMove );
                                end if;

                                exit when not bRet;
                              end loop;

                              exit when not bRet;
                            end loop;

                            if ( bRet ) then
                              insert into BDG_MOVES(
                                            ID_MOVE,
                                            ORDROWNUM,
                                            UNIQCODE,
                                            BDG_CLASSIF,
                                            BDG_FUNCTION,
                                            BDG_OBJECT,
                                            DT_KT,
                                            CODVAL,
                                            AMOUNT,
                                            SYS_AMOUNT,
                                            VALIOR,
                                            SCH_DATE
                                          )
                                select nNewMove,
                                       ORDROWNUM,
                                       UNIQCODE,
                                       BDG_CLASSIF,
                                       BDG_FUNCTION,
                                       BDG_OBJECT,
                                       DT_KT,
                                       CODVAL,
                                       -AMOUNT,
                                       -SYS_AMOUNT,
                                       VALIOR,
                                       dNewDate
                                  from BDG_MOVES
                                 where ID_MOVE = rMoves.ID_MOVE;

                              insert into ADD_MOVES(
                                            ID_MOVE,
                                            ORDROWNUM,
                                            UNIQCODE,
                                            ADD_CLASSIF,
                                            ID_EXPO,
                                            DT_KT,
                                            AMOUNT,
                                            VALIOR,
                                            SCH_DATE
                                          )
                                select nNewMove,
                                       ORDROWNUM,
                                       UNIQCODE,
                                       ADD_CLASSIF,
                                       ID_EXPO,
                                       DT_KT,
                                       -AMOUNT,
                                       VALIOR,
                                       dNewDate
                                  from ADD_MOVES
                                 where ID_MOVE = rMoves.ID_MOVE;

                              update TAXES_REGISTER
                                 set TAX_STATUS  = decode( INT_CODE, null, Taxes.TaxStateNoSch, Taxes.TaxStateRefused )
                               where ID_MOVE = rMoves.ID_MOVE;

                              for recInv in ( select ID_INVOICE
                                                from (select ID_INVOICE
                                                        from TAXES_REGISTER
                                                       where ID_MOVE = rMoves.ID_MOVE and
                                                             nvl( ID_INVOICE, 0 ) != 0
                                                      union
                                                      select ID_INVOICE
                                                        from TAXES_TAXLIST
                                                       where SCH_ID_MOVE = rMoves.ID_MOVE and
                                                             nvl( ID_INVOICE, 0 ) != 0) ) loop
                                bRet  := Schema_Invoices.CMD_INVOICES_ADD.AnullVatTaxSchInvoice( recInv.ID_INVOICE );
                                exit when not bRet;
                              end loop;

                              update COST_REGISTER
                                 set STATUS  = 'F'
                               where ID_MOVE = rMoves.ID_MOVE;

                              delete from CASH_ORDERS
                                    where ID_MOVE = rMoves.ID_MOVE;

                              $if ( Schema_GPSys.OraSys.bModule_PaymentsTEU ) $then
                              update Schema_Payments.TEU_INCSETTLSCH_PERIOD_HEADER
                                 set STATUS  = Schema_Payments.Cmd_TEU_MID.defSettlStatus_New
                               where ID_MOVE = rMoves.ID_MOVE;
                            $end
                            end if;
                          else
                            aParams.delete;
                            aParams( 1 ).ML_NAME   := 'NEW_MOVE';
                            aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( nNewMove );
                            Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи движение $NEW_MOVE$',
                                                               Schema_GPSys.MLng.ctxAccounting,
                                                               Schema_GPSys.MLng.lngBG,
                                                               aParams
                                                              );
                          end if;
                        end if;
                      elsif ( sError is not null ) then
                        Schema_RA.GPC_RA.RespSetErrorText_NoML( sError );
                      end if;
                    end if;
                  else
                    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректна счетоводна дата', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                  end if;
                else
                  Schema_RA.GPC_RA.RespSetErrorText( 'Сторниране с дата по-малка от счетоводната дата на ордера',
                                                     Schema_GPSys.MLng.ctxAccounting,
                                                     Schema_GPSys.MLng.lngBG
                                                    );
                end if;
              else
                Schema_RA.GPC_RA.RespSetErrorText( 'В момента има забрана за операции', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
              end if;
            end if;

            Expo.SetAllSkipLimit( false );
          end if;
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ID_MOVE';
          aParams( 1 ).ML_VALUE  := to_char( rMoves.ID_MOVE );
          Schema_RA.GPC_RA.RespSetErrorText( 'Ордерът вече е сторниран $ID_MOVE$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
        end if;

        bDummy    := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoMoves, rMoves.ID_MOVE );
      else
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_MOVE';
        aParams( 1 ).ML_VALUE  := to_char( rMoves.ID_MOVE );
        Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи движение: $ID_MOVE$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
      end if;
    else
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма такъв ордер', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
    end if;

    return bRet;
  end StornoMemoOrder;

  --------------------------------------------------------------------------------
  function CmdStornoMemoOrder(
    aParamEntities3D  in Schema_GPSys.GPC_Parser.taParamEntities3D,
    bResponce         in boolean default true
  )
    return boolean is
    aRowValues   Schema_GPSys.GPC_Parser.taParamStrings;
    RecExpoMove  EXPO_MOVES%rowtype;
    RecMoveText  EXPO_MOVE_TEXT%rowtype;
    dNewDate     date;
    nNewDoc      integer;
    nNewMove     integer;
    ii           integer := 1;
    sOrdText     varchar2( 4000 );
    cDummy       varchar2( 16 );
    bDummy       boolean;
    bChkOper     boolean := true;
    bRet         boolean;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), RecExpoMove.ID_MOVE ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), RecExpoMove.UNIQCODE ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), RecExpoMove.SCH_DATE ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), RecExpoMove.SCH_DOC ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 5 ), dNewDate ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), sOrdText );

    if ( aRowValues.exists( 7 ) ) then
      bRet      := bRet and
                   Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 7 ), bChkOper );
    end if;

    if ( aRowValues.exists( 10 ) ) then
      bRet      := bRet and
                   Schema_GPSys.GPC_Parser.ReadString( aRowValues( 8 ), RecMoveText.FOLDER_MODE ) and
                   Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 9 ), RecMoveText.FOLDER_DATE ) and
                   Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 10 ), RecMoveText.FOLDER_NMBR );
    end if;

    if ( bRet and
        not ( RecExpoMove.ID_MOVE > 0 or
             ( RecExpoMove.UNIQCODE > 0 and
              RecExpoMove.SCH_DATE is not null and
              RecExpoMove.SCH_DOC > 0 ) ) ) then
      bRet      := RecMoveText.FOLDER_MODE is not null and
                   RecMoveText.FOLDER_DATE is not null and
                   RecMoveText.FOLDER_NMBR > 0;

      if ( bRet ) then
        begin
          select distinct ID_MOVE
            into RecExpoMove.ID_MOVE
            from EXPO_MOVE_TEXT
           where FOLDER_MODE = RecMoveText.FOLDER_MODE and
                 FOLDER_DATE = RecMoveText.FOLDER_DATE and
                 FOLDER_NMBR = RecMoveText.FOLDER_NMBR;
        exception
          when others then
            bRet  := false;
            Schema_RA.GPC_RA.RespSetErrorText( 'Няма такъв мемориален ордер', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
        end;
      end if;
    end if;

    if ( bRet ) then
      bRet  := StornoMemoOrder( RecExpoMove.ID_MOVE, RecExpoMove.UNIQCODE, RecExpoMove.SCH_DATE, RecExpoMove.SCH_DOC, sOrdText, dNewDate, nNewDoc, nNewMove, bChkOper );
    end if;

    if ( bRet ) then
      if ( bResponce ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 1 );
        cDummy      := null;
        bDummy      := Schema_GPSys.GPC_Parser.WriteInteger( ii, cDummy ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( nNewMove, cDummy );
        Schema_GPSys.GPC_Parser.RespAddRow( cDummy );
      else
        Schema_GPSys.GPC_Parser.nGlobalNumber  := nNewMove;
      end if;
    end if;

    if ( bRet ) then
      if ( nvl( RecExpoMove.ID_MOVE, 0 ) != 0 ) then
        for rec in ( select distinct b.ID_MOVE
                       from EXPO_GROUPMOVES a,
                            EXPO_GROUPMOVES b
                      where a.ID_MOVE = RecExpoMove.ID_MOVE and
                            b.ID_GROUP = a.ID_GROUP and
                            b.ID_MOVE != RecExpoMove.ID_MOVE ) loop
          bRet  := StornoMemoOrder( rec.ID_MOVE, null, null, null, sOrdText, dNewDate, nNewDoc, nNewMove, bChkOper );

          if ( bRet ) then
            if ( bResponce ) then
              cDummy      := null;
              ii          := ii + 1;
              bDummy      := Schema_GPSys.GPC_Parser.WriteInteger( ii, cDummy ) and
                             Schema_GPSys.GPC_Parser.WriteInteger( nNewMove, cDummy );
              Schema_GPSys.GPC_Parser.RespAddRow( cDummy );
            else
              Schema_GPSys.GPC_Parser.nGlobalNumber  := nNewMove;
            end if;
          end if;

          exit when not bRet;
        end loop;
      end if;
    end if;

    if ( bResponce ) then
      if ( bRet ) then
        commit;
      else
        rollback;
      end if;
    end if;

    return bRet;
  end CmdStornoMemoOrder;

  --------------------------------------------------------------------------------
  function PreViewExpoState( oOpers in Schema_GPSys.TblSchOper )
    return boolean is
    aExpo      Schema_GPSys.OraGPSys.aNumbers;
    nBegDt     number;
    nBegKt     number;
    nEndDt     number;
    nEndKt     number;
    nSaldo     number;
    nTypeExpo  pls_integer;
    sData      varchar2( 4000 );
    sIBAN      varchar2( 40 );
    bRet       boolean := true;
    aParams    Schema_RA.GPC_RA.tblErrParams;

    cursor qCur( oOp in Schema_GPSys.TblSchOper ) is
      select distinct EXPODT
        from table( cast( oOp as Schema_GPSys.TblSchOper ) )
      union
      select distinct EXPOKT
        from table( cast( oOp as Schema_GPSys.TblSchOper ) );

  begin
    open qCur( oOpers );

    fetch qCur
      bulk collect into aExpo;

    close qCur;

    if ( aExpo.count > 0 ) then
      Schema_GPSys.GPC_Parser.RespAddArray( 3, true );

      for ii in aExpo.first .. aExpo.last loop
        begin
          select TYPE_EXPO
            into nTypeExpo
            from Schema_GPSys.EXPOSITION
           where ID_EXPO = aExpo( ii );
        exception
          when no_data_found then
            bRet                   := false;
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'EXPO';
            aParams( 1 ).ML_VALUE  := to_char( aExpo( ii ) );
            Schema_RA.GPC_RA.RespSetErrorText( 'Няма експозиция с номер $EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
        end;

        if ( bRet and
            Schema_RA.GPC_SS.CheckRightExpo_VSaldo_CUser( nTypeExpo, aExpo( ii ) ) ) then
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( aExpo( ii ), sData ) and
                       LoadExpoData( aExpo( ii ), sData, sIBAN ) and
                       Expo.GetExpoHotOborot( aExpo( ii ), nBegDt, nBegKt ) and
                       Schema_GPSys.GPC_Parser.WriteAmount( nBegDt, sData ) and
                       Schema_GPSys.GPC_Parser.WriteAmount( nBegKt, sData );

          if ( bRet ) then
            select sum( decode( a.EXPODT, aExpo( ii ), a.AMOUNTDT, 0 ) ),
                   sum( decode( a.EXPOKT, aExpo( ii ), a.AMOUNTKT, 0 ) )
              into nEndDt,
                   nEndKt
              from table( cast( oOpers as Schema_GPSys.TblSchOper ) ) a
             where aExpo( ii ) in (a.EXPODT, a.EXPOKT);

            nEndDt    := nvl( nEndDt, 0 );
            nEndKt    := nvl( nEndKt, 0 );
            nSaldo    := Expo.ExpoSumAvailable( aExpo( ii ), to_date( '01.01.3000', 'dd.mm.yyyy' ), true ) - nEndDt + nEndKt;
            nEndDt    := nBegDt + nEndDt;
            nEndKt    := nBegKt + nEndKt;
            --
            bRet      := Schema_GPSys.GPC_Parser.WriteAmount( nEndDt, sData ) and
                         Schema_GPSys.GPC_Parser.WriteAmount( nEndKt, sData ) and
                         Schema_GPSys.GPC_Parser.WriteAmount( nSaldo, sData );
          end if;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData, true );
          end if;
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end PreViewExpoState;

  --------------------------------------------------------------------------------
  function SavePreViewResults(
    oOpers    in Schema_GPSys.TblSchOper,
    CostRows  in Schema_GPSys.tblCostOpers,
    nIDCust   in pls_integer
  )
    return boolean is
    rCustData  Schema_Cust.GPC_Customs.recCustData;
    sData      varchar2( 4000 );
    sIBAN      varchar2( 40 );
    bRet       boolean := false;
  begin
    Schema_GPSys.GPC_Parser.RespAddArray( 2, true );

    for ii in oOpers.first .. oOpers.last loop
      sData     := null;
      bRet      := LoadExpoData( oOpers( ii ).ExpoDt, sData, sIBAN ) and
                   LoadExpoData( oOpers( ii ).ExpoKt, sData, sIBAN ) and
                   Schema_GPSys.GPC_Parser.WriteInteger( oOpers( ii ).OperType, sData ) and
                   Schema_GPSys.GPC_Parser.WriteInteger( oOpers( ii ).ExpoDt, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( oOpers( ii ).ValDt, sData ) and
                   Schema_GPSys.GPC_Parser.WriteAmount( oOpers( ii ).AmountDt, sData ) and
                   Schema_GPSys.GPC_Parser.WriteAmount( oOpers( ii ).AmountKt, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( oOpers( ii ).ValKt, sData ) and
                   Schema_GPSys.GPC_Parser.WriteInteger( oOpers( ii ).ExpoKt, sData ) and
                   Schema_GPSys.GPC_Parser.WriteDate( oOpers( ii ).Valior, sData ) and
                   Schema_GPSys.GPC_Parser.WriteAmount( oOpers( ii ).SysAmount, sData );

      if ( CostRows.exists( ii ) ) then
        bRet      := bRet and
                     Schema_GPSys.GPC_Parser.WriteString( CostRows( ii ).ID_kind, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( CostRows( ii ).ID_cost, sData );
      else
        bRet      := bRet and
                     Schema_GPSys.GPC_Parser.WriteString( null, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( null, sData );
      end if;

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddRow( sData, true );
      end if;

      exit when not bRet;
    end loop;

    bRet      := bRet and
                 PreViewExpoState( oOpers );

    if ( bRet ) then
      if ( nvl( nIDCust, 0 ) != 0 ) then
        rCustData         := null;
        rCustData.IDCust  := nIDCust;

        if ( Schema_Cust.GPC_Customs.GetCustData( rCustData ) ) then
          Schema_GPSys.GPC_Parser.RespAddTable( 4 );
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rCustData.IDCust, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.CLITYPE, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.FTYPE, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.FIRSTNAME, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.SecndName, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.LASTNAME, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.EGN, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.BULSTAT, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.SECTORNA, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.OTRASLOVA, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.DANNUMBER, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.LICHNAKARTA, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.COUNTRY, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.POSTBOX, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.TELEFON, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.LATINNAME, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.LATINADDR, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.ADDRESS, sData );
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        end if;
      end if;

      commit;
    else
      rollback;
    end if;

    return bRet;
  end SavePreViewResults;

  --------------------------------------------------------------------------------
  function CheckCostData(
    CostOpers  in     Schema_GPSys.tblCostOpers,
    sError     in out varchar2
  )
    return boolean is
    sExpoCost    varchar2( 100 );
    sCostKind    varchar2( 100 );
    sCostCenter  varchar2( 100 );
    sExpoCode    Schema_GPSys.EXPOSITION.SYNT_CODE%type;
    bRet         boolean := true;
    ii           pls_integer;
  begin
    sExpoCost  := Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'SCH_COSTGROUP', null );

    if ( sExpoCost is not null and
        CostOpers.exists( CostOpers.first ) and
        CostOpers.count > 0 ) then
      for rec in ( select /*+ LEADING( B ) USE_NL( A ) */
                         a.EXPO_CODE,
                          b.Id_Kind,
                          b.ID_cost
                     from Schema_GPSys.EXPOSITION a,
                          table( cast( CostOpers as Schema_GPSys.tblCostOpers ) ) b
                    where a.ID_EXPO = b.ID_EXPO_DT ) loop
        if ( substr( rec.EXPO_CODE, 1, length( sExpoCost ) ) = sExpoCost ) then
          if ( rec.ID_KIND is null or
              rec.ID_COST is null ) then
            bRet        := false;
            sError      := Schema_GPSys.MLng.Str2( 'Непопълнени полета: "Вид на разход", "Разходен център"',
                                                   Schema_GPSys.MLng.ctxAccounting,
                                                   Schema_GPSys.MLng.lngBG
                                                  );
          end if;
        elsif ( rec.ID_KIND is not null or
               rec.ID_COST is not null ) then
          bRet        := false;
          sError      := Schema_GPSys.MLng.Str2( 'Попълнени полета: "Вид на разход","Разходен център" за неподходяща експозиция',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG
                                                );
        end if;
      end loop;
    end if;

    return bRet;
  end CheckCostData;

  --------------------------------------------------------------------------------
  function GenerateMemoOrder(
    HeadData       in out nocopy Schema_GPSys.tMemoOrder,
    DealOper       in            Schema_GPSys.tblDealOper,
    bPreView       in            boolean default false,
    nInQueue       in            integer default Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work,
    bZBalSpot      in            boolean default true,
    bCashReq       in            boolean default false,
    nIDExpo4Zapor  in            integer default null,
    BdgOpers       in            tblBdgOpers default tBdgOpers,
    AddOpers       in            tblAddOpers default tAddOpers,
    CostOpers      in            Schema_GPSys.tblCostOpers default tCostOpers,
    RegTaxes       in            Taxes.tblRegTaxes default Taxes.tRegTaxes,
    bAutoUseExpo   in            boolean default false
  )
    return boolean is
    bRet            boolean;
    bExistBudget    boolean;
    oOpers          Schema_GPSys.TblSchOper;
    oDoc            Schema_GPSys.DocSysIQType;
    BdgRows         tblBdgOpers;
    AddRows         tblAddOpers;
    TaxesRows       Taxes.tblRegTaxes;
    tExpoMoveAdd    tblExpoMoveAdd;
    aColl           Schema_GPSys.VarcharCollectionType;
    CostRows        Schema_GPSys.tblCostOpers;
    aClosedExpo     Schema_GPSys.OraGPSys.aNumbers;
    aTaxedExpo      Schema_GPSys.OraGPSys.aNumbers;
    aListFr         Schema_GPSys.OraGPSys.aStrings;
    aListTo         Schema_GPSys.OraGPSys.aStrings;
    RecMoveText     EXPO_MOVE_TEXT%rowtype;
    recPrevDeal     EXPO_DEAL_RATE%rowtype;
    dDummy          date;
    dSchDate        date;
    IDMove          integer;
    nRateType       integer;
    nCurrent        integer;
    CloseExpo       integer;
    nOpersID        integer;
    ii              integer;
    jj              integer;
    nDocID          integer := 3;
    nFixing         number;
    nOperSum        number;
    sError          varchar2( 200 ) := Schema_GPSys.MLng.Str2( 'Грешка при генериране на документа', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
    sAllFolderData  varchar2( 100 );
    aParams         Schema_RA.GPC_RA.tblErrParams;
  begin
    ClearGlExpoMoveRec( );
    oDoc                                := Schema_GPSys.DocSysIQType( );
    oOpers                              := Schema_GPSys.TblSchOper( );
    BdgRows                             := BdgOpers;
    AddRows                             := AddOpers;
    CostRows                            := CostOpers;
    TaxesRows                           := RegTaxes;

    if ( bAutoUseExpo ) then
      select distinct ID_EXPO
        bulk collect into aTaxedExpo
        from (select /*+ LEADING( a b c ) USE_NL( b c ) */
                    a.EXPO_DT as ID_EXPO
                from Schema_GPSys.EXPOTYPES c,
                     Schema_GPSys.EXPOSITION b,
                     table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
               where b.ID_EXPO = a.EXPO_DT and
                     b.ID_CUST > 0 and
                     c.TYPE_EXPO = b.TYPE_EXPO and
                     c.BASE_TYPE in (Schema_GPSys.HeadExpo.ExpoCurrent, Schema_GPSys.HeadExpo.ExpoOther) and
                     c.ACTPASS = 'P'
              union all
              select /*+ LEADING( a b c ) USE_NL( b c ) */
                    a.EXPO_KT as ID_EXPO
                from Schema_GPSys.EXPOTYPES c,
                     Schema_GPSys.EXPOSITION b,
                     table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
               where b.ID_EXPO = a.EXPO_KT and
                     b.ID_CUST > 0 and
                     c.TYPE_EXPO = b.TYPE_EXPO and
                     c.BASE_TYPE in (Schema_GPSys.HeadExpo.ExpoCurrent, Schema_GPSys.HeadExpo.ExpoOther) and
                     c.ACTPASS = 'P');
    end if;

    -- до сега се е пълнило при съсздаване на HeadData, ма ми се струва доста тъпо да се пълни на 100 места вместо на едно ;-)
    HeadData.DateTime                   := sysdate;
    bRet                                := HeadData.SCH_DATE = Schema_RA.GPC_Tools.GetSchDate( HeadData.UNIQCODE );
    bRet                                := nvl( bRet, false );

    if ( not bRet ) then
      dSchDate  := Schema_DocSys.DOCSYS.GetWorkDay( HeadData.SCH_DATE, dDummy );
      bRet      := dSchDate is not null and
                   HeadData.SCH_DATE = dSchDate;
    end if;

    bRet                                := bRet and
                                           Schema_RA.GPC_Tools.Chk4ValidPeriod( HeadData.UNIQCODE, HeadData.SCH_DATE, Schema_RA.GPC_Tools.defValidPeriodType_SchDate );

    if ( bRet ) then
      bRet      := bPreView or
                   ( Schema_RA.GPC_Tools.AccountingAllowed( HeadData.UNIQCODE ) and
                    ( not Schema_GPSys.OraGPSys.IsSysObjLocked( Schema_GPSys.OraGPSys.LockTypeSchOpers, HeadData.UNIQCODE, true ) ) and
                    ( not Schema_GPSys.OraGPSys.IsSysObjLocked( Schema_GPSys.OraGPSys.LockTypeSchOpers, -1, true ) ) );

      if ( bRet ) then
        bRet  := CheckCostData( CostRows, sError );

        if ( bRet ) then
          if ( DealOper.count > 0 ) then
            for rec in ( select a.EXPO_KT
                           from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                          where a.DEAL_TYPE not in (Sch_Preocenka, Sch_ClearOborot, Sch_ImportOborot, Sch_AvanLihvi, Sch_Lihvi) and
                                a.AMOUNT_KT > 0 and
                                exists
                                  (select 1
                                     from EXPO_LIMITS b
                                    where b.ID_EXPO = a.EXPO_KT and
                                          b.STATUS = Expo.ZaporStat_Active and
                                          b.TYPE_LIMIT = Expo.ExpoLimit_ForbiddenKT) and
                                rownum < 2 ) loop
              bRet    := false;
              --
              --aParams.delete;
              --aParams( 1 ).ML_NAME   := 'ID_EXPO';
              --aParams( 1 ).ML_VALUE  := rec.EXPO_KT;
              --sError                 := Schema_GPSys.MLng.Str2( 'Забранен КТ по експозиция номер: $ID_EXPO$',
              --                                                  Schema_GPSys.MLng.ctxAccounting,
              --                                                  Schema_GPSys.MLng.lngBG,
              --                                                  aParams
              --                                                 );
              sError  := Schema_GPSys.MLng.Str2( 'Сметката има наложена пълна блокировка по K/t', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
            end loop;

            if ( bRet and
                GetINI_CheckPeriodValior ) then
              for kk in 1 .. DealOper.count loop
                if ( not ( Schema_RA.GPC_Tools.Chk4ValidPeriod( HeadData.UNIQCODE, DealOper( kk ).VALIOR_DT, Schema_RA.GPC_Tools.defValidPeriodType_Valior ) and
                          Schema_RA.GPC_Tools.Chk4ValidPeriod( HeadData.UNIQCODE, DealOper( kk ).VALIOR_KT, Schema_RA.GPC_Tools.defValidPeriodType_Valior ) ) ) then
                  bRet    := false;
                  sError  := Schema_GPSys.MLng.Str2( 'Некоректен вальор', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                  exit;
                end if;
              end loop;
            end if;

            if ( bRet ) then
              HeadData.ORIGIN  := trim( HeadData.ORIGIN );

              if ( HeadData.ORIGIN is not null ) then
                -- purvata pozicia e za ORIGIN( ako stoinostite sa 'T' ili 'F' ), a ostanalite pozicii se polzvat za FOLDER_MODE !!!
                if ( upper( substr( HeadData.ORIGIN, 1, 1 ) ) in ('T', 'F') ) then
                  RecMoveText.FOLDER_MODE  := substr( HeadData.ORIGIN, 2 );
                  HeadData.ORIGIN          := upper( substr( HeadData.ORIGIN, 1, 1 ) );
                else
                  RecMoveText.FOLDER_MODE  := HeadData.ORIGIN;
                  HeadData.ORIGIN          := null;
                end if;

                sAllFolderData  := RecMoveText.FOLDER_MODE;

                if ( Schema_GPSys.OraGPSys.SplitRanges( sAllFolderData, aListFr, aListTo, false ) ) then
                  RecMoveText.FOLDER_MODE  := aListFr( 1 );
                  RecMoveText.FOLDER_DATE  := Schema_GPSys.OraGPSys.BegOfMonth( HeadData.SCH_DATE );

                  if ( aListFr.count >= 2 and
                      aListFr( 2 ) is not null and
                      trim( aListFr( 2 ) ) <> '0' ) then
                    RecMoveText.FOLDER_NMBR  := aListFr( 2 );

                    select count( 1 )
                      into ii
                      from EXPO_MOVES b,
                           EXPO_MOVE_TEXT a
                     where a.FOLDER_MODE = RecMoveText.FOLDER_MODE and
                           a.FOLDER_DATE = RecMoveText.FOLDER_DATE and
                           a.FOLDER_NMBR = RecMoveText.FOLDER_NMBR and
                           b.ID_MOVE = a.ID_MOVE and
                           b.UNIQCODE = HeadData.UNIQCODE;

                    bRet                     := ii = 0;

                    if ( bRet ) then
                      Expo.SetMaxExpoNumber( 'Folder_' || RecMoveText.FOLDER_MODE || '_' || to_char( HeadData.UNIQCODE, 'FM0999999999' ) || to_char( RecMoveText.FOLDER_DATE, 'yyyymmdd' ),
                                             RecMoveText.FOLDER_NMBR,
                                             true
                                            );
                    else
                      aParams.delete;
                      aParams( 1 ).ML_NAME   := 'FOLDER_NMBR';
                      aParams( 1 ).ML_VALUE  := RecMoveText.FOLDER_NMBR;
                      aParams( 2 ).ML_NAME   := 'FOLDER_MODE';
                      aParams( 2 ).ML_VALUE  := RecMoveText.FOLDER_MODE;
                      aParams( 3 ).ML_NAME   := 'FOLDER_DATE';
                      aParams( 3 ).ML_VALUE  := Schema_GPSys.OraGPSys.DATE2STR( RecMoveText.FOLDER_DATE );
                      sError                 := Schema_GPSys.MLng.Str2( 'В системата вече съществува номер: $FOLDER_NMBR$, папка: $FOLDER_MODE$, дата: $FOLDER_DATE$',
                                                                        Schema_GPSys.MLng.ctxAccounting,
                                                                        Schema_GPSys.MLng.lngBG,
                                                                        aParams
                                                                       );
                    end if;
                  end if;
                else
                  RecMoveText.FOLDER_MODE  := null;
                end if;
              end if;

              bRet             := bRet and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '1.1', 1, HeadData.UNIQCODE ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, 'SaveMemoOrder', '1.2', 1, HeadData.ORD_TEXT ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, 'SaveMemoOrder', '1.3', 1, HeadData.SCH_DATE ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '1.4', 1, HeadData.ID_STORNO ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '1.5', 1, HeadData.ID_CUST ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, 'SaveMemoOrder', '1.6', 1, HeadData.SYS_TEXT ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '1.ORD_DEALS', 1, 2 ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, 'SaveMemoOrder', '1.7', 1, HeadData.ORIGIN ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, 'SaveMemoOrder', '1.8', 1, to_char( HeadData.DateTime, Schema_GPSys.GPC_Parser.FORMAT_TRANSPORT_DATETIME ) ) and
                                  Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, 'SaveMemoOrder', '1.9', 1, sAllFolderData );

              if ( bRet ) then
                ii  := 0;

                for rec in ( select DEAL_TYPE,
                                    EXPO_DT,
                                    AMOUNT_DT,
                                    AMOUNT_KT,
                                    EXPO_KT,
                                    VALIOR_DT,
                                    VALIOR_KT,
                                    MAIN_EXPO,
                                    USE_TAXES,
                                    AMOUNT_SYS,
                                    REFERENCIA,
                                    TECHNOLOGY,
                                    TECHNOLOGY_DATA
                               from table( cast( DealOper as Schema_GPSys.tblDealOper ) ) ) loop
                  if ( ii = 0 or
                      rec.DEAL_TYPE not in (Sch_Preocenka, Sch_ClearOborot) ) then
                    bRet      := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '2.1', nDocID, rec.DEAL_TYPE ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '2.2', nDocID, rec.EXPO_DT ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '2.3', nDocID, rec.AMOUNT_DT ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '2.4', nDocID, rec.AMOUNT_KT ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '2.5', nDocID, rec.EXPO_KT ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, 'SaveMemoOrder', '2.6', nDocID, rec.VALIOR_DT ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmddate( oDoc, 'SaveMemoOrder', '2.7', nDocID, rec.VALIOR_KT ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '2.8', nDocID, rec.MAIN_EXPO ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, 'SaveMemoOrder', '2.9', nDocID, rec.REFERENCIA ) and
                                 Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, 'SaveMemoOrder', '2.10', nDocID, rec.USE_TAXES );
                  end if;

                  ii                := ii + 1;

                  if ( rec.DEAL_TYPE = Sch_CloseExpo ) then
                    CloseExpo  := rec.MAIN_EXPO;
                  elsif ( rec.DEAL_TYPE = Sch_ClearOborot and
                         rec.EXPO_DT = rec.EXPO_KT ) then
                    aClosedExpo( aClosedExpo.count + 1 )  := rec.EXPO_DT;
                  end if;

                  bExistBudget      := BdgRows.exists( ii ) and
                                       BdgRows( ii ).BDG_CLASSIF is not null;

                  if ( bExistBudget ) then
                    BdgRows( ii ).ORDROWNUM  := oOpers.count + 1;
                  end if;

                  if ( AddRows.exists( ii ) ) then
                    AddRows( ii ).ORDROWNUM   := oOpers.count + 1;
                    AddRows( ii ).ID_EXPO_DT  := rec.EXPO_DT;
                    AddRows( ii ).ID_EXPO_KT  := rec.EXPO_KT;
                  end if;

                  if ( CostRows.exists( ii ) and
                      CostRows( ii ).ID_kind is not null ) then
                    CostRows( ii ).ORDROWNUM  := oOpers.count + 1;
                    CostRows( ii ).AMOUNT_DT  := rec.AMOUNT_DT;
                    CostRows( ii ).CODVAL     := Schema_GPSys.HeadExpo.IDExpo2CodVal( rec.EXPO_DT );
                    CostRows( ii ).VALIOR_DT  := rec.VALIOR_DT;
                  end if;

                  if ( rec.TECHNOLOGY is not null and
                      rec.TECHNOLOGY = Cmd_Expo.nExpoMoveTechn_LGD ) then
                    aColl                                             := Schema_GPSys.OraGPSys.str2lst( rec.TECHNOLOGY_DATA, ';' );
                    tExpoMoveAdd( tExpoMoveAdd.count + 1 ).ORDROWNUM  := oOpers.count + 1;
                    tExpoMoveAdd( tExpoMoveAdd.count ).TECHNOLOGY     := rec.TECHNOLOGY;
                    tExpoMoveAdd( tExpoMoveAdd.count ).DEAL_TYPE      := rec.DEAL_TYPE;

                    if ( aColl.last >= 2 ) then
                      tExpoMoveAdd( tExpoMoveAdd.count ).TECHNOLOGY_STR1  := trim( aColl( 2 ) );
                      tExpoMoveAdd( tExpoMoveAdd.count ).TECHNOLOGY_NUM1  := to_number( aColl( 1 ) );
                    end if;
                  end if;

                  bRet              := bRet and
                                       CreateSchTrans( oDoc,
                                                       nDocID,
                                                       nOpersID,
                                                       oOpers,
                                                       DealOper,
                                                       sError,
                                                       HeadData.UNIQCODE,
                                                       nvl( HeadData.ID_CUST, 0 ),
                                                       HeadData.SCH_DATE,
                                                       rec.DEAL_TYPE,
                                                       rec.EXPO_DT,
                                                       rec.AMOUNT_DT,
                                                       rec.AMOUNT_KT,
                                                       rec.EXPO_KT,
                                                       rec.VALIOR_DT,
                                                       rec.VALIOR_KT,
                                                       rec.USE_TAXES,
                                                       rec.AMOUNT_SYS,
                                                       bZBalSpot,
                                                       bCashReq,
                                                       CloseExpo,
                                                       ii = DealOper.count,
                                                       bExistBudget,
                                                       BdgRows,
                                                       ii,
                                                       aTaxedExpo,
                                                       TaxesRows
                                                      );
                  exit when not bRet;
                end loop;
              end if;

              if ( bRet ) then
                if ( bPreView ) then
                  HeadData.ID_MOVE  := -1;
                  --
                  bRet              := Expo.ChkMaxDaySum( sError, oOpers, HeadData.SCH_DATE );

                  if ( bRet and
                      oOpers.count > 0 ) then
                    if ( Schema_GPSys.OraGPSys.rPreview.nIDObject is not null and
                        Schema_GPSys.OraGPSys.rPreview.nModeObject = Schema_GPSys.OraGPSys.nPreviewModePayments and
                        Schema_GPSys.OraGPSys.rPreview.bPreview ) then
                      Schema_GPSys.OraGPSys.rPreview.nAmount    := 0;
                      Schema_GPSys.OraGPSys.rPreview.nOurTaxes  := 0;
                      Schema_GPSys.OraGPSys.rPreview.nExtTaxes  := 0;
                      Schema_GPSys.OraGPSys.rPreview.nXchgRate  := 1;

                      for recOpers in ( select /*+ LEADING( a b c ) USE_NL( b c )*/
                                              a.*,
                                               b.CODVAL as CODVAL_DT,
                                               c.CODVAL as CODVAL_KT
                                          from Schema_GPSys.EXPOSITION c,
                                               Schema_GPSys.EXPOSITION b,
                                               table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                                         where Schema_GPSys.OraGPSys.rPreview.nIDExpo in (a.EXPO_DT, a.EXPO_KT) and
                                               b.ID_EXPO = a.EXPO_DT and
                                               c.ID_EXPO = a.EXPO_KT ) loop
                        Schema_GPSys.OraGPSys.rPreview.nAmount        := Schema_GPSys.OraGPSys.rPreview.nAmount +
                                                                         case
                                                                           when recOpers.EXPO_DT = Schema_GPSys.OraGPSys.rPreview.nIDExpo then recOpers.AMOUNT_DT
                                                                           else -recOpers.AMOUNT_KT
                                                                         end;
                        Schema_GPSys.OraGPSys.rPreview.nOurTaxes      := Schema_GPSys.OraGPSys.rPreview.nOurTaxes +
                                                                         case
                                                                           when recOpers.EXPO_DT = Schema_GPSys.OraGPSys.rPreview.nIDExpo and
                                                                                recOpers.DEAL_TYPE in (Sch_BiseraTaxes, Sch_ForeignTaxes) then
                                                                             recOpers.AMOUNT_DT
                                                                           else
                                                                             0
                                                                         end;
                        Schema_GPSys.OraGPSys.rPreview.nExtTaxes      := Schema_GPSys.OraGPSys.rPreview.nExtTaxes +
                                                                         case
                                                                           when recOpers.EXPO_DT = Schema_GPSys.OraGPSys.rPreview.nIDExpo and
                                                                                recOpers.DEAL_TYPE = Sch_ForeignTaxesExt then
                                                                             recOpers.AMOUNT_DT
                                                                           else
                                                                             0
                                                                         end;

                        if ( recOpers.EXPO_DT = Schema_GPSys.OraGPSys.rPreview.nIDExpo and
                            recOpers.DEAL_TYPE in (Sch_PrevodBisera, Sch_PrevodForeign) and
                            recOpers.CODVAL_DT != recOpers.CODVAL_KT ) then
                          Schema_GPSys.OraGPSys.rPreview.nXchgRate      := case
                                                                             when nvl( recOpers.XCHG_RATE, 0 ) > 0 then recOpers.XCHG_RATE
                                                                             else recOpers.AMOUNT_KT / recOpers.AMOUNT_DT
                                                                           end;

                          select count( 1 )
                            into jj
                            from Schema_GPSys.CONFSYSTEM
                           where FLDSECTION = 'Deal' and
                                 FLDITEM = 'REVERSE_RATE' and
                                 UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                 FLDVALUE like '%&' || recOpers.CODVAL_DT || recOpers.CODVAL_KT || '&%';

                          if ( jj > 0 ) then
                            Schema_GPSys.OraGPSys.rPreview.nXchgRate  := 1 / Schema_GPSys.OraGPSys.rPreview.nXchgRate;
                          end if;
                        end if;
                      end loop;

                      if ( nvl( Schema_GPSys.OraGPSys.rPreview.bFullLog, false ) ) then
                        insert into Schema_GPSys.PREVIEW_CHANGES(
                                      ID_PREVIEW,
                                      MODE_OBJECT,
                                      ID_OBJECT,
                                      ID_EXPO,
                                      AMOUNT,
                                      OURTAXES,
                                      EXTTAXES,
                                      XCHGRATE,
                                      CH_DATE
                                    )
                             values ( Schema_GPSys.OraGPSys.rPreview.nIDPreview,
                                      Schema_GPSys.OraGPSys.rPreview.nModeObject,
                                      Schema_GPSys.OraGPSys.rPreview.nIDObject,
                                      Schema_GPSys.OraGPSys.rPreview.nIDExpo,
                                      Schema_GPSys.OraGPSys.rPreview.nAmount,
                                      Schema_GPSys.OraGPSys.rPreview.nOurTaxes,
                                      Schema_GPSys.OraGPSys.rPreview.nExtTaxes,
                                      Schema_GPSys.OraGPSys.rPreview.nXchgRate,
                                      sysdate
                                     );
                      end if;
                    else
                      bRet  := SavePreViewResults( oOpers, CostRows, HeadData.ID_CUST );
                    end if;
                  end if;
                else
                  bRet      := Expo.ChkCustLimits( sError, oOpers ) and
                               Expo.ChkMaxDaySum( sError, oOpers, HeadData.SCH_DATE ) and
                               $if ( Schema_GPSys.OraSys.bModule_CAuthOS ) $then
                               ExpoAuth.ChkCardLimits( sError, oOpers ) and
                               $end
                               Expo.ChkExpoOpers( sError, IDMove, HeadData.UNIQCODE, HeadData.ID_CUST, oOpers, HeadData.SCH_DATE, null, aClosedExpo, nIDExpo4Zapor );

                  if ( bRet ) then
                    HeadData.ID_MOVE  := IDMove;
                    bRet              := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '1.ID_MOVE', 1, IDMove );

                    if ( bRet ) then
                      RecMoveText.ID_MOVE     := IDMove;
                      RecMoveText.ORD_TEXT    := HeadData.ORD_TEXT;
                      RecMoveText.SYS_TEXT    := HeadData.SYS_TEXT;
                      RecMoveText.CH_OPER     := Schema_RA.GPC_RA.nCurrentUserID;
                      RecMoveText.ORIGIN      := HeadData.ORIGIN;
                      RecMoveText.DATETIME    := to_char( HeadData.DateTime, Schema_GPSys.GPC_Parser.FORMAT_TRANSPORT_DATETIME );
                      RecMoveText.ID_CUST     := HeadData.ID_CUST;
                      RecMoveText.DOC_NUM     := null;
                      RecMoveText.CH_STAMP    := null;
                      RecMoveText.OPER_DATE   := null;
                      RecMoveText.PREFERRATE  := Schema_GPSys.OraGPSys.DocSysBoolean( Schema_GPSys.XchgRates.bPreferRate );

                      insert into EXPO_MOVE_TEXT
                           values RecMoveText;
                    end if;

                    if ( bRet ) then
                      HeadData.SCH_DOC  := Expo.GetExpoNumberW( Expo.SchDocCntName( HeadData.UNIQCODE, HeadData.SCH_DATE ) );
                      bRet              := nvl( HeadData.SCH_DOC, 0 ) > 0;

                      if ( bRet ) then
                        update EXPO_MOVES
                           set SCH_DOC  = HeadData.SCH_DOC
                         where ID_MOVE = HeadData.ID_MOVE;
                      else
                        sError  := Schema_RA.GPC_RA.RespGetErrorText;
                      end if;
                    end if;

                    bRet              := bRet and
                                         Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '1.SCH_DOC', 1, HeadData.SCH_DOC ) and
                                         Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'SaveMemoOrder', '1.CHOPER', 1, Schema_RA.GPC_RA.nCurrentUserID );
                    ii                := null;
                    jj                := null;
                    bRet              := bRet and
                                         Schema_DocSys.DocSys_SaveInIQ.SaveDocInIQ( ii, jj, oDoc, nDocID, nInQueue );

                    if ( bRet ) then
                      bRet  := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoMoves, IDMove );

                      if ( bRet ) then
                        ii                  := BdgRows.first;

                        while ( ii is not null ) loop
                          if ( BdgRows( ii ).BDG_CLASSIF is not null ) then
                            insert into BDG_MOVES(
                                          ID_MOVE,
                                          ORDROWNUM,
                                          UNIQCODE,
                                          BDG_CLASSIF,
                                          BDG_FUNCTION,
                                          BDG_OBJECT,
                                          DT_KT,
                                          CODVAL,
                                          AMOUNT,
                                          SYS_AMOUNT,
                                          VALIOR,
                                          SCH_DATE
                                        )
                                 values ( HeadData.ID_MOVE,
                                          BdgRows( ii ).ORDROWNUM,
                                          HeadData.UNIQCODE,
                                          BdgRows( ii ).BDG_CLASSIF,
                                          nvl( BdgRows( ii ).BDG_FUNCTION, '_' ),
                                          nvl( decode( BdgRows( ii ).BDG_OBJECT, '0', null, BdgRows( ii ).BDG_OBJECT ), '_' ),
                                          BdgRows( ii ).DT_KT,
                                          BdgRows( ii ).CODVAL,
                                          BdgRows( ii ).AMOUNT,
                                          BdgRows( ii ).SYS_AMOUNT,
                                          BdgRows( ii ).VALIOR,
                                          HeadData.SCH_DATE
                                         );
                          end if;

                          ii  := BdgRows.next( ii );
                        end loop;

                        ii                  := AddRows.first;

                        while ( ii is not null ) loop
                          if ( AddRows( ii ).ADDCLASSIF_DT is not null ) then
                            insert into ADD_MOVES(
                                          ID_MOVE,
                                          ORDROWNUM,
                                          UNIQCODE,
                                          ADD_CLASSIF,
                                          ID_EXPO,
                                          DT_KT,
                                          AMOUNT,
                                          VALIOR,
                                          SCH_DATE
                                        )
                                 values ( HeadData.ID_MOVE,
                                          AddRows( ii ).ORDROWNUM,
                                          HeadData.UNIQCODE,
                                          AddRows( ii ).ADDCLASSIF_DT,
                                          AddRows( ii ).ID_EXPO_DT,
                                          'D',
                                          AddRows( ii ).AMOUNT_DT,
                                          AddRows( ii ).VALIOR_DT,
                                          HeadData.SCH_DATE
                                         );
                          end if;

                          if ( AddRows( ii ).ADDCLASSIF_KT is not null ) then
                            insert into ADD_MOVES(
                                          ID_MOVE,
                                          ORDROWNUM,
                                          UNIQCODE,
                                          ADD_CLASSIF,
                                          ID_EXPO,
                                          DT_KT,
                                          AMOUNT,
                                          VALIOR,
                                          SCH_DATE
                                        )
                                 values ( HeadData.ID_MOVE,
                                          AddRows( ii ).ORDROWNUM,
                                          HeadData.UNIQCODE,
                                          AddRows( ii ).ADDCLASSIF_KT,
                                          AddRows( ii ).ID_EXPO_KT,
                                          'K',
                                          AddRows( ii ).AMOUNT_KT,
                                          AddRows( ii ).VALIOR_KT,
                                          HeadData.SCH_DATE
                                         );
                          end if;

                          ii  := AddRows.next( ii );
                        end loop;

                        ii                  := CostRows.first;

                        while ( ii is not null ) loop
                          if ( CostRows( ii ).ID_Kind is not null ) then
                            insert into COST_REGISTER(
                                          ID_KIND,
                                          ID_COST,
                                          CODVAL,
                                          AMOUNT,
                                          SCH_DATE,
                                          VALIOR,
                                          ID_MOVE,
                                          ORDROWNUM,
                                          ID_CUST
                                        )
                                 values ( CostRows( ii ).ID_kind,
                                          CostRows( ii ).ID_cost,
                                          CostRows( ii ).CodVal,
                                          CostRows( ii ).Amount_Dt,
                                          HeadData.SCH_DATE,
                                          CostRows( ii ).Valior_Dt,
                                          HeadData.ID_MOVE,
                                          CostRows( ii ).ORDROWNUM,
                                          HeadData.ID_CUST
                                         );
                          end if;

                          ii  := CostRows.next( ii );
                        end loop;

                        if ( not bSkipTaxesRegister ) then
                          ii  := TaxesRows.first;

                          while ( ii is not null ) loop
                            insert into TAXES_REGISTER(
                                          ID_TAX,
                                          UNIQCODE,
                                          ID_CUST,
                                          EXT_CODE,
                                          INT_CODE,
                                          TAXVAL,
                                          TAXSUM,
                                          TRFSUM,
                                          DT_EXPO,
                                          KT_EXPO,
                                          REG_DATE,
                                          ID_MOVE,
                                          TAX_STATUS,
                                          KIND_TECH,
                                          ID_PAYTAX,
                                          KIND_PREFER,
                                          OBJECT_PREFER,
                                          USER_ID,
                                          COMPETENCE,
                                          ORD_TEXT,
                                          AMOUNT,
                                          CODVAL
                                        )
                                 values ( Taxes.GetTaxesNumber( 'ID_REGTAX' ),
                                          TaxesRows( ii ).UNIQCODE,
                                          TaxesRows( ii ).ID_CUST,
                                          TaxesRows( ii ).EXT_CODE,
                                          TaxesRows( ii ).INT_CODE,
                                          TaxesRows( ii ).TAXVAL,
                                          TaxesRows( ii ).TAXSUM,
                                          TaxesRows( ii ).TRFSUM,
                                          TaxesRows( ii ).DT_EXPO,
                                          TaxesRows( ii ).KT_EXPO,
                                          HeadData.SCH_DATE,
                                          HeadData.ID_MOVE,
                                          Taxes.TaxStateSch,
                                          TaxesRows( ii ).KIND_TECH,
                                          TaxesRows( ii ).ID_PAYTAX,
                                          TaxesRows( ii ).KIND_PREFER,
                                          TaxesRows( ii ).OBJECT_PREFER,
                                          TaxesRows( ii ).USER_ID,
                                          TaxesRows( ii ).COMPETENCE,
                                          TaxesRows( ii ).ORD_TEXT,
                                          TaxesRows( ii ).AMOUNT,
                                          TaxesRows( ii ).CODVAL
                                         );

                            ii  := TaxesRows.next( ii );
                          end loop;
                        end if;

                        ii                  := tExpoMoveAdd.first;

                        while ( ii is not null ) loop
                          insert into EXPO_MOVES_ADD(
                                        ID_MOVE,
                                        ORDROWNUM,
                                        DEAL_TYPE,
                                        TECHNOLOGY,
                                        TECHNOLOGY_STR1,
                                        TECHNOLOGY_NUM1
                                      )
                               values ( HeadData.ID_MOVE,
                                        tExpoMoveAdd( ii ).ORDROWNUM,
                                        tExpoMoveAdd( ii ).DEAL_TYPE,
                                        tExpoMoveAdd( ii ).TECHNOLOGY,
                                        tExpoMoveAdd( ii ).TECHNOLOGY_STR1,
                                        tExpoMoveAdd( ii ).TECHNOLOGY_NUM1
                                       );

                          ii  := tExpoMoveAdd.next( ii );
                        end loop;

                        if ( bRet ) then
                          nCurrent               := 0;
                          recPrevDeal.DEAL_NUM   := 0;
                          recPrevDeal.EXPO_DT    := 0;
                          recPrevDeal.CODVAL_DT  := '~';
                          recPrevDeal.CODVAL_KT  := '~';

                          for recDeal in ( select /*+ LEADING( deal, expo_debit, expo_credit, type_debit, type_credit ) USE_NL( expo_debit, expo_credit, type_debit, type_credit ) */
                                                 deal.DEAL_TYPE,
                                                  deal.EXPO_DT,
                                                  deal.AMOUNT_DT,
                                                  deal.AMOUNT_KT,
                                                  deal.EXPO_KT,
                                                  deal.VALIOR_DT,
                                                  deal.VALIOR_KT,
                                                  deal.MAIN_EXPO,
                                                  deal.USE_TAXES,
                                                  deal.AMOUNT_SYS,
                                                  deal.REFERENCIA,
                                                  deal.XCHG_RATE,
                                                  expo_debit.CODVAL as CODVAL_DT,
                                                  expo_credit.CODVAL as CODVAL_KT,
                                                  type_debit.BASE_TYPE as BASE_TYPE_DT,
                                                  type_credit.BASE_TYPE as BASE_TYPE_KT
                                             from Schema_GPSys.EXPOTYPES type_debit,
                                                  Schema_GPSys.EXPOTYPES type_credit,
                                                  Schema_GPSys.EXPOSITION expo_debit,
                                                  Schema_GPSys.EXPOSITION expo_credit,
                                                  table( cast( DealOper as Schema_GPSys.tblDealOper ) ) deal
                                            where expo_debit.ID_EXPO = deal.EXPO_DT and
                                                  expo_credit.ID_EXPO = deal.EXPO_KT and
                                                  type_debit.TYPE_EXPO = expo_debit.TYPE_EXPO and
                                                  type_credit.TYPE_EXPO = expo_credit.TYPE_EXPO ) loop
                            nCurrent               := nCurrent + 1;

                            if ( recDeal.CODVAL_DT != recDeal.CODVAL_KT ) then
                              if ( nvl( recDeal.XCHG_RATE, 0 ) = 0 ) then
                                if ( nvl( recDeal.AMOUNT_DT, 0 ) != 0 and
                                    nvl( recDeal.AMOUNT_KT, 0 ) != 0 ) then
                                  recDeal.XCHG_RATE  := recDeal.AMOUNT_KT / recDeal.AMOUNT_DT;
                                else
                                  recDeal.XCHG_RATE  := 1;
                                  nFixing            := 1;
                                end if;
                              end if;

                              $if Schema_GPSys.OraSys.VerBankUnion or
                                  Schema_GPSys.OraSys.VerBankDBank $then
                              nRateType      := case recDeal.DEAL_TYPE
                                                  when Sch_Change then Schema_GPSys.XchgRates.XchgRateType_BuySell
                                                  else Schema_GPSys.XchgRates.XchgRateType_BuyDevSelDev
                                                end;
                              $else
                                if ( recDeal.BASE_TYPE_DT = Schema_GPSys.HeadExpo.ExpoCash and
                                    recDeal.BASE_TYPE_KT = Schema_GPSys.HeadExpo.ExpoCash ) then
                                  nRateType  := Schema_GPSys.XchgRates.XchgRateType_BuySell;
                                elsif ( recDeal.BASE_TYPE_DT = Schema_GPSys.HeadExpo.ExpoCash ) then
                                  nRateType  := Schema_GPSys.XchgRates.XchgRateType_BuySelDev;
                                elsif ( recDeal.BASE_TYPE_KT = Schema_GPSys.HeadExpo.ExpoCash ) then
                                  nRateType  := Schema_GPSys.XchgRates.XchgRateType_BuyDevSel;
                                else
                                  nRateType  := Schema_GPSys.XchgRates.XchgRateType_BuyDevSelDev;
                                end if;
                              $end
                              nFixing        := Schema_GPSys.XchgRates.GetXchgRate( HeadData.UNIQCODE, HeadData.SCH_DATE, recDeal.CODVAL_DT, recDeal.CODVAL_KT, nRateType );
                            else
                              recDeal.XCHG_RATE  := 1;
                              nFixing            := 1;
                            end if;

                            if ( recDeal.DEAL_TYPE = Sch_Change and
                                recDeal.EXPO_DT = recPrevDeal.EXPO_DT and
                                recDeal.CODVAL_KT = Schema_GPSys.OraGPSys.SYS_CURR and
                                Schema_GPSys.OraGPSys.SYS_CURR not in (recPrevDeal.CODVAL_DT, recPrevDeal.CODVAL_KT) ) then
                              update EXPO_DEAL_RATE
                                 set AMOUNT_DT   = AMOUNT_DT + recDeal.AMOUNT_DT,
                                     ADDAMN_SYS  = recDeal.AMOUNT_KT
                               where ID_MOVE = HeadData.ID_MOVE and
                                     DEAL_NUM = recPrevDeal.DEAL_NUM;
                            else
                              insert into EXPO_DEAL_RATE(
                                            ID_MOVE,
                                            DEAL_NUM,
                                            EXPO_DT,
                                            AMOUNT_DT,
                                            CODVAL_DT,
                                            VALIOR_DT,
                                            EXPO_KT,
                                            AMOUNT_KT,
                                            CODVAL_KT,
                                            VALIOR_KT,
                                            RATE_FIXING,
                                            RATE_AGREED
                                          )
                                   values ( HeadData.ID_MOVE,
                                            nCurrent,
                                            recDeal.EXPO_DT,
                                            recDeal.AMOUNT_DT,
                                            recDeal.CODVAL_DT,
                                            recDeal.VALIOR_DT,
                                            recDeal.EXPO_KT,
                                            recDeal.AMOUNT_KT,
                                            recDeal.CODVAL_KT,
                                            recDeal.VALIOR_KT,
                                            nFixing,
                                            recDeal.XCHG_RATE
                                           );
                            end if;

                            recPrevDeal.DEAL_NUM   := nCurrent;
                            recPrevDeal.EXPO_DT    := recDeal.EXPO_DT;
                            recPrevDeal.CODVAL_DT  := recDeal.CODVAL_DT;
                            recPrevDeal.CODVAL_KT  := recDeal.CODVAL_KT;
                          end loop;
                        end if;

                        if ( bRet and
                            nvl( HeadData.ID_CUST, 0 ) > 0 ) then
                          for rec in ( select /*+ LEADING( a ) USE_NL( b, c, d, e ) */
                                             a.EXPO_DT,
                                              b.CODVAL as CODVAL_DT,
                                              b.TYPE_EXPO as EXPOTYPE_DT,
                                              b.ID_CUST as ID_CUST_DT,
                                              decode( d.BASE_TYPE, Schema_GPSys.HeadExpo.ExpoCash, 'I', '~' ) as OPER_DT,
                                              d.ACTPASS as ACTPASS_DT,
                                              a.AMOUNT_DT,
                                              a.AMOUNT_KT,
                                              e.ACTPASS as ACTPASS_KT,
                                              decode( e.BASE_TYPE, Schema_GPSys.HeadExpo.ExpoCash, 'O', '~' ) as OPER_KT,
                                              c.ID_CUST as ID_CUST_KT,
                                              c.TYPE_EXPO as EXPOTYPE_KT,
                                              c.CODVAL as CODVAL_KT,
                                              a.EXPO_KT,
                                              a.DEAL_TYPE
                                         from Schema_GPSys.EXPOTYPES e,
                                              Schema_GPSys.EXPOTYPES d,
                                              Schema_GPSys.EXPOSITION c,
                                              Schema_GPSys.EXPOSITION b,
                                              table( cast( DealOper as Schema_GPSys.tblDealOper ) ) a
                                        where b.ID_EXPO = a.EXPO_DT and
                                              c.ID_EXPO = a.EXPO_KT and
                                              d.TYPE_EXPO = b.TYPE_EXPO and
                                              e.TYPE_EXPO = c.TYPE_EXPO ) loop
                            $if Schema_GPSys.OraSys.VerBank $then
                            nOperSum  := rec.AMOUNT_DT;

                            if ( nOperSum > 0 and
                                rec.ID_CUST_DT > 0 and
                                rec.ACTPASS_DT = 'P' and
                                ( ( rec.ACTPASS_KT = 'A' and
                                   rec.ID_CUST_DT = rec.ID_CUST_KT ) or
                                 rec.DEAL_TYPE in (Sch_RegisterTaxes, Sch_CredTaxes, Sch_lihvi, Sch_CredPogasiava) ) ) then
                              for recLimits in ( select *
                                                   from EXPO_LIMITS
                                                  where ID_EXPO = rec.EXPO_DT and
                                                        TYPE_LIMIT = Expo.ExpoLimit_DueAmn and
                                                        STATUS = Expo.ZaporStat_Active and
                                                        SUMLIMIT > 0 ) loop
                                nFixing      := Schema_GPSys.XchgRates.GetExactSum( nOperSum,
                                                                                    HeadData.UNIQCODE,
                                                                                    HeadData.SCH_DATE,
                                                                                    rec.CODVAL_DT,
                                                                                    recLimits.CODVAL,
                                                                                    Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                   );

                                if ( nFixing > 0 ) then
                                  if ( nFixing >= recLimits.SUMLIMIT ) then
                                    delete from EXPO_LIMITS
                                          where ID_LIMIT = recLimits.ID_LIMIT;
                                  else
                                    recLimits.SUMLIMIT  := recLimits.SUMLIMIT - nFixing;

                                    update EXPO_LIMITS
                                       set SUMLIMIT  = recLimits.SUMLIMIT
                                     where ID_LIMIT = recLimits.ID_LIMIT;
                                  end if;

                                  Expo.SetMaxTriggNumber( 'ID_LASTLIMIT', rec.EXPO_DT );
                                  nOperSum      := greatest( nOperSum -
                                                             Schema_GPSys.XchgRates.GetExactSum( recLimits.SUMLIMIT,
                                                                                                 HeadData.UNIQCODE,
                                                                                                 HeadData.SCH_DATE,
                                                                                                 recLimits.CODVAL,
                                                                                                 rec.CODVAL_DT,
                                                                                                 Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                ),
                                                             0
                                                            );
                                end if;
                              end loop;
                            end if;

                            if ( Schema_RA.GPC_RA.nCurrentUserID > 0 and
                                ( not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 25 ) ) ) then
                              if ( sForApproval is null ) then
                                sForApproval  := Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'FORAPPROVAL_EXPO_TYPES', '~' );
                              end if;

                              if ( ( rec.ID_CUST_DT > 0 or
                                    '&' || sForApproval || '&' like '%&' || to_char( rec.EXPOTYPE_DT ) || '&%' ) and
                                  rec.ID_CUST_KT > 0 and
                                  rec.ACTPASS_KT = 'P' and
                                  rec.ID_CUST_DT != rec.ID_CUST_KT and
                                  rec.DEAL_TYPE in (Sch_Free) ) then
                                insert into EXPO_LIMITS(
                                              ID_LIMIT,
                                              TYPE_LIMIT,
                                              ID_EXPO,
                                              BEG_DATE,
                                              CODVAL,
                                              SUMLIMIT,
                                              STATUS
                                            )
                                     values ( HeadData.ID_MOVE,
                                              Expo.ExpoLimit_ForApproval,
                                              rec.EXPO_KT,
                                              HeadData.SCH_DATE,
                                              rec.CODVAL_KT,
                                              rec.AMOUNT_KT,
                                              Expo.ZaporStat_Active
                                             );

                                Expo.SetMaxTriggNumber( 'ID_LASTLIMIT', rec.EXPO_KT );
                              end if;
                            end if;
                          $else
                            if ( rec.OPER_DT != '~' ) then
                              insert into CASH_ORDERS(
                                            IDORDER,
                                            ORDERNO,
                                            ID_CUST,
                                            ID_EXPO,
                                            IN_OUT,
                                            CODVAL,
                                            AMOUNT,
                                            SCH_DATE,
                                            ID_MOVE
                                          )
                                   values ( Expo.GetExpoNumber( 'CASHORDER' ),
                                            Expo.GetExpoNumber( Expo.CashDocCntName( rec.OPER_DT, rec.EXPO_DT, HeadData.SCH_DATE ) ),
                                            HeadData.ID_CUST,
                                            rec.EXPO_DT,
                                            rec.OPER_DT,
                                            rec.CODVAL_DT,
                                            rec.AMOUNT_DT,
                                            HeadData.SCH_DATE,
                                            HeadData.ID_MOVE
                                           );
                            end if;

                            if ( rec.OPER_KT != '~' ) then
                              insert into CASH_ORDERS(
                                            IDORDER,
                                            ORDERNO,
                                            ID_CUST,
                                            ID_EXPO,
                                            IN_OUT,
                                            CODVAL,
                                            AMOUNT,
                                            SCH_DATE,
                                            ID_MOVE
                                          )
                                   values ( Expo.GetExpoNumber( 'CASHORDER' ),
                                            Expo.GetExpoNumber( Expo.CashDocCntName( rec.OPER_KT, rec.EXPO_KT, HeadData.SCH_DATE ) ),
                                            HeadData.ID_CUST,
                                            rec.EXPO_KT,
                                            rec.OPER_KT,
                                            rec.CODVAL_KT,
                                            rec.AMOUNT_KT,
                                            HeadData.SCH_DATE,
                                            HeadData.ID_MOVE
                                           );
                            end if;
                          $end
                          end loop;
                        end if;

                        --
                        Expo.rMemoOrderAdd  := null;
                      else
                        aParams.delete;
                        aParams( 1 ).ML_NAME   := 'ID_MOVE';
                        aParams( 1 ).ML_VALUE  := Schema_GPSys.OraGPSys.IntToS( IDMove );
                        sError                 := Schema_GPSys.MLng.Str2( 'Не може да се заключи движение $ID_MOVE$',
                                                                          Schema_GPSys.MLng.ctxAccounting,
                                                                          Schema_GPSys.MLng.lngBG,
                                                                          aParams
                                                                         );
                      end if;
                    else
                      aParams.delete;
                      aParams( 1 ).ML_NAME   := 'DOC_ID';
                      aParams( 1 ).ML_VALUE  := to_char( nDocID );
                      sError                 := Schema_GPSys.MLng.Str2( 'SaveDocInIQ() error: $DOC_ID$', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngEN, aParams );
                    end if;
                  end if;
                end if;
              end if;
            end if;
          end if;
        end if;
      else
        sError  := Schema_GPSys.MLng.Str2( 'В момента има забрана за операции', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
      end if;
    else
      sError  := Schema_GPSys.MLng.Str2( 'Некоректна счетоводна дата', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
    end if;

    if ( not bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText_NoML( sError );
    else
      if ( not bPreView ) then
        glExpoMoveRec.ID_MOVE   := HeadData.ID_MOVE;
        glExpoMoveRec.SCH_DATE  := HeadData.SCH_DATE;
        glExpoMoveRec.SCH_DOC   := HeadData.SCH_DOC;
      end if;
    end if;

    Schema_GPSys.XchgRates.bPreferRate  := false;
    return bRet;
  end GenerateMemoOrder;

  --------------------------------------------------------------------------------
  function CmdInBankPaySave( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues     Schema_GPSys.GPC_Parser.taParamStrings;
    aIDMoves       Schema_GPSys.OraGPSys.aIntegers;
    HeadData1      Schema_GPSys.tMemoOrder;
    DealOper1      Schema_GPSys.tblDealOper;
    HeadData2      Schema_GPSys.tMemoOrder;
    DealOper2      Schema_GPSys.tblDealOper;
    HeadData3      Schema_GPSys.tMemoOrder;
    DealOper3      Schema_GPSys.tblDealOper;
    nUniqCodeDt    integer;
    nHeadUCode     integer;
    nUniqCodeKt    integer;
    nIdExpoDt      integer;
    nIdExpoKt      integer;
    nIdExpoX       integer;
    nIdExpoY       integer;
    nIdExpoXC      integer;
    nIdExpoYC      integer;
    nIDExpo4Zapor  integer;
    nSumDt         number;
    nSumKt         number;
    sTaxDt         varchar2( 1 );
    sTaxKt         varchar2( 1 );
    sCodValDt      varchar2( 3 );
    sCodValKt      varchar2( 3 );
    sCodVal        varchar2( 3 );
    sBankCode      varchar2( 8 );
    sOsnovanie     varchar2( 4000 );
    sData          varchar2( 4000 );
    sReferencia    varchar2( 200 );
    dValiorDt      date;
    dValiorKt      date;
    dSchDate       date;
    bDirect        boolean;
    bRet           boolean := false;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count > 0 ) then
      for jj in aParamEntities3D.first .. aParamEntities3D.last loop
        bRet  := false;

        if ( aParamEntities3D( jj ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( jj ).sValue, aRowValues ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUniqCodeDt ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nIdExpoDt ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), sCodValDt ) and
                       Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 4 ), nSumDt ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 5 ), dValiorDt ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), sTaxDt ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 7 ), nUniqCodeKt ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 8 ), nIdExpoKt ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 9 ), sCodValKt ) and
                       Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 10 ), nSumKt ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 11 ), dValiorKt ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 12 ), sTaxKt ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 13 ), dSchDate ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 14 ), sOsnovanie ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 15 ), sReferencia );
        end if;

        exit when not bRet;
      end loop;
    end if;

    if ( bRet ) then
      if ( nUniqCodeDt != nUniqCodeKt and
          nSumKt > 0 and
          Schema_GPSys.HeadExpo.IsItCashExpo( nIdExpoDt ) and
          Schema_GPSys.HeadExpo.ChkCashExpo( nUniqCodeDt, nIdExpoDt, 2, nIDExpo4Zapor ) and
          nvl( Schema_GPSys.HeadExpo.IDExpo2IDCust( nIdExpoKt ), 0 ) > 0 and
          Schema_GPSys.HeadExpo.IsItPasiveExpo( nIdExpoKt ) ) then
        nIDExpo4Zapor  := nIdExpoKt;
      else
        nIDExpo4Zapor  := null;
      end if;

      if ( nUniqCodeDt = nUniqCodeKt or
          not Expo.IsSystemHaveBalances ) then
        DealOper1                    := Schema_GPSys.tblDealOper( );
        HeadData1                    := Schema_GPSys.tMemoOrder( null, nvl( Schema_RA.GPC_RA.nCurrentUniqCode, nUniqCodeDt ), sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );
        DealOper1.extend;
        DealOper1( DealOper1.last )  := Schema_GPSys.tDealOper( Sch_Free, nIdExpoDt, nSumDt, nSumKt, nIdExpoKt, dValiorDt, dValiorKt, nIdExpoDt, sTaxDt, null, sReferencia, null, 0, null );
        bRet                         := Schema_GPSys.Cmd_HeadExpo.ChkOverNightRules( DealOper1 ) and
                                        GenerateMemoOrder( HeadData1, DealOper1, false, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, true, false, nIDExpo4Zapor );

        if ( bRet ) then
          aIDMoves( 1 )  := HeadData1.ID_MOVE;
          commit;
        else
          rollback;
        end if;
      else
        nHeadUCode   := Schema_RA.GPC_Tools.GetHeadUniqCode;
        bDirect      := nvl( nHeadUCode, 0 ) = 0 or
                        nHeadUCode in (nUniqCodeDt, nUniqCodeKt) or
                        ( sCodValKt = Schema_GPSys.OraGPSys.SYS_CURR and
                         Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'Счетоводство', 'РазчетиПоделения', 0 ) = 0 );

        if ( bDirect ) then
          bRet  := InBankGetExpoConf( nUniqCodeDt, nUniqCodeKt, sCodValKt, 'O', nIdExpoX, sCodVal );

          if ( bRet ) then
            bRet  := InBankGetExpoConf( nUniqCodeKt, nUniqCodeDt, sCodValKt, 'I', nIdExpoY, sCodVal );
          end if;
        else
          bRet  := InBankGetExpoConf( nUniqCodeDt, nHeadUCode, sCodValKt, 'O', nIdExpoX, sCodVal );

          if ( bRet ) then
            bRet  := InBankGetExpoConf( nHeadUCode, nUniqCodeDt, sCodValKt, 'I', nIdExpoXC, sCodVal );

            if ( bRet ) then
              bRet  := InBankGetExpoConf( nHeadUCode, nUniqCodeKt, sCodValKt, 'O', nIdExpoYC, sCodVal );

              if ( bRet ) then
                bRet  := InBankGetExpoConf( nUniqCodeKt, nHeadUCode, sCodValKt, 'I', nIdExpoY, sCodVal );
              end if;
            end if;
          end if;
        end if;

        if ( bRet ) then
          DealOper1                    := Schema_GPSys.tblDealOper( );
          HeadData1                    := Schema_GPSys.tMemoOrder( null, nUniqCodeDt, sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );
          DealOper1.extend;
          DealOper1( DealOper1.last )  := Schema_GPSys.tDealOper( Sch_Free, nIdExpoDt, nSumDt, nSumKt, nIdExpoX, dValiorDt, dValiorKt, nIdExpoDt, sTaxDt, null, sReferencia, null, 0, null );
          --
          DealOper2                    := Schema_GPSys.tblDealOper( );
          HeadData2                    := Schema_GPSys.tMemoOrder( null, nUniqCodeKt, sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );
          DealOper2.extend;
          DealOper2( DealOper2.last )  := Schema_GPSys.tDealOper( Sch_Free, nIdExpoY, nSumKt, nSumKt, nIdExpoKt, dValiorKt, dValiorKt, nIdExpoKt, sTaxKt, null, sReferencia, null, 0, null );

          if ( not bDirect ) then
            DealOper3                    := Schema_GPSys.tblDealOper( );
            HeadData3                    := Schema_GPSys.tMemoOrder( null, nHeadUCode, sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );
            DealOper3.extend;
            DealOper3( DealOper3.last )  := Schema_GPSys.tDealOper( Sch_Free, nIdExpoXC, nSumKt, nSumKt, nIdExpoYC, dValiorKt, dValiorKt, nIdExpoKt, 'F', null, sReferencia, null, 0, null );
          end if;

          bRet                         := GenerateMemoOrder( HeadData1, DealOper1, false, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, true, false, nIDExpo4Zapor ) and
                                          GenerateMemoOrder( HeadData2, DealOper2 ) and
                                          ( bDirect or
                                           GenerateMemoOrder( HeadData3, DealOper3 ) );

          if ( bRet ) then
            aIDMoves( 1 )  := HeadData1.ID_MOVE;
            aIDMoves( 2 )  := HeadData2.ID_MOVE;

            if ( not bDirect ) then
              aIDMoves( 3 )  := HeadData3.ID_MOVE;
            end if;

            bRet           := Expo.SaveGroupIdMoves( aIDMoves );
          end if;

          if ( bRet ) then
            commit;
          else
            rollback;
          end if;
        end if;
      end if;
    end if;

    if ( bRet ) then
      Schema_GPSys.GPC_Parser.RespAddArray( 1 );

      for ii in aIDMoves.first .. aIDMoves.last loop
        sData     := null;
        bRet      := bRet and
                     Schema_GPSys.GPC_Parser.WriteInteger( ii, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( aIDMoves( ii ), sData );

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        end if;
      end loop;
    end if;

    return bRet;
  end CmdInBankPaySave;

  --------------------------------------------------------------------------------
  function CmdGetCustProducts( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues   Schema_GPSys.GPC_Parser.taParamStrings;
    nPacket      LOAN_INSURANCE.PACKET_ID%type;
    sStatus      varchar2( 1 );
    sData        varchar2( 4000 );
    cSymbol      varchar2( 10 ) := '__________';
    cAgnCode     varchar2( 16 );
    cRet         varchar2( 1 );
    nIDCust      integer;
    nUniqCode    integer;
    nIDMKU       integer;
    nIDAgent     integer;
    nSaldo       number;
    nFreeSaldo   number;
    nAvansLih    number;
    dSchDate     date;
    dNullDate    date;
    dExpDate     date;
    dAvanLih     date;
    bOther       boolean;
    bCurrent     boolean;
    bDeposit     boolean;
    bEngage      boolean;
    bCredit      boolean;
    bCover       boolean;
    bCard        boolean := false;
    bRet         boolean;
    bViewSaldo   boolean;
    bCheckUCode  boolean
                   := nvl( Schema_GPSys.OraGPSys.OracleBoolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'CHECK_OPER_EXPOUCODE', 'F' ) ), false );
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    $if Schema_GPSys.OraSys.VerBank $then
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDCust ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nUniqCode ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), sStatus ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 4 ), bOther ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 5 ), bCurrent ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 6 ), bDeposit ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 7 ), bEngage ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 8 ), bCredit ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 9 ), bCover ) and
                 ( ( not aRowValues.exists( 10 ) ) or
                  Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 10 ), bCard ) );

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      dSchDate  := Schema_RA.GPC_Tools.GetSchDate( nUniqCode );

      if ( not Expo.IsSystemHaveBalances ) then
        nUniqCode  := 0;
      end if;

      Schema_GPSys.GPC_Parser.RespAddArray( 1 );

      if ( nvl( bOther, false ) ) then
        for rec in (  $if ( Schema_GPSys.OraSys.bModule_Deal ) $then
                    select  a.ID_EXPO,
                            a.UNIQCODE,
                            b.TYPE_EXPO,
                            c.FLDNAME,
                            c.ACTPASS,
                            a.CODVAL,
                            b.BANKACC,
                            b.IBAN,
                            b.EXT_IBAN,
                            a.OPEN_DATE,
                            a.CLOSE_DATE,
                            b.EXPO_NAME,
                            e.ID_AGENT,
                            e.COD_AGENT,
                            a.ID_CUST
                       from Schema_Deal.AGENTS e,
                            Schema_Deal.AGENTS_PRODUCT_LINKS d,
                            Schema_GPSys.EXPOTYPES c,
                            Schema_GPSys.EXPOSITION b,
                            OTHER_EXPO a
                      where a.ID_CUST = nIDCust and
                            ( nUniqCode = 0 or
                             a.UNIQCODE = nUniqCode ) and
                            ( sStatus is null or
                             a.STATUS = sStatus ) and
                            b.ID_EXPO = a.ID_EXPO and
                            b.TYPE_EXPO = c.TYPE_EXPO and
                            c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent and
                            b.ID_EXPO = d.ID_PRODUCT(+) and
                            d.ID_AGENT = e.ID_AGENT(+) and
                            d.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpCurrent
                    union all
                    select a.ID_EXPO,
                           a.UNIQCODE,
                           b.TYPE_EXPO,
                           c.FLDNAME,
                           c.ACTPASS,
                           a.CODVAL,
                           b.BANKACC,
                           b.IBAN,
                           b.EXT_IBAN,
                           a.OPEN_DATE,
                           a.CLOSE_DATE,
                           b.EXPO_NAME,
                           e.ID_AGENT,
                           e.COD_AGENT,
                           a.ID_CUST
                      from Schema_Deal.AGENTS e,
                           Schema_Deal.AGENTS_PRODUCT_LINKS d,
                           Schema_GPSys.EXPOTYPES c,
                           Schema_GPSys.EXPOSITION b,
                           OTHER_EXPO a,
                           EXPO_COTITULQRI x
                     where x.ID_CUST = nIDCust and
                           a.ID_EXPO = x.ID_EXPO and
                           ( nUniqCode = 0 or
                            a.UNIQCODE = nUniqCode ) and
                           ( sStatus is null or
                            a.STATUS = sStatus ) and
                           b.ID_EXPO = a.ID_EXPO and
                           b.TYPE_EXPO = c.TYPE_EXPO and
                           c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent and
                           b.ID_EXPO = d.ID_PRODUCT(+) and
                           d.ID_AGENT = e.ID_AGENT(+) and
                           d.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpCurrent  $else
    select a.ID_EXPO,
                                a.UNIQCODE,
                                b.TYPE_EXPO,
                                c.FLDNAME,
                                c.ACTPASS,
                                a.CODVAL,
                                b.BANKACC,
                                b.IBAN,
                                b.EXT_IBAN,
                                a.OPEN_DATE,
                                a.CLOSE_DATE,
                                b.EXPO_NAME,
                                0 as ID_AGENT,
                                null as COD_AGENT,
                                a.ID_CUST
                           from Schema_GPSys.EXPOTYPES c,
                                Schema_GPSys.EXPOSITION b,
                                OTHER_EXPO a
                          where a.ID_CUST = nIDCust and
                                ( nUniqCode = 0 or
                                 a.UNIQCODE = nUniqCode ) and
                                ( sStatus is null or
                                 a.STATUS = sStatus ) and
                                b.ID_EXPO = a.ID_EXPO and
                                b.TYPE_EXPO = c.TYPE_EXPO and
                                c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent
                        union all
                        select a.ID_EXPO,
                               a.UNIQCODE,
                               b.TYPE_EXPO,
                               c.FLDNAME,
                               c.ACTPASS,
                               a.CODVAL,
                               b.BANKACC,
                               b.IBAN,
                               b.EXT_IBAN,
                               a.OPEN_DATE,
                               a.CLOSE_DATE,
                               b.EXPO_NAME,
                               0 as ID_AGENT,
                               null as COD_AGENT,
                               a.ID_CUST
                          from Schema_GPSys.EXPOTYPES c,
                               Schema_GPSys.EXPOSITION b,
                               OTHER_EXPO a,
                               EXPO_COTITULQRI x
                         where x.ID_CUST = nIDCust and
                               a.ID_EXPO = x.ID_EXPO and
                               ( nUniqCode = 0 or
                                a.UNIQCODE = nUniqCode ) and
                               ( sStatus is null or
                                a.STATUS = sStatus ) and
                               b.ID_EXPO = a.ID_EXPO and
                               b.TYPE_EXPO = c.TYPE_EXPO and
                               c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent
    $end
                                                                                   ) loop
          if ( Schema_RA.GPC_SS.CheckRightExpo_VExpo_CUser( rec.TYPE_EXPO, rec.ID_EXPO ) and
              ( not bCheckUCode or
               Schema_RA.GPC_SS.CheckRightUCode_CUser( rec.UNIQCODE ) ) ) then
            bViewSaldo  := Schema_RA.GPC_SS.CheckRightExpo_VSaldo_CUser( rec.TYPE_EXPO, rec.ID_EXPO );
            bRet        := Expo.GetExpoHotSaldo( Rec.ID_EXPO, nSaldo );

            if ( rec.ACTPASS = 'P' ) then
              nFreeSaldo  := Expo.ExpoSumAvailable( Rec.ID_EXPO, dSchDate, false, 1 );
            else
              nFreeSaldo  := nSaldo;
            end if;

            sData       := null;
            bRet        := bRet and
                           Schema_GPSys.GPC_Parser.WriteInteger( Schema_GPSys.HeadExpo.ExpoGrpCurrent, sData ) and --  1
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_EXPO, sData ) and --  2
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.TYPE_EXPO, sData ) and --  3
                           Schema_GPSys.GPC_Parser.WriteString( rec.FLDNAME, sData ) and --  4
                           Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and --  5
                           Schema_GPSys.GPC_Parser.WriteString( rec.BANKACC, sData ) and --  6
                           Schema_GPSys.GPC_Parser.WriteAmount( nSaldo, sData ) and --  7
                           Schema_GPSys.GPC_Parser.WriteDate( rec.OPEN_DATE, sData ) and --  8
                           Schema_GPSys.GPC_Parser.WriteDate( dNullDate, sData ) and --  9
                           Schema_GPSys.GPC_Parser.WriteDate( rec.CLOSE_DATE, sData ) and -- 10
                           Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_NAME, sData ) and -- 11
                           Schema_GPSys.GPC_Parser.WriteAmount( nFreeSaldo, sData ) and -- 12
                           Schema_GPSys.GPC_Parser.WriteString( Expo.Check4Limits( Rec.ID_EXPO, dSchDate ), sData ) and -- 13
                           Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Tools.UniqCode2BankCode( Rec.UNIQCODE ), sData ) and -- 14
                           Schema_GPSys.GPC_Parser.WriteAmount( 0, sData ) and -- 15
                           Schema_GPSys.GPC_Parser.WriteLogic( bViewSaldo, sData ) and -- 16
                           Schema_GPSys.GPC_Parser.WriteDate( null, sData ) and -- 17
                           Schema_GPSys.GPC_Parser.WriteInteger( Rec.UNIQCODE, sData ) and -- 18
                           Schema_GPSys.GPC_Parser.WriteString( rec.IBAN, sData ) and -- 19
                           Schema_GPSys.GPC_Parser.WriteString( Expo.GetExpoBKAcc( rec.ID_EXPO ), sData ) and --20
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_AGENT, sData ) and -- 21
                           Schema_GPSys.GPC_Parser.WriteString( rec.COD_AGENT, sData ) and -- 22
                           Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 23
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CUST, sData ) and --  24
                           Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 25
                           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 26
                           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 27
                           Schema_GPSys.GPC_Parser.WriteString( rec.EXT_IBAN, sData ) and -- 28
                           true;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            else
              exit;
            end if;
          end if;
        end loop;
      end if;

      if ( bRet and
          nvl( bCurrent, false ) ) then
        for rec in (  $if ( Schema_GPSys.OraSys.bModule_Deal ) $then
                    select  a.ID_EXPO,
                            a.UNIQCODE,
                            b.TYPE_EXPO,
                            c.FLDNAME,
                            c.ACTPASS,
                            a.CODVAL,
                            b.BANKACC,
                            b.IBAN,
                            b.EXT_IBAN,
                            a.OPEN_DATE,
                            a.CLOSE_DATE,
                            a.START_DATE,
                            b.EXPO_NAME,
                            e.ID_AGENT,
                            e.COD_AGENT,
                            a.ID_CUST
                       from Schema_Deal.AGENTS e,
                            Schema_Deal.AGENTS_PRODUCT_LINKS d,
                            Schema_GPSys.EXPOTYPES c,
                            Schema_GPSys.EXPOSITION b,
                            CURRENT_EXPO a
                      where a.ID_CUST = nIDCust and
                            ( nUniqCode = 0 or
                             a.UNIQCODE = nUniqCode ) and
                            ( sStatus is null or
                             a.STATUS = sStatus ) and
                            b.ID_EXPO = a.ID_EXPO and
                            b.TYPE_EXPO = c.TYPE_EXPO and
                            c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent and
                            b.ID_EXPO = d.ID_PRODUCT(+) and
                            d.ID_AGENT = e.ID_AGENT(+) and
                            d.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpCurrent
                    union all
                    select a.ID_EXPO,
                           a.UNIQCODE,
                           b.TYPE_EXPO,
                           c.FLDNAME,
                           c.ACTPASS,
                           a.CODVAL,
                           b.BANKACC,
                           b.IBAN,
                           b.EXT_IBAN,
                           a.OPEN_DATE,
                           a.CLOSE_DATE,
                           a.START_DATE,
                           b.EXPO_NAME,
                           e.ID_AGENT,
                           e.COD_AGENT,
                           a.ID_CUST
                      from Schema_Deal.AGENTS e,
                           Schema_Deal.AGENTS_PRODUCT_LINKS d,
                           Schema_GPSys.EXPOTYPES c,
                           Schema_GPSys.EXPOSITION b,
                           CURRENT_EXPO a,
                           EXPO_COTITULQRI x
                     where x.ID_CUST = nIDCust and
                           a.ID_EXPO = x.ID_EXPO and
                           ( nUniqCode = 0 or
                            a.UNIQCODE = nUniqCode ) and
                           ( sStatus is null or
                            a.STATUS = sStatus ) and
                           b.ID_EXPO = a.ID_EXPO and
                           b.TYPE_EXPO = c.TYPE_EXPO and
                           c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent and
                           b.ID_EXPO = d.ID_PRODUCT(+) and
                           d.ID_AGENT = e.ID_AGENT(+) and
                           d.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpCurrent  $else
    select a.ID_EXPO,
                                a.UNIQCODE,
                                b.TYPE_EXPO,
                                c.FLDNAME,
                                c.ACTPASS,
                                a.CODVAL,
                                b.BANKACC,
                                b.IBAN,
                                b.EXT_IBAN,
                                a.OPEN_DATE,
                                a.CLOSE_DATE,
                                a.START_DATE,
                                b.EXPO_NAME,
                                0 as ID_AGENT,
                                null as COD_AGENT,
                                a.ID_CUST
                           from Schema_GPSys.EXPOTYPES c,
                                Schema_GPSys.EXPOSITION b,
                                CURRENT_EXPO a
                          where a.ID_CUST = nIDCust and
                                ( nUniqCode = 0 or
                                 a.UNIQCODE = nUniqCode ) and
                                ( sStatus is null or
                                 a.STATUS = sStatus ) and
                                b.ID_EXPO = a.ID_EXPO and
                                b.TYPE_EXPO = c.TYPE_EXPO and
                                c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent
                        union all
                        select a.ID_EXPO,
                               a.UNIQCODE,
                               b.TYPE_EXPO,
                               c.FLDNAME,
                               c.ACTPASS,
                               a.CODVAL,
                               b.BANKACC,
                               b.IBAN,
                               b.EXT_IBAN,
                               a.OPEN_DATE,
                               a.CLOSE_DATE,
                               a.START_DATE,
                               b.EXPO_NAME,
                               0 as ID_AGENT,
                               null as COD_AGENT,
                               a.ID_CUST
                          from Schema_GPSys.EXPOTYPES c,
                               Schema_GPSys.EXPOSITION b,
                               CURRENT_EXPO a,
                               EXPO_COTITULQRI x
                         where x.ID_CUST = nIDCust and
                               a.ID_EXPO = x.ID_EXPO and
                               ( nUniqCode = 0 or
                                a.UNIQCODE = nUniqCode ) and
                               ( sStatus is null or
                                a.STATUS = sStatus ) and
                               b.ID_EXPO = a.ID_EXPO and
                               b.TYPE_EXPO = c.TYPE_EXPO and
                               c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpCurrent
    $end
                                                                                   ) loop
          if ( Schema_RA.GPC_SS.CheckRightExpo_VExpo_CUser( rec.TYPE_EXPO, rec.ID_EXPO ) and
              ( not bCheckUCode or
               Schema_RA.GPC_SS.CheckRightUCode_CUser( rec.UNIQCODE ) ) ) then
            bViewSaldo  := Schema_RA.GPC_SS.CheckRightExpo_VSaldo_CUser( rec.TYPE_EXPO, rec.ID_EXPO );
            bRet        := Expo.GetExpoHotSaldo( Rec.ID_EXPO, nSaldo );

            if ( rec.ACTPASS = 'P' ) then
              nFreeSaldo  := Expo.ExpoSumAvailable( Rec.ID_EXPO, dSchDate, false, 1 );
            else
              nFreeSaldo  := nSaldo;
            end if;

            sData       := null;
            bRet        := bRet and
                           Schema_GPSys.GPC_Parser.WriteInteger( Schema_GPSys.HeadExpo.ExpoGrpCurrent, sData ) and --  1
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_EXPO, sData ) and --  2
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.TYPE_EXPO, sData ) and --  3
                           Schema_GPSys.GPC_Parser.WriteString( rec.FLDNAME, sData ) and --  4
                           Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and --  5
                           Schema_GPSys.GPC_Parser.WriteString( rec.BANKACC, sData ) and --  6
                           Schema_GPSys.GPC_Parser.WriteAmount( nSaldo, sData ) and --  7
                           Schema_GPSys.GPC_Parser.WriteDate( rec.OPEN_DATE, sData ) and --  8
                           Schema_GPSys.GPC_Parser.WriteDate( dNullDate, sData ) and --  9
                           Schema_GPSys.GPC_Parser.WriteDate( rec.CLOSE_DATE, sData ) and -- 10
                           Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_NAME, sData ) and -- 11
                           Schema_GPSys.GPC_Parser.WriteAmount( nFreeSaldo, sData ) and -- 12
                           Schema_GPSys.GPC_Parser.WriteString( Expo.Check4Limits( Rec.ID_EXPO, dSchDate ), sData ) and -- 13
                           Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Tools.UniqCode2BankCode( Rec.UNIQCODE ), sData ) and -- 14
                           Schema_GPSys.GPC_Parser.WriteAmount( 0, sData ) and -- 15
                           Schema_GPSys.GPC_Parser.WriteLogic( bViewSaldo, sData ) and -- 16
                           Schema_GPSys.GPC_Parser.WriteDate( rec.START_DATE, sData ) and -- 17
                           Schema_GPSys.GPC_Parser.WriteInteger( Rec.UNIQCODE, sData ) and -- 18
                           Schema_GPSys.GPC_Parser.WriteString( rec.IBAN, sData ) and -- 19
                           Schema_GPSys.GPC_Parser.WriteString( Expo.GetExpoBKAcc( rec.ID_EXPO ), sData ) and --20
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_AGENT, sData ) and -- 21
                           Schema_GPSys.GPC_Parser.WriteString( rec.COD_AGENT, sData ) and -- 22
                           Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 23
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CUST, sData ) and --  24
                           Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 25
                           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 26
                           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 27
                           Schema_GPSys.GPC_Parser.WriteString( rec.EXT_IBAN, sData ) and -- 28
                           true;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            else
              exit;
            end if;
          end if;
        end loop;
      end if;

      if ( bRet and
          nvl( bDeposit, false ) ) then
        for rec in (  $if ( Schema_GPSys.OraSys.bModule_Deal ) $then
                    select  a.ID_EXPO,
                            a.UNIQCODE,
                            b.TYPE_EXPO,
                            c.FLDNAME,
                            c.ACTPASS,
                            a.CODVAL,
                            b.BANKACC,
                            b.IBAN,
                            b.EXT_IBAN,
                            a.OPEN_DATE,
                            a.LIHDATE,
                            a.START_DATE,
                            a.VID_SROK,
                            a.SROK,
                            a.CLOSE_DATE,
                            a.AVANS_LIH,
                            b.EXPO_NAME,
                            e.ID_AGENT,
                            e.COD_AGENT,
                            a.ID_CUST,
                            a.TODATE1
                       from Schema_Deal.AGENTS e,
                            Schema_Deal.AGENTS_PRODUCT_LINKS d,
                            Schema_GPSys.EXPOTYPES c,
                            Schema_GPSys.EXPOSITION b,
                            DEPOSIT_EXPO a
                      where a.ID_CUST = nIDCust and
                            ( nUniqCode = 0 or
                             a.UNIQCODE = nUniqCode ) and
                            ( sStatus is null or
                             a.STATUS = sStatus ) and
                            b.ID_EXPO = a.ID_EXPO and
                            b.TYPE_EXPO = c.TYPE_EXPO and
                            c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                            b.ID_EXPO = d.ID_PRODUCT(+) and
                            d.ID_AGENT = e.ID_AGENT(+) and
                            d.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpDeposit
                    union all
                    select a.ID_EXPO,
                           a.UNIQCODE,
                           b.TYPE_EXPO,
                           c.FLDNAME,
                           c.ACTPASS,
                           a.CODVAL,
                           b.BANKACC,
                           b.IBAN,
                           b.EXT_IBAN,
                           a.OPEN_DATE,
                           a.LIHDATE,
                           a.START_DATE,
                           a.VID_SROK,
                           a.SROK,
                           a.CLOSE_DATE,
                           a.AVANS_LIH,
                           b.EXPO_NAME,
                           e.ID_AGENT,
                           e.COD_AGENT,
                           a.ID_CUST,
                           a.TODATE1
                      from Schema_Deal.AGENTS e,
                           Schema_Deal.AGENTS_PRODUCT_LINKS d,
                           Schema_GPSys.EXPOTYPES c,
                           Schema_GPSys.EXPOSITION b,
                           DEPOSIT_EXPO a,
                           EXPO_COTITULQRI x
                     where x.ID_CUST = nIDCust and
                           a.ID_EXPO = x.ID_EXPO and
                           ( nUniqCode = 0 or
                            a.UNIQCODE = nUniqCode ) and
                           ( sStatus is null or
                            a.STATUS = sStatus ) and
                           b.ID_EXPO = a.ID_EXPO and
                           b.TYPE_EXPO = c.TYPE_EXPO and
                           c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                           b.ID_EXPO = d.ID_PRODUCT(+) and
                           d.ID_AGENT = e.ID_AGENT(+) and
                           d.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpDeposit      $else
     select a.ID_EXPO,
        a.UNIQCODE,
        b.TYPE_EXPO,
        c.FLDNAME,
        c.ACTPASS,
        a.CODVAL,
        b.BANKACC,
        b.IBAN,
        b.EXT_IBAN,
        a.OPEN_DATE,
        a.LIHDATE,
        a.START_DATE,
        a.VID_SROK,
        a.SROK,
        a.CLOSE_DATE,
        a.AVANS_LIH,
        b.EXPO_NAME,
        0 as ID_AGENT,
        null as COD_AGENT,
        a.ID_CUST,
        a.TODATE1
   from Schema_GPSys.EXPOTYPES c,
        Schema_GPSys.EXPOSITION b,
        DEPOSIT_EXPO a
  where a.ID_CUST = nIDCust and
        ( nUniqCode = 0 or
         a.UNIQCODE = nUniqCode ) and
        ( sStatus is null or
         a.STATUS = sStatus ) and
        b.ID_EXPO = a.ID_EXPO and
        b.TYPE_EXPO = c.TYPE_EXPO and
        c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpDeposit
union all
select a.ID_EXPO,
       a.UNIQCODE,
       b.TYPE_EXPO,
       c.FLDNAME,
       c.ACTPASS,
       a.CODVAL,
       b.BANKACC,
       b.IBAN,
       b.EXT_IBAN,
       a.OPEN_DATE,
       a.LIHDATE,
       a.START_DATE,
       a.VID_SROK,
       a.SROK,
       a.CLOSE_DATE,
       a.AVANS_LIH,
       b.EXPO_NAME,
       0 as ID_AGENT,
       null as COD_AGENT,
       a.ID_CUST,
       a.TODATE1
  from Schema_GPSys.EXPOTYPES c,
       Schema_GPSys.EXPOSITION b,
       DEPOSIT_EXPO a,
       EXPO_COTITULQRI x
 where x.ID_CUST = nIDCust and
       a.ID_EXPO = x.ID_EXPO and
       ( nUniqCode = 0 or
        a.UNIQCODE = nUniqCode ) and
       ( sStatus is null or
        a.STATUS = sStatus ) and
       b.ID_EXPO = a.ID_EXPO and
       b.TYPE_EXPO = c.TYPE_EXPO and
       c.FLDGROUP = Schema_GPSys.HeadExpo.ExpoGrpDeposit
       $end
                                                                                   ) loop
          if ( Schema_RA.GPC_SS.CheckRightExpo_VExpo_CUser( rec.TYPE_EXPO, rec.ID_EXPO ) and
              ( not bCheckUCode or
               Schema_RA.GPC_SS.CheckRightUCode_CUser( rec.UNIQCODE ) ) ) then
            bViewSaldo  := Schema_RA.GPC_SS.CheckRightExpo_VSaldo_CUser( rec.TYPE_EXPO, rec.ID_EXPO );
            bRet        := Expo.GetExpoHotSaldo( Rec.ID_EXPO, nSaldo );

            if ( rec.ACTPASS = 'P' ) then
              nFreeSaldo  := Expo.ExpoSumAvailable( Rec.ID_EXPO, dSchDate, false, 1 );
            else
              nFreeSaldo  := nSaldo;
            end if;

            if ( Schema_GPSys.OraGPSys.OracleBoolean( rec.AVANS_LIH ) ) then
              if ( OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositProgresia, rec.TYPE_EXPO ) ) then
                dAvanLih  := rec.OPEN_DATE;
              else
                dAvanLih  := rec.START_DATE;
              end if;

              nAvansLih  := CalcLih.AvansLihAlowed( rec.ID_EXPO, dAvanLih - 1, null );
            else
              nAvansLih  := 0;
            end if;

            if ( Schema_GPSys.HeadExpo.IsItOverNightDepo( rec.ID_EXPO, rec.TYPE_EXPO ) ) then
              dExpDate  := CALCLIH.ExpiryDate( rec.START_DATE, Schema_GPSys.HeadExpo.DepositVidSrok_Days, 1, rec.TODATE1 );
            else
              dExpDate  := CALCLIH.ExpiryDate( rec.START_DATE, rec.VID_SROK, rec.SROK, rec.TODATE1 );
            end if;

            sData       := null;
            bRet        := bRet and
                           Schema_GPSys.GPC_Parser.WriteInteger( Schema_GPSys.HeadExpo.ExpoGrpDeposit, sData ) and --  1
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_EXPO, sData ) and --  2
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.TYPE_EXPO, sData ) and --  3
                           Schema_GPSys.GPC_Parser.WriteString( rec.FLDNAME, sData ) and --  4
                           Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and --  5
                           Schema_GPSys.GPC_Parser.WriteString( rec.BANKACC, sData ) and --  6
                           Schema_GPSys.GPC_Parser.WriteAmount( nSaldo, sData ) and --  7
                           Schema_GPSys.GPC_Parser.WriteDate( rec.OPEN_DATE, sData ) and --  8
                           Schema_GPSys.GPC_Parser.WriteDate( dExpDate, sData ) and --  9
                           Schema_GPSys.GPC_Parser.WriteDate( rec.CLOSE_DATE, sData ) and -- 10
                           Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_NAME, sData ) and -- 11
                           Schema_GPSys.GPC_Parser.WriteAmount( nFreeSaldo, sData ) and -- 12
                           Schema_GPSys.GPC_Parser.WriteString( Expo.Check4Limits( Rec.ID_EXPO, dSchDate ), sData ) and -- 13
                           Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Tools.UniqCode2BankCode( Rec.UNIQCODE ), sData ) and -- 14
                           Schema_GPSys.GPC_Parser.WriteAmount( nAvansLih, sData ) and -- 15
                           Schema_GPSys.GPC_Parser.WriteLogic( bViewSaldo, sData ) and -- 16
                           Schema_GPSys.GPC_Parser.WriteDate( rec.START_DATE, sData ) and -- 17
                           Schema_GPSys.GPC_Parser.WriteInteger( Rec.UNIQCODE, sData ) and -- 18
                           Schema_GPSys.GPC_Parser.WriteString( rec.IBAN, sData ) and -- 19
                           Schema_GPSys.GPC_Parser.WriteString( Expo.GetExpoBKAcc( rec.ID_EXPO ), sData ) and -- 21
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_AGENT, sData ) and -- 22
                           Schema_GPSys.GPC_Parser.WriteString( rec.COD_AGENT, sData ) and -- 23
                           Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 23
                           Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CUST, sData ) and --  24
                           Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 25
                           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 26
                           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 27
                           Schema_GPSys.GPC_Parser.WriteString( rec.EXT_IBAN, sData ) and -- 28
                           true;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            else
              exit;
            end if;
          end if;
        end loop;
      end if;

      if ( bRet and
          nvl( bEngage, false ) ) then
        for rec in (  $if ( Schema_GPSys.OraSys.bModule_Deal ) $then
                    select  a.*,
                            c.ID_AGENT,
                            c.COD_AGENT
                       from Schema_Deal.AGENTS c,
                            Schema_Deal.AGENTS_PRODUCT_LINKS b,
                            LOAN_ENGAGE a
                      where a.ID_CUST = nIDCust and
                            ( nUniqCode = 0 or
                             a.UNIQCODE = nUniqCode ) and
                            ( sStatus is null or
                             a.STATUS = sStatus ) and
                            a.ID_CRED_ENGAGE = b.ID_PRODUCT(+) and
                            b.ID_AGENT = c.ID_AGENT(+) and
                            b.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpEngage  $else
   select a.*,
      0 as ID_AGENT,
      null as COD_AGENT
 from LOAN_ENGAGE a
where a.ID_CUST = nIDCust and
      ( nUniqCode = 0 or
       a.UNIQCODE = nUniqCode ) and
      ( sStatus is null or
       a.STATUS = sStatus )
   $end
                                                                                   ) loop
          if ( not bCheckUCode or
              Schema_RA.GPC_SS.CheckRightUCode_CUser( rec.UNIQCODE ) ) then
            select nvl( min( ID_MKU ), 0 )
              into nIDMKU
              from LOAN_MKU_RELS
             where ID_CRED_ENGAGE = rec.ID_CRED_ENGAGE and
                   nvl( MODE_OBJECT, CMD_Loans_MKU.nLoanEngage2MKU ) = CMD_Loans_MKU.nLoanEngage2MKU;

            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( Schema_GPSys.HeadExpo.ExpoGrpEngage, sData ) and --  1
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CRED_ENGAGE, sData ) and --  2
                         Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and --  3
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.NomID2NomName( 'NOM_TYPE_EB', rec.ENGAGE_TYPE ), sData ) and --  4
                         Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and --  5
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  6
                         Schema_GPSys.GPC_Parser.WriteAmount( rec.AMOUNT, sData ) and --  7
                         Schema_GPSys.GPC_Parser.WriteDate( rec.OPEN_DATE, sData ) and --  8
                         Schema_GPSys.GPC_Parser.WriteDate( rec.EXP_DATE, sData ) and --  9
                         Schema_GPSys.GPC_Parser.WriteDate( rec.CLOSE_DATE, sData ) and -- 10
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.NomID2NomName( 'NOM_MODE_EB', rec.ENGAGE_AIM ), sData ) and -- 11
                         Schema_GPSys.GPC_Parser.WriteAmount( rec.AMOUNT, sData ) and -- 12
                         Schema_GPSys.GPC_Parser.WriteString( cSymbol, sData ) and -- 13
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Tools.UniqCode2BankCode( Rec.UNIQCODE ), sData ) and -- 14
                         Schema_GPSys.GPC_Parser.WriteAmount( 0, sData ) and -- 15
                         Schema_GPSys.GPC_Parser.WriteLogic( true, sData ) and -- 16
                         Schema_GPSys.GPC_Parser.WriteDate( null, sData ) and -- 17
                         Schema_GPSys.GPC_Parser.WriteInteger( Rec.UNIQCODE, sData ) and -- 18
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 19
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 20
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_AGENT, sData ) and -- 21
                         Schema_GPSys.GPC_Parser.WriteString( rec.COD_AGENT, sData ) and -- 22
                         Schema_GPSys.GPC_Parser.WriteInteger( nIDMKU, sData ) and -- 23
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CUST, sData ) and --  24
                         Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 25
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 26
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 27
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 28
                         true;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            else
              exit;
            end if;
          end if;
        end loop;
      end if;

      if ( bRet and
          nvl( bCredit, false ) ) then
        for rec in ( select *
                       from LOAN_CREDIT
                      where ID_CUST = nIDCust and
                            ( nUniqCode = 0 or
                             UNIQCODE = nUniqCode ) and
                            ( sStatus is null or
                             STATUS = sStatus )
                    union all
                    select *
                      from LOAN_CREDIT_DEP
                     where ID_CUST = nIDCust and
                           ( nUniqCode = 0 or
                            UNIQCODE = nUniqCode ) and
                           ( sStatus is null or
                            STATUS = sStatus ) ) loop
          if ( not bCheckUCode or
              Schema_RA.GPC_SS.CheckRightUCode_CUser( rec.UNIQCODE ) ) then
            $if ( Schema_GPSys.OraSys.bModule_Deal ) $then
            begin
              select b.ID_AGENT,
                     b.COD_AGENT
                into nIDAgent,
                     cAgnCode
                from Schema_Deal.AGENTS b,
                     Schema_Deal.AGENTS_PRODUCT_LINKS a
               where a.ID_PRODUCT = rec.ID_CRED_ENGAGE and
                     a.TYPEPRODUCT = Schema_GPSys.HeadExpo.ExpoGrpCredit and
                     a.ID_AGENT = b.ID_AGENT;
            exception
              when no_data_found then
                cAgnCode  := null;
                nIDAgent  := 0;
            end;

            $else
            cAgnCode  := null;
              nIDAgent  := 0;
            $end
            select nvl( min( ID_MKU ), 0 )
              into nIDMKU
              from LOAN_MKU_RELS
             where ID_CRED_ENGAGE = rec.ID_CRED_ENGAGE and
                   nvl( MODE_OBJECT, CMD_Loans_MKU.nLoanEngage2MKU ) = CMD_Loans_MKU.nLoanEngage2MKU;

            select nvl( min( PACKET_ID ), 0 )
              into nPacket
              from LOAN_INSURANCE
             where ID_CRED_ENGAGE = rec.ID_CRED_ENGAGE and
                   ID_CUST = rec.ID_CUST and
                   STATUS = Loans.LoanStat_Active;

            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( Schema_GPSys.HeadExpo.ExpoGrpCredit, sData ) and --  1
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CRED_ENGAGE, sData ) and --  2
                         Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and --  3
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.CredProgram2Name( rec.PROGRAMA ), sData ) and --  4
                         Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and --  5
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  6
                         Schema_GPSys.GPC_Parser.WriteAmount( rec.AMOUNT, sData ) and --  7
                         Schema_GPSys.GPC_Parser.WriteDate( rec.OPEN_DATE, sData ) and --  8
                         Schema_GPSys.GPC_Parser.WriteDate( rec.EXP_DATE, sData ) and --  9
                         Schema_GPSys.GPC_Parser.WriteDate( rec.CLOSE_DATE, sData ) and -- 10
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.CredObjEB2Name( rec.CRED_AIM ), sData ) and -- 11
                         Schema_GPSys.GPC_Parser.WriteAmount( rec.AMOUNT, sData ) and -- 12
                         Schema_GPSys.GPC_Parser.WriteString( cSymbol, sData ) and -- 13
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Tools.UniqCode2BankCode( Rec.UNIQCODE ), sData ) and -- 14
                         Schema_GPSys.GPC_Parser.WriteAmount( nvl( Loans.CalcCreditEngagement( rec, dSchDate ), 0 ), sData ) and -- 15
                         Schema_GPSys.GPC_Parser.WriteLogic( true, sData ) and -- 16
                         Schema_GPSys.GPC_Parser.WriteDate( rec.REQEARLYDATE, sData ) and -- 17
                         Schema_GPSys.GPC_Parser.WriteInteger( Rec.UNIQCODE, sData ) and -- 18
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 19
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 20
                         Schema_GPSys.GPC_Parser.WriteInteger( nIDAgent, sData ) and -- 21
                         Schema_GPSys.GPC_Parser.WriteString( cAgnCode, sData ) and -- 22
                         Schema_GPSys.GPC_Parser.WriteInteger( nIDMKU, sData ) and -- 23
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CUST, sData ) and --  24
                         Schema_GPSys.GPC_Parser.WriteInteger( nPacket, sData ) and -- 25
                         Schema_GPSys.GPC_Parser.WriteString( rec.PROGRAMA, sData ) and -- 26
                         Schema_GPSys.GPC_Parser.WriteString( rec.STATUS, sData ) and -- 27
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 28
                         true;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            else
              exit;
            end if;
          end if;
        end loop;
      end if;

      if ( bRet and
          nvl( bCover, false ) ) then
        for rec in (  $if ( Schema_GPSys.OraSys.bModule_Deal ) $then
                    select  a.*,
                            c.ID_AGENT,
                            c.COD_AGENT
                       from Schema_Deal.AGENTS c,
                            Schema_Deal.AGENTS_PRODUCT_LINKS b,
                            LOAN_COVER a
                      where a.ID_CUST = nIDCust and
                            ( nUniqCode = 0 or
                             a.UNIQCODE = nUniqCode ) and
                            ( sStatus is null or
                             a.STATUS = sStatus ) and
                            a.ID_COVER = b.ID_PRODUCT(+) and
                            b.ID_AGENT = c.ID_AGENT(+) and
                            b.TYPEPRODUCT(+) = Schema_GPSys.HeadExpo.ExpoGrpCover      $else
      select a.*,
      0 as ID_AGENT,
      null as COD_AGENT
 from LOAN_COVER a
where a.ID_CUST = nIDCust and
      ( nUniqCode = 0 or
       a.UNIQCODE = nUniqCode ) and
      ( sStatus is null or
       a.STATUS = sStatus )
      $end
                                                                                  ) loop
          if ( not bCheckUCode or
              Schema_RA.GPC_SS.CheckRightUCode_CUser( rec.UNIQCODE ) ) then
            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( Schema_GPSys.HeadExpo.ExpoGrpCover, sData ) and --  1
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_COVER, sData ) and --  2
                         Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and --  3
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.NomID2NomName( 'NOM_COVER_KIND', rec.COVER_MODE ), sData ) and --  4
                         Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and --  5
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  6
                         Schema_GPSys.GPC_Parser.WriteAmount( rec.AMOUNT, sData ) and --  7
                         Schema_GPSys.GPC_Parser.WriteDate( rec.BEG_DATE, sData ) and --  8
                         Schema_GPSys.GPC_Parser.WriteDate( rec.END_DATE, sData ) and --  9
                         Schema_GPSys.GPC_Parser.WriteDate( rec.CLOSE_DATE, sData ) and -- 10
                         Schema_GPSys.GPC_Parser.WriteString( rec.NAME_COVER, sData ) and -- 11
                         Schema_GPSys.GPC_Parser.WriteAmount( rec.AMOUNT, sData ) and -- 12
                         Schema_GPSys.GPC_Parser.WriteString( cSymbol, sData ) and -- 13
                         Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Tools.UniqCode2BankCode( Rec.UNIQCODE ), sData ) and -- 14
                         Schema_GPSys.GPC_Parser.WriteAmount( 0, sData ) and -- 15
                         Schema_GPSys.GPC_Parser.WriteLogic( true, sData ) and -- 16
                         Schema_GPSys.GPC_Parser.WriteDate( null, sData ) and -- 17
                         Schema_GPSys.GPC_Parser.WriteInteger( Rec.UNIQCODE, sData ) and -- 18
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 19
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 20
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_AGENT, sData ) and -- 21
                         Schema_GPSys.GPC_Parser.WriteString( rec.COD_AGENT, sData ) and -- 22
                         Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 23
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CUST, sData ) and --  24
                         Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 25
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 26
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 27
                         Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 28
                         true;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            else
              exit;
            end if;
          end if;
        end loop;
      end if;

      if ( bRet and
          Schema_GPSys.ORASYS.bModule_Cards and
          nvl( bCard, false ) ) then
        execute immediate 'begin Schema_Cards.BORICA.GetCustProducts_Cards (:1, :2, :3, :4 ); end;' using in nIDCust, in nUniqCode, out cRet, in sStatus;

        bRet  := nvl( cRet = 'T', false );
      end if;
    end if;

    $end
    return bRet;
  exception
    when no_data_found then
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      return true;
  end CmdGetCustProducts;

  --------------------------------------------------------------------------------
  function CmdObjGroupRelLoad( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nIDCust     integer;
    nUniqCode   integer;
    nCurrent    pls_integer := 0;
    bRet        boolean;
    bStop       boolean;
    sData       varchar2( 4000 );
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDCust ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nUniqCode );

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      Schema_GPSys.GPC_Parser.RespAddTable( 1 );

      for rec in ( select *
                     from OBJ_GROUP_REL
                    where ID_CUST = nIDCust and
                          UNIQCODE = nUniqCode ) loop
        nCurrent  := nCurrent + 1;

        if ( not ( Schema_RA.GPC_RA.CheckStopField( bStop, nCurrent, nCurrent ) and
                  ( not bStop ) ) ) then
          bRet  := false;
          exit;
        end if;

        sData     := null;
        bRet      := bRet and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_GROUP, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.TYPE_OBJ1, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_OBJ1, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.TYPE_OBJ2, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_OBJ2, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rec.STATUS, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.CH_OPER, sData );

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdObjGroupRelLoad;

  --------------------------------------------------------------------------------
  function LoadExpoData(
    nIDExpo       in     integer,
    sData         in out varchar2,
    sIBAN            out varchar2,
    bAddCustData  in     boolean := true
  )
    return boolean is
    RecExpo   Schema_GPSys.EXPOSITION%rowtype;
    sAccount  varchar2( 1000 );
    sTemp     varchar2( 1000 );
    aParams   Schema_RA.GPC_RA.tblErrParams;
  begin
    select *
      into RecExpo
      from Schema_GPSys.EXPOSITION
     where ID_EXPO = nIDExpo;

    sIBAN  := RecExpo.IBAN;

    if ( RecExpo.BANKACC is null ) then
      sAccount  := Expo.GetExpoBKAcc( nIDExpo );
    else
      sAccount  := Schema_GPSys.OraGPSys.GetSynt( RecExpo.EXPO_CODE ) || '-' || RecExpo.BANKACC;
    end if;

    if ( RecExpo.ID_CUST > 0 and
        bAddCustData ) then
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'ID_CUST';
      aParams( 1 ).ML_VALUE  := to_char( RecExpo.ID_CUST );
      sTemp                  := ' ' || Schema_GPSys.MLng.Str2( 'Кл.№$ID_CUST$', Schema_GPSys.MLng.ctxLoans, Schema_GPSys.MLng.lngBG, aParams );
    end if;

    return Schema_GPSys.GPC_Parser.WriteString( RecExpo.EXPO_NAME || sTemp, sData ) and
           Schema_GPSys.GPC_Parser.WriteString( sAccount, sData ) and
           Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.HeadExpo.IDExpo2TypeName( nIDExpo ), sData );
  exception
    when no_data_found then
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      return false;
  end LoadExpoData;

  --------------------------------------------------------------------------------
  function GetBDGProgramsName( nPrgID in varchar2 )
    return varchar2 is
    sProgramName  varchar2( 100 );
  begin
    $if ( Schema_GPSys.OraSys.VerBNT ) $then
    begin
      select NAME_PROG
        into sProgramName
        from Schema_DMA.BDG_PROGRAMS
       where ID_PROG = nPrgID;
    exception
      when no_data_found then
        sProgramName  := null;
    end;

    return sProgramName;
  $else
    return null;
  $end
  end GetBDGProgramsName;

  --------------------------------------------------------------------------------
  function LoadBDGData(
    nIdMove     in     integer,
    nOrdRowNum  in     integer,
    sData       in out varchar2
  )
    return boolean is
    recBDG  BDG_MOVES%rowtype;
  begin
    $if ( Schema_GPSys.OraSys.VerBNT ) $then
    begin
      select *
        into recBDG
        from BDG_MOVES
       where ID_MOVE = nIdMove and
             ORDROWNUM = nOrdRowNum;
    exception
      when others then
        recBDG  := null;
    end;

    return Schema_GPSys.GPC_Parser.WriteString( recBDG.BDG_CLASSIF, sData ) and --  1
           Schema_GPSys.GPC_Parser.WriteString( recBDG.BDG_FUNCTION, sData ) and --  2
           Schema_GPSys.GPC_Parser.WriteString( recBDG.BDG_OBJECT, sData ) and --  3
           Schema_GPSys.GPC_Parser.WriteString( GetBDGProgramsName( recBDG.BDG_OBJECT ), sData ) and --  4
           Schema_GPSys.GPC_Parser.WriteString( recBDG.DT_KT, sData ) and --  5
           Schema_GPSys.GPC_Parser.WriteString( recBDG.CODVAL, sData ) and --  6
           Schema_GPSys.GPC_Parser.WriteNumber( recBDG.AMOUNT, sData ) and --  7
           Schema_GPSys.GPC_Parser.WriteNumber( recBDG.SYS_AMOUNT, sData ); --                           8
  $else
    return Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  1
           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  2
           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  3
           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  4
           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  5
           Schema_GPSys.GPC_Parser.WriteString( null, sData ) and --  6
           Schema_GPSys.GPC_Parser.WriteNumber( null, sData ) and --  7
           Schema_GPSys.GPC_Parser.WriteNumber( null, sData ); --     8
  $end
  end LoadBDGData;

  --------------------------------------------------------------------------------
  function LoadAddData(
    nIdMove     in     integer,
    nOrdRowNum  in     integer,
    sData       in out varchar2
  )
    return boolean is
    recADD_DT  ADD_MOVES%rowtype;
    recADD_KT  ADD_MOVES%rowtype;
  begin
    begin
      select ADD_CLASSIF,
             AMOUNT
        into recADD_DT.ADD_CLASSIF,
             recADD_DT.AMOUNT
        from ADD_MOVES
       where ID_MOVE = nIdMove and
             ORDROWNUM = nOrdRowNum and
             DT_KT = 'D';
    exception
      when others then
        recADD_DT  := null;
    end;

    begin
      select ADD_CLASSIF,
             AMOUNT
        into recADD_KT.ADD_CLASSIF,
             recADD_KT.AMOUNT
        from ADD_MOVES
       where ID_MOVE = nIdMove and
             ORDROWNUM = nOrdRowNum and
             DT_KT = 'K';
    exception
      when others then
        recADD_KT  := null;
    end;

    return Schema_GPSys.GPC_Parser.WriteString( recADD_DT.ADD_CLASSIF, sData ) and --  1
           Schema_GPSys.GPC_Parser.WriteNumber( recADD_DT.AMOUNT, sData ) and --  2
           Schema_GPSys.GPC_Parser.WriteString( recADD_KT.ADD_CLASSIF, sData ) and --  3
           Schema_GPSys.GPC_Parser.WriteNumber( recADD_KT.AMOUNT, sData ); --          4
  end LoadAddData;

  --------------------------------------------------------------------------------
  function CmdMemoOrderCashDoc( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues    Schema_GPSys.GPC_Parser.taParamStrings;
    RecExpoMove   EXPO_MOVES%rowtype;
    bRet          boolean;
    bStop         boolean;
    nCurrent      integer := 0;
    nCurNum       integer := 0;
    sData         varchar2( 4000 );

    type recCashDoc is record(
      RecName      varchar2( 1000 ),
      BankAcc      varchar2( 10 ),
      BankCode     varchar2( 8 ),
      UniqCode     integer,
      CodVal       varchar2( 3 ),
      Amount       number,
      SendName     varchar2( 1000 ),
      EGN          varchar2( 20 ),
      LichnaKarta  varchar2( 1000 ),
      OrdText      varchar2( 4000 ),
      IdExpo       integer,
      IBAN         varchar2( 34 ),
      ExpoUCode    integer,
      DateTime     varchar2( 20 ),
      DealNum      integer,
      LKDate       date,
      Unit         integer,
      ChOper       integer,
      IdCashDoc    integer
    );

    type tblCashDoc is table of recCashDoc
      index by binary_integer;

    RecDocCashDt  tblCashDoc;
    RecDocCashKt  tblCashDoc;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 aRowValues.count >= 4 and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), RecExpoMove.ID_MOVE ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), RecExpoMove.UNIQCODE ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), RecExpoMove.SCH_DATE ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), RecExpoMove.SCH_DOC ) and
                 ( nvl( RecExpoMove.ID_MOVE, 0 ) != 0 or
                  ( nvl( RecExpoMove.UNIQCODE, 0 ) != 0 and
                   RecExpoMove.SCH_DATE is not null and
                   nvl( RecExpoMove.SCH_DOC, 0 ) != 0 ) );

    if ( bRet ) then
      Schema_GPSys.GPC_Parser.RespAddArray( 1 );

      if ( RecExpoMove.ID_MOVE = 0 ) then
        begin
          select ID_MOVE
            into RecExpoMove.ID_MOVE
            from EXPO_MOVES
           where SCH_DATE = RecExpoMove.SCH_DATE and
                 UNIQCODE = RecExpoMove.UNIQCODE and
                 SCH_DOC = RecExpoMove.SCH_DOC and
                 rownum < 2;
        exception
          when no_data_found then
            bRet  := false;
            Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
        end;
      end if;

      if ( bRet ) then
        for rec in (  select a.DT_KT,
                             a.AMOUNT,
                             a.ID_EXPO,
                             a.UNIQCODE as UNIQCODE,
                             a.DEAL_NUM,
                             b.ORD_TEXT,
                             b.DATETIME,
                             b.CH_OPER,
                             c.CODVAl,
                             c.FLD_UNIT,
                             f.OPER_TYPE,
                             g.UNIQCODE as EXPOUCODE,
                             g.BANKACC,
                             g.IBAN,
                             h.id,
                             trim( trim( h.FIRSTNAME ) || ' ' || trim( h.MIDLENAME ) || ' ' || trim( h.LASTNAME ) ) as REC_NAME,
                             e.FLDBANKCODE,
                             k.id as SEND_ID,
                             trim( trim( k.FIRSTNAME ) || ' ' || trim( k.MIDLENAME ) || ' ' || trim( k.LASTNAME ) ) as SEND_NAME,
                             nvl( k.EGN, k.ENCH ) as EGN,
                             decode( nvl( l.FLDFOREIGN, 'F' ), 'F', k.LICHNAKARTA, k.PASSPORT ) as LICHNAKARTA,
                             decode( nvl( l.FLDFOREIGN, 'F' ), 'F', k.LK_DATEIZD, k.PASSPORT_DATE ) as LK_DATEIZD,
                             m.ID_CASH_DOC
                        from EXPO_MOVES a,
                             EXPO_MOVE_TEXT b,
                             Schema_GPSys.EXPOSITION c,
                             Schema_GPSys.EXPOTYPES d,
                             EXPO_MOVES f,
                             Schema_GPSys.EXPOSITION g,
                             Schema_Cust.CUSTOMS h,
                             Schema_RA.CONFIG e,
                             Schema_Cust.CUSTOMS k,
                             Schema_Cust.NOM_CUSTTYPES l,
                             CASH_DOCS m
                       where a.ID_MOVE = RecExpoMove.ID_MOVE and
                             a.ID_MOVE = b.ID_MOVE and
                             a.ID_EXPO = c.ID_EXPO and
                             c.TYPE_EXPO = d.TYPE_EXPO and
                             d.BASE_TYPE = Schema_GPSys.HeadExpo.ExpoCash and
                             a.ID_MOVE = f.ID_MOVE and
                             a.ORDROWNUM = f.ORDROWNUM and
                             a.ID_EXPO <> f.ID_EXPO and
                             a.DT_KT <> f.DT_KT and
                             f.ID_EXPO = g.ID_EXPO and
                             g.ID_CUST = h.id(+) and
                             e.FLDUNIQCODE = a.UNIQCODE and
                             b.ID_CUST = k.id(+) and
                             k.FTYPE = l.FLDFTYPEID(+) and
                             a.ID_MOVE = m.ID_MOVE(+)
                    order by a.ORDROWNUM ) loop
          if ( rec.OPER_TYPE = Sch_RateDiffer and
              rec.DT_KT = 'D' and
              RecDocCashDt( RecDocCashDt.count ).IdExpo = rec.ID_EXPO ) then
            RecDocCashDt( RecDocCashDt.count ).Amount  := RecDocCashDt( RecDocCashDt.count ).Amount + rec.Amount;
          elsif ( rec.OPER_TYPE = Sch_RateDiffer and
                 rec.DT_KT = 'K' and
                 RecDocCashKt( RecDocCashKt.count ).IdExpo = rec.ID_EXPO ) then
            RecDocCashKt( RecDocCashKt.count ).Amount  := RecDocCashKt( RecDocCashKt.count ).Amount + rec.Amount;
          elsif ( rec.DT_KT = 'D' ) then
            nCurNum                              := RecDocCashDt.count + 1;
            RecDocCashDt( nCurNum ).RecName      := rec.REC_NAME;
            RecDocCashDt( nCurNum ).BankAcc      := rec.BANKACC;
            RecDocCashDt( nCurNum ).BankCode     := rec.FLDBANKCODE;
            RecDocCashDt( nCurNum ).UniqCode     := rec.UNIQCODE;
            RecDocCashDt( nCurNum ).CodVal       := rec.CODVAL;
            RecDocCashDt( nCurNum ).Amount       := rec.Amount;
            RecDocCashDt( nCurNum ).SendName     := rec.SEND_NAME;
            RecDocCashDt( nCurNum ).EGN          := rec.EGN;
            RecDocCashDt( nCurNum ).LichnaKarta  := rec.LICHNAKARTA;
            RecDocCashDt( nCurNum ).OrdText      := rec.ORD_TEXT;
            RecDocCashDt( nCurNum ).IdExpo       := rec.ID_EXPO;
            RecDocCashDt( nCurNum ).IBAN         := rec.IBAN;
            RecDocCashDt( nCurNum ).ExpoUCode    := rec.EXPOUCODE;
            RecDocCashDt( nCurNum ).DateTime     := rec.DATETIME;
            RecDocCashDt( nCurNum ).DealNum      := rec.DEAL_NUM;
            RecDocCashDt( nCurNum ).LKDate       := rec.LK_DATEIZD;
            RecDocCashDt( nCurNum ).Unit         := rec.FLD_UNIT;
            RecDocCashDt( nCurNum ).ChOper       := rec.CH_OPER;
            RecDocCashDt( nCurNum ).IdCashDoc    := rec.ID_CASH_DOC;
          else
            nCurNum                              := RecDocCashKt.count + 1;
            RecDocCashKt( nCurNum ).RecName      := rec.REC_NAME;
            RecDocCashKt( nCurNum ).BankAcc      := rec.BANKACC;
            RecDocCashKt( nCurNum ).BankCode     := rec.FLDBANKCODE;
            RecDocCashKt( nCurNum ).UniqCode     := rec.UNIQCODE;
            RecDocCashKt( nCurNum ).CodVal       := rec.CODVAL;
            RecDocCashKt( nCurNum ).Amount       := rec.Amount;
            RecDocCashKt( nCurNum ).SendName     := rec.SEND_NAME;
            RecDocCashKt( nCurNum ).EGN          := rec.EGN;
            RecDocCashKt( nCurNum ).LichnaKarta  := rec.LICHNAKARTA;
            RecDocCashKt( nCurNum ).OrdText      := rec.ORD_TEXT;
            RecDocCashKt( nCurNum ).IdExpo       := rec.ID_EXPO;
            RecDocCashKt( nCurNum ).IBAN         := rec.IBAN;
            RecDocCashKt( nCurNum ).ExpoUCode    := rec.EXPOUCODE;
            RecDocCashKt( nCurNum ).DateTime     := rec.DATETIME;
            RecDocCashKt( nCurNum ).DealNum      := rec.DEAL_NUM;
            RecDocCashKt( nCurNum ).LKDate       := rec.LK_DATEIZD;
            RecDocCashKt( nCurNum ).Unit         := rec.FLD_UNIT;
            RecDocCashKt( nCurNum ).ChOper       := rec.CH_OPER;
            RecDocCashKt( nCurNum ).IdCashDoc    := rec.ID_CASH_DOC;
          end if;

          nCurrent  := nCurrent + 1;
          bRet      := bRet and
                       Schema_RA.GPC_RA.ChkStopField( nCurrent, nCurrent );
          exit when not bRet;
        end loop;
      end if;

      if ( RecDocCashDt.count > 0 and
          bRet ) then
        for ii in RecDocCashDt.first .. RecDocCashDT.last loop
          sData     := null;
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.WriteString( '1', sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).RecName, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).BankAcc, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).BankCode, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashDt( ii ).UniqCode, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).CodVal, sData ) and
                       Schema_GPSys.GPC_Parser.WriteAmount( RecDocCashDt( ii ).Amount, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).SendName, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).EGN, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).LICHNAKARTA, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).OrdText, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashDt( ii ).IdExpo, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).IBAN, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).ExpoUCode, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( Expo.GetExpoBKAcc( RecDocCashDt( ii ).IdExpo ), sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashDt( ii ).DateTime, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashDt( ii ).DealNum, sData ) and
                       Schema_GPSys.GPC_Parser.WriteDate( RecDocCashDt( ii ).LKDate, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashDt( ii ).Unit, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashDt( ii ).ChOper, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashDt( ii ).IdCashDoc, sData ) and
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( RecDocCashKt.count > 0 and
          bRet ) then
        for ii in RecDocCashKt.first .. RecDocCashKt.last loop
          sData     := null;
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.WriteString( '2', sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).RecName, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).BankAcc, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).BankCode, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashKt( ii ).UniqCode, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).CodVal, sData ) and
                       Schema_GPSys.GPC_Parser.WriteAmount( RecDocCashKt( ii ).Amount, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).SendName, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).EGN, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).LICHNAKARTA, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).OrdText, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashKt( ii ).IdExpo, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).IBAN, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).ExpoUCode, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( Expo.GetExpoBKAcc( RecDocCashKt( ii ).IdExpo ), sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( RecDocCashKt( ii ).DateTime, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashKt( ii ).DealNum, sData ) and
                       Schema_GPSys.GPC_Parser.WriteDate( RecDocCashKt( ii ).LKDate, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashKt( ii ).Unit, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashKt( ii ).ChOper, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( RecDocCashKt( ii ).IdCashDoc, sData ) and
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      bRet      := bRet and
                   Cmd_Expo_Add2.WriteTaxesByIDMove( RecExpoMove.ID_MOVE );
    end if;

    return bRet;
  end CmdMemoOrderCashDoc;

  --------------------------------------------------------------------------------
  function CmdLoadMemoOrder( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues        Schema_GPSys.GPC_Parser.taParamStrings;
    oDoc              Schema_GPSys.RecDocSysType;
    oDealList         Schema_GPSys.DocSysList;
    oDeal             Schema_GPSys.RecDocSysType;
    oOperList         Schema_GPSys.DocSysList;
    oOper             Schema_GPSys.RecDocSysType;
    aAvisoExpos       Schema_GPSys.OraGPSys.aNumbers;
    aAvisoCusts       Schema_GPSys.OraGPSys.aNumbers;
    rCustData         Schema_Cust.GPC_Customs.recCustData;
    RecExpoMove       EXPO_MOVES%rowtype;
    RecMoveText       EXPO_MOVE_TEXT%rowtype;
    recExpoOrderConf  EXPO_ORDER_CONF_REG%rowtype;
    cCmdName          varchar2( 20 ) := 'LoadMemoOrder';
    bRet              boolean;
    bDTCash           boolean;
    bKTCash           boolean;
    bFirstRow         boolean;
    bExclZBal         boolean := false;
    DocType           integer;
    nIDCust           integer;
    nRowNum           integer;
    nDealNum          integer;
    nIDMainExpo       integer;
    nDealType         integer;
    nMainExpoCust     integer;
    kk                integer;
    nIDExpoDT         integer;
    nIDExpoKT         integer;
    nRate             number;
    sData             varchar2( 4000 );
    sDummy            varchar2( 2000 );
    sRefer            varchar2( 2000 );
    sOrdText          varchar2( 2000 );
    sOper             varchar2( 256 );
    sCashName         varchar2( 256 );
    sEGN              varchar2( 20 );
    sCustName         varchar2( 200 );
    sPCardNo          varchar2( 9 );
    sPCardIzdadenaOt  varchar2( 100 );
    sAddress          varchar2( 4000 );
    sIBAN_DT          varchar2( 40 );
    sIBAN_KT          varchar2( 40 );
    rExpoMove         EXPO.recExpoMove;
    aResp             Schema_GPSys.OraGPSys.aStrings;
    aSchDocType       Schema_GPSys.OraGPSys.aNumbers;
    aExpo             Schema_GPSys.OraGPSys.aNumbers;
    aSchRefer         Schema_GPSys.OraGPSys.aStrings;
    dValiorDt         date;
    dPCardDate        date;

    type tSchRows is table of Schema_GPSys.RecDocSysType
      index by binary_integer;

    aSchRows          tSchRows;
    sSuffix           varchar2( 1000 );
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 aRowValues.count >= 4 and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), RecExpoMove.ID_MOVE ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), RecExpoMove.UNIQCODE ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), RecExpoMove.SCH_DATE ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), RecExpoMove.SCH_DOC );

    if ( aRowValues.exists( 5 ) ) then
      bRet      := bRet and
                   Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 5 ), bExclZBal );
    end if;

    if ( aRowValues.exists( 8 ) ) then
      bRet      := bRet and
                   Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), RecMoveText.FOLDER_MODE ) and
                   Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 7 ), RecMoveText.FOLDER_DATE ) and
                   Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 8 ), RecMoveText.FOLDER_NMBR );
    end if;

    bRet      := bRet and
                 ( RecExpoMove.ID_MOVE > 0 or
                  ( RecExpoMove.UNIQCODE > 0 and
                   RecExpoMove.SCH_DATE is not null and
                   RecExpoMove.SCH_DOC > 0 ) or
                  ( RecMoveText.FOLDER_MODE is not null and
                   RecMoveText.FOLDER_DATE is not null and
                   RecMoveText.FOLDER_NMBR > 0 ) );

    if ( bRet ) then
      begin
        if ( RecExpoMove.ID_MOVE > 0 ) then
          -- проверяваме дали има такова МО за да знаем какво съобщение да извадим
          $if ( Schema_GPSys.OraSys.VerFIS ) $then
          select distinct ID_MOVE
            into RecExpoMove.ID_MOVE
            from EXPO_MOVES
           where ID_MOVE = RecExpoMove.ID_MOVE and
                 UNIQCODE = RecExpoMove.UNIQCODE;
        $else
          select distinct ID_MOVE
            into RecExpoMove.ID_MOVE
            from EXPO_MOVES
           where ID_MOVE = RecExpoMove.ID_MOVE;
        $end
        elsif ( RecExpoMove.UNIQCODE > 0 and
               RecExpoMove.SCH_DATE is not null and
               RecExpoMove.SCH_DOC > 0 ) then
          select distinct ID_MOVE
            into RecExpoMove.ID_MOVE
            from EXPO_MOVES
           where UNIQCODE = RecExpoMove.UNIQCODE and
                 SCH_DATE = RecExpoMove.SCH_DATE and
                 SCH_DOC = RecExpoMove.SCH_DOC;
        else
          select distinct ID_MOVE
            into RecExpoMove.ID_MOVE
            from EXPO_MOVE_TEXT
           where FOLDER_MODE = RecMoveText.FOLDER_MODE and
                 FOLDER_DATE = RecMoveText.FOLDER_DATE and
                 FOLDER_NMBR = RecMoveText.FOLDER_NMBR;
        end if;
      exception
        when others then
          bRet  := false;
          Schema_RA.GPC_RA.RespSetErrorText( 'Няма такъв мемориален ордер', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
      end;

      if ( bRet ) then
        select distinct ID_EXPO
          bulk collect into aExpo
          from EXPO_MOVES
         where ID_MOVE = RecExpoMove.ID_MOVE;

        for ii in 1 .. aExpo.count loop
          bRet  := Schema_RA.GPC_SS.CheckRightExpo_VExpo_CUser( Schema_GPSys.HeadExpo.IDExpo2TypeExpo( aExpo( ii ) ), aExpo( ii ) );

          if ( not bRet ) then
            Schema_RA.GPC_RA.RespSetErrorText( 'В ордера е налична забранена експозиция', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
            exit;
          end if;
        end loop;
      end if;

      if ( bRet ) then
        begin
          execute immediate
            'SELECT d.DOC_NUM, d.CH_STAMP ' || 'FROM Schema_DocSys.DOC_REGISTER_A d, Schema_DocSys.R101000 c ' || 'WHERE c.DOC_NUM = d.DOC_NUM and c.DOC_ID = d.FIELD_NUM and c.F10100001 = :1'
            into RecExpoMove.DOC_NUM, RecExpoMove.CH_STAMP
            using RecExpoMove.ID_MOVE;
        exception
          when no_data_found then
            bRet  := false;
            Schema_RA.GPC_RA.RespSetErrorText( 'Документът все още не е обработен от сървера', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
        end;
      end if;

      if ( bRet ) then
        begin
          select *
            into RecMoveText
            from EXPO_MOVE_TEXT
           where ID_MOVE = RecExpoMove.ID_MOVE and
                 rownum < 2;
        exception
          when no_data_found then
            null;
        end;

        begin
          select *
            into recExpoOrderConf
            from EXPO_ORDER_CONF_REG
           where ID_MOVE = RecExpoMove.ID_MOVE;
        exception
          when no_data_found then
            null;
        end;

        --следното е направено за да не гърми при дълги текстове; подава се отделно в масив 8
        RecMoveText.ORD_TEXT  := substr( RecMoveText.ORD_TEXT, 1, 3900 );
        --DocType    := Schema_DocSys.DocSys.DocumentType( RecExpoMove.DOC_NUM );
        DocType               := 101000;
        Schema_DocSys.DocSys.GetDocument( DocType, RecExpoMove.DOC_NUM, RecExpoMove.CH_STAMP, oDoc );
        bFirstRow             := true;
        sSuffix               := null;
        bRet                  := Schema_GPSys.GPC_Parser.WriteString( null, sSuffix ) and
                                 Schema_GPSys.GPC_Parser.WriteDate( RecMoveText.FOLDER_DATE, sSuffix ) and
                                 Schema_GPSys.GPC_Parser.WriteInteger( RecMoveText.FOLDER_NMBR, sSuffix ) and
                                 Schema_GPSys.GPC_Parser.WriteInteger( case
                                                                         when nvl( recExpoOrderConf.STATUS, '~' ) = Cmd_Expo_Add2.sMO_Confirm_Status then recExpoOrderConf.CH_OPER
                                                                         else null
                                                                       end,
                                                                       sSuffix
                                                                      ) and
                                 Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, DocType, 1, bFirstRow, false, null, sSuffix );

        if ( bRet ) then
          sOrdText  := Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '1.03' );
          Schema_DocSys.DocSys.GetList( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, 'ORD_DEALS' ), oDealList );
          nIDCust   := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '1.07' );

          for ii in 1 .. oDealList.count loop
            Schema_DocSys.DocSys.GetDocument( oDealList( ii ).DocType, oDealList( ii ).LDocNo, oDealList( ii ).LChStamp, oDeal );
            Schema_DocSys.DocSys.GetList( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDeal, cCmdName, 'OPERS' ), oOperList );
            nDealNum             := 0;

            for jj in 1 .. oOperList.count loop
              Schema_DocSys.DocSys.GetDocument( oOperList( jj ).DocType, oOperList( jj ).LDocNo, oOperList( jj ).LChStamp, oOper );
              nRowNum  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oOper, cCmdName, '2.10' );

              if ( nRowNum is not null ) then
                aSchRows( nRowNum )     := oOper;
                aSchDocType( nRowNum )  := oOperList( jj ).DocType;
                aSchRefer( nRowNum )    := Schema_GPSys.OraGPSys.GetFromCmdString( oDeal, cCmdName, 'REFER' );

                if ( nDealNum = 0 ) then
                  select nvl( min( DEAL_NUM ), 0 )
                    into nDealNum
                    from EXPO_MOVES
                   where ID_MOVE = RecExpoMove.ID_MOVE and
                         ORDROWNUM = nRowNum;
                end if;
              end if;
            end loop;

            rExpoMove.Expo_dt    := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDeal, cCmdName, 'EXPO_DT' );
            rExpoMove.Amount_dt  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDeal, cCmdName, 'AMOUNT_DT' );
            rExpoMove.Amount_kt  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDeal, cCmdName, 'AMOUNT_KT' );
            rExpoMove.Expo_kt    := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDeal, cCmdName, 'EXPO_KT' );
            rExpoMove.Val_dt     := Schema_GPSys.HeadExpo.IDExpo2CodVal( rExpoMove.Expo_dt );
            rExpoMove.Val_kt     := Schema_GPSys.HeadExpo.IDExpo2CodVal( rExpoMove.Expo_kt );
            --
            nDealType            := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDeal, cCmdName, 'DEAL_TYPE' );

            if ( nDealNum = 1 or
                ( sOper is null and
                 nDealType = Sch_CloseExpo ) ) then
              bDTCash  := Schema_GPSys.HeadExpo.IsItCashExpo( rExpoMove.Expo_dt );
              bKTCash  := Schema_GPSys.HeadExpo.IsItCashExpo( rExpoMove.Expo_kt );

              if ( bDTCash or
                  bKTCash ) then
                if ( bDTCash and
                    not bKTCash ) then
                  sOper  := Schema_GPSys.MLng.Str2( 'Вноска', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                elsif ( not bDTCash and
                       bKTCash ) then
                  sOper  := Schema_GPSys.MLng.Str2( 'Теглене', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                elsif ( bDTCash and
                       bKTCash ) then
                  sOper  := Schema_GPSys.MLng.Str2( 'Покупко-продажба на валута', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
                else
                  sOper  := null;
                end if;

                if ( bDTCash ) then
                  sCashName  := Cash.IDExpo2CashName( rExpoMove.Expo_dt );
                elsif ( bKTCash ) then
                  sCashName  := Cash.IDExpo2CashName( rExpoMove.Expo_kt );
                end if;
              end if;
            end if;

            sData                := null;
            nIDMainExpo          := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDeal, cCmdName, 'MAIN_EXPO' );
            nMainExpoCust        := Schema_GPSys.HeadExpo.IDExpo2IDCust( nIDMainExpo );
            nIDExpoKT            := Schema_GPSys.HeadExpo.IDExpo2IDCust( rExpoMove.Expo_kt );
            nIDExpoDT            := Schema_GPSys.HeadExpo.IDExpo2IDCust( rExpoMove.Expo_dt );

            if ( nDealType = Sch_Change or
                nMainExpoCust > 0 ) then
              Schema_GPSys.GPC_Parser.RespAddTable( 5 );
              sDummy            := null;
              sRefer            := Schema_GPSys.OraGPSys.GetFromCmdString( oDeal, cCmdName, 'REFERENCIA' );
              dValiorDt         := Schema_GPSys.OraGPSys.GetFromCmdDate( oDeal, cCmdName, 'VALIOR_DT' );
              rExpoMove.Valior  := Schema_GPSys.OraGPSys.GetFromCmdDate( oDeal, cCmdName, 'VALIOR_KT' );
              bRet              := Schema_GPSys.GPC_Parser.WriteString( rExpoMove.Val_dt, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteInteger( rExpoMove.Expo_dt, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteNumber( rExpoMove.Amount_dt, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteString( rExpoMove.Val_kt, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteInteger( rExpoMove.Expo_kt, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteNumber( rExpoMove.Amount_kt, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteInteger( nIDMainExpo, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteInteger( nDealType, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteString( sRefer, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteDate( dValiorDt, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteDate( rExpoMove.Valior, sDummy ) and
                                   Schema_GPSys.GPC_Parser.WriteString( case
                                                                          when nIDExpoKT > 0 and
                                                                               nIDExpoDT > 0 then
                                                                            'T'
                                                                          else
                                                                            'F'
                                                                        end,
                                                                        sDummy
                                                                       );

              if ( bRet ) then
                Schema_GPSys.GPC_Parser.RespAddRow( sDummy );
              end if;

              if ( nMainExpoCust > 0 and
                  not Schema_GPSys.OraGPSys.SearchNumberInArray( aAvisoExpos, nIDMainExpo ) ) then
                Schema_GPSys.GPC_Parser.RespAddTable( 11 );
                sDummy    := null;
                bRet      := Schema_GPSys.GPC_Parser.WriteInteger( nIDMainExpo, sDummy ) and
                             Schema_GPSys.GPC_Parser.WriteInteger( nMainExpoCust, sDummy ); --id_cust

                if ( bRet ) then
                  Schema_GPSys.GPC_Parser.RespAddRow( sDummy );
                end if;

                Schema_GPSys.OraGPSys.Add2UniqArr( aAvisoExpos, nIDMainExpo );
                Schema_GPSys.OraGPSys.Add2UniqArr( aAvisoCusts, nMainExpoCust );
              end if;

              if ( nvl( nIDCust, 0 ) > 0 and
                  nIDCust = nIDExpoKT and
                  not Schema_GPSys.OraGPSys.SearchNumberInArray( aAvisoExpos, rExpoMove.Expo_kt ) ) then
                Schema_GPSys.GPC_Parser.RespAddTable( 11 );
                sDummy    := null;
                bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rExpoMove.Expo_kt, sDummy ) and
                             Schema_GPSys.GPC_Parser.WriteInteger( nIDExpoKT, sDummy ); --id_cust

                if ( bRet ) then
                  Schema_GPSys.GPC_Parser.RespAddRow( sDummy );
                end if;

                Schema_GPSys.OraGPSys.Add2UniqArr( aAvisoExpos, rExpoMove.Expo_kt );
                Schema_GPSys.OraGPSys.Add2UniqArr( aAvisoCusts, nIDExpoKT );
              end if;

              if ( nvl( nIDCust, 0 ) > 0 and
                  nIDCust = nIDExpoDT and
                  not Schema_GPSys.OraGPSys.SearchNumberInArray( aAvisoExpos, rExpoMove.Expo_Dt ) ) then
                Schema_GPSys.GPC_Parser.RespAddTable( 11 );
                sDummy    := null;
                bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rExpoMove.Expo_Dt, sDummy ) and
                             Schema_GPSys.GPC_Parser.WriteInteger( nIDExpoDT, sDummy ); --id_cust

                if ( bRet ) then
                  Schema_GPSys.GPC_Parser.RespAddRow( sDummy );
                end if;

                Schema_GPSys.OraGPSys.Add2UniqArr( aAvisoExpos, rExpoMove.Expo_Dt );
                Schema_GPSys.OraGPSys.Add2UniqArr( aAvisoCusts, nIDExpoDT );
              end if;
            end if;

            if ( rExpoMove.Val_dt != rExpoMove.Val_kt and
                nvl( rExpoMove.Amount_dt, 0 ) != 0 and
                nvl( rExpoMove.Amount_kt, 0 ) != 0 ) then
              begin
                select nvl( RATE_AGREED, 0 )
                  into nRate
                  from EXPO_DEAL_RATE
                 where ID_MOVE = RecExpoMove.ID_MOVE and
                       DEAL_NUM = nDealNum;
              exception
                when others then
                  nRate  := 0;
              end;

              $if Schema_GPSys.OraSys.VerBankTokuda or
                  Schema_GPSys.OraSys.VerBankDBank $then
              if ( nRate = 0 ) then
                nRate  := rExpoMove.Amount_Kt / rExpoMove.Amount_Dt;
              end if;

              bRet      := Schema_GPSys.GPC_Parser.WriteString( rExpoMove.Val_Kt, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rExpoMove.Val_Dt, sData ) and
                           Schema_GPSys.GPC_Parser.WriteAmount( nRate, sData );

              $else
                if ( nRate = 0 ) then
                  nRate  := rExpoMove.Amount_dt / rExpoMove.Amount_kt;
                else
                  nRate  := 1 / nRate;
                end if;

                bRet      := Schema_GPSys.GPC_Parser.WriteString( rExpoMove.Val_dt, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rExpoMove.Val_kt, sData ) and
                             Schema_GPSys.GPC_Parser.WriteAmount( nRate, sData );
              $end
              if ( bRet ) then
                aResp( aResp.count + 1 )  := sData;
              end if;
            end if;

            exit when not bRet;
          end loop;

          if ( bRet ) then
            bFirstRow  := true;
            kk         := aSchRows.first;

            while ( kk is not null and
                   bRet ) loop
              sData    := null;
              sSuffix  := null;

              if ( ( not bExclZBal ) or
                  Schema_GPSys.OraGPSys.GetFromCmdNumber( aSchRows( kk ), cCmdName, '2.01' ) not in (Sch_Preocenka, Sch_ZBalPpv) ) then
                bRet      := LoadExpoData( Schema_GPSys.OraGPSys.GetFromCmdNumber( aSchRows( kk ), cCmdName, '2.02' ), sData, sIBAN_DT, not Schema_GPSys.OraSys.VerTFS ) and
                             LoadExpoData( Schema_GPSys.OraGPSys.GetFromCmdNumber( aSchRows( kk ), cCmdName, '2.05' ), sData, sIBAN_KT, not Schema_GPSys.OraSys.VerTFS ) and
                             Schema_GPSys.GPC_Parser.WriteString( aSchRefer( kk ), sData ) and
                             LoadBDGData( RecExpoMove.ID_MOVE, kk, sData ) and
                             LoadAddData( RecExpoMove.ID_MOVE, kk, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sIBAN_DT, sSuffix ) and
                             Schema_GPSys.GPC_Parser.WriteString( sIBAN_KT, sSuffix ) and
                             Schema_GPSys.OraGPSys.PutRespFromCmdParam( aSchRows( kk ), cCmdName, aSchDocType( kk ), 2, bFirstRow, false, sData, sSuffix );
              end if;

              kk       := aSchRows.next( kk );
            end loop;
          end if;
        end if;

        if ( bRet ) then
          if ( nvl( nIDCust, 0 ) != 0 ) then
            rCustData         := null;
            rCustData.IDCust  := nIDCust;

            if ( Schema_Cust.GPC_Customs.GetCustData( rCustData ) ) then
              Schema_GPSys.GPC_Parser.RespAddTable( 3 );
              sData     := null;
              bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rCustData.IDCust, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.CLITYPE, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.FTYPE, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.FIRSTNAME, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.SecndName, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.LASTNAME, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( nvl( rCustData.EGN, rCustData.ENCH ), sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.BULSTAT, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.SECTORNA, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.OTRASLOVA, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.DANNUMBER, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.LICHNAKARTA, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.COUNTRY, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.POSTBOX, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.TELEFON, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.LATINNAME, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.LATINADDR, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.ADDRESS, sData );
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            end if;
          end if;

          if ( aAvisoCusts.count > 0 ) then
            Schema_GPSys.GPC_Parser.RespAddTable( 12 );

            for ii in aAvisoCusts.first .. aAvisoCusts.last loop
              rCustData         := null;
              rCustData.IDCust  := aAvisoCusts( ii );

              if ( Schema_Cust.GPC_Customs.GetCustData( rCustData ) ) then
                sData     := null;
                bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rCustData.IDCust, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.CLITYPE, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.FTYPE, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.FIRSTNAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.SecndName, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.LASTNAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( nvl( rCustData.EGN, rCustData.ENCH ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.BULSTAT, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.SECTORNA, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.OTRASLOVA, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.DANNUMBER, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.LICHNAKARTA, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.COUNTRY, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.POSTBOX, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.TELEFON, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.LATINNAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.LATINADDR, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustData.ADDRESS, sData );
                Schema_GPSys.GPC_Parser.RespAddRow( sData );
              end if;
            end loop;
          end if;

          if ( aResp.count > 0 ) then
            Schema_GPSys.GPC_Parser.RespAddTable( 4 );

            for ii in aResp.first .. aResp.last loop
              Schema_GPSys.GPC_Parser.RespAddRow( aResp( ii ) );
            end loop;
          end if;

          Schema_GPSys.GPC_Parser.RespAddTable( 6 );
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteString( sOper, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( sCashName, sData );

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddTable( 7 );

            for rec in ( select *
                           from CASH_ORDERS
                          where ID_MOVE = RecExpoMove.ID_MOVE ) loop
              if ( nvl( rec.ID_CUST, 0 ) != 0 ) then
                bRet  := Schema_Cust.GPC_Customs.GetCustDataCashOrders( rec.ID_CUST, true, sEGN, sCustName, sPCardNo, sPCardIzdadenaOt, dPCardDate, sAddress );
              end if;

              sData  := null;

              if ( bRet ) then
                bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rec.IDORDER, sData ) and
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CUST, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rec.IN_OUT, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and
                             Schema_GPSys.GPC_Parser.WriteNumber( rec.AMOUNT, sData ) and
                             Schema_GPSys.GPC_Parser.WriteDate( rec.SCH_DATE, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetINI_DDS_Bank( RecExpoMove.UNIQCODE ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetINI_DDS_IdentNo( RecExpoMove.UNIQCODE ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sCustName, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sEGN, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sPCardNo, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sPCardIzdadenaOt, sData ) and
                             Schema_GPSys.GPC_Parser.WriteDate( dPCardDate, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sAddress, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sOrdText, sData ) and
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.ORDERNO, sData );
              end if;

              if ( bRet ) then
                Schema_GPSys.GPC_Parser.RespAddRow( sData );
              end if;

              exit when not bRet;
            end loop;
          end if;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddArray( 8 );
            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteString( RecMoveText.ORD_TEXT, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( RecMoveText.PREFERRATE, sData ) and
                         true;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            end if;
          end if;

          bRet      := bRet and
                       Cmd_Expo_Add2.WriteTaxesByIDMove( RecExpoMove.ID_MOVE );
        end if;
      end if;
    end if;

    return bRet;
  end CmdLoadMemoOrder;

  --------------------------------------------------------------------------------
  function CmdExpoAvansOlih( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues   Schema_GPSys.GPC_Parser.taParamStrings;
    RecDepoExpo  DEPOSIT_EXPO%rowtype;
    cDummy       varchar2( 16 );
    nIDExpo      integer;
    nIDMove      integer;
    bDummy       boolean;
    bRet         boolean;
  begin
    Schema_DocSys.DocSys_SaveInIQ.UseQueueWork; -- don't delete !!! It's for Union version thich is old!
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDExpo );

    begin
      select *
        into RecDepoExpo
        from DEPOSIT_EXPO
       where ID_EXPO = nIDExpo and
             STATUS = 'T';

      bRet  := Schema_GPSys.OraGPSys.OracleBoolean( RecDepoExpo.AVANS_LIH );
    exception
      when no_data_found then
        bRet  := false;
    end;

    if ( bRet ) then
      bRet  := CalcLih.DoAvansOlih( RecDepoExpo, true, nIDMove );

      if ( bRet ) then
        commit;

        if ( nIDMove > 0 ) then
          Schema_GPSys.GPC_Parser.RespAddArray( 1 );
          cDummy  := null;
          bDummy  := Schema_GPSys.GPC_Parser.WriteInteger( nIDMove, cDummy );
          Schema_GPSys.GPC_Parser.RespAddRow( cDummy );
        end if;
      else
        rollback;
      end if;
    else
      Schema_RA.GPC_RA.RespSetErrorText( 'Не се допуска авансово начисляване на лихви', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
    end if;

    return bRet;
  end CmdExpoAvansOlih;

  --------------------------------------------------------------------------------
  function CmdExpoCalcLihvi( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues    Schema_GPSys.GPC_Parser.taParamStrings;
    bRet          boolean;
    bHight        boolean;
    bPlanLih      boolean;
    bRealLih      boolean;
    nIDExpo       integer;
    dToDate       date;
    nLihva        number;
    MemoHeadData  Schema_GPSys.tMemoOrder;
    aLihvi        CALCLIH.tblLihviLihvi;
    sData         varchar2( 4000 );
  begin
    Schema_DocSys.DocSys_SaveInIQ.UseQueueWork;
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDExpo ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 2 ), dToDate ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 3 ), bHight ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 4 ), bPlanLih ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 5 ), bRealLih );

    if ( bRet ) then
      if ( bPlanLih ) then
        savepoint CmdExpoCalcLihvi_1;
        bRet  := CALCLIH.ExpoPlanLihvi( nIDExpo, dToDate, true );

        if ( bRet ) then
          commit;
        else
          rollback to CmdExpoCalcLihvi_1;
        end if;
      elsif ( bRealLih ) then
        savepoint CmdExpoCalcLihvi_2;
        bRet  := CALCLIH.ExpoOlih( nIDExpo, dToDate, null, false, true, MemoHeadData, null, true, false, true, false, true );

        if ( bRet ) then
          commit;
        else
          rollback to CmdExpoCalcLihvi_2;
        end if;
      else
        bRet  := CALCLIH.CalcExpoLihvi( nIDExpo, dToDate, bHight, true, aLihvi, nLihva, false, null, null, false, Schema_RA.GPC_SERVICES.bRunningAll /*samo za testovi celi*/
                                                                                                                                                     );

        if ( bRet ) then
          if ( aLihvi.count > 0 ) then
            Schema_GPSys.GPC_Parser.RespAddArray( 1 );

            for ii in reverse aLihvi.first .. aLihvi.last loop
              sData     := null;
              bRet      := Schema_GPSys.GPC_Parser.WriteDate( aLihvi( ii ).BegDate, sData ) and
                           Schema_GPSys.GPC_Parser.WriteDate( aLihvi( ii ).EndDate, sData ) and
                           Schema_GPSys.GPC_Parser.WriteAmount( aLihvi( ii ).Saldo, sData ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( aLihvi( ii ).nDays, sData ) and
                           Schema_GPSys.GPC_Parser.WriteAmount( aLihvi( ii ).LihProc, sData ) and
                           Schema_GPSys.GPC_Parser.WriteAmount( aLihvi( ii ).Lihva, sData ) and
                           Schema_GPSys.GPC_Parser.WriteString( aLihvi( ii ).Kapit, sData );

              if ( bRet ) then
                Schema_GPSys.GPC_Parser.RespAddRow( sData );
              else
                exit;
              end if;
            end loop;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddArray( 3 );

              for rExpoData in ( select trim( trim( b.FIRSTNAME ) || ' ' || trim( b.MIDLENAME ) || ' ' || trim( b.LASTNAME ) ) as CUST_NAME,
                                        a.SCHACCOUNT,
                                        a.EXPO_NAME,
                                        a.IBAN
                                   from Schema_Cust.CUSTOMS b,
                                        Schema_GPSys.EXPOSITION a
                                  where a.ID_EXPO = nIDExpo and
                                        a.ID_CUST = b.id(+) ) loop
                sData     := null;
                bRet      := Schema_GPSys.GPC_Parser.WriteString( rExpoData.CUST_NAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rExpoData.SCHACCOUNT, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rExpoData.EXPO_NAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rExpoData.IBAN, sData );

                if ( bRet ) then
                  Schema_GPSys.GPC_Parser.RespAddRow( sData );
                else
                  exit;
                end if;
              end loop;
            end if;
          end if;
        end if;
      end if;
    end if;

    return bRet;
  end CmdExpoCalcLihvi;

  --------------------------------------------------------------------------------
  function CmdOlihviavane( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    aTypeExpo   Schema_GPSys.OraGPSys.aNumbers;
    aPodelenie  Schema_GPSys.OraGPSys.aNumbers;
    aCodVal     Schema_GPSys.OraGPSys.aStrings;
    dDate       date;
    bRet        boolean := false;
    bPXMaster   boolean := false;
    nRowNum     integer;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count > 0 ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        if ( aParamEntities3D( ii ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 1 ), dDate );
        elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) ) then
            bRet  := false;

            if ( aRowValues.count > 0 ) then
              for jj in aRowValues.first .. aRowValues.last loop
                bRet  := Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( jj ), aTypeExpo( aTypeExpo.count + 1 ) );
                exit when not bRet;
              end loop;
            end if;
          end if;
        elsif ( aParamEntities3D( ii ).nRowType = 3 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
              aRowValues.count > 0 ) then
            for jj in aRowValues.first .. aRowValues.last loop
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( jj ), aCodVal( aCodVal.count + 1 ) );
              exit when not bRet;
            end loop;
          end if;
        elsif ( aParamEntities3D( ii ).nRowType = 4 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
              aRowValues.count > 0 ) then
            for jj in aRowValues.first .. aRowValues.last loop
              bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( jj ), aPodelenie( aPodelenie.count + 1 ) );
              exit when not bRet;
            end loop;
          end if;
        elsif ( Schema_RA.GPC_PX.IsPXParam( aParamEntities3D( ii ).nRowType ) ) then
          bRet  := true;
        end if;

        exit when not bRet;
      end loop;
    end if;

    if ( bRet and
        aPodelenie.count > 0 and
        aTypeExpo.count > 0 and
        Schema_RA.GPC_PX.IsPXCommand( aParamEntities3D ) ) then
      if ( Schema_RA.GPC_PX.IsPxMaster ) then
        bPXMaster  := true;

        for jj in aPodelenie.first .. aPodelenie.last loop
          Schema_RA.GPC_PX.aPXIntegers( Schema_RA.GPC_PX.aPXIntegers.count + 1 )  := aPodelenie( jj );
        end loop;

        bRet       := Schema_RA.GPC_PX.RunMasterProcess( aParamEntities3D, Schema_RA.GPC_PX.defPXSplitMode_List );
      else
        aPodelenie.delete;

        for jj in Schema_RA.GPC_PX.aPXIntegers.first .. Schema_RA.GPC_PX.aPXIntegers.last loop
          aPodelenie( aPodelenie.count + 1 )  := Schema_RA.GPC_PX.aPXIntegers( jj );
        end loop;
      end if;
    end if;

    if ( bRet and
        not bPXMaster and
        aPodelenie.count > 0 and
        aTypeExpo.count > 0 ) then
      for kk in aPodelenie.first .. aPodelenie.last loop
        nRowNum  := Schema_RA.GPC_RA.GetNumber( 'MainBatchLog' );
        commit;
        Schema_RA.GPC_RA.LogMainBatchPrc( nRowNum, 'CmdOlihviavane', aPodelenie( kk ), false, dDate );

        for ii in aTypeExpo.first .. aTypeExpo.last loop
          if ( aCodVal.count > 0 ) then
            for jj in aCodVal.first .. aCodVal.last loop
              bRet  := CALCLIH.Olihviavane( aPodelenie( kk ), aTypeExpo( ii ), aCodVal( jj ), dDate );
              exit when not bRet;
            end loop;
          else
            bRet  := CALCLIH.Olihviavane( aPodelenie( kk ), aTypeExpo( ii ), null, dDate );
          end if;

          exit when not bRet;
        end loop;

        Schema_RA.GPC_RA.LogMainBatchPrc( nRowNum, 'CmdOlihviavane', aPodelenie( kk ), bRet, dDate );
        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdOlihviavane;

  --------------------------------------------------------------------------------
  function CmdChangeLihProc( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues      Schema_GPSys.GPC_Parser.taParamStrings;
    rExpoOpenData   Schema_GPSys.Cmd_HeadExpo.recExpoOpenData;
    tIntList        Schema_GPSys.tblExpoIntRate;
    tIntListNew     Schema_GPSys.tblExpoIntRate;
    aCustTypes      Schema_GPSys.OraGPSys.aStrings;
    RecCurrIntRate  CURRENT_INT_RATE%rowtype;
    RecDepIntRate   DEPOSIT_INT_RATE%rowtype;
    sCodVal         varchar2( 3 );
    bRet            boolean := false;
    bStop           boolean;
    nUniqCode       integer;
    nTypeExpo       integer;
    nCurrent        integer := 0;
    nAge            integer := -1;
    nAgeFr          integer := -1;
    nAgeTo          integer := -1;
    nPrefer         number;
    nPreferLow      number;
    nAmountCorr     number;
    nMinBaseProc    number;
    nCoeff          number;
    dDateFr         date;
    dDateTo         date;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    tIntList  := Schema_GPSys.tblExpoIntRate( );

    if ( aParamEntities3D.count > 0 ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        if ( aParamEntities3D( ii ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUniqCode ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nTypeExpo ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowVAlues( 3 ), sCodVal ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 4 ), dDateFr ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 5 ), dDateTo ) and
                       ( ( not aRowValues.exists( 7 ) ) or
                        ( Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 6 ), nAgeFr ) and
                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 7 ), nAgeTo ) ) );
        elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
              aRowValues.count > 0 ) then
            bRet                            := Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 1 ), RecCurrIntRate.FROM_DATE ) and
                                               Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 2 ), RecCurrIntRate.AMN_TO ) and
                                               Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), RecCurrIntRate.REL_PRC ) and
                                               Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), RecCurrIntRate.BASE_PRC ) and
                                               Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 5 ), RecCurrIntRate.PERCENT ) and
                                               ( ( not aRowValues.exists( 8 ) ) or
                                                ( Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), RecCurrIntRate.REL_PRC_LOW ) and
                                                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 7 ), RecCurrIntRate.BASE_PRC_LOW ) and
                                                 Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 8 ), RecCurrIntRate.PERCENT_LOW ) ) );
            tIntList.extend;
            tIntList( tIntList.count )      := Schema_GPSys.TExpoIntRate( null,
                                                                          RecCurrIntRate.FROM_DATE,
                                                                          RecCurrIntRate.AMN_TO,
                                                                          RecCurrIntRate.PERCENT,
                                                                          null,
                                                                          null,
                                                                          RecCurrIntRate.PERCENT_LOW,
                                                                          null,
                                                                          null,
                                                                          null,
                                                                          RecCurrIntRate.REL_PRC,
                                                                          RecCurrIntRate.BASE_PRC,
                                                                          RecCurrIntRate.REL_PRC_LOW,
                                                                          RecCurrIntRate.BASE_PRC_LOW,
                                                                          null
                                                                         );
          end if;
        elsif ( aParamEntities3D( ii ).nRowType = 3 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
              aRowValues.count > 0 ) then
            bRet                            := Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 1 ), RecDepIntRate.FROM_DATE ) and
                                               Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 2 ), RecDepIntRate.AMN_TO ) and
                                               Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), RecDepIntRate.REL_PRC ) and
                                               Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), RecDepIntRate.BASE_PRC ) and
                                               Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 5 ), RecDepIntRate.PERCENT ) and
                                               Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), RecDepIntRate.REL_PRC_LOW ) and
                                               Schema_GPSys.GPC_Parser.ReadString( aRowValues( 7 ), RecDepIntRate.BASE_PRC_LOW ) and
                                               Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 8 ), RecDepIntRate.PERCENT_LOW );
            tIntList.extend;
            tIntList( tIntList.count )      := Schema_GPSys.TExpoIntRate( null,
                                                                          RecDepIntRate.FROM_DATE,
                                                                          RecDepIntRate.AMN_TO,
                                                                          RecDepIntRate.PERCENT,
                                                                          null,
                                                                          null,
                                                                          RecDepIntRate.PERCENT_LOW,
                                                                          null,
                                                                          null,
                                                                          null,
                                                                          RecDepIntRate.REL_PRC,
                                                                          RecDepIntRate.BASE_PRC,
                                                                          RecDepIntRate.REL_PRC_LOW,
                                                                          RecDepIntRate.BASE_PRC_LOW,
                                                                          null
                                                                         );
          end if;
        elsif ( aParamEntities3D( ii ).nRowType = 4 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
              aRowValues.count > 0 ) then
            bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), aCustTypes( aCustTypes.count + 1 ) );
          end if;
        end if;

        exit when not bRet;
      end loop;
    end if;

    if ( bRet ) then
      bRet      := not ( OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositProgresia, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositInvest1, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositInvest1A, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositInvest2, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositDinamika, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.Deposit6x6, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHameleon, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHamelTriple, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositUBiznes, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositUAvans, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositUAvans2, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositChildSave, nTypeExpo ) or
                        OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositRenta, nTypeExpo ) );

      if ( not bRet ) then
        Schema_RA.GPC_RA.RespSetErrorText( 'Лихвените проценти за този тип не подлежат на смяна', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
      end if;
    end if;

    if ( bRet ) then
      for rCurrExpo in (  select a.ID_EXPO,
                                 a.ID_CUST,
                                 a.TYPE_EXPO,
                                 a.OPEN_DATE,
                                 a.LIHDATE,
                                 nvl( a.PREFER_MODE, 0 ) as PREFERMODE,
                                 b.TECHNOLOGY,
                                 c.FTYPE
                            from CURRENT_EXPO a,
                                 Schema_GPSys.EXPOSITION b,
                                 Schema_Cust.CUSTOMS c
                           where ( ( nUniqCode = -1 or
                                    a.UNIQCODE = nUniqCode ) and
                                  a.TYPE_EXPO = nTypeExpo and
                                  a.STATUS = 'T' and
                                  a.CODVAL = sCodVal and
                                  nvl( a.PREFER_MODE, 0 ) not in (Schema_GPSys.HeadExpo.ExpoPreferMode4) and
                                  ( dDateTo is null or
                                   a.OPEN_DATE < dDateTo ) and
                                  ( dDateFr is null or
                                   a.OPEN_DATE > dDateFr ) and
                                  a.ID_EXPO = b.ID_EXPO and
                                  b.ID_CUST = c.id )
                        order by a.ID_EXPO ) loop
        if ( aCustTypes.count = 0 or
            Schema_GPSys.OraGPSys.SearchStringInArray( aCustTypes, rCurrExpo.FType ) ) then
          if ( Schema_GPSys.HeadExpo.IsItCurrentChildSave( 0, rCurrExpo.TYPE_EXPO ) ) then
            nAge  := Schema_GPSys.OraGPSys.CalcAge( nvl( Schema_Cust.GPC_Customs.Egn2BirthDate( null, rCurrExpo.ID_CUST ), rCurrExpo.OPEN_DATE ), rCurrExpo.OPEN_DATE );
          else
            nAge  := -1;
          end if;

          if ( nAge = -1 or
              ( nAge between nAgeFr and nAgeTo ) ) then
            rExpoOpenData.Technology  := rCurrExpo.TECHNOLOGY;
            rExpoOpenData.IDExpo      := rCurrExpo.ID_EXPO;

            if ( Schema_GPSys.OraSys.VerBankUnion or
                Schema_GPSys.OraSys.VerBankDBank ) then
              rExpoOpenData.ExpoMode  := Schema_GPSys.HeadExpo.ExpoModeStandard;
            end if;

            tIntListNew               := tIntList;

            for rCurrIntRate in (  select *
                                     from CURRENT_INT_RATE
                                    where ID_EXPO = rCurrExpo.ID_EXPO and
                                          FROM_DATE < tIntList( 1 ).FROMDATE
                                 order by FROM_DATE desc ) loop
              if ( tIntList.count = tIntListNew.count ) then
                nPrefer       := rCurrIntRate.PREFER;
                nAmountCorr   := rCurrIntRate.AMN_CORR;
                nPreferLow    := rCurrIntRate.PREFER_LOW;
                nMinBaseProc  := rCurrIntRate.MIN_BASE_PROC;
                nCoeff        := rCurrIntRate.COEFF;
              end if;

              tIntListNew.extend;
              tIntListNew( tIntListNew.count )      := Schema_GPSys.TExpoIntRate( null,
                                                                                  rCurrIntRate.FROM_DATE,
                                                                                  rCurrIntRate.AMN_TO,
                                                                                  rCurrIntRate.PERCENT,
                                                                                  rCurrIntRate.PREFER,
                                                                                  rCurrIntRate.AMN_CORR,
                                                                                  rCurrIntRate.PERCENT_LOW,
                                                                                  rCurrIntRate.PREFER_LOW,
                                                                                  rCurrIntRate.MIN_BASE_PROC,
                                                                                  rCurrIntRate.COEFF,
                                                                                  rCurrIntRate.REL_PRC,
                                                                                  rCurrIntRate.BASE_PRC,
                                                                                  rCurrIntRate.REL_PRC_LOW,
                                                                                  rCurrIntRate.BASE_PRC_LOW,
                                                                                  null
                                                                                 );
            end loop;

            for ii in tIntList.first .. tIntList.last loop
              if ( rCurrExpo.PREFERMODE in (0, Schema_GPSys.HeadExpo.ExpoPreferMode3) ) then
                tIntListNew( ii ).PREFER     := 0;
                tIntListNew( ii ).PREFERLOW  := 0;
              end if;

              tIntListNew( ii ).AMOUNTCORR   := nAmountCorr;
              tIntListNew( ii ).MINBASEPROC  := nMinBaseProc;
              tIntListNew( ii ).COEFF        := nCoeff;
            end loop;

            bRet                      := Schema_GPSys.Cmd_HeadExpo.ChangeExpo( rExpoOpenData, tIntListNew, 0, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_System );
          end if;
        end if;

        nCurrent  := nCurrent + 1;
        bRet      := bRet and
                     Schema_RA.GPC_RA.ChkStopField( nCurrent, nCurrent );
        exit when not bRet;
      end loop;
    end if;

    if ( bRet ) then
      for rDepExpo in (  select a.ID_EXPO,
                                a.LIHDATE,
                                b.TECHNOLOGY,
                                nvl( a.PREFER_MODE, 0 ) as PREFERMODE,
                                c.FTYPE
                           from DEPOSIT_EXPO a,
                                Schema_GPSys.EXPOSITION b,
                                Schema_Cust.CUSTOMS c
                          where ( ( nUniqCode = -1 or
                                   a.UNIQCODE = nUniqCode ) and
                                 a.TYPE_EXPO = nTypeExpo and
                                 a.STATUS = 'T' and
                                 a.CODVAL = sCodVal and
                                 nvl( a.PREFER_MODE, 0 ) not in (Schema_GPSys.HeadExpo.ExpoPreferMode4) and
                                 ( dDateTo is null or
                                  a.OPEN_DATE < dDateTo ) and
                                 ( dDateFr is null or
                                  a.OPEN_DATE > dDateFr ) and
                                 a.ID_EXPO = b.ID_EXPO and
                                 b.ID_CUST = c.id )
                       order by a.ID_EXPO ) loop
        if ( aCustTypes.count = 0 or
            Schema_GPSys.OraGPSys.SearchStringInArray( aCustTypes, rDepExpo.FType ) ) then
          rExpoOpenData.Technology  := rDepExpo.TECHNOLOGY;
          rExpoOpenData.IDExpo      := rDepExpo.ID_EXPO;

          if ( Schema_GPSys.OraSys.VerBankUnion or
              Schema_GPSys.OraSys.VerBankDBank ) then
            rExpoOpenData.ExpoMode  := Schema_GPSys.HeadExpo.ExpoModeStandard;
          end if;

          tIntListNew               := tIntList;

          for rDepIntRate in (  select *
                                  from DEPOSIT_INT_RATE
                                 where ID_EXPO = rDepExpo.ID_EXPO and
                                       FROM_DATE < tIntList( 1 ).FROMDATE
                              order by FROM_DATE desc ) loop
            if ( tIntList.count = tIntListNew.count ) then
              nPrefer      := rDepIntRate.PREFER;
              nAmountCorr  := rDepIntRate.AMN_CORR;
              nPreferLow   := rDepIntRate.PREFER_LOW;
            end if;

            tIntListNew.extend;
            tIntListNew( tIntListNew.count )      := Schema_GPSys.TExpoIntRate( null,
                                                                                rDepIntRate.FROM_DATE,
                                                                                rDepIntRate.AMN_TO,
                                                                                rDepIntRate.PERCENT,
                                                                                rDepIntRate.PREFER,
                                                                                rDepIntRate.AMN_CORR,
                                                                                rDepIntRate.PERCENT_LOW,
                                                                                rDepIntRate.PREFER_LOW,
                                                                                null,
                                                                                null,
                                                                                rDepIntRate.REL_PRC,
                                                                                rDepIntRate.BASE_PRC,
                                                                                rDepIntRate.REL_PRC_LOW,
                                                                                rDepIntRate.BASE_PRC_LOW,
                                                                                null
                                                                               );
          end loop;

          for ii in tIntList.first .. tIntList.last loop
            if ( rDepExpo.PREFERMODE in (0, Schema_GPSys.HeadExpo.ExpoPreferMode3) ) then
              tIntListNew( ii ).PREFER     := 0;
              tIntListNew( ii ).PREFERLOW  := 0;
            end if;

            tIntListNew( ii ).AMOUNTCORR  := nAmountCorr;
          end loop;

          bRet                      := Schema_GPSys.Cmd_HeadExpo.ChangeExpo( rExpoOpenData, tIntListNew, 0, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_System );
        end if;

        nCurrent  := nCurrent + 1;
        bRet      := bRet and
                     Schema_RA.GPC_RA.ChkStopField( nCurrent, nCurrent );
        exit when not bRet;
      end loop;
    end if;

    if ( bRet ) then
      commit;
    else
      rollback;
    end if;

    return bRet;
  end CmdChangeLihProc;

  --------------------------------------------------------------------------------
  function CmdRazchetirane( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    aPodelenie  Schema_GPSys.OraGPSys.aNumbers;
    bRet        boolean := false;
    bExpos      boolean;
    bMMarket    boolean;
    bPXMaster   boolean := false;
    dDate       date;
    cRet        varchar2( 1 );
    nRowNum     integer;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count > 0 ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        if ( aParamEntities3D( ii ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 1 ), dDate ) and
                       Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bExpos ) and
                       Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 3 ), bMMarket ) and
                       bExpos or
                       bMMarket;
        elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) ) then
            bRet  := true;

            if ( aRowValues.count > 0 ) then
              for jj in aRowValues.first .. aRowValues.last loop
                bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( jj ), aPodelenie( aPodelenie.count + 1 ) );
                exit when not bRet;
              end loop;
            end if;
          end if;
        elsif ( Schema_RA.GPC_PX.IsPXParam( aParamEntities3D( ii ).nRowType ) ) then
          bRet  := true;
        end if;
      end loop;
    end if;

    if ( bRet and
        aPodelenie.count > 0 and
        Schema_RA.GPC_PX.IsPXCommand( aParamEntities3D ) ) then
      if ( Schema_RA.GPC_PX.IsPxMaster ) then
        bPXMaster  := true;

        for jj in aPodelenie.first .. aPodelenie.last loop
          Schema_RA.GPC_PX.aPXIntegers( Schema_RA.GPC_PX.aPXIntegers.count + 1 )  := aPodelenie( jj );
        end loop;

        bRet       := Schema_RA.GPC_PX.RunMasterProcess( aParamEntities3D, Schema_RA.GPC_PX.defPXSplitMode_List );
      else
        aPodelenie.delete;

        for jj in Schema_RA.GPC_PX.aPXIntegers.first .. Schema_RA.GPC_PX.aPXIntegers.last loop
          aPodelenie( aPodelenie.count + 1 )  := Schema_RA.GPC_PX.aPXIntegers( jj );
        end loop;
      end if;
    end if;

    if ( bRet and
        not bPXMaster and
        aPodelenie.count > 0 ) then
      for ii in aPodelenie.first .. aPodelenie.last loop
        nRowNum  := Schema_RA.GPC_RA.GetNumber( 'MainBatchLog' );
        commit;
        Schema_RA.GPC_RA.LogMainBatchPrc( nRowNum, 'CmdRazchetirane', aPodelenie( ii ), false, dDate );

        if ( bExpos ) then
          bRet  := CALCLIH.Razchetirane( aPodelenie( ii ), dDate );
        end if;

        if ( bRet and
            bMMarket and
            Schema_GPSys.ORASYS.bModule_Deal ) then
          execute immediate ' begin  Schema_Deal.Deals.MMarketRazchetirane(:1, :2, :3 );  end;' using in aPodelenie( ii ), in dDate, out cRet;

          bRet  := nvl( cRet = 'T', false );
        end if;

        Schema_RA.GPC_RA.LogMainBatchPrc( nRowNum, 'CmdRazchetirane', aPodelenie( ii ), bRet, dDate );
        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdRazchetirane;

  --------------------------------------------------------------------------------
  function GetConf2ExpoPreoc(
    sCodVal      in     varchar2,
    sSYNT        in     varchar2,
    sIN_BALANCE  in     varchar2,
    nUniqCode    in     integer,
    bBlackOper   in     boolean,
    sEXPO_CODE   in     varchar2,
    sANFEAT      in     varchar2,
    nECRBuff        out integer,
    nECRBalP        out integer,
    nECRZadP        out integer,
    nECRBalR        out integer,
    nECRZadR        out integer,
    sVCRZadP        out varchar2,
    sVCRBalR        out varchar2,
    sVCRBalP        out varchar2,
    sVCRZadR        out varchar2,
    sVCRBuff        out varchar2
  )
    return boolean is
    bRet     boolean := true;
    aParams  Schema_RA.GPC_RA.tblErrParams;
  begin
    if ( sIN_BALANCE = 'T' ) then
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'UNIQCODE';
      aParams( 1 ).ML_VALUE  := to_char( nUniqCode );
      Schema_RA.GPC_RA.RespSetErrorText( 'Липсва буферна експозиция за преоценка $UNIQCODE$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
      bRet                   := bBlackOper or
                                Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'RateDifferPreocenka', Schema_GPSys.OraGPSys.SYS_CURR, 'QUP', null, null, null, nECRBuff, sVCRBuff ) and
                                sVCRBuff = Schema_GPSys.OraGPSys.SYS_CURR;

      if ( bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'CURRENCY';
        aParams( 1 ).ML_VALUE  := sCODVAL;
        aParams( 2 ).ML_NAME   := 'SYNT';
        aParams( 2 ).ML_VALUE  := sSYNT;
        aParams( 3 ).ML_NAME   := 'UNIQCODE';
        aParams( 3 ).ML_VALUE  := to_char( nUniqCode );
        Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за приходи от преоценка $CURRENCY$ $SYNT$ $UNIQCODE$',
                                           Schema_GPSys.MLng.ctxAccounting,
                                           Schema_GPSys.MLng.lngBG,
                                           aParams
                                          );
        bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode,
                                                                   'RateDifferPreocenka',
                                                                   Schema_GPSys.OraGPSys.SYS_CURR,
                                                                   'Prihod',
                                                                   sEXPO_CODE || '_' || substr( sANFEAT, 1, 1 ),
                                                                   sCODVAL,
                                                                   sSYNT,
                                                                   nECRBalP,
                                                                   sVCRBalP
                                                                  ) and
                                  sVCRBalP = Schema_GPSys.OraGPSys.SYS_CURR;

        if ( bRet ) then
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'CURRENCY';
          aParams( 1 ).ML_VALUE  := sCODVAL;
          aParams( 2 ).ML_NAME   := 'SYNT';
          aParams( 2 ).ML_VALUE  := sSYNT;
          aParams( 3 ).ML_NAME   := 'UNIQCODE';
          aParams( 3 ).ML_VALUE  := to_char( nUniqCode );
          Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за разходи от преоценка $CURRENCY$ $SYNT$ $UNIQCODE$',
                                             Schema_GPSys.MLng.ctxAccounting,
                                             Schema_GPSys.MLng.lngBG,
                                             aParams
                                            );
          bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode,
                                                                     'RateDifferPreocenka',
                                                                     Schema_GPSys.OraGPSys.SYS_CURR,
                                                                     'Razhod',
                                                                     sEXPO_CODE || '_' || substr( sANFEAT, 1, 1 ),
                                                                     sCODVAL,
                                                                     sSYNT,
                                                                     nECRBalR,
                                                                     sVCRBalR
                                                                    ) and
                                    sVCRBalR = Schema_GPSys.OraGPSys.SYS_CURR;
        end if;
      end if;
    else
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'CURRENCY';
      aParams( 1 ).ML_VALUE  := sCODVAL;
      aParams( 2 ).ML_NAME   := 'SYNT';
      aParams( 2 ).ML_VALUE  := sSYNT;
      Schema_RA.GPC_RA.RespSetErrorText( 'Липсва обща пасивна задбалансова експозиция $CURRENCY$ $SYNT$',
                                         Schema_GPSys.MLng.ctxAccounting,
                                         Schema_GPSys.MLng.lngBG,
                                         aParams
                                        );
      bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'Common_Zadbalance', Schema_GPSys.OraGPSys.SYS_CURR, 'Passive', 'Preocenka', sCODVAL, sSYNT, nECRZadP, sVCRZadP ) and
                                sVCRZadP = Schema_GPSys.OraGPSys.SYS_CURR;

      if ( bRet ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'CURRENCY';
        aParams( 1 ).ML_VALUE  := sCODVAL;
        aParams( 2 ).ML_NAME   := 'SYNT';
        aParams( 2 ).ML_VALUE  := sSYNT;
        Schema_RA.GPC_RA.RespSetErrorText( 'Липсва обща активна задбалансова експозиция $CURRENCY$ $SYNT$',
                                           Schema_GPSys.MLng.ctxAccounting,
                                           Schema_GPSys.MLng.lngBG,
                                           aParams
                                          );
        bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCode, 'Common_Zadbalance', Schema_GPSys.OraGPSys.SYS_CURR, 'Active', 'Preocenka', sCODVAL, sSYNT, nECRZadR, sVCRZadR ) and
                                  sVCRZadR = Schema_GPSys.OraGPSys.SYS_CURR;
      end if;
    end if;

    return bRet;
  end GetConf2ExpoPreoc;

  --------------------------------------------------------------------------------
  procedure DoOperExpoPreoc(
    nID_EXPO     in     integer,
    sCODVAL      in     varchar2,
    sSYNT        in     varchar2,
    nUniqCode    in     integer,
    sIN_BALANCE  in     varchar2,
    sACTPASS     in     varchar2,
    dWDate       in     date,
    bValior      in     boolean,
    bZeroMinus   in     boolean,
    bBlackOper   in     boolean,
    nECRBalP     in     integer,
    nECRZadP     in     integer,
    nECRBalR     in     integer,
    nECRZadR     in     integer,
    nECRBuff     in     integer,
    nScale       in     number,
    DealOper     in out Schema_GPSys.tblDealOper,
    rBDGData     in out BDG_MOVES%rowtype,
    BdgOpers     in out tblBdgOpers,
    bReport      in     boolean default false
  ) is
    nOborDt       number;
    nOborKt       number;
    nSysOborDt    number;
    nSysOborKt    number;
    nValSaldo     number;
    nOldSaldo     number;
    nNewSaldo     number;
    nAllValSaldo  number := 0;
    nAllOldSaldo  number := 0;
    nTemp         number;
    bDTSaldo      boolean;
    nExpoCRP      integer;
    nExpoCRR      integer;
    ii            integer;
    jj            integer;
    sData         varchar2( 4000 );
  begin
    if ( ( not NoRateDiffer4Cash ) or
        ( not Schema_GPSys.HeadExpo.IsItCashExpo( nID_EXPO ) ) ) then
      select count( 1 )
        into ii
        from Schema_GPSys.CONFSYSTEM
       where FLDSECTION = 'BUDGET' and
             FLDITEM = 'PREOC_SYNT' and
             UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
             FLDVALUE like '%&' || sSYNT || '&%';

      select count( 1 )
        into jj
        from Schema_GPSys.CONFSYSTEM
       where FLDSECTION = 'BDG' and
             FLDITEM = 'SYNTH4CLASIF' and
             UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
             FLDVALUE like '%&' || sSYNT || '&%';

      for rBDGExpo in ( select ID_EXPO,
                               BDG_CLASSIF,
                               BDG_FUNCTION,
                               BDG_OBJECT
                          from BDG_EXPO_STATE
                         where ID_EXPO = nID_EXPO and
                               ii > 0
                       union all
                       select -nID_EXPO as ID_EXPO,
                              rBDGData.BDG_CLASSIF as BDG_CLASSIF,
                              rBDGData.BDG_FUNCTION as BDG_FUNCTION,
                              rBDGData.BDG_OBJECT as BDG_OBJECT
                         from dual ) loop
        if ( rBDGExpo.ID_EXPO > 0 ) then
          nValSaldo     := Expo.EBdgAllSaldoDate( nID_EXPO, rBDGExpo.BDG_CLASSIF, rBDGExpo.BDG_FUNCTION, rBDGExpo.BDG_OBJECT, dWDate, bValior, nOborDt, nOborKt, nSysOborDt, nSysOborKt );
          nOldSaldo     := nSysOborKt - nSysOborDt;
          --
          nAllValSaldo  := nAllValSaldo + nValSaldo;
          nAllOldSaldo  := nAllOldSaldo + nOldSaldo;
        else -- za da se oberat razlikite
          nValSaldo  := Expo.EAllSaldoDate( nID_EXPO, dWDate, bValior, nOborDt, nOborKt, nSysOborDt, nSysOborKt ) - nAllValSaldo;
          nOldSaldo  := nSysOborKt - nSysOborDt - nAllOldSaldo;
        end if;

        nNewSaldo  := Schema_GPSys.XchgRates.GetExactSum( nValSaldo, nUniqCode, dWDate, sCODVAL, Schema_GPSys.OraGPSys.SYS_CURR, Schema_GPSys.XchgRates.XchgRateType_Fixing );

        if ( bReport ) then
          nTemp  := Schema_GPSys.OraGPSys.nTruncSet( nNewSaldo - nOldSaldo );

          if ( ( nValSaldo = 0 and
                nTemp != 0 ) or
              ( nValSaldo * nOldSaldo < 0 ) or
              ( nValSaldo != 0 and
               abs( nTemp ) > nScale ) ) then
            sData  := null;

            if ( Schema_GPSys.GPC_Parser.WriteDate( dWDate, sData ) and
                Schema_GPSys.GPC_Parser.WriteString( abs( rBDGExpo.ID_EXPO ), sData ) and
                Schema_GPSys.GPC_Parser.WriteString( sCODVAL, sData ) and
                Schema_GPSys.GPC_Parser.WriteString( rBDGExpo.BDG_CLASSIF, sData ) and
                Schema_GPSys.GPC_Parser.WriteString( rBDGExpo.BDG_FUNCTION, sData ) and
                Schema_GPSys.GPC_Parser.WriteString( rBDGExpo.BDG_OBJECT, sData ) and
                Schema_GPSys.GPC_Parser.WriteNumber( nOldSaldo, sData ) and
                Schema_GPSys.GPC_Parser.WriteNumber( nNewSaldo, sData ) and
                Schema_GPSys.GPC_Parser.WriteNumber( nTemp, sData ) and
                Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.HeadExpo.IDExpo2ExpoName( abs( rBDGExpo.ID_EXPO ) ), sData ) and
                Schema_GPSys.GPC_Parser.WriteString( Expo.GetExpoBKAcc( abs( rBDGExpo.ID_EXPO ) ), sData ) and
                Schema_GPSys.GPC_Parser.WriteNumber( nValSaldo, sData ) and
                Schema_GPSys.GPC_Parser.WriteNumber( Schema_GPSys.XchgRates.GetXchgRate( nUniqCode, dWDate, sCODVAL, Schema_GPSys.OraGPSys.SYS_CURR, Schema_GPSys.XchgRates.XchgRateType_Fixing ),
                                                     sData
                                                    ) ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            else
              exit;
            end if;
          end if;
        else
          if ( bZeroMinus ) then
            bDTSaldo  := nNewSaldo <= 0;
          else
            bDTSaldo  := nNewSaldo < 0;
          end if;

          nNewSaldo  := Schema_GPSys.OraGPSys.nTruncSet( nNewSaldo - nOldSaldo );

          if ( bDTSaldo ) then
            nNewSaldo  := -nNewSaldo;
          end if;

          if ( ( nValSaldo = 0 and
                nNewSaldo != 0 ) or
              ( nValSaldo * nOldSaldo < 0 ) or
              ( nValSaldo != 0 and
               abs( nNewSaldo ) > nScale ) ) then
            if ( sIN_BALANCE = 'T' ) then
              begin
                select /*+ leading( a b c ) use_nl( b c ) */
                      a.CRP_EXPO,
                       a.CRR_EXPO
                  into nExpoCRP,
                       nExpoCRR
                  from Schema_GPSys.EXPOSITION c,
                       Schema_GPSys.EXPOSITION b,
                       Schema_GPSys.EXPOSITION a
                 where a.ID_EXPO = nID_EXPO and
                       b.ID_EXPO = a.CRP_EXPO and
                       c.ID_EXPO = a.CRR_EXPO and
                       b.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR and
                       c.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR and
                       b.STATUS = 'T' and
                       c.STATUS = 'T';
              exception
                when no_data_found then
                  nExpoCRP  := nECRBalP;
                  nExpoCRR  := nECRBalR;
              end;
            else
              if ( sACTPASS = 'P' ) then
                nExpoCRP  := nECRZadR;
                nExpoCRR  := nECRZadR;
              elsif ( sACTPASS = 'A' ) then
                nExpoCRP  := nECRZadP;
                nExpoCRR  := nECRZadP;
              else
                nExpoCRP  := nECRZadP;
                nExpoCRR  := nECRZadR;
              end if;
            end if;

            DealOper.extend;

            if ( bDTSaldo ) then
              if ( nNewSaldo > 0 ) then
                DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nID_EXPO, 0, nNewSaldo, nExpoCRP, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
              else
                if ( bBlackOper ) then
                  DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nExpoCRR, -nNewSaldo, 0, nID_EXPO, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
                else
                  DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nID_EXPO, 0, nNewSaldo, nECRBuff, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
                  DealOper.extend;
                  DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nExpoCRR, -nNewSaldo, -nNewSaldo, nECRBuff, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
                end if;
              end if;

              rBDGData.AMOUNT  := nNewSaldo;
            else
              if ( nNewSaldo > 0 ) then
                DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nExpoCRR, nNewSaldo, 0, nID_EXPO, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
              else
                if ( bBlackOper ) then
                  DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nID_EXPO, 0, -nNewSaldo, nExpoCRP, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
                else
                  DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nECRBuff, nNewSaldo, 0, nID_EXPO, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
                  DealOper.extend;
                  DealOper( DealOper.last )  := Schema_GPSys.tDealOper( Sch_Preocenka, nECRBuff, -nNewSaldo, -nNewSaldo, nExpoCRP, dWDate, dWDate, nID_EXPO, 'F', null, null, null, 0, null );
                end if;
              end if;

              rBDGData.AMOUNT  := -nNewSaldo;
            end if;

            if ( sIN_BALANCE = 'T' and
                rBDGExpo.BDG_CLASSIF is not null ) then
              BdgOpers( DealOper.last ).BDG_CLASSIF   := rBDGExpo.BDG_CLASSIF;
              BdgOpers( DealOper.last ).BDG_FUNCTION  := rBDGExpo.BDG_FUNCTION;
              BdgOpers( DealOper.last ).BDG_OBJECT    := rBDGExpo.BDG_OBJECT;
              BdgOpers( DealOper.last ).DT_KT         := rBDGData.DT_KT;
              BdgOpers( DealOper.last ).CODVAL        := Schema_GPSys.OraGPSys.SYS_CURR;

              if ( jj > 0 ) then
                BdgOpers( DealOper.last ).AMOUNT      := rBDGData.AMOUNT;
                BdgOpers( DealOper.last ).SYS_AMOUNT  := rBDGData.AMOUNT;
              else
                BdgOpers( DealOper.last ).AMOUNT      := 0;
                BdgOpers( DealOper.last ).SYS_AMOUNT  := 0;
              end if;

              BdgOpers( DealOper.last ).VALIOR        := dWDate;
            end if;
          end if;
        end if;
      end loop;
    end if;
  end DoOperExpoPreoc;

  --------------------------------------------------------------------------------
  function CmdExpoPreocenka( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues     Schema_GPSys.GPC_Parser.taParamStrings;
    aPodelenie     Schema_GPSys.OraGPSys.aNumbers;
    HeadData       Schema_GPSys.tMemoOrder;
    DealOper       Schema_GPSys.tblDealOper;
    BdgOpers       tblBdgOpers;
    rBDGData       BDG_MOVES%rowtype;
    sBDGClassif    BDG_MOVES.BDG_CLASSIF%type;
    sKey           EXPO_NUMBERS.OBJ_NAME%type;
    recExpo        Schema_GPSys.EXPOSITION%rowtype;
    sFolderMode    EXPO_MOVE_TEXT.FOLDER_MODE%type;
    nScale         number;
    dFDate         date;
    dTDate         date;
    dWDate         date;
    dDummy         date;
    dDateBeg       date;
    dDateEnd       date;
    nECRBuff       integer;
    sVCRBuff       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRBalP       integer;
    sVCRBalP       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRBalR       integer;
    sVCRBalR       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRZadP       integer;
    sVCRZadP       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRZadR       integer;
    sVCRZadR       Schema_GPSys.EXPOSITION.CODVAL%type;
    nExpoCRP       integer;
    nExpoCRR       integer;
    nAllExpo       pls_integer;
    nBegExpo       pls_integer := 0;
    nCurExpo       pls_integer := 0;
    nRowNum        pls_integer;
    sExclSyntCode  varchar2( 4000 );
    bValior        boolean;
    bDTSaldo       boolean;
    bZeroMinus     boolean;
    bBlackOper     boolean;
    bOldState      boolean;
    bDummy         boolean;
    bReport        boolean := false;
    bRet           boolean := false;
    bEnd           boolean := true;
    bFromTask      boolean := false;
    aParams        Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_DocSys.DOCSYS_SAVEINIQ.UseQueueBatch2;

    if ( aParamEntities3D.count > 0 ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        if ( aParamEntities3D( ii ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 1 ), dFDate ) and
                       Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bValior ) and
                       ( ( not aRowValues.exists( 3 ) ) or
                        Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), dTDate ) ) and
                       ( ( not aRowValues.exists( 4 ) ) or
                        Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 4 ), bReport ) ) and
                       ( ( not aRowValues.exists( 5 ) ) or
                        Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 5 ), bFromTask ) ) and
                       true;
          dTDate    := nvl( dTDate, dFDate );
        elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) ) then
            bRet  := true;

            if ( aRowValues.count > 0 ) then
              for jj in aRowValues.first .. aRowValues.last loop
                bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( jj ), aPodelenie( aPodelenie.count + 1 ) );
                exit when not bRet;
              end loop;
            end if;
          end if;
        end if;
      end loop;

      if ( bRet and
          bFromTask ) then
        dFDate  := Schema_RA.GPC_Tools.GetSchDate( null );
        dTDate  := dFDate;

        if ( aPodelenie.count = 0 ) then
          for recConfig in ( select FLDUNIQCODE
                               from Schema_RA.CONFIG ) loop
            aPodelenie( aPodelenie.count + 1 )  := recConfig.FLDUNIQCODE;
          end loop;
        end if;
      end if;
    end if;

    if ( bRet ) then
      if ( ( not bFromTask ) or
          dTDate < trunc( sysdate ) ) then
        if ( bRet and
            aPodelenie( aPodelenie.count ) > 0 ) then
          bOldState  := Expo.SetSkipLimit( EXPO.ModeSkip_CardAuth, true );
          nScale     := Schema_GPSys.OraGPSys.GetCurrencyScale( Schema_GPSys.OraGPSys.SYS_CURR );
          nScale     := power( 10, nScale );
          nScale     := Schema_GPSys.OraGPSys.nTruncSet( nScale );
          dDateBeg   := sysdate;

          for ii in aPodelenie.first .. aPodelenie.last loop
            if ( bReport ) then
              Schema_GPSys.GPC_Parser.RespAddTable( 1 );
            else
              nRowNum  := Schema_RA.GPC_RA.GetNumber( 'MainBatchLog' );
              commit;
              Schema_RA.GPC_RA.LogMainBatchPrc( nRowNum, 'CmdExpoPreocenka', aPodelenie( ii ), false, dTDate );
            end if;

            if ( Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'Счетоводство', 'ПреоценкаЕкспозиции', 'T' ) ) ) then
              bRet  := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, aPodelenie( ii ) );

              if ( bRet ) then
                sFolderMode    := Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'FOLDER', 'MODE_PREOC', null );
                --
                sBDGClassif    := Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'BUDGET', 'PREOC_CLASSIF', null );

                if ( sBDGClassif is not null ) then
                  rBDGData.BDG_FUNCTION  := Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'BUDGET', 'PREOC_FUNCTION', null );
                  rBDGData.BDG_OBJECT    := Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'BUDGET', 'PREOC_OBJECT', null );
                  rBDGData.DT_KT         := Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'BUDGET', 'PREOC_DT_KT', 'K' );
                end if;

                --
                bZeroMinus     := Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'Счетоводство', 'PreocZeroDT', 'T' ) );
                bBlackOper     := Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'Счетоводство', 'PreocBlackOper', 'T' ) );
                sExclSyntCode  := Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'Счетоводство', 'PreocExclSyntCode', '~' );
                --
                dWDate         := dFDate;

                while ( dWDate <= dTDate ) loop
                  if ( nvl( dWDate = Schema_RA.GPC_Tools.GetSchDate( aPodelenie( ii ) ), false ) or
                      nvl( dWDate = Schema_DocSys.DOCSYS.GetWorkDay( dWDate, dDummy ), false ) ) then
                    sKey               := 'Preocenka_' || to_char( aPodelenie( ii ) );
                    recExpo.EXPO_CODE  := '_';
                    recExpo.CODVAL     := '_';
                    recExpo.AN_FEAT    := '_';

                    if ( not bReport ) then
                      begin
                        select nvl( NUM, 0 )
                          into nBegExpo
                          from EXPO_NUMBERS
                         where OBJ_NAME = sKey;
                      exception
                        when no_data_found then
                          nBegExpo  := 0;

                          insert into EXPO_NUMBERS(
                                        OBJ_NAME,
                                        NUM
                                      )
                               values ( sKey,
                                        nBegExpo
                                       );

                          commit;
                      end;
                    end if;

                    select count( ID_EXPO )
                      into nAllExpo
                      from Schema_GPSys.EXPOSITION
                     where UNIQCODE = aPodelenie( ii ) and
                           STATUS = 'T' and
                           ID_EXPO > nBegExpo and
                           CODVAL != Schema_GPSys.OraGPSys.SYS_CURR and
                           NOPREOC = 'F' and
                           instr( sExclSyntCode, '&' || SYNT_CODE || '&' ) = 0;

                    DealOper           := Schema_GPSys.tblDealOper( );

                    if ( nAllExpo > 0 ) then
                      for rec in (  select Schema_GPSys.OraGPSys.GetSynt( a.EXPO_CODE ) as SYNT,
                                           a.CODVAL,
                                           nvl( a.AN_FEAT, '~' ) as ANFEAT,
                                           a.ID_EXPO,
                                           a.TYPE_EXPO,
                                           a.EXPO_CODE,
                                           a.AN1,
                                           a.AN2,
                                           a.AN3,
                                           a.AN4,
                                           a.AN5,
                                           a.AN6,
                                           a.SYNT_CODE,
                                           b.IN_BALANCE,
                                           b.ACTPASS
                                      from Schema_GPSys.EXPOTYPES b,
                                           Schema_GPSys.EXPOSITION a
                                     where a.UNIQCODE = aPodelenie( ii ) and
                                           a.STATUS = 'T' and
                                           a.ID_EXPO > nBegExpo and
                                           a.CODVAL != Schema_GPSys.OraGPSys.SYS_CURR and
                                           a.NOPREOC = 'F' and
                                           instr( sExclSyntCode, '&' || a.SYNT_CODE || '&' ) = 0 and
                                           a.TYPE_EXPO = b.TYPE_EXPO
                                  order by 1,
                                           2,
                                           3,
                                           4 ) loop
                        if ( recExpo.EXPO_CODE != rec.SYNT or
                            recExpo.CODVAL != rec.CODVAL or
                            recExpo.AN_FEAT != rec.ANFEAT ) then
                          recExpo.EXPO_CODE  := rec.SYNT;
                          recExpo.CODVAL     := rec.CODVAL;
                          recExpo.AN_FEAT    := rec.ANFEAT;
                          bRet               := GetConf2ExpoPreoc( rec.CodVal,
                                                                   rec.SYNT,
                                                                   rec.IN_BALANCE,
                                                                   aPodelenie( ii ),
                                                                   bBlackOper,
                                                                   rec.EXPO_CODE,
                                                                   rec.ANFEAT,
                                                                   nECRBuff,
                                                                   nECRBalP,
                                                                   nECRZadP,
                                                                   nECRBalR,
                                                                   nECRZadR,
                                                                   sVCRZadP,
                                                                   sVCRBalR,
                                                                   sVCRBalP,
                                                                   sVCRZadR,
                                                                   sVCRBuff
                                                                  );
                        end if;

                        if ( bRet ) then
                          if ( sBDGClassif is not null ) then
                            rBDGData.BDG_CLASSIF      := nvl( Schema_GPSys.OraGPSys.GetIniValueInt( aPodelenie( ii ), 'BUDGET', 'PREOC_CLASSIF_' || to_char( rec.TYPE_EXPO ) || 'A1' || rec.AN1, null ),
                                                              sBDGClassif
                                                             );
                          end if;

                          DoOperExpoPreoc( rec.ID_EXPO,
                                           rec.CODVAL,
                                           rec.SYNT_CODE,
                                           aPodelenie( ii ),
                                           rec.IN_BALANCE,
                                           rec.ACTPASS,
                                           dWDate,
                                           bValior,
                                           bZeroMinus,
                                           bBlackOper,
                                           nECRBalP,
                                           nECRZadP,
                                           nECRBalR,
                                           nECRZadR,
                                           nECRBuff,
                                           nScale,
                                           DealOper,
                                           rBDGData,
                                           BdgOpers,
                                           bReport
                                          );

                          if ( ( not bReport ) and
                              DealOper.count > 500 ) then
                            savepoint CmdExpoPreocenka_1;
                            HeadData      := Schema_GPSys.tMemoOrder( null,
                                                                      aPodelenie( ii ),
                                                                      Schema_GPSys.MLng.Str2( 'Валутна преоценка', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ),
                                                                      dWDate,
                                                                      null,
                                                                      null,
                                                                      null,
                                                                      null,
                                                                      null,
                                                                      sFolderMode,
                                                                      sysdate
                                                                     );
                            bRet          := GenerateMemoOrder( HeadData, DealOper, false, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, true, false, null, BdgOpers );

                            if ( bRet ) then
                              update EXPO_NUMBERS
                                 set NUM  = rec.ID_EXPO
                               where OBJ_NAME = sKey;

                              commit;
                            else
                              rollback to CmdExpoPreocenka_1;
                            end if;

                            DealOper      := Schema_GPSys.tblDealOper( );
                          end if;
                        end if;

                        bEnd      := false;

                        if ( mod( nCurExpo, 10 ) = 0 ) then
                          Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue  := nvl( Schema_DocSys.DOCSYS_SAVEINIQ.ChooseInputIQ, Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue );
                        end if;

                        nCurExpo  := nCurExpo + 1;

                        if ( not bRet ) then
                          Schema_RA.GPC_Tools.WriteErrorMsg( Schema_GPSys.MLng.Str2( 'Валутна преоценка', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ) );
                        end if;

                        bRet      := /* bRet and */
                                     -- da ne spira pri gre6ka
                                     Schema_RA.GPC_RA.ChkStopField( nCurExpo, nAllExpo, null, Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue );
                        exit when not bRet;
                        bEnd      := true;
                      end loop;
                    else
                      bEnd  := true;
                    end if;

                    if ( bRet and
                        bEnd and
                        ( not bReport ) ) then
                      if ( DealOper.count > 0 ) then
                        savepoint CmdExpoPreocenka_2;
                        HeadData      := Schema_GPSys.tMemoOrder( null,
                                                                  aPodelenie( ii ),
                                                                  Schema_GPSys.MLng.Str2( 'Валутна преоценка', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ),
                                                                  dWDate,
                                                                  null,
                                                                  null,
                                                                  null,
                                                                  null,
                                                                  null,
                                                                  sFolderMode,
                                                                  sysdate
                                                                 );
                        bRet          := GenerateMemoOrder( HeadData, DealOper, false, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, true, false, null, BdgOpers );

                        if ( bRet ) then
                          commit;
                        else
                          rollback to CmdExpoPreocenka_2;
                        end if;
                      end if;

                      if ( bRet ) then
                        delete from EXPO_NUMBERS
                              where OBJ_NAME = sKey;

                        commit;
                      end if;
                    end if;
                  end if;

                  exit when not bRet;
                  dWDate  := dWDate + 1;
                end loop;

                bDTSaldo       := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, aPodelenie( ii ) );
              else
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'UNIQCODE';
                aParams( 1 ).ML_VALUE  := to_char( aPodelenie( ii ) );
                Schema_RA.GPC_RA.RespSetErrorText( 'Неуспешен опит за забрана на счетоводни операции в поделение $UNIQCODE$',
                                                   Schema_GPSys.MLng.ctxAccounting,
                                                   Schema_GPSys.MLng.lngBG,
                                                   aParams
                                                  );
              end if;
            end if;

            if ( not bReport ) then
              Schema_RA.GPC_RA.LogMainBatchPrc( nRowNum, 'CmdExpoPreocenka', aPodelenie( ii ), bRet, dTDate );
            end if;

            exit when not bRet;
          end loop;

          bDummy     := Expo.SetSkipLimit( EXPO.ModeSkip_CardAuth, bOldState );
          dDateEnd   := sysdate;
        end if;
      else
        if ( bFromTask and
            dTDate >= trunc( sysdate ) ) then
          Schema_RA.GPC_Tools.WriteErrorMsg( Schema_GPSys.MLng.Str2( 'Tехнология Schema_Expo.CmdExpoPreocenka - преоценката не е извършена, защото счетоводна дата е по-голяма или равна на календарната дата',
                                                                     Schema_GPSys.MLng.ctxAccounting,
                                                                     Schema_GPSys.MLng.lngBG
                                                                    ),
                                             Schema_RA.GPC_Tools.def_SubTypeMode_None,
                                             0,
                                             Schema_RA.GPC_Tools.defSeverity_Info
                                            );
        end if;
      end if;
    else
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    end if;

    if ( bFromTask ) then
      bDummy      := Schema_RA.EVENT.GenerateEvent( true,
                                                    null,
                                                    case
                                                      when bRet then Schema_RA.EVENT.defTypeEvent_ExpoPreocenka_OK
                                                      else Schema_RA.EVENT.defTypeEvent_ExpoPreocenka_NOK
                                                    end,
                                                    0,
                                                    case
                                                      when bRet then
                                                        Schema_GPSys.MLng.Str2( 'Валутна преоценка' ||
                                                                                chr( 13 )||
                                                                                chr( 10 )||
                                                                                ' Стартиран ' ||
                                                                                to_char( dDateBeg, Schema_GPSys.GPC_Parser.FORMAT_DATETIME_DOTS )||
                                                                                ' и приключил ' ||
                                                                                to_char( dDateEnd, Schema_GPSys.GPC_Parser.FORMAT_DATETIME_DOTS ),
                                                                                Schema_GPSys.MLng.ctxSysMsg,
                                                                                Schema_GPSys.MLng.lngBG
                                                                               )
                                                      else
                                                        Schema_GPSys.MLng.Str2( 'Валутна преоценка приключи с грешка' ||
                                                                                chr( 13 )||
                                                                                chr( 10 )||
                                                                                Schema_RA.GPC_RA.RespGetErrorText ||
                                                                                chr( 13 )||
                                                                                chr( 10 )||
                                                                                ' Стартиран ' ||
                                                                                to_char( dDateBeg, Schema_GPSys.GPC_Parser.FORMAT_DATETIME_DOTS )||
                                                                                ' и приключил ' ||
                                                                                to_char( dDateEnd, Schema_GPSys.GPC_Parser.FORMAT_DATETIME_DOTS ),
                                                                                Schema_GPSys.MLng.ctxSysMsg,
                                                                                Schema_GPSys.MLng.lngBG
                                                                               )
                                                    end
                                                   );
    end if;

    return bRet;
  end CmdExpoPreocenka;

  --------------------------------------------------------------------------------
  function CmdBaseIntrSave( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues   Schema_GPSys.GPC_Parser.taParamStrings;
    oDoc         Schema_GPSys.DocSysIQType;
    RecBaseIntr  EXPO_BASE_INTR%rowtype;
    jj           pls_integer;
    sCmdName     varchar2( 64 ) := 'BaseIntrSave';
    bRet         boolean := false;
    aParams      Schema_RA.GPC_RA.tblErrParams;
  begin
    if ( aParamEntities3D.count > 0 ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        RecBaseIntr  := null;
        oDoc         := Schema_GPSys.DocSysIQType( );
        bRet         := aParamEntities3D( ii ).nRowType = 1 and
                        Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                        Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), RecBaseIntr.BASE_PRC ) and
                        Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), RecBaseIntr.CODVAL ) and
                        Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), RecBaseIntr.FROM_DATE ) and
                        Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 4 ), RecBaseIntr.PERCENT ) and
                        Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 5 ), RecBaseIntr.AMN_TO ) and
                        ( ( not aRowValues.exists( 6 ) ) or
                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 6 ), RecBaseIntr.END_DATE ) ) and
                        Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.TypeBase', 1, RecBaseIntr.BASE_PRC ) and
                        Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.CodVal', 1, RecBaseIntr.CODVAL ) and
                        Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, sCmdName, '1.FromDate', 1, RecBaseIntr.FROM_DATE ) and
                        Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.Percent', 1, RecBaseIntr.PERCENT ) and
                        Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ChOper', 1, Schema_RA.GPC_RA.nCurrentUserID ) and
                        Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.AmnTo', 1, RecBaseIntr.AMN_TO ) and
                        Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, sCmdName, '1.EndDate', 1, RecBaseIntr.END_DATE ) and
                        true;

        if ( bRet ) then
          bRet      := RecBaseIntr.BASE_PRC not like 'REBASEDINDEX%' or
                       RecBaseIntr.PERCENT > 0;

          if ( bRet ) then
            jj    := Schema_DocSys.DOCSYS_SaveInIQ.SaveDoc( oDoc );
            bRet  := jj = 0;

            if ( bRet ) then
              merge /*+ leading( yy xx ) use_nl( xx ) */
                   into  LOAN_CRED_PROCESS xx
                   using (select /*+ LEADING( a b c ) USE_NL( b c ) */
                                distinct a.ID_CRED_ENGAGE
                            from CURRENT_INT_RATE c,
                                 LOAN_EXPOSITION b,
                                 LOAN_CREDIT a
                           where a.STATUS = Schema_Expo.Loans.LoanStat_Active and
                                 b.ID_CRED_ENGAGE = a.ID_CRED_ENGAGE and
                                 b.TYPE_CRED_EXPO = Schema_GPSys.HeadExpo.ExpoCred_RedovenDulg and
                                 c.ID_EXPO = b.ID_EXPO and
                                 nvl( c.BASE_PRC, '~' ) = RecBaseIntr.BASE_PRC) yy
                      on ( xx.ID_CRED = yy.ID_CRED_ENGAGE )
              when matched then
                update set xx.LIH_PROC  = 0;

              commit;
            else
              rollback;
              --
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'ERR';
              aParams( 1 ).ML_VALUE  := to_char( jj );
              Schema_RA.GPC_RA.RespSetErrorText( 'SaveDoc() error: $ERR$', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngEN, aParams );
            end if;
          else
            Schema_RA.GPC_RA.RespSetErrorText( 'Некоректна стойност', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          end if;
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdBaseIntrSave;

  --------------------------------------------------------------------------------
  function CmdBaseIntrLoad( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    RecIntr     EXPO_BASE_INTR%rowtype;
    sData       varchar2( 4000 );
    dWrkDate    date;
    dFrDate     date;
    dToDate     date;
    bRet        boolean := false;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 aRowValues.count >= 4 and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), RecIntr.BASE_PRC ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), RecIntr.CODVAL ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), dFrDate ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 4 ), dToDate ) and
                 true;

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      Schema_GPSys.GPC_Parser.RespAddTable( 1 );

      select max( FROM_DATE )
        into dWrkDate
        from EXPO_BASE_INTR
       where BASE_PRC = RecIntr.BASE_PRC and
             CODVAL = RecIntr.CODVAL and
             FROM_DATE <= dFrDate;

      dWrkDate  := nvl( dWrkDate, dFrDate );

      for rec in (  select *
                      from EXPO_BASE_INTR
                     where BASE_PRC = RecIntr.BASE_PRC and
                           CODVAL = RecIntr.CODVAL and
                           FROM_DATE between dWrkDate and dToDate
                  order by FROM_DATE ) loop
        sData     := null;
        bRet      := Schema_GPSys.GPC_Parser.WriteDate( rec.FROM_DATE, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( rec.PERCENT, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rec.BASE_PRC, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( rec.AMN_TO, sData ) and
                     Schema_GPSys.GPC_Parser.WriteDate( rec.END_DATE, sData ) and
                     true;

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        else
          exit;
        end if;
      end loop;
    end if;

    return bRet;
  end CmdBaseIntrLoad;

  --------------------------------------------------------------------------------
  function CmdIDMove2DocDate( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nIdMove     integer;
    nDocNo      integer;
    nUniqCode   integer;
    dDocDate    date;
    sTemp       varchar2( 4000 );
    bRet        boolean;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                 Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIdMove );

    if ( bRet ) then
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'ID_MOVE';
      aParams( 1 ).ML_VALUE  := to_char( nIdMove );
      Schema_RA.GPC_RA.RespSetErrorText( 'Несъществуващо движение с номер $ID_MOVE$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
      bRet                   := Expo.IDMove2DocDate( nIDMove, nUniqCode, dDocDate, nDocNo );

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 1 );
        bRet      := Schema_GPSys.GPC_Parser.WriteInteger( nUniqCode, sTemp ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( nDocNo, sTemp ) and
                     Schema_GPSys.GPC_Parser.WriteDate( dDocDate, sTemp );

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sTemp );
        end if;
      end if;
    end if;

    return bRet;
  end CmdIDMove2DocDate;

  --------------------------------------------------------------------------------
  function CmdNewHameleonDep( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    handle      varchar2( 128 );
    sCodVal     varchar2( 3 );
    nIdExpo     integer;
    nNewIdExpo  integer;
    ii          integer;
    bRet        boolean;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи технологията', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    dbms_lock.allocate_unique( 'Schema_Expo.NewHameleonDep', handle );
    bRet  := dbms_lock.REQUEST( handle, dbms_lock.X_MODE, 0 ) = 0;

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIdExpo ) and
                   Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), sCodVal );

      if ( bRet ) then
        select /*+ ORDERED USE_NL( b ) */
              count( 1 )
          into ii
          from (select distinct ID_EXPO
                  from (with Rel as
                               (select a.ID_OBJ1
                                  from Schema_Expo.OBJ_GROUP_REL a
                                 where a.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                       a.ID_OBJ2 = nIDExpo and
                                       a.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit)
                        ( select ID_OBJ1 as ID_EXPO
                            from Rel
                         union
                         select ID_OBJ1 as ID_EXPO
                           from Schema_Expo.OBJ_GROUP_REL
                          where TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                ID_OBJ1 = nIDExpo and
                                TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit )
                        union all
                        select b.ID_OBJ2 as ID_EXPO
                          from Schema_Expo.OBJ_GROUP_REL b
                         where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                               b.ID_OBJ1 in (select ID_OBJ1 as MAINEXPO
                                               from Rel) and
                               b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit
                        union all
                        select b.ID_OBJ2 as ID_EXPO
                          from Schema_Expo.OBJ_GROUP_REL b
                         where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                               b.ID_OBJ1 = nIDExpo and
                               b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit)) a,
               Schema_GPSys.EXPOSITION b
         where b.ID_EXPO = a.ID_EXPO and
               b.CODVAL = sCodVal;

        bRet  := ii = 0;

        if ( bRet ) then
          bRet  := Expo.NewDepozitOpen( nIdExpo, sCodVal, nNewIdExpo );

          if ( bRet ) then
            commit;
          else
            rollback;
          end if;
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Такъв депозит вече е открит', Schema_GPSys.MLng.ctxAccounts, Schema_GPSys.MLng.lngBG );
        end if;
      end if;

      ii        := dbms_lock.release( handle );
    end if;

    return bRet;
  end CmdNewHameleonDep;

  --------------------------------------------------------------------------------
  function CmdChgValHameleonDep( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues    Schema_GPSys.GPC_Parser.taParamStrings;
    MemoHeadData  Schema_GPSys.tMemoOrder;
    DealOper      Schema_GPSys.TDealOper;
    DealOpers     Schema_GPSys.tblDealOper;
    aIDs          Schema_GPSys.OraGPSys.aNumbers;
    sData         varchar2( 4000 );
    sCodVal       varchar2( 3 );
    sNewVal       varchar2( 3 );
    ii            pls_integer;
    nRowType      pls_integer;
    nExist        pls_integer := 0;
    nTypeExpo     pls_integer;
    nRate         number;
    bRet          boolean := true;
    bOldState     boolean;
    bLimits       boolean;
    aParams       Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    ii  := aParamEntities3D.first;

    while ( ii is not null and
           bRet ) loop
      nRowType  := aParamEntities3D( ii ).nRowType;
      bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues );

      if ( bRet ) then
        if ( nRowType = 1 ) then
          MemoHeadData           := Schema_GPSys.tMemoOrder( null, null, null, null, null, null, null, null, null, null, null );
          DealOper               := Schema_GPSys.TDealOper( null, null, null, null, null, null, null, null, null, null, null, null, null, null );
          DealOpers              := Schema_GPSys.tblDealOper( );
          bRet                   := aRowValues.count >= 7 and
                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), MemoHeadData.ORD_TEXT ) and
                                    Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 2 ), MemoHeadData.SCH_DATE ) and
                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), MemoHeadData.ORIGIN ) and
                                    Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), DealOper.EXPO_DT ) and
                                    Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 5 ), DealOper.AMOUNT_KT ) and
                                    Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 6 ), DealOper.VALIOR_DT ) and
                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 7 ), sNewVal );

          begin
            select UNIQCODE,
                   ID_CUST,
                   TYPE_EXPO
              into MemoHeadData.UNIQCODE,
                   MemoHeadData.ID_CUST,
                   nTypeExpo
              from DEPOSIT_EXPO
             where ID_EXPO = DealOper.EXPO_DT;

            if not ( OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHameleon, nTypeExpo ) or
                    OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHamelPref, nTypeExpo ) or
                    OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHamelTriple, nTypeExpo ) ) then
              Schema_RA.GPC_RA.RespSetErrorText( 'Депозитът трябва да е от тип "Хамелеон"', Schema_GPSys.MLng.ctxAccounts, Schema_GPSys.MLng.lngBG );
              bRet  := false;
            end if;
          exception
            when no_data_found then
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'EXPO_DT';
              aParams( 1 ).ML_VALUE  := to_char( DealOper.EXPO_DT );
              Schema_RA.GPC_RA.RespSetErrorText( 'Няма експозиция с номер $EXPO_DT$', Schema_GPSys.MLng.ctxAccounts, Schema_GPSys.MLng.lngBG, aParams );
          end;

          MemoHeadData.DateTime  := sysdate;
        elsif ( nRowType = 2 ) then
          bRet      := aRowValues.count >= 2 and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), sCodVal ) and
                       Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 2 ), nRate );

          if ( bRet ) then
            bRet      := nRate =
                           round( case
                                    when sCodVal = Schema_GPSys.OraGPSys.BGN_CURR and
                                         Schema_GPSys.OraGPSys.GetSysCurrByDate( MemoHeadData.SCH_DATE ) = Schema_GPSys.OraGPSys.EUR_CURR then
                                      Schema_GPSys.OraGPSys.BGN2EURRate
                                    else
                                      Schema_GPSys.XchgRates.GetXchgRate( MemoHeadData.UNIQCODE,
                                                                          MemoHeadData.SCH_DATE,
                                                                          sCodVal,
                                                                          Schema_GPSys.OraGPSys.GetSysCurrByDate( MemoHeadData.SCH_DATE ),
                                                                          Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                         )
                                  end,
                                  8
                                 );

            if ( not bRet ) then
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'RATE';
              aParams( 1 ).ML_VALUE  := to_char( nRate );
              aParams( 2 ).ML_NAME   := 'CURRENCY';
              aParams( 2 ).ML_VALUE  := sCodVal;
              Schema_RA.GPC_RA.RespSetErrorText( 'Несъответствие на финксинга $RATE$ за $CURRENCY$', Schema_GPSys.MLng.ctxAccounts, Schema_GPSys.MLng.lngBG, aParams );
            end if;
          end if;
        end if;
      end if;

      ii        := aParamEntities3D.next( ii );
    end loop;

    if ( bRet ) then
      select /*+ ORDERED USE_NL( b ) */
            nvl( min( b.ID_EXPO ), 0 )
        into DealOper.EXPO_KT
        from (select distinct ID_EXPO
                from (with Rel as
                             (select a.ID_OBJ1
                                from Schema_Expo.OBJ_GROUP_REL a
                               where a.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                     a.ID_OBJ2 = DealOper.EXPO_DT and
                                     a.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit)
                      ( select ID_OBJ1 as ID_EXPO
                          from Rel
                       union
                       select ID_OBJ1 as ID_EXPO
                         from Schema_Expo.OBJ_GROUP_REL
                        where TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                              ID_OBJ1 = DealOper.EXPO_DT and
                              TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit )
                      union all
                      select b.ID_OBJ2 as ID_EXPO
                        from Schema_Expo.OBJ_GROUP_REL b
                       where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                             b.ID_OBJ1 in (select ID_OBJ1 as MAINEXPO
                                             from Rel) and
                             b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit
                      union all
                      select b.ID_OBJ2 as ID_EXPO
                        from Schema_Expo.OBJ_GROUP_REL b
                       where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                             b.ID_OBJ1 = DealOper.EXPO_DT and
                             b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit)) a,
             Schema_GPSys.EXPOSITION b
       where b.ID_EXPO = a.ID_EXPO and
             b.CODVAL = sNewVal;

      if ( DealOper.EXPO_KT = 0 ) then
        bRet  := Expo.NewDepozitOpen( DealOper.EXPO_DT, sNewVal, DealOper.EXPO_KT );
      else
        if ( not ( OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHamelPref, nTypeExpo ) or
                  OTHEREXPO.IsSpecialDeposit( Schema_GPSys.HeadExpo.DepositHamelTriple, nTypeExpo ) ) ) then
          select distinct ID_EXPO
            bulk collect into aIDs
            from (select distinct ID_EXPO
                    from (with Rel as
                                 (select a.ID_OBJ1
                                    from Schema_Expo.OBJ_GROUP_REL a
                                   where a.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                         a.ID_OBJ2 = DealOper.EXPO_DT and
                                         a.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit)
                          ( select ID_OBJ1 as ID_EXPO
                              from Rel
                           union
                           select ID_OBJ1 as ID_EXPO
                             from Schema_Expo.OBJ_GROUP_REL
                            where TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                  ID_OBJ1 = DealOper.EXPO_DT and
                                  TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit )
                          union all
                          select b.ID_OBJ2 as ID_EXPO
                            from Schema_Expo.OBJ_GROUP_REL b
                           where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                 b.ID_OBJ1 in (select ID_OBJ1 as MAINEXPO
                                                 from Rel) and
                                 b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit
                          union all
                          select b.ID_OBJ2 as ID_EXPO
                            from Schema_Expo.OBJ_GROUP_REL b
                           where b.TYPE_OBJ1 = Schema_GPSys.HeadExpo.ExpoGrpDeposit and
                                 b.ID_OBJ1 = DealOper.EXPO_DT and
                                 b.TYPE_OBJ2 = Schema_GPSys.HeadExpo.ExpoGrpDeposit));

          if ( aIDs.count > 0 ) then
            for jj in aIDs.first .. aIDs.last loop
              for kk in aIDs.first .. aIDs.last loop
                if ( jj != kk ) then
                  select count( 1 )
                    into nRowType
                    from EXPO_STRNMOVES d,
                         EXPO_STRNMOVES c,
                         EXPO_MOVES b,
                         EXPO_MOVES a
                   where a.ID_EXPO = aIDs( jj ) and
                         b.ID_MOVE = a.ID_MOVE and
                         b.ORDROWNUM = a.ORDROWNUM and
                         b.ID_EXPO = aIDs( kk ) and
                         a.ID_MOVE = c.ID_MOVE_NEW(+) and
                         c.ID_MOVE_NEW is null and
                         a.ID_MOVE = d.ID_MOVE_OLD(+) and
                         d.ID_MOVE_OLD is null;

                  nExist  := nExist + nRowType;
                end if;
              end loop;
            end loop;
          end if;
        end if;
      end if;

      if ( bRet ) then
        if ( nExist < Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'EXPOSITION', 'HML_MAX_CHANGE', 2 ) ) then
          bRet      := Expo.GetExpoHotSaldo( DealOper.EXPO_DT, DealOper.AMOUNT_DT ) and
                       DealOper.AMOUNT_DT > 0;

          if ( bRet ) then
            DealOper.DEAL_TYPE            := Sch_Free;
            DealOper.MAIN_EXPO            := DealOper.EXPO_DT;
            DealOper.USE_TAXES            := 'F';
            DealOper.VaLIOR_KT            := DealOper.VALIOR_DT;
            DealOpers.extend;
            DealOpers( DealOpers.count )  := DealOper;
            bOldState                     := Expo.SetSkipLimit( EXPO.ModeSkip_Limit, true );
            bRet                          := GenerateMemoOrder( MemoHeadData, DealOpers );
            bLimits                       := Expo.SetSkipLimit( EXPO.ModeSkip_Limit, bOldState );
          end if;

          if ( bRet and
              nvl( MemoHeadData.ID_MOVE, 0 ) > 0 ) then
            Schema_GPSys.GPC_Parser.RespAddArray( 1 );
            sData  := null;
            bRet   := Schema_GPSys.GPC_Parser.WriteInteger( MemoHeadData.ID_MOVE, sData );

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            end if;

            commit;
          else
            rollback;
          end if;
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Достигнат е максималният брой превалутирания на депозита',
                                             Schema_GPSys.MLng.ctxAccounts,
                                             Schema_GPSys.MLng.lngBG
                                            );
          bRet  := false;
        end if;
      end if;
    end if;

    return bRet;
  end CmdChgValHameleonDep;

  ---------------------------------------------------------------------------------------
  procedure SaveEntierPassed(
    nUniqCode  in integer,
    sPrc       in varchar2
  ) is
  begin
    insert into ENTIER_PASSED(
                  UNIQCODE,
                  PRC,
                  STAMP
                )
         values ( nUniqCode,
                  sPrc,
                  sysdate
                 );
  end SaveEntierPassed;

  ---------------------------------------------------------------------------------------
  function CmdYearEndSaldoDo( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues     Schema_GPSys.GPC_Parser.taParamStrings;
    HeadData       Schema_GPSys.tMemoOrder;
    aListFr        Schema_GPSys.OraGPSys.aStrings;
    aListTo        Schema_GPSys.OraGPSys.aStrings;
    aUniqCodes     Schema_GPSys.OraGPSys.aIntegers;
    DealOper       Schema_GPSys.tblDealOper;
    sReferenciaA   EXPO_MOVES.REFERENCIA%type;
    sReferenciaP   EXPO_MOVES.REFERENCIA%type;
    ii             pls_integer;
    jj             pls_integer;
    nCurrent       integer := 0;
    nGroup         integer;
    nUniqCode      integer;
    nSaldo         number;
    nSaldoSys      number;
    nOrgOborDt     number;
    nOrgOborKt     number;
    nSysOborDt     number;
    nSysOborKt     number;
    dSchDate       date;
    dValior        date;
    sValDt         varchar2( 3 );
    sValKt         varchar2( 3 );
    sExclSyntCode  varchar2( 4000 );
    bRet           boolean := true;
    bStop          boolean;
    bDummy         boolean;
    bPreView       boolean := false;
    bNoPreoc       boolean := false;
    aParams        Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    ii    := aParamEntities3D.first;
    bRet  := ii is not null;
    Schema_RA.GPC_RA.BegTempResponces;

    while ( ii is not null and
           bRet ) loop
      if ( aParamEntities3D( ii ).nRowType = 1 ) then
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                     aRowValues.count >= 4 and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUniqCode ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nGroup ) and
                     Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), dSchDate ) and
                     Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 4 ), dValior ) and
                     ( ( not aRowValues.exists( 5 ) ) or
                      Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 5 ), bPreView ) );
      elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
        if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) ) then
          bRet  := true;

          if ( aRowValues.count > 0 ) then
            for jj in aRowValues.first .. aRowValues.last loop
              bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( jj ), aUniqCodes( aUniqCodes.count + 1 ) );
              exit when not bRet;
            end loop;
          end if;
        end if;
      end if;

      exit when not bRet;
      ii  := aParamEntities3D.next( ii );
    end loop;

    if ( bRet ) then
      sReferenciaA  := Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'REFERENCE', 'END_SALDO_A', null );
      sReferenciaP  := Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'REFERENCE', 'END_SALDO_P', null );

      if ( aUniqCodes.count = 0 ) then
        aUniqCodes( aUniqCodes.count + 1 )  := nUniqCode;
      end if;

      for jj in aUniqCodes.first .. aUniqCodes.last loop
        nUniqCode      := aUniqCodes( jj );
        sExclSyntCode  := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'PreocExclSyntCode', '~' );
        bRet           := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqCode );

        if ( bRet ) then
          for recConf in ( select *
                             from END_SALDA_CONF
                            where ID_GROUP = nGroup and
                                  UNIQCODE = nUniqCode ) loop
            bRet  := Schema_GPSys.OraGPSys.SplitRanges( recConf.EXPOCODE, aListFr, aListTo );

            if ( bRet ) then
              sValDt  := Schema_GPSys.HeadExpo.IDExpo2CodVal( recConf.SALDODT );
              sValKt  := Schema_GPSys.HeadExpo.IDExpo2CodVal( recConf.SALDOKT );
              ii      := aListFr.first;

              while ( ii is not null ) loop
                for recExpo in ( select *
                                   from Schema_GPSys.EXPOSITION
                                  where UNIQCODE = nUniqCode and
                                        STATUS = 'T' and
                                        ( Schema_GPSys.OraGPSys.GetSynt( EXPO_CODE ) between aListFr( ii ) and aListTo( ii ) ) ) loop
                  if ( recExpo.ID_EXPO not in (recConf.SALDODT, recConf.SALDOKT) ) then
                    nSaldo     := Expo.EAllSaldoDate( recExpo.ID_EXPO, dSchDate, false, nOrgOborDt, nOrgOborKt, nSysOborDt, nSysOborKt );
                    nSaldoSys  := nSysOborKt - nSysOborDt;

                    if ( nSaldo != 0 and
                        nSaldo between nvl( recConf.SALDOFR, nSaldo ) and nvl( recConf.SALDOTO, nSaldo ) ) then
                      HeadData      := Schema_GPSys.tMemoOrder( null,
                                                                nUniqCode,
                                                                Schema_GPSys.MLng.Str2( 'Приключване на салда', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ),
                                                                dSchDate,
                                                                null,
                                                                null,
                                                                null,
                                                                null,
                                                                null,
                                                                null,
                                                                sysdate
                                                               );
                      bNoPreoc      := not ( recExpo.NOPREOC = 'F' and
                                            instr( sExclSyntCode, '&' || recExpo.SYNT_CODE || '&' ) = 0 );
                      DealOper      := Schema_GPSys.tblDealOper( );
                      DealOper.extend;

                      if ( nSaldo < 0 ) then
                        nSaldo                         := -nSaldo;
                        nSaldoSys                      := -nSaldoSys;
                        DealOper( DealOper.last )      := Schema_GPSys.tDealOper( Sch_EndSaldo,
                                                                                  recConf.SALDODT,
                                                                                  case
                                                                                    when bNoPreoc and
                                                                                         sValDt = Schema_GPSys.OraGPSys.SYS_CURR then
                                                                                      nSaldoSys
                                                                                    else
                                                                                      Schema_GPSys.XchgRates.GetExactSum( nSaldo,
                                                                                                                          HeadData.UNIQCODE,
                                                                                                                          dValior,
                                                                                                                          recExpo.CODVAL,
                                                                                                                          sValDt,
                                                                                                                          Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                                         )
                                                                                  end,
                                                                                  nSaldo,
                                                                                  recExpo.ID_EXPO,
                                                                                  dValior,
                                                                                  dValior,
                                                                                  recExpo.ID_EXPO,
                                                                                  'F',
                                                                                  case
                                                                                    when bNoPreoc then nSaldoSys
                                                                                    else null
                                                                                  end,
                                                                                  sReferenciaA,
                                                                                  null,
                                                                                  0,
                                                                                  null
                                                                                 );
                      else
                        DealOper( DealOper.last )      := Schema_GPSys.tDealOper( Sch_EndSaldo,
                                                                                  recExpo.ID_EXPO,
                                                                                  nSaldo,
                                                                                  case
                                                                                    when bNoPreoc and
                                                                                         sValKt = Schema_GPSys.OraGPSys.SYS_CURR then
                                                                                      nSaldoSys
                                                                                    else
                                                                                      Schema_GPSys.XchgRates.GetExactSum( nSaldo,
                                                                                                                          HeadData.UNIQCODE,
                                                                                                                          dValior,
                                                                                                                          recExpo.CODVAL,
                                                                                                                          sValKt,
                                                                                                                          Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                                                         )
                                                                                  end,
                                                                                  recConf.SALDOKT,
                                                                                  dValior,
                                                                                  dValior,
                                                                                  recExpo.ID_EXPO,
                                                                                  'F',
                                                                                  case
                                                                                    when bNoPreoc then nSaldoSys
                                                                                    else null
                                                                                  end,
                                                                                  sReferenciaP,
                                                                                  null,
                                                                                  0,
                                                                                  null
                                                                                 );
                      end if;

                      bRet          := GenerateMemoOrder( HeadData, DealOper, bPreView, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_System );

                      if ( bRet ) then
                        commit;
                      else
                        rollback;
                      end if;
                    end if;
                  end if;

                  nCurrent  := nCurrent + 1;
                  bRet      := Schema_RA.GPC_RA.ChkStopField( nCurrent, nCurrent );
                  exit when not bRet;
                end loop;

                exit when not bRet;
                ii  := aListFr.next( ii );
              end loop;
            end if;

            exit when not bRet;
          end loop;

          if ( bRet ) then
            SaveEntierPassed( nUniqCode, 'ClearSaldo' );
          end if;

          bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqCode );
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'UNIQCODE';
          aParams( 1 ).ML_VALUE  := to_char( nUniqCode );
          Schema_RA.GPC_RA.RespSetErrorText( 'Неуспешен опит за забрана на счетоводни операции в поделение $UNIQCODE$',
                                             Schema_GPSys.MLng.ctxAccounting,
                                             Schema_GPSys.MLng.lngBG,
                                             aParams
                                            );
        end if;

        exit when not bRet;
      end loop;
    end if;

    if ( bRet ) then
      Schema_RA.GPC_RA.EndTempResponces;
    else
      Schema_RA.GPC_RA.BegTempResponces;
    end if;

    return bRet;
  end CmdYearEndSaldoDo;

  --------------------------------------------------------------------------------
  function CmdClearAllOboroty( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    HeadData    Schema_GPSys.tMemoOrder;
    DealOper    Schema_GPSys.tblDealOper;
    oDoc        Schema_GPSys.DocSysIQType;
    aUniqCodes  Schema_GPSys.OraGPSys.aIntegers;
    sCmdName    varchar2( 64 ) := 'SystemDocument';
    ii          pls_integer;
    jj          pls_integer;
    nOrgOBDT    number;
    nOrgOBKT    number;
    nSysOBDT    number;
    nSysOBKT    number;
    nOrgSum     number;
    nSysSum     number;
    nCurrent    integer := 0;
    nUniqCode   integer;
    dSchDate    date;
    dValior     date;
    dLastDate   date;
    bRet        boolean := true;
    bDummy      boolean;
    bEnd        boolean := true;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_DocSys.DOCSYS_SAVEINIQ.UseQueueBatch3;
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    ii    := aParamEntities3D.first;
    bRet  := ii is not null;

    while ( ii is not null and
           bRet ) loop
      if ( aParamEntities3D( ii ).nRowType = 1 ) then
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                     aRowValues.count >= 3 and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUniqCode ) and
                     Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 2 ), dSchDate ) and
                     Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), dValior );
      elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
        if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) ) then
          bRet  := true;

          if ( aRowValues.count > 0 ) then
            for jj in aRowValues.first .. aRowValues.last loop
              bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( jj ), aUniqCodes( aUniqCodes.count + 1 ) );
              exit when not bRet;
            end loop;
          end if;
        end if;
      end if;

      exit when not bRet;
      ii  := aParamEntities3D.next( ii );
    end loop;

    if ( bRet ) then
      if ( aUniqCodes.count = 0 ) then
        aUniqCodes( aUniqCodes.count + 1 )  := nUniqCode;
      end if;

      for jj in aUniqCodes.first .. aUniqCodes.last loop
        nUniqCode  := aUniqCodes( jj );
        bRet       := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqCode );

        if ( bRet ) then
          DealOper  := Schema_GPSys.tblDealOper( );

          for recExpo in (  select a.ID_EXPO,
                                   a.CODVAL,
                                   a.EXPO_CODE
                              from Schema_GPSys.EXPOSITION a,
                                   EXPO_STATE b
                             where a.UNIQCODE = nUniqCode and
                                   a.ID_EXPO = b.ID_EXPO and
                                   ( b.OBOR_DT != 0 or
                                    b.OBOR_KT != 0 or
                                    b.SYS_OBOR_DT != 0 or
                                    b.SYS_OBOR_KT != 0 )
                          order by 3,
                                   1 ) loop
            select nvl( max( a.SCH_DATE ), dSchDate )
              into dLastDate
              from EXPO_MOVES a
             where a.ID_MOVE = (select max( b.ID_MOVE_LAST )
                                  from Schema_GPSys.EXPO_UNIQCODE_LOG b
                                 where b.ID_EXPO = recExpo.ID_EXPO) and
                   a.ORDROWNUM = 1 and
                   a.DT_KT = 'D';

            if ( dLastDate <= dSchDate ) then
              select nvl( max( a.SCH_DATE ), dSchDate )
                into dLastDate
                from EXPO_MOVES a
               where a.ID_MOVE = (select max( b.ID_MOVE_LAST )
                                    from Schema_GPSys.EXPO_CODVAL_LOG b
                                   where b.ID_EXPO = recExpo.ID_EXPO) and
                     a.ORDROWNUM = 1 and
                     a.DT_KT = 'D';

              if ( dLastDate <= dSchDate ) then
                if ( recExpo.CODVAL = Schema_GPSys.OraGPSys.SYS_CURR ) then
                  nOrgSum  := Expo.ExpoSaldoDate( recExpo.ID_EXPO, dSchDate, false, nOrgOBDT, nOrgOBKT );
                  --
                  nOrgSum  := -least( nOrgOBDT, nOrgOBKT );
                  nSysSum  := null;
                else
                  nOrgSum  := Expo.EAllSaldoDate( recExpo.ID_EXPO, dSchDate, false, nOrgOBDT, nOrgOBKT, nSysOBDT, nSysOBKT );
                  --
                  nOrgSum  := -least( nOrgOBDT, nOrgOBKT );
                  nSysSum  := -least( nSysOBDT, nSysOBKT );
                end if;

                if ( nOrgSum != 0 or
                    nvl( nSysSum, 0 ) != 0 ) then
                  DealOper.extend;
                  DealOper( DealOper.last )      := Schema_GPSys.tDealOper( Sch_ClearOborot,
                                                                            recExpo.ID_EXPO,
                                                                            nOrgSum,
                                                                            nOrgSum,
                                                                            recExpo.ID_EXPO,
                                                                            dValior,
                                                                            dValior,
                                                                            recExpo.ID_EXPO,
                                                                            'F',
                                                                            nSysSum,
                                                                            null,
                                                                            null,
                                                                            0,
                                                                            null
                                                                           );
                end if;
              end if;
            end if;

            if ( DealOper.count > 500 ) then
              savepoint CmdClearAllOboroty_1;
              Schema_DocSys.DOCSYS_SAVEINIQ.nGlobalInputQueue  := nvl( Schema_DocSys.DOCSYS_SAVEINIQ.ChooseInputIQ, Schema_DocSys.DOCSYS_SAVEINIQ.nGlobalInputQueue );
              HeadData                                         := Schema_GPSys.tMemoOrder( null,
                                                                                           nUniqCode,
                                                                                           Schema_GPSys.MLng.Str2( 'Приключване на обороти',
                                                                                                                   Schema_GPSys.MLng.ctxAccounting,
                                                                                                                   Schema_GPSys.MLng.lngBG
                                                                                                                  ),
                                                                                           dSchDate,
                                                                                           null,
                                                                                           null,
                                                                                           null,
                                                                                           null,
                                                                                           null,
                                                                                           null,
                                                                                           sysdate
                                                                                          );
              bRet                                             := GenerateMemoOrder( HeadData, DealOper );

              if ( bRet ) then
                commit;
              else
                Schema_RA.GPC_Tools.WriteErrorMsg( Schema_GPSys.MLng.Str2( 'Приключване на обороти', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ) );
                rollback to CmdClearAllOboroty_1;
              end if;

              DealOper                                         := Schema_GPSys.tblDealOper( );
            end if;

            --
            bEnd      := false;

            if ( mod( nCurrent, 10 ) = 0 ) then
              Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue  := nvl( Schema_DocSys.DOCSYS_SAVEINIQ.ChooseInputIQ, Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue );
            end if;

            nCurrent  := nCurrent + 1;
            bRet      := Schema_RA.GPC_RA.ChkStopField( nCurrent, nCurrent, null, Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue );
            exit when not bRet;
            bEnd      := true;
          end loop;

          if ( bRet and
              bEnd and
              DealOper.count > 0 ) then
            savepoint CmdClearAllOboroty_2;
            HeadData      := Schema_GPSys.tMemoOrder( null,
                                                      nUniqCode,
                                                      Schema_GPSys.MLng.Str2( 'Приключване на обороти', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ),
                                                      dSchDate,
                                                      null,
                                                      null,
                                                      null,
                                                      null,
                                                      null,
                                                      null,
                                                      sysdate
                                                     );
            bRet          := GenerateMemoOrder( HeadData, DealOper );

            if ( bRet ) then
              commit;
            else
              Schema_RA.GPC_Tools.WriteErrorMsg( Schema_GPSys.MLng.Str2( 'Приключване на обороти', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ) );
              rollback to CmdClearAllOboroty_2;
            end if;
          end if;

          if ( bRet ) then
            SaveEntierPassed( nUniqCode, 'ClearAllOborot' );
          end if;

          bDummy    := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqCode );
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'UNIQCODE';
          aParams( 1 ).ML_VALUE  := to_char( nUniqCode );
          Schema_RA.GPC_RA.RespSetErrorText( 'Неуспешен опит за забрана на счетоводни операции в поделение $UNIQCODE$',
                                             Schema_GPSys.MLng.ctxAccounting,
                                             Schema_GPSys.MLng.lngBG,
                                             aParams
                                            );
          Schema_RA.GPC_Tools.WriteErrorMsg( Schema_GPSys.MLng.Str2( 'Приключване на обороти', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ) );
        end if;

        if ( mod( nCurrent, 10 ) = 0 ) then
          Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue  := nvl( Schema_DocSys.DOCSYS_SAVEINIQ.ChooseInputIQ, Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue );
        end if;

        nCurrent   := nCurrent + 1;
        bRet       := Schema_RA.GPC_RA.ChkStopField( nCurrent, nCurrent, null, Schema_DocSys.DocSys_SaveInIQ.nGlobalInputQueue );
        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdClearAllOboroty;

  -------------------------------------------------------------------------------
  function CmdEndSaldoConfSave( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    tSalda      tblSaldaConf;
    tChckSldFr  tblChecked;
    tChckSldTo  tblChecked;
    ii          pls_integer;
    nGroup      integer;
    nCurrent    integer;
    nUniqCode   integer;
    handle      varchar2( 128 );
    bRet        boolean;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи технологията', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    dbms_lock.allocate_unique( 'EndSaldoConf_Lock', handle );
    bRet  := dbms_lock.REQUEST( handle, dbms_lock.X_MODE, 0 ) = 0;

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      ii        := aParamEntities3D.first;
      bRet      := ii is not null;

      while ( ii is not null and
             bRet ) loop
        if ( aParamEntities3D( ii ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       aRowValues.count >= 2 and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nGroup ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nUniqCode );
        elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       aRowValues.count >= 3 and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), tSalda( tSalda.count + 1 ).EXPOCODE ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), tSalda( tSalda.count ).SALDODT ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 3 ), tSalda( tSalda.count ).SALDOKT );

          if ( bRet and
              aRowValues.count >= 7 ) then
            bRet      := Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 4 ), tSalda( tSalda.count ).SALDOFR ) and
                         Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 5 ), tSalda( tSalda.count ).SALDOTO ) and
                         Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 6 ), tChckSldFr( tChckSldFr.count + 1 ) ) and
                         Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 7 ), tChckSldTo( tChckSldTo.count + 1 ) );
          end if;
        end if;

        ii  := aParamEntities3D.next( ii );
      end loop;

      if ( bRet and
          nGroup > 0 and
          nUniqCode > 0 ) then
        delete from END_SALDA_CONF
              where ID_GROUP = nGroup and
                    UNIQCODE = nUniqCode;

        ii  := tSalda.first;

        while ( ii is not null ) loop
          if ( tChckSldFr.count >= ii and
              not tChckSldFr( ii ) ) then
            -- прави се нарочно
            tSalda( ii ).SALDOFR  := null;
          end if;

          if ( tChckSldTo.count >= ii and
              not tChckSldTo( ii ) ) then
            -- прави се нарочно
            tSalda( ii ).SALDOTO  := null;
          end if;

          insert into END_SALDA_CONF(
                        ID_GROUP,
                        UNIQCODE,
                        EXPOCODE,
                        SALDODT,
                        SALDOKT,
                        SALDOFR,
                        SALDOTO
                      )
               values ( nGroup,
                        nUniqCode,
                        tSalda( ii ).EXPOCODE,
                        tSalda( ii ).SALDODT,
                        tSalda( ii ).SALDOKT,
                        tSalda( ii ).SALDOFR,
                        tSalda( ii ).SALDOTO
                       );

          ii  := tSalda.next( ii );
        end loop;

        commit;
      end if;

      nCurrent  := dbms_lock.release( handle );
    end if;

    return bRet;
  end CmdEndSaldoConfSave;

  --------------------------------------------------------------------------------
  function CmdEndSaldoConfFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    ii          pls_integer;
    nGroup      integer;
    nUniqCode   integer;
    sData       varchar2( 4000 );
    bRet        boolean := false;
    cIsSaldoFr  varchar2( 1 );
    cIsSaldoTo  varchar2( 1 );
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    ii  := aParamEntities3D.first;

    if ( ii is not null ) then
      bRet      := aParamEntities3D( ii ).nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                   aRowValues.count >= 2 and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nGroup ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nUniqCode ) and
                   nGroup > 0 and
                   nUniqCode > 0;
    end if;

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      Schema_GPSys.GPC_Parser.RespAddTable( 1 );

      for rec in ( select a.*,
                          b.SCHACCOUNT as SCHACCDT,
                          c.SCHACCOUNT as SCHACCKT
                     from END_SALDA_CONF a,
                          Schema_GPSys.EXPOSITION b,
                          Schema_GPSys.EXPOSITION c
                    where a.UNIQCODE = nUniqCode and
                          a.ID_GROUP = nGroup and
                          b.ID_EXPO = a.SALDODT and
                          c.ID_EXPO = a.SALDOKT ) loop
        sData     := null;

        if ( rec.SALDOFR is null ) then
          cIsSaldoFr  := 'F';
        else
          cIsSaldoFr  := 'T';
        end if;

        if ( rec.SALDOTO is null ) then
          cIsSaldoTo  := 'F';
        else
          cIsSaldoTo  := 'T';
        end if;

        bRet      := Schema_GPSys.GPC_Parser.WriteString( rec.EXPOCODE, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.SALDODT, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.SALDOKT, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( rec.SALDOFR, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( rec.SALDOTO, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( cIsSaldoFr, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( cIsSaldoTo, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rec.SCHACCDT, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rec.SCHACCKT, sData );

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdEndSaldoConfFind;

  --------------------------------------------------------------------------------
  function CmdChkExpo4Olih( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    aDates      Schema_GPSys.Tbl1Date;
    sData       varchar2( 4000 );
    ii          pls_integer;
    nRowType    pls_integer;
    nRegSrok    pls_integer;
    nUniqCode   integer;
    dToDate     date;
    bDummy      boolean;
    bRet        boolean := false;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    ii  := aParamEntities3D.first;

    if ( ii is not null ) then
      nRowType  := aParamEntities3D( ii ).nRowType;
      bRet      := nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                   aRowValues.count >= 2 and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUniqCode ) and
                   Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 2 ), dToDate );

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddTable( 1 );

        for rExpoOlih in (  select *
                              from CURRENT_EXPO
                             where ( nUniqCode = -1 or
                                    UNIQCODE = nUniqCode ) and
                                   STATUS = 'T'
                          order by ID_EXPO ) loop
          bDummy  := CALCLIH.CapitDatesCurrentExpo( rExpoOlih, dToDate, aDates );

          if ( aDates.count > 0 ) then
            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.UNIQCODE, sData ) and
                         Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.ID_EXPO, sData ) and
                         Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.ID_CUST, sData ) and
                         Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.TYPE_EXPO, sData ) and
                         Schema_GPSys.GPC_Parser.WriteDate( aDates( aDates.last ).dDate, sData );

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            end if;
          end if;

          exit when not bRet;
        end loop;

        if ( bRet ) then
          for rExpoOlih in (  select *
                                from DEPOSIT_EXPO
                               where ( nUniqCode = -1 or
                                      UNIQCODE = nUniqCode ) and
                                     STATUS = 'T'
                            order by ID_EXPO ) loop
            bDummy  := CALCLIH.CapitDatesDepositExpo( rExpoOlih, dToDate, aDates, nRegSrok );

            if ( aDates.count > 0 ) then
              sData     := null;
              bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.UNIQCODE, sData ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.ID_EXPO, sData ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.ID_CUST, sData ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( rExpoOlih.TYPE_EXPO, sData ) and
                           Schema_GPSys.GPC_Parser.WriteDate( aDates( aDates.first ).dDate, sData );

              if ( bRet ) then
                Schema_GPSys.GPC_Parser.RespAddRow( sData );
              end if;
            end if;

            exit when not bRet;
          end loop;
        end if;
      end if;
    end if;

    return bRet;
  end CmdChkExpo4Olih;

  ------------------------------------------------------------------------------------------
  function CmdExpoOnHandLoad( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nIDConf     integer;
    nIDCust     integer;
    sData       varchar2( 4000 );
    bLockReq    boolean;
    bRet        boolean := false;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count = 1 ) then
      bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                   aRowValues.count >= 2 and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDConf ) and
                   Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bLockReq ) and
                   nIDConf > 0;
    end if;

    if ( bRet ) then
      if ( bLockReq ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_CONF';
        aParams( 1 ).ML_VALUE  := to_char( nIDConf );
        Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи конфигурация за падежи по сметки No $ID_CONF$',
                                           Schema_GPSys.MLng.ctxAccounting,
                                           Schema_GPSys.MLng.lngBG,
                                           aParams
                                          );
        bRet                   := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoOnHand, nIDConf );
      end if;

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 1 );
        bRet                   := false;
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'ID_CONF';
        aParams( 1 ).ML_VALUE  := to_char( nIDConf );
        Schema_RA.GPC_RA.RespSetErrorText( 'Не са намерени данни за конфигурация за падежи по сметки No $ID_CONF$',
                                           Schema_GPSys.MLng.ctxAccounting,
                                           Schema_GPSys.MLng.lngBG,
                                           aParams
                                          );

        for rec in ( select a.*,
                            b.CODVAL,
                            b.EXPO_NAME,
                            b.IBAN
                       from EXPO_ONHAND a,
                            Schema_GPSys.EXPOSITION b
                      where a.ID_CONF = nIDConf and
                            a.ID_EXPO = b.ID_EXPO ) loop
          Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          nIDCust   := Schema_GPSys.HeadExpo.IDExpo2IDCust( rec.ID_EXPO );
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CONF, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_EXPO, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_NAME, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rec.IBAN, sData ) and
                       Schema_GPSys.GPC_Parser.WriteNumber( rec.CORRECTION, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( rec.USERID, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( nIDCust, sData );

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;
        end loop;

        if ( not bRet and
            bLockReq ) then
          bLockReq  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoOnHand, nIDConf );
        end if;
      end if;
    end if;

    return bRet;
  end CmdExpoOnHandLoad;

  --------------------------------------------------------------------------------
  function CmdExpoOnHandFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nUserID     integer;
    nIDCust     integer;
    sData       varchar2( 4000 );
    bRet        boolean := false;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count = 1 ) then
      bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                   aRowValues.count >= 1 and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUserID ) and
                   nUserID > 0;
    end if;

    if ( bRet ) then
      Schema_GPSys.GPC_Parser.RespAddTable( 1 );
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

      for rec in ( select a.*,
                          b.CODVAL,
                          b.EXPO_NAME,
                          b.BANKACC
                     from EXPO_ONHAND a,
                          Schema_GPSys.EXPOSITION b
                    where a.USERID in (0, nUserID) and
                          a.ID_EXPO = b.ID_EXPO ) loop
        sData     := null;
        nIDCust   := Schema_GPSys.HeadExpo.IDExpo2IDCust( rec.ID_EXPO );
        bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_CONF, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_EXPO, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rec.CODVAL, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_NAME, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rec.BANKACC, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( rec.CORRECTION, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( rec.USERID, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( nIDCust, sData );

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        end if;
      end loop;
    end if;

    return bRet;
  end CmdExpoOnHandFind;

  --------------------------------------------------------------------------------
  function CmdExpoOnHandSave( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nIDConf     integer;
    cOper       varchar2( 10 );
    recData     EXPO_ONHAND%rowtype;
    bDummy      boolean;
    bRet        boolean := false;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count = 1 ) then
      bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                   aRowValues.count >= 5 and
                   Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), cOper ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), recData.ID_CONF ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 3 ), recData.USERID ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), recData.ID_EXPO ) and
                   Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 5 ), recData.CORRECTION ) and
                   recData.USERID >= 0;
    end if;

    if ( bRet ) then
      if ( cOper = 'NEW' ) then
        begin
          select ID_CONF
            into nIDConf
            from EXPO_ONHAND
           where USERID = recData.USERID and
                 ID_EXPO = recData.ID_EXPO;

          bRet                   := false;
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'USERID';
          aParams( 1 ).ML_VALUE  := to_char( recData.USERID );
          aParams( 2 ).ML_NAME   := 'ID_EXPO';
          aParams( 2 ).ML_VALUE  := to_char( recData.ID_EXPO );
          aParams( 3 ).ML_NAME   := 'ID_CONF';
          aParams( 3 ).ML_VALUE  := to_char( nIDConf );
          Schema_RA.GPC_RA.RespSetErrorText( 'Вече има конфигурация за потребител $USERID$ и експозиция $ID_EXPO$ в ред No $ID_CONF$',
                                             Schema_GPSys.MLng.ctxAccounting,
                                             Schema_GPSys.MLng.lngBG,
                                             aParams
                                            );
        exception
          when no_data_found then
            recData.ID_CONF  := Expo.GetExpoNumber( 'IDOnHand' );

            insert into EXPO_ONHAND(
                          ID_CONF,
                          USERID,
                          ID_EXPO,
                          CORRECTION
                        )
                 values ( recData.ID_CONF,
                          recData.USERID,
                          recData.ID_EXPO,
                          recData.CORRECTION
                         );

            commit;
        end;
      elsif ( cOper = 'EDT' ) then
        update EXPO_ONHAND
           set CORRECTION  = recData.CORRECTION
         where ID_CONF = recData.ID_CONF;

        bRet    := sql%rowcount > 0;
        commit;
        bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoOnHand, nIDConf );
      else
        delete from EXPO_ONHAND
              where ID_CONF = recData.ID_CONF;

        commit;
        bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeExpoOnHand, nIDConf );
      end if;
    end if;

    return bRet;
  end CmdExpoOnHandSave;

  --------------------------------------------------------------------------------
  function CmdCorrectPlanLihvi( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    HeadData    Schema_GPSys.tMemoOrder;
    DealOper    Schema_GPSys.TDealOper;
    MemoRows    Schema_GPSys.tblDealOper;
    RecPlanL    Calclih.tblPlanLihvi;
    cCodValKt   Schema_GPSys.EXPOSITION.CODVAL%type;
    cCodValDt   Schema_GPSys.EXPOSITION.CODVAL%type;
    cCodVal     Schema_GPSys.EXPOSITION.CODVAL%type;
    sData       varchar2( 2000 );
    bActive     boolean;
    bStorno     boolean;
    bRet        boolean := false;
    nAmount     number;
    dValior     date;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count = 1 ) then
      HeadData  := Schema_GPSys.tMemoOrder( null, null, null, null, null, null, null, null, null, null, sysdate );
      DealOper  := Schema_GPSys.TDealOper( null, null, null, null, null, null, null, null, null, null, null, null, null, null );
      bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                   aRowValues.count >= 10 and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), HeadData.UNIQCODE ) and
                   Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bActive ) and
                   Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 3 ), bStorno ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), RecPlanL( 1 ).ID_EXPO ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 5 ), DealOper.EXPO_DT ) and
                   Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 6 ), nAmount ) and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 7 ), DealOper.EXPO_KT ) and
                   Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 8 ), HeadData.SCH_DATE ) and
                   Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 9 ), dValior ) and
                   Schema_GPSys.GPC_Parser.ReadString( aRowValues( 10 ), HeadData.ORD_TEXT ) and
                   ( aRowValues.count < 11 or
                    Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 11 ), HeadData.ID_MOVE ) ) and
                   ( aRowValues.count < 12 or
                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 12 ), RecPlanL( 1 ).ISMANUAL ) ) and
                   RecPlanL( 1 ).ID_EXPO > 0;

      if ( bRet ) then
        if ( not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 16 ) ) then
          bRet  := not bStorno;

          if ( not bRet ) then
            Schema_RA.GPC_RA.RespSetErrorText( 'Вие нямате право за сторниране на разчетирани лихви',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG
                                              );
          end if;
        end if;

        if ( bRet and
            nvl( HeadData.ID_MOVE, 0 ) > 0 ) then
          bRet  := Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 20 );

          if ( not bRet ) then
            Schema_RA.GPC_RA.RespSetErrorText( 'Вие нямате право за маркиране на ръчно регистрирани ТНЛ, за осчетоводени със стар МО',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG
                                              );
          end if;
        end if;

        if ( bRet ) then
          HeadData.SYS_TEXT  := Schema_GPSys.MLng.Str2( 'Корекции по разчетиране лихви', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
          cCodVal            := Schema_GPSys.HeadExpo.IDExpo2CodVal( RecPlanL( 1 ).ID_EXPO );
          cCodValDt          := Schema_GPSys.HeadExpo.IDExpo2CodVal( DealOper.EXPO_DT );
          cCodValKt          := Schema_GPSys.HeadExpo.IDExpo2CodVal( DealOper.EXPO_KT );
          --
          bRet               := ( not bActive ) or
                                cCodValKt = Schema_GPSys.OraGPSys.SYS_CURR;

          if ( bRet ) then
            bRet      := bActive or
                         cCodValDt = Schema_GPSys.OraGPSys.SYS_CURR;

            if ( bRet ) then
              bRet      := ( not bActive ) or
                           cCodValDt = cCodVal;

              if ( bRet ) then
                bRet      := bActive or
                             cCodValKt = cCodVal;

                if ( not bRet ) then
                  aParams.delete;
                  aParams( 1 ).ML_NAME   := 'EXPO_KT';
                  aParams( 1 ).ML_VALUE  := to_char( DealOper.EXPO_KT );
                  aParams( 2 ).ML_NAME   := 'ID_EXPO';
                  aParams( 2 ).ML_VALUE  := to_char( RecPlanL( 1 ).ID_EXPO );
                  Schema_RA.GPC_RA.RespSetErrorText( 'Различни валути на експозиция $EXPO_KT$ и експозиция $ID_EXPO$',
                                                     Schema_GPSys.MLng.ctxAccounting,
                                                     Schema_GPSys.MLng.lngBG,
                                                     aParams
                                                    );
                end if;
              else
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'EXPO_DT';
                aParams( 1 ).ML_VALUE  := to_char( DealOper.EXPO_DT );
                aParams( 2 ).ML_NAME   := 'ID_EXPO';
                aParams( 2 ).ML_VALUE  := to_char( RecPlanL( 1 ).ID_EXPO );
                Schema_RA.GPC_RA.RespSetErrorText( 'Различни валути на експозиция $EXPO_DT$ и експозиция $ID_EXPO$',
                                                   Schema_GPSys.MLng.ctxAccounting,
                                                   Schema_GPSys.MLng.lngBG,
                                                   aParams
                                                  );
              end if;
            else
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'EXPO_DT';
              aParams( 1 ).ML_VALUE  := to_char( DealOper.EXPO_DT );
              Schema_RA.GPC_RA.RespSetErrorText( 'Некоректнa валута на експозиция $EXPO_DT$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
            end if;
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'EXPO_KT';
            aParams( 1 ).ML_VALUE  := to_char( DealOper.EXPO_KT );
            Schema_RA.GPC_RA.RespSetErrorText( 'Некоректнa валута на експозиция $EXPO_KT$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
          end if;

          if ( bRet ) then
            DealOper.DEAL_TYPE            := Sch_PlanLihvi;
            DealOper.VALIOR_DT            := dValior;
            DealOper.VALIOR_KT            := dValior;
            RecPlanL( 1 ).STATUS          := CalcLih.Lihvi_Confirmed;
            RecPlanL( 1 ).VALIOR          := dValior;

            if ( bActive ) then
              RecPlanL( 1 ).EXPO_RAZCHET  := DealOper.EXPO_DT;
              RecPlanL( 1 ).EXPO_REZULT   := DealOper.EXPO_KT;

              if ( not bStorno ) then
                DealOper.AMOUNT_DT    := nAmount;
                RecPlanL( 1 ).NDELTA  := -nAmount;
              else
                DealOper.AMOUNT_DT    := -nAmount;
                RecPlanL( 1 ).NDELTA  := nAmount;
              end if;

              DealOper.AMOUNT_KT          := Schema_GPSys.XchgRates.GetExactSum( DealOper.AMOUNT_DT, HeadData.UNIQCODE, dValior, cCodValDt, cCodValKt, Schema_GPSys.XchgRates.XchgRateType_Fixing );
            else
              RecPlanL( 1 ).EXPO_RAZCHET  := DealOper.EXPO_KT;
              RecPlanL( 1 ).EXPO_REZULT   := DealOper.EXPO_DT;

              if ( not bStorno ) then
                DealOper.AMOUNT_KT    := nAmount;
                RecPlanL( 1 ).NDELTA  := nAmount;
              else
                DealOper.AMOUNT_KT    := -nAmount;
                RecPlanL( 1 ).NDELTA  := -nAmount;
              end if;

              DealOper.AMOUNT_DT          := Schema_GPSys.XchgRates.GetExactSum( DealOper.AMOUNT_KT, HeadData.UNIQCODE, dValior, cCodValKt, cCodValDt, Schema_GPSys.XchgRates.XchgRateType_Fixing );
            end if;

            RecPlanL( 1 ).NDELTA_SYS      := Schema_GPSys.XchgRates.GetExactSum( RecPlanL( 1 ).NDELTA,
                                                                                 HeadData.UNIQCODE,
                                                                                 dValior,
                                                                                 Schema_GPSys.HeadExpo.IDExpo2CodVal( RecPlanL( 1 ).ID_EXPO ),
                                                                                 Schema_GPSys.OraGPSys.SYS_CURR,
                                                                                 Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                                );
          end if;

          if ( nvl( HeadData.ID_MOVE, 0 ) = 0 ) then
            MemoRows                   := Schema_GPSys.tblDealOper( );
            MemoRows.extend;
            MemoRows( MemoRows.last )  := DealOper;
            bRet                       := GenerateMemoOrder( HeadData, MemoRows );
          end if;

          if ( bRet ) then
            RecPlanL( 1 ).ID_PLAN_LIH  := calclih.GetLihviNumber( 'PLANLIH' );
            RecPlanL( 1 ).ISMANUAL     := nvl( RecPlanL( 1 ).ISMANUAL, 'T' );

            insert into LIHVI_PLANLIH(
                          ID_PLAN_LIH,
                          ID_EXPO,
                          VALIOR,
                          NDELTA,
                          EXPO_RAZCHET,
                          STATUS,
                          EXPO_REZULT,
                          NDELTA_SYS,
                          ISMANUAL
                        )
                 values ( RecPlanL( 1 ).ID_PLAN_LIH,
                          RecPlanL( 1 ).ID_EXPO,
                          RecPlanL( 1 ).VALIOR,
                          RecPlanL( 1 ).NDELTA,
                          RecPlanL( 1 ).EXPO_RAZCHET,
                          RecPlanL( 1 ).STATUS,
                          RecPlanL( 1 ).EXPO_REZULT,
                          RecPlanL( 1 ).NDELTA_SYS,
                          RecPlanL( 1 ).ISMANUAL
                         );

            bRet                       := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypePlanLih, RecPlanL( 1 ).ID_PLAN_LIH );

            if ( bRet ) then
              bRet  := CalcLih.SavePlanLihva( RecPlanL, HeadData );
            else
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'ID_PLAN_LIH';
              aParams( 1 ).ML_VALUE  := to_char( RecPlanL( 1 ).ID_PLAN_LIH );
              Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи запис за разчетиране на лихви $ID_PLAN_LIH$',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;
          end if;

          if ( bRet ) then
            commit;
            Schema_GPSys.GPC_Parser.RespAddArray( 1 );
            bRet  := Schema_GPSys.GPC_Parser.WriteInteger( HeadData.ID_MOVE, sData );

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            end if;
          else
            rollback;
          end if;
        end if;
      end if;
    end if;

    return bRet;
  end CmdCorrectPlanLihvi;

  --------------------------------------------------------------------------------
  function CmdMoveCustProducts( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    ii          pls_integer;
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nIDCustFr   integer;
    nIDCustTo   integer;
    nIDLoan     integer;
    bRet        boolean := false;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    ii  := aParamEntities3D.first;

    if ( ii is not null ) then
      if ( aParamEntities3D( ii ).nRowType = 1 ) then
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                     aRowValues.count >= 2 and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDCustFr ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nIDCustTo ) and
                     nvl( nIDCustFr, 0 ) > 0 and
                     nvl( nIDCustTo, 0 ) > 0 and
                     nIDCustFr != nIDCustTo;
        bRet      := bRet and
                     Cmd_Expo_Add2.MoveCustProducts( 1, nIDCustFr, nIDCustTo );
      elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                     aRowValues.count >= 2 and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDLoan ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nIDCustTo ) and
                     nvl( nIDLoan, 0 ) > 0 and
                     nvl( nIDCustTo, 0 ) > 0;
        bRet      := bRet and
                     Cmd_Expo_Add2.MoveCustLoan( nIDLoan, nIDCustTo );
      end if;

      if ( bRet ) then
        commit;
      else
        rollback;
      end if;
    end if;

    return bRet;
  end CmdMoveCustProducts;

  --------------------------------------------------------------------------------
  function HierarchySaveMemOrder(
    aIDMoves     in out nocopy Schema_GPSys.OraGPSys.aIntegers,
    nUniqCodeDt  in            integer,
    nIdExpoDt    in            integer,
    nSumDt       in            number,
    dValiorDt    in            date,
    nUniqCodeKt  in            integer,
    nIdExpoKt    in            integer,
    nSumKt       in            number,
    dValiorKt    in            date,
    dSchDate     in            date,
    sOsnovanie   in            varchar2,
    nSumRazchet  in            number,
    sValRazchet  in            varchar2,
    sReferencia  in            varchar2,
    nSumSys      in            number default null,
    nDealType    in            integer default Sch_Free,
    BdgOpers     in            tblBdgOpers default tBdgOpers,
    AddOpers     in            tblAddOpers default tAddOpers,
    sTechnoKt    in            varchar2 default null,
    bSaveGroup   in            boolean default true,
    sOrigin      in            varchar2 default null,
    CostOpers    in            Schema_GPSys.tblCostOpers default tCostOpers,
    RegTaxes     in            Taxes.tblRegTaxes default Taxes.tRegTaxes,
    nIDCust      in            integer default null
  )
    return boolean is
    cursor qGetMaster( nSlave in integer ) is
      ( select UCODE_MASTER
          from Schema_GPSys.PODELENIA_CONF
         where UCODE_SLAVE = nSlave );

    HeadData1      Schema_GPSys.tMemoOrder;
    DealOper1      Schema_GPSys.tblDealOper;
    aListFr        Schema_GPSys.OraGPSys.aStrings;
    aListTo        Schema_GPSys.OraGPSys.aStrings;
    aUniqsDt       Schema_GPSys.OraGPSys.aNumbers;
    aUniqsKt       Schema_GPSys.OraGPSys.aNumbers;
    cReferDt       EXPO_MOVES.REFERENCIA%type;
    cReferKt       EXPO_MOVES.REFERENCIA%type;
    cRefer         EXPO_MOVES.REFERENCIA%type;
    nIdExpoOut     integer;
    nIdExpoIn      integer;
    nPosDt         integer := 0;
    nPosKt         integer := 0;
    nMoveFr        integer := 0;
    nMoveTo        integer := 0;
    nHeadUniq      integer;
    nIDExpo4Zapor  integer;
    nUCodeDt       integer;
    nUCodeKt       integer;
    nDiffPos       integer;
    sCodValIn      varchar2( 3 );
    sCodValOut     varchar2( 3 );
    bRet           boolean := false;
    bDown          boolean := false;
    bParentDt      boolean := true;
    aParams        Schema_RA.GPC_RA.tblErrParams;
  begin
    cRefer                          := sReferencia;
    nUCodeDt                        := nUniqCodeDt;
    nUCodeKt                        := nUniqCodeKt;
    aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
    aUniqsKt( aUniqsKt.count + 1 )  := nUCodeKt;

    if ( nUniqCodeDt = nUniqCodeKt or
        not Expo.IsSystemHaveBalances ) then
      DealOper1                    := Schema_GPSys.tblDealOper( );
      HeadData1                    := Schema_GPSys.tMemoOrder( null, nUniqCodeDt, sOsnovanie, dSchDate, null, null, nIDCust, null, null, sOrigin, sysdate );
      DealOper1.extend;
      DealOper1( DealOper1.last )  := Schema_GPSys.tDealOper( nDealType, nIdExpoDt, nSumDt, nSumKt, nIdExpoKt, dValiorDt, dValiorKt, nIdExpoDt, 'F', nSumSys, cRefer, null, 0, null );
      bRet                         := GenerateMemoOrder( HeadData1, DealOper1, false, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, true, false, null, BdgOpers, AddOpers, CostOpers, RegTaxes );

      if ( bRet ) then
        aIDMoves( aIDMoves.count + 1 )  := HeadData1.ID_MOVE;
      end if;
    else
      Schema_RA.GPC_RA.RespSetErrorText( 'Грешка, няма връзка между избраните поделения', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

      if ( Schema_GPSys.OraGPSys.SplitRanges( cRefer, aListFr, aListTo, false ) ) then
        if ( aListFr.count = 1 ) then
          cReferDt  := aListFr( 1 );
          cReferKt  := aListFr( 1 );
        elsif ( aListFr.count >= 2 ) then
          cReferDt  := aListFr( 1 );
          cReferKt  := aListFr( 2 );
        end if;

        if ( aListFr.count >= 3 ) then
          cReferDt  := nvl( cReferDt, ';' ) || ';' || aListFr( 3 ) || '-' || aListTo( 3 );
          cReferKt  := nvl( cReferKt, ';' ) || ';' || nvl( sTechnoKt, aListFr( 3 ) || '-' || aListTo( 3 ) );
        end if;
      end if;

      loop
        if ( nUCodeKt != -1 ) then
          open qGetMaster( nUCodeKt );

          nUCodeKt  := null;

          fetch qGetMaster
            into nUCodeKt;

          close qGetMaster;

          nUCodeKt  := nvl( nUCodeKt, -1 );

          if ( not bDown ) then
            bDown  := nUCodeKt = nUniqCodeDt;
          end if;
        end if;

        if ( nUCodeDt != -1 ) then
          open qGetMaster( nUCodeDt );

          nUCodeDt  := null;

          fetch qGetMaster
            into nUCodeDt;

          close qGetMaster;

          nUCodeDt  := nvl( nUCodeDt, -1 );
        end if;

        if ( nUCodeDt != nUCodeKt ) then
          if ( nUCodeKt != -1 ) then
            nPosDt  := Schema_GPSys.OraGPSys.AScan( aUniqsDt, nUCodeKt );
          end if;

          if ( nPosDt = 0 and
              nUCodeDt != -1 ) then
            nPosKt  := Schema_GPSys.OraGPSys.AScan( aUniqsKt, nUCodeDt );
          end if;

          if ( nPosDt = 0 and
              nPosKt = 0 ) then
            if ( nUCodeDt != -1 ) then
              aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
            end if;

            if ( nUCodeKt != -1 ) then
              aUniqsKt( aUniqsKt.count + 1 )  := nUCodeKt;
            end if;
          else
            bRet  := true;
            exit;
          end if;
        else
          if ( nUCodeDt != -1 ) then
            aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
            nPosDt                          := aUniqsDt.count;
            bRet                            := true;
          end if;

          exit;
        end if;
      end loop;

      if ( bRet ) then
        nHeadUniq  := Schema_RA.GPC_Tools.GetHeadUniqCode( );

        if ( nSumKt > 0 and
            Schema_GPSys.HeadExpo.IsItCashExpo( nIdExpoDt ) and
            Schema_GPSys.HeadExpo.ChkCashExpo( nUniqCodeDt, nIdExpoDt, 2, nIDExpo4Zapor ) and
            nvl( Schema_GPSys.HeadExpo.IDExpo2IDCust( nIdExpoKt ), 0 ) > 0 and
            Schema_GPSys.HeadExpo.IsItPasiveExpo( nIdExpoKt ) ) then
          nIDExpo4Zapor  := nIdExpoKt;
        else
          nIDExpo4Zapor  := null;
        end if;

        if ( nPosDt = 0 ) then
          nPosDt     := aUniqsDt.count;
          bParentDt  := false;
        end if;

        for jj in 1 .. nPosDt loop
          if ( ( jj = 1 or
                jj != nPosDt or
                not bParentDt ) and
              aUniqsDt( jj ) != nHeadUniq and
              not bDown ) then
            bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Master', null, to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                                      sCodValOut = sValRazchet;
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'UNIQ_DT';
            aParams( 1 ).ML_VALUE  := aUniqsDt( jj );
            aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
            aParams( 2 ).ML_VALUE  := sValRazchet;
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_DT$ Master $VAL_RAZCHET$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
          else
            bRet                   := bRet and
                                      Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsKt( aUniqsKt.count ), to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                                      sCodValOut = sValRazchet;
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'UNIQ_DT';
            aParams( 1 ).ML_VALUE  := aUniqsDt( jj );
            aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
            aParams( 2 ).ML_VALUE  := sValRazchet;
            aParams( 3 ).ML_NAME   := 'UNIQ_KT';
            aParams( 3 ).ML_VALUE  := aUniqsKt( aUniqsKt.count );
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_DT$  Slave $VAL_RAZCHET$ $UNIQ_KT$',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;

          if ( jj > 1 ) then
            bRet                   := bRet and
                                      Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Slave', nUCodeDt, to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                                      sCodValIn = sValRazchet;
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'UNIQ_DT';
            aParams( 1 ).ML_VALUE  := aUniqsDt( jj );
            aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
            aParams( 2 ).ML_VALUE  := sValRazchet;
            aParams( 3 ).ML_NAME   := 'UNIQCODE_DT';
            aParams( 3 ).ML_VALUE  := to_char( nUCodeDt );
            Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_DT$  Slave $VAL_RAZCHET$ $UNIQCODE_DT$',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;

          if ( bRet ) then
            DealOper1  := Schema_GPSys.tblDealOper( );
            HeadData1  := Schema_GPSys.tMemoOrder( null, aUniqsDt( jj ), sOsnovanie, dSchDate, null, null, nIDCust, null, null, sOrigin, sysdate );

            if ( HeadData1.UniqCode = nUniqCodeDt ) then
              cRefer  := cReferDt;
            elsif ( HeadData1.UniqCode = nUniqCodeKt ) then
              cRefer  := cReferKt;
            else
              cRefer  := null;
            end if;

            DealOper1.extend;

            if ( jj = 1 ) then
              DealOper1( DealOper1.last )  := Schema_GPSys.tDealOper( nDealType, nIdExpoDt, nSumDt, nSumRazchet, nIdExpoOut, dValiorDt, dValiorKt, nIdExpoDt, 'F', nSumSys, cRefer, null, 0, null );
            else
              DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                          nIdExpoIn,
                                                                          nSumRazchet,
                                                                          nSumRazchet,
                                                                          nIdExpoOut,
                                                                          dValiorKt,
                                                                          dValiorKt,
                                                                          nIdExpoIn,
                                                                          'F',
                                                                          nSumSys,
                                                                          cRefer,
                                                                          null,
                                                                          0,
                                                                          null
                                                                         );
            end if;

            if ( jj = 1 ) then
              bRet  := GenerateMemoOrder( HeadData1, DealOper1, false, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, true, false, nIDExpo4Zapor, BdgOpers, tAddOpers, CostOpers, RegTaxes );
            else
              bRet  := GenerateMemoOrder( HeadData1, DealOper1 );
            end if;

            if ( bRet ) then
              aIDMoves( aIDMoves.count + 1 )  := HeadData1.ID_MOVE;

              if ( jj = 1 ) then
                nMoveFr  := HeadData1.ID_MOVE;
              end if;
            end if;
          end if;

          nUCodeDt  := aUniqsDt( jj );
          exit when not bRet;
        end loop;

        if ( bRet ) then
          if ( nPosKt = 0 ) then
            nPosKt  := aUniqsKt.count;
          end if;

          for jj in reverse 1 .. nPosKt loop
            if ( ( jj < nPosKt or
                  bParentDt ) and
                aUniqsKt( jj ) != nHeadUniq ) then
              bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Master', null, to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                                        sCodValIn = sValRazchet;
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'UNIQ_KT';
              aParams( 1 ).ML_VALUE  := aUniqsKt( jj );
              aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
              aParams( 2 ).ML_VALUE  := sValRazchet;
              Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_KT$ Master $VAL_RAZCHET$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
            else
              bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsDt( aUniqsDt.count ), to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                                        sCodValIn = sValRazchet;
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'UNIQ_KT';
              aParams( 1 ).ML_VALUE  := aUniqsKt( jj );
              aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
              aParams( 2 ).ML_VALUE  := sValRazchet;
              aParams( 3 ).ML_NAME   := 'UNIQ_DT';
              aParams( 3 ).ML_VALUE  := aUniqsDt( aUniqsDt.count );
              Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_KT$ Slave $VAL_RAZCHET$ $UNIQ_DT$',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;

            if ( jj != 1 ) then
              bRet                   := bRet and
                                        Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsKt( jj - 1 ), to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                                        sCodValOut = sValRazchet;
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'UNIQ_KT';
              aParams( 1 ).ML_VALUE  := aUniqsKt( jj );
              aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
              aParams( 2 ).ML_VALUE  := sValRazchet;
              aParams( 3 ).ML_NAME   := 'UNIQ_KT2';
              aParams( 3 ).ML_VALUE  := aUniqsKt( jj - 1 );
              Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_KT$  Slave $VAL_RAZCHET$ $UNIQ_KT2$',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;

            if ( bRet ) then
              DealOper1  := Schema_GPSys.tblDealOper( );
              HeadData1  := Schema_GPSys.tMemoOrder( null, aUniqsKt( jj ), sOsnovanie, dSchDate, null, null, nIDCust, null, null, sOrigin, sysdate );

              if ( HeadData1.UniqCode = nUniqCodeDt ) then
                cRefer  := cReferDt;
              elsif ( HeadData1.UniqCode = nUniqCodeKt ) then
                cRefer  := cReferKt;
              else
                cRefer  := null;
              end if;

              DealOper1.extend;

              if ( jj = 1 ) then
                DealOper1( DealOper1.last )  := Schema_GPSys.tDealOper( nDealType, nIdExpoIn, nSumRazchet, nSumKt, nIdExpoKt, dValiorKt, dValiorKt, nIdExpoKt, 'F', nSumSys, cRefer, null, 0, null );
              else
                DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                            nIdExpoIn,
                                                                            nSumRazchet,
                                                                            nSumRazchet,
                                                                            nIdExpoOut,
                                                                            dValiorKt,
                                                                            dValiorKt,
                                                                            nIdExpoIn,
                                                                            'F',
                                                                            nSumSys,
                                                                            cRefer,
                                                                            null,
                                                                            0,
                                                                            null
                                                                           );
              end if;

              bRet       := GenerateMemoOrder( HeadData1, DealOper1 );

              if ( bRet ) then
                aIDMoves( aIDMoves.count + 1 )  := HeadData1.ID_MOVE;

                if ( jj = 1 ) then
                  nMoveTo  := HeadData1.ID_MOVE;
                end if;
              end if;
            end if;

            exit when not bRet;
          end loop;
        end if;

        bRet       := bRet and
                      ( not bSaveGroup or
                       Expo.SaveGroupIdMoves( aIDMoves ) );

        if ( bRet and
            nMoveFr > 0 and
            nMoveTo > 0 ) then
          insert into EXPO_REL_MOVES(
                        ID_MOVE_FR,
                        ID_MOVE_TO
                      )
               values ( nMoveFr,
                        nMoveTo
                       );
        end if;
      end if;
    end if;

    return bRet;
  end HierarchySaveMemOrder;

  --------------------------------------------------------------------------------
  function HierarchySaveSchDeals(
    aIDMoves     in out nocopy Schema_GPSys.OraGPSys.aIntegers,
    nUniqCodeDt  in            integer,
    nUniqCodeKt  in            integer,
    dSchDate     in            date,
    sOsnovanie   in            varchar2,
    sValRazchet  in            varchar2,
    SchDeals     in            tSchDeals,
    nDealType    in            integer default Sch_Free
  )
    return boolean is
    cursor qGetMaster( nSlave in integer ) is
      ( select UCODE_MASTER
          from Schema_GPSys.PODELENIA_CONF
         where UCODE_SLAVE = nSlave );

    HeadData1      Schema_GPSys.tMemoOrder;
    DealOper1      Schema_GPSys.tblDealOper;
    aListFr        Schema_GPSys.OraGPSys.aStrings;
    aListTo        Schema_GPSys.OraGPSys.aStrings;
    aUniqsDt       Schema_GPSys.OraGPSys.aNumbers;
    aUniqsKt       Schema_GPSys.OraGPSys.aNumbers;
    cReferDt       EXPO_MOVES.REFERENCIA%type;
    cReferKt       EXPO_MOVES.REFERENCIA%type;
    cRefer         EXPO_MOVES.REFERENCIA%type;
    nIdExpoOut     integer;
    nIdExpoIn      integer;
    nPosDt         integer := 0;
    nPosKt         integer := 0;
    nHeadUniq      integer;
    nUCodeDt       integer;
    nUCodeKt       integer;
    nSchD_UCodeDt  integer;
    nSchD_UCodeKt  integer;
    nDiffPos       integer;
    sCodValIn      varchar2( 3 );
    sCodValOut     varchar2( 3 );
    bRet           boolean := false;
    bDown          boolean := false;
    bParentDt      boolean := true;
    aParams        Schema_RA.GPC_RA.tblErrParams;
  begin
    if ( SchDeals.count > 0 ) then
      savepoint HierarchySaveSchDeals;
      nUCodeDt                        := nUniqCodeDt;
      nUCodeKt                        := nUniqCodeKt;
      aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
      aUniqsKt( aUniqsKt.count + 1 )  := nUCodeKt;

      if ( nUniqCodeDt = nUniqCodeKt or
          not Expo.IsSystemHaveBalances ) then
        DealOper1  := Schema_GPSys.tblDealOper( );
        HeadData1  := Schema_GPSys.tMemoOrder( null, nUniqCodeDt, sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );

        for ii in SchDeals.first .. SchDeals.last loop
          DealOper1.extend;
          cRefer                           := SchDeals( ii ).sReferencia;
          DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                      SchDeals( ii ).nIdExpoDt,
                                                                      SchDeals( ii ).nSumDt,
                                                                      SchDeals( ii ).nSumKt,
                                                                      SchDeals( ii ).nIdExpoKt,
                                                                      SchDeals( ii ).dValiorDt,
                                                                      SchDeals( ii ).dValiorKt,
                                                                      SchDeals( ii ).nIdExpoDt,
                                                                      'F',
                                                                      SchDeals( ii ).nSumSys,
                                                                      cRefer,
                                                                      null,
                                                                      0,
                                                                      null
                                                                     );
        end loop;

        bRet       := GenerateMemoOrder( HeadData1, DealOper1 );

        if ( bRet ) then
          aIDMoves( aIDMoves.count + 1 )  := HeadData1.ID_MOVE;
        end if;
      else
        Schema_RA.GPC_RA.RespSetErrorText( 'Грешка, няма връзка между избраните поделения', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

        loop
          if ( nUCodeKt != -1 ) then
            open qGetMaster( nUCodeKt );

            nUCodeKt  := null;

            fetch qGetMaster
              into nUCodeKt;

            close qGetMaster;

            nUCodeKt  := nvl( nUCodeKt, -1 );

            if ( not bDown ) then
              bDown  := nUCodeKt = nUniqCodeDt;
            end if;
          end if;

          if ( nUCodeDt != -1 ) then
            open qGetMaster( nUCodeDt );

            nUCodeDt  := null;

            fetch qGetMaster
              into nUCodeDt;

            close qGetMaster;

            nUCodeDt  := nvl( nUCodeDt, -1 );
          end if;

          if ( nUCodeDt != nUCodeKt ) then
            if ( nUCodeKt != -1 ) then
              nPosDt  := Schema_GPSys.OraGPSys.AScan( aUniqsDt, nUCodeKt );
            end if;

            if ( nPosDt = 0 and
                nUCodeDt != -1 ) then
              nPosKt  := Schema_GPSys.OraGPSys.AScan( aUniqsKt, nUCodeDt );
            end if;

            if ( nPosDt = 0 and
                nPosKt = 0 ) then
              if ( nUCodeDt != -1 ) then
                aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
              end if;

              if ( nUCodeKt != -1 ) then
                aUniqsKt( aUniqsKt.count + 1 )  := nUCodeKt;
              end if;
            else
              bRet  := true;
              exit;
            end if;
          else
            if ( nUCodeDt != -1 ) then
              aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
              nPosDt                          := aUniqsDt.count;
              bRet                            := true;
            end if;

            exit;
          end if;
        end loop;

        if ( bRet ) then
          nHeadUniq  := Schema_RA.GPC_Tools.GetHeadUniqCode( );

          if ( nPosDt = 0 ) then
            nPosDt     := aUniqsDt.count;
            bParentDt  := false;
          end if;

          for jj in 1 .. nPosDt loop
            if ( ( jj = 1 or
                  jj != nPosDt or
                  not bParentDt ) and
                aUniqsDt( jj ) != nHeadUniq and
                not bDown ) then
              bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Master', null, to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                                        sCodValOut = sValRazchet;
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'UNIQ_DT';
              aParams( 1 ).ML_VALUE  := aUniqsDt( jj );
              aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
              aParams( 2 ).ML_VALUE  := sValRazchet;
              Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_DT$ Master $VAL_RAZCHET$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
            else
              bRet                   := bRet and
                                        Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsKt( aUniqsKt.count ), to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                                        sCodValOut = sValRazchet;
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'UNIQ_DT';
              aParams( 1 ).ML_VALUE  := aUniqsDt( jj );
              aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
              aParams( 2 ).ML_VALUE  := sValRazchet;
              aParams( 3 ).ML_NAME   := 'UNIQ_KT';
              aParams( 3 ).ML_VALUE  := aUniqsKt( aUniqsKt.count );
              Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_DT$  Slave $VAL_RAZCHET$ $UNIQ_KT$',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;

            if ( jj > 1 ) then
              bRet                   := bRet and
                                        Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Slave', nUCodeDt, to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                                        sCodValIn = sValRazchet;
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'UNIQ_DT';
              aParams( 1 ).ML_VALUE  := aUniqsDt( jj );
              aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
              aParams( 2 ).ML_VALUE  := sValRazchet;
              aParams( 3 ).ML_NAME   := 'UNIQCODE_DT';
              aParams( 3 ).ML_VALUE  := to_char( nUCodeDt );
              Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_DT$  Slave $VAL_RAZCHET$ $UNIQCODE_DT$',
                                                 Schema_GPSys.MLng.ctxAccounting,
                                                 Schema_GPSys.MLng.lngBG,
                                                 aParams
                                                );
            end if;

            if ( bRet ) then
              DealOper1  := Schema_GPSys.tblDealOper( );
              HeadData1  := Schema_GPSys.tMemoOrder( null, aUniqsDt( jj ), sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );

              for ii in SchDeals.first .. SchDeals.last loop
                cRefer  := SchDeals( ii ).sReferencia;

                if ( Schema_GPSys.OraGPSys.SplitRanges( cRefer, aListFr, aListTo, false ) ) then
                  if ( aListFr.count = 1 ) then
                    cReferDt  := aListFr( 1 );
                    cReferKt  := aListFr( 1 );
                  elsif ( aListFr.count >= 2 ) then
                    cReferDt  := aListFr( 1 );
                    cReferKt  := aListFr( 2 );
                  end if;
                end if;

                if ( HeadData1.UniqCode = nUniqCodeDt ) then
                  cRefer  := cReferDt;
                elsif ( HeadData1.UniqCode = nUniqCodeKt ) then
                  cRefer  := cReferKt;
                else
                  cRefer  := null;
                end if;

                select UNIQCODE
                  into nSchD_UCodeDt
                  from Schema_GPSys.EXPOSITION
                 where ID_EXPO = SchDeals( ii ).nIdExpoDt;

                select UNIQCODE
                  into nSchD_UCodeKt
                  from Schema_GPSys.EXPOSITION
                 where ID_EXPO = SchDeals( ii ).nIdExpoKt;

                if ( nSchD_UCodeDt = nSchD_UCodeKt ) then
                  if ( nSchD_UCodeDt = aUniqsDt( jj ) ) then
                    DealOper1.extend;
                    DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                SchDeals( ii ).nIdExpoDt,
                                                                                SchDeals( ii ).nSumDt,
                                                                                SchDeals( ii ).nSumKt,
                                                                                SchDeals( ii ).nIdExpoKt,
                                                                                SchDeals( ii ).dValiorDt,
                                                                                SchDeals( ii ).dValiorKt,
                                                                                SchDeals( ii ).nIdExpoDt,
                                                                                'F',
                                                                                SchDeals( ii ).nSumSys,
                                                                                cRefer,
                                                                                null,
                                                                                0,
                                                                                null
                                                                               );
                  end if;
                else
                  DealOper1.extend;

                  if ( jj = 1 ) then
                    DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                SchDeals( ii ).nIdExpoDt,
                                                                                SchDeals( ii ).nSumDt,
                                                                                SchDeals( ii ).nSumRazchet,
                                                                                nIdExpoOut,
                                                                                SchDeals( ii ).dValiorDt,
                                                                                SchDeals( ii ).dValiorKt,
                                                                                SchDeals( ii ).nIdExpoDt,
                                                                                'F',
                                                                                SchDeals( ii ).nSumSys,
                                                                                cRefer,
                                                                                null,
                                                                                0,
                                                                                null
                                                                               );
                  else
                    DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                nIdExpoIn,
                                                                                SchDeals( ii ).nSumRazchet,
                                                                                SchDeals( ii ).nSumRazchet,
                                                                                nIdExpoOut,
                                                                                SchDeals( ii ).dValiorKt,
                                                                                SchDeals( ii ).dValiorKt,
                                                                                nIdExpoIn,
                                                                                'F',
                                                                                SchDeals( ii ).nSumSys,
                                                                                cRefer,
                                                                                null,
                                                                                0,
                                                                                null
                                                                               );
                  end if;
                end if;
              end loop;

              if ( DealOper1.count > 0 ) then
                bRet  := GenerateMemoOrder( HeadData1, DealOper1 );

                if ( bRet ) then
                  aIDMoves( aIDMoves.count + 1 )  := HeadData1.ID_MOVE;
                end if;
              end if;
            end if;

            nUCodeDt  := aUniqsDt( jj );
            exit when not bRet;
          end loop;

          if ( bRet ) then
            if ( nPosKt = 0 ) then
              nPosKt  := aUniqsKt.count;
            end if;

            for jj in reverse 1 .. nPosKt loop
              if ( ( jj < nPosKt or
                    bParentDt ) and
                  aUniqsKt( jj ) != nHeadUniq ) then
                bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Master', null, to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                                          sCodValIn = sValRazchet;
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'UNIQ_KT';
                aParams( 1 ).ML_VALUE  := aUniqsKt( jj );
                aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
                aParams( 2 ).ML_VALUE  := sValRazchet;
                Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_KT$ Master $VAL_RAZCHET$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
              else
                bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsDt( aUniqsDt.count ), to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                                          sCodValIn = sValRazchet;
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'UNIQ_KT';
                aParams( 1 ).ML_VALUE  := aUniqsKt( jj );
                aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
                aParams( 2 ).ML_VALUE  := sValRazchet;
                aParams( 3 ).ML_NAME   := 'UNIQ_DT';
                aParams( 3 ).ML_VALUE  := aUniqsDt( aUniqsDt.count );
                Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_KT$ Slave $VAL_RAZCHET$ $UNIQ_DT$',
                                                   Schema_GPSys.MLng.ctxAccounting,
                                                   Schema_GPSys.MLng.lngBG,
                                                   aParams
                                                  );
              end if;

              if ( jj != 1 ) then
                bRet                   := bRet and
                                          Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsKt( jj - 1 ), to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                                          sCodValOut = sValRazchet;
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'UNIQ_KT';
                aParams( 1 ).ML_VALUE  := aUniqsKt( jj );
                aParams( 2 ).ML_NAME   := 'VAL_RAZCHET';
                aParams( 2 ).ML_VALUE  := sValRazchet;
                aParams( 3 ).ML_NAME   := 'UNIQ_KT2';
                aParams( 3 ).ML_VALUE  := aUniqsKt( jj - 1 );
                Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet $UNIQ_KT$  Slave $VAL_RAZCHET$ $UNIQ_KT2$',
                                                   Schema_GPSys.MLng.ctxAccounting,
                                                   Schema_GPSys.MLng.lngBG,
                                                   aParams
                                                  );
              end if;

              if ( bRet ) then
                DealOper1  := Schema_GPSys.tblDealOper( );
                HeadData1  := Schema_GPSys.tMemoOrder( null, aUniqsKt( jj ), sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );

                for ii in SchDeals.first .. SchDeals.last loop
                  cRefer  := SchDeals( ii ).sReferencia;

                  if ( Schema_GPSys.OraGPSys.SplitRanges( cRefer, aListFr, aListTo, false ) ) then
                    if ( aListFr.count = 1 ) then
                      cReferDt  := aListFr( 1 );
                      cReferKt  := aListFr( 1 );
                    elsif ( aListFr.count >= 2 ) then
                      cReferDt  := aListFr( 1 );
                      cReferKt  := aListFr( 2 );
                    end if;
                  end if;

                  if ( HeadData1.UniqCode = nUniqCodeDt ) then
                    cRefer  := cReferDt;
                  elsif ( HeadData1.UniqCode = nUniqCodeKt ) then
                    cRefer  := cReferKt;
                  else
                    cRefer  := null;
                  end if;

                  select UNIQCODE
                    into nSchD_UCodeDt
                    from Schema_GPSys.EXPOSITION
                   where ID_EXPO = SchDeals( ii ).nIdExpoDt;

                  select UNIQCODE
                    into nSchD_UCodeKt
                    from Schema_GPSys.EXPOSITION
                   where ID_EXPO = SchDeals( ii ).nIdExpoKt;

                  if ( nSchD_UCodeDt = nSchD_UCodeKt ) then
                    if ( nSchD_UCodeKt = aUniqsKt( jj ) ) then
                      DealOper1.extend;
                      DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                  SchDeals( ii ).nIdExpoDt,
                                                                                  SchDeals( ii ).nSumDt,
                                                                                  SchDeals( ii ).nSumKt,
                                                                                  SchDeals( ii ).nIdExpoKt,
                                                                                  SchDeals( ii ).dValiorDt,
                                                                                  SchDeals( ii ).dValiorKt,
                                                                                  SchDeals( ii ).nIdExpoDt,
                                                                                  'F',
                                                                                  SchDeals( ii ).nSumSys,
                                                                                  cRefer,
                                                                                  null,
                                                                                  0,
                                                                                  null
                                                                                 );
                    end if;
                  else
                    DealOper1.extend;

                    if ( jj = 1 ) then
                      DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                  nIdExpoIn,
                                                                                  SchDeals( ii ).nSumRazchet,
                                                                                  SchDeals( ii ).nSumKt,
                                                                                  SchDeals( ii ).nIdExpoKt,
                                                                                  SchDeals( ii ).dValiorKt,
                                                                                  SchDeals( ii ).dValiorKt,
                                                                                  SchDeals( ii ).nIdExpoKt,
                                                                                  'F',
                                                                                  SchDeals( ii ).nSumSys,
                                                                                  cRefer,
                                                                                  null,
                                                                                  0,
                                                                                  null
                                                                                 );
                    else
                      DealOper1( DealOper1.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                  nIdExpoIn,
                                                                                  SchDeals( ii ).nSumRazchet,
                                                                                  SchDeals( ii ).nSumRazchet,
                                                                                  nIdExpoOut,
                                                                                  SchDeals( ii ).dValiorKt,
                                                                                  SchDeals( ii ).dValiorKt,
                                                                                  nIdExpoIn,
                                                                                  'F',
                                                                                  SchDeals( ii ).nSumSys,
                                                                                  cRefer,
                                                                                  null,
                                                                                  0,
                                                                                  null
                                                                                 );
                    end if;
                  end if;
                end loop;

                if ( DealOper1.count > 0 ) then
                  bRet  := GenerateMemoOrder( HeadData1, DealOper1 );

                  if ( bRet ) then
                    aIDMoves( aIDMoves.count + 1 )  := HeadData1.ID_MOVE;
                  end if;
                end if;
              end if;

              exit when not bRet;
            end loop;
          end if;

          bRet       := bRet and
                        Expo.SaveGroupIdMoves( aIDMoves );
        end if;
      end if;

      if ( not bRet ) then
        rollback to HierarchySaveSchDeals;
      end if;
    end if;

    return bRet;
  end HierarchySaveSchDeals;

  --------------------------------------------------------------------------------
  function HierarchySaveMSchDeals(
    aIDMoves     in out nocopy Schema_GPSys.OraGPSys.aIntegers,
    dSchDate     in            date,
    sOsnovanie   in            varchar2,
    sValRazchet  in            varchar2,
    SchDeals     in            tSchDeals,
    nDealType    in            integer default Sch_Free
  )
    return boolean is
    cursor qGetMaster( nSlave in integer ) is
      ( select UCODE_MASTER
          from Schema_GPSys.PODELENIA_CONF
         where UCODE_SLAVE = nSlave );

    aListFr      Schema_GPSys.OraGPSys.aStrings;
    aListTo      Schema_GPSys.OraGPSys.aStrings;
    aUniqsDt     Schema_GPSys.OraGPSys.aNumbers;
    aUniqsKt     Schema_GPSys.OraGPSys.aNumbers;
    cReferDt     EXPO_MOVES.REFERENCIA%type;
    cReferKt     EXPO_MOVES.REFERENCIA%type;
    cRefer       EXPO_MOVES.REFERENCIA%type;
    nIdExpoOut   integer;
    nIdExpoIn    integer;
    nPosDt       integer;
    nPosKt       integer;
    nHeadUniq    integer;
    nUCodeDt     integer;
    nUCodeKt     integer;
    nUniqCodeDt  integer;
    nUniqCodeKt  integer;
    sCodValIn    varchar2( 3 );
    sCodValOut   varchar2( 3 );
    bRet         boolean;
    bDown        boolean;
    bParentDt    boolean;
    nUCodePos    integer;

    type tMOrder is record(
      nUCode    integer,
      HeadData  Schema_GPSys.tMemoOrder,
      DealOper  Schema_GPSys.tblDealOper
    );

    type tblMOrders is table of tMOrder
      index by binary_integer;

    MOrders      tblMOrders;
  begin
    if ( SchDeals.count > 0 ) then
      if ( Schema_GPSys.OraSys.VerInsBulIns or
          Schema_GPSys.OraSys.VerInsOlympic ) then
        nHeadUniq  := 1000;
      else
        nHeadUniq  := Schema_RA.GPC_Tools.GetHeadUniqCode( );
      end if;

      savepoint HierarchySaveMSchDeals;

      for ii in SchDeals.first .. SchDeals.last loop
        nPosDt                          := 0;
        nPosKt                          := 0;
        bRet                            := false;
        bDown                           := false;
        bParentDt                       := true;
        aUniqsDt.delete;
        aUniqsKt.delete;

        select UNIQCODE
          into nUniqCodeDt
          from Schema_GPSys.EXPOSITION
         where ID_EXPO = SchDeals( ii ).nIdExpoDt;

        select UNIQCODE
          into nUniqCodeKt
          from Schema_GPSys.EXPOSITION
         where ID_EXPO = SchDeals( ii ).nIdExpoKt;

        nUCodeDt                        := nUniqCodeDt;
        nUCodeKt                        := nUniqCodeKt;
        aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
        aUniqsKt( aUniqsKt.count + 1 )  := nUCodeKt;

        if ( nUniqCodeDt = nUniqCodeKt or
            not Expo.IsSystemHaveBalances ) then
          nUCodePos                                                                := 0;
          bRet                                                                     := true;

          for kk in 1 .. MOrders.count loop
            if ( MOrders( kk ).nUCode = nUniqCodeDt ) then
              nUCodePos  := kk;
              exit;
            end if;
          end loop;

          if ( nUCodePos = 0 ) then
            nUCodePos                      := MOrders.count + 1;
            MOrders( nUCodePos ).nUCode    := nUniqCodeDt;
            MOrders( nUCodePos ).HeadData  := Schema_GPSys.tMemoOrder( null, nUniqCodeDt, sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );
            MOrders( nUCodePos ).DealOper  := Schema_GPSys.tblDealOper( );
          end if;

          cRefer                                                                   := SchDeals( ii ).sReferencia;
          MOrders( nUCodePos ).DealOper.extend;
          MOrders( nUCodePos ).DealOper( MOrders( nUCodePos ).DealOper.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                                              SchDeals( ii ).nIdExpoDt,
                                                                                                              SchDeals( ii ).nSumDt,
                                                                                                              SchDeals( ii ).nSumKt,
                                                                                                              SchDeals( ii ).nIdExpoKt,
                                                                                                              SchDeals( ii ).dValiorDt,
                                                                                                              SchDeals( ii ).dValiorKt,
                                                                                                              SchDeals( ii ).nIdExpoDt,
                                                                                                              'F',
                                                                                                              SchDeals( ii ).nSumSys,
                                                                                                              cRefer,
                                                                                                              null,
                                                                                                              0,
                                                                                                              null
                                                                                                             );
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Грешка, няма връзка между избраните поделения', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

          loop
            if ( nUCodeKt != -1 ) then
              open qGetMaster( nUCodeKt );

              nUCodeKt  := null;

              fetch qGetMaster
                into nUCodeKt;

              close qGetMaster;

              nUCodeKt  := nvl( nUCodeKt, -1 );

              if ( not bDown ) then
                bDown  := nUCodeKt = nUniqCodeDt;
              end if;
            end if;

            if ( nUCodeDt != -1 ) then
              open qGetMaster( nUCodeDt );

              nUCodeDt  := null;

              fetch qGetMaster
                into nUCodeDt;

              close qGetMaster;

              nUCodeDt  := nvl( nUCodeDt, -1 );
            end if;

            if ( nUCodeDt != nUCodeKt ) then
              if ( nUCodeKt != -1 ) then
                nPosDt  := Schema_GPSys.OraGPSys.AScan( aUniqsDt, nUCodeKt );
              end if;

              if ( nPosDt = 0 and
                  nUCodeDt != -1 ) then
                nPosKt  := Schema_GPSys.OraGPSys.AScan( aUniqsKt, nUCodeDt );
              end if;

              if ( nPosDt = 0 and
                  nPosKt = 0 ) then
                if ( nUCodeDt != -1 ) then
                  aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
                end if;

                if ( nUCodeKt != -1 ) then
                  aUniqsKt( aUniqsKt.count + 1 )  := nUCodeKt;
                end if;
              else
                bRet  := true;
                exit;
              end if;
            else
              if ( nUCodeDt != -1 ) then
                aUniqsDt( aUniqsDt.count + 1 )  := nUCodeDt;
                nPosDt                          := aUniqsDt.count;
                bRet                            := true;
              end if;

              exit;
            end if;
          end loop;

          if ( bRet ) then
            if ( nPosDt = 0 ) then
              nPosDt     := aUniqsDt.count;
              bParentDt  := false;
            end if;

            for jj in 1 .. nPosDt loop
              if ( ( jj = 1 or
                    jj != nPosDt or
                    not bParentDt ) and
                  aUniqsDt( jj ) != nHeadUniq and
                  not bDown ) then
                bRet      := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Master', null, to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                             sCodValOut = sValRazchet;
              else
                bRet      := bRet and
                             Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsKt( aUniqsKt.count ), to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                             sCodValOut = sValRazchet;
              end if;

              if ( jj > 1 ) then
                bRet      := bRet and
                             Schema_GPSys.HeadExpo.Conf2Expo( aUniqsDt( jj ), 'Razchet', sValRazchet, 'Slave', nUCodeDt, to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                             sCodValIn = sValRazchet;
              end if;

              if ( bRet ) then
                nUCodePos  := 0;

                for kk in 1 .. MOrders.count loop
                  if ( MOrders( kk ).nUCode = aUniqsDt( jj ) ) then
                    nUCodePos  := kk;
                    exit;
                  end if;
                end loop;

                if ( nUCodePos = 0 ) then
                  nUCodePos                      := MOrders.count + 1;
                  MOrders( nUCodePos ).nUCode    := aUniqsDt( jj );
                  MOrders( nUCodePos ).HeadData  := Schema_GPSys.tMemoOrder( null, aUniqsDt( jj ), sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );
                  MOrders( nUCodePos ).DealOper  := Schema_GPSys.tblDealOper( );
                end if;

                cRefer     := SchDeals( ii ).sReferencia;
                MOrders( nUCodePos ).DealOper.extend;

                if ( Schema_GPSys.OraGPSys.SplitRanges( cRefer, aListFr, aListTo, false ) ) then
                  if ( aListFr.count = 1 ) then
                    cReferDt  := aListFr( 1 );
                    cReferKt  := aListFr( 1 );
                  elsif ( aListFr.count >= 2 ) then
                    cReferDt  := aListFr( 1 );
                    cReferKt  := aListFr( 2 );
                  end if;
                end if;

                if ( MOrders( nUCodePos ).HeadData.UniqCode = nUniqCodeDt ) then
                  cRefer  := cReferDt;
                elsif ( MOrders( nUCodePos ).HeadData.UniqCode = nUniqCodeKt ) then
                  cRefer  := cReferKt;
                else
                  cRefer  := null;
                end if;

                if ( jj = 1 ) then
                  MOrders( nUCodePos ).DealOper( MOrders( nUCodePos ).DealOper.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                                                      SchDeals( ii ).nIdExpoDt,
                                                                                                                      SchDeals( ii ).nSumDt,
                                                                                                                      SchDeals( ii ).nSumRazchet,
                                                                                                                      nIdExpoOut,
                                                                                                                      SchDeals( ii ).dValiorDt,
                                                                                                                      SchDeals( ii ).dValiorKt,
                                                                                                                      SchDeals( ii ).nIdExpoDt,
                                                                                                                      'F',
                                                                                                                      SchDeals( ii ).nSumSys,
                                                                                                                      cRefer,
                                                                                                                      null,
                                                                                                                      0,
                                                                                                                      null
                                                                                                                     );
                else
                  MOrders( nUCodePos ).DealOper( MOrders( nUCodePos ).DealOper.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                                                      nIdExpoIn,
                                                                                                                      SchDeals( ii ).nSumRazchet,
                                                                                                                      SchDeals( ii ).nSumRazchet,
                                                                                                                      nIdExpoOut,
                                                                                                                      SchDeals( ii ).dValiorKt,
                                                                                                                      SchDeals( ii ).dValiorKt,
                                                                                                                      nIdExpoIn,
                                                                                                                      'F',
                                                                                                                      SchDeals( ii ).nSumSys,
                                                                                                                      cRefer,
                                                                                                                      null,
                                                                                                                      0,
                                                                                                                      null
                                                                                                                     );
                end if;
              end if;

              nUCodeDt  := aUniqsDt( jj );
              exit when not bRet;
            end loop;

            if ( bRet ) then
              if ( nPosKt = 0 ) then
                nPosKt  := aUniqsKt.count;
              end if;

              for jj in reverse 1 .. nPosKt loop
                if ( ( jj < nPosKt or
                      bParentDt ) and
                    aUniqsKt( jj ) != nHeadUniq ) then
                  bRet      := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Master', null, to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                               sCodValIn = sValRazchet;
                else
                  bRet      := Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsDt( aUniqsDt.count ), to_char( nDealType ), null, nIdExpoIn, sCodValIn ) and
                               sCodValIn = sValRazchet;
                end if;

                if ( jj != 1 ) then
                  bRet      := bRet and
                               Schema_GPSys.HeadExpo.Conf2Expo( aUniqsKt( jj ), 'Razchet', sValRazchet, 'Slave', aUniqsKt( jj - 1 ), to_char( nDealType ), null, nIdExpoOut, sCodValOut ) and
                               sCodValOut = sValRazchet;
                end if;

                if ( bRet ) then
                  nUCodePos  := 0;

                  for kk in 1 .. MOrders.count loop
                    if ( MOrders( kk ).nUCode = aUniqsKt( jj ) ) then
                      nUCodePos  := kk;
                      exit;
                    end if;
                  end loop;

                  if ( nUCodePos = 0 ) then
                    nUCodePos                      := MOrders.count + 1;
                    MOrders( nUCodePos ).nUCode    := aUniqsKt( jj );
                    MOrders( nUCodePos ).HeadData  := Schema_GPSys.tMemoOrder( null, aUniqsKt( jj ), sOsnovanie, dSchDate, null, null, null, null, null, null, sysdate );
                    MOrders( nUCodePos ).DealOper  := Schema_GPSys.tblDealOper( );
                  end if;

                  cRefer     := SchDeals( ii ).sReferencia;
                  MOrders( nUCodePos ).DealOper.extend;

                  if ( Schema_GPSys.OraGPSys.SplitRanges( cRefer, aListFr, aListTo, false ) ) then
                    if ( aListFr.count = 1 ) then
                      cReferDt  := aListFr( 1 );
                      cReferKt  := aListFr( 1 );
                    elsif ( aListFr.count >= 2 ) then
                      cReferDt  := aListFr( 1 );
                      cReferKt  := aListFr( 2 );
                    end if;
                  end if;

                  if ( MOrders( nUCodePos ).HeadData.UniqCode = nUniqCodeDt ) then
                    cRefer  := cReferDt;
                  elsif ( MOrders( nUCodePos ).HeadData.UniqCode = nUniqCodeKt ) then
                    cRefer  := cReferKt;
                  else
                    cRefer  := null;
                  end if;

                  if ( jj = 1 ) then
                    MOrders( nUCodePos ).DealOper( MOrders( nUCodePos ).DealOper.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                                                        nIdExpoIn,
                                                                                                                        SchDeals( ii ).nSumRazchet,
                                                                                                                        SchDeals( ii ).nSumKt,
                                                                                                                        SchDeals( ii ).nIdExpoKt,
                                                                                                                        SchDeals( ii ).dValiorKt,
                                                                                                                        SchDeals( ii ).dValiorKt,
                                                                                                                        SchDeals( ii ).nIdExpoKt,
                                                                                                                        'F',
                                                                                                                        SchDeals( ii ).nSumSys,
                                                                                                                        cRefer,
                                                                                                                        null,
                                                                                                                        0,
                                                                                                                        null
                                                                                                                       );
                  else
                    MOrders( nUCodePos ).DealOper( MOrders( nUCodePos ).DealOper.last )      := Schema_GPSys.tDealOper( nDealType,
                                                                                                                        nIdExpoIn,
                                                                                                                        SchDeals( ii ).nSumRazchet,
                                                                                                                        SchDeals( ii ).nSumRazchet,
                                                                                                                        nIdExpoOut,
                                                                                                                        SchDeals( ii ).dValiorKt,
                                                                                                                        SchDeals( ii ).dValiorKt,
                                                                                                                        nIdExpoIn,
                                                                                                                        'F',
                                                                                                                        SchDeals( ii ).nSumSys,
                                                                                                                        cRefer,
                                                                                                                        null,
                                                                                                                        0,
                                                                                                                        null
                                                                                                                       );
                  end if;
                end if;

                exit when not bRet;
              end loop;
            end if;
          end if;
        end if;

        exit when not bRet;
      end loop;

      if ( bRet ) then
        for kk in 1 .. MOrders.count loop
          if ( MOrders( kk ).DealOper.count > 0 ) then
            bRet  := GenerateMemoOrder( MOrders( kk ).HeadData, MOrders( kk ).DealOper );

            if ( bRet ) then
              aIDMoves( aIDMoves.count + 1 )  := MOrders( kk ).HeadData.ID_MOVE;
            else
              exit;
            end if;
          end if;
        end loop;

        bRet      := bRet and
                     Expo.SaveGroupIdMoves( aIDMoves );
      end if;

      if ( not bRet ) then
        rollback to HierarchySaveMSchDeals;
      end if;
    end if;

    return bRet;
  end HierarchySaveMSchDeals;

  --------------------------------------------------------------------------------
  function CmdHierarchyPay( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    ii          pls_integer;
    jj          pls_integer;
    kk          pls_integer;
    SchDeals    tSchDeals;
    aIDMoves    Schema_GPSys.OraGPSys.aIntegers;
    sOsnovanie  varchar2( 4000 );
    sData       varchar2( 4000 );
    dSchDate    date;
    bRet        boolean;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := true;
    ii        := aParamEntities3D.first;

    while ( ii is not null and
           bRet ) loop
      bRet  := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues );

      if ( bRet ) then
        case aParamEntities3D( ii ).nRowType
          when 1 then
            bRet      := aRowValues.count >= 2 and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), sOsnovanie ) and
                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 2 ), dSchDate );
          when 2 then
            jj        := SchDeals.count + 1;
            -- подредени са както в CmdSaveMemoOrder
            bRet      := aRowValues.count >= 12 and
                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), SchDeals( jj ).nDealType ) and
                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), SchDeals( jj ).nUCodeDt ) and
                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 3 ), SchDeals( jj ).nIDExpoDt ) and
                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 4 ), SchDeals( jj ).nSumDt ) and
                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 5 ), SchDeals( jj ).nSumKt ) and
                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 6 ), SchDeals( jj ).nIDExpoKt ) and
                         Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 7 ), SchDeals( jj ).nUCodeKt ) and
                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 8 ), SchDeals( jj ).dValiorDt ) and
                         Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 9 ), SchDeals( jj ).dValiorKt ) and
                         Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 10 ), SchDeals( jj ).nSumRazchet ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 11 ), SchDeals( jj ).sValRazchet ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 12 ), SchDeals( jj ).sReferencia ) and
                         ( ( not aRowValues.exists( 13 ) ) or
                          Schema_GPSys.GPC_Parser.ReadAmount( aRowValues( 13 ), SchDeals( jj ).nSumSys ) );

            if ( SchDeals( jj ).nSumSys = 0 ) then
              SchDeals( jj ).nSumSys  := null;
            end if;

            if ( bRet ) then -- проверка дали nDealType е валидно
              SchDeals( jj ).nDealType  := nvl( SchDeals( jj ).nDealType, Sch_Free );

              if ( SchDeals( jj ).nDealType ~= Sch_Free ) then
                begin
                  select OPER_TYPE
                    into SchDeals( jj ).nDealType
                    from PODELENIA_OPER_TYPE
                   where OPER_TYPE = SchDeals( jj ).nDealType;
                exception
                  when no_data_found then
                    bRet  := false;
                end;
              end if;
            end if;
          else
            bRet  := false;
        end case;
      end if;

      ii    := aParamEntities3D.next( ii );
    end loop;

    bRet      := bRet and
                 dSchDate is not null and
                 SchDeals.count > 0;

    if ( bRet ) then
      kk  := 0;
      Schema_GPSys.GPC_Parser.RespAddArray( 1 );
      ii  := SchDeals.first;

      while ( ii is not null and
             bRet ) loop
        aIDMoves.delete;
        bRet      := HierarchySaveMemOrder( aIDMoves,
                                            SchDeals( ii ).nUCodeDt,
                                            SchDeals( ii ).nIDExpoDt,
                                            SchDeals( ii ).nSumDt,
                                            SchDeals( ii ).dValiorDt,
                                            SchDeals( ii ).nUCodeKt,
                                            SchDeals( ii ).nIDExpoKt,
                                            SchDeals( ii ).nSumKt,
                                            SchDeals( ii ).dValiorKt,
                                            dSchDate,
                                            sOsnovanie,
                                            SchDeals( ii ).nSumRazchet,
                                            SchDeals( ii ).sValRazchet,
                                            SchDeals( ii ).sReferencia,
                                            SchDeals( ii ).nSumSys,
                                            SchDeals( ii ).nDealType
                                           );
        jj        := aIDMoves.first;

        if ( jj is not null and
            kk = 0 ) then
          Schema_GPSys.GPC_Parser.nGlobalNumber  := aIDMoves( jj );
        end if;

        kk        := kk + 1;

        while ( jj is not null and
               bRet ) loop
          sData     := null;
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.WriteInteger( kk, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( aIDMoves( jj ), sData ) and
                       Schema_GPSys.GPC_Parser.RespAddRow( sData );
          jj        := aIDMoves.next( jj );
        end loop;

        ii        := SchDeals.next( ii );
      end loop;
    end if;

    return bRet;
  end CmdHierarchyPay;

  --------------------------------------------------------------------------------
  function InBankGetExpoConf(
    nUniqCodeFrom   in            integer,
    nUniqcodeTo     in            integer,
    sCodVal         in            varchar2,
    cInOut          in            varchar2,
    nIdExpoRazchet     out nocopy integer,
    sCodValRazchet     out nocopy varchar2
  )
    return boolean is
    bRet       boolean := false;
    sBankCode  varchar2( 8 );
    aParams    Schema_RA.GPC_RA.tblErrParams;
  begin
    if ( sCodVal = Schema_GPSys.OraGPSys.SYS_CURR ) then
      sBankCode  := Schema_RA.GPC_Tools.UniqCode2BankCode( nUniqCodeTo );

      if ( cInOut = 'O' ) then
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'UCODE_FROM';
        aParams( 1 ).ML_VALUE  := to_char( nUniqCodeFrom );
        aParams( 2 ).ML_NAME   := 'SYS_CURRENCY';
        aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.SYS_CURR;
        aParams( 3 ).ML_NAME   := 'BANK_CODE';
        aParams( 3 ).ML_VALUE  := sBankCode;
        aParams( 4 ).ML_NAME   := 'UCODE_TO';
        aParams( 4 ).ML_VALUE  := to_char( nUniqCodeTo );
        Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet_BISERA $UCODE_FROM$ $SYS_CURRENCY$ INTER O $BANK_CODE$ $UCODE_TO$',
                                           Schema_GPSys.MLng.ctxAccounting,
                                           Schema_GPSys.MLng.lngBG,
                                           aParams
                                          );
        bRet                   := sBankCode is not null and
                                  Schema_GPSys.HeadExpo.Conf2Expo( nUniqCodeFrom,
                                                                   'Razchet_BISERA',
                                                                   Schema_GPSys.OraGPSys.SYS_CURR,
                                                                   'INTER',
                                                                   'O',
                                                                   sBankCode,
                                                                   nUniqCodeTo,
                                                                   nIdExpoRazchet,
                                                                   sCodValRazchet
                                                                  ) and
                                  sCodValRazchet = sCodVal;
      else
        aParams.delete;
        aParams( 1 ).ML_NAME   := 'UCODE_FROM';
        aParams( 1 ).ML_VALUE  := to_char( nUniqCodeFrom );
        aParams( 2 ).ML_NAME   := 'SYS_CURRENCY';
        aParams( 2 ).ML_VALUE  := Schema_GPSys.OraGPSys.SYS_CURR;
        aParams( 3 ).ML_NAME   := 'BANK_CODE';
        aParams( 3 ).ML_VALUE  := sBankCode;
        aParams( 4 ).ML_NAME   := 'UCODE_TO';
        aParams( 4 ).ML_VALUE  := to_char( nUniqCodeTo );
        Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet_BISERA $UCODE_FROM$ $SYS_CURRENCY$ INTER I $BANK_CODE$ $UCODE_TO$',
                                           Schema_GPSys.MLng.ctxAccounting,
                                           Schema_GPSys.MLng.lngBG,
                                           aParams
                                          );
        bRet                   := sBankCode is not null and
                                  Schema_GPSys.HeadExpo.Conf2Expo( nUniqCodeFrom,
                                                                   'Razchet_BISERA',
                                                                   Schema_GPSys.OraGPSys.SYS_CURR,
                                                                   'INTER',
                                                                   'I',
                                                                   sBankCode,
                                                                   nUniqCodeTo,
                                                                   nIdExpoRazchet,
                                                                   sCodValRazchet
                                                                  ) and
                                  sCodVal = sCodValRazchet;
      end if;
    else
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'UCODE_FROM';
      aParams( 1 ).ML_VALUE  := to_char( nUniqCodeFrom );
      aParams( 2 ).ML_NAME   := 'CURRENCY';
      aParams( 2 ).ML_VALUE  := sCodVal;
      aParams( 3 ).ML_NAME   := 'UCODE_TO';
      aParams( 3 ).ML_VALUE  := to_char( nUniqCodeTo );
      Schema_RA.GPC_RA.RespSetErrorText( 'Липсва експозиция за Razchet_VALUTA $UCODE_FROM$ $CURRENCY$ $UCODE_TO$',
                                         Schema_GPSys.MLng.ctxAccounting,
                                         Schema_GPSys.MLng.lngBG,
                                         aParams
                                        );
      bRet                   := Schema_GPSys.HeadExpo.Conf2Expo( nUniqCodeFrom, 'Razchet_VALUTA', sCodVal, nUniqCodeTo, null, null, null, nIdExpoRazchet, sCodValRazchet ) and
                                sCodVal = sCodValRazchet;
    end if;

    return bRet;
  end InBankGetExpoConf;

  ------------------------------------------------------------------------------------------
  function CmdExpoPreocenkaByExpo(
    aParamEntities3D  in Schema_GPSys.GPC_Parser.taParamEntities3D,
    bLockUniqCode     in boolean default true,
    bCommit           in boolean default true
  )
    return boolean is
    aRowValues     Schema_GPSys.GPC_Parser.taParamStrings;
    aExpos         Schema_GPSys.OraGPSys.aNumbers;
    HeadData       Schema_GPSys.tMemoOrder;
    DealOper       Schema_GPSys.tblDealOper;
    BdgOpers       tblBdgOpers;
    rBDGData       BDG_MOVES%rowtype;
    sBDGClassif    BDG_MOVES.BDG_CLASSIF%type;
    recExpo        Schema_GPSys.EXPOSITION%rowtype;
    sFolderMode    EXPO_MOVE_TEXT.FOLDER_MODE%type;
    nScale         number;
    dFDate         date;
    dTDate         date;
    dWDate         date;
    dDummy         date;
    nECRBuff       integer;
    sVCRBuff       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRBalP       integer;
    sVCRBalP       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRBalR       integer;
    sVCRBalR       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRZadP       integer;
    sVCRZadP       Schema_GPSys.EXPOSITION.CODVAL%type;
    nECRZadR       integer;
    sVCRZadR       Schema_GPSys.EXPOSITION.CODVAL%type;
    nExpoCRP       integer;
    nExpoCRR       integer;
    nUniqCode      integer;
    nAllExpo       pls_integer;
    sExclSyntCode  varchar2( 4000 );
    bValior        boolean;
    bDTSaldo       boolean;
    bZeroMinus     boolean;
    bBlackOper     boolean;
    bOldState      boolean;
    bDummy         boolean;
    bRet           boolean := false;
    sData          varchar2( 4000 );
    aParams        Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count > 0 ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        if ( aParamEntities3D( ii ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 1 ), dFDate ) and
                       Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bValior ) and
                       ( ( not aRowValues.exists( 3 ) ) or
                        Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), dTDate ) );
          dTDate    := nvl( dTDate, dFDate );
        elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
          if ( Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) ) then
            bRet  := true;

            if ( aRowValues.count > 0 ) then
              for jj in aRowValues.first .. aRowValues.last loop
                bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( jj ), aExpos( aExpos.count + 1 ) );
                exit when not bRet;
              end loop;
            end if;
          end if;
        end if;
      end loop;
    end if;

    if ( bRet and
        aExpos( aExpos.count ) > 0 ) then
      bOldState  := Expo.SetSkipLimit( EXPO.ModeSkip_CardAuth, true );
      nScale     := Schema_GPSys.OraGPSys.GetCurrencyScale( Schema_GPSys.OraGPSys.SYS_CURR );
      nScale     := power( 10, nScale );
      nScale     := Schema_GPSys.OraGPSys.nTruncSet( nScale );

      for ii in aExpos.first .. aExpos.last loop
        if ( aExpos.first = ii ) then
          nUniqCode  := Schema_GPSys.HeadExpo.IDExpo2UCode( aExpos( ii ) );
        else
          bRet  := nUniqCode = Schema_GPSys.HeadExpo.IDExpo2UCode( aExpos( ii ) );
        end if;

        exit when not bRet;
      end loop;

      if ( bRet ) then
        if ( Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'ПреоценкаЕкспозиции', 'T' ) ) ) then
          if ( bLockUniqCode ) then
            bRet  := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqCode );
          end if;

          if ( bRet ) then
            sFolderMode    := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'FOLDER', 'MODE_PREOC', null );
            --
            sBDGClassif    := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_CLASSIF', null );

            if ( sBDGClassif is not null ) then
              rBDGData.BDG_FUNCTION  := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_FUNCTION', null );
              rBDGData.BDG_OBJECT    := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_OBJECT', null );
              rBDGData.DT_KT         := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_DT_KT', 'K' );
            end if;

            --
            bZeroMinus     := Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'PreocZeroDT', 'T' ) );
            bBlackOper     := Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'PreocBlackOper', 'T' ) );
            sExclSyntCode  := Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'Счетоводство', 'PreocExclSyntCode', '~' );
            --
            dWDate         := dFDate;
            Schema_GPSys.GPC_Parser.RespAddArray( 1 );

            while ( dWDate <= dTDate ) loop
              if ( nvl( dWDate = Schema_RA.GPC_Tools.GetSchDate( nUniqCode ), false ) or
                  nvl( dWDate = Schema_DocSys.DOCSYS.GetWorkDay( dWDate, dDummy ), false ) ) then
                DealOper  := Schema_GPSys.tblDealOper( );

                for ii in aExpos.first .. aExpos.last loop
                  for rec in ( select Schema_GPSys.OraGPSys.GetSynt( a.EXPO_CODE ) as SYNT,
                                      a.CODVAL,
                                      nvl( a.AN_FEAT, '~' ) as ANFEAT,
                                      a.ID_EXPO,
                                      a.TYPE_EXPO,
                                      a.EXPO_CODE,
                                      a.AN1,
                                      a.AN2,
                                      a.AN3,
                                      a.AN4,
                                      a.AN5,
                                      a.AN6,
                                      a.SYNT_CODE,
                                      b.IN_BALANCE,
                                      b.ACTPASS
                                 from Schema_GPSys.EXPOTYPES b,
                                      Schema_GPSys.EXPOSITION a
                                where a.ID_EXPO = aExpos( ii ) and
                                      a.STATUS = 'T' and
                                      a.CODVAL != Schema_GPSys.OraGPSys.SYS_CURR and
                                      a.NOPREOC = 'F' and
                                      instr( sExclSyntCode, '&' || a.SYNT_CODE || '&' ) = 0 and
                                      a.TYPE_EXPO = b.TYPE_EXPO ) loop
                    bRet      := GetConf2ExpoPreoc( rec.CodVal,
                                                    rec.SYNT_CODE,
                                                    rec.IN_BALANCE,
                                                    nUniqCode,
                                                    bBlackOper,
                                                    rec.EXPO_CODE,
                                                    rec.ANFEAT,
                                                    nECRBuff,
                                                    nECRBalP,
                                                    nECRZadP,
                                                    nECRBalR,
                                                    nECRZadR,
                                                    sVCRZadP,
                                                    sVCRBalR,
                                                    sVCRBalP,
                                                    sVCRZadR,
                                                    sVCRBuff
                                                   );

                    if ( bRet ) then
                      if ( sBDGClassif is not null ) then
                        rBDGData.BDG_CLASSIF  := nvl( Schema_GPSys.OraGPSys.GetIniValueInt( nUniqCode, 'BUDGET', 'PREOC_CLASSIF_' || to_char( rec.TYPE_EXPO ) || 'A1' || rec.AN1, null ), sBDGClassif );
                      end if;

                      DoOperExpoPreoc( rec.ID_EXPO,
                                       rec.CODVAL,
                                       rec.SYNT_CODE,
                                       nUniqCode,
                                       rec.IN_BALANCE,
                                       rec.ACTPASS,
                                       dWDate,
                                       bValior,
                                       bZeroMinus,
                                       bBlackOper,
                                       nECRBalP,
                                       nECRZadP,
                                       nECRBalR,
                                       nECRZadR,
                                       nECRBuff,
                                       nScale,
                                       DealOper,
                                       rBDGData,
                                       BdgOpers
                                      );
                    end if;

                    exit when not bRet;
                  end loop;

                  exit when not bRet;
                end loop;

                if ( bRet ) then
                  if ( DealOper.count > 0 ) then
                    savepoint CmdExpoPreocenkaByExpo_2;
                    HeadData      := Schema_GPSys.tMemoOrder( null,
                                                              nUniqCode,
                                                              Schema_GPSys.MLng.Str2( 'Валутна преоценка', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG ),
                                                              dWDate,
                                                              null,
                                                              null,
                                                              null,
                                                              null,
                                                              null,
                                                              sFolderMode,
                                                              sysdate
                                                             );
                    bRet          := GenerateMemoOrder( HeadData, DealOper, false, Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work, true, false, null, BdgOpers );

                    if ( bCommit ) then
                      if ( bRet ) then
                        sData  := null;
                        bRet   := Schema_GPSys.GPC_Parser.WriteInteger( HeadData.ID_MOVE, sData );

                        if ( bRet ) then
                          Schema_GPSys.GPC_Parser.RespAddRow( sData );
                        end if;

                        commit;
                      else
                        rollback to CmdExpoPreocenkaByExpo_2;
                      end if;
                    end if;
                  end if;
                end if;
              end if;

              exit when not bRet;
              dWDate  := dWDate + 1;
            end loop;

            if ( bLockUniqCode ) then
              bDTSaldo  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeSchOpers, nUniqCode );
            end if;
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'UNIQCODE';
            aParams( 1 ).ML_VALUE  := to_char( nUniqCode );
            Schema_RA.GPC_RA.RespSetErrorText( 'Неуспешен опит за забрана на счетоводни операции в поделение $UNIQCODE$',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;
        end if;
      else
        Schema_RA.GPC_RA.RespSetErrorText( 'Експозициите трябва да са от едно поделение', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG );
      end if;

      bDummy     := Expo.SetSkipLimit( EXPO.ModeSkip_CardAuth, bOldState );
    end if;

    return bRet;
  end CmdExpoPreocenkaByExpo;

  ------------------------------------------------------------------------------------------
  function CmdUpdateMemOrderText( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues     Schema_GPSys.GPC_Parser.taParamStrings;
    sOrdText       EXPO_MOVE_TEXT.ORD_TEXT%type;
    bRet           boolean;
    nIDMove        integer;
    nOrdRowNum     integer;
    nTechnType     integer := 0;
    nObjID         integer := 0;
    nOperType      integer := Sch_Free;
    dValiorPeriod  date;
  begin
    bRet  := aParamEntities3D.first is not null;

    if ( bRet ) then
      if ( aParamEntities3D( aParamEntities3D.first ).nRowType = 1 ) then
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( aParamEntities3D.first ).sValue, aRowValues ) and
                     aRowValues.count >= 2 and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDMove ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), sOrdText );

        if ( bRet and
            aRowValues.count >= 4 ) then
          bRet      := Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), dValiorPeriod ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), nOrdRowNum );
        end if;

        if ( bRet and
            aRowValues.count >= 7 ) then
          bRet      := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 5 ), nTechnType ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 6 ), nObjID ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 7 ), nOperType );
        end if;
      end if;

      if ( bRet ) then
        if ( not Expo.IsStorno( nIDMove ) ) then
          if ( sOrdText is not null ) then
            update EXPO_MOVE_TEXT
               set SYS_TEXT  = ORD_TEXT,
                   ORD_TEXT  = sOrdText
             where ID_MOVE = nIDMove;

            bRet  := sql%rowcount > 0;
          end if;

          if ( bRet and
              dValiorPeriod is not null ) then
            if ( nTechnType = 0 or
                nObjID = 0 ) then
              update EXPO_MOVES
                 set VALIOR_PERIOD  = dValiorPeriod
               where ID_MOVE = nIDMove and
                     ( nOrdRowNum = 0 or
                      ORDROWNUM = nOrdRowNum );

              bRet      := bRet and
                           sql%rowcount > 0;
            else
              update EXPO_MOVES
                 set VALIOR_PERIOD  = dValiorPeriod
               where ID_MOVE = nIDMove and
                     TECHN_TYPE = nTechnType and
                     TECHN_IDOBJ = nObjID and
                     ORDROWNUM = (select min( ORDROWNUM )
                                    from EXPO_MOVES
                                   where ID_MOVE = nIDMove and
                                         OPER_TYPE = nOperType and
                                         TECHN_TYPE = nTechnType and
                                         TECHN_IDOBJ = nObjID);

              bRet      := bRet and
                           sql%rowcount > 0;
            end if;
          end if;

          if ( bRet ) then
            commit;
          else
            Schema_RA.GPC_RA.RespSetErrorText( 'Не е намерено движение/ред от движение, което да бъде променено',
                                               Schema_GPSys.MLng.ctxAccounting,
                                               Schema_GPSys.MLng.lngBG
                                              );
            rollback;
          end if;
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Не може да редактирате сторниран/сторниращ документ',
                                             Schema_GPSys.MLng.ctxAccounting,
                                             Schema_GPSys.MLng.lngBG
                                            );
          bRet  := false;
        end if;
      end if;
    end if;

    return bRet;
  end CmdUpdateMemOrderText;

  ------------------------------------------------------------------------------------------
  function MemOrderClearTechnType( nIDMOve in integer )
    return boolean is
  begin
    update EXPO_MOVES
       set TECHN_TYPE   = 0,
           TECHN_IDOBJ  = 0
     where ID_MOVE = nIDMOve;

    return sql%rowcount > 0;
  end MemOrderClearTechnType;

  ------------------------------------------------------------------------------------------
  procedure ClearGlExpoMoveRec is
  begin
    glExpoMoveRec.ID_MOVE   := null;
    glExpoMoveRec.SCH_DATE  := null;
    glExpoMoveRec.SCH_DOC   := null;
  end ClearGlExpoMoveRec;

  --------------------------------------------------------------------------
  function CmdMoveOverNight2Current( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    HeadData    Schema_GPSys.tMemoOrder;
    DealOper    Schema_GPSys.tblDealOper;
    nSuma       number;
    nUniqCode   integer;
    nCurExpo    integer;
    nIDExpo     integer;
    dToDate     date;
    dSchDate    date;
    bOldState   boolean;
    bDummy      boolean;
    bRet        boolean;
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_DocSys.DOCSYS_SAVEINIQ.UseQueueBatch1;
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet  := aParamEntities3D.first is not null;

    if ( bRet ) then
      if ( aParamEntities3D( aParamEntities3D.first ).nRowType = 1 ) then
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( aParamEntities3D.first ).sValue, aRowValues ) and
                     aRowValues.count >= 1 and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUniqCode ) and
                     ( ( not aRowValues.exists( 2 ) ) or
                      Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 2 ), dToDate ) );
      end if;

      if ( bRet ) then
        dSchDate   := Schema_RA.GPC_Tools.GetSchDate( null );
        dToDate    := nvl( dToDate, dSchDate );
        bOldState  := Expo.SetSkipLimit( Expo.ModeSkip_Limit, true );

        for recDepo in ( select a.*
                           from DEPOSIT_EXPO a
                          where a.STATUS = Loans.LoanStat_Active and
                                ( nUniqCode = -1 or
                                 a.UNIQCODE = nUniqCode ) and
                                exists
                                  (select 1
                                     from Schema_GPSys.CONFSYSTEM g
                                    where g.FLDSECTION = 'EXPOSITION' and
                                          g.FLDITEM = 'OVERNIGHT_DEPO_TYPES' and
                                          g.UNIQCODE = Schema_GPSys.OraGPSys.defUniqCode_All and
                                          g.FLDVALUE like '%&' || to_char( a.TYPE_EXPO ) || '&%') ) loop
          bRet      := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockMoveOverNight2Current, recDepo.ID_EXPO );

          if ( bRet ) then
            select nvl( sum( AMOUNT ), 0 )
              into nSuma
              from EXPO_MOVES
             where ID_EXPO = recDepo.ID_EXPO and
                   VALIOR = dToDate and
                   DT_KT = 'K';

            if ( nSuma = 0 ) then
              nIDExpo   := Expo.GetExpo4Lihvi( recDepo.ID_EXPO );
              bRet      := nIDExpo > 0 and
                           nIDExpo != recDepo.ID_EXPO;

              if ( bRet ) then
                HeadData  := null;
                bRet      := Calclih.ExpoOlih( recDepo.ID_EXPO, dToDate, true, false, false, HeadData, null, false, false, false );

                if ( bRet ) then
                  nSuma  := Expo.ExpoSumAvailable( recDepo.ID_EXPO, dToDate );

                  if ( nSuma > 0 ) then
                    HeadData                       := Schema_GPSys.tMemoOrder( null,
                                                                               recDepo.UNIQCODE,
                                                                               Schema_GPSys.MLng.Str2( 'Прехвърляне на OverNight експозиция по обслужваща разплащателна експозиция',
                                                                                                       Schema_GPSys.MLng.ctxAccounting,
                                                                                                       Schema_GPSys.MLng.lngBG
                                                                                                      ),
                                                                               dSchDate,
                                                                               null,
                                                                               null,
                                                                               recDepo.ID_CUST,
                                                                               null,
                                                                               null,
                                                                               null,
                                                                               sysdate
                                                                              );
                    DealOper                       := Schema_GPSys.tblDealOper( );
                    --
                    DealOper.extend;
                    DealOper( DealOper.last )      := Schema_GPSys.tDealOper( Sch_Free,
                                                                              recDepo.ID_EXPO,
                                                                              nSuma,
                                                                              Schema_GPSys.XchgRates.GetExactSum( nSuma,
                                                                                                                  recDepo.UNIQCODE,
                                                                                                                  dToDate,
                                                                                                                  recDepo.CODVAL,
                                                                                                                  Schema_GPSys.HeadExpo.IDExpo2CodVal( nIDExpo ),
                                                                                                                  Schema_GPSys.XchgRates.XchgRateType_BuyDevSelDev
                                                                                                                 ),
                                                                              nIDExpo,
                                                                              dToDate,
                                                                              dToDate,
                                                                              recDepo.ID_EXPO,
                                                                              'F',
                                                                              null,
                                                                              null,
                                                                              null,
                                                                              0,
                                                                              null
                                                                             );
                    bRet                           := GenerateMemoOrder( HeadData, DealOper );
                  end if;
                end if;
              else
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'ID_EXPO';
                aParams( 1 ).ML_VALUE  := to_char( recDepo.ID_EXPO );
                Schema_RA.GPC_RA.RespSetErrorText( 'Липсва обслужваща разплащателна експозиция към депозитна експозиция $ID_EXPO$',
                                                   Schema_GPSys.MLng.ctxAccounting,
                                                   Schema_GPSys.MLng.lngBG,
                                                   aParams
                                                  );
              end if;
            end if;

            bDummy  := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockMoveOverNight2Current, recDepo.ID_EXPO );
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( recDepo.ID_EXPO );
            Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи експозиция $ID_EXPO$', Schema_GPSys.MLng.ctxAccounting, Schema_GPSys.MLng.lngBG, aParams );
          end if;

          if ( bRet ) then
            commit;
          else
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ID_EXPO';
            aParams( 1 ).ML_VALUE  := to_char( recDepo.ID_EXPO );
            Schema_RA.GPC_Tools.WriteErrorMsg( Schema_GPSys.MLng.Str2( 'Обработка на OverNight експозиция $ID_EXPO$',
                                                                       Schema_GPSys.MLng.ctxAccounting,
                                                                       Schema_GPSys.MLng.lngBG,
                                                                       aParams
                                                                      )
                                              );
            rollback;
          end if;

          nCurExpo  := nCurExpo + 1;
          bRet      := Schema_RA.GPC_RA.ChkStopField( nCurExpo, nCurExpo );
          exit when not bRet;
        end loop;

        if ( bOldState is not null ) then
          bDummy  := Expo.SetSkipLimit( Expo.ModeSkip_Limit, bOldState );
        end if;
      end if;
    end if;

    return bRet;
  end CmdMoveOverNight2Current;

  ------------------------------------------------------------------------------------------
  procedure XX is
    oRespRow  Schema_GPSys.GPC_Parser.trParamEntity3D;
    oResp     Schema_GPSys.GPC_Parser.taParamEntities3D;
    bRet      boolean;
  begin
    /*
      Schema_RA.GPC_RA.ClearResponce;
      oRespRow.nRowType         := 1;
      oRespRow.sValue           := '100' || '&' || '"TEXT ORDER"' || '&' || '20030411' || '&' || '&' || '20';
      oResp( oResp.count + 1 )  := oRespRow;
      oRespRow.nRowType         := 2;
      oRespRow.sValue           := '10' || '&' || '1' || '&' || '22.33' || '&' || '22.33' || '&' || '3' || '&' || '20030411' || '&' || '20030411' || '&' || '1';
      oResp( oResp.count + 1 )  := oRespRow;
      bRet                      := CmdSaveMemoOrder( oResp );
  */
    ----
    /*
        oRespRow.nRowType         := 1;
        oRespRow.sValue           := '100' ||
                                     '&' ||
                                     '75' ||
                                     '&' ||
                                     '"BGN"' ||
                                     '&' ||
                                     '1.00000000' ||
                                     '&' ||
                                     '20030901' ||
                                     '&' ||
                                     '"T"' ||
                                     '&' ||
                                     '102' ||
                                     '&' ||
                                     '79' ||
                                     '&' ||
                                     '"BGN"' ||
                                     '&' ||
                                     '1.00000000' ||
                                     '&' ||
                                     '20030901' ||
                                     '&' ||
                                     '"T"' ||
                                     '&' ||
                                     '20030901' ||
                                     '&' ||
                                     '"1"' ||
                                     '&';
        oResp( oResp.count + 1 )  := oRespRow;
        bRet                      := CmdInBankPaySave( oResp );
      */
    Schema_RA.GPC_RA.ClearResponce;
    Schema_RA.GPC_RA.nCurrentUserID  := 9;
    Schema_RA.GPC_RA.bDebug          := true;
    oRespRow.nRowType                := 1;
    oRespRow.sValue                  := '';
    oResp( oResp.count + 1 )         := oRespRow;
    oRespRow.nRowType                := 2;
    oRespRow.sValue                  := '';
    oResp( oResp.count + 1 )         := oRespRow;
    bRet                             := CmdSaveMemoOrder( oResp );
    Schema_RA.GPC_RA.DisplayResponce( bRet );
  end XX;

  --------------------------------------------------------------------------------
  procedure YY is
    oRespRow  Schema_GPSys.GPC_Parser.trParamEntity3D;
    oResp     Schema_GPSys.GPC_Parser.taParamEntities3D;
    bRet      boolean;
  begin
    Schema_RA.GPC_RA.ClearResponce;
    oRespRow.nRowType         := 1;
    oRespRow.sValue           := '';
    oResp( oResp.count + 1 )  := oRespRow;
    bRet                      := CmdExpoCalcLihvi( oResp );
    Schema_RA.GPC_RA.DisplayResponce( bRet );
  end YY;

  --------------------------------------------------------------------------------
  procedure ZZ is
    oRespRow  Schema_GPSys.GPC_Parser.trParamEntity3D;
    oResp     Schema_GPSys.GPC_Parser.taParamEntities3D;
    lRet      boolean;
  begin
    oRespRow.nRowType         := 1;
    oRespRow.sValue           := '32' ||
                                 '&' ||
                                 '84' ||
                                 '&' ||
                                 '20.00000000' ||
                                 '&' ||
                                 '20030901' ||
                                 '&' ||
                                 '4' ||
                                 '&' ||
                                 '92' ||
                                 '&' ||
                                 '20.00000000' ||
                                 '&' ||
                                 '20030901' ||
                                 '&' ||
                                 '20030901' ||
                                 '&' ||
                                 '"dsad"' ||
                                 '&' ||
                                 '20.00000000' ||
                                 '&' ||
                                 '"EUR"' ||
                                 '&';
    oResp( oResp.count + 1 )  := oRespRow;
    lRet                      := CmdHierarchyPay( oResp );
    Schema_RA.GPC_RA.DisplayResponce( lRet );
  /*if ( lRet ) then
     dbms_output.put_line( 'Ok' );
   else
     dbms_output.put_line( 'Fail' );
   end if;*/
  end ZZ;

  --------------------------------------------------------------------------------
  procedure ll is
    oRespRow  Schema_GPSys.GPC_Parser.trParamEntity3D;
    oResp     Schema_GPSys.GPC_Parser.taParamEntities3D;
    bRet      boolean;
    aIDMoves  Schema_GPSys.OraGPSys.aIntegers;
  begin
    Schema_RA.GPC_RA.ClearResponce;
    --oRespRow.nRowType         := 1;
    --oRespRow.sValue           := '"DEL"' || '&' || '2' || '&' || '9' || '&' || '1' || '&' || '100' || '&';
    --oResp( oResp.count + 1 )  := oRespRow;
    /* oRespRow.nRowType         := 2;
     oRespRow.sValue           := '"EUR"' || '&' || '1.95583000' || '&';
     oResp( oResp.count + 1 )  := oRespRow;
     oRespRow.sValue           := '"USD"' || '&' || '1.72302000' || '&';
     oResp( oResp.count + 1 )  := oRespRow;*/
    bRet      := HierarchySaveMemOrder( aIDMoves,
                                        100,
                                        91,
                                        Schema_GPSys.XchgRates.GetExactSum( 20,
                                                                            100,
                                                                            to_date( '20030901', 'yyyymmdd' ),
                                                                            'EUR',
                                                                            Schema_GPSys.HeadExpo.IDExpo2CodVal( 91 ),
                                                                            Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                           ),
                                        to_date( '20030901', 'yyyymmdd' ),
                                        103,
                                        94,
                                        Schema_GPSys.XchgRates.GetExactSum( 20,
                                                                            103,
                                                                            to_date( '20030901', 'yyyymmdd' ),
                                                                            'EUR',
                                                                            Schema_GPSys.HeadExpo.IDExpo2CodVal( 94 ),
                                                                            Schema_GPSys.XchgRates.XchgRateType_Fixing
                                                                           ),
                                        to_date( '20030901', 'yyyymmdd' ),
                                        Schema_RA.GPC_Tools.GetSchDate( null ),
                                        'Осчетоводяване на транзакция ',
                                        Schema_GPSys.XchgRates.GetExactSum( 20, null, to_date( '20030901', 'yyyymmdd' ), '20', 'EUR', Schema_GPSys.XchgRates.XchgRateType_Fixing ),
                                        'EUR',
                                        null
                                       );
    Schema_RA.GPC_RA.DisplayResponce( bRet );
  end ll;

  --------------------------------------------------------------------------------
  procedure DisplayDealOper( dbgDealOper in Schema_GPSys.tDealOper ) is
  begin
    dbms_output.put_line( 'DEAL_TYPE:=' ||
                          dbgDealOper.DEAL_TYPE ||
                          ', EXPO_DT:=' ||
                          dbgDealOper.EXPO_DT ||
                          ', AMOUNT_DT:=' ||
                          dbgDealOper.AMOUNT_DT ||
                          ', AMOUNT_KT:=' ||
                          dbgDealOper.AMOUNT_KT ||
                          ', EXPO_KT:=' ||
                          dbgDealOper.EXPO_KT ||
                          ', VALIOR_DT:=' ||
                          to_char( dbgDealOper.VALIOR_DT, 'yyyy-mm-dd' )||
                          ', VALIOR_KT:=' ||
                          to_char( dbgDealOper.VALIOR_KT, 'yyyy-mm-dd' )||
                          ', MAIN_EXPO:=' ||
                          dbgDealOper.MAIN_EXPO ||
                          ', USE_TAXES:=' ||
                          dbgDealOper.USE_TAXES
                         );
  end DisplayDealOper;

  --------------------------------------------------------------------------------
  procedure DisplayDealOpers( dbgDealOpers in Schema_GPSys.tblDealOper ) is
    ii  pls_integer;
  begin
    ii  := dbgDealOpers.first;

    while ( ii is not null ) loop
      DisplayDealOper( dbgDealOpers( ii ) );
      ii  := dbgDealOpers.next( ii );
    end loop;
  end DisplayDealOpers;

  ------------------------------------------------------
  function CmdRMCreditSave( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues   Schema_GPSys.GPC_Parser.taParamStrings;
    oDoc         Schema_GPSys.DocSysIQType;
    RecRMCredit  nom_rmcred%rowtype;
    --    RecBaseNull  nom_rmcred%rowtype;
    jj           pls_integer;
    sCmdName     varchar2( 64 ) := 'RMCredit';
    bRet         boolean := false;
    nEdit        pls_integer;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

    if ( aParamEntities3D.count > 0 ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        --        RecBaseIntr  := RecBaseNull;
        oDoc      := Schema_GPSys.DocSysIQType( );
        bRet      := aParamEntities3D( ii ).nRowType = 1 and
                     Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nEdit ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), RecRMCredit.NOM_ID ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), RecRMCredit.NOM_NAME ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), RecRMCredit.EMAIL );

        if ( nEdit = 1 ) then
          update nom_rmcred
             set NOM_NAME  = RecRMCredit.NOM_NAME,
                 EMAIL     = RecRMCredit.EMAIL
           where NOM_ID = RecRMCredit.NOM_ID;

          bRet  := sql%rowcount > 0;
        else
          begin
            insert into nom_rmcred(
                          NOM_ID,
                          NOM_NAME,
                          EMAIL
                        )
                 values ( RecRMCredit.NOM_ID,
                          RecRMCredit.NOM_NAME,
                          RecRMCredit.EMAIL
                         );

            bRet  := sql%rowcount > 0;
          exception
            when dup_val_on_index then
              Schema_RA.GPC_RA.RespSetErrorText( 'Дублиращ се номер', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
              bRet  := false;
          end;
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdRMCreditSave;

  -------------------------------------
  function CmdRMCreditFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nUserID     integer;
    nIDCust     integer;
    sData       varchar2( 4000 );
    bRet        boolean := false;
  begin
    --    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри' );
    /*
        if ( aParamEntities3D.count = 1 ) then
          bRet  := aParamEntities3D( 1 ).nRowType = 1                                        and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                   aRowValues.count >= 1                                                     and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nUserID )                 and
                   nUserID > 0;
        end if;
    */
    Schema_GPSys.GPC_Parser.RespAddTable( 1 );

    for rec in ( select *
                   from nom_rmcred ) loop
      sData     := null;
      bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rec.NOM_ID, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rec.NOM_NAME, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rec.EMAIL, sData ) and
                   true;

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddRow( sData );
      end if;
    end loop;

    return bRet;
  end CmdRMCreditFind;
--------------------------------------------------------------------------------
end Cmd_Expo;
/