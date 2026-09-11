create or replace package GPC_CMD_Cust
  authid definer is
  --------------------------------------------------------------------------------
  type rAddress is record(
    ADDRESS         varchar2( 4000 ),
    ADDR_CITY       varchar2( 100 ),
    ADDR_OBL        varchar2( 100 ),
    ADDR_PK         varchar2( 100 ),
    ADDR_ZK         varchar2( 100 ),
    ADDR_STREET     varchar2( 100 ),
    ADDR_NUM        varchar2( 100 ),
    ADDR_BLOK       varchar2( 100 ),
    ADDR_VHOD       varchar2( 100 ),
    ADDR_ETAJ       varchar2( 100 ),
    ADDR_APART      varchar2( 100 ),
    Conn_person     varchar2( 400 ),
    Mobile          varchar2( 100 ),
    HomePhone       varchar2( 100 ),
    ADDR_MUNI       varchar2( 100 ),
    ID_FROM_DEBTOR  varchar2( 100 ), -- Само за Физ.лице, когато се взима от основното досие
    ID_DATE_DEBTOR  date -- Само за Физ.лице, когато се взима от основното досие
  );

  --------------------------------------------------------------------------------
  function INI_ReportMaxRetRows
    return integer;

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
  );

  function CmdCustomsSave(
    aParamEntities3D  in Schema_GPSys.GPC_Parser.taParamEntities3D,
    bChkInBase        in boolean default true,
    nInQueue          in integer default Schema_DocSys.DOCSYS_SAVEINIQ.InputQueue_Work,
    bRegular          in boolean default true,
    bResp             in boolean default true,
    bSkipMvrIn        in boolean default false
  )
    return boolean;

  function CmdCustomsFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  function CmdKontragentiFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  function CmdCustomsConnFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  function CmdCustomsLoad( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  function CmdCustomsLoadArc( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  function CmdCustomsFromDate( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  ---------------------------------------------------------------
  function CmdCustGetNameLatByBIC( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  function CmdRelationShipMgrsFind( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  function CmdRelationShipMgrsSave( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  --------------------------------------------------------------------------------
  function Cmd_REQLOG_CustomsLoadPics( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  ---------------------------------------------------------------
  function CmdCustGetPrintData( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  ---------------------------------------------------------------
  function CmdCustSetPrintData( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  --------------------------------------------------------------------------------
  function UpdateUserData( rCust in CUSTOMS%rowtype )
    return boolean;

  --------------------------------------------------------------------------------
  function CmdShareholdersHierarchyTree( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  --------------------------------------------------------------------------------
  function GetCustAddress4Contact( nIDCust in integer )
    return varchar2;

  --------------------------------------------------------------------------------
  function CustHasGrafInf( nIDCust in integer )
    return boolean;

  --------------------------------------------------------------------------------
  function CmdCustCheckGrafInf( aParamEntities3D in Schema_GPSys.GPC_Parser.taParamEntities3D )
    return boolean;

  --------------------------------------------------------------------------------
  procedure XX;

  procedure YY;
--------------------------------------------------------------------------------
end GPC_CMD_Cust;
/