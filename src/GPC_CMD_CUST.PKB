create or replace package body GPC_Cmd_Cust is
  --------------------------------------------------------------------------------
  defShareholders_NotConnected    constant varchar2( 1 ) := 'F';
  defShareholders_Interconnected  constant varchar2( 1 ) := 'T';
  defShareholders_Indirect        constant varchar2( 1 ) := 'I';
  --
  defCustomsSearchMode_OR         constant varchar2( 2 ) := 'OR';
  defCustomsSearchMode_AND        constant varchar2( 3 ) := 'AND';
  --
  nINI_ReportMaxRetRows                    integer;

  --------------------------------------------------------------------------------
  type trShareholders is record(
    ID_CUST              CUSTOMS.ID%type,
    SHAREHOLDER_ID_CUST  CUSTOMS.ID%type,
    SHAREHOLDER_TYPE     CUSTOMS.CLITYPE%type,
    SHAREHOLDER_NAME     varchar2( 4000 ),
    SHAREHOLDER_EIK      varchar2( 30 ),
    OWNERSHIP            number,
    HIERARCHY_LEVEL      pls_integer,
    TRACE_STRING         varchar2( 4000 ),
    INTERCONNECTED       varchar2( 1 )
  );

  type tаShareholders is table of trShareholders
    index by binary_integer;

  type trCustomsSearchParams is record(
    CustRec                 CUSTOMS%rowtype,
    sCompanyAddress         varchar2( 1000 ),
    sURL                    varchar2( 1000 ),
    sPart                   varchar2( 200 ),
    sSchAcc                 varchar2( 64 ),
    sDeinost                varchar2( 20 ),
    sMCC                    varchar2( 20 ),
    sBankAcc                varchar2( 10 ),
    sHaveCustNo             varchar2( 1 ),
    sCheckExactBULSTAT      varchar2( 1 ),
    sNotChkUniqCode         varchar2( 1 ),
    sCustomsSearchMode      varchar2( 3 ),
    nUniqCode               integer,
    nMainCode               integer,
    nCustNo                 integer,
    nIDExpo                 integer,
    nPartialSeekEGNLK       integer,
    dRegDateFr              date,
    dRegDateTo              date,
    bFindInCreditoiskateli  boolean,
    sPersIDDocNumber        varchar2( 200 ),
    sIdentifierAny          varchar2( 50 ),
    sAlphabetAny            varchar2( 1 )
  );

  --------------------------------------------------------------------------------
  function INI_ReportMaxRetRows
    return integer is
  begin
    if ( nINI_ReportMaxRetRows is null ) then
      nINI_ReportMaxRetRows  := to_number( nvl( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'ReportMaxRetRows', '3000' ), '3000' ) );
    end if;

    return nINI_ReportMaxRetRows;
  end INI_ReportMaxRetRows;

  --------------------------------------------------------------------------------
  procedure AddIDCustChOperRows(
    oDoc       in out Schema_GPSys.DocSysIQType,
    sCmdName   in     varchar2,
    sOper      in     varchar2,
    nRowType   in     pls_integer,
    nState     in     pls_integer,
    nDocLevel  in out pls_integer,
    nDocList   in out pls_integer,
    IDCust     in     integer,
    nDocType      out pls_integer,
    nFldType      out pls_integer
  ) is
    bDummy  boolean;
    sTemp   varchar2( 100 );
  begin
    if ( nRowType = 2 or
        nRowType = 3 or
        nRowType = 4 ) then
      sTemp  := 'Dosie';
    elsif ( nRowType = 5 ) then
      sTemp  := 'CustNumber';
    elsif ( nRowType = 6 ) then
      sTemp  := 'Repres';
    elsif ( nRowType = 7 ) then
      sTemp  := 'Proxy';
    elsif ( nRowType = 8 ) then
      sTemp  := 'Contact';
    elsif ( nRowType = 9 ) then
      sTemp  := 'Link';
    elsif ( nRowType = 10 ) then
      sTemp  := 'Code';
    elsif ( nRowType = 11 ) then
      sTemp  := 'Pic';
    elsif ( nRowType = 13 ) then
      sTemp  := 'Stock';
    elsif ( nRowType = 14 ) then
      sTemp  := 'Rival';
    elsif ( nRowType = 15 ) then
      sTemp  := 'Voucher';
    elsif ( nRowType = 16 ) then
      sTemp  := 'Worker';
    elsif ( nRowType = 17 ) then
      sTemp  := 'ListAddresses';
    elsif ( nRowType = 18 ) then
      sTemp  := 'DopInformation';
    elsif ( nRowType = 19 ) then
      sTemp  := 'Roles';
    elsif ( nRowType = 20 ) then
      sTemp  := 'DanInfo';
    elsif ( nRowType = 21 ) then
      sTemp  := 'AECountry';
    elsif ( nRowType = 22 ) then
      sTemp  := 'AEDanInfo';
    elsif ( nRowType = 23 ) then
      sTemp  := 'AEControlPers';
    elsif ( nRowType = 24 ) then
      sTemp  := 'IBANList';
    elsif ( nRowType = 25 ) then
      sTemp  := 'URLs';
    end if;

    if ( nState != nRowType ) then
      nDocList   := nDocLevel + 1;
      nDocLevel  := nDocLevel + 1;
      bDummy     := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'CustSave' || sOper, '1.' || sTemp, 1, nDocList );
    end if;

    nDocLevel  := nDocLevel + 1;
    bDummy     := Schema_GPSys.OraGPSys.AddDocRowListDesc( oDoc, nDocList, nDocLevel );
    bDummy     := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, nRowType || '.ChOper', nDocLevel, Schema_RA.GPC_RA.nCurrentUserID );
    bDummy     := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, nRowType || '.IDCust', nDocLevel, IDCust );

    if ( bDummy ) then
      nDocType  := oDoc( oDoc.count ).DocType;
      nFldType  := oDoc( oDoc.count ).FieldType;
    else
      nDocType  := null;
      nFldType  := null;
    end if;
  end AddIDCustChOperRows;

  --------------------------------------------------------------------------------
  function CmdCustomsSave(
    aParamEntities3D  in Schema_GPSys.GPC_Parser.taParamEntities3D,
    bChkInBase        in boolean default true,
    nInQueue          in integer default Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work,
    bRegular          in boolean default true,
    bResp             in boolean default true,
    bSkipMvrIn        in boolean default false
  )
    return boolean is
    type tCustRoles is table of varchar2( 1 )
      index by varchar2( 40 );

    oDoc                   Schema_GPSys.DocSysIQType;
    aRowValues             Schema_GPSys.GPC_Parser.taParamStrings;
    aIDs                   Schema_GPSys.OraGPSys.aNumbers;
    aCustRoles             tCustRoles;
    aRowIDs                Schema_GPSys.OraGPSys.aNumbers;
    CustData               GPC_Customs.recCustData;
    rLogRegister           Schema_RA.REQLOG_REGISTER%rowtype;
    rCust                  CUSTOMS%rowtype;
    rDeletedCust           CUST_DELETED_DATA%rowtype;
    recCustCredInfo        CUST_CREDITINFO%rowtype;
    handle                 varchar2( 128 );
    sOper                  varchar2( 10 );
    sCmdName               varchar2( 64 );
    sData                  varchar2( 2000 );
    sAction                varchar2( 2000 );
    sRole                  varchar2( 40 );
    sDeinost               varchar2( 20 );
    sLCard                 varchar2( 200 );
    nState                 pls_integer;
    ii                     pls_integer;
    jj                     pls_integer;
    nRowType               pls_integer;
    nDocLevel              pls_integer;
    nDocList               pls_integer;
    nDocNumList            pls_integer;
    nCustIDPos             pls_integer;
    nDosieIDPos            pls_integer;
    nRelifEnttyIDPos       pls_integer;
    nSkipInactCust         integer := 0;
    nUniqCode              integer;
    nMainCode              integer;
    nCustNo                integer;
    nMVRCount              integer;
    nNumDocType            pls_integer;
    nNumFldType            pls_integer;
    nRepDocType            pls_integer;
    nRepFldType            pls_integer;
    nPxyDocType            pls_integer;
    nPxyFldType            pls_integer;
    nCntDocType            pls_integer;
    nCntFldType            pls_integer;
    nLnkDocType            pls_integer;
    nLnkFldType            pls_integer;
    nPicDocType            pls_integer;
    nPicFldType            pls_integer;
    nCodeDocType           pls_integer;
    nCodeFldType           pls_integer;
    nStockDocType          pls_integer;
    nStockFldType          pls_integer;
    nRivalDocType          pls_integer;
    nRivalFldType          pls_integer;
    nVoucherDocType        pls_integer;
    nVoucherFldType        pls_integer;
    nWorkerDocType         pls_integer;
    nWorkerFldType         pls_integer;
    nAddressDocType        pls_integer;
    nAddressFldType        pls_integer;
    nDopInfoDocType        pls_integer;
    nDopInfoFldType        pls_integer;
    nRolesDocType          pls_integer;
    nRolesFldType          pls_integer;
    nDanInfoDocType        pls_integer;
    nDanInfoFldType        pls_integer;
    nAECountryDocType      pls_integer;
    nAECountryFldType      pls_integer;
    nAEDanInfoDocType      pls_integer;
    nAEDanInfoFldType      pls_integer;
    nAEControlPersDocType  pls_integer;
    nAEControlPersFldType  pls_integer;
    nIBANsDocType          pls_integer;
    nIBANsFldType          pls_integer;
    nURLsDocType           pls_integer;
    nURLsFldType           pls_integer;
    bBlock                 boolean := false;
    bDummy                 boolean;
    bRet                   boolean := true;
    bLogCust               boolean := false;
    bCustCredInfo          boolean := false;
    bSkipMVR               boolean := bSkipMvrIn;
    aParams                Schema_RA.GPC_RA.tblErrParams;
  begin
    handle  := Schema_GPSys.OraGPSys.DbmsLock_AllocateUnique( 'Schema_GPSys.HEADEXPO_LOCK' );
    bRet    := dbms_lock.REQUEST( handle, dbms_lock.X_MODE, 0 ) = 0;

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      oDoc                                   := Schema_GPSys.DocSysIQType( );
      nDocLevel                              := 1;
      nState                                 := 0;
      ii                                     := aParamEntities3D.first;

      while ( ii is not null and
             bRet ) loop
        nRowType  := aParamEntities3D( ii ).nRowType;
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues );

        if ( bRet ) then
          sCmdName  := 'CustSave';

          if ( nRowType = 1 ) then -- общи данни
            bRet       := nState = 0 and
                          aRowValues.count >= 13 and
                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), sOper ) and
                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), rCust.CLITYPE ) and
                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), rCust.FTYPE ) and
                          Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 5 ), nUniqCode ) and
                          Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 6 ), nCustNo ) and
                          Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 7 ), rCust.EMPLOYER ) and
                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 8 ), rCust.EXT_NUMBER ) and
                          Schema_GPSys.GPC_Parser.ReadMoney( aRowValues( 9 ), rCust.PRIVRES_VAL, rCust.PRIVRES_AMN ) and
                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 10 ), rCust.CUST_SEGMENT ) and
                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 11 ), rCust.PROFIT_CENTER ) and
                          Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 12 ), rCust.RELATIONSHIPMGR ) and
                          Schema_GPSys.GPC_Parser.ReadString( aRowValues( 13 ), rCust.DDS_VIN );

            if ( bRet and
                aRowValues.exists( 14 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 14 ), rCust.fldACTIVE );
            end if;

            if ( bRet and
                aRowValues.exists( 20 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 15 ), rCust.PREGLED_DATE ) and
                           Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 16 ), rCust.MON_DATE ) and
                           Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 17 ), rCust.RATING ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 19 ), rCust.RATING_TYPE ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 18 ), rCust.MON_TYPE ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 20 ), rCust.RISK_SEG );
            end if;

            if ( bRet and
                aRowValues.exists( 21 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 21 ), rCust.RISK_MANAGEMENT );
            end if;

            if ( bRet and
                aRowValues.exists( 22 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 22 ), rCust.RISK_MANAGER );
            end if;

            if ( bRet and
                aRowValues.exists( 23 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 23 ), rCust.HAND_RISK_MANAGE );
            end if;

            if ( bRet and
                aRowValues.exists( 24 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 24 ), rCust.EXPO_CLASS );
            end if;

            if ( bRet and
                aRowValues.exists( 25 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 25 ), rCust.CREDCLASSIF );
            end if;

            if ( bRet and
                aRowValues.exists( 27 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 26 ), rCust.MONTHLY_INCOME ) and
                           Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 27 ), rCust.YEARLY_INCOME );
            end if;

            if ( bRet and
                aRowValues.exists( 28 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 28 ), rCust.TYPEREGISTER );
            end if;

            if ( bRet and
                aRowValues.exists( 29 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 29 ), rCust.IS_ONLINE );
            end if;

            if ( bRet and
                aRowValues.exists( 35 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 30 ), rCust.PROV_PD1Y ) and
                           Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 31 ), rCust.PROV_PDLT ) and
                           Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 32 ), rCust.PROV_LGD ) and
                           Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 33 ), rCust.PROV_PHASE ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 34 ), rCust.PROV_RATING ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 35 ), rCust.PROV_PUBLISHER );
            end if;

            if ( bRet and
                aRowValues.exists( 37 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 36 ), rCust.PROV_FUND2ASSET ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 37 ), rCust.PROV_DSCR );
            end if;

            if ( bRet and
                aRowValues.exists( 38 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 38 ), rCust.PS_CODE );
            end if;

            if ( bRet and
                aRowValues.exists( 39 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 39 ), rCust.TAX_TYPE );
            end if;

            if ( bRet and
                aRowValues.exists( 41 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 40 ), rCust.MARKETING_USER ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 41 ), rCust.MARKETING_PARTNER );
            end if;

            if ( bRet and
                aRowValues.exists( 42 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 42 ), rCust.ID_AGENT );
            end if;

            if ( bRet and
                aRowValues.exists( 44 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 43 ), rCust.YEARLY_EXPENSE ) and
                           Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 44 ), rCust.ALL_CREDIT_DUES );
            end if;

            if ( bRet and
                aRowValues.exists( 46 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 45 ), rCust.RELIF_ENTTY_TYPE ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 46 ), rCust.RELIF_ENTTY_ID );
            end if;

            if ( bRet and
                aRowValues.exists( 48 ) ) then
              bRet      := Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 47 ), rDeletedCust.LAST_DECLINE_DATE ) and
                           Schema_GPSys.GPC_Parser.ReadString( aRowValues( 48 ), rDeletedCust.DISPUTE );
            end if;

            if ( bRet and
                aRowValues.exists( 49 ) ) then
              bRet  := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 49 ), rCust.NKID2025 );
            end if;

            nMainCode  := GPC_Customs.UniqCode2MainCode( nUniqCode );

            if ( rCust.EXT_NUMBER is null and
                nCustNo > 0 and
                Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'CUSTNO2EXTNUM', 'F' ) ) ) then
              rCust.EXT_NUMBER  := to_char( nCustNo );
            end if;

            if ( bRet ) then
              sCmdName  := sCmdName || sOper;
              nState    := nRowType;
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ChOper', nDocLevel, Schema_RA.GPC_RA.nCurrentUserID );
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.Employer', nDocLevel, rCust.Employer );
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Ext_Number', nDocLevel, rCust.EXT_NUMBER );
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdMoney( oDoc, sCmdName, '1.ПривлеченРесурс', nDocLevel, rCust.PRIVRES_VAL, rCust.PRIVRES_AMN );
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Сегмент', nDocLevel, rCust.CUST_SEGMENT );
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.ПрофитЦентър', nDocLevel, rCust.PROFIT_CENTER );
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.RelationshipManager', nDocLevel, rCust.RELATIONSHIPMGR );
              bDummy    := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.DDS_VIN', nDocLevel, rCust.DDS_VIN );

              if ( aRowValues.exists( 14 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Активен', nDocLevel, nvl( rCust.fldACTIVE, GPC_Customs.CustStat_Activen ) );
              else
                if ( sOper = 'NEW' ) then
                  bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Активен', nDocLevel, GPC_Customs.CustStat_Activen );
                end if;
              end if;

              if ( aRowValues.exists( 20 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, sCmdName, '1.Дата на преглед', nDocLevel, rCust.PREGLED_DATE );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdDate( oDoc, sCmdName, '1.Дата на мониторинг', nDocLevel, rCust.MON_DATE );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.Рейтинг', nDocLevel, rCust.RATING );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Тип на рейтинга', nDocLevel, rCust.RATING_TYPE );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Вид мониторинг', nDocLevel, rCust.MON_TYPE );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Риск сегментация', nDocLevel, rCust.RISK_SEG );
              end if;

              if ( aRowValues.exists( 21 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Тип управление', nDocLevel, rCust.RISK_MANAGEMENT );
              end if;

              if ( aRowValues.exists( 22 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.Риск мениджър', nDocLevel, rCust.RISK_MANAGER );
              end if;

              if ( aRowValues.exists( 23 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Ръчно управление ТУ', nDocLevel, rCust.HAND_RISK_MANAGE );
              end if;

              if ( aRowValues.exists( 24 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.Класове експозиции', nDocLevel, rCust.EXPO_CLASS );
              end if;

              if ( aRowValues.exists( 25 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.CREDCLASSIF', nDocLevel, rCust.CREDCLASSIF );
              end if;

              if ( aRowValues.exists( 27 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.MonthlyIncome', nDocLevel, rCust.MONTHLY_INCOME );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.YearlyIncome', nDocLevel, rCust.YEARLY_INCOME );
              end if;

              if ( aRowValues.exists( 28 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.TYPEREGISTER', nDocLevel, rCust.TYPEREGISTER );
              end if;

              if ( aRowValues.exists( 29 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.IS_ONLINE', nDocLevel, rCust.IS_ONLINE );
              end if;

              if ( aRowValues.exists( 35 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.PROV_PD1Y', nDocLevel, rCust.PROV_PD1Y );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.PROV_PDLT', nDocLevel, rCust.PROV_PDLT );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.PROV_LGD', nDocLevel, rCust.PROV_LGD );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.PROV_PHASE', nDocLevel, rCust.PROV_PHASE );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.PROV_RATING', nDocLevel, rCust.PROV_RATING );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.PROV_PUBLISHER', nDocLevel, rCust.PROV_PUBLISHER );
              end if;

              if ( aRowValues.exists( 37 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.PROV_FUND2ASSET', nDocLevel, rCust.PROV_FUND2ASSET );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.PROV_DSCR', nDocLevel, rCust.PROV_DSCR );
              end if;

              if ( aRowValues.exists( 38 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.PS_CODE', nDocLevel, rCust.PS_CODE );
              end if;

              if ( aRowValues.exists( 39 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.TAX_TYPE', nDocLevel, rCust.TAX_TYPE );
              end if;

              if ( aRowValues.exists( 41 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.MARKETING_USER', nDocLevel, rCust.MARKETING_USER );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.MARKETING_PARTNER', nDocLevel, rCust.MARKETING_PARTNER );
              end if;

              if ( aRowValues.exists( 42 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.ID_AGENT', nDocLevel, rCust.ID_AGENT );
              end if;

              if ( aRowValues.exists( 44 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.YearlyExpense', nDocLevel, rCust.YEARLY_EXPENSE );
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, sCmdName, '1.AllCreditDues', nDocLevel, rCust.ALL_CREDIT_DUES );
              end if;

              if ( aRowValues.exists( 46 ) ) then
                bDummy            := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.RelifEnttyType', nDocLevel, rCust.RELIF_ENTTY_TYPE );
                bDummy            := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.RelifEnttyID', nDocLevel, rCust.RELIF_ENTTY_ID );
                nRelifEnttyIDPos  := oDoc.count;
              end if;

              if ( aRowValues.exists( 49 ) ) then
                bDummy  := Schema_GPSys.OraGPSys.AddDocRowFromCmdString( oDoc, sCmdName, '1.NKID2025', nDocLevel, rCust.NKID2025 );
              end if;
            end if;
          elsif ( nRowType = 2 or
                 nRowType = 3 or
                 nRowType = 4 ) then -- гражданин/фирма/банка
            bRet    := nState = 1;

            if ( nRowType = 2 ) then
              sCmdName  := sCmdName || 'Citizen';
            elsif ( nRowType = 3 ) then
              sCmdName  := sCmdName || 'Firm';
            elsif ( nRowType = 4 ) then
              sCmdName  := sCmdName || 'Bank';
            end if;

            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nNumDocType, nNumFldType );

            if ( nNumDocType is not null ) then
              nDosieIDPos  := oDoc.count;
            end if;

            nState  := nRowType;
          elsif ( nRowType = 5 ) then -- кл.номера
            bRet         := ( sOper = 'EDT' and
                             nState = 1 ) or
                            nState = 2 or
                            nState = 3 or
                            nState = 4 or
                            nState = 5;
            sCmdName     := sCmdName || 'Numbers';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nNumDocType, nNumFldType );
            nDocNumList  := nDocList;
            nState       := nRowType;
          elsif ( nRowType = 6 ) then -- представители
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6;
            sCmdName  := sCmdName || 'Repres';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nRepDocType, nRepFldType );
            nState    := nRowType;
          elsif ( nRowType = 7 ) then -- пълномощници
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7;
            sCmdName  := sCmdName || 'Proxy';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nPxyDocType, nPxyFldType );
            nState    := nRowType;
          elsif ( nRowType = 8 ) then -- лица за контакт
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8;
            sCmdName  := sCmdName || 'Contact';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nCntDocType, nCntFldType );
            nState    := nRowType;
          elsif ( nRowType = 9 ) then -- свързани лица
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9;
            sCmdName  := sCmdName || 'Link';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nLnkDocType, nLnkFldType );
            nState    := nRowType;
          elsif ( nRowType = 10 ) then -- кодове по МФ
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10;
            sCmdName  := sCmdName || 'Code';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nCodeDocType, nCodeFldType );
            nState    := nRowType;
          elsif ( nRowType = 11 ) then -- графична информация
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11;
            sCmdName  := sCmdName || 'Pic';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nPicDocType, nPicFldType );
            nState    := nRowType;
          elsif ( nRowType = 12 ) then -- общи данни
            sCmdName  := sCmdName || sOper;
          elsif ( nRowType = 13 ) then -- акционери
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13;
            sCmdName  := sCmdName || 'Stock';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nStockDocType, nStockFldType );
            nState    := nRowType;
          elsif ( nRowType = 14 ) then -- контрагенти и конкуренти
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14;
            sCmdName  := sCmdName || 'Rival';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nRivalDocType, nRivalFldType );
            nState    := nRowType;
          elsif ( nRowType = 15 ) then -- поръчители
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15;
            sCmdName  := sCmdName || 'Voucher';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nVoucherDocType, nVoucherFldType );
            nState    := nRowType;
          elsif ( nRowType = 16 ) then -- работодатели
            bRet      := ( sOper = 'EDT' and
                          nState = 1 ) or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16;
            sCmdName  := sCmdName || 'Worker';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nWorkerDocType, nWorkerFldType );
            nState    := nRowType;
          elsif ( nRowType = 17 ) then -- списък с адреси
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17;
            sCmdName  := sCmdName || 'Addresses';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nAddressDocType, nAddressFldType );
            nState    := nRowType;
          elsif ( nRowType = 18 ) then -- системна информация (таблица)
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17 or
                         nState = 18;
            sCmdName  := sCmdName || 'DopInfo';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nDopInfoDocType, nDopInfoFldType );
            nState    := nRowType;
          elsif ( nRowType = 19 ) then -- Списък роли
            bRet      := Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), sRole ) and
                         Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), sDeinost ) and
                         true;

            if ( sRole is null and
                sDeinost is null ) then
              bRet  := false;
              Schema_RA.GPC_RA.RespSetErrorText( 'Не са избрани стойности за роля/дейност', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
            else
              sRole  := lpad( nvl( sRole, '0' ), 20, '0' ) || lpad( nvl( sDeinost, '0' ), 20, '0' );

              if ( aCustRoles.exists( sRole ) ) then
                bRet  := false;
                Schema_RA.GPC_RA.RespSetErrorText( 'Дублирана комбинация роля/дейност', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
              else
                aCustRoles( sRole )  := 'T';
              end if;
            end if;

            if ( bRet ) then
              bRet      := nState = 1 or
                           nState = 2 or
                           nState = 3 or
                           nState = 4 or
                           --nState = 5           or
                           nState = 6 or
                           nState = 7 or
                           nState = 8 or
                           nState = 9 or
                           nState = 10 or
                           nState = 11 or
                           nState = 13 or
                           nState = 14 or
                           nState = 15 or
                           nState = 16 or
                           nState = 17 or
                           nState = 18 or
                           nState = 19;
              sCmdName  := sCmdName || 'Roles';
              AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nRolesDocType, nRolesFldType );
              nState    := nRowType;
            end if;
          elsif ( nRowType = 20 ) then -- Данъчна информация
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17 or
                         nState = 19 or
                         nState = 20;
            sCmdName  := sCmdName || 'DanInfo';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nDanInfoDocType, nDanInfoFldType );
            nState    := nRowType;
          elsif ( nRowType = 21 ) then -- Автоматичен обмен - Държави
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17 or
                         nState = 19 or
                         nState = 20 or
                         nState = 21;
            sCmdName  := sCmdName || 'AECountry';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nAECountryDocType, nAECountryFldType );
            nState    := nRowType;
          elsif ( nRowType = 22 ) then -- Автоматичен обмен - Данъчна информация
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17 or
                         nState = 19 or
                         nState = 20 or
                         nState = 21 or
                         nState = 22;
            sCmdName  := sCmdName || 'AEDanInfo';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nAEDanInfoDocType, nAEDanInfoFldType );
            nState    := nRowType;
          elsif ( nRowType = 23 ) then -- Автоматичен обмен - Контролиращи лица
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17 or
                         nState = 19 or
                         nState = 20 or
                         nState = 21 or
                         nState = 22 or
                         nState = 23;
            sCmdName  := sCmdName || 'AEControlPers';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nAEControlPersDocType, nAEControlPersFldType );
            nState    := nRowType;
          elsif ( nRowType = 24 ) then -- Списък IBAN
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17 or
                         nState = 19 or
                         nState = 20 or
                         nState = 21 or
                         nState = 22 or
                         nState = 23 or
                         nState = 24;
            sCmdName  := sCmdName || 'IBANs';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nIBANsDocType, nIBANsFldType );
            nState    := nRowType;
          elsif ( nRowType = 25 ) then -- Списък URL
            bRet      := nState = 1 or
                         nState = 2 or
                         nState = 3 or
                         nState = 4 or
                         --nState = 5           or
                         nState = 6 or
                         nState = 7 or
                         nState = 8 or
                         nState = 9 or
                         nState = 10 or
                         nState = 11 or
                         nState = 13 or
                         nState = 14 or
                         nState = 15 or
                         nState = 16 or
                         nState = 17 or
                         nState = 19 or
                         nState = 20 or
                         nState = 21 or
                         nState = 22 or
                         nState = 23 or
                         nState = 24 or
                         nState = 25;
            sCmdName  := sCmdName || 'URLs';
            AddIDCustChOperRows( oDoc, sCmdName, sOper, nRowType, nState, nDocLevel, nDocList, rCust.id, nURLsDocType, nURLsFldType );
            nState    := nRowType;
          elsif ( nRowType = 26 ) then -- АнаКредит
            bRet           := bRet and
                              Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                              aRowValues.count >= 13 and
                              Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), recCustCredInfo.FLG_BNKRPTCY_IN_GRP ) and
                              Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), recCustCredInfo.LGL_PRCDNG_STTS ) and
                              Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), recCustCredInfo.DT_INTTN_LGL_PRCDNGS ) and
                              Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), recCustCredInfo.ENTRPRS_SZ_CRR ) and
                              Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 5 ), recCustCredInfo.NMBR_EMPLYS ) and
                              Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 6 ), recCustCredInfo.BLNC_SHT_TTL ) and
                              Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 7 ), recCustCredInfo.ANNL_TRNVR ) and
                              Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 8 ), recCustCredInfo.DT_FNNCL_STTMTS ) and
                              Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 9 ), recCustCredInfo.DT_FNNCL_ADT ) and
                              Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 10 ), recCustCredInfo.EQTY ) and
                              Schema_GPSys.GPC_Parser.ReadString( aRowValues( 11 ), recCustCredInfo.EMP_SEC ) and
                              Schema_GPSys.GPC_Parser.ReadString( aRowValues( 12 ), recCustCredInfo.INCM_SRC ) and
                              Schema_GPSys.GPC_Parser.ReadString( aRowValues( 13 ), recCustCredInfo.REASON_FOR_ENTITY_ID_CHANGE ) and
                              ( not aRowValues.exists( 14 ) or
                               Schema_GPSys.GPC_Parser.ReadNumber( aRowValues( 14 ), recCustCredInfo.GROSS_INCM ) );
            nState         := nRowType;
            bCustCredInfo  := true;
          end if;

          jj        := aRowValues.first;

          if ( nRowType = 12 and
              aRowValues( jj ) is not null and
              sOper = 'EDT' ) then
            if ( aRowValues( jj ) = 1 ) then -- Представители
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Repres', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 2 ) then -- Пълномощници
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Proxy', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 3 ) then -- Лица за контакт
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Contact', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 4 ) then -- Свързани лица
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Link', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 5 ) then -- Графична информация
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Pic', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 6 ) then -- Код
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Code', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 7 ) then -- Акционер
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Stock', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 8 ) then -- Контрагент конкурент
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Rival', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 9 ) then -- Поръчител
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Voucher', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 10 ) then -- Работодател
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Worker', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 11 ) then -- Роли
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'Roles', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 12 ) then -- Данъчна информация
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'DanInfo', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 13 ) then -- Автоматичен обмен - Държави
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'AECountry', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 14 ) then -- Автоматичен обмен - Данъчна информация
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'AEDanInfo', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 15 ) then -- Автоматичен обмен - Контролиращи лица
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'AEControlPers', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 16 ) then -- Списък IBAN
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'IBANList', 1, null, bDummy );
            elsif ( aRowValues( jj ) = 17 ) then -- Списък URL
              bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, 1 || '.' || 'URLs', 1, null, bDummy );
            end if;
          end if;

          while ( jj is not null and
                 bRet ) loop
            bRet  := Schema_GPSys.OraGPSys.AddDocRowFromCmd( oDoc, sCmdName, nRowType || '.' || jj, nDocLevel, aRowValues( jj ), bDummy );

            -- EGN, BULSTAT, DANNUMBER, BAE, BIC
            if ( bDummy ) then
              if ( nRowType = 1 ) then
                if ( jj = 2 ) then
                  nCustIDPos  := oDoc.count;
                  rCust.id    := oDoc( nCustIDPos ).nv;
                end if;
              elsif ( nRowType = 2 ) then -- гражданин
                if ( jj = 1 ) then
                  rCust.EGN  := oDoc( oDoc.count ).sv;
                elsif ( jj = 2 ) then
                  rCust.FIRSTNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 3 ) then
                  rCust.MIDLENAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 4 ) then
                  rCust.LASTNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 7 ) then
                  rCust.LICHNAKARTA  := oDoc( oDoc.count ).sv;
                elsif ( jj = 20 ) then
                  rCust.EMAIL  := oDoc( oDoc.count ).sv;
                elsif ( jj = 21 ) then
                  rCust.BULSTAT  := oDoc( oDoc.count ).sv;
                elsif ( jj = 24 ) then
                  rCust.ENCH  := oDoc( oDoc.count ).sv;
                elsif ( jj = 32 ) then
                  rCust.LATINNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 35 ) then
                  rCust.SECTORNA  := oDoc( oDoc.count ).sv;
                elsif ( jj = 36 ) then
                  rCust.OTRASLOVA  := oDoc( oDoc.count ).sv;
                elsif ( jj = 49 ) then
                  rCust.TAX_FOREIGN  := oDoc( oDoc.count ).nv;
                elsif ( jj = 50 ) then
                  rCust.COMMLIH  := oDoc( oDoc.count ).nv;
                elsif ( jj = 54 ) then
                  rCust.BIRTH_DATE  := oDoc( oDoc.count ).dv;
                elsif ( jj = 69 ) then
                  rCust.BIRTH_COUNTRY  := oDoc( oDoc.count ).sv;
                elsif ( jj = 96 ) then
                  rCust.INST_SECTOR  := oDoc( oDoc.count ).sv;
                elsif ( jj = 108 ) then
                  rCust.LATIN_FIRSTNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 109 ) then
                  rCust.LATIN_MIDLENAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 110 ) then
                  rCust.LATIN_LASTNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 129 ) then
                  rCust.BG_CARD_NO  := oDoc( oDoc.count ).sv;
                end if;
              elsif ( nRowType = 3 ) then -- фирма
                if ( jj = 1 ) then
                  rCust.FIRSTNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 3 ) then
                  rCust.BULSTAT  := oDoc( oDoc.count ).sv;
                elsif ( jj = 4 ) then
                  rCust.DANNUMBER  := oDoc( oDoc.count ).sv;
                elsif ( jj = 10 ) then
                  rCust.TZTYPE  := oDoc( oDoc.count ).sv;
                elsif ( jj = 11 ) then
                  rCust.SECTORNA  := oDoc( oDoc.count ).sv;
                elsif ( jj = 12 ) then
                  rCust.OTRASLOVA  := oDoc( oDoc.count ).sv;
                elsif ( jj = 23 ) then
                  rCust.EMAIL  := oDoc( oDoc.count ).sv;
                elsif ( jj = 35 ) then
                  rCust.LATINNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 62 ) then
                  rCust.TAX_FOREIGN  := oDoc( oDoc.count ).nv;
                elsif ( jj = 63 ) then
                  rCust.COMMLIH  := oDoc( oDoc.count ).nv;
                elsif ( jj = 96 ) then
                  rCust.INST_SECTOR  := oDoc( oDoc.count ).sv;
                end if;
              elsif ( nRowType = 4 ) then -- банка
                if ( jj = 1 ) then
                  rCust.FIRSTNAME  := oDoc( oDoc.count ).sv;
                elsif ( jj = 2 ) then
                  rCust.BAE  := oDoc( oDoc.count ).sv;
                elsif ( jj = 4 ) then
                  rCust.BIC  := oDoc( oDoc.count ).sv;
                elsif ( jj = 16 ) then
                  rCust.EMAIL  := oDoc( oDoc.count ).sv;
                elsif ( jj = 17 ) then
                  rCust.DANNUMBER  := oDoc( oDoc.count ).sv;
                elsif ( jj = 18 ) then
                  rCust.SECTORNA  := oDoc( oDoc.count ).sv;
                elsif ( jj = 19 ) then
                  rCust.OTRASLOVA  := oDoc( oDoc.count ).sv;
                elsif ( jj = 38 ) then
                  rCust.TAX_FOREIGN  := oDoc( oDoc.count ).nv;
                elsif ( jj = 39 ) then
                  rCust.COMMLIH  := oDoc( oDoc.count ).nv;
                elsif ( jj = 68 ) then
                  rCust.INST_SECTOR  := oDoc( oDoc.count ).nv;
                end if;
              end if;
            end if;

            jj    := aRowValues.next( jj );
          end loop;
        end if;

        ii        := aParamEntities3D.next( ii );
      end loop;

      bRet                                   := bRet and
                                                nState >= 1;

      if ( nUniqCode = 0 ) then
        nUniqCode  := null;
      end if;

      if ( nCustNo = 0 ) then
        nCustNo  := null;
      end if;

      if ( bRet and
          sOper != 'NEW' and
          rCust.fldACTIVE in (GPC_Customs.CustStat_SlujZakrit, GPC_Customs.CustStat_ClientZakrit, GPC_Customs.CustStat_ZakritZapori, GPC_Customs.CustStat_ManualTrans) ) then
        bRet  := CustStatus.CustHasActiveProducts( rCust.id );
      end if;

      if ( bRet and
          sOper != 'NEW' and
          rCust.fldACTIVE != GPC_Customs.CustStat_Activen ) then
        bRet  := CustStatus.RemoveCustFromGroup( rCust.id, true );
      end if;

      if ( bRet and
          bChkInBase and
          Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'CHKINBASE', 'T' ) ) ) then -- проверка за клиент с такива данни
        bDummy  := sOper = 'NEW';
        $if ( Schema_GPSys.OraSys.VerBankUnion or
             Schema_GPSys.OraSys.VerBankDBank or
             Schema_GPSys.OraSys.VerBankSAS or
             Schema_GPSys.OraSys.VerBankTokuda ) $then
          nSkipInactCust  := 1;
        $end

        if ( not bDummy and
            nvl( rCust.fldACTIVE, GPC_Customs.CustStat_Activen ) != GPC_Customs.CustStat_Hidden ) then
          if ( nvl( nUniqCode, 0 ) = 0 and
              nvl( nMainCode, 0 ) = 0 ) then
            begin
              select UNIQCODE
                into nMainCode
                from CUSTOMS
               where id = rCust.id;
            exception
              when no_data_found then
                null;
            end;
          end if;

          select count( 1 )
            into ii
            from CUSTOMS
           where id = rCust.id and
                 UNIQCODE in (nUniqCode, nMainCode) and
                 ( nvl( EGN, '~' ) != nvl( rCust.EGN, '~' ) or
                  nvl( BULSTAT, '~' ) != nvl( rCust.BULSTAT, '~' ) or
                  nvl( DANNUMBER, '~' ) != nvl( rCust.DANNUMBER, '~' ) or
                  nvl( BAE, '~' ) != nvl( rCust.BAE, '~' ) or
                  nvl( BIC, '~' ) != nvl( rCust.BIC, '~' ) or
                  ( nSkipInactCust = 1 and
                   nvl( FLDACTIVE, '~' ) != nvl( rCust.FLDACTIVE, '~' ) ) );

          bDummy  := ii > 0;
        end if;

        if ( bDummy ) then
          bRet      := not GPC_Customs.IsCustomerExist( 'EGN',
                                                        rCust.EGN,
                                                        nvl( nUniqCode, 0 ),
                                                        nMainCode,
                                                        false,
                                                        aIDs,
                                                        nvl( rCust.id, 0 ),
                                                        'CUSTOMS',
                                                        'ID',
                                                        nSkipInactCust = 1,
                                                        false,
                                                        case nvl( Schema_GPSys.OraGPSys.OracleBoolean( Schema_GPSys.OraGPSys.GetIniValue( Schema_GPSys.OraGPSys.defUniqCode_All,
                                                                                                                                          'CUSTOMS',
                                                                                                                                          'CHECK_CLITYPE',
                                                                                                                                          null
                                                                                                                                         )
                                                                                                      ),
                                                                  Schema_GPSys.OraSys.VerBankTokuda or
                                                                  Schema_GPSys.OraSys.VerBankDBank
                                                                 )
                                                          when true then
                                                            rCust.CLITYPE
                                                          else
                                                            null
                                                        end,
                                                        case nvl( Schema_GPSys.OraGPSys.OracleBoolean( Schema_GPSys.OraGPSys.GetIniValue( Schema_GPSys.OraGPSys.defUniqCode_All,
                                                                                                                                          'CUSTOMS',
                                                                                                                                          'CHECK_CLITYPE',
                                                                                                                                          null
                                                                                                                                         )
                                                                                                      ),
                                                                  Schema_GPSys.OraSys.VerBankTokuda or
                                                                  Schema_GPSys.OraSys.VerBankDBank
                                                                 )
                                                          when true then
                                                            rCust.FTYPE
                                                          else
                                                            null
                                                        end
                                                       ) and
                       ( ( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'CHECK_BULSTAT', 'T' ) = 'F' and
                          rCust.CLITYPE = 'C' ) or
                        not GPC_Customs.IsCustomerExist( 'BULSTAT',
                                                         rCust.BULSTAT,
                                                         nvl( nUniqCode, 0 ),
                                                         nMainCode,
                                                         false,
                                                         aIDs,
                                                         nvl( rCust.id, 0 ),
                                                         'CUSTOMS',
                                                         'ID',
                                                         nSkipInactCust = 1,
                                                         false,
                                                         case nvl( Schema_GPSys.OraGPSys.OracleBoolean( Schema_GPSys.OraGPSys.GetIniValue( Schema_GPSys.OraGPSys.defUniqCode_All,
                                                                                                                                           'CUSTOMS',
                                                                                                                                           'CHECK_CLITYPE',
                                                                                                                                           null
                                                                                                                                          )
                                                                                                       ),
                                                                   false
                                                                  )
                                                           when true then
                                                             rCust.CLITYPE
                                                           else
                                                             null
                                                         end
                                                        ) ) and
                       not GPC_Customs.IsCustomerExist( 'DANNUMBER', rCust.DANNUMBER, nvl( nUniqCode, 0 ), nMainCode, false, aIDs, nvl( rCust.id, 0 ), 'CUSTOMS', 'ID', nSkipInactCust = 1 ) and
                       not GPC_Customs.IsCustomerExist( 'BAE', rCust.BAE, nvl( nUniqCode, 0 ), nMainCode, false, aIDs, nvl( rCust.id, 0 ), 'CUSTOMS', 'ID', nSkipInactCust = 1 ) and
                       not GPC_Customs.IsCustomerExist( 'BIC', rCust.BIC, nvl( nUniqCode, 0 ), nMainCode, true, aIDs, nvl( rCust.id, 0 ), 'CUSTOMS', 'ID', nSkipInactCust = 1 );

          if ( not bRet ) then
            Schema_RA.GPC_RA.RespSetErrorText( 'Клиентът вече съществува в базата', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG );
          end if;
        end if;
      end if;

      if ( bRet and
          nvl( nUniqCode, 0 ) > 0 and
          nvl( nCustNo, 0 ) > 0 ) then
        bRet  := not GPC_Customs.IsCustNoExist( nUniqCode, nCustNo, rCust.id );

        if ( bRet ) then
          bRet  := GPC_Customs.IsCustNoInRange( nUniqCode, nCustNo );

          if ( not bRet ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'UNIQCODE';
            aParams( 1 ).ML_VALUE  := to_char( nUniqCode );
            aParams( 2 ).ML_NAME   := 'CUST_NO';
            aParams( 2 ).ML_VALUE  := to_char( nCustNo );
            Schema_RA.GPC_RA.RespSetErrorText( 'Клиентският номер не отговаря на диапазона $UNIQCODE$ $CUST_NO$',
                                               Schema_GPSys.MLng.ctxCustomers,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'UNIQCODE';
          aParams( 1 ).ML_VALUE  := to_char( nUniqCode );
          aParams( 2 ).ML_NAME   := 'CUST_NO';
          aParams( 2 ).ML_VALUE  := to_char( nCustNo );
          Schema_RA.GPC_RA.RespSetErrorText( 'Клиентският номер вече съществува в базата $UNIQCODE$ $CUST_NO$',
                                             Schema_GPSys.MLng.ctxCustomers,
                                             Schema_GPSys.MLng.lngBG,
                                             aParams
                                            );
        end if;
      end if;

      if ( bRet and
          rCust.EXT_NUMBER is not null ) then
        select distinct id
          bulk collect into aIDs
          from CUSTOMS
         where EXT_NUMBER = rCust.EXT_NUMBER;

        bRet      := ( aIDs.count = 0 ) or
                     ( aIDs.count = 1 and
                      nvl( rCust.id, 0 ) = aIDs( aIDs.first ) );

        if ( not bRet ) then
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'EXT_NUMBER';
          aParams( 1 ).ML_VALUE  := rCust.EXT_NUMBER;
          Schema_RA.GPC_RA.RespSetErrorText( 'Външният номер вече съществува в базата $EXT_NUMBER$',
                                             Schema_GPSys.MLng.ctxCustomers,
                                             Schema_GPSys.MLng.lngBG,
                                             aParams
                                            );
        end if;
      end if;

      if ( bRet and
          ( Schema_GPSys.ORASYS.VerBankUnion or
           Schema_GPSys.ORASYS.VerBankDBank or
           Schema_GPSys.OraSys.VerBankSAS or
           Schema_GPSys.OraSys.VerBankTokuda or
           not Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 19 ) ) ) then
        CustData             := null;
        CustData.CliType     := rCust.CLITYPE;
        CustData.FType       := rCust.FTYPE;
        CustData.CustName    := trim( trim( trim( rCust.FIRSTNAME ) || ' ' || trim( rCust.MIDLENAME ) || ' ' || trim( rCust.LASTNAME ) ) );
        CustData.LatinName2  := trim( trim( rCust.LATIN_FIRSTNAME ) || ' ' || trim( rCust.LATIN_MIDLENAME ) || ' ' || trim( rCust.LATIN_LASTNAME ) );
        CustData.LatinName   := trim( rCust.LATINNAME );
        CustData.BIRTH_DATE  := rCust.BIRTH_DATE;

        if ( rCust.CliType = 'C' ) then
          CustData.EGN_BULSTAT  := rCust.EGN;
        else
          CustData.EGN_BULSTAT  := rCust.BULSTAT;
        end if;

        if ( nvl( rCust.fldACTIVE, GPC_Customs.CustStat_Activen ) != GPC_Customs.CustStat_Hidden and
            CMD_EIF.IsPersonInRegEIF( CustData, true, sAction, bBlock, aRowIDs, rLogRegister ) ) then
          bLogCust  := true;
          bRet      := not bBlock;

          if ( not bRet ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'ACTION';
            aParams( 1 ).ML_VALUE  := sAction;
            Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се регистрира ВИСОКО РИСКОВ клиент $ACTION$',
                                               Schema_GPSys.MLng.ctxCustomers,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;
        end if;
      end if;

      $if ( Schema_GPSys.OraSys.VerBankTokuda ) $then
        if ( bRet and
            sOper = 'NEW' and
            rCust.CliType = 'C' ) then
          if ( Schema_Cust.GPC_Customs.IsForeign( rCust.FType ) ) then
            bSkipMVR      := bSkipMVR or
                             rCust.BG_CARD_NO is null or
                             rCust.BIRTH_DATE is null;
            sLCard        := rCust.BG_CARD_NO;
          else
            sLCard  := rCust.LICHNAKARTA;
          end if;

          if ( not bSkipMVR ) then
            select count( 1 )
              into nMVRCount
              from Schema_Expo.LOAN_MVR_RESP_HEAD
             where LICHNAKARTA = sLCard and
                   BIRTH_DATE = rCust.BIRTH_DATE and
                   trunc( CH_DATE ) = trunc( sysdate ) and
                   STATUS = Schema_Expo.Cmd_CkrNoi.defMVRReqStatus_Finished and
                   VALID_FLAG = Schema_Expo.Cmd_CkrNoi.defMVRValidFlag_Valid;

            if ( nMVRCount = 0 ) then
              Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се регистрира клиент без проверени данни от МВР',
                                                 Schema_GPSys.MLng.ctxCustomers,
                                                 Schema_GPSys.MLng.lngBG
                                                );
              bRet  := false;
            end if;
          end if;
        end if;
      $end

      if ( bRet ) then
        if ( sOper = 'NEW' ) then
          if ( bRegular or
              nvl( rCust.id, 0 ) = 0 ) then
            rCust.id  := GPC_Customs.Get_Number( 'ID' );
          end if;

          oDoc( nCustIDPos ).nv   := rCust.id;
          oDoc( nDosieIDPos ).nv  := rCust.id;
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nNumDocType, nNumFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nRepDocType, nRepFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nPxyDocType, nPxyFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nCntDocType, nCntFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nLnkDocType, nLnkFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nCodeDocType, nCodeFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nPicDocType, nPicFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nStockDocType, nStockFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nRivalDocType, nRivalFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nVoucherDocType, nVoucherFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nWorkerDocType, nWorkerFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nAddressDocType, nAddressFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nDopInfoDocType, nDopInfoFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nRolesDocType, nRolesFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nDanInfoDocType, nDanInfoFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nAECountryDocType, nAECountryFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nAEDanInfoDocType, nAEDanInfoFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nAEControlPersDocType, nAEControlPersFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nIBANsDocType, nIBANsFldType, rCust.id );
          bDummy                  := Schema_GPSys.OraGPSys.UpdDocByDocFieldTypeNumber( oDoc, nURLsDocType, nURLsFldType, rCust.id );

          insert into CUSTOMS(
                        id,
                        FIRSTNAME,
                        MIDLENAME,
                        LASTNAME,
                        EGN,
                        BULSTAT,
                        DANNUMBER,
                        BAE,
                        BIC,
                        CLITYPE,
                        FTYPE,
                        TZTYPE,
                        COMMLIH,
                        EXT_NUMBER,
                        PRIVRES_VAL,
                        PRIVRES_AMN,
                        CUST_SEGMENT,
                        PROFIT_CENTER,
                        RELATIONSHIPMGR,
                        fldACTIVE,
                        DDS_VIN,
                        UNIQCODE,
                        PREGLED_DATE,
                        MON_DATE,
                        RATING,
                        RATING_TYPE,
                        MON_TYPE,
                        RISK_SEG,
                        EXPO_CLASS,
                        INST_SECTOR,
                        TAX_FOREIGN,
                        SECTORNA,
                        OTRASLOVA,
                        LATINNAME,
                        LATIN_FIRSTNAME,
                        LATIN_MIDLENAME,
                        LATIN_LASTNAME,
                        TAX_TYPE,
                        MARKETING_USER,
                        MARKETING_PARTNER,
                        ID_AGENT,
                        YEARLY_EXPENSE,
                        ALL_CREDIT_DUES,
                        RELIF_ENTTY_TYPE,
                        RELIF_ENTTY_ID,
                        NKID2025
                      )
               values ( rCust.id,
                        rCust.FIRSTNAME,
                        rCust.MIDLENAME,
                        rCust.LASTNAME,
                        rCust.EGN,
                        rCust.BULSTAT,
                        rCust.DANNUMBER,
                        rCust.BAE,
                        rCust.BIC,
                        rCust.CLITYPE,
                        rCust.FTYPE,
                        rCust.TZTYPE,
                        rCust.COMMLIH,
                        rCust.EXT_NUMBER,
                        rCust.PRIVRES_VAL,
                        rCust.PRIVRES_AMN,
                        rCust.CUST_SEGMENT,
                        rCust.PROFIT_CENTER,
                        rCust.RELATIONSHIPMGR,
                        rCust.fldACTIVE,
                        rCust.DDS_VIN,
                        nMainCode,
                        rCust.PREGLED_DATE,
                        rCust.MON_DATE,
                        rCust.RATING,
                        rCust.RATING_TYPE,
                        rCust.MON_TYPE,
                        rCust.RISK_SEG,
                        rCust.EXPO_CLASS,
                        rCust.INST_SECTOR,
                        rCust.TAX_FOREIGN,
                        rCust.SECTORNA,
                        rCust.OTRASLOVA,
                        rCust.LATINNAME,
                        rCust.LATIN_FIRSTNAME,
                        rCust.LATIN_MIDLENAME,
                        rCust.LATIN_LASTNAME,
                        rCust.TAX_TYPE,
                        rCust.MARKETING_USER,
                        rCust.MARKETING_PARTNER,
                        rCust.ID_AGENT,
                        rCust.YEARLY_EXPENSE,
                        rCust.ALL_CREDIT_DUES,
                        rCust.RELIF_ENTTY_TYPE,
                        rCust.RELIF_ENTTY_ID,
                        rCust.NKID2025
                       );

          Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи клиента', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          bRet                    := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeCustoms, rCust.id );
        else
          update CUSTOMS
             set FIRSTNAME          = nvl( rCust.FIRSTNAME, FIRSTNAME ),
                 MIDLENAME          = nvl( rCust.MIDLENAME, MIDLENAME ),
                 LASTNAME           = nvl( rCust.LASTNAME, LASTNAME ),
                 EGN                = nvl( rCust.EGN, EGN ),
                 BULSTAT            = nvl( rCust.BULSTAT, BULSTAT ),
                 DANNUMBER          = nvl( rCust.DANNUMBER, DANNUMBER ),
                 BAE                = nvl( rCust.BAE, BAE ),
                 BIC                = nvl( rCust.BIC, BIC ),
                 CLITYPE            = nvl( rCust.CLITYPE, CLITYPE ),
                 FTYPE              = nvl( rCust.FTYPE, FTYPE ),
                 TZTYPE             = nvl( rCust.TZTYPE, TZTYPE ),
                 COMMLIH            = nvl( rCust.COMMLIH, COMMLIH ),
                 EXT_NUMBER         = nvl( rCust.EXT_NUMBER, EXT_NUMBER ),
                 PRIVRES_VAL        = nvl( rCust.PRIVRES_VAL, PRIVRES_VAL ),
                 PRIVRES_AMN        = nvl( rCust.PRIVRES_AMN, PRIVRES_AMN ),
                 CUST_SEGMENT       = nvl( rCust.CUST_SEGMENT, CUST_SEGMENT ),
                 PROFIT_CENTER      = nvl( rCust.PROFIT_CENTER, PROFIT_CENTER ),
                 RELATIONSHIPMGR    = nvl( rCust.RELATIONSHIPMGR, RELATIONSHIPMGR ),
                 fldACTIVE          = nvl( rCust.fldACTIVE, fldACTIVE ),
                 DDS_VIN            = nvl( rCust.DDS_VIN, DDS_VIN ),
                 UNIQCODE           = nvl( nMainCode, UNIQCODE ),
                 PREGLED_DATE       = nvl( rCust.PREGLED_DATE, PREGLED_DATE ),
                 MON_DATE           = nvl( rCust.MON_DATE, MON_DATE ),
                 RATING             = nvl( rCust.RATING, RATING ),
                 RATING_TYPE        = nvl( rCust.RATING_TYPE, RATING_TYPE ),
                 MON_TYPE           = nvl( rCust.MON_TYPE, MON_TYPE ),
                 RISK_SEG           = nvl( rCust.RISK_SEG, RISK_SEG ),
                 EXPO_CLASS         = nvl( rCust.EXPO_CLASS, EXPO_CLASS ),
                 INST_SECTOR        = nvl( rCust.INST_SECTOR, INST_SECTOR ),
                 TAX_FOREIGN        = nvl( rCust.TAX_FOREIGN, TAX_FOREIGN ),
                 SECTORNA           = nvl( rCust.SECTORNA, SECTORNA ),
                 OTRASLOVA          = nvl( rCust.OTRASLOVA, OTRASLOVA ),
                 LATINNAME          = nvl( rCust.LATINNAME, LATINNAME ),
                 LATIN_FIRSTNAME    = nvl( rCust.LATIN_FIRSTNAME, LATIN_FIRSTNAME ),
                 LATIN_MIDLENAME    = nvl( rCust.LATIN_MIDLENAME, LATIN_MIDLENAME ),
                 LATIN_LASTNAME     = nvl( rCust.LATIN_LASTNAME, LATIN_LASTNAME ),
                 TAX_TYPE           = rCust.TAX_TYPE, -- ако не е подадено в командата, то е празно така или иначе, ако е подадено празно в командата, да работи според CLITYPE
                 MARKETING_USER     = nvl( rCust.MARKETING_USER, MARKETING_USER ),
                 MARKETING_PARTNER  = nvl( rCust.MARKETING_PARTNER, MARKETING_PARTNER ),
                 ID_AGENT           = nvl( rCust.ID_AGENT, ID_AGENT ),
                 YEARLY_EXPENSE     = nvl( rCust.YEARLY_EXPENSE, YEARLY_EXPENSE ),
                 ALL_CREDIT_DUES    = nvl( rCust.ALL_CREDIT_DUES, ALL_CREDIT_DUES ),
                 RELIF_ENTTY_TYPE   = nvl( rCust.RELIF_ENTTY_TYPE, RELIF_ENTTY_TYPE ),
                 RELIF_ENTTY_ID     = nvl( rCust.RELIF_ENTTY_ID, RELIF_ENTTY_ID ),
                 NKID2025           = nvl( rCust.NKID2025, NKID2025 )
           where id = rCust.id;
        end if;

        update CUST_DELETED_DATA
           set LAST_DECLINE_DATE  = nvl( rDeletedCust.LAST_DECLINE_DATE, LAST_DECLINE_DATE ),
               DISPUTE            = nvl( rDeletedCust.DISPUTE, DISPUTE )
         where IDCUST = rCust.id;

        if ( sql%rowcount = 0 ) then
          insert into CUST_DELETED_DATA(
                        IDCUST,
                        LAST_DECLINE_DATE,
                        DISPUTE
                      )
               values ( rCust.id,
                        rDeletedCust.LAST_DECLINE_DATE,
                        rDeletedCust.DISPUTE
                       );
        end if;
      end if;

      if ( bRet and
          GPC_Customs.IsForeign( rCust.FTYPE ) and
          rCust.CLITYPE in ('C', 'F') and
          rCust.RELIF_ENTTY_ID is null and
          nvl( nRelifEnttyIDPos, 0 ) > 0 ) then
        if ( rCust.CLITYPE = 'C' ) then
          oDoc( nRelifEnttyIDPos ).sv      := rCust.BIRTH_COUNTRY ||
                                              to_char( rCust.BIRTH_DATE, 'yyyymmdd' )||
                                              rpad( substr( rCust.LATIN_FIRSTNAME, 1, 5 ), 5, '#' )||
                                              rpad( substr( rCust.LATIN_LASTNAME, 1, 5 ), 5, '#' )||
                                              dbms_random.string( 'X', 4 );
        elsif ( rCust.CLITYPE = 'F' ) then
          oDoc( nRelifEnttyIDPos ).sv  := 'RI' || lpad( rCust.id, 6, '#' );
        end if;
      end if;

      if ( bRet and
          GPC_Customs.INI_UsersAsCustomers ) then
        bRet  := UpdateUserData( rCust );
      end if;

      $if ( Schema_GPSys.OraSys.VerBankUnion or
           Schema_GPSys.OraSys.VerBankDBank or
           Schema_GPSys.OraSys.VerBankSAS or
           Schema_GPSys.OraSys.VerBankTokuda ) $then
        bRet      := bRet and
                     Schema_Expo.Cmd_Loans_Mku.UpdateSoftCollectionChg( rCust );
      $end

      if ( bRet ) then
        if ( nUniqCode is not null ) then
          if ( nCustNo is null ) then
            nCustNo  := GPC_Customs.GetNewCustNo( rCust.id, nUniqCode, nCustNo );
          end if;

          if ( nCustNo is not null and
              not GPC_Customs.IsCustNoExist( nUniqCode, nCustNo ) ) then
            if ( nDocNumList is null ) then
              nDocNumList  := nDocLevel + 1;
              nDocLevel    := nDocLevel + 1;
              bDummy       := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'CustSave' || sOper, '1.CustNumber', 1, nDocNumList );
            end if;

            nDocLevel  := nDocLevel + 1;
            bDummy     := Schema_GPSys.OraGPSys.AddDocRowListDesc( oDoc, nDocNumList, nDocLevel );
            bDummy     := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'CustSaveNumbers', '5.IDCust', nDocLevel, rCust.id );
            bDummy     := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'CustSaveNumbers', '5.1', nDocLevel, nUniqCode );
            bDummy     := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'CustSaveNumbers', '5.2', nDocLevel, nCustNo );
            bDummy     := Schema_GPSys.OraGPSys.AddDocRowFromCmdNumber( oDoc, 'CustSaveNumbers', '5.ChOper', nDocLevel, Schema_RA.GPC_RA.nCurrentUserID );

            insert into CUSTNUMS(
                          id,
                          UNIQCODE,
                          CUSTNO,
                          FLDORDER,
                          REG_DATE
                        )
                 values ( rCust.id,
                          nUniqCode,
                          nCustNo,
                          GPC_Customs.GetNewCustOrdNo( rCust.id ),
                          Schema_RA.GPC_Tools.GetSchDate( null )
                         );
          end if;
        end if;
      end if;

      if ( bRet and
          bCustCredInfo ) then
        bRet  := Schema_Cust.GPC_Customs.CustCredInfo_Update( rCust.id, recCustCredInfo );
      end if;

      if ( bRet ) then
        ii    := Schema_DocSys.DOCSYS_SaveInIQ.SaveDoc( oDoc, nInQueue );
        bRet  := ii = 0;

        if ( bRet ) then
          Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи клиента', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          bRet  := Schema_GPSys.OraGPSys.MarkLockedObj( Schema_GPSys.OraGPSys.LockTypeCustoms, rCust.id );
        else
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'ERR';
          aParams( 1 ).ML_VALUE  := to_char( ii );
          Schema_RA.GPC_RA.RespSetErrorText( 'SaveDocInIQ() error: $ERR$', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngEN, aParams );
        end if;
      end if;


      if ( bRet and
          bResp ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 1 );
        sData  := null;

        if ( Schema_GPSys.GPC_Parser.WriteInteger( rCust.id, sData ) and
            Schema_GPSys.GPC_Parser.WriteString( sAction, sData ) ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
          Schema_GPSys.GPC_Parser.RespAddArray( 2 );

          for rec in (  select UniqCode,
                               CustNo
                          from CUSTNUMS
                         where id = rCust.id
                      order by UniqCode,
                               CustNo ) loop
            sData  := null;

            if ( Schema_GPSys.GPC_Parser.WriteInteger( rec.UniqCode, sData ) and
                Schema_GPSys.GPC_Parser.WriteInteger( rec.CustNo, sData ) ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            end if;
          end loop;
        end if;
      end if;

      Schema_GPSys.GPC_Parser.nGlobalNumber  := rCust.id;

      if ( bRet ) then
        if ( bLogCust ) then
          rLogRegister.PARAM6  := rCust.id;
          CMD_EIF.PutCustInReqLog( rLogRegister );
        end if;
      
        if ( sOper = 'NEW' ) then
          insert into CUST_UNITS(
                        ID_CUST,
                        FLD_UNIT,
                        STATUS
                      )
               values ( rCust.id,
                        Schema_RA.GPC_RA.nCurrentUnit,
                        'T'
                       );
        end if;
      
        commit;
      else
        rollback;
      end if;

      ii                                     := dbms_lock.release( handle );
    else
      Schema_RA.GPC_RA.RespSetErrorText( 'Не може да се заключи технологията', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    end if;

    return bRet;
  end CmdCustomsSave;

  --------------------------------------------------------------------------------
  function CustomsFind(
    aFindParams  in     trCustomsSearchParams,
    aIDs            out Schema_GPSys.OraGPSys.aNumbers
  )
    return boolean is
    nFilterId  integer := Schema_GPSys.OraGPSys.GetQueryFilterId;
    bRet       boolean := true;
  begin
    if ( aFindParams.sCustomsSearchMode = defCustomsSearchMode_AND ) then
      select a.ID
        bulk collect into aIDs
        from CUSTOMS a
       where rownum <= INI_ReportMaxRetRows + 1 and
             ( nvl( aFindParams.CustRec.ID, 0 ) = 0 or
              a.ID = aFindParams.CustRec.ID ) and
             ( nvl( aFindParams.nIdExpo, 0 ) = 0 or
              exists
                (select 1
                   from Schema_GPSys.EXPOSITION ex
                  where ex.ID_EXPO = aFindParams.nIdExpo and
                        ex.ID_CUST = a.ID) ) and
             ( aFindParams.CustRec.EGN is null or
              ( aFindParams.nPartialSeekEGNLK = 0 and
               a.EGN = aFindParams.CustRec.EGN ) or
              ( aFindParams.nPartialSeekEGNLK = 1 and
               a.EGN like aFindParams.CustRec.EGN || '%' ) ) and
             ( aFindParams.CustRec.LICHNAKARTA is null or
              ( aFindParams.nPartialSeekEGNLK = 0 and
               a.LICHNAKARTA = aFindParams.CustRec.LICHNAKARTA ) or
              ( aFindParams.nPartialSeekEGNLK = 1 and
               a.LICHNAKARTA like aFindParams.CustRec.LICHNAKARTA || '%' ) ) and
             ( aFindParams.CustRec.BULSTAT is null or
              ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysTrue and
               a.BULSTAT = aFindParams.CustRec.BULSTAT ) or
              ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysFalse and
               a.BULSTAT like aFindParams.CustRec.BULSTAT || '%' ) ) and
             ( aFindParams.CustRec.DANNUMBER is null or
              a.DANNUMBER = aFindParams.CustRec.DANNUMBER ) and
             ( aFindParams.CustRec.BAE is null or
              a.BAE = aFindParams.CustRec.BAE ) and
             ( aFindParams.CustRec.ENCH is null or
              a.ENCH = aFindParams.CustRec.ENCH ) and
             ( aFindParams.CustRec.BIC is null or
              upper( a.BIC ) = upper( aFindParams.CustRec.BIC ) ) and
             ( aFindParams.CustRec.INITIALS is null or
              upper( a.INITIALS ) = upper( aFindParams.CustRec.INITIALS ) ) and
             ( nvl( aFindParams.CustRec.EMPLOYER, 0 ) = 0 or
              a.EMPLOYER = aFindParams.CustRec.EMPLOYER ) and
             ( aFindParams.CustRec.IBAN is null or
              a.IBAN = aFindParams.CustRec.IBAN or
              exists
                (select 1
                   from Schema_GPSys.EXPOSITION ex
                  where ex.IBAN = aFindParams.CustRec.IBAN and
                        ex.ID_CUST = a.ID) ) and
             ( aFindParams.CustRec.EMPLOYER_NAME is null or
              upper( a.EMPLOYER_NAME ) = upper( aFindParams.CustRec.EMPLOYER_NAME ) ) and
             ( aFindParams.CustRec.FIRSTNAME is null or
              upper( a.FIRSTNAME ) like upper( aFindParams.CustRec.FIRSTNAME || '%' ) or
              ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
               ( upper( a.LATIN_FIRSTNAME ) like upper( aFindParams.CustRec.FIRSTNAME || '%' ) ) ) ) and
             ( aFindParams.CustRec.MIDLENAME is null or
              upper( a.MIDLENAME ) like upper( aFindParams.CustRec.MIDLENAME || '%' ) or
              ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
               ( upper( a.LATIN_MIDLENAME ) like upper( aFindParams.CustRec.MIDLENAME || '%' ) ) ) ) and
             ( aFindParams.CustRec.LASTNAME is null or
              upper( a.LASTNAME ) like upper( aFindParams.CustRec.LASTNAME || '%' ) or
              ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
               ( upper( a.LATIN_LASTNAME ) like upper( aFindParams.CustRec.LASTNAME || '%' ) ) ) ) and
             ( aFindParams.CustRec.LATINNAME is null or
              upper( a.LATINNAME ) like upper( aFindParams.CustRec.LATINNAME || '%' ) or
              ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
               ( upper( a.FIRSTNAME ) || upper( a.MIDLENAME ) || upper( a.LASTNAME ) like upper( aFindParams.CustRec.LATINNAME || '%' ) ) ) ) and
             ( aFindParams.CustRec.TELEFON is null or
              a.TELEFON like aFindParams.CustRec.TELEFON || '%' or
              a.MOBILE like aFindParams.CustRec.TELEFON || '%' or
              a.FAX like aFindParams.CustRec.TELEFON || '%' or
              a.MOBILE_CONTACT like aFindParams.CustRec.TELEFON || '%' ) and
             ( nvl( aFindParams.nUniqCode, 0 ) = 0 or
              nvl( aFindParams.nCustNo, 0 ) = 0 or
              exists
                (select 1
                   from CUSTNUMS cn
                  where cn.UNIQCODE = aFindParams.nUniqCode and
                        cn.CUSTNO = aFindParams.nCustNo and
                        cn.ID = a.ID) ) and
             ( nvl( aFindParams.nUniqCode, 0 ) = 0 or
              aFindParams.sBankAcc is null or
              exists
                (select 1
                   from Schema_GPSys.EXPOSITION ex
                  where ( ( length( aFindParams.sBankAcc ) <= 10 and
                           ex.BANKACC = aFindParams.sBankAcc and
                           ex.UNIQCODE = aFindParams.nUniqCode ) or
                         ( length( aFindParams.sBankAcc ) > 10 and
                          ex.IBAN = aFindParams.sBankAcc ) ) and
                        ex.ID_CUST = a.ID) ) and
             ( aFindParams.CustRec.EXT_NUMBER is null or
              upper( a.EXT_NUMBER ) = upper( aFindParams.CustRec.EXT_NUMBER ) ) and
             ( aFindParams.sPart is null or
              ( ( aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue or
                 a.UNIQCODE in (aFindParams.nUniqCode, aFindParams.nMainCode) ) and
               ( instr( upper( a.FIRSTNAME ), upper( aFindParams.sPart ) ) != 0 or
                instr( upper( a.MIDLENAME ), upper( aFindParams.sPart ) ) != 0 or
                instr( upper( a.LASTNAME ), upper( aFindParams.sPart ) ) != 0 or
                ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
                 ( instr( upper( a.LATIN_FIRSTNAME ), upper( aFindParams.sPart ) ) != 0 or
                  instr( upper( a.LATIN_MIDLENAME ), upper( aFindParams.sPart ) ) != 0 or
                  instr( upper( a.LATIN_LASTNAME ), upper( aFindParams.sPart ) ) != 0 or
                  instr( upper( a.LATINNAME ), upper( aFindParams.sPart ) ) != 0 ) ) ) ) ) and
             ( aFindParams.CustRec.CUST_SEGMENT is null or
              upper( a.CUST_SEGMENT ) = upper( aFindParams.CustRec.CUST_SEGMENT ) ) and
             ( aFindParams.CustRec.PROFIT_CENTER is null or
              upper( a.PROFIT_CENTER ) = upper( aFindParams.CustRec.PROFIT_CENTER ) ) and
             ( nvl( aFindParams.CustRec.RELATIONSHIPMGR, 0 ) <= 0 or
              a.RELATIONSHIPMGR = aFindParams.CustRec.RELATIONSHIPMGR ) and
             ( aFindParams.CustRec.DDS_VIN is null or
              upper( a.DDS_VIN ) = upper( aFindParams.CustRec.DDS_VIN ) ) and
             ( aFindParams.sSchAcc is null or
              exists
                (select 1
                   from Schema_GPSys.EXPOSITION ex
                  where ex.SCHACCOUNT like aFindParams.sSchAcc and
                        ex.ID_CUST = a.ID) ) and
             ( aFindParams.CustRec.COMPANY_GROUPS is null or
              a.COMPANY_GROUPS = aFindParams.CustRec.COMPANY_GROUPS ) and
             ( aFindParams.CustRec.INDUSTRY is null or
              a.INDUSTRY = aFindParams.CustRec.INDUSTRY ) and
             ( aFindParams.dRegDateFr is null or
              a.REGISTRATION_DATE >= aFindParams.dRegDateFr ) and
             ( aFindParams.dRegDateTo is null or
              a.REGISTRATION_DATE <= aFindParams.dRegDateTo ) and
             ( aFindParams.CustRec.CLITYPE is null or
              upper( a.CLITYPE ) = upper( aFindParams.CustRec.CLITYPE ) ) and
             ( ( aFindParams.sDeinost is null and
                Schema_GPSys.OraGPSys.sHasFilter( 2 ) = Schema_GPSys.OraGPSys.DocSysFalse and
                Schema_GPSys.OraGPSys.sHasFilter( 3 ) = Schema_GPSys.OraGPSys.DocSysFalse ) or
              exists
                (select cr.CUST_ID,
                        cr.ROLE_ID,
                        cr.DEINOST
                   from CUST_ROLES cr
                  where cr.CUST_ID = a.ID and
                        ( aFindParams.sDeinost is null or
                         cr.DEINOST = aFindParams.sDeinost )
                 intersect
                 ( select xx.CUST_ID,
                          xx.ROLE_ID,
                          xx.DEINOST
                     from CUST_ROLES xx
                    where xx.CUST_ID = a.ID and
                          Schema_GPSys.OraGPSys.sHasFilter( 2 ) = Schema_GPSys.OraGPSys.DocSysFalse
                  union all
                  select c.CUST_ID,
                         c.ROLE_ID,
                         c.DEINOST
                    from CUST_ROLES c,
                         Schema_GPSys.QUERY_FILTERS qf
                   where Schema_GPSys.OraGPSys.sHasFilter( 2 ) = Schema_GPSys.OraGPSys.DocSysTrue and
                         qf.ID_FILTER = nFilterId and
                         qf.FILTER_MODE = 2 and
                         c.CUST_ID = a.ID and
                         c.ROLE_ID = qf.STR_FR )
                 intersect
                 ( select xx.CUST_ID,
                          xx.ROLE_ID,
                          xx.DEINOST
                     from CUST_ROLES xx
                    where xx.CUST_ID = a.ID and
                          Schema_GPSys.OraGPSys.sHasFilter( 3 ) = Schema_GPSys.OraGPSys.DocSysFalse
                  union all
                  select d.CUST_ID,
                         d.ROLE_ID,
                         d.DEINOST
                    from CUST_ROLES d,
                         Schema_GPSys.QUERY_FILTERS qf
                   where Schema_GPSys.OraGPSys.sHasFilter( 3 ) = Schema_GPSys.OraGPSys.DocSysTrue and
                         qf.ID_FILTER = nFilterId and
                         qf.FILTER_MODE = 3 and
                         d.CUST_ID = a.ID and
                         d.STATUS = qf.STR_FR )) ) and
             ( aFindParams.sCompanyAddress is null or
              ( upper( a.FOREIGN_ADDRESS ) like '%' || aFindParams.sCompanyAddress || '%' or
               upper( a.LATINADDR ) like '%' || aFindParams.sCompanyAddress || '%' or
               upper( a.ADDRESS_CONTACT ) like '%' || aFindParams.sCompanyAddress || '%' or
               upper( a.ADDRESS ) like '%' || aFindParams.sCompanyAddress || '%' ) ) and
             ( aFindParams.sURL is null or
              exists
                (select 1
                   from CUST_URLS e
                  where e.IDCUST = a.ID and
                        upper( e.URL ) like '%' || aFindParams.sURL || '%') ) and
             ( aFindParams.sMCC is null or
              exists
                (select 1
                   from CUST_URLS f
                  where f.IDCUST = a.ID and
                        f.MCC = aFindParams.sMCC) ) and
             ( aFindParams.CustRec.MERCH_COMPL_MATCH is null or
              nvl( a.MERCH_COMPL_MATCH, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_COMPL_MATCH ) and
             ( aFindParams.CustRec.MERCH_VISA_MC_MATCH is null or
              nvl( a.MERCH_VISA_MC_MATCH, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_VISA_MC_MATCH ) and
             ( aFindParams.CustRec.MERCH_LICENSE is null or
              nvl( a.MERCH_LICENSE, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_LICENSE ) and
             ( nvl( aFindParams.CustRec.SLUJITEL_REG, 0 ) = 0 or
              a.SLUJITEL_REG = aFindParams.CustRec.SLUJITEL_REG ) and
             ( aFindParams.CustRec.MERCH_PCI_SAQ_VER is null or
              a.MERCH_PCI_SAQ_VER = aFindParams.CustRec.MERCH_PCI_SAQ_VER ) and
             ( aFindParams.CustRec.MERCH_PCI_COMPL_DATE is null or
              a.MERCH_PCI_COMPL_DATE = aFindParams.CustRec.MERCH_PCI_COMPL_DATE ) and
             ( aFindParams.CustRec.MERCH_PCI_VALID_DATE is null or
              a.MERCH_PCI_VALID_DATE = aFindParams.CustRec.MERCH_PCI_VALID_DATE ) and
             ( aFindParams.CustRec.MERCH_PCI_SCAN is null or
              nvl( a.MERCH_PCI_SCAN, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_PCI_SCAN ) and
             ( aFindParams.CustRec.MERCH_PCI_GATEWAY is null or
              upper( a.MERCH_PCI_GATEWAY ) like '%' || aFindParams.CustRec.MERCH_PCI_GATEWAY || '%' ) and
             ( aFindParams.CustRec.MERCH_HARD_COPIES_FNO is null or
              a.MERCH_HARD_COPIES_FNO = aFindParams.CustRec.MERCH_HARD_COPIES_FNO ) and
             ( aFindParams.CustRec.MERCH_PARTNER_BANK is null or
              a.MERCH_PARTNER_BANK = aFindParams.CustRec.MERCH_PARTNER_BANK ) and
             ( aFindParams.sPersIDDocNumber is null or
              ( aFindParams.nPartialSeekEGNLK = 0 and
               ( a.PASSPORT = aFindParams.sPersIDDocNumber or
                a.DRIVING_LICENSE = aFindParams.sPersIDDocNumber or
                a.LICHNAKARTA = aFindParams.sPersIDDocNumber or
                a.BG_CARD_NO = aFindParams.sPersIDDocNumber ) ) or
              ( aFindParams.nPartialSeekEGNLK = 1 and
               ( a.PASSPORT like aFindParams.sPersIDDocNumber || '%' or
                a.DRIVING_LICENSE like aFindParams.sPersIDDocNumber || '%' or
                a.LICHNAKARTA like aFindParams.sPersIDDocNumber || '%' or
                a.BG_CARD_NO like aFindParams.sPersIDDocNumber || '%' ) ) ) and
             ( aFindParams.CustRec.BIRTH_DATE is null or
              a.BIRTH_DATE = aFindParams.CustRec.BIRTH_DATE ) and
             ( aFindParams.CustRec.BIRTH_PLACE is null or
              upper( BIRTH_PLACE ) like upper( aFindParams.CustRec.BIRTH_PLACE ) || '%' ) and
             ( aFindParams.CustRec.BIRTH_COUNTRY is null or
              a.BIRTH_COUNTRY = aFindParams.CustRec.BIRTH_COUNTRY ) and
             ( aFindParams.sIdentifierAny is null or
              ( aFindParams.nPartialSeekEGNLK = 0 and
               a.EGN = aFindParams.sIdentifierAny ) or
              ( aFindParams.nPartialSeekEGNLK = 1 and
               a.EGN like aFindParams.sIdentifierAny || '%' ) or
              ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysTrue and
               a.BULSTAT = aFindParams.sIdentifierAny ) or
              ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysFalse and
               a.BULSTAT like aFindParams.sIdentifierAny || '%' ) or
              a.DANNUMBER = aFindParams.sIdentifierAny or
              a.BAE = aFindParams.sIdentifierAny or
              a.ENCH = aFindParams.sIdentifierAny or
              upper( a.BIC ) = upper( aFindParams.sIdentifierAny ) or
              upper( a.EXT_NUMBER ) = upper( aFindParams.CustRec.EXT_NUMBER ) or
              upper( a.DDS_VIN ) = upper( aFindParams.sIdentifierAny ) );
    else
      bRet  := false;
      Schema_RA.GPC_RA.RespSetErrorText( 'Непознат тип филтрация', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    end if;

    if ( bRet and
        aIDs.count > INI_ReportMaxRetRows ) then
      bRet  := false;
      Schema_RA.GPC_RA.RespSetErrorText( 'Резултатът от търсенето е ОГРОМЕН', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    end if;

    return bRet;
  end CustomsFind;

  --------------------------------------------------------------------------------
  function CmdCustomsFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues                 Schema_GPSys.GPC_Parser.taParamStrings;
    acAddress                  Schema_GPSys.VarcharCollectionType;
    rCustAddres                GPC_CMD_Cust.rAddress;
    aIDs                       Schema_GPSys.OraGPSys.aNumbers;
    iqQ                        Schema_GPSys.OraGPSys.EmpCurTyp;
    rMsgConf                   Schema_GPSys.MSGCONF%rowtype;
    aFindParams                trCustomsSearchParams;
    rCustoms                   CUSTOMS%rowtype;
    sAddress                   CUSTOMS.ADDRESS%type;
    recBenef                   GPC_Customs.recCustData;
    sAddress_Contact           varchar2( 4000 );
    sData                      varchar2( 4000 );
    sMVRValidFlag              varchar2( 1 );
    nCustNo                    integer;
    nMVRChOper                 integer;
    dMVRChDate                 date;
    jj                         pls_integer;
    nCntOWAClients             pls_integer;
    nFilterId                  integer := Schema_GPSys.OraGPSys.GetQueryFilterId;
    nTemp                      number;
    bDummy                     boolean;
    bRet                       boolean;
    bOK                        boolean := true;
    bFind                      boolean := false;
    bNotRightView              boolean := false;
    bWWWHome                   boolean := false;
    bCustomerIsCreditoiskatel  boolean := false;
    bIsOraWebAdmin             boolean := false;
    bSearchRegistration        boolean := false;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    jj                              := aParamEntities3D.first;
    bRet                            := jj is not null;

    while ( jj is not null and
           bRet ) loop
      if ( aParamEntities3D( jj ).nRowType = 1 ) then
        bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                     aRowValues.count >= 25 and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), aFindParams.CustRec.id ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), aFindParams.nUniqCode ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 3 ), aFindParams.nCustNo ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), aFindParams.CustRec.EGN, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 5 ), aFindParams.CustRec.BULSTAT, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), aFindParams.CustRec.DANNUMBER, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 7 ), aFindParams.CustRec.BAE, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 8 ), aFindParams.CustRec.FIRSTNAME, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 9 ), aFindParams.CustRec.MIDLENAME, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 10 ), aFindParams.CustRec.LASTNAME, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 11 ), aFindParams.CustRec.BIC, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 12 ), aFindParams.sPart, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 13 ), aFindParams.CustRec.INITIALS, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 14 ), aFindParams.CustRec.ENCH, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 15 ), aFindParams.CustRec.CLITYPE, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 16 ), aFindParams.sHaveCustNo, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 17 ), aFindParams.sBankAcc, true ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 18 ), aFindParams.nIdExpo ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 19 ), aFindParams.CustRec.FTYPE, true ) and
                     Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 20 ), aFindParams.CustRec.EMPLOYER ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 21 ), aFindParams.CustRec.LATINNAME, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 22 ), aFindParams.CustRec.IBAN, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 23 ), aFindParams.CustRec.EXT_NUMBER, true ) and
                     Schema_GPSys.GPC_Parser.ReadString( aRowValues( 24 ), aFindParams.CustRec.fldACTIVE, true ) and
                     Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 25 ), aFindParams.bFindInCreditoiskateli );

        if ( aRowValues.count >= 29 ) then
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 26 ), aFindParams.CustRec.CUST_SEGMENT ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 27 ), aFindParams.CustRec.PROFIT_CENTER ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 28 ), aFindParams.CustRec.RELATIONSHIPMGR ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 29 ), aFindParams.CustRec.DDS_VIN );
        end if;

        if ( aRowValues.count >= 31 ) then
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 30 ), aFindParams.CustRec.STATUS_DOSIE ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 31 ), aFindParams.CustRec.EMPLOYER_NAME );
        end if;

        if ( aRowValues.count >= 33 ) then
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 32 ), aFindParams.CustRec.LICHNAKARTA ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 33 ), aFindParams.CustRec.TELEFON );
        end if;

        if ( aRowValues.count >= 34 ) then
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 34 ), aFindParams.sSchAcc );
        end if;

        if ( aRowValues.count >= 38 ) then
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 35 ), aFindParams.CustRec.COMPANY_GROUPS ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 36 ), aFindParams.CustRec.INDUSTRY ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 37 ), aFindParams.dRegDateFr ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 38 ), aFindParams.dRegDateTo );
        end if;

        if ( aRowValues.count >= 54 ) then
          bRet                                   := bRet and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 39 ), aFindParams.sCustomsSearchMode ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 40 ), aFindParams.sDeinost ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 41 ), aFindParams.sCompanyAddress ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 42 ), aFindParams.sURL ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 43 ), aFindParams.sMCC ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 44 ), aFindParams.CustRec.MERCH_COMPL_MATCH ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 45 ), aFindParams.CustRec.MERCH_VISA_MC_MATCH ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 46 ), aFindParams.CustRec.MERCH_LICENSE ) and
                                                    Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 47 ), aFindParams.CustRec.SLUJITEL_REG ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 48 ), aFindParams.CustRec.MERCH_PCI_SAQ_VER ) and
                                                    Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 49 ), aFindParams.CustRec.MERCH_PCI_COMPL_DATE ) and
                                                    Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 50 ), aFindParams.CustRec.MERCH_PCI_VALID_DATE ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 51 ), aFindParams.CustRec.MERCH_PCI_SCAN ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 52 ), aFindParams.CustRec.MERCH_PCI_GATEWAY ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 53 ), aFindParams.CustRec.MERCH_HARD_COPIES_FNO ) and
                                                    Schema_GPSys.GPC_Parser.ReadString( aRowValues( 54 ), aFindParams.CustRec.MERCH_PARTNER_BANK ) and
                                                    true;
          aFindParams.sCompanyAddress            := upper( aFindParams.sCompanyAddress );
          aFindParams.sURL                       := upper( aFindParams.sURL );
          aFindParams.CustRec.MERCH_PCI_GATEWAY  := upper( aFindParams.CustRec.MERCH_PCI_GATEWAY );
        end if;

        if ( aRowValues.count >= 59 ) then
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 55 ), aFindParams.sPersIDDocNumber ) and
                       Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 56 ), aFindParams.CustRec.BIRTH_DATE ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 57 ), aFindParams.CustRec.BIRTH_PLACE ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 58 ), aFindParams.CustRec.BIRTH_COUNTRY ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 59 ), aFindParams.sIdentifierAny ) and
                       true;
        end if;

        if ( aRowValues.count >= 61 ) then
          bRet      := bRet and
                       Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 60 ), bIsOraWebAdmin ) and
                       Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 61 ), bSearchRegistration ) and
                       true;
        end if;
      elsif ( aParamEntities3D( jj ).nRowType = 2 ) then
        bRet  := Schema_GPSys.OraGPSys.FilterSaveStrings( aParamEntities3D( jj ).sValue, aParamEntities3D( jj ).nRowType ); -- Роли
      elsif ( aParamEntities3D( jj ).nRowType = 3 ) then
        bRet  := Schema_GPSys.OraGPSys.FilterSaveStrings( aParamEntities3D( jj ).sValue, aParamEntities3D( jj ).nRowType ); -- Статус в ролите
      else
        bRet  := false;
      end if;

      jj  := aParamEntities3D.next( jj );
    end loop;

    aFindParams.sCustomsSearchMode  := nvl( aFindParams.sCustomsSearchMode, defCustomsSearchMode_OR );

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      aFindParams.nMainCode            := GPC_Customs.UniqCode2MainCode( aFindParams.nUniqCode );
      aFindParams.nPartialSeekEGNLK    := 0;

      if ( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'PARTIAL_SEEK_EGN_LK', 'F' ) = 'T' ) then
        aFindParams.nPartialSeekEGNLK  := 1;
      end if;

      aFindParams.sCheckExactBULSTAT   := Schema_GPSys.OraGPSys.DocSysTrue;
      $if ( Schema_GPSys.OraSys.VerBankUnion or
           Schema_GPSys.OraSys.VerBankDBank or
           Schema_GPSys.OraSys.VerBankSAS or
           Schema_GPSys.OraSys.VerBankTokuda ) $then
        aFindParams.sCheckExactBULSTAT  := Schema_GPSys.OraGPSys.DocSysFalse;
      $end
      aFindParams.sNotChkUniqCode      := case
                                            when Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 31 ) then Schema_GPSys.OraGPSys.DocSysTrue
                                            else Schema_GPSys.OraGPSys.DocSysFalse
                                          end;

      if ( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'SEEK_NAMES_LATIN_AND_CYRILLIC', 'F' ) = 'T' ) then
        aFindParams.sAlphabetAny  := Schema_GPSys.OraGPSys.DocSysTrue;
      else
        aFindParams.sAlphabetAny  := Schema_GPSys.OraGPSys.DocSysFalse;
      end if;

      if ( bOK and
          aFindParams.sSchAcc is not null ) then
        $if ( Schema_GPSys.OraSys.VerFIS or
             Schema_GPSys.OraSys.VerBankTokuda or
             Schema_GPSys.OraSys.VerBankDBank ) $then
          aFindParams.sSchAcc  := aFindParams.sSchAcc || '%';
        $else
          null;
        $end
      end if;

      --
      if ( aFindParams.sCustomsSearchMode = defCustomsSearchMode_OR ) then
        if ( nvl( aFindParams.CustRec.id, 0 ) > 0 ) then
          aIDs( aIDs.count + 1 )  := aFindParams.CustRec.id;
        elsif ( nvl( aFindParams.nIdExpo, 0 ) > 0 ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'ID_EXPO',
                                                      aFindParams.nIdExpo,
                                                      aFindParams.nUniqCode,
                                                      aFindParams.nMainCode,
                                                      true,
                                                      aIDs,
                                                      0,
                                                      'Schema_GPSys.EXPOSITION',
                                                      'ID_CUST',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        else
          if ( aFindParams.nPartialSeekEGNLK = 0 and
              aFindParams.CustRec.EGN is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'EGN',
                                                        aFindParams.CustRec.EGN,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.nPartialSeekEGNLK = 0 and
                 aFindParams.CustRec.LICHNAKARTA is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'LICHNAKARTA',
                                                        aFindParams.CustRec.LICHNAKARTA,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysTrue and
                 aFindParams.CustRec.BULSTAT is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'BULSTAT',
                                                        aFindParams.CustRec.BULSTAT,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.CustRec.DANNUMBER is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'DANNUMBER',
                                                        aFindParams.CustRec.DANNUMBER,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.CustRec.BAE is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'BAE',
                                                        aFindParams.CustRec.BAE,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.CustRec.ENCH is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'ENCH',
                                                        aFindParams.CustRec.ENCH,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.CustRec.BIC is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'BIC',
                                                        aFindParams.CustRec.BIC,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.CustRec.INITIALS is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'INITIALS',
                                                        aFindParams.CustRec.INITIALS,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( nvl( aFindParams.CustRec.EMPLOYER, 0 ) > 0 ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'EMPLOYER',
                                                        aFindParams.CustRec.EMPLOYER,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.CustRec.IBAN is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'IBAN',
                                                        aFindParams.CustRec.IBAN,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.CustRec.EMPLOYER_NAME is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'EMPLOYER_NAME',
                                                        aFindParams.CustRec.EMPLOYER_NAME,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          elsif ( aFindParams.nPartialSeekEGNLK = 0 and
                 aFindParams.sPersIDDocNumber is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'PASSPORT',
                                                        aFindParams.sPersIDDocNumber,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bDummy      := aIDs.count <= INI_ReportMaxRetRows and
                           GPC_Customs.IsCustomerExist( 'DRIVING_LICENSE',
                                                        aFindParams.sPersIDDocNumber,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bDummy      := aIDs.count <= INI_ReportMaxRetRows and
                           GPC_Customs.IsCustomerExist( 'LICHNAKARTA',
                                                        aFindParams.sPersIDDocNumber,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bDummy      := aIDs.count <= INI_ReportMaxRetRows and
                           GPC_Customs.IsCustomerExist( 'BG_CARD_NO',
                                                        aFindParams.sPersIDDocNumber,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        false,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
          end if;

          if ( aFindParams.CustRec.FIRSTNAME is not null or
              aFindParams.CustRec.MIDLENAME is not null or
              aFindParams.CustRec.LASTNAME is not null or
              aFindParams.CustRec.LATINNAME is not null or
              ( aFindParams.nPartialSeekEGNLK = 1 and
               aFindParams.CustRec.EGN is not null ) or
              ( aFindParams.nPartialSeekEGNLK = 1 and
               aFindParams.CustRec.LICHNAKARTA is not null ) or
              aFindParams.CustRec.TELEFON is not null or
              ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysFalse and
               aFindParams.CustRec.BULSTAT is not null ) or
              ( aFindParams.nPartialSeekEGNLK = 1 and
               aFindParams.sPersIDDocNumber is not null ) or
              aFindParams.CustRec.BIRTH_DATE is not null or
              aFindParams.CustRec.BIRTH_PLACE is not null or
              aFindParams.CustRec.BIRTH_COUNTRY is not null ) then
            if ( aFindParams.CustRec.FIRSTNAME is not null ) then
              aFindParams.CustRec.FIRSTNAME  := upper( aFindParams.CustRec.FIRSTNAME ) || '%';
            end if;

            if ( aFindParams.CustRec.MIDLENAME is not null ) then
              aFindParams.CustRec.MIDLENAME  := upper( aFindParams.CustRec.MIDLENAME ) || '%';
            end if;

            if ( aFindParams.CustRec.LASTNAME is not null ) then
              aFindParams.CustRec.LASTNAME  := upper( aFindParams.CustRec.LASTNAME ) || '%';
            end if;

            if ( aFindParams.CustRec.LATINNAME is not null ) then
              aFindParams.CustRec.LATINNAME  := upper( aFindParams.CustRec.LATINNAME ) || '%';
            end if;

            if ( aFindParams.nPartialSeekEGNLK = 1 and
                aFindParams.CustRec.EGN is not null ) then
              aFindParams.CustRec.EGN  := aFindParams.CustRec.EGN || '%';
            end if;

            if ( aFindParams.nPartialSeekEGNLK = 1 and
                aFindParams.CustRec.LICHNAKARTA is not null ) then
              aFindParams.CustRec.LICHNAKARTA  := aFindParams.CustRec.LICHNAKARTA || '%';
            end if;

            if ( aFindParams.CustRec.TELEFON is not null ) then
              aFindParams.CustRec.TELEFON  := aFindParams.CustRec.TELEFON || '%';
            end if;

            if ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysFalse and
                aFindParams.CustRec.BULSTAT is not null ) then
              aFindParams.CustRec.BULSTAT  := aFindParams.CustRec.BULSTAT || '%';
            end if;

            if ( ( aFindParams.nPartialSeekEGNLK = 1 and
                  aFindParams.sPersIDDocNumber is not null ) ) then
              aFindParams.sPersIDDocNumber  := aFindParams.sPersIDDocNumber || '%';
            end if;

            if ( aFindParams.CustRec.BIRTH_PLACE is not null ) then
              aFindParams.CustRec.BIRTH_PLACE  := upper( aFindParams.CustRec.BIRTH_PLACE ) || '%';
            end if;

            for rec in ( select id
                           from CUSTOMS
                          where ( aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue or
                                 UNIQCODE in (aFindParams.nUniqCode, aFindParams.nMainCode) ) and
                                ( ( aFindParams.CustRec.FIRSTNAME is null or
                                   upper( FIRSTNAME ) like aFindParams.CustRec.FIRSTNAME or
                                   ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
                                    ( upper( LATIN_FIRSTNAME ) like aFindParams.CustRec.FIRSTNAME ) ) ) and
                                 ( aFindParams.CustRec.MIDLENAME is null or
                                  upper( MIDLENAME ) like aFindParams.CustRec.MIDLENAME or
                                  ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
                                   ( upper( LATIN_MIDLENAME ) like aFindParams.CustRec.MIDLENAME ) ) ) and
                                 ( aFindParams.CustRec.LASTNAME is null or
                                  upper( LASTNAME ) like aFindParams.CustRec.LASTNAME or
                                  ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
                                   ( upper( LATIN_LASTNAME ) like aFindParams.CustRec.LASTNAME ) ) ) and
                                 ( aFindParams.CustRec.LATINNAME is null or
                                  upper( LATINNAME ) like aFindParams.CustRec.LATINNAME or
                                  ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
                                   ( upper( FIRSTNAME ) || upper( MIDLENAME ) || upper( LASTNAME ) like aFindParams.CustRec.LATINNAME ) ) ) and
                                 ( aFindParams.nPartialSeekEGNLK = 0 or
                                  aFindParams.CustRec.EGN is null or
                                  EGN like aFindParams.CustRec.EGN ) and
                                 ( aFindParams.nPartialSeekEGNLK = 0 or
                                  aFindParams.CustRec.LICHNAKARTA is null or
                                  LICHNAKARTA like aFindParams.CustRec.LICHNAKARTA ) and
                                 ( aFindParams.CustRec.TELEFON is null or
                                  TELEFON like aFindParams.CustRec.TELEFON or
                                  MOBILE like aFindParams.CustRec.TELEFON or
                                  FAX like aFindParams.CustRec.TELEFON or
                                  MOBILE_CONTACT like aFindParams.CustRec.TELEFON ) and
                                 ( aFindParams.sCheckExactBULSTAT = Schema_GPSys.OraGPSys.DocSysTrue or
                                  aFindParams.CustRec.BULSTAT is null or
                                  BULSTAT like aFindParams.CustRec.BULSTAT ) ) and
                                ( aFindParams.nPartialSeekEGNLK = 0 or
                                 aFindParams.sPersIDDocNumber is null or
                                 PASSPORT like aFindParams.sPersIDDocNumber or
                                 DRIVING_LICENSE like aFindParams.sPersIDDocNumber or
                                 LICHNAKARTA like aFindParams.sPersIDDocNumber or
                                 BG_CARD_NO like aFindParams.sPersIDDocNumber ) and
                                ( aFindParams.CustRec.BIRTH_DATE is null or
                                 BIRTH_DATE = aFindParams.CustRec.BIRTH_DATE ) and
                                ( aFindParams.CustRec.BIRTH_PLACE is null or
                                 upper( BIRTH_PLACE ) like aFindParams.CustRec.BIRTH_PLACE ) and
                                ( aFindParams.CustRec.BIRTH_COUNTRY is null or
                                 BIRTH_COUNTRY = aFindParams.CustRec.BIRTH_COUNTRY ) ) loop
              Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, rec.id );
              bOK  := aIDs.count <= INI_ReportMaxRetRows;
              exit when not bOK;
            end loop;
          end if;

          if ( bOK and
              aFindParams.nUniqCode > 0 and
              aFindParams.nCustNo > 0 ) then
            for rec in ( select id
                           from CUSTNUMS
                          where UNIQCODE = aFindParams.nUniqCode and
                                CUSTNO = aFindParams.nCustNo ) loop
              Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, rec.id );
              bOK  := aIDs.count <= INI_ReportMaxRetRows;
              exit when not bOK;
            end loop;
          end if;

          if ( bOK and
              aFindParams.nUniqCode > 0 and
              aFindParams.sBankAcc is not null ) then
            aFindParams.CustRec.id  := Schema_GPSys.HeadExpo.BankAcc2IDCust( aFindParams.nUniqCode, aFindParams.sBankAcc );

            if ( aFindParams.CustRec.id is not null ) then
              Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, aFindParams.CustRec.id );
            end if;
          end if;

          if ( bOK and
              aFindParams.CustRec.EXT_NUMBER is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'EXT_NUMBER',
                                                        aFindParams.CustRec.EXT_NUMBER,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bOK         := aIDs.count <= INI_ReportMaxRetRows;
          end if;

          if ( bOK and
              aFindParams.CustRec.IBAN is not null ) then
            aFindParams.CustRec.id  := Schema_GPSys.HeadExpo.IBAN2IdCust( aFindParams.CustRec.IBAN );

            if ( aFindParams.CustRec.id is not null ) then
              Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, aFindParams.CustRec.id );
            end if;
          end if;

          if ( bOK and
              aFindParams.sPart is not null ) then
            aFindParams.sPart  := upper( aFindParams.sPart );

            for rec in ( select id
                           from CUSTOMS
                          where ( aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue or
                                 UNIQCODE in (aFindParams.nUniqCode, aFindParams.nMainCode) ) and
                                ( instr( upper( FIRSTNAME ), aFindParams.sPart ) != 0 or
                                 instr( upper( MIDLENAME ), aFindParams.sPart ) != 0 or
                                 instr( upper( LASTNAME ), aFindParams.sPart ) != 0 or
                                 ( aFindParams.sAlphabetAny = Schema_GPSys.OraGPSys.DocSysTrue and
                                  ( instr( upper( LATIN_FIRSTNAME ), aFindParams.sPart ) != 0 or
                                   instr( upper( LATIN_MIDLENAME ), aFindParams.sPart ) != 0 or
                                   instr( upper( LATIN_LASTNAME ), aFindParams.sPart ) != 0 or
                                   instr( upper( LATINNAME ), aFindParams.sPart ) != 0 ) ) ) ) loop
              Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, rec.id );
              bOK  := aIDs.count <= INI_ReportMaxRetRows;
              exit when not bOK;
            end loop;
          end if;

          if ( bOK and
              aFindParams.CustRec.CUST_SEGMENT is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'CUST_SEGMENT',
                                                        aFindParams.CustRec.CUST_SEGMENT,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bOK         := aIDs.count <= INI_ReportMaxRetRows;
          end if;

          if ( bOK and
              aFindParams.CustRec.PROFIT_CENTER is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'PROFIT_CENTER',
                                                        aFindParams.CustRec.PROFIT_CENTER,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bOK         := aIDs.count <= INI_ReportMaxRetRows;
          end if;

          if ( bOK and
              nvl( aFindParams.CustRec.RELATIONSHIPMGR, 0 ) > 0 ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'RELATIONSHIPMGR',
                                                        aFindParams.CustRec.RELATIONSHIPMGR,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bOK         := aIDs.count <= INI_ReportMaxRetRows;
          end if;

          if ( bOK and
              aFindParams.CustRec.DDS_VIN is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'DDS_VIN',
                                                        aFindParams.CustRec.DDS_VIN,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'CUSTOMS',
                                                        'ID',
                                                        false,
                                                        false,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bOK         := aIDs.count <= INI_ReportMaxRetRows;
          end if;

          if ( bOK and
              aFindParams.sSchAcc is not null ) then
            bDummy      := GPC_Customs.IsCustomerExist( 'SCHACCOUNT',
                                                        aFindParams.sSchAcc,
                                                        aFindParams.nUniqCode,
                                                        aFindParams.nMainCode,
                                                        true,
                                                        aIDs,
                                                        0,
                                                        'Schema_GPSys.EXPOSITION',
                                                        'ID_CUST',
                                                        false,
                                                        Schema_GPSys.OraSys.VerFIS or
                                                        Schema_GPSys.OraSys.VerBankTokuda or
                                                        Schema_GPSys.OraSys.VerBankDBank,
                                                        null,
                                                        null,
                                                        aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                       );
            bOK         := aIDs.count <= INI_ReportMaxRetRows;
          end if;

          if ( bOk and
              aFindParams.sIdentifierAny is not null ) then
            if ( bOk and -- не щот съм кьорава, а за да е униформено с долните
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.EGN, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'EGN',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          false,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;

            if ( bOk and
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.BULSTAT, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'BULSTAT',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          false,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;

            if ( bOk and
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.DANNUMBER, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'DANNUMBER',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          false,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;

            if ( bOk and
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.ENCH, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'ENCH',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          false,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;

            if ( bOk and
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.BIC, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'BIC',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          true,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;

            if ( bOk and
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.IBAN, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'IBAN',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          false,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;

            if ( bOk and
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.EXT_NUMBER, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'EXT_NUMBER',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          true,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;

            if ( bOk and
                aFindParams.sIdentifierAny <> nvl( aFindParams.CustRec.DDS_VIN, '~~~' ) ) then
              bDummy      := GPC_Customs.IsCustomerExist( 'DDS_VIN',
                                                          aFindParams.sIdentifierAny,
                                                          aFindParams.nUniqCode,
                                                          aFindParams.nMainCode,
                                                          true,
                                                          aIDs,
                                                          0,
                                                          'CUSTOMS',
                                                          'ID',
                                                          false,
                                                          false,
                                                          null,
                                                          null,
                                                          aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                         );
              bOK         := aIDs.count <= INI_ReportMaxRetRows;
            end if;
          end if;

          if ( bOK and
              ( aFindParams.CustRec.COMPANY_GROUPS is not null or
               aFindParams.CustRec.INDUSTRY is not null or
               aFindParams.dRegDateFr is not null or
               aFindParams.dRegDateTo is not null or
               aFindParams.sDeinost is not null or
               Schema_GPSys.OraGPSys.HasFilter( 2 ) or
               Schema_GPSys.OraGPSys.HasFilter( 3 ) or
               aFindParams.sCompanyAddress is not null ) or
              aFindParams.sURL is not null or
              aFindParams.sMCC is not null or
              aFindParams.CustRec.MERCH_COMPL_MATCH is not null or
              aFindParams.CustRec.MERCH_VISA_MC_MATCH is not null or
              aFindParams.CustRec.MERCH_LICENSE is not null or
              aFindParams.CustRec.MERCH_PCI_SAQ_VER is not null or
              nvl( aFindParams.CustRec.SLUJITEL_REG, 0 ) > 0 or
              aFindParams.CustRec.MERCH_PCI_COMPL_DATE is not null or
              aFindParams.CustRec.MERCH_PCI_VALID_DATE is not null or
              aFindParams.CustRec.MERCH_PCI_SCAN is not null or
              aFindParams.CustRec.MERCH_PCI_GATEWAY is not null or
              aFindParams.CustRec.MERCH_HARD_COPIES_FNO is not null or
              aFindParams.CustRec.MERCH_PARTNER_BANK is not null ) then
            for rec in ( select a.ID
                           from CUSTOMS a
                          where a.COMPANY_GROUPS = aFindParams.CustRec.COMPANY_GROUPS or
                                a.INDUSTRY = aFindParams.CustRec.INDUSTRY or
                                a.REGISTRATION_DATE between aFindParams.dRegDateFr and aFindParams.dRegDateTo or
                                exists
                                  (select 1
                                     from CUST_ROLES b
                                    where b.CUST_ID = a.ID and
                                          b.DEINOST = aFindParams.sDeinost) or
                                ( Schema_GPSys.OraGPSys.sHasFilter( 2 ) = Schema_GPSys.OraGPSys.DocSysTrue and
                                 exists
                                   (select 1
                                      from CUST_ROLES c,
                                           Schema_GPSys.QUERY_FILTERS qf
                                     where qf.ID_FILTER = nFilterId and
                                           qf.FILTER_MODE = 2 and
                                           c.CUST_ID = a.ID and
                                           c.ROLE_ID = qf.STR_FR) ) or
                                ( Schema_GPSys.OraGPSys.sHasFilter( 3 ) = Schema_GPSys.OraGPSys.DocSysTrue and
                                 exists
                                   (select 1
                                      from CUST_ROLES d,
                                           Schema_GPSys.QUERY_FILTERS qf
                                     where qf.ID_FILTER = nFilterId and
                                           qf.FILTER_MODE = 3 and
                                           d.CUST_ID = a.ID and
                                           d.STATUS = qf.STR_FR) ) or
                                ( aFindParams.sCompanyAddress is not null and
                                 ( upper( a.FOREIGN_ADDRESS ) like '%' || aFindParams.sCompanyAddress || '%' or
                                  upper( a.LATINADDR ) like '%' || aFindParams.sCompanyAddress || '%' or
                                  upper( a.ADDRESS_CONTACT ) like '%' || aFindParams.sCompanyAddress || '%' or
                                  upper( a.ADDRESS ) like '%' || aFindParams.sCompanyAddress || '%' ) ) or
                                ( aFindParams.sURL is not null and
                                 exists
                                   (select 1
                                      from CUST_URLS e
                                     where e.IDCUST = a.ID and
                                           upper( e.URL ) like '%' || aFindParams.sURL || '%') ) or
                                ( aFindParams.sMCC is not null and
                                 exists
                                   (select 1
                                      from CUST_URLS f
                                     where f.IDCUST = a.ID and
                                           f.MCC = aFindParams.sMCC) ) or
                                nvl( a.MERCH_COMPL_MATCH, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_COMPL_MATCH or
                                nvl( a.MERCH_VISA_MC_MATCH, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_VISA_MC_MATCH or
                                nvl( a.MERCH_LICENSE, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_LICENSE or
                                a.SLUJITEL_REG = aFindParams.CustRec.SLUJITEL_REG or
                                a.MERCH_PCI_SAQ_VER = aFindParams.CustRec.MERCH_PCI_SAQ_VER or
                                a.MERCH_PCI_COMPL_DATE = aFindParams.CustRec.MERCH_PCI_COMPL_DATE or
                                a.MERCH_PCI_VALID_DATE = aFindParams.CustRec.MERCH_PCI_VALID_DATE or
                                nvl( a.MERCH_PCI_SCAN, Schema_GPSys.OraGPSys.DocSysFalse ) = aFindParams.CustRec.MERCH_PCI_SCAN or
                                upper( a.MERCH_PCI_GATEWAY ) like '%' || aFindParams.CustRec.MERCH_PCI_GATEWAY || '%' or
                                a.MERCH_HARD_COPIES_FNO = aFindParams.CustRec.MERCH_HARD_COPIES_FNO or
                                a.MERCH_PARTNER_BANK = aFindParams.CustRec.MERCH_PARTNER_BANK ) loop
              Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, rec.id );
              bOK  := aIDs.count <= INI_ReportMaxRetRows;
              exit when not bOK;
            end loop;
          end if;
        end if;
      elsif ( aFindParams.sCustomsSearchMode = defCustomsSearchMode_AND ) then
        bRet  := CustomsFind( aFindParams, aIDs );
      end if;

      if ( bRet and
          aIDs.count > 0 ) then
        bRet  := aIDs.count <= INI_ReportMaxRetRows;

        if ( bRet ) then
          Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          Schema_GPSys.GPC_Parser.RespAddArray( 1 );

          for ii in aIDs.first .. aIDs.last loop
            if ( bIsOraWebAdmin ) then
              select count( 1 )
                into nCntOWAClients
                from ORAWEBADM_CLIENTS
               where ID_CUST = aIDs( ii );

              if ( bSearchRegistration ) then
                bDummy  := nCntOWAClients > 0;
              else
                bDummy  := nCntOWAClients = 0;
              end if;
            else
              bDummy  := true;
            end if;

            if ( bDummy ) then
              if ( aFindParams.sHaveCustNo is null ) then
                bDummy  := true;
              else
                open iqQ for
                  select id
                    from CUSTNUMS
                   where id = aIDs( ii );

                fetch iqQ
                  into aFindParams.CustRec.id;

                if ( aFindParams.sHaveCustNo = 'T' ) then
                  bDummy  := iqQ%found;
                else
                  bDummy  := iqQ%notfound;
                end if;

                close iqQ;
              end if;
            end if;

            if ( bDummy ) then
              begin
                select *
                  into rCustoms
                  from CUSTOMS
                 where id = aIDs( ii );

                if ( aFindParams.CustRec.fldACTIVE is not null and
                    aFindParams.CustRec.fldACTIVE != GPC_Customs.CustStat_All ) then
                  if ( aFindParams.CustRec.fldACTIVE = GPC_Customs.CustStat_Working ) then
                    bDummy      := nvl( rCustoms.fldACTIVE, GPC_Customs.CustStat_Activen ) in
                                     ( GPC_Customs.CustStat_Activen,
                                      GPC_Customs.CustStat_Neaktiven,
                                      GPC_Customs.CustStat_SlujZakrit,
                                      GPC_Customs.CustStat_ClientZakrit,
                                      GPC_Customs.CustStat_ManualTrans,
                                      GPC_Customs.CustStat_ZakritZapori );
                  else
                    bDummy  := nvl( rCustoms.fldACTIVE, GPC_Customs.CustStat_Activen ) = aFindParams.CustRec.fldACTIVE;
                  end if;
                end if;

                if ( bDummy and
                    aFindParams.CustRec.STATUS_DOSIE is not null ) then
                  bDummy  := ( aFindParams.CustRec.STATUS_DOSIE = rCustoms.STATUS_DOSIE );
                end if;
              exception
                when no_data_found then
                  bDummy  := false;
              end;

              if ( bDummy ) then
                if ( Schema_RA.GPC_SS.CheckRightCust_VCust_CUser( rCustoms.FTYPE, rCustoms.id ) ) then
                  if ( nvl( rCustoms.CH_STAMP, 0 ) != 0 and
                      ( aFindParams.CustRec.CLITYPE is null or
                       aFindParams.CustRec.CLITYPE = rCustoms.CLITYPE ) and
                      ( aFindParams.CustRec.FTYPE is null or
                       aFindParams.CustRec.FTYPE = rCustoms.FTYPE ) and
                      ( aFindParams.sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue or
                       rCustoms.UNIQCODE in (aFindParams.nUniqCode, aFindParams.nMainCode) ) and
                      ( aFindParams.CustRec.CUST_SEGMENT is null or
                       aFindParams.CustRec.CUST_SEGMENT = rCustoms.CUST_SEGMENT ) and
                      ( aFindParams.CustRec.PROFIT_CENTER is null or
                       aFindParams.CustRec.PROFIT_CENTER = rCustoms.PROFIT_CENTER ) and
                      ( nvl( aFindParams.CustRec.RELATIONSHIPMGR, 0 ) = 0 or
                       aFindParams.CustRec.RELATIONSHIPMGR = rCustoms.RELATIONSHIPMGR ) ) then
                    bFind     := true;

                    if ( GPC_Customs.IsForeign( rCustoms.FTYPE ) and
                        rCustoms.CLITYPE != 'B' ) then
                      sAddress          := rCustoms.LATINADDR;
                      sAddress_Contact  := rCustoms.FOREIGN_ADDRESS;
                    else
                      if ( rCustoms.ADDRESS is null ) then
                        bDummy    := GPC_Customs.GetCustAddress( rCustoms.PTR2DATA, null, null, acAddress, rCustAddres, GPC_Customs.defPrimaryAddr, true );
                        sAddress  := acAddress( 1 ) || acAddress( 2 ) || acAddress( 3 ) || acAddress( 4 ) || acAddress( 5 ) || acAddress( 6 ) || acAddress( 7 ) || acAddress( 8 ) || acAddress( 9 );
                      else
                        sAddress  := rCustoms.ADDRESS;
                      end if;

                      sAddress_Contact  := rCustoms.ADDRESS_CONTACT;
                    end if;

                    $if ( Schema_GPSys.OraSys.VerBankUnion or
                         Schema_GPSys.OraSys.VerBankDBank or
                         Schema_GPSys.OraSys.VerBankSAS or
                         Schema_GPSys.OraSys.VerBankTokuda ) $then
                      if ( aFindParams.bFindInCreditoiskateli ) then
                        bCustomerIsCreditoiskatel  := Schema_Expo.CR.FindCustInCR( rCustoms.id );
                      end if;
                    $end

                    --
                    begin
                      select *
                        into rMsgConf
                        from Schema_GPSys.MSGCONF
                       where ID_OBJECT = rCustoms.id and
                             MODE_OBJECT = Schema_GPSys.Cmd_OraGPSys.nModeObj_Cust and
                             TECHNOLOGY = Schema_GPSys.Cmd_OraGPSys.nModeTech_UnionVesti and
                             rownum < 2;
                    exception
                      when no_data_found then
                        rMsgConf  := null;
                    end;

                    --
                    select count( 1 )
                      into nTemp
                      from Schema_GPSys.WWWCONF
                     where ID_CUST = rCustoms.id and
                           ACTIVE = 'T';

                    bWWWHome  := nTemp > 0;

                    begin
                      select min( CUSTNO )
                        into aFindParams.nCustNo
                        from CUSTNUMS
                       where id = aIDs( ii ) and
                             UNIQCODE = aFindParams.nUniqCode;
                    exception
                      when no_data_found then
                        aFindParams.nCustNo  := 0;
                    end;

                    recBenef  := null;

                    if ( rCustoms.MERCH_PAYMENT_BENEF > 0 ) then
                      recBenef.IDCust  := rCustoms.MERCH_PAYMENT_BENEF;
                      bRet             := GPC_Customs.GetCustData( recBenef );
                    end if;

                    begin
                      select CH_DATE,
                             VALID_FLAG,
                             CH_OPER
                        into dMVRChDate,
                             sMVRValidFlag,
                             nMVRChOper
                        from (  select CH_DATE,
                                       VALID_FLAG,
                                       CH_OPER
                                  from Schema_Expo.LOAN_MVR_RESP_HEAD
                                 where LICHNAKARTA = rCustoms.LICHNAKARTA and
                                       BIRTH_DATE = rCustoms.BIRTH_DATE
                              order by ID_RESP desc)
                       where rownum < 2;
                    exception
                      when no_data_found then
                        dMVRChDate     := null;
                        sMVRValidFlag  := null;
                        nMVRChOper     := 0;
                    end;

                    --
                    if ( bRet ) then
                      sData     := null;
                      bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.id, sData ) and --  1
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CLITYPE, sData ) and --  2
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.FTYPE, sData ) and --  3
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.FIRSTNAME, sData ) and --  4
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MIDLENAME, sData ) and --  5
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.LASTNAME, sData ) and --  6
                                   Schema_GPSys.GPC_Parser.WriteString( nvl( rCustoms.EGN, rCustoms.ENCH ), sData ) and --  7
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.BULSTAT, sData ) and --  8
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.DANNUMBER, sData ) and --  9
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.BAE, sData ) and -- 10
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.BIC, sData ) and -- 11
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.LICHNAKARTA, sData ) and -- 12
                                   Schema_GPSys.GPC_Parser.WriteString( sAddress, sData ) and -- 13
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.DUTY, sData ) and -- 14
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.EMPLOYER, sData ) and -- 15
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.EXT_NUMBER, sData ) and -- 16
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CUST_SEGMENT, sData ) and -- 17
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.PROFIT_CENTER, sData ) and -- 18
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.RELATIONSHIPMGR, sData ) and -- 19
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.fldACTIVE, sData ) and -- 20
                                   Schema_GPSys.GPC_Parser.WriteLogic( bCustomerIsCreditoiskatel, sData ) and -- 21
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.IBAN, sData ) and -- 22
                                   Schema_GPSys.GPC_Parser.WriteInteger( rMsgConf.ID_CONF, sData ) and -- 23
                                   Schema_GPSys.GPC_Parser.WriteString( rMsgConf.ACTIVE, sData ) and -- 24
                                   Schema_GPSys.GPC_Parser.WriteLogic( bWWWHome, sData ) and -- 25
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.EMPLOYER_NAME, sData ) and -- 26
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.STATUS_DOSIE, sData ) and -- 27
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.ADDRESS_KOR, sData ) and -- 28
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.DDS_VIN, sData ) and -- 29
                                   Schema_GPSys.GPC_Parser.WriteInteger( aFindParams.nCustNo, sData ) and -- 30
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MOL, sData ) and -- 31
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.DECFROM, sData ) and -- 32
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.DECSIGNED, sData ) and -- 33
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.DIVIDENT, sData ) and -- 34
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.storage, sData ) and -- 35
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CT_DT, sData ) and -- 36
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CT_DB, sData ) and -- 37
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CT_BU, sData ) and -- 38
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CT_MFA, sData ) and -- 39
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CT_CASH, sData ) and -- 40
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CT_DU, sData ) and -- 41
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.EXPIRY, sData ) and -- 42
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.TELEFON, sData ) and -- 43
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.EMAIL, sData ) and -- 44
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.RISKY_CLIENT, sData ) and -- 45
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.RISK_SEG, sData ) and -- 46
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.LK_IZDADENOT, sData ) and -- 47
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.BIRTH_DATE, sData ) and -- 48
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.LATINNAME, sData ) and -- 49
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.LATINADDR, sData ) and -- 50
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.LK_DATEIZD, sData ) and -- 51
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CITY, sData ) and -- 52
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MUNICIPALITY, sData ) and -- 53
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CITY_REG, sData ) and -- 54
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MUNICIPALITY_REG, sData ) and -- 55
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.COUNTRY, sData ) and -- 56
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.INITIALS, sData ) and -- 57
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.FIRMENO_DELO, sData ) and -- 58
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.FOREIGN_ADDRESS, sData ) and -- 59
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MCC, sData ) and -- 60
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.INDUSTRY, sData ) and -- 61
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.COMPANY_GROUPS, sData ) and -- 62
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCHANTS, sData ) and -- 63
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_WEBSITE, sData ) and -- 64
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.FATCA, sData ) and -- 65
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.REGISTRATION_DATE, sData ) and -- 66
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CONTACT_PERSON, sData ) and -- 67
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.RESIDENCE_COUNTRY, sData ) and -- 68
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.LAST_UPDATE, sData ) and -- 69
                                   Schema_GPSys.GPC_Parser.WriteString( sAddress_Contact, sData ) and -- 70
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.TYPEREGISTER, sData ) and -- 71
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MOBILE, sData ) and -- 72
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.GENDER, sData ) and -- 73
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.LK_VALID_TO, sData ) and -- 74
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CITIZENSHIP, sData ) and -- 75
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.SLUJ_PHONE, sData ) and -- 76
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.HOUSING_STATUS, sData ) and -- 77
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.YEARS_CURR_ADDR, sData ) and -- 78
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.EDUCATION, sData ) and -- 79
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.PROFESSION, sData ) and -- 80
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.FAMILY_STATUS, sData ) and -- 81
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.TD_UNLIMITED, sData ) and -- 82
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.TD_LIMITED, sData ) and -- 83
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.TD_FROM_DATE, sData ) and -- 84
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.TD_TO_DATE, sData ) and -- 85
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.STAJ_CURR_JOB_M, sData ) and -- 86
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.STAJ_CURR_JOB_Y, sData ) and -- 87
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.ALL_STAJ_M, sData ) and -- 88
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.ALL_STAJ_Y, sData ) and -- 89
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.DOG_UPR_FROM_DATE, sData ) and -- 90
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.DOG_UPR_TO_DATE, sData ) and -- 91
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.SOCIALSTAT, sData ) and -- 92
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.IS_ONLINE, sData ) and -- 93
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.BIRTH_COUNTRY, sData ) and -- 94
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.OFFICIAL_DATA, sData ) and -- 95
                                   Schema_GPSys.GPC_Parser.WriteNumber( rCustoms.PROV_PD1Y, sData ) and -- 96
                                   Schema_GPSys.GPC_Parser.WriteNumber( rCustoms.PROV_PDLT, sData ) and -- 97
                                   Schema_GPSys.GPC_Parser.WriteNumber( rCustoms.PROV_LGD, sData ) and -- 98
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.PROV_PHASE, sData ) and -- 99
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_REJ_REASON, sData ) and -- 100
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_COMPL_MATCH, sData ) and -- 101
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_COMPL_DETAILS, sData ) and -- 102
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_VISA_MC_MATCH, sData ) and -- 103
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_VISA_MC_DETAILS, sData ) and -- 104
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_LICENSE, sData ) and -- 105
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_LICENSE_DETAILS, sData ) and -- 106
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.MERCH_PAYMENT_BENEF, sData ) and -- 107
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_HARD_COPIES_FNO, sData ) and -- 108
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_PCI_SAQ_TYPE, sData ) and -- 109
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_PCI_SAQ_VER, sData ) and -- 110
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.MERCH_PCI_COMPL_DATE, sData ) and -- 111
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.MERCH_PCI_VALID_DATE, sData ) and -- 112
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_PCI_SCAN, sData ) and -- 113
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.MERCH_PCI_SCAN_DATE, sData ) and -- 114
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_PCI_GATEWAY, sData ) and -- 115
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.SLUJITEL_REG, sData ) and -- 116
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.MERCH_PARTNER_BANK, sData ) and -- 117
                                   Schema_GPSys.GPC_Parser.WriteString( recBenef.CustName, sData ) and -- 118
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.BIRTH_PLACE, sData ) and -- 119
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.BG_CARD_NO, sData ) and -- 120
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.BG_CARD_IZDADENAOT, sData ) and -- 121
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.BG_CARD_VALID_FROM, sData ) and -- 122
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.BG_CARD_VALID_TO, sData ) and -- 123
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.PASSPORT, sData ) and -- 124
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.PASSPORT_DATE, sData ) and -- 125
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.DRIVING_LICENSE, sData ) and -- 126
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.LATIN_FIRSTNAME, sData ) and -- 127
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.LATIN_LASTNAME, sData ) and -- 128
                                   Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.MONTHS_CURR_ADDR, sData ) and -- 129
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.DOC_VALID_TO, sData ) and -- 130
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.CARD_COUNTRY, sData ) and -- 131
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.PROV_FUND2ASSET, sData ) and -- 132
                                   Schema_GPSys.GPC_Parser.WriteString( rCustoms.PROV_DSCR, sData ) and -- 133
                                   Schema_GPSys.GPC_Parser.WriteDate( rCustoms.FIRMENO_DELO_DATE, sData ) and -- 134
                                   Schema_GPSys.GPC_Parser.WriteDate( dMVRChDate, sData ) and -- 135
                                   Schema_GPSys.GPC_Parser.WriteString( sMVRValidFlag, sData ) and -- 136
                                   Schema_GPSys.GPC_Parser.WriteInteger( nMVRChOper, sData ) and -- 137
                                   true;

                      if ( bRet ) then
                        Schema_GPSys.GPC_Parser.RespAddRow( sData );
                      end if;
                    end if;
                  end if;
                else
                  bNotRightView  := true;
                end if;
              end if;
            end if;

            bRet      := bRet and
                         Schema_RA.GPC_RA.ChkStopField( ii, aIDs.last );
            exit when not bRet;
          end loop;
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Резултатът от търсенето е ОГРОМЕН', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
        end if;
      end if;
    end if;

    if ( not bFind and
        bNotRightView ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Нямате право за преглед на намерените клиенти', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG );
      bRet  := false;
    end if;

    return bRet;
  end CmdCustomsFind;

  --------------------------------------------------------------------------------
  function CmdKontragentiFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues       Schema_GPSys.GPC_Parser.taParamStrings;
    aIDs             Schema_GPSys.OraGPSys.aNumbers;
    iqQ              Schema_GPSys.OraGPSys.EmpCurTyp;
    CustRec          CUSTOMS%rowtype;
    rCustoms         CUSTOMS%rowtype;
    nUniqCode        number;
    nMainCode        integer;
    nCustNo          number;
    sData            varchar2( 4000 );
    sPart            varchar2( 200 );
    sHaveCustNo      varchar2( 1 );
    sNotChkUniqCode  varchar2( 1 );
    sBankAcc         varchar2( 10 );
    bDummy           boolean;
    bRet             boolean;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), CustRec.id ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nUniqCode ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 3 ), nCustNo ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), CustRec.EGN ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 5 ), CustRec.BULSTAT ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), CustRec.DANNUMBER ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 7 ), CustRec.BAE ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 8 ), CustRec.FIRSTNAME ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 9 ), CustRec.MIDLENAME ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 10 ), CustRec.LASTNAME ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 11 ), CustRec.BIC ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 12 ), sPart ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 13 ), CustRec.INITIALS ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 14 ), CustRec.ENCH ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 15 ), CustRec.CLITYPE ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 16 ), sHaveCustNo ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 17 ), sBankAcc ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 18 ), CustRec.DOSTAVCHIK ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 19 ), CustRec.TARGPRED ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 20 ), CustRec.ZASTRAHOVATEL ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 21 ), CustRec.PROVERITEL ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 22 ), CustRec.PREVANTIVNIK );

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      nMainCode            := GPC_Customs.UniqCode2MainCode( nUniqCode );
      sNotChkUniqCode      := case
                                when Schema_RA.GPC_SS.CheckRightFnc_CUser( Schema_RA.GPC_SS.SS_RIGHT_FNC_EXPO + 31 ) then Schema_GPSys.OraGPSys.DocSysTrue
                                else Schema_GPSys.OraGPSys.DocSysFalse
                              end;

      if ( CustRec.id is null or
          CustRec.id = 0 ) then
        if ( CustRec.EGN is not null ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'EGN',
                                                      CustRec.EGN,
                                                      nUniqCode,
                                                      nMainCode,
                                                      false,
                                                      aIDs,
                                                      0,
                                                      'CUSTOMS',
                                                      'ID',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        elsif ( CustRec.BULSTAT is not null ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'BULSTAT',
                                                      CustRec.BULSTAT,
                                                      nUniqCode,
                                                      nMainCode,
                                                      false,
                                                      aIDs,
                                                      0,
                                                      'CUSTOMS',
                                                      'ID',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        elsif ( CustRec.DANNUMBER is not null ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'DANNUMBER',
                                                      CustRec.DANNUMBER,
                                                      nUniqCode,
                                                      nMainCode,
                                                      false,
                                                      aIDs,
                                                      0,
                                                      'CUSTOMS',
                                                      'ID',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        elsif ( CustRec.BAE is not null ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'BAE',
                                                      CustRec.BAE,
                                                      nUniqCode,
                                                      nMainCode,
                                                      false,
                                                      aIDs,
                                                      0,
                                                      'CUSTOMS',
                                                      'ID',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        elsif ( CustRec.ENCH is not null ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'ENCH',
                                                      CustRec.ENCH,
                                                      nUniqCode,
                                                      nMainCode,
                                                      false,
                                                      aIDs,
                                                      0,
                                                      'CUSTOMS',
                                                      'ID',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        elsif ( CustRec.BIC is not null ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'BIC',
                                                      CustRec.BIC,
                                                      nUniqCode,
                                                      nMainCode,
                                                      true,
                                                      aIDs,
                                                      0,
                                                      'CUSTOMS',
                                                      'ID',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        elsif ( CustRec.INITIALS is not null ) then
          bDummy      := GPC_Customs.IsCustomerExist( 'INITIALS',
                                                      CustRec.INITIALS,
                                                      nUniqCode,
                                                      nMainCode,
                                                      true,
                                                      aIDs,
                                                      0,
                                                      'CUSTOMS',
                                                      'ID',
                                                      false,
                                                      false,
                                                      null,
                                                      null,
                                                      sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue
                                                     );
        end if;

        if ( CustRec.FIRSTNAME is not null or
            CustRec.MIDLENAME is not null or
            CustRec.LASTNAME is not null ) then
          CustRec.FIRSTNAME  := upper( CustRec.FIRSTNAME );
          CustRec.MIDLENAME  := upper( CustRec.MIDLENAME );
          CustRec.LASTNAME   := upper( CustRec.LASTNAME );

          for rec in ( select id
                         from CUSTOMS
                        where ( CustRec.FIRSTNAME is null or
                               instr( upper( FIRSTNAME ), CustRec.FIRSTNAME ) != 0 ) and
                              ( CustRec.MIDLENAME is null or
                               instr( upper( MIDLENAME ), CustRec.MIDLENAME ) != 0 ) and
                              ( CustRec.LASTNAME is null or
                               instr( upper( LASTNAME ), CustRec.LASTNAME ) != 0 ) and
                              ( CustRec.DOSTAVCHIK is null or
                               ( CustRec.DOSTAVCHIK = 'T' and
                                CustRec.DOSTAVCHIK = DOSTAVCHIK ) ) and
                              ( CustRec.TARGPRED is null or
                               ( CustRec.TARGPRED = 'T' and
                                CustRec.TARGPRED = TARGPRED ) ) and
                              ( CustRec.ZASTRAHOVATEL is null or
                               ( CustRec.ZASTRAHOVATEL = 'T' and
                                CustRec.ZASTRAHOVATEL = ZASTRAHOVATEL ) ) and
                              ( CustRec.PREVANTIVNIK is null or
                               ( CustRec.PREVANTIVNIK = 'T' and
                                CustRec.PREVANTIVNIK = PREVANTIVNIK ) ) and
                              ( CustRec.PROVERITEL is null or
                               ( CustRec.PROVERITEL = 'T' and
                                CustRec.PROVERITEL = PROVERITEL ) ) ) loop
            Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, rec.id );
          end loop;
        end if;

        if ( nUniqCode is not null and
            nCustNo is not null ) then
          for rec in ( select id
                         from CUSTNUMS
                        where UNIQCODE = nUniqCode and
                              CUSTNO = nCustNo ) loop
            Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, rec.id );
          end loop;
        end if;

        if ( nUniqCode is not null and
            sBankAcc is not null ) then
          CustRec.id  := Schema_GPSys.HeadExpo.BankAcc2IDCust( nUniqCode, sBankAcc );

          if ( CustRec.id is not null ) then
            Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, CustRec.id );
          end if;
        end if;

        if ( sPart is not null ) then
          sPart  := upper( sPart );

          for rec in ( select id
                         from CUSTOMS
                        where instr( upper( FIRSTNAME ), sPart ) != 0 or
                              instr( upper( MIDLENAME ), sPart ) != 0 or
                              instr( upper( LASTNAME ), sPart ) != 0 ) loop
            Schema_GPSys.OraGPSys.Add2UniqArr( aIDs, rec.id );
          end loop;
        end if;
      else
        aIDs( aIDs.count + 1 )  := CustRec.id;
      end if;

      if ( aIDs.count > 0 ) then
        bRet  := aIDs.count < 3000;

        if ( bRet ) then
          Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          Schema_GPSys.GPC_Parser.RespAddArray( 1 );

          for ii in aIDs.first .. aIDs.last loop
            if ( sHaveCustNo is null ) then
              bDummy  := true;
            else
              open iqQ for
                select id
                  from CUSTNUMS
                 where id = aIDs( ii );

              fetch iqQ
                into CustRec.id;

              if ( sHaveCustNo = 'T' ) then
                bDummy  := iqQ%found;
              else
                bDummy  := iqQ%notfound;
              end if;

              close iqQ;
            end if;

            if ( bDummy ) then
              select *
                into rCustoms
                from CUSTOMS
               where id = aIDs( ii );

              if ( nvl( rCustoms.CH_STAMP, 0 ) != 0 and
                  ( CustRec.CLITYPE is null or
                   CustRec.CLITYPE = rCustoms.CLITYPE ) and
                  ( sNotChkUniqCode = Schema_GPSys.OraGPSys.DocSysTrue or
                   rCustoms.UNIQCODE in (nUniqCode, nMainCode) ) ) then
                sData     := null;
                bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rCustoms.id, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.CLITYPE, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.FTYPE, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.FIRSTNAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.MIDLENAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.LASTNAME, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.EGN, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.BULSTAT, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.DANNUMBER, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.BAE, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.BIC, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.DOSTAVCHIK, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.TARGPRED, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.ZASTRAHOVATEL, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.PROVERITEL, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( rCustoms.PREVANTIVNIK, sData );

                if ( bRet ) then
                  Schema_GPSys.GPC_Parser.RespAddRow( sData );
                else
                  exit;
                end if;
              end if;
            end if;
          end loop;
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Резултатът от търсенето е ОГРОМЕН', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
        end if;
      end if;
    end if;

    return bRet;
  exception
    when no_data_found then
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      return true;
  end CmdKontragentiFind;

  --------------------------------------------------------------------------------
  function WriteCustData(
    IDCust  in     integer,
    sData      out varchar2
  )
    return boolean is
    bRet       boolean;
    rCustData  GPC_Customs.recCustData;
  begin
    rCustData.IDCust  := IDCust;
    bRet              := GPC_Customs.GetCustData( rCustData );

    if ( bRet ) then
      bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rCustData.IDCust, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.CLITYPE, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.FTYPE, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.FIRSTNAME, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.SecndName, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.LASTNAME, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.EGN, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.BULSTAT, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.ADDRESS, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.LICHNAKARTA, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rCustData.LKartaIzd, sData ) and
                   Schema_GPSys.GPC_Parser.WriteDate( rCustData.LKartaDate, sData );
    end if;

    return bRet;
  end WriteCustData;

  --------------------------------------------------------------------------------
  function GetCustExposList(
    nIDCust    in integer,
    nUniqCode  in integer
  )
    return boolean is
    bRet       boolean;
    oParamRow  Schema_GPSys.GPC_Parser.trParamEntity3D;
    oParam     Schema_GPSys.GPC_Parser.taParamEntities3D;
  begin
    oParamRow.nRowType          := 1;
    oParamRow.sValue            := Schema_GPSys.GPC_Parser.toN( 0 )||
                                   Schema_GPSys.GPC_Parser.toN( nIDCust )||
                                   Schema_GPSys.GPC_Parser.toN( nUniqCode )||
                                   Schema_GPSys.GPC_Parser.toN( 0 )||
                                   Schema_GPSys.GPC_Parser.toS( null )||
                                   Schema_GPSys.GPC_Parser.toS( null )||
                                   Schema_GPSys.GPC_Parser.toS( null )||
                                   Schema_GPSys.GPC_Parser.toS( null )||
                                   Schema_GPSys.GPC_Parser.toS( null )||
                                   Schema_GPSys.GPC_Parser.toS( null )||
                                   Schema_GPSys.GPC_Parser.toS( null )||
                                   Schema_GPSys.GPC_Parser.toN( 0 )||
                                   Schema_GPSys.GPC_Parser.toS( null );
    oParam( oParam.count + 1 )  := oParamRow;
    bRet                        := Schema_GPSys.Cmd_HeadExpo.CmdGetCustExpos( oParam, 19 );
    return bRet;
  end GetCustExposList;

  --------------------------------------------------------------------------------
  function CanWorkWithCust( CustRec in CUSTOMS%rowtype )
    return boolean is
    bCanWorkWithCust  boolean;
    oList             Schema_GPSys.DocSysList;
  begin
    bCanWorkWithCust      := CustRec.CLITYPE = 'B' or
                             not Schema_GPSys.OraGPSys.Str2Boolean( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'ChkGrafInf', 'F' ) );

    if ( not bCanWorkWithCust ) then
      if ( CustRec.PTR2PIC is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2PIC, oList );
        bCanWorkWithCust  := oList.count > 0; --клиента има закачена графична информация
      end if;
    end if;

    return bCanWorkWithCust;
  end CanWorkWithCust;

  --------------------------------------------------------------------------------
  function CustomsLoad(
    CustRec          in CUSTOMS%rowtype,
    brAppl           in integer,
    dChDate          in date,
    nChOper          in integer,
    nUserId          in integer,
    DocTypeCust      in number,
    DocNumCust       in number,
    DocChStamp       in number,
    bLoadDATA        in boolean,
    bLoadREPR        in boolean,
    bLoadAUTH        in boolean,
    bLoadCONT        in boolean,
    bLoadLINK        in boolean,
    bLoadPIC         in boolean,
    bLoadSTOCK       in boolean,
    bLoadRIVAL       in boolean,
    bLoadVOUCHER     in boolean,
    bLoadWORKER      in boolean,
    bLoadIBAN        in boolean,
    bLoad4FIS        in boolean,
    bLoadURLs        in boolean,
    bLoadCreditInfo  in boolean,
    bArc             in boolean
  )
    return boolean is
    oDoc             Schema_GPSys.RecDocSysType;
    oList            Schema_GPSys.DocSysList;
    rCustData        GPC_Customs.recCustData;
    recBenef         GPC_Customs.recCustData;
    recAgent         GPC_Customs.recCustData;
    recRepr          GPC_Customs.recCustData;
    recCustCredInfo  CUST_CREDITINFO_A%rowtype;
    recDeletedCust   CUST_DELETED_DATA%rowtype;
    bRet             boolean := true;
    bFirstRow        boolean;
    bHasProducts     boolean;
    nRowType         pls_integer;
    nIDReprCust      integer;
    nIDAuthCust      integer;
    nCustNo          integer;
    nIdPic           integer;
    cCmdName         varchar2( 20 ) := 'CustomsLoad';
    sPrefix          varchar2( 4000 );
    sSuffix          varchar2( 4000 );
    sArc             varchar2( 1 );
    sData            varchar2( 4000 );
  begin
    if ( nvl( DocChStamp, 0 ) != 0 ) then
      Schema_DocSys.DOCSYS.GetDocument( DocTypeCust, DocNumCust, DocChStamp, oDoc );
      nRowType          := 1;
      bFirstRow         := true;
      sPrefix           := null;
      sSuffix           := null;
      bHasProducts      := not CustStatus.CustHasActiveProducts( CustRec.id, false, false, true, true, true, false );
      bRet              := bRet and
                           Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                           Schema_GPSys.GPC_Parser.WriteDate( dChDate, sPrefix );
      rCustData         := null;
      rCustData.IDCust  := CustRec.EMPLOYER;

      if ( rCustData.IDCust > 0 ) then
        bRet  := GPC_Customs.GetCustData( rCustData );
      end if;

      begin
        select LAST_DECLINE_DATE,
               LAST_EXPO_END_DATE,
               LAST_OPER_DATE,
               LAST_DOCSYS_DATE,
               DELETE_DATE,
               DISPUTE
          into recDeletedCust.LAST_DECLINE_DATE,
               recDeletedCust.LAST_EXPO_END_DATE,
               recDeletedCust.LAST_OPER_DATE,
               recDeletedCust.LAST_DOCSYS_DATE,
               recDeletedCust.DELETE_DATE,
               recDeletedCust.DISPUTE
          from CUST_DELETED_DATA
         where IDCUST = CustRec.id;
      exception
        when no_data_found then
          recDeletedCust  := null;
      end;

      bRet              := bRet and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2REPR, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2AUTH, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2CONT, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2LINK, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2PIC, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2STOCK, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2RIVAL, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2VOUCHER, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2WORKER, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( CustRec.PTR2IBANS, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( nChOper, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.CLITYPE, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.FTYPE, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.FIRSTNAME, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.SecndName, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.LASTNAME, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.EGN, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( rCustData.BULSTAT, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( CustRec.ADDRESS, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteInteger( nUserId, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteLogic( bHasProducts, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteLogic( CanWorkWithCust( CustRec ), sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteDate( recDeletedCust.DELETE_DATE, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteDate( recDeletedCust.LAST_EXPO_END_DATE, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteDate( recDeletedCust.LAST_OPER_DATE, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteDate( recDeletedCust.LAST_DECLINE_DATE, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( recDeletedCust.DISPUTE, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteDate( recDeletedCust.LAST_DOCSYS_DATE, sSuffix ) and
                           true;
      bRet              := bRet and
                           Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, DocTypeCust, nRowType, bFirstRow, false, sPrefix, sSuffix );
    end if;

    if ( bRet ) then
      if ( bLoadDATA ) then
        if ( CustRec.PTR2DATA is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2DATA, oList );

          if ( CustRec.CLITYPE = 'C' ) then
            nRowType  := 2;
          elsif ( CustRec.CLITYPE = 'F' ) then
            nRowType  := 3;
          elsif ( CustRec.CLITYPE = 'B' ) then
            nRowType  := 4;
          else
            bRet  := false;
          end if;

          if ( bRet ) then
            for ii in oList.first .. oList.last loop
              Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
              recBenef  := null;

              if ( CustRec.MERCH_PAYMENT_BENEF > 0 ) then
                recBenef.IDCust  := CustRec.MERCH_PAYMENT_BENEF;
                bRet             := GPC_Customs.GetCustData( recBenef );
              end if;

              if ( CustRec.ID_AGENT > 0 ) then
                recAgent.IDCust  := CustRec.ID_AGENT;
                bRet             := GPC_Customs.GetCustData( recAgent );
              end if;

              sPrefix   := null;
              sSuffix   := null;
              bRet      := bRet and
                           Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                           Schema_GPSys.GPC_Parser.WriteString( recBenef.CustName, sSuffix ) and
                           Schema_GPSys.GPC_Parser.WriteString( recAgent.CustName, sSuffix ) and
                           Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, nRowType, bFirstRow, false, sPrefix, sSuffix );
              exit when not bRet;
            end loop;
          end if;
        end if;

        if ( bRet and
            CustRec.PTR2CUST is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2CUST, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 5, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;

        if ( bRet and
            CustRec.PTR2CODE is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2CODE, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 10, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;

        if ( bRet and
            CustRec.PTR2ADDRESS is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2ADDRESS, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 16, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;

        -------------------
        if ( bRet and
            CustRec.PTR2DOPINFO is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2DOPINFO, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 17, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;

        -------------------
        if ( bRet and
            CustRec.PTR2ROLES is not null ) then
          Schema_DocSys.DocSys.GetList( CustRec.PTR2ROLES, oList );
          bFirstRow  := true;

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 18, bFirstRow, false, sPrefix );

            if ( not bRet ) then
              exit;
            end if;
          end loop;
        end if;

        -------------------
        if ( bRet and
            CustRec.PTR2DANINFO is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2DANINFO, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 21, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;

        -------------------
        if ( bRet and
            CustRec.PTR2AECOUNTRY is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2AECOUNTRY, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 22, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;

        -------------------
        if ( bRet and
            CustRec.PTR2AEDANINFO is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2AEDANINFO, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 23, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;

        -------------------
        if ( bRet and
            CustRec.PTR2AECONTROLPERS is not null ) then
          bFirstRow  := true;
          Schema_DocSys.DocSys.GetList( CustRec.PTR2AECONTROLPERS, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sPrefix   := null;
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                         Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 24, bFirstRow, false, sPrefix );
            exit when not bRet;
          end loop;
        end if;
      end if;

      if ( bRet and
          bLoadREPR and
          CustRec.PTR2REPR is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2REPR, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          nIDReprCust  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '6.01' );
          sPrefix      := null;
          bRet         := WriteCustData( nIDReprCust, sPrefix );

          if ( bLoad4FIS ) then
            bRet      := bRet and
                         Schema_GPSys.GPC_Parser.WriteInteger( 0, sPrefix );
          end if;

          if ( bRet ) then
            sSuffix         := null;

            select nvl( max( CUSTNO ), 0 )
              into nCustNo
              from CUSTNUMS
             where id = nIDReprCust and
                   UNIQCODE = Schema_RA.GPC_RA.nCurrentUniqCode;

            recRepr.IDCust  := nIDReprCust;
            bRet            := GPC_Customs.GetCustData( recRepr );
            bRet            := bRet and
                               Schema_GPSys.GPC_Parser.WriteInteger( nCustNo, sSuffix ) and
                               Schema_GPSys.GPC_Parser.WriteString( recRepr.LatinName, sSuffix ) and
                               Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 6, bFirstRow, false, sPrefix, sSuffix );
          end if;

          exit when not bRet;
        end loop;
      end if;

      ---------------------------------------------------------------
      if ( bRet and
          bLoadAUTH and
          CustRec.PTR2AUTH is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2AUTH, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          nIDAuthCust  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '7.01' );
          sPrefix      := null;
          bRet         := WriteCustData( nIDAuthCust, sPrefix );

          if ( bRet ) then
            bRet  := Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 7, bFirstRow, false, sPrefix );
          end if;

          exit when not bRet;
        end loop;
      end if;

      ---------------------------------------------------------------
      if ( bRet and
          bLoadCONT and
          CustRec.PTR2CONT is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2CONT, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          sPrefix   := null;
          bRet      := WriteCustData( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '8.01' ), sPrefix );
          bRet      := bRet and
                       Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 8, bFirstRow, false, sPrefix );
          exit when not bRet;
        end loop;
      end if;

      ---------------------------------------------------------------
      if ( bRet and
          bLoadLINK and
          CustRec.PTR2LINK is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2LINK, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          sPrefix   := null;
          bRet      := WriteCustData( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '9.01' ), sPrefix );
          bRet      := bRet and
                       Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 9, bFirstRow, false, sPrefix );
          exit when not bRet;
        end loop;
      end if;

      ---------------------------------------------------------------
      if ( bRet and
          bLoadPIC and
          CustRec.PTR2PIC is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2PIC, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          nIdPic  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '11.01' );

          begin
            select Blob_id
              into nIdPic
              from Schema_DocSys.BLOB_VALUES
             where BLOB_ID = nIdPic;

            bRet  := Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 11, bFirstRow, false );
          exception
            when no_data_found then
              null;
          end;

          exit when not bRet;
        end loop;
      end if;

      if ( bRet and
          bLoadSTOCK and
          CustRec.PTR2STOCK is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2STOCK, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          sPrefix   := null;
          bRet      := WriteCustData( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '12.01' ), sPrefix );
          bRet      := bRet and
                       Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 12, bFirstRow, false, sPrefix );
          exit when not bRet;
        end loop;
      end if;

      -------------------------
      if ( bRet and
          bLoadRIVAL and
          CustRec.PTR2RIVAL is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2RIVAL, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          sPrefix   := null;
          bRet      := WriteCustData( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '13.01' ), sPrefix );
          bRet      := bRet and
                       Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 13, bFirstRow, false, sPrefix );
          exit when not bRet;
        end loop;
      end if;

      ----------------------
      if ( bRet and
          bLoadVOUCHER and
          CustRec.PTR2VOUCHER is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2VOUCHER, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          sPrefix   := null;
          bRet      := WriteCustData( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '14.01' ), sPrefix );
          bRet      := bRet and
                       Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 14, bFirstRow, false, sPrefix );
          exit when not bRet;
        end loop;
      end if;

      -------------------
      if ( bRet and
          bLoadWORKER and
          CustRec.PTR2WORKER is not null ) then
        Schema_DocSys.DocSys.GetList( CustRec.PTR2WORKER, oList );
        bFirstRow  := true;

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          sPrefix   := null;
          bRet      := WriteCustData( Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, cCmdName, '15.01' ), sPrefix );
          bRet      := bRet and
                       Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 15, bFirstRow, false, sPrefix );
          exit when not bRet;
        end loop;
      end if;

      -------------------
      if ( bRet and
          bLoadIBAN and
          CustRec.PTR2IBANS is not null ) then
        bFirstRow  := true;
        Schema_DocSys.DocSys.GetList( CustRec.PTR2IBANS, oList );

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          bRet  := Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 25, bFirstRow, false );
          exit when not bRet;
        end loop;
      end if;

      -------------------
      if ( bRet and
          bLoadURLs and
          CustRec.PTR2URLS is not null ) then
        bFirstRow  := true;
        Schema_DocSys.DocSys.GetList( CustRec.PTR2URLS, oList );

        for ii in oList.first .. oList.last loop
          Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
          sPrefix   := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sPrefix ) and
                       Schema_GPSys.OraGPSys.PutRespFromCmdParam( oDoc, cCmdName, oList( ii ).DocType, 26, bFirstRow, false, sPrefix );
          exit when not bRet;
        end loop;
      end if;

      if ( bRet and
          bLoadCreditInfo ) then
        sArc      := Schema_GPSys.OraGPSys.DocSysBoolean( bArc );

        begin
          select *
            into recCustCredInfo
            from (  select *
                      from (select a.*
                              from Schema_Cust.CUST_CREDITINFO a
                             where ID_CUST = CustRec.id and
                                   ( sArc = 'F' or
                                    CH_STAMP < DocChStamp )
                            union all
                            select a.*
                              from Schema_Cust.CUST_CREDITINFO_A a
                             where ID_CUST = CustRec.id and
                                   CH_STAMP < DocChStamp and
                                   sArc = 'T')
                  order by CH_STAMP desc)
           where rownum < 2;
        exception
          when no_data_found then
            recCustCredInfo  := null;
        end;

        Schema_GPSys.GPC_Parser.RespAddTable( 27 );
        bRet      := bRet and
                     Schema_GPSys.GPC_Parser.WriteInteger( brAppl, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( recCustCredInfo.FLG_BNKRPTCY_IN_GRP, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( recCustCredInfo.LGL_PRCDNG_STTS, sData ) and
                     Schema_GPSys.GPC_Parser.WriteDate( recCustCredInfo.DT_INTTN_LGL_PRCDNGS, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( recCustCredInfo.ENTRPRS_SZ_CRR, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( recCustCredInfo.NMBR_EMPLYS, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( recCustCredInfo.BLNC_SHT_TTL, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( recCustCredInfo.ANNL_TRNVR, sData ) and
                     Schema_GPSys.GPC_Parser.WriteDate( recCustCredInfo.DT_FNNCL_STTMTS, sData ) and
                     Schema_GPSys.GPC_Parser.WriteDate( recCustCredInfo.DT_FNNCL_ADT, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( recCustCredInfo.EQTY, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( recCustCredInfo.EMP_SEC, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( recCustCredInfo.INCM_SRC, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( recCustCredInfo.REASON_FOR_ENTITY_ID_CHANGE, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( recCustCredInfo.GROSS_INCM, sData ) and
                     true;

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        end if;
      end if;
    end if;

    return bRet;
  end CustomsLoad;

  --------------------------------------------------------------------------------
  function CmdCustomsLoad( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues       Schema_GPSys.GPC_Parser.taParamStrings;
    CustRec          CUSTOMS%rowtype;
    sData            varchar2( 4000 );
    iqq              Schema_GPSys.OraGPSys.EmpCurTyp;
    sIBAN            Schema_GPSys.EXPOSITION.IBAN%type;
    rLockInfo        Schema_GPSys.OraGPSys.tLockInfo;
    nRowType         pls_integer;
    bLockCust        boolean;
    bLoadDATA        boolean;
    bLoadREPR        boolean;
    bLoadAUTH        boolean;
    bLoadCONT        boolean;
    bLoadLINK        boolean;
    bLoadPIC         boolean;
    bRet             boolean;
    bLoadSTOCK       boolean;
    bLoadRIVAL       boolean;
    bLoadVOUCHER     boolean;
    bLoadWORKER      boolean;
    bLoadCustExpos   boolean := false;
    bLoadIBAN        boolean := false;
    bLoadURLs        boolean := false;
    bLoadCreditInfo  boolean;
    nUserId          integer := 0;
    nExpoID          integer := 0;
    DocNumCust       number;
    DocTypeCust      number;
    aParams          Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                 Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 aRowValues.count >= 13 and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), CustRec.id ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bLockCust ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 3 ), bLoadDATA ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 4 ), bLoadREPR ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 5 ), bLoadAUTH ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 6 ), bLoadCONT ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 7 ), bLoadLINK ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 8 ), bLoadPIC ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 9 ), bLoadSTOCK ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 10 ), bLoadRIVAL ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 11 ), bLoadVOUCHER ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 12 ), bLoadWORKER ) and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 13 ), CustRec.EGN ) and
                 true;

    if ( bRet and
        aRowValues.exists( 14 ) ) then
      bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 14 ), bLoadCustExpos );
    end if;

    if ( bRet and
        aRowValues.exists( 15 ) ) then
      bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 15 ), bLoadIBAN );
    end if;

    if ( bRet and
        aRowValues.exists( 17 ) ) then
      bRet      := Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 16 ), nExpoID ) and
                   Schema_GPSys.GPC_Parser.ReadString( aRowValues( 17 ), sIBAN );
    end if;

    if ( bRet and
        aRowValues.exists( 18 ) ) then
      bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 18 ), bLoadURLs );
    end if;

    if ( bRet and
        aRowValues.exists( 19 ) ) then
      bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 19 ), bLoadCreditInfo );
    end if;

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

      if ( CustRec.id != 0 or
          nExpoID != 0 or
          sIBAN is not null ) then
        if ( CustRec.id = 0 ) then
          if ( nExpoID != 0 ) then
            CustRec.id             := Schema_GPSys.HeadExpo.IDExpo2IDCust( nExpoID );
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'EXPO_ID';
            aParams( 1 ).ML_VALUE  := to_char( nExpoID );
            Schema_RA.GPC_RA.RespSetErrorText( 'Няма данни за клиент с експозиция: $EXPO_ID$', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG, aParams );
            bRet                   := CustRec.id != 0;
          else
            CustRec.id             := Schema_GPSys.HeadExpo.IBAN2IdCust( sIBAN );
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'IBAN';
            aParams( 1 ).ML_VALUE  := sIBAN;
            Schema_RA.GPC_RA.RespSetErrorText( 'Няма данни за клиент с IBAN:$IBAN$', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG, aParams );
            bRet                   := CustRec.id != 0;
          end if;
        end if;

        if ( bRet ) then
          begin
            select *
              into CustRec
              from CUSTOMS
             where id = CustRec.id;
          exception
            when no_data_found then
              Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
              bRet  := false;
          end;
        end if;
      else
        open iqq for
          select *
            from CUSTOMS
           where EGN = CustRec.EGN;

        fetch iqq
          into CustRec;

        if ( iqq%notfound ) then
          Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          bRet  := false;
        end if;

        close iqq;
      end if;

      if ( bRet ) then
        if ( nvl( CustRec.CH_STAMP, 0 ) != 0 ) then
          bRet      := not bLockCust or
                       Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeCustoms, CustRec.id );

          if ( bRet ) then
            if ( bLockCust and
                bLoadData and
                GPC_Customs.INI_UsersAsCustomers ) then
              begin
                select min( FLDUSERID )
                  into nUserId
                  from Schema_RA.RA_USERS
                 where FLD_CUST_ID = CustRec.ID and
                       FLDDISABLED = 'F';

                if ( nvl( nUserId, 0 ) > 0 ) then
                  aParams.delete;
                  aParams( 1 ).ML_NAME   := 'USER_ID';
                  aParams( 1 ).ML_VALUE  := to_char( nUserId );
                  Schema_RA.GPC_RA.RespSetErrorText( 'Потребител номер $USER_ID$ не може да бъде заключен',
                                                     Schema_GPSys.MLng.ctxCustomers,
                                                     Schema_GPSys.MLng.lngBG
                                                    );
                  bRet                   := Schema_GPSys.OraGPSys.LockSysObj( Schema_GPSys.OraGPSys.LockTypeUsers, nUserId );
                end if;
              exception
                when no_data_found then
                  null;
              end;
            end if;

            if ( bRet ) then
              DocNumCust  := Schema_DocSys.DOCSYS.GetDocNo( CustRec.CH_STAMP, DocTypeCust );
              bRet        := CustomsLoad( CustRec,
                                          1,
                                          null,
                                          0,
                                          nUserId,
                                          DocTypeCust,
                                          DocNumCust,
                                          CustRec.CH_STAMP,
                                          bLoadDATA,
                                          bLoadREPR,
                                          bLoadAUTH,
                                          bLoadCONT,
                                          bLoadLINK,
                                          bLoadPIC,
                                          bLoadSTOCK,
                                          bLoadRIVAL,
                                          bLoadVOUCHER,
                                          bLoadWORKER,
                                          bLoadIBAN,
                                          false,
                                          bLoadURLs,
                                          bLoadCreditInfo,
                                          false
                                         );

              if ( bRet and
                  bLoadCustExpos ) then
                bRet  := GetCustExposList( CustRec.id, CustRec.UNIQCODE );
              end if;

              $if ( Schema_GPSys.OraSys.VerBankUnion or
                   Schema_GPSys.OraSys.VerBankDBank or
                   Schema_GPSys.OraSys.VerBankSAS or
                   Schema_GPSys.OraSys.VerBankTokuda ) $then
                if ( bRet ) then
                  for rec in ( select ID_CUST,
                                      CLITYPE,
                                      ID_GROUP,
                                      CURR_DATE,
                                      DAYS_OVERDUE_GROUP,
                                      greatest( DAYS_GLAV, DAYS_LIH, DAYS_TAX ) as DAYS_OVERDUE,
                                      COURT_SALDO,
                                      OLD_RISK,
                                      NEW_RISK,
                                      CH_DATE,
                                      HAND_RISK_MANAGE
                                 from Schema_Expo.SOFT_COLLECTION_CHG
                                where ID_CUST = CustRec.id ) loop
                    Schema_GPSys.GPC_Parser.RespAddTable( 20 );
                    sData     := null;
                    bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rec.ID_GROUP, sData ) and --  1
                                 Schema_GPSys.GPC_Parser.WriteDate( rec.CURR_DATE, sData ) and --  2
                                 Schema_GPSys.GPC_Parser.WriteInteger( rec.DAYS_OVERDUE, sData ) and --  3
                                 Schema_GPSys.GPC_Parser.WriteInteger( rec.DAYS_OVERDUE_GROUP, sData ) and --  4
                                 Schema_GPSys.GPC_Parser.WriteString( rec.COURT_SALDO, sData ) and --  5
                                 Schema_GPSys.GPC_Parser.WriteString( rec.OLD_RISK, sData ) and --  6
                                 Schema_GPSys.GPC_Parser.WriteString( rec.NEW_RISK, sData ) and
                                 Schema_GPSys.GPC_Parser.WriteString( rec.HAND_RISK_MANAGE, sData ) and
                                 true;

                    if ( bRet ) then
                      Schema_GPSys.GPC_Parser.RespAddRow( sData );
                    else
                      exit;
                    end if;
                  end loop;
                end if;
              $end
            end if;
          else
            rLockInfo              := Schema_GPSys.OraGPSys.GetLockInfo( Schema_GPSys.OraGPSys.LockTypeCustoms, CustRec.id );
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'USER_NAME';
            aParams( 1 ).ML_VALUE  := rLockInfo.sUserName;
            aParams( 2 ).ML_NAME   := 'LOCK_DATE';
            aParams( 2 ).ML_VALUE  := to_char( rLockInfo.dLock, 'dd.mm.yyyy/HH24:MI:SS' );
            Schema_RA.GPC_RA.RespSetErrorText( 'Досието е заключено от потребител $USER_NAME$ на дата/час $LOCK_DATE$',
                                               Schema_GPSys.MLng.ctxCustomers,
                                               Schema_GPSys.MLng.lngBG,
                                               aParams
                                              );
          end if;
        end if;
      end if;
    end if;

    return bRet;
  end CmdCustomsLoad;

  --------------------------------------------------------------------------------
  function CmdCustomsLoadArc( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues       Schema_GPSys.GPC_Parser.taParamStrings;
    oDoc             Schema_GPSys.RecDocSysType;
    DocChStamps      Schema_GPSys.NumbersCollectionType;
    CustRec          CUSTOMS%rowtype;
    nRowType         pls_integer;
    nCount           integer;
    nTmp             integer;
    brAppl           integer := 0;
    nPTRDoc          integer;
    bLoadDATA        boolean;
    bLoadREPR        boolean;
    bLoadAUTH        boolean;
    bLoadCONT        boolean;
    bLoadLINK        boolean;
    bLoadPIC         boolean;
    bStop            boolean;
    bRet             boolean;
    bLoadSTOCK       boolean;
    bLoadRIVAL       boolean;
    bLoadVOUCHER     boolean;
    bLoadWORKER      boolean;
    bLoad4FIS        boolean := false;
    bLoadIBAN        boolean := false;
    bLoadURLs        boolean;
    bLoadCreditInfo  boolean;
    DocNumCust       number;
    DocTypeCust      number;
    nChOper          number;
    dChDate          date;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                 Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 aRowValues.count >= 13 and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), CustRec.id ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bLoadDATA ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 3 ), bLoadREPR ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 4 ), bLoadAUTH ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 5 ), bLoadCONT ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 6 ), bLoadLINK ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 7 ), bLoadPIC ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 8 ), nPTRDoc ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 9 ), nCount ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 10 ), bLoadSTOCK ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 11 ), bLoadRIVAL ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 12 ), bLoadVOUCHER ) and
                 Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 13 ), bLoadWORKER );

    if ( bRet and
        aRowValues.exists( 14 ) ) then
      bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 14 ), bLoad4FIS );
    end if;

    if ( bRet and
        aRowValues.exists( 15 ) ) then
      bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 15 ), bLoadURLs );
    end if;

    if ( bRet and
        aRowValues.exists( 16 ) ) then
      bRet  := Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 16 ), bLoadCreditInfo );
    end if;

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );

      if ( nvl( nPTRDoc, 0 ) = 0 ) then
        begin
          select *
            into CustRec
            from CUSTOMS
           where id = CustRec.id;
        exception
          when no_data_found then
            Schema_RA.GPC_RA.RespSetErrorText( 'Няма изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
            bRet  := false;
        end;
      end if;

      if ( bRet ) then
        if ( nvl( CustRec.CH_STAMP, 0 ) != 0 ) then
          DocNumCust  := Schema_DocSys.DOCSYS.GetDocNo( CustRec.CH_STAMP, DocTypeCust );
          Schema_DocSys.DOCSYS.GetDocStamps( DocNumCust, true, DocChStamps );

          if ( nvl( nCount, 0 ) > 0 and
              DocChStamps.count > nCount ) then
            nTmp  := DocChStamps.count - nCount + 1;
          else
            nTmp  := DocChStamps.first;
          end if;

          for jj in nTmp .. DocChStamps.last loop
            brAppl                     := brAppl + 1;

            if ( not ( Schema_RA.GPC_RA.CheckStopField( bStop, jj, jj ) and
                      ( not bStop ) ) ) then
              bRet  := false;
              exit;
            end if;

            Schema_DocSys.DOCSYS.GetDocument( DocTypeCust, DocNumCust, DocChStamps( jj ), oDoc );
            CustRec.PTR2DATA           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Dosie' );
            CustRec.PTR2CUST           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.CustNumber' );
            CustRec.PTR2CODE           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Code' );
            --------
            CustRec.PTR2REPR           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Repres' );
            CustRec.PTR2AUTH           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Proxy' );
            CustRec.PTR2CONT           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Contact' );
            CustRec.PTR2LINK           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Link' );
            CustRec.PTR2PIC            := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Pic' );
            CustRec.PTR2STOCK          := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Stock' );
            CustRec.PTR2RIVAL          := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Rival' );
            CustRec.PTR2VOUCHER        := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Voucher' );
            CustRec.PTR2WORKER         := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.Worker' );
            CustRec.PTR2ADDRESS        := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.ListAddresses' );
            CustRec.PTR2DANINFO        := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.DanInfo' );
            CustRec.PTR2AECOUNTRY      := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.AECountry' );
            CustRec.PTR2AEDANINFO      := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.AEDanInfo' );
            CustRec.PTR2AECONTROLPERS  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.AEControlPers' );
            CustRec.PTR2IBANS          := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.IBANList' );
            CustRec.PTR2URLS           := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.URLs' );
            nChOper                    := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustSaveNEW', '1.ChOper' );
            dChDate                    := Schema_DocSys.DOCSYS.GetDateByChStamp( DocChStamps( jj ) );
            bRet                       := CustomsLoad( CustRec,
                                                       brAppl,
                                                       dChDate,
                                                       nChOper,
                                                       0,
                                                       DocTypeCust,
                                                       DocNumCust,
                                                       DocChStamps( jj ),
                                                       bLoadDATA,
                                                       bLoadREPR,
                                                       bLoadAUTH,
                                                       bLoadCONT,
                                                       bLoadLINK,
                                                       bLoadPIC,
                                                       bLoadSTOCK,
                                                       bLoadRIVAL,
                                                       bLoadVOUCHER,
                                                       bLoadWORKER,
                                                       false,
                                                       bLoad4FIS,
                                                       bLoadURLs,
                                                       bLoadCreditInfo,
                                                       true
                                                      );
            exit when not bRet;
          end loop;
        else
          if ( bLoadREPR ) then
            CustRec.PTR2REPR  := nPTRDoc;
          elsif ( bLoadAUTH ) then
            CustRec.PTR2AUTH  := nPTRDoc;
          elsif ( bLoadCONT ) then
            CustRec.PTR2CONT  := nPTRDoc;
          elsif ( bLoadLINK ) then
            CustRec.PTR2LINK  := nPTRDoc;
          elsif ( bLoadPIC ) then
            CustRec.PTR2PIC  := nPTRDoc;
          elsif ( bLoadSTOCK ) then
            CustRec.PTR2STOCK  := nPTRDoc;
          elsif ( bLoadRIVAL ) then
            CustRec.PTR2RIVAL  := nPTRDoc;
          elsif ( bLoadVOUCHER ) then
            CustRec.PTR2VOUCHER  := nPTRDoc;
          elsif ( bLoadWORKER ) then
            CustRec.PTR2WORKER  := nPTRDoc;
          elsif ( bLoadIBAN ) then
            CustRec.PTR2IBANS  := nPTRDoc;
          elsif ( bLoadURLs ) then
            CustRec.PTR2URLS  := nPTRDoc;
          end if;

          bRet      := CustomsLoad( CustRec,
                                    1,
                                    null,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    bLoadDATA,
                                    bLoadREPR,
                                    bLoadAUTH,
                                    bLoadCONT,
                                    bLoadLINK,
                                    bLoadPIC,
                                    bLoadSTOCK,
                                    bLoadRIVAL,
                                    bLoadVOUCHER,
                                    bLoadWORKER,
                                    false,
                                    bLoad4FIS,
                                    bLoadURLs,
                                    bLoadCreditInfo,
                                    true
                                   );
        end if;
      end if;
    end if;

    return bRet;
  end CmdCustomsLoadArc;

  --------------------------------------------------------------------------------
  function CmdCustomsConnFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues    Schema_GPSys.GPC_Parser.taParamStrings;
    nIdCust       CUSTOMS.id%type;
    sData         varchar2( 4000 );
    dRepDate      date;
    bRet          boolean;
    bExportToDWH  boolean := false;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIdCust ) and
                 ( ( not aRowValues.exists( 3 ) ) or
                  ( Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bExportToDWH ) and
                   Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 3 ), dRepDate ) ) ) and
                 true;
    $if ( not Schema_GPSys.OraSys.bModule_ExportDWH ) $then
      bExportToDWH  := false;
    $end

    if ( bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      Schema_GPSys.GPC_Parser.RespAddTable( 1 );
      nIdCust  := nvl( nIdCust, 0 );

      for rec in ( select a.IDREL1,
                          b.CLITYPE as CLITYPE1,
                          b.FTYPE as FTYPE1,
                          b.FIRSTNAME as FIRSTNAME1,
                          b.MIDLENAME as MIDLENAME1,
                          b.LASTNAME as LASTNAME1,
                          b.EGN as EGN1,
                          b.BULSTAT as BULSTAT1,
                          b.ENCH as ENCH1,
                          a.TYPEREL,
                          a.IDREL2,
                          c.CLITYPE as CLITYPE2,
                          c.FTYPE as FTYPE2,
                          c.FIRSTNAME as FIRSTNAME2,
                          c.MIDLENAME as MIDLENAME2,
                          c.LASTNAME as LASTNAME2,
                          c.EGN as EGN2,
                          c.BULSTAT as BULSTAT2,
                          c.ENCH as ENCH2
                     from (select IDCONN as IDREL1,
                                  IDCUST as IDREL2,
                                  TYPE_CONN as TYPEREL
                             from CUST_CONN
                            where nIdCust = 0 or
                                  IDCUST = nIdCust
                           union
                           select IDCUST as IDREL1,
                                  IDCONN as IDREL2,
                                  TYPE_CONN as TYPEREL
                             from CUST_CONN
                            where IDCONN = nIdCust) a,
                          CUSTOMS b,
                          CUSTOMS c
                    where a.IDREL1 = b.id and
                          a.IDREL2 = c.id ) loop
        if ( not bExportToDWH ) then
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rec.IDREL1, sData ) and --  1
                       Schema_GPSys.GPC_Parser.WriteString( rec.CLITYPE1, sData ) and --  2
                       Schema_GPSys.GPC_Parser.WriteString( rec.FTYPE1, sData ) and --  3
                       Schema_GPSys.GPC_Parser.WriteString( rec.FIRSTNAME1, sData ) and --  4
                       Schema_GPSys.GPC_Parser.WriteString( rec.MIDLENAME1, sData ) and --  5
                       Schema_GPSys.GPC_Parser.WriteString( rec.LASTNAME1, sData ) and --  6
                       Schema_GPSys.GPC_Parser.WriteString( rec.EGN1, sData ) and --  7
                       Schema_GPSys.GPC_Parser.WriteString( rec.BULSTAT1, sData ) and --  8
                       Schema_GPSys.GPC_Parser.WriteString( rec.ENCH1, sData ) and --  9
                       Schema_GPSys.GPC_Parser.WriteString( rec.TYPEREL, sData ) and -- 10
                       Schema_GPSys.GPC_Parser.WriteInteger( rec.IDREL2, sData ) and -- 11
                       Schema_GPSys.GPC_Parser.WriteString( rec.CLITYPE2, sData ) and -- 12
                       Schema_GPSys.GPC_Parser.WriteString( rec.FTYPE2, sData ) and -- 13
                       Schema_GPSys.GPC_Parser.WriteString( rec.FIRSTNAME2, sData ) and -- 14
                       Schema_GPSys.GPC_Parser.WriteString( rec.MIDLENAME2, sData ) and -- 15
                       Schema_GPSys.GPC_Parser.WriteString( rec.LASTNAME2, sData ) and -- 16
                       Schema_GPSys.GPC_Parser.WriteString( rec.EGN2, sData ) and -- 17
                       Schema_GPSys.GPC_Parser.WriteString( rec.BULSTAT2, sData ) and -- 18
                       Schema_GPSys.GPC_Parser.WriteString( rec.ENCH2, sData ); -- 19

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;
        else
          $if Schema_GPSys.OraSys.bModule_ExportDWH $then
            insert into Schema_ImportExport.REP_CUST_CONN(
                          REP_DATE, -- 1
                          IDREL1, -- 2
                          CLITYPE1, -- 3
                          FTYPE1, -- 4
                          FIRSTNAME1, -- 5
                          MIDLENAME1, -- 6
                          LASTNAME1, -- 7
                          EGN1, -- 8
                          BULSTAT1, -- 9
                          ENCH1, -- 10
                          TYPEREL, -- 11
                          IDREL2, -- 12
                          CLITYPE2, -- 13
                          FTYPE2, -- 14
                          FIRSTNAME2, -- 15
                          MIDLENAME2, -- 16
                          LASTNAME2, -- 17
                          EGN2, -- 18
                          BULSTAT2, -- 19
                          ENCH2 -- 20
                        )
                 values ( dRepDate, -- 1
                          rec.IDREL1, -- 2
                          rec.CLITYPE1, -- 3
                          rec.FTYPE1, -- 4
                          rec.FIRSTNAME1, -- 5
                          rec.MIDLENAME1, -- 6
                          rec.LASTNAME1, -- 7
                          rec.EGN1, -- 8
                          rec.BULSTAT1, -- 9
                          rec.ENCH1, -- 10
                          rec.TYPEREL, -- 11
                          rec.IDREL2, -- 12
                          rec.CLITYPE2, -- 13
                          rec.FTYPE2, -- 14
                          rec.FIRSTNAME2, -- 15
                          rec.MIDLENAME2, -- 16
                          rec.LASTNAME2, -- 17
                          rec.EGN2, -- 18
                          rec.BULSTAT2, -- 19
                          rec.ENCH2 -- 20
                         );
          $else
            null;
          $end
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdCustomsConnFind;

  --------------------------------------------------------------------------------
  function CmdCustomsFromDate( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues   Schema_GPSys.GPC_Parser.taParamStrings;
    oDocCust     Schema_GPSys.RecDocSysType;
    oDoc         Schema_GPSys.RecDocSysType;
    acAddress    Schema_GPSys.VarcharCollectionType;
    rCustAddres  GPC_CMD_Cust.rAddress;
    oList        Schema_GPSys.DocSysList;
    nUniqCode    integer;
    nCustNo      integer;
    nCurrent     integer := 0;
    DocNumCust   number;
    DocTypeCust  number;
    nEndCh       number;
    nTempCh      number;
    nTypeDoc     number;
    cCmdName     varchar2( 40 );
    CustName     varchar2( 4000 );
    CustType     varchar2( 4000 );
    sData        varchar2( 4000 );
    sAddress     varchar2( 4000 );
    dOutDate1    date;
    dOutDate2    date;
    dDate        date;
    bDummy       boolean;
    bRet         boolean;
    bStop        boolean;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadDate( aRowValues( 1 ), dDate ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 2 ), nUniqCode );
    cCmdName  := 'CustomsLoad';

    for rec in (  select c.id,
                         c.CH_STAMP,
                         c.CLITYPE,
                         c.PTR2DATA
                    from CUSTOMS c
                   where ( select count( n.id )
                             from CUSTNUMS n
                            where n.id = c.id and
                                  n.Uniqcode = nUniqCode ) > 0
                order by c.CLITYPE ) loop
      nCurrent    := nCurrent + 1;

      if ( not ( Schema_RA.GPC_RA.CheckStopField( bStop, nCurrent, nCurrent ) and
                ( not bStop ) ) ) then
        bRet  := false;
        exit;
      end if;

      DocNumCust  := Schema_DocSys.DOCSYS.GetDocNo( rec.CH_STAMP, DocTypeCust );
      nEndCh      := Schema_DocSys.DOCSYS.GetDocStampByDate( DocNumCust, dDate, nTempCh, dOutDate1, dOutDate2 );

      if ( Schema_DocSys.DOCSYS.GetDateByChStamp( nEndCh ) <= dDate ) then
        Schema_DocSys.DOCSYS.GetDocument( DocTypeCust, DocNumCust, nEndCh, oDocCust );
        CustType  := Schema_GPSys.OraGPSys.GetFromCmdString( oDocCust, cCmdName, '1.03' );
        nTypeDoc  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDocCust, 'CustSaveNEW', '1.Dosie' );

        if ( nTypeDoc is not null ) then
          Schema_DocSys.DocSys.GetList( nTypeDoc, oList );

          select min( CUSTNO )
            into nCustNo
            from CUSTNUMS
           where id = rec.id and
                 Uniqcode = nUniqCode;

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sData     := null;
            bDummy    := GPC_Customs.GetCustAddress( nTypeDoc, null, null, acAddress, rCustAddres, GPC_Customs.defPrimaryAddr, true );
            sAddress  := acAddress( 1 ) || acAddress( 2 ) || acAddress( 3 ) || acAddress( 4 ) || acAddress( 5 ) || acAddress( 6 ) || acAddress( 7 ) || acAddress( 8 ) || acAddress( 9 );
            bRet      := Schema_GPSys.GPC_Parser.WriteString( rec.CLITYPE, sData ) and
                         Schema_GPSys.GPC_Parser.WriteString( CustType, sData ) and
                         Schema_GPSys.GPC_Parser.WriteInteger( rec.id, sData ) and
                         Schema_GPSys.GPC_Parser.WriteInteger( nCustNo, sData );

            if ( bRet ) then
              if ( rec.CLITYPE = 'C' ) then
                CustName  := Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.002' );
                CustName  := Custname || ' ' || Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.003' );
                CustName  := Custname || ' ' || Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.004' );
                bRet      := Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.001' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( CustName, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.017' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.018' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.035' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.036' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '2.044' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sAddress, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( ' ', sData );
              elsif ( rec.CLITYPE = 'F' ) then
                bRet      := Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.003' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.001' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.019' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.020' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.011' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.012' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.056' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sAddress, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '3.010' ), sData );
              elsif ( rec.CLITYPE = 'B' ) then
                bRet      := Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '4.03' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '4.01' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '4.12' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '4.13' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '4.18' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '4.19' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, cCmdName, '4.26' ), sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( sAddress, sData ) and
                             Schema_GPSys.GPC_Parser.WriteString( ' ', sData );
              else
                bRet  := false;
              end if;
            end if;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddTable( 1 );
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
              sData  := null;
            else
              Schema_RA.GPC_RA.RespSetErrorText( 'Грешка при зареждане на данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
              bRet  := false;
            end if;
          end loop;
        end if;
      end if;
    end loop;

    return bRet;
  end CmdCustomsFromDate;

  --------------------------------------------------------------------------------
  function CmdCustGetNameLatByBIC( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    rCustoms    CUSTOMS%rowtype;
    cBICCode    CUSTOMS.BIC%type;
    bRet        boolean;
    sData       varchar2( 4000 );
    aParams     Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := aParamEntities3D( 1 ).nRowType = 1 and
                 Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 aRowValues.count >= 1 and
                 Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), cBICCode ) and
                 cBICCode is not null;

    if ( bRet ) then
      begin
        select *
          into rCustoms
          from CUSTOMS
         where BIC = cBICCode;
      exception
        when others then
          bRet                   := false;
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'BIC_CODE';
          aParams( 1 ).ML_VALUE  := cBICCode;
          Schema_RA.GPC_RA.RespSetErrorText( 'Няма досие с BIC код:$BIC_CODE$', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG, aParams );
      end;

      if ( bRet is not null ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 1 );
        sData     := null;
        bRet      := Schema_GPSys.GPC_Parser.WriteString( rCustoms.LATINNAME, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( rCustoms.LATINADDR, sData );

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
        end if;
      end if;
    end if;

    return bRet;
  end CmdCustGetNameLatByBIC;

  --------------------------------------------------------------------------------
  function CmdRelationShipMgrsFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    sData     varchar2( 4000 );
    bRet      boolean := true;
    bStop     boolean;
    nCurrent  integer := 0;
  begin
    Schema_GPSys.GPC_Parser.RespAddTable( 1 );

    for rec in ( select *
                   from RELATIONSHIPMGRS ) loop
      nCurrent  := nCurrent + 1;

      if ( not ( Schema_RA.GPC_RA.CheckStopField( bStop, nCurrent, nCurrent ) and
                ( not bStop ) ) ) then
        exit;
      end if;

      sData     := null;
      bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rec.FLDUSERID, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rec.FLDUSERFNAME, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rec.FLDDISABLED, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rec.PROFIT_CENTER, sData ) and
                   Schema_GPSys.GPC_Parser.WriteString( rec.CODE, sData );

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddRow( sData );
      end if;
    end loop;

    return bRet;
  end CmdRelationShipMgrsFind;

  --------------------------------------------------------------------------------
  function CmdRelationShipMgrsSave( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    ii           pls_integer;
    nRowType     pls_integer;
    aRowValues   Schema_GPSys.GPC_Parser.taParamStrings;
    ManagerData  RELATIONSHIPMGRS%rowtype;
    bRet         boolean;
    sSEGMENT     varchar2( 10 );
    sOper        varchar2( 10 );
    handle       varchar2( 128 );
    nCount       integer;
    bDummy       boolean;
    aParams      Schema_RA.GPC_RA.tblErrParams;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet  := aParamEntities3D.first is not null;

    if ( bRet ) then
      bRet  := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues );

      if ( bRet ) then
        if ( aParamEntities3D( 1 ).nRowType = 1 ) then
          bRet      := aRowValues.count >= 6 and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), ManagerData.FLDUSERID ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), ManagerData.FLDUSERFNAME ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), ManagerData.PROFIT_CENTER ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), sSEGMENT ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 5 ), sOper ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), ManagerData.FLDDISABLED ) and
                       ManagerData.FLDUSERID > 0;
        else
          bRet  := false;
        end if;
      end if;

      if ( bRet ) then
        dbms_lock.allocate_unique( 'Schema_Cust.RelationShipMgrsSave' || ManagerData.FLDUSERID, handle );
        nCount                   := dbms_lock.request( handle, dbms_lock.x_mode, 0, false );
        ManagerData.FLDDISABLED  := nvl( ManagerData.FLDDISABLED, 'T' );

        if ( nCount = 0 ) then
          if ( sOper = 'NEW' ) then
            select count( 1 )
              into ii
              from RELATIONSHIPMGRS
             where FLDUSERID = ManagerData.FLDUSERID;

            if ( ii = 0 ) then
              insert into RELATIONSHIPMGRS(
                            FLDUSERID,
                            FLDUSERFNAME,
                            PROFIT_CENTER,
                            FLDDISABLED,
                            CODE
                          )
                   values ( ManagerData.FLDUSERID,
                            ManagerData.FLDUSERFNAME,
                            ManagerData.PROFIT_CENTER,
                            ManagerData.FLDDISABLED,
                            lpad( substr( ManagerData.PROFIT_CENTER, 0, 4 ), 4, '0' ) || substr( sSEGMENT, 0, 1 ) || lpad( GPC_Customs.Get_Number( 'MGRS_' || ManagerData.PROFIT_CENTER ), 3, '0' )
                           );
            else
              aParams.delete;
              aParams( 1 ).ML_NAME   := 'FLDUSERID';
              aParams( 1 ).ML_VALUE  := to_char( ManagerData.FLDUSERID );
              Schema_RA.GPC_RA.RespSetErrorText( 'Relationship Manager $FLDUSERID$ вече съществува в базата', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG, aParams );
              bRet                   := false;
            end if;
          else
            update RELATIONSHIPMGRS
               set FLDUSERFNAME  = ManagerData.FLDUSERFNAME,
                   FLDDISABLED   = ManagerData.FLDDISABLED
             where FLDUSERID = ManagerData.FLDUSERID;

            bRet  := sql%rowcount = 1;
          end if;

          if ( bRet ) then
            commit;
          end if;

          nCount  := dbms_lock.RELEASE( handle );
        end if;
      end if;
    end if;

    return bRet;
  end CmdRelationShipMgrsSave;

  --------------------------------------------------------------------------------
  procedure XX is
    bRet      boolean;
    oRespRow  Schema_GPSys.GPC_Parser.trParamEntity3D;
    oResp     Schema_GPSys.GPC_Parser.taParamEntities3D;
  begin
    Schema_RA.GPC_RA.ClearResponce;
    --
    oRespRow.nRowType         := 1;
    oRespRow.sValue           := '"EDT"' || '&' || '1' || '&' || '"F"' || '&' || '"LF"' || '&' || '100' || '&' || '0' || '&';
    oResp( oResp.count + 1 )  := oRespRow;
    -- гражданин
    oRespRow.nRowType         := 2;
    oRespRow.sValue           := '"8299999998"' ||
                                 '&' ||
                                 '"Николай"' ||
                                 '&' ||
                                 '"hahaddd"' ||
                                 '&' ||
                                 '"asdfg"' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&' ||
                                 '&';
    oResp( oResp.count + 1 )  := oRespRow;
    -- фирма
    /*  oRespRow.nRowType         := 3;
        oRespRow.sValue           := '"GP Consulting"' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&' ||
                                     '&';
        oResp( oResp.count + 1 )  := oRespRow;*/
    -- банка
    /*  oRespRow.nRowType         := 4;
        oRespRow.sValue           := '"Банка"' || '&' || '"68096809"' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&' || '&';
        oResp( oResp.count + 1 )  := oRespRow;*/
    --
    /*  oRespRow.nRowType         := 5;
        oRespRow.sValue           := '100' || '&' || '1111';
        oResp( oResp.count + 1 )  := oRespRow;
        --
        oRespRow.nRowType         := 5;
        oRespRow.sValue           := '101' || '&' || '2222';
        oResp( oResp.count + 1 )  := oRespRow;*/
    --
    oRespRow.nRowType         := 6;
    oRespRow.sValue           := '123' || '&' || '"Director"' || '&' || '"TDD 1"';
    oResp( oResp.count + 1 )  := oRespRow;
    --
    oRespRow.nRowType         := 6;
    oRespRow.sValue           := '124' || '&' || '"Boss"' || '&' || '"TDD 2"';
    oResp( oResp.count + 1 )  := oRespRow;
    --
    oRespRow.nRowType         := 7;
    oRespRow.sValue           := '123' || '&' || '"Tegli"' || '&' || '"1112"' || '&' || '20030303' || '&' || '11' || '&' || 'USD100' || '&';
    oResp( oResp.count + 1 )  := oRespRow;
    --
    oRespRow.nRowType         := 7;
    oRespRow.sValue           := '124' || '&' || '"Vnasia"' || '&' || '"1122"' || '&' || '20030505' || '&' || '12' || '&' || 'EUR200.00000000' || '&';
    oResp( oResp.count + 1 )  := oRespRow;
    --
    oRespRow.nRowType         := 8;
    oRespRow.sValue           := '123' ||
                                 '&' ||
                                 '"Sofia"' ||
                                 '&' ||
                                 '"Sofiiska"' ||
                                 '&' ||
                                 '"Sofia"' ||
                                 '&' ||
                                 '"1618"' ||
                                 '&' ||
                                 '"Veslec"' ||
                                 '&' ||
                                 '"29"' ||
                                 '&' ||
                                 '"166"' ||
                                 '&' ||
                                 '"088"' ||
                                 '&' ||
                                 '"fax"' ||
                                 '&' ||
                                 '"telex"' ||
                                 '&' ||
                                 '"e-mail"' ||
                                 '&' ||
                                 '"web"';
    oResp( oResp.count + 1 )  := oRespRow;
    --
    oRespRow.nRowType         := 8;
    oRespRow.sValue           := '124' ||
                                 '&' ||
                                 '"Sofia 1"' ||
                                 '&' ||
                                 '"Sofiiska 1"' ||
                                 '&' ||
                                 '"Sofia 1"' ||
                                 '&' ||
                                 '"1618"' ||
                                 '&' ||
                                 '"Veslec"' ||
                                 '&' ||
                                 '"29"' ||
                                 '&' ||
                                 '"166"' ||
                                 '&' ||
                                 '"088"' ||
                                 '&' ||
                                 '"fax"' ||
                                 '&' ||
                                 '"telex"' ||
                                 '&' ||
                                 '"e-mail"' ||
                                 '&' ||
                                 '"web"';
    oResp( oResp.count + 1 )  := oRespRow;
    --
    oRespRow.nRowType         := 9;
    oRespRow.sValue           := '123' || '&' || '"Bashta"';
    oResp( oResp.count + 1 )  := oRespRow;
    --
    --oRespRow.nRowType         := 9;
    --oRespRow.sValue           := '124' || '&' || '"Maika"';
    --oResp( oResp.count + 1 )  := oRespRow;
    --
    oRespRow.nRowType         := 11;
    oRespRow.sValue           := '5' || '&' || '0' || '&' || '"657657"' || '&';
    oResp( oResp.count + 1 )  := oRespRow;
    oRespRow.nRowType         := 11;
    oRespRow.sValue           := '6' || '&' || '0' || '&' || '"657657"' || '&';
    oResp( oResp.count + 1 )  := oRespRow;
    bRet                      := CmdCustomsSave( oResp );
    Schema_RA.GPC_RA.DisplayResponce( bRet );
  end XX;

  --------------------------------------------------------------------------------
  function Cmd_REQLOG_CustomsLoadPics( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    bRet           boolean := true;
    aRowValues     Schema_GPSys.GPC_Parser.taParamStrings;
    aConfigs       Schema_GPSys.NumbersCollectionType;
    sData          varchar2( 4000 );
    sDateTimeFrom  varchar2( 21 );
    sRegDate       varchar2( 21 );
    dDateTimeFrom  date;
    sDateTimeTo    varchar2( 21 );
    dDateTimeTo    date;
    nUserId        pls_integer;
    nCustId        pls_integer;
    nRowType       pls_integer;
    ii             pls_integer;

    cursor qReqLogFind(
      dpDateFrom  in date,
      dpDateTo    in date,
      npUserId    in integer,
      npCustId    in integer,
      qaConfigs   in Schema_GPSys.NumbersCollectionType
    ) is
      select *
        from Schema_RA.REQLOG_REGISTER
       where REG_DATE between dpDateFrom and dpDateTo and
             ID_REQLOG_CONFIG in (select column_value
                                    from table( qaConfigs )) and
             ( npUserId = 0 or
              ID_USER = npUserId ) and
             ( nCustId = 0 or
              PARAM1 = to_char( nCustId ) );

    rReqLog        qReqLogFind%rowtype;
    nCount         integer := 0;
    rCustData      GPC_Customs.recCustData;
  begin
    ii        := aParamEntities3D.first;
    aConfigs  := Schema_GPSys.NumbersCollectionType( );

    while ( ii is not null and
           bRet ) loop
      nRowType  := aParamEntities3D( ii ).nRowType;
      bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues );

      if ( bRet ) then
        if ( nRowType = 1 ) then -- общи данни
          bRet      := aRowValues.count >= 4 and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), sDateTimeFrom ) and
                       Schema_GPSys.GPC_Parser.ReadDateTime( sDateTimeFrom, dDateTimeFrom ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), sDateTimeTo ) and
                       Schema_GPSys.GPC_Parser.ReadDateTime( sDateTimeTo, dDateTimeTo ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 3 ), nUserId ) and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 4 ), nCustId ) and
                       true;
          nUserId   := nvl( nUserId, 0 );
          nCustId   := nvl( nCustId, 0 );
        elsif ( nRowType = 2 ) then
          aConfigs.extend;
          bRet      := aRowValues.count >= 1 and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), aConfigs( aConfigs.count ) ) and
                       true;
        end if;
      end if;

      ii        := aParamEntities3D.next( ii );
    end loop;

    if ( bRet ) then
      Schema_GPSys.GPC_Parser.RespAddTable( 1 );

      open qReqLogFind( dDateTimeFrom, dDateTimeTo, nUserId, nCustId, aConfigs );

      loop
        fetch qReqLogFind
          into rReqLog;

        exit when qReqLogFind%notfound or
                  not bRet;
        nCount     := nCount + 1;
        rCustData  := null;

        if ( rReqLog.ID_REQLOG_CONFIG = Schema_RA.GPC_RA.ReqLog_Config_CustGraphicsInfo ) then
          rCustData.IDCust  := to_number( rReqLog.PARAM1, Schema_GPSys.GPC_Parser.FORMAT_ORACLE_NUMBER );
          bRet              := GPC_Customs.GetCustData( rCustData );
        elsif ( rReqLog.ID_REQLOG_CONFIG = Schema_RA.GPC_RA.ReqLog_Config_CustFromEIFSave ) then
          rCustData.IDCust  := to_number( rReqLog.PARAM6, Schema_GPSys.GPC_Parser.FORMAT_ORACLE_NUMBER );
          bRet              := GPC_Customs.GetCustData( rCustData );
          rReqLog.PARAM6    := null;
        elsif ( rReqLog.ID_REQLOG_CONFIG = Schema_RA.GPC_RA.ReqLog_Config_CustRegEIFShort ) then
          rReqLog.PARAM10  := null;
          rReqLog.PARAM9   := rReqLog.PARAM7;
          rReqLog.PARAM8   := rReqLog.PARAM6;
          rReqLog.PARAM7   := null;
          rReqLog.PARAM6   := rReqLog.PARAM5;
          rReqLog.PARAM5   := rReqLog.PARAM4;
          rReqLog.PARAM4   := rReqLog.PARAM3;
          rReqLog.PARAM3   := rReqLog.PARAM2;
          rReqLog.PARAM2   := rReqLog.PARAM1;
          rReqLog.PARAM1   := null;
        end if;

        if ( bRet ) then
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( rReqLog.ID_REQLOG, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( rReqLog.ID_REQLOG_CONFIG, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( rReqLog.ID_CMD, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.ID_SESSION, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.IP, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( rReqLog.ID_USER, sData ) and
                       Schema_GPSys.GPC_Parser.WriteDateTime_HumanFormat( rReqLog.REG_DATE, sRegDate ) and
                       Schema_GPSys.GPC_Parser.WriteString( sRegDate, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( rReqLog.UNIQCODE, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( rCustData.IDCust, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rCustData.CustName, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM1, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM2, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM3, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM4, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM5, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM6, sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM7, sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( to_number( rReqLog.PARAM8 ), sData ) and
                       Schema_GPSys.GPC_Parser.WriteInteger( to_number( rReqLog.PARAM9 ), sData ) and
                       Schema_GPSys.GPC_Parser.WriteString( rReqLog.PARAM10, sData ) and
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          else
            Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
          end if;
        end if;

        bRet       := bRet and
                      Schema_RA.GPC_RA.ChkStopField( nCount, nCount, Schema_GPSys.MLng.Str2( 'ReqLog Processing', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngEN ) );
      end loop;

      close qReqLogFind;
    else
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    end if;

    return bRet;
  end Cmd_REQLOG_CustomsLoadPics;

  --------------------------------------------------------------------------------
  function CmdCustGetPrintData( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    oDoc          Schema_GPSys.RecDocSysType;
    oDoc2         Schema_GPSys.RecDocSysType;
    oList         Schema_GPSys.DocSysList;
    oList2        Schema_GPSys.DocSysList;
    aRowValues    Schema_GPSys.GPC_Parser.taParamStrings;
    sData         varchar2( 4000 );
    sAddress      varchar2( 4000 );
    sParam        varchar2( 200 );
    sCmdName      varchar2( 20 ) := 'CustomsLoad';
    ii            pls_integer;
    jj            pls_integer;
    nIDCust       pls_integer;
    nPTR2REPR     CUSTOMS.PTR2REPR%type;
    nPTR2AUTH     CUSTOMS.PTR2AUTH%type;
    nPTR2DANINFO  CUSTOMS.PTR2DANINFO%type;
    nPTR2ROLES    CUSTOMS.PTR2ROLES%type;
    acAddress     Schema_GPSys.VarcharCollectionType;
    rCustAddres   rAddress;
    bRet          boolean := true;
    bHasCustNum   boolean;

    cursor qPrintData( qnIDCust in integer ) is
      select CUSTOMS.*,
             FIRSTNAME || ' ' || MIDLENAME || ' ' || LASTNAME as CUST_NAMES,
             ENCH || EGN || BULSTAT as CUST_EGN
        from CUSTOMS
       where id = qnIDCust;

  begin
    ii    := aParamEntities3D.first;
    bRet  := ii is not null;

    if ( ii is not null ) then
      bRet      := aParamEntities3D( ii ).nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                   aRowValues.count >= 1 and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDCust );
    end if;

    if ( not bRet ) then
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    else
      select count( 1 )
        into jj
        from CUSTNUMS
       where id = nIDCust;

      bHasCustNum  := jj > 0;

      for rec in qPrintData( nIDCust ) loop
        nPTR2REPR     := rec.PTR2REPR;
        nPTR2AUTH     := rec.PTR2AUTH;
        nPTR2DANINFO  := rec.PTR2DANINFO;
        nPTR2ROLES    := rec.PTR2ROLES;

        if ( rec.PTR2DATA is not null ) then
          Schema_GPSys.GPC_Parser.RespAddArray( 1 );
          Schema_DocSys.DocSys.GetList( rec.PTR2DATA, oList );

          for ii in oList.first .. oList.last loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
            sData     := null;
            bRet      := Schema_GPSys.GPC_Parser.WriteString( rec.CUST_NAMES, sData ) and -- 1
                         Schema_GPSys.GPC_Parser.WriteString( rec.CUST_EGN, sData ) and -- 2
                         Schema_GPSys.GPC_Parser.WriteString( rec.LICHNAKARTA, sData ) and -- 3
                         Schema_GPSys.GPC_Parser.WriteDate( rec.LK_DATEIZD, sData ) and -- 4
                         Schema_GPSys.GPC_Parser.WriteString( rec.LK_IZDADENOT, sData ) and -- 5
                         Schema_GPSys.GPC_Parser.WriteString( rec.ADDRESS, sData ) and -- 6
                         Schema_GPSys.GPC_Parser.WriteString( rec.TELEFON, sData ) and -- 7
                         Schema_GPSys.GPC_Parser.WriteString( rec.MOBILE, sData ) and -- 8
                         Schema_GPSys.GPC_Parser.WriteString( rec.EMAIL, sData ) and -- 9
                         Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.008', sData ) and -- 10
                         Schema_GPSys.GPC_Parser.WriteString( rec.DANNUMBER, sData ) and -- 11
                         true;

            if ( bRet ) then
              if ( rec.CLITYPE = 'C' ) then
                bRet      := Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.079', sData ) and -- 12
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.081', sData ) and -- 13
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.083', sData ) and -- 14
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.085', sData ) and -- 15
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.087', sData ) and -- 16
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.089', sData ) and -- 17
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DT, sData ) and -- 18
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DB, sData ) and -- 19
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_BU, sData ) and -- 20
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_MFA, sData ) and -- 21
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_CASH, sData ) and -- 22
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DU, sData ) and -- 23
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.073', sData ) and -- 24
                             Schema_GPSys.GPC_Parser.WriteDate( rec.DECFROM, sData ) and -- 25
                             Schema_GPSys.GPC_Parser.WriteDate( rec.DECSIGNED, sData ) and -- 26
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.076', sData ) and -- 27
                             Schema_GPSys.GPC_Parser.WriteString( rec.DIVIDENT, sData ) and -- 28
                             Schema_GPSys.GPC_Parser.WriteString( rec.storage, sData ) and -- 29
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 30
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.id, sData ) and -- 31
                             Schema_GPSys.GPC_Parser.WriteString( rec.CLITYPE, sData ) and -- 32
                             Schema_GPSys.GPC_Parser.WriteLogic( bHasCustNum, sData ) and -- 33
                             Schema_GPSys.GPC_Parser.WriteString( rec.FAX, sData ) and -- 34
                             Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.NomID2NomName( 'NOM_COUNTRY', rec.COUNTRY ), sData ) and -- 35
                             Schema_GPSys.GPC_Parser.WriteString( rec.LATINNAME, sData ) and -- 36
                             Schema_GPSys.GPC_Parser.WriteString( rec.LATINADDR, sData ) and -- 37
                             Schema_GPSys.GPC_Parser.WriteString( GPC_Customs.SectorID2Name( rec.SECTORNA ), sData ) and -- 38
                             Schema_GPSys.GPC_Parser.WriteString( rec.OTRASLOVA, sData ) and -- 39
                             Schema_GPSys.GPC_Parser.WriteString( rec.ICDEINOST, sData ) and -- 40
                             Schema_GPSys.GPC_Parser.WriteString( rec.TDD, sData ) and -- 41
                             Schema_GPSys.GPC_Parser.WriteString( rec.DDS_VIN, sData ) and -- 42
                             Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_CLASS, sData ) and -- 43
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 44
                             Schema_GPSys.GPC_Parser.WriteInteger2( oDoc, sCmdName, '2.050', sData ) and -- 45
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '2.068', sData ) and -- 46
                             Schema_GPSys.GPC_Parser.WriteDate( null, sData ) and -- 47
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 48
                             Schema_GPSys.GPC_Parser.WriteString( rec.FTYPE, sData ) and -- 49
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 50
                             Schema_GPSys.GPC_Parser.WriteString( rec.INST_SECTOR, sData ) and -- 51
                             Schema_GPSys.GPC_Parser.WriteDate( rec.CARD_VALID_DATE, sData ) and -- 52
                             Schema_GPSys.GPC_Parser.WriteString( rec.CARD_COUNTRY, sData ) and -- 53
                             Schema_GPSys.GPC_Parser.WriteString( rec.FATCA, sData ) and -- 54
                             Schema_GPSys.GPC_Parser.WriteDate( rec.RISKY_CLIENT_DATE, sData ) and -- 55
                             Schema_GPSys.GPC_Parser.WriteString( rec.MERCHANTS, sData ) and -- 56
                             Schema_GPSys.GPC_Parser.WriteString( rec.MCC, sData ) and -- 57
                             Schema_GPSys.GPC_Parser.WriteString( rec.INDUSTRY, sData ) and -- 58
                             Schema_GPSys.GPC_Parser.WriteString( rec.COMPANY_GROUPS, sData ) and -- 59
                             Schema_GPSys.GPC_Parser.WriteDate( rec.TERMINATION_DATE, sData ) and -- 60
                             Schema_GPSys.GPC_Parser.WriteDate( rec.REGISTRATION_DATE, sData ) and -- 61
                             Schema_GPSys.GPC_Parser.WriteString( rec.MERCH_WEBSITE, sData ) and -- 62
                             Schema_GPSys.GPC_Parser.WriteString( rec.DESCRIPTOR, sData ) and -- 63
                             Schema_GPSys.GPC_Parser.WriteString( rec.CITY_FIELD, sData ) and -- 64
                             Schema_GPSys.GPC_Parser.WriteString( rec.PCI_COMPLIENT, sData ) and -- 65
                             Schema_GPSys.GPC_Parser.WriteNumber( rec.PROJECTED_VOL_FROM, sData ) and -- 66
                             Schema_GPSys.GPC_Parser.WriteNumber( rec.PROJECTED_VOL_TO, sData ) and -- 67
                             Schema_GPSys.GPC_Parser.WriteDate( rec.BOARD_VALID_DATE, sData ) and -- 68
                             Schema_GPSys.GPC_Parser.WriteString( rec.BOARD_COUNTRY, sData ) and -- 69
                             Schema_GPSys.GPC_Parser.WriteString( rec.RISKY_CLIENT, sData ) and -- 70
                             Schema_GPSys.GPC_Parser.WriteString( rec.FLDACTIVE, sData ) and -- 71
                             Schema_GPSys.GPC_Parser.WriteDate( rec.FIRMENO_DELO_DATE, sData ) and -- 72
                             Schema_GPSys.GPC_Parser.WriteString( rec.EMPLOYER_NAME, sData ) and -- 73
                             Schema_GPSys.GPC_Parser.WriteString( rec.CONTACT_PERSON, sData ) and -- 74
                             Schema_GPSys.GPC_Parser.WriteString( rec.FOREIGN_ADDRESS, sData ) and -- 75
                             Schema_GPSys.GPC_Parser.WriteString( rec.MCC, sData ) and -- 76 - праща се втори път за MCC_RISK
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.SLUJITEL_REG, sData ) and -- 77
                             true;
              elsif ( rec.CLITYPE = 'F' ) then
                if ( GPC_Customs.GetCustAddress( rec.PTR2DATA, null, null, acAddress, rCustAddres, GPC_Customs.defPrimaryAddr ) ) then
                  sAddress  := rCustAddres.address;
                end if;

                bRet      := Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.079', sData ) and -- 12
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.081', sData ) and -- 13
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.083', sData ) and -- 14
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.085', sData ) and -- 15
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.087', sData ) and -- 16
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.089', sData ) and -- 17
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DT, sData ) and -- 18
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DB, sData ) and -- 19
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_BU, sData ) and -- 20
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_MFA, sData ) and -- 21
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_CASH, sData ) and -- 22
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DU, sData ) and -- 23
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.073', sData ) and -- 24
                             Schema_GPSys.GPC_Parser.WriteDate( rec.DECFROM, sData ) and -- 25
                             Schema_GPSys.GPC_Parser.WriteDate( rec.DECSIGNED, sData ) and -- 26
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.076', sData ) and -- 27
                             Schema_GPSys.GPC_Parser.WriteString( rec.DIVIDENT, sData ) and -- 28
                             Schema_GPSys.GPC_Parser.WriteString( rec.storage, sData ) and -- 29
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.009', sData ) and -- 30
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.id, sData ) and -- 31
                             Schema_GPSys.GPC_Parser.WriteString( rec.CLITYPE, sData ) and -- 32
                             Schema_GPSys.GPC_Parser.WriteLogic( bHasCustNum, sData ) and -- 33
                             Schema_GPSys.GPC_Parser.WriteString( rec.FAX, sData ) and -- 34
                             Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.NomID2NomName( 'NOM_COUNTRY', rec.COUNTRY ), sData ) and -- 35
                             Schema_GPSys.GPC_Parser.WriteString( rec.LATINNAME, sData ) and -- 36
                             Schema_GPSys.GPC_Parser.WriteString( rec.LATINADDR, sData ) and -- 37
                             Schema_GPSys.GPC_Parser.WriteString( GPC_Customs.SectorID2Name( rec.SECTORNA ), sData ) and -- 38
                             Schema_GPSys.GPC_Parser.WriteString( rec.OTRASLOVA, sData ) and -- 39
                             Schema_GPSys.GPC_Parser.WriteString( rec.ICDEINOST, sData ) and -- 40
                             Schema_GPSys.GPC_Parser.WriteString( rec.TDD, sData ) and -- 41
                             Schema_GPSys.GPC_Parser.WriteString( rec.DDS_VIN, sData ) and -- 42
                             Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_CLASS, sData ) and -- 43
                             Schema_GPSys.GPC_Parser.WriteString( sAddress, sData ) and -- 44
                             Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 45
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 46
                             Schema_GPSys.GPC_Parser.WriteDate2( oDoc, sCmdName, '3.005', sData ) and -- 47
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '3.006', sData ) and -- 48
                             Schema_GPSys.GPC_Parser.WriteString( rec.FTYPE, sData ) and -- 49
                             Schema_GPSys.GPC_Parser.WriteString( rec.TZTYPE, sData ) and -- 50
                             Schema_GPSys.GPC_Parser.WriteString( rec.INST_SECTOR, sData ) and -- 51
                             Schema_GPSys.GPC_Parser.WriteDate( rec.CARD_VALID_DATE, sData ) and -- 52
                             Schema_GPSys.GPC_Parser.WriteString( rec.CARD_COUNTRY, sData ) and -- 53
                             Schema_GPSys.GPC_Parser.WriteString( rec.FATCA, sData ) and -- 54
                             Schema_GPSys.GPC_Parser.WriteDate( rec.RISKY_CLIENT_DATE, sData ) and -- 55
                             Schema_GPSys.GPC_Parser.WriteString( rec.MERCHANTS, sData ) and -- 56
                             Schema_GPSys.GPC_Parser.WriteString( rec.MCC, sData ) and -- 57
                             Schema_GPSys.GPC_Parser.WriteString( rec.INDUSTRY, sData ) and -- 58
                             Schema_GPSys.GPC_Parser.WriteString( rec.COMPANY_GROUPS, sData ) and -- 59
                             Schema_GPSys.GPC_Parser.WriteDate( rec.TERMINATION_DATE, sData ) and -- 60
                             Schema_GPSys.GPC_Parser.WriteDate( rec.REGISTRATION_DATE, sData ) and -- 61
                             Schema_GPSys.GPC_Parser.WriteString( rec.MERCH_WEBSITE, sData ) and -- 62
                             Schema_GPSys.GPC_Parser.WriteString( rec.DESCRIPTOR, sData ) and -- 63
                             Schema_GPSys.GPC_Parser.WriteString( rec.CITY_FIELD, sData ) and -- 64
                             Schema_GPSys.GPC_Parser.WriteString( rec.PCI_COMPLIENT, sData ) and -- 65
                             Schema_GPSys.GPC_Parser.WriteNumber( rec.PROJECTED_VOL_FROM, sData ) and -- 66
                             Schema_GPSys.GPC_Parser.WriteNumber( rec.PROJECTED_VOL_TO, sData ) and -- 67
                             Schema_GPSys.GPC_Parser.WriteDate( rec.BOARD_VALID_DATE, sData ) and -- 68
                             Schema_GPSys.GPC_Parser.WriteString( rec.BOARD_COUNTRY, sData ) and -- 69
                             Schema_GPSys.GPC_Parser.WriteString( rec.RISKY_CLIENT, sData ) and -- 70
                             Schema_GPSys.GPC_Parser.WriteString( rec.FLDACTIVE, sData ) and -- 71
                             Schema_GPSys.GPC_Parser.WriteDate( rec.FIRMENO_DELO_DATE, sData ) and -- 72
                             Schema_GPSys.GPC_Parser.WriteString( rec.EMPLOYER_NAME, sData ) and -- 73
                             Schema_GPSys.GPC_Parser.WriteString( rec.CONTACT_PERSON, sData ) and -- 74
                             Schema_GPSys.GPC_Parser.WriteString( rec.FOREIGN_ADDRESS, sData ) and -- 75
                             Schema_GPSys.GPC_Parser.WriteString( rec.MCC, sData ) and -- 76 - праща се втори път за MCC_RISK
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.SLUJITEL_REG, sData ) and -- 77
                             true;
              else
                sAddress  := null;
                sParam    := Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, 'CustomsLoad', '4.33' );

                if ( sParam is not null ) then
                  sAddress  := sParam || ', ';
                end if;

                sParam    := Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, 'CustomsLoad', '4.34' );

                if ( sParam is not null ) then
                  sAddress  := sAddress || sParam;
                end if;

                bRet      := Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.52', sData ) and -- 12
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.54', sData ) and -- 13
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.56', sData ) and -- 14
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.58', sData ) and -- 15
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.60', sData ) and -- 16
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.62', sData ) and -- 17
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DT, sData ) and -- 18
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DB, sData ) and -- 19
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_BU, sData ) and -- 20
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_MFA, sData ) and -- 21
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_CASH, sData ) and -- 22
                             Schema_GPSys.GPC_Parser.WriteString( rec.CT_DU, sData ) and -- 23
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.46', sData ) and -- 24
                             Schema_GPSys.GPC_Parser.WriteDate( rec.DECFROM, sData ) and -- 25
                             Schema_GPSys.GPC_Parser.WriteDate( rec.DECSIGNED, sData ) and -- 26
                             Schema_GPSys.GPC_Parser.WriteString2( oDoc, sCmdName, '4.49', sData ) and -- 27
                             Schema_GPSys.GPC_Parser.WriteString( rec.DIVIDENT, sData ) and -- 28
                             Schema_GPSys.GPC_Parser.WriteString( rec.storage, sData ) and -- 29
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 30
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.id, sData ) and -- 31
                             Schema_GPSys.GPC_Parser.WriteString( rec.CLITYPE, sData ) and -- 32
                             Schema_GPSys.GPC_Parser.WriteLogic( bHasCustNum, sData ) and -- 33
                             Schema_GPSys.GPC_Parser.WriteString( rec.FAX, sData ) and -- 33
                             Schema_GPSys.GPC_Parser.WriteString( Schema_RA.GPC_Nom.NomID2NomName( 'NOM_COUNTRY', rec.COUNTRY ), sData ) and -- 35
                             Schema_GPSys.GPC_Parser.WriteString( rec.LATINNAME, sData ) and -- 36
                             Schema_GPSys.GPC_Parser.WriteString( sAddress, sData ) and -- 37
                             Schema_GPSys.GPC_Parser.WriteString( GPC_Customs.SectorID2Name( rec.SECTORNA ), sData ) and -- 38
                             Schema_GPSys.GPC_Parser.WriteString( rec.OTRASLOVA, sData ) and -- 39
                             Schema_GPSys.GPC_Parser.WriteString( rec.ICDEINOST, sData ) and -- 40
                             Schema_GPSys.GPC_Parser.WriteString( rec.TDD, sData ) and -- 41
                             Schema_GPSys.GPC_Parser.WriteString( rec.DDS_VIN, sData ) and -- 42
                             Schema_GPSys.GPC_Parser.WriteString( rec.EXPO_CLASS, sData ) and -- 43
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 44
                             Schema_GPSys.GPC_Parser.WriteInteger( 0, sData ) and -- 45
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 46
                             Schema_GPSys.GPC_Parser.WriteDate( null, sData ) and -- 47
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 48
                             Schema_GPSys.GPC_Parser.WriteString( rec.FTYPE, sData ) and -- 49
                             Schema_GPSys.GPC_Parser.WriteString( null, sData ) and -- 50
                             Schema_GPSys.GPC_Parser.WriteString( rec.INST_SECTOR, sData ) and -- 51
                             Schema_GPSys.GPC_Parser.WriteDate( rec.CARD_VALID_DATE, sData ) and -- 52
                             Schema_GPSys.GPC_Parser.WriteString( rec.CARD_COUNTRY, sData ) and -- 53
                             Schema_GPSys.GPC_Parser.WriteString( rec.FATCA, sData ) and -- 54
                             Schema_GPSys.GPC_Parser.WriteDate( rec.RISKY_CLIENT_DATE, sData ) and -- 55
                             Schema_GPSys.GPC_Parser.WriteString( rec.MERCHANTS, sData ) and -- 56
                             Schema_GPSys.GPC_Parser.WriteString( rec.MCC, sData ) and -- 57
                             Schema_GPSys.GPC_Parser.WriteString( rec.INDUSTRY, sData ) and -- 58
                             Schema_GPSys.GPC_Parser.WriteString( rec.COMPANY_GROUPS, sData ) and -- 59
                             Schema_GPSys.GPC_Parser.WriteDate( rec.TERMINATION_DATE, sData ) and -- 60
                             Schema_GPSys.GPC_Parser.WriteDate( rec.REGISTRATION_DATE, sData ) and -- 61
                             Schema_GPSys.GPC_Parser.WriteString( rec.MERCH_WEBSITE, sData ) and -- 62
                             Schema_GPSys.GPC_Parser.WriteString( rec.DESCRIPTOR, sData ) and -- 63
                             Schema_GPSys.GPC_Parser.WriteString( rec.CITY_FIELD, sData ) and -- 64
                             Schema_GPSys.GPC_Parser.WriteString( rec.PCI_COMPLIENT, sData ) and -- 65
                             Schema_GPSys.GPC_Parser.WriteNumber( rec.PROJECTED_VOL_FROM, sData ) and -- 66
                             Schema_GPSys.GPC_Parser.WriteNumber( rec.PROJECTED_VOL_TO, sData ) and -- 67
                             Schema_GPSys.GPC_Parser.WriteDate( rec.BOARD_VALID_DATE, sData ) and -- 68
                             Schema_GPSys.GPC_Parser.WriteString( rec.BOARD_COUNTRY, sData ) and -- 69
                             Schema_GPSys.GPC_Parser.WriteString( rec.RISKY_CLIENT, sData ) and -- 70
                             Schema_GPSys.GPC_Parser.WriteString( rec.FLDACTIVE, sData ) and -- 71
                             Schema_GPSys.GPC_Parser.WriteDate( rec.FIRMENO_DELO_DATE, sData ) and -- 72
                             Schema_GPSys.GPC_Parser.WriteString( rec.EMPLOYER_NAME, sData ) and -- 73
                             Schema_GPSys.GPC_Parser.WriteString( rec.CONTACT_PERSON, sData ) and -- 74
                             Schema_GPSys.GPC_Parser.WriteString( rec.FOREIGN_ADDRESS, sData ) and -- 75
                             Schema_GPSys.GPC_Parser.WriteString( rec.MCC, sData ) and -- 76 - праща се втори път за MCC_RISK
                             Schema_GPSys.GPC_Parser.WriteInteger( rec.SLUJITEL_REG, sData ) and -- 77
                             true;
              end if;
            end if;

            if ( bRet ) then
              Schema_GPSys.GPC_Parser.RespAddRow( sData );
            end if;
          end loop;
        end if;

        exit when not bRet;
      end loop;

      if ( nPTR2REPR is not null ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 2 );

        for recRepr in ( select FIRSTNAME || ' ' || MIDLENAME || ' ' || LASTNAME as NAMES,
                                ENCH || EGN || BULSTAT as EGN,
                                LICHNAKARTA,
                                ADDRESS,
                                id,
                                LK_IZDADENOT,
                                LK_DATEIZD,
                                REPRPOSITION,
                                FIRSTNAME,
                                MIDLENAME,
                                LASTNAME
                           from CUSTOMS,
                                CUST_REPR
                          where id = IDCUST_REPR and
                                IDCUST = nIDCust ) loop
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteString( recRepr.NAMES, sData ) and -- 1
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.EGN, sData ) and -- 2
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.LICHNAKARTA, sData ) and -- 3
                       Schema_GPSys.GPC_Parser.WriteDate( recRepr.LK_DATEIZD, sData ) and -- 4
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.LK_IZDADENOT, sData ) and -- 5
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.ADDRESS, sData ) and -- 6
                       Schema_GPSys.GPC_Parser.WriteInteger( recRepr.id, sData ) and -- 7
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.REPRPOSITION, sData ) and -- 8
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.FIRSTNAME, sData ) and -- 9
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.MIDLENAME, sData ) and -- 10
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.LASTNAME, sData ) and -- 11
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( nPTR2AUTH is not null ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 3 );

        for recRepr in ( select FIRSTNAME || ' ' || MIDLENAME || ' ' || LASTNAME as NAMES,
                                ENCH || EGN || BULSTAT as EGN,
                                LICHNAKARTA,
                                ADDRESS,
                                id,
                                LK_IZDADENOT,
                                LK_DATEIZD,
                                TYPEAUTH,
                                AUTH_NO,
                                AUTH_DATE
                           from CUSTOMS,
                                CUST_AUTH
                          where id = IDCUST_AUTH and
                                IDCUST = nIDCust ) loop
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteString( recRepr.NAMES, sData ) and -- 1
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.EGN, sData ) and -- 2
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.LICHNAKARTA, sData ) and -- 3
                       Schema_GPSys.GPC_Parser.WriteDate( recRepr.LK_DATEIZD, sData ) and -- 4
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.LK_IZDADENOT, sData ) and -- 5
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.ADDRESS, sData ) and -- 6
                       Schema_GPSys.GPC_Parser.WriteInteger( recRepr.id, sData ) and -- 7
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.TYPEAUTH, sData ) and -- 8
                       Schema_GPSys.GPC_Parser.WriteString( recRepr.AUTH_NO, sData ) and -- 9
                       Schema_GPSys.GPC_Parser.WriteDate( recRepr.AUTH_DATE, sData ) and --10
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( nPTR2DANINFO is not null ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 4 );

        for recDanInfo in ( select DAN_NO,
                                   DAN_COUNTRY
                              from CUST_DANINFO
                             where IDCUST = nIDCust ) loop
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteString( recDanInfo.DAN_NO, sData ) and -- 1
                       Schema_GPSys.GPC_Parser.WriteString( recDanInfo.DAN_COUNTRY, sData ) and -- 2
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 5 );

        for recPrintDocs in ( select *
                                from CUST_PRINT_DOCS
                               where IDCUST = nIDCust ) loop
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteString( recPrintDocs.ID_DOC, sData ) and -- 1
                       Schema_GPSys.GPC_Parser.WriteInteger( recPrintDocs.UNIQCODE, sData ) and -- 2
                       Schema_GPSys.GPC_Parser.WriteDate( recPrintDocs.CH_DATE, sData ) and -- 3
                       Schema_GPSys.GPC_Parser.WriteInteger( recPrintDocs.CH_OPER, sData ) and -- 4
                       Schema_GPSys.GPC_Parser.WriteString( recPrintDocs.REMARKS, sData ) and -- 5
                       Schema_GPSys.GPC_Parser.WriteString( recPrintDocs.PHONE, sData ) and -- 6
                       Schema_GPSys.GPC_Parser.WriteString( recPrintDocs.SMS, sData ) and -- 7
                       Schema_GPSys.GPC_Parser.WriteString( recPrintDocs.EMAIL, sData ) and -- 8
                       Schema_GPSys.GPC_Parser.WriteString( recPrintDocs.DECLINE, sData ) and -- 9
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 6 );

        for recExpos in ( select expo.CODVAL as CODVAL,
                                 expo.IBAN as IBAN,
                                 expo.ID_EXPO,
                                 iban.IBAN as VIRT_IBAN,
                                 iban.BIC as BIC,
                                 iban.BANK_NAME as BANKNAME
                            from Schema_GPSys.EXPOSITION expo,
                                 Schema_GPSys.EXPO_IBANS iban
                           where expo.ID_CUST = nIDCust and
                                 expo.ID_EXPO = iban.ID_EXPO and
                                 expo.STATUS = 'T' and
                                 iban.STATUS = 'T' ) loop
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( recExpos.ID_EXPO, sData ) and -- 1
                       Schema_GPSys.GPC_Parser.WriteString( recExpos.CODVAL, sData ) and -- 2
                       Schema_GPSys.GPC_Parser.WriteString( recExpos.IBAN, sData ) and -- 3
                       Schema_GPSys.GPC_Parser.WriteString( recExpos.VIRT_IBAN, sData ) and -- 4
                       Schema_GPSys.GPC_Parser.WriteString( recExpos.BIC, sData ) and -- 5
                       Schema_GPSys.GPC_Parser.WriteString( recExpos.BANKNAME, sData ) and -- 6
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( bRet ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 7 );

        for recExpos in ( select expo.CODVAL as CODVAL,
                                 expo.IBAN as IBAN,
                                 expo.ID_EXPO,
                                 expo.TYPE_EXPO
                            from Schema_GPSys.EXPOSITION expo
                           where expo.ID_CUST = nIDCust and
                                 expo.STATUS = 'T' ) loop
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteInteger( recExpos.ID_EXPO, sData ) and -- 1
                       Schema_GPSys.GPC_Parser.WriteString( recExpos.CODVAL, sData ) and -- 2
                       Schema_GPSys.GPC_Parser.WriteString( recExpos.IBAN, sData ) and -- 3
                       Schema_GPSys.GPC_Parser.WriteInteger( recExpos.TYPE_EXPO, sData ) and -- 4
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;

      if ( nPTR2ROLES is not null ) then
        Schema_GPSys.GPC_Parser.RespAddArray( 8 );

        for recRole in (  select STATUS
                            from CUST_ROLES
                           where CUST_ID = nIDCust and
                                 DEINOST = GPC_CMD_CUST_ADD.defActivityType_EPaymnets
                        order by STATUS_DATE desc ) loop
          sData     := null;
          bRet      := Schema_GPSys.GPC_Parser.WriteString( recRole.STATUS, sData ) and -- 1
                       true;

          if ( bRet ) then
            Schema_GPSys.GPC_Parser.RespAddRow( sData );
          end if;

          exit when not bRet;
        end loop;
      end if;
    end if;

    return bRet;
  end CmdCustGetPrintData;

  --------------------------------------------------------------------------------
  function CmdCustSetPrintData( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    type tblDocs is table of CUST_PRINT_DOCS%rowtype
      index by binary_integer;

    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    aParams     Schema_RA.GPC_RA.tblErrParams;
    aDocs       tblDocs;
    ii          pls_integer;
    jj          pls_integer;
    nIDCust     pls_integer;
    bRet        boolean;
    bPrint      boolean;
  begin
    bRet  := aParamEntities3D.first is not null;

    if ( bRet ) then
      for ii in aParamEntities3D.first .. aParamEntities3D.last loop
        bRet  := false;

        if ( aParamEntities3D( ii ).nRowType = 1 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       aRowValues.count >= 2 and
                       Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDCust ) and
                       Schema_GPSys.GPC_Parser.ReadLogic( aRowValues( 2 ), bPrint ) and
                       true;
        elsif ( aParamEntities3D( ii ).nRowType = 2 ) then
          bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                       aRowValues.count >= 6 and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 1 ), aDocs( aDocs.count + 1 ).ID_DOC ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 2 ), aDocs( aDocs.count ).REMARKS ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 3 ), aDocs( aDocs.count ).PHONE ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 4 ), aDocs( aDocs.count ).SMS ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 5 ), aDocs( aDocs.count ).EMAIL ) and
                       Schema_GPSys.GPC_Parser.ReadString( aRowValues( 6 ), aDocs( aDocs.count ).DECLINE ) and
                       true;
        end if;

        exit when not bRet;
      end loop;
    end if;

    if ( bRet ) then
      bRet  := aDocs.count > 0;

      if ( bRet ) then
        for ii in aDocs.first .. aDocs.last loop
          if ( bPrint ) then
            update CUST_PRINT_DOCS
               set UNIQCODE  = Schema_RA.GPC_RA.nCurrentUniqCode,
                   CH_DATE   = sysdate,
                   CH_OPER   = Schema_RA.GPC_RA.nCurrentUserID,
                   REMARKS   = aDocs( ii ).REMARKS,
                   PHONE     = aDocs( ii ).PHONE,
                   SMS       = aDocs( ii ).SMS,
                   EMAIL     = aDocs( ii ).EMAIL,
                   DECLINE   = aDocs( ii ).DECLINE
             where IDCUST = nIDCust and
                   ID_DOC = aDocs( ii ).ID_DOC;
          else
            update CUST_PRINT_DOCS
               set REMARKS  = aDocs( ii ).REMARKS,
                   PHONE    = aDocs( ii ).PHONE,
                   SMS      = aDocs( ii ).SMS,
                   EMAIL    = aDocs( ii ).EMAIL,
                   DECLINE  = aDocs( ii ).DECLINE
             where IDCUST = nIDCust and
                   ID_DOC = aDocs( ii ).ID_DOC;
          end if;

          if ( sql%rowcount = 0 ) then
            begin
              insert into CUST_PRINT_DOCS(
                            IDCUST,
                            ID_DOC,
                            UNIQCODE,
                            CH_DATE,
                            CH_OPER,
                            REMARKS,
                            PHONE,
                            SMS,
                            EMAIL,
                            DECLINE
                          )
                   values ( nIDCust,
                            aDocs( ii ).ID_DOC,
                            Schema_RA.GPC_RA.nCurrentUniqCode,
                            sysdate,
                            Schema_RA.GPC_RA.nCurrentUserID,
                            aDocs( ii ).REMARKS,
                            aDocs( ii ).PHONE,
                            aDocs( ii ).SMS,
                            aDocs( ii ).EMAIL,
                            aDocs( ii ).DECLINE
                           );
            exception
              when dup_val_on_index then
                bRet                   := false;
                --
                aParams.delete;
                aParams( 1 ).ML_NAME   := 'ID_DOC';
                aParams( 1 ).ML_VALUE  := aDocs( ii ).ID_DOC;
                Schema_RA.GPC_RA.RespSetErrorText( 'Дублирани данни за вид документ $ID_DOC$', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG, aParams );
            end;
          end if;

          exit when not bRet;
        end loop;
      else
        Schema_RA.GPC_RA.RespSetErrorText( 'Не са подадени данни за запис', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
      end if;
    else
      Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    end if;

    return bRet;
  end CmdCustSetPrintData;

  --------------------------------------------------------------------------------
  function UpdateUserData( rCust in CUSTOMS%rowtype )
    return boolean is
    aUCsForUpdate    Schema_GPSys.OraGPSys.aNumbers;
    sCustName        varchar2( 600 );
    bNomDataChanged  boolean;
    bUsersByUC       boolean;
    bRet             boolean;
    aParams          Schema_RA.GPC_RA.tblErrParams;

    cursor qSelectUser( nCustID in integer ) is
      select *
        from Schema_RA.RA_USERS
       where FLD_CUST_ID = nCustID and
             nvl( INST_CREATED, Schema_GPSys.OraGPSys.GetDBSchemaPrefix ) = Schema_GPSys.OraGPSys.GetDBSchemaPrefix;

    rUser            qSelectUser%rowtype;
  begin
    bRet       := true;
    sCustName  := trim( trim( rCust.FIRSTNAME ) || ' ' || trim( rCust.MIDLENAME ) || ' ' || trim( rCust.LASTNAME ) );

    if ( sCustName is not null ) then
      open qSelectUser( rCust.id );

      fetch qSelectUser
        into rUser;

      if ( qSelectUser%found ) then
        bNomDataChanged  := rUser.FLDUSERFNAME != sCustName;
        bUsersByUC       := Schema_GPSys.OraSys.VerFIS;

        select FLDUNIQCODE
          bulk collect into aUCsForUpdate
          from Schema_RA.RA_RIGHTS_UC
         where FLDUSERID = rUser.FLDUSERID;

        if ( bNomDataChanged or
            nvl( rUser.FLDUSEREMAIL, ' ' ) != nvl( rCust.EMAIL, ' ' ) ) then
          insert into Schema_RA.RA_USERS_A
               values rUser;

          update Schema_RA.RA_USERS
             set FLDUSERFNAME  = sCustName,
                 FLDUSEREMAIL  = rCust.EMAIL,
                 FLDOPER       = Schema_RA.GPC_RA.nCurrentUserID,
                 FLDCH_DATE    = sysdate
           where FLDUSERID = rUser.FLDUSERID;

          Schema_RA.GPC_RA.RespSetErrorText( 'Грешка при генериране на номенклатура Потребители', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG );
          bRet  := Schema_RA.GPC_Cmd_Users.GenerateUsersNom( bNomDataChanged, bUsersByUC, aUCsForUpdate );
        end if;

        if ( bRet ) then
          aParams.delete;
          aParams( 1 ).ML_NAME   := 'FLDUSERID';
          aParams( 1 ).ML_VALUE  := to_char( rUser.FLDUSERID );
          Schema_RA.GPC_RA.RespSetErrorText( 'Потребител с ID $FLDUSERID$ не може да бъде отключен', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG, aParams );
          bRet                   := Schema_GPSys.OraGPSys.UnLockSysObj( Schema_GPSys.OraGPSys.LockTypeUsers, rUser.FLDUSERID );
        end if;
      end if;

      close qSelectUser;
    end if;

    return bRet;
  end UpdateUserData;

  --------------------------------------------------------------------------------
  function GetShareholderHierarchyTree(
    nIDCust         in     pls_integer,
    аShareholders  in out tаShareholders,
    sTraceString    in     varchar2,
    nLevel          in     pls_integer,
    nUpperItem      in     pls_integer
  )
    return boolean is
    oDoc            Schema_GPSys.RecDocSysType;
    oList           Schema_GPSys.DocSysList;
    аIDs           tаShareholders;
    rCust           CUSTOMS%rowtype;
    nShareholderID  pls_integer;
    bRet            boolean := true;
    aParams         Schema_RA.GPC_RA.tblErrParams;

    cursor qFindCust( pnIDCust in pls_integer ) is
      select *
        from CUSTOMS
       where ID = pnIDCust;

  begin
    open qFindCust( nIDCust );

    fetch qFindCust
      into rCust;

    if ( qFindCust%notfound ) then
      aParams.delete;
      aParams( 1 ).ML_NAME   := 'ID_CUST';
      aParams( 1 ).ML_VALUE  := to_char( nIDCust );
      Schema_RA.GPC_RA.RespSetErrorText( 'Няма данни за клиент с ID: $ID_CUST$', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG, aParams );
      bRet                   := false;
    end if;

    close qFindCust;

    if ( bRet and
        rCust.PTR2STOCK is not null ) then
      Schema_DocSys.DocSys.GetList( rCust.PTR2STOCK, oList );

      for ii in oList.first .. oList.last loop
        Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );
        аIDs( аIDs.count + 1 ).SHAREHOLDER_ID_CUST  := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustomsLoad', '12.01' );
        аIDs( аIDs.count ).OWNERSHIP                := Schema_GPSys.OraGPSys.GetFromCmdNumber( oDoc, 'CustomsLoad', '12.02' );

        if ( nvl( аIDs( аIDs.count ).SHAREHOLDER_ID_CUST, 0 ) = nUpperItem ) then
          аShareholders( аShareholders.count ).INTERCONNECTED  := defShareholders_Interconnected;
        end if;
      end loop;

      for ii in аIDs.first .. аIDs.last loop
        nShareholderID  := аIDs( ii ).SHAREHOLDER_ID_CUST;

        if ( nvl( nShareholderID, 0 ) > 0 ) then
          rCust  := null;

          open qFindCust( nShareholderID );

          fetch qFindCust
            into rCust;

          if ( qFindCust%notfound ) then
            aParams.delete;
            aParams( 1 ).ML_NAME   := 'SHAREHOLDER_ID';
            aParams( 1 ).ML_VALUE  := to_char( nShareholderID );
            Schema_RA.GPC_RA.RespSetErrorText( 'Няма данни за собственик с ID: $SHAREHOLDER_ID$', Schema_GPSys.MLng.ctxCustomers, Schema_GPSys.MLng.lngBG, aParams );
            bRet                   := false;
          end if;

          close qFindCust;

          if ( bRet ) then
            аShareholders( аShareholders.count + 1 ).ID_CUST          := nIDCust;
            аShareholders( аShareholders.count ).SHAREHOLDER_ID_CUST  := nShareholderID;
            аShareholders( аShareholders.count ).OWNERSHIP            := аIDs( ii ).OWNERSHIP;
            аShareholders( аShareholders.count ).SHAREHOLDER_TYPE     := rCust.CLITYPE;
            аShareholders( аShareholders.count ).SHAREHOLDER_NAME     := trim( trim( rCust.FIRSTNAME ) || ' ' || trim( rCust.MIDLENAME ) || ' ' || trim( rCust.LASTNAME ) );
            аShareholders( аShareholders.count ).SHAREHOLDER_EIK      := case rCust.CLITYPE
                                                                             when 'C' then nvl( rCust.EGN, rCust.ENCH )
                                                                             else rCust.BULSTAT
                                                                           end;
            аShareholders( аShareholders.count ).TRACE_STRING         := sTraceString || to_char( nShareholderID ) || Schema_GPSys.GPC_Parser.DELIMITER_SEMICOLON;
            аShareholders( аShareholders.count ).INTERCONNECTED       := defShareholders_NotConnected;
            аShareholders( аShareholders.count ).HIERARCHY_LEVEL      := nLevel;

            if ( instr( sTraceString, Schema_GPSys.GPC_Parser.DELIMITER_SEMICOLON || to_char( nShareholderID ) || Schema_GPSys.GPC_Parser.DELIMITER_SEMICOLON ) > 0 ) then
              if ( nShareholderID = nUpperItem ) then
                аShareholders( аShareholders.count ).INTERCONNECTED  := defShareholders_Interconnected;
              else
                аShareholders( аShareholders.count ).INTERCONNECTED  := defShareholders_Indirect;
              end if;
            else
              if ( rCust.CLITYPE != 'C' ) then
                bRet  := GetShareholderHierarchyTree( nShareholderID, аShareholders, sTraceString || to_char( nShareholderID ) || Schema_GPSys.GPC_Parser.DELIMITER_SEMICOLON, nLevel + 1, nIDCust );
              end if;
            end if;
          end if;
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end GetShareholderHierarchyTree;

  --------------------------------------------------------------------------------
  function CmdShareholdersHierarchyTree( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    аShareholders  tаShareholders;
    aRowValues      Schema_GPSys.GPC_Parser.taParamStrings;
    nIDCust         pls_integer;
    nCurrent        pls_integer := 1;
    ii              pls_integer;
    sData           varchar2( 4000 );
    bRet            boolean;
  begin
    ii    := aParamEntities3D.first;
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet  := ii is not null;

    while ( ii is not null and
           bRet ) loop
      bRet      := aParamEntities3D( ii ).nRowType = 1 and
                   Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( ii ).sValue, aRowValues ) and
                   aRowValues.count >= 1 and
                   Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIDCust ) and
                   nvl( nIDCust, 0 ) > 0 and
                   true;
      ii        := aParamEntities3D.next( ii );
    end loop;

    if ( bRet ) then
      bRet  := GetShareholderHierarchyTree( nIDCust, аShareholders, Schema_GPSys.GPC_Parser.DELIMITER_SEMICOLON || to_char( nIDCust ) || Schema_GPSys.GPC_Parser.DELIMITER_SEMICOLON, 2, 0 );
    end if;

    if ( bRet ) then
      Schema_GPSys.GPC_Parser.RespAddArray( 1 );

      for ii in 1 .. аShareholders.count loop
        sData     := null;
        bRet      := Schema_GPSys.GPC_Parser.WriteInteger( аShareholders( ii ).ID_CUST, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( аShareholders( ii ).SHAREHOLDER_ID_CUST, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( аShareholders( ii ).SHAREHOLDER_TYPE, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( аShareholders( ii ).SHAREHOLDER_NAME, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( аShareholders( ii ).SHAREHOLDER_EIK, sData ) and
                     Schema_GPSys.GPC_Parser.WriteNumber( аShareholders( ii ).OWNERSHIP, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( аShareholders( ii ).TRACE_STRING, sData ) and
                     Schema_GPSys.GPC_Parser.WriteString( аShareholders( ii ).INTERCONNECTED, sData ) and
                     Schema_GPSys.GPC_Parser.WriteInteger( аShareholders( ii ).HIERARCHY_LEVEL, sData ) and
                     true;

        if ( bRet ) then
          Schema_GPSys.GPC_Parser.RespAddRow( sData );
          nCurrent  := nCurrent + 1;
          bRet      := bRet and
                       Schema_RA.GPC_RA.ChkStopField( nCurrent, nCurrent );
        else
          Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни изходни данни', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
        end if;

        exit when not bRet;
      end loop;
    end if;

    return bRet;
  end CmdShareholdersHierarchyTree;

  --------------------------------------------------------------------------------
  function GetCustAddress4Contact( nIDCust in integer )
    return varchar2 is
    recCust      CUSTOMS%rowtype;
    oList        Schema_GPSys.DocSysList;
    oDoc         Schema_GPSys.RecDocSysType;
    rCustAddres  rAddress;
    sAddress     varchar2( 4000 );
    acAddress    Schema_GPSys.VarcharCollectionType;
    bRet         boolean;
  begin
    begin
      select *
        into recCust
        from CUSTOMS
       where ID = nIDCust;
    exception
      when no_data_found then
        null;
    end;

    if ( recCust.CLITYPE = 'C' ) then
      if ( GPC_Customs.GetCustAddress( recCust.PTR2ADDRESS, GPC_Customs.CustAddrType_Contact, null, acAddress, rCustAddres, GPC_Customs.defAddrConnectList ) ) then
        sAddress  := rCustAddres.address;
      end if;
    elsif ( recCust.CLITYPE = 'F' ) then
      if ( GPC_Customs.GetCustAddress( recCust.PTR2DATA, null, null, acAddress, rCustAddres, GPC_Customs.defPrimaryAddr ) ) then
        sAddress  := rCustAddres.address;
      end if;
    end if;

    return sAddress;
  end GetCustAddress4Contact;

  --------------------------------------------------------------------------------
  function CustHasGrafInf( nIDCust in integer )
    return boolean is
    bCustHasGrafInf  boolean := false;
    aSData           Schema_GPSys.GPC_Parser.taParamStrings;
    oList            Schema_GPSys.DocSysList;
    oDoc             Schema_GPSys.RecDocSysType;
    nIDList          integer;
  begin
    Schema_GPSys.GPC_Parser.SplitStr2Arr( Schema_GPSys.OraGPSys.GetIniValueInt( Schema_GPSys.OraGPSys.defUniqCode_All, 'CUSTOMS', 'ChkGrafInfSpecific', null ), '&', aSData );

    if ( aSData.count = 0 ) then
      bCustHasGrafInf  := true;
    else
      begin
        select PTR2PIC
          into nIDList
          from CUSTOMS
         where id = nIDCust;
      exception
        when no_data_found then
          nIDList  := null;
      end;

      if ( nIDList is not null ) then
        Schema_DocSys.DocSys.GetList( nIDList, oList );

        for nn in aSData.first .. aSData.last loop
          bCustHasGrafInf  := false;

          for ii in 1 .. oList.count loop
            Schema_DocSys.DocSys.GetDocument( oList( ii ).DocType, oList( ii ).LDocNo, oList( ii ).LChStamp, oDoc );

            if ( aSData( nn ) = Schema_GPSys.OraGPSys.GetFromCmdString( oDoc, 'CustomsLoad', '11.02' ) ) then --Тип графична информация
              bCustHasGrafInf  := true;
              exit;
            end if;
          end loop;

          exit when not bCustHasGrafInf;
        end loop;
      end if;
    end if;

    return bCustHasGrafInf;
  end CustHasGrafInf;

  --------------------------------------------------------------------------------
  function CmdCustCheckGrafInf( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean is
    aRowValues  Schema_GPSys.GPC_Parser.taParamStrings;
    nIdCust     CUSTOMS.id%type;
    sData       varchar2( 4000 );
    bRet        boolean;
  begin
    Schema_RA.GPC_RA.RespSetErrorText( 'Некоректни входни параметри', Schema_GPSys.MLng.ctxSysMsg, Schema_GPSys.MLng.lngBG );
    bRet      := Schema_GPSys.GPC_Parser.SplitParams( aParamEntities3D( 1 ).sValue, aRowValues ) and
                 Schema_GPSys.GPC_Parser.ReadInteger( aRowValues( 1 ), nIdCust );

    if ( bRet ) then
      Schema_GPSys.GPC_Parser.RespAddArray( 1 );
      sData     := null;
      bRet      := Schema_GPSys.GPC_Parser.WriteLogic( CustHasGrafInf( nIdCust ), sData ) and
                   Schema_GPSys.GPC_Parser.RespAddRow( sData );
    end if;

    return bRet;
  end CmdCustCheckGrafInf;

  --------------------------------------------------------------------------------
  procedure YY is
    bRet      boolean;
    oRespRow  Schema_GPSys.GPC_Parser.trParamEntity3D;
    oResp     Schema_GPSys.GPC_Parser.taParamEntities3D;
  begin
    Schema_RA.GPC_RA.ClearResponce;
    oRespRow.nRowType         := 1;
    oRespRow.sValue           := '4' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '"T"' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '55893' ||
                                 '&' ||
                                 '3' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '"F"' ||
                                 '&' ||
                                 '"F"' ||
                                 '&';
    oResp( oResp.count + 1 )  := oRespRow;
    /*oRespRow.nRowType         := 13;
      oRespRow.sValue           := '4'||'&'||'244.00000000'||'&';
      oResp( oResp.count + 1 )  := oRespRow;*/
    --
    bRet                      := CmdCustomsLoadArc( oResp );
    /*
        oRespRow.sValue           := '';
        oResp( oResp.count + 1 )  := oRespRow;
        --
        bRet                      := CmdCustomsFind( oResp );*/
    Schema_RA.GPC_RA.DisplayResponce( bRet );
  end YY;
--------------------------------------------------------------------------------
end GPC_Cmd_Cust;
/