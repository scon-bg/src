package com.scon.WebIns.jsf.base;

import com.scon.WebIns.MVIns.noms.NomStoredDocs;
import com.scon.WebIns.cmd.CmdInsAgentsAgentFindRow;
import com.scon.WebIns.cmd.base.CmdListData_Result;
import com.scon.WebIns.cmd.plc.CmdInsPolicyAnexDelete;
import com.scon.WebIns.cmd.plc.CmdInsPolicyAnexDelete_Params;
import com.scon.WebIns.cmd.plc.CmdInsPolicyAnexFind;
import com.scon.WebIns.cmd.plc.CmdInsPolicyAnexFind_Params;
import com.scon.WebIns.cmd.plc.CmdInsPolicyAnexFind_Result;
import com.scon.WebIns.cmd.plc.CmdInsPolicyAnexLoad;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyDelete;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyXXXLoad;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyXXXLoad_Param;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyXXXSave;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyXXXSave_Result;
import com.scon.WebIns.cmd.base.CmdResult;
import com.scon.WebIns.cmd.base.OraInsCmdAbstract;
import com.scon.WebIns.cmd.plc.CmdInsAgentsCommissionFind;
import com.scon.WebIns.cmd.plc.CmdInsAgentsCommissionFind_Params;
import com.scon.WebIns.cmd.plc.CmdInsAgentsCommissionFind_Result;
import com.scon.WebIns.cmd.plc.CmdInsPlcHistoryFind;
import com.scon.WebIns.cmd.plc.CmdInsPlcHistoryFind_Params;
import com.scon.WebIns.cmd.plc.CmdInsPlcHistoryFind_Result;
import com.scon.WebIns.cmd.plc.CmdInsPlcHistoryFind_ResultRow;
import com.scon.WebIns.cmd.plc.CmdInsPolicyCmplxPlcUndoAnul;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyFind;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyFind_Params;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyFind_Result;
import com.scon.WebIns.cmd.plc.CmdInsPolicyPolicyFind_ResultRow;
import com.scon.WebIns.cmd.plc.CmdPolicyDeleteUndo;
import com.scon.WebIns.ejb.NomsFacade;
import com.scon.WebIns.ejb.PoliciesFacade;
import com.scon.WebIns.ejb.UsersFacade;
import com.scon.WebIns.entities.customers.base.Customer;
import com.scon.WebIns.entities.elSmetki.ElSmetkiLoad;
import com.scon.WebIns.entities.noms.*;
import com.scon.WebIns.entities.policies.base.AccumulationBase;
import com.scon.WebIns.entities.policies.base.AddressBase;
import com.scon.WebIns.entities.policies.base.PlcAnnexBase;
import com.scon.WebIns.entities.policies.base.PlcAnnexClaim;
import com.scon.WebIns.entities.policies.base.PlcBase;
import com.scon.WebIns.entities.policies.base.PlcCoverBase;
import com.scon.WebIns.entities.policies.base.PlcDependenciesBase;
import com.scon.WebIns.entities.policies.base.PlcOtsNadBase;
import com.scon.WebIns.entities.policies.base.PlcPadejiBase;
import com.scon.WebIns.entities.policies.base.PlcRowBase;
import com.scon.WebIns.entities.policies.base.PlcStikeriBase;
import com.scon.WebIns.entities.users.Permissions;
import com.scon.WebIns.entities.users.Users;
import com.scon.WebIns.entities.users.UsersPermissionsFld;
import com.scon.WebIns.entities.users.UsersPermissionsNom.PermNomType;
import com.scon.WebIns.jsf.base.CustSelect.CustSelectMode;
import com.scon.WebIns.jsf.base.fs.CustomerSmallBaseFSC;
import com.scon.WebIns.jsf.base.fs.PlcBaseFSC;
import com.scon.WebIns.jsf.base.fs.PlcCntrlInterface;
import com.scon.WebIns.jsf.base.fs.PrintCntrlInterface;
import com.scon.WebIns.jsf.base.fs.SelectCustInterface;
import com.scon.WebIns.jsf.pictures.PicturesCntrl;
import com.scon.WebIns.jsf.sys.AppMenu;
import com.scon.WebIns.jsf.sys.DataTableCustomExporter;
import com.scon.WebIns.jsf.sys.JsfUtil;
import com.scon.WebIns.jsf.sys.NomsController;
import com.scon.WebIns.jsf.sys.SXLSXTools;
import com.scon.WebIns.jsf.sys.SessionBean;
import com.scon.WebIns.sys.App;
import com.scon.WebIns.sys.LockType;
import com.scon.WebIns.sys.PrintInfo;
import com.scon.WebIns.sys.Res;
import com.scon.WebIns.sys.Tools;
import com.scon.WebIns.sys.Utils;
import com.scon.WebIns.sys.def;
import java.io.IOException;
import java.io.Serializable;
import java.io.UnsupportedEncodingException;
import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.*;
import jakarta.annotation.PostConstruct;
import jakarta.ejb.EJB;
import jakarta.faces.application.FacesMessage;
import jakarta.faces.component.UIComponent;
import jakarta.faces.context.FacesContext;
import jakarta.faces.event.ActionEvent;
import jakarta.faces.event.AjaxBehaviorEvent;
import jakarta.faces.model.SelectItem;
import jakarta.faces.validator.ValidatorException;
import jakarta.inject.Inject;
import java.math.RoundingMode;
import net.sf.jasperreports.engine.JRException;
import net.sf.jasperreports.engine.util.Pair;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.xssf.streaming.SXSSFSheet;
import org.apache.poi.xssf.streaming.SXSSFWorkbook;
import org.primefaces.PrimeFaces;
import org.primefaces.component.selectonemenu.SelectOneMenu;
import org.primefaces.event.RowEditEvent;
import org.primefaces.event.ToggleEvent;
import org.primefaces.model.DefaultTreeNode;
import org.primefaces.model.SortMeta;
import org.primefaces.model.SortOrder;
import org.primefaces.model.TreeNode;
import org.primefaces.model.Visibility;
import org.primefaces.model.menu.DefaultMenuItem;
import org.primefaces.model.menu.DefaultMenuModel;
import org.primefaces.model.menu.MenuModel;

public abstract class PlcControllerBase<O extends PlcBase, F extends PlcBaseFSC, S extends CmdInsPolicyPolicyXXXSave, L extends CmdInsPolicyPolicyXXXLoad> extends CntrlBase implements PlcCntrlInterface, PrintCntrlInterface, SelectCustInterface, Serializable {

  private static final long serialVersionUID = 1L;
  @EJB
  private PoliciesFacade policiesFacade;
  @EJB
  private CmdInsPolicyAnexFind anexFindFacade;
  @EJB
  protected CmdInsPolicyAnexLoad anexLoadFacade;
  @EJB
  protected CmdInsPolicyAnexDelete anexDeleteFacade;
  @EJB
  private CmdInsPolicyPolicyDelete cmdInsPolicyPolicyDelete;
  @EJB
  private CmdInsPolicyCmplxPlcUndoAnul cmdInsPolicyCmplxPlcUndoAnul;
  @EJB
  private CmdPolicyDeleteUndo cmdPolicyDeleteUndo;
  @EJB
  private CmdInsPolicyPolicyFind cmdPoliciFind;
  @EJB
  private CmdInsPlcHistoryFind cmdInsPlcHistoryFind;
  @EJB
  private CmdInsAgentsCommissionFind cmdInsAgentsCommissionFind;
  //
  @Inject
  private CustContactsController custContCntrl;
  //@Inject
  protected CustSelect custSelect;

  protected O plcObj;
  private O plcOldData;
  protected F fs;
  private PlcAnnexBase plcAnnexObj;//TODO - нещо не ми харесва тая концепция на анексите.
  private PlcAnnexBase plcSecAnnexObj;
  private String viewMode;
  private String operType;
  private String operTypeOnLoad;
  private String plcType;
  private NomInspolicyinstype plcTypeNom;
  protected NomInsPolicyTypeBase plcTypeOraIns;
  protected Integer plcID;
  protected Integer elSmetkaId;
  //protected String AgencyIDAgentID;
  protected boolean permDuePrem;
  protected boolean permEditPolicy;
  protected boolean permDelAnnex;
  protected boolean permDelAnnexBreak;
  protected boolean permSavePadejiValidate;
  protected boolean permPadejiAfterPlcExpDate;
  protected boolean permChangeContractDate;
  protected boolean permEditPadeji;
  protected boolean permSecondAgent;
  protected boolean permSecondAgentView;
  private boolean permEditExtras;
  private boolean permEditDiscounts;
  private boolean permEditFlRenew;
  private boolean permPlcHistory;
  private boolean permPlcPictures;
  private boolean permCommissions;
  protected boolean permAccumulation;
  protected MenuModel plcPrintMenu;
  protected NomPolicyStatus plcStatusAfterSave;
  private CmdInsPlcHistoryFind_Result plcHistoryResult;
  private PlcAnnexBase selectedPlcAnnex;
  private CmdInsPlcHistoryFind_ResultRow selectedPlcHistory;
  private CmdListData_Result<CmdInsAgentsCommissionFind_Result> commissionFindResult;
  private List<CmdInsAgentsCommissionFind_Result> selectedCommList;
  protected DataTableCustomExporter dataTableExporter;
  private TreeNode accumulationTree;
  protected String[] allowedCustKlientCustTypes;
  private PicturesCntrl picturesCntrl;
  //
  /*
   * параметри за търсене на полица
   */
  protected Integer plcSearchId;
  protected CmdInsPolicyPolicyFind_ResultRow plcSearchSelectedRow;
  protected String plcSearchNum;
  protected String plcSearchCustName;
  protected NomFormtype plcSearchBlankType;
  protected String plcSearchBlankNum;
  protected String plcSearchCustPin;
  protected String plcSearchDKN;
  protected String plcSearchVIN;
  protected String plcSearchVINLastSym;
  protected String plcSearchAssistanceTalon;
  private SelectItem[] plcSearchNomFormtype;
  protected String plcSearchInsCustPin;
  protected String plcSearchMainPlcNum;
  private List<CmdInsAgentsAgentFindRow> plcAgencyAgentSI;
  protected Collection<NomMaturitytype> nomMaturitytype;
  private String blankNumText;
  private List<CmdInsPolicyPolicyFind_ResultRow> plcSearchResultList;
  /*
   * END параметри за търсене на полица
   */
  private SelectItem[] secondAgents;
  private SelectItem[] nomFormtype;
  private SelectItem[] nomElSmetkiPayType;
  private SelectItem[] nomPeriod;
  private SelectItem[] nomVal;
  protected BigDecimal otsSum;
  protected BigDecimal nadSum;
  protected BigDecimal otsSumObj;
  protected BigDecimal nadSumObj;
  private BigDecimal totalPremium;
  private BigDecimal taxWrittenSum;
  private BigDecimal totalPlcSum;
  protected String MPSSeatsSize;
  protected String preUpdateFlds;
  protected String menuTerminationLabel;
  protected boolean printElSmetka;
  protected boolean printElSmetka2ndPlc;
  private String cancelBtnText;
  protected BigDecimal taxPremProc;
  protected BigDecimal inDFZFavourPrc;
  private boolean proportionDiscount;
  private String editBtnText;
  private String skipQuestions;
  private String chRequestQuestions;
  protected Map<String, Integer[]> plcOldPadejId;
  private PlcPadejiBase selectedPadejForPrint;
  private PlcPadejiBase emptySelectedPadejForPrint;
  protected BigDecimal agentCommission;
  private boolean bRenderNewOperBtn;
  private Map<String, String> plcNamesMap;
  /*
   * за Анекси
   */
  protected SelectItem[] nomAnnexType;
  protected SelectItem[] nomCancelationreason;
  protected boolean bAnnexNew;
  protected boolean bAnnexView;
  protected boolean bSaveGF;
  protected boolean showAnnexForm;
  protected boolean showSecondAgentSection;
  protected boolean expanedSecondAgentSection;
  private List<PlcAnnexBase> anexesList;
  private Map<String, List<PlcPadejiBase>> plcPadejiMap;

  /*
   * END за Анекси
   */
  @PostConstruct
  private void postInit() {
    this.custSelect = new CustSelect(this);
    this.picturesCntrl = new PicturesCntrl(this);
    this.dataTableExporter = new DataTableCustomExporter();
    this.bAnnexNew = false;
    this.bAnnexView = false;
    this.bSaveGF = false;
    this.showAnnexForm = false;
    this.bRenderNewOperBtn = false;
    this.fs = this.NewFsObject();
    this.plcNamesMap = new HashMap<>();

    this.taxPremProc = new BigDecimal(utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "TaxPremProc", "0.00"));
    this.inDFZFavourPrc = new BigDecimal(utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "InDFZFavourPrc", "0.00"));
    this.proportionDiscount = Tools.Str2Bool(utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "ProportionDiscount", "F"));
//    this.AgencyIDAgentID = "";
//    if (this.app.getVerInsAsset() || this.app.getVerInsAllianz()) {
//      this.usersFacade.LoadAgentData(this.sb.getCurrentUser());
//    }
    if (this.app.getVerInsBulIns()) {
      this.blankNumText = Tools.getMsg("Plc_FormNumber");
      this.MPSSeatsSize = "5";
    } else {
      this.blankNumText = Tools.getMsg("Plc_BlankNum");
      this.MPSSeatsSize = "3";
    }

    this.menuTerminationLabel = Tools.getMsg("Menu_Termination");
  }

  public void init(String p1, String p2) {
    this.setP1(p1);
    this.setP2(p2);
    this.onLoad();
  }

  public void onLoad() {
    this.permChangeContractDate = this.sb.HasPermission(Permissions.PLC_CHANGE_CONTRACT_DATE);
    this.initFromParams(Tools.parseAction(this.p1));
    // TODO - да се измисли универсална схема
    this.FillNomFormtype(false);

    this.plcObj = this.NewPlcObject();
    this.setPermByPlcType();
    this.permEditPolicy = true;//this.sb.HasPermission(Permissions.EDIT_POLICY);
    this.permDelAnnex = this.sb.HasPermission(Permissions.PLC_DEL_ANNEX);
    this.permDelAnnexBreak = this.sb.HasPermission(Permissions.PLC_DEL_ANNEX_BREAK);
    this.permSavePadejiValidate = this.sb.HasPermission(Permissions.SAVE_PADEJ_VALIDATION);
    this.permPadejiAfterPlcExpDate = this.sb.HasPermission(Permissions.SAVE_PADEJ_VALIDATION_PLC_EXP_DATE);
    this.permEditPadeji = this.sb.HasPermission(Permissions.PLC_EDIT_PADEJI);
    this.permSecondAgent = this.sb.HasPermission(Permissions.MENU_POLICIES_SECOND_AGENT);
    this.permSecondAgentView = this.sb.HasPermission(Permissions.MENU_POLICIES_SECOND_AGENT_VIEW);
    this.permPlcHistory = this.sb.HasPermission(Permissions.PLC_HISTORY);
    this.permPlcPictures = this.sb.HasPermission(Permissions.PLC_PICTURES);
    this.permCommissions = this.sb.HasPermission(Permissions.PERM_PLC_COMMISSIONS);
    // TODO - да се вчаси
    switch (this.operType) {
      case def.OPER_TYPE_NEW:
      case def.OPER_TYPE_BONUS_MALUS:
        try {
        this.plcObj = this.PrepareDefaults(this.plcObj);
        this.plcPrepareNew();
      } catch (SQLException ex) {
        throw new Error(this.toString() + ".onLoad()", ex);
      }
      break;
      case def.OPER_TYPE_EDIT:
      case def.OPER_TYPE_VIEW:
      case def.OPER_TYPE_NEW_BY_ID:
      case def.OPER_TYPE_PREDL_TO_PLC:
      case def.OPER_TYPE_PREDL_ANNEX_DEL:
      case def.OPER_TYPE_IMPORT_PERSONS:
      case def.OPER_TYPE_DUE_PREMIUM:
        if (!Tools.isEmpty(this.p2)) {
          this.plcID = Integer.valueOf(this.p2);
        }
        break;
      case def.OPER_TYPE_RENEW:
      case def.OPER_TYPE_PRINT:
        break;
      case def.OPER_TYPE_SECOND_AGENT:
        this.showSecondAgentSection = this.permSecondAgent;
        break;
      case def.OPER_TYPE_ANNEX_NEW:
        this.plcAnnexObj = new PlcAnnexBase();
        this.showAnnexForm = true;
        break;
      case def.OPER_TYPE_ANNEX_BREAK:
        this.plcAnnexObj = new PlcAnnexBase();
        this.plcAnnexObj.setAnnexTypeId(this.utils.FindNom(NomAnnextype.class, NomAnnextype.BREAK));
        this.showAnnexForm = true;
        break;
      case def.OPER_TYPE_ANNEX_RECOVER:
        if (!this.app.getVerInsAllianz() && !this.app.getVerInsEZK() && !this.app.getVerInsMVIns()) {
          this.plcAnnexObj = new PlcAnnexBase();
          this.plcAnnexObj.setAnnexTypeId(this.utils.FindNom(NomAnnextype.class, NomAnnextype.RECOVER));
          this.showAnnexForm = true;
        }
        break;
    }
    this.bAnnexNew = this.plcAnnexObj != null && !this.operTypeView();
    if (!this.operTypeNew() && !this.operTypeReNew() && !this.operTypeNewByID() && !this.operTypeSecondAgent()) {
      this.showSecondAgentSection = this.permSecondAgentView;
    }
    this.expanedSecondAgentSection = this.operTypeSecondAgent();
    try {
      this.plcLoadByID();
    } catch (SQLException ex) {
      throw new Error(this.toString() + ".onLoad()", ex);
    }
  }

  protected void initFromParams(String[] params) {
    if (params != null && params.length > 3) {
      this.setPlcType(params[2]);
      this.setOperType(params[1]);
      this.operTypeOnLoad = this.getOperType();
      this.setViewMode(params[3]);
    }
  }

  //
  /*
   * обработки, value change methods и др. подобни
   */
  //
  abstract public O NewPlcObject();

  abstract public O asPlc();

  abstract public F NewFsObject();

  abstract public S getSaveFacade();

  abstract public L getLoadFacade();

  public String GetCodPolica() {
    if (Tools.isEmpty(this.plcObj.getPolicyID())) {
      if (this.app.getVerInsBulIns()) {
        if (this.plcObj.getBlancType() != null) {
          return (this.plcObj.getBlancType().getInscode());
        } else {
          return (null);
        }
      } else {
        if (this.plcObj.getInsPolicyType() != null) {
          return this.plcObj.getInsPolicyType().getNomPlcCode();
        } else {
          return (null);
        }
      }
    } else {
      return (this.plcObj.getCodPolica());
    }
  }

  protected boolean lockPolicyOnLoad(Integer chStamp) {
    return (this.operTypeEdit() || this.operTypeIssuePlc() || this.operTypeImportPersons() || this.operTypeDuePremium() || this.operTypeImportFamilyMembers() || this.operTypeEngLetterNew() || (this.operTypeAnnexDelPredl() && this.plcTypeOraIns.isComplex()) || (this.bAnnexNew && Tools.isEmpty(chStamp)));
  }

  public CmdInsPolicyPolicyXXXLoad_Param GetLoadParams(Integer plcID, Integer mainPlcId, Integer chStamp) {
    CmdInsPolicyPolicyXXXLoad_Param loadParams = new CmdInsPolicyPolicyXXXLoad_Param();
    if (this.plcTypeOraIns.isComplex()) {
      if (Tools.isEmpty(mainPlcId)) {
        loadParams.setPolicyID(plcID);
      } else {
        loadParams.setMainPlcID(mainPlcId);
      }
    } else {
      loadParams.setPolicyID(plcID);
    }
    loadParams.setChStamp(chStamp);
    loadParams.setLockReq(this.lockPolicyOnLoad(chStamp));
    if (this.bAnnexNew) {
      loadParams.setAction(CmdInsPolicyPolicyXXXLoad_Param.ACTION_ANNEX);
    } else {
      if (this.isNewPlcByOperType()) {
        loadParams.setAction(CmdInsPolicyPolicyXXXLoad_Param.ACTION_RENEW);
      } else {
        loadParams.setAction(CmdInsPolicyPolicyXXXLoad_Param.ACTION_EDIT);
      }
    }
    if (this.plcTypeOraIns.isGroupTypeNone()) {
      loadParams.setType(Integer.valueOf(this.plcTypeOraIns.getNomId()));
    } else {
      loadParams.setGroupType(this.plcTypeOraIns.getGroupType());
    }
    loadParams.setBlankType(this.plcSearchBlankType == null ? null : this.plcSearchBlankType.getNomId());
    loadParams.setBlankNum(this.plcSearchBlankNum);
    loadParams.setPolicyNum(this.plcSearchNum);
    loadParams.setAssistanceTalon(this.plcSearchAssistanceTalon);
    loadParams.setInsCustPin(this.plcSearchInsCustPin);
    if (this.getbLoadAnnexesList(chStamp)) {
      loadParams.setbLoadAnnexes(true);
    }
    //loadParams.setMode("m");
    return (loadParams);
  }

  protected boolean getbLoadAnnexesList(Integer chStamp) {
    return ((this.app.getVerInsAsset() || this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns() || this.app.getVerInsNadejda() || this.app.getVerInsOZOK())
            && (this.operTypeView() || this.operTypeRecover() || this.operTypeAnnexDel() || this.operTypeAnnexDelPredl() || this.operTypeAnnexOffer())
            && Tools.isEmpty(chStamp));
  }

  protected void setPermByPlcType() {
    this.permDuePrem = this.plcObj.getPlcCombType() != null && this.sb.hasPermissionNomPlc(this.plcObj.getPlcCombType().getNomId(), PermNomType.duePrem);
    this.permEditExtras = this.plcObj.getPlcCombType() != null && this.sb.hasPermissionNomPlc(this.plcObj.getPlcCombType().getNomId(), PermNomType.extrax);
    this.permEditDiscounts = this.plcObj.getPlcCombType() != null && this.sb.hasPermissionNomPlc(this.plcObj.getPlcCombType().getNomId(), PermNomType.discounts);
    this.permEditFlRenew = this.plcObj.getPlcCombType() != null && this.sb.hasPermissionNomPlc(this.plcObj.getPlcCombType().getNomId(), PermNomType.flRenew);
  }

  public O PrepareDefaults(O defObj) {

    NomCountry defCountry = (NomCountry) this.nomsFacade.find(NomCountry.BG, NomCountry.class);

    defObj.setReg_Date(this.sb.getCurrDate());

    defObj.setFrom_Date(Tools.Add2Date(defObj.getReg_Date(), 1, 0, 0, false));
    defObj.setFromTime(def.timePlcStart);
    defObj.setToTime(def.timePlcEnd_2);
    defObj.setIn_Count(1);
    defObj.setAg_No(this.sb.getCurrentAgency());

    defObj.getCustKlient().setCustCountryId(defCountry);
    defObj.setMonth((NomPeriod) this.nomsFacade.find(NomPeriod.YEAR_1, NomPeriod.class));
    defObj.setTax(true);
    if (defObj.getPlcCombType() != null && !Tools.isEmpty(defObj.getPlcCombType().getNomId())) {
      defObj.setOtsNadList(this.OtsNad_FillList(defObj.getPlcCombType().getNomId(), this.otsNadLevel(), true));
    }
    defObj.FillPlcCodVal(def.SYS_CURR);

    this.fs.setTo_Date(true);
    this.fs.setToTime(true);
    this.fs.getPlcRowFSC().setSaveRowBtn(true);
    this.fs.getPlcRowFSC().setTrfRowBtn(true);

//    if (this.app.getVerInsAsset() || this.app.getVerInsAllianz()) {
//      if (this.getAutoFillAgencyAgent()) {
//        this.AgencyIDAgentID = this.getUniqCodeAgent();
//      }
//    }
    defObj.setBlancType(this.utils.FindNom(NomFormtype.class, NomFormtype.AUTO_0));
    this.handleBlancTypeChange(null);

    return (defObj);
  }

  protected void PrepareDefaultsAnex() {
    if (this.plcAnnexObj == null) {
      this.plcAnnexObj = new PlcAnnexBase();
    }
    this.plcAnnexObj.setAnnexDate(this.sb.getCurrDate());
    if (this.operTypeRecover()) {
      this.plcAnnexObj.setAnnexComDate(Tools.Add2Date(this.sb.getCurrDate(), 1, 0, 0, true));
    } else {
      this.plcAnnexObj.setAnnexComDate(this.sb.getCurrDate());
    }
    this.plcAnnexObj.setAnnexComTime(def.timePlcStart);
    this.plcAnnexObj.setAnnexExpDate(this.plcObj.getTo_Date());
    this.plcAnnexObj.setAnnexExpTime(def.timePlcEnd_2);
    this.plcAnnexObj.setAnnexRegDate(new Date());
    this.plcAnnexObj.setAnnexRegTime(def.timePlcStart);
    this.plcAnnexObj.setAnnexNo(this.plcObj.getBroiAnexes() + 1);
    this.handleAnexNoChange(null);
    if (this.operTypeAnnexBreak()) {
      this.fillAnnexBreakPremiumSec(this.getPlcType(), this.plcAnnexObj, this.plcObj.getRAmount());
      this.plcLoad_FillAnexBreak_cbCancelReason();
    }
  }

  protected void fillAnnexBreakPremiumSec(String policyType, PlcAnnexBase annexBreak, BigDecimal annexPlanAmount) {
    if (this.operTypeAnnexBreak()) {
      annexBreak.setAnnexPlan(annexPlanAmount);
      List<PlcPadejiBase> padejiList = (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(policyType);
      annexBreak.setAnnexTaxPlan(this.GetPadejiAmount(padejiList)[1]);

      if (padejiList != null) {
        for (Iterator it = padejiList.iterator(); it.hasNext();) {
          PlcPadejiBase oPadej = (PlcPadejiBase) it.next();
          if (oPadej.inclInAnnexBreakPremCalc()) {
            annexBreak.setAnnexPay(annexBreak.getAnnexPay().add(oPadej.getVnesena_Premia()));
            annexBreak.setAnnexCharged(annexBreak.getAnnexCharged().add(oPadej.getNa4isl_Premia()));
            annexBreak.setAnnexPaidTax(annexBreak.getAnnexPaidTax().add(oPadej.getTaxPlatenAmnt()));
          }
        }
      }
      this.handleAnexRetPremCalc(policyType, annexBreak);
    }
  }

  protected void plcInitOnRenew() {
    this.plcObj.setChStamp(0);
    this.plcObj.setIns_Ref("");
    this.plcObj.setMainPlcID(0);
    this.plcObj.setComplexPlcId(0);
    this.plcObj.setPreizdavaneTemp(null);
    this.plcObj.setStatus(new NomPolicyStatus());
    this.plcObj.setDispStatus(null);
    this.plcObj.setMonth(new NomPeriod());
    this.plcObj.setAgency(null);
    this.plcObj.setAg_No(this.sb.getCurrentAgency());
    this.plcObj.setAgent(this.sb.getUserDefaultAgent());
    this.plcObj.setBlankNo(null);
    this.plcObj.setBlancType(null);

    this.plcObj.setPayType(null);
    this.plcObj.setIBAN(null);
    //this.plcObj.FillPlcCodVal(def.SYS_CURR);
    O plcDefaults = this.PrepareDefaults(this.NewPlcObject());

    this.plcObj.setMonth(plcDefaults.getMonth());
    this.plcObj.setReg_Date(plcDefaults.getReg_Date());
    this.plcObj.setFrom_Date(plcDefaults.getFrom_Date());
    this.plcObj.setFromTime(plcDefaults.getFromTime());
    this.plcObj.setToTime(plcDefaults.getToTime());
    this.SetExpiringDate(this.plcObj.getFrom_Date(), true);
    if (this.getRenderDaysCount()) {
      this.calcExpiringDateByDayCount();
    }
    this.plcObj.setIn_Count(plcDefaults.getIn_Count());

    this.plcObj.setTax(plcDefaults.getTax());
    this.plcObj.setBlancType(plcDefaults.getBlancType());
    this.plcObj.setGF(BigDecimal.ZERO.setScale(2));

    if (this.app.getVerInsBulIns()) {
      handleContractDateValueChange(null);
      this.setOtsWrPrFS();
    } else {
      if (this.app.getVerInsNadejda() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
        this.plcObj.setPreizdavane(true);
      }
    }
    this.plcObj.setOtsNadList(this.OtsNad_FillList(this.plcObj.getPlcCombType().getNomId(), this.otsNadLevel(), true));
    this.plcObj.setRAmnt(BigDecimal.ZERO.setScale(2));
    this.plcObj.setRAmount(BigDecimal.ZERO.setScale(2));
    this.WrittenPremiumChange(null);
    this.plcObj.setPadejiMap(new HashMap<>());
    if (this.plcObj.getInsPolicyType() != null) {
      this.plcObj.getPadejiMap().put(this.plcObj.getInsPolicyType().getNomId(), new ArrayList<>());
    }
    this.plcObj.setPadejiMapNotVisible(new HashMap<>());
    this.plcObj.setStikeriList(new ArrayList<>());
    this.plcObj.setAnexesList(new ArrayList<>());
    this.plcInitOnRenew(plcDefaults);
    this.plcObj.clearInactiveNoms();
  }

  protected void plcInitOnRenew(O plcDefaults) {

  }

  public void plcSaveNew(ActionEvent ae) throws SQLException {
    if (this.plcSave_doBeforeSave()) {
      if (this.plcValidateSave()) {
        if (Tools.InList(this.operType, def.OPER_TYPE_NEW, def.OPER_TYPE_RENEW, def.OPER_TYPE_BONUS_MALUS)) {
          NomPolicyStatus currStatus = this.plcObj.getStatus();
          NomPolicyStatus currStatus2ndPlc = null;
          Integer id2ndPlc = null;
          Integer idPlc = this.plcObj.getPolicyID();
          Integer[] complexPlcIds = this.plcObj.getComplexPlcIds();
          this.plcObj.setPolicyID(0);
          this.plcObj.setComplexPlcIds(null, 0);

          this.plcObj.setStatus((NomPolicyStatus) this.nomsFacade.find(NomPolicyStatus.PREDLOJENIE, NomPolicyStatus.class));
          this.plcObj.setPStatus((NomPolicyOfferStatus) this.nomsFacade.find(NomPolicyOfferStatus.PREDLOJENIE, NomPolicyOfferStatus.class));

          if (this.getbPlcCombined()) {
            currStatus2ndPlc = this.get2ndPlcCntrl().getPlcObj().getStatus();
            id2ndPlc = this.get2ndPlcCntrl().getPlcObj().getPolicyID();
            this.get2ndPlcCntrl().getPlcObj().setPolicyID(0);
            this.get2ndPlcCntrl().getPlcObj().setStatus((NomPolicyStatus) this.nomsFacade.find(NomPolicyStatus.PREDLOJENIE, NomPolicyStatus.class));
            this.get2ndPlcCntrl().getPlcObj().setPStatus((NomPolicyOfferStatus) this.nomsFacade.find(NomPolicyOfferStatus.PREDLOJENIE, NomPolicyOfferStatus.class));
          }
          this.plcSave_FillSysFlds();
          this.plcSave_FillLists(true);
          if (this.plcSave(true)) {
            JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperCreated2", this.GetPlcText()));
          } else {
            this.plcObj.setStatus(currStatus);
            this.plcObj.setPolicyID(idPlc);
            this.plcObj.setComplexPlcIds(complexPlcIds, 0);
            if (this.getbPlcCombined()) {
              this.get2ndPlcCntrl().getPlcObj().setStatus(currStatus2ndPlc);
              this.get2ndPlcCntrl().getPlcObj().setPolicyID(id2ndPlc);
            }
          }
        } else {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
        }
      }
    }
  }

  public void plcSaveEdit(ActionEvent ae) throws SQLException {
    if (this.plcSave_doBeforeSave()) {
      if (this.plcValidateSave()) {
        if (Tools.InList(this.operType, def.OPER_TYPE_EDIT, def.OPER_TYPE_IMPORT_PERSONS, def.OPER_TYPE_DUE_PREMIUM)) {
          NomPolicyStatus currStatus = this.plcObj.getStatus();
          NomPolicyStatus currStatus2ndPlc = null;
          if (this.getbPlcCombined()) {
            currStatus2ndPlc = this.get2ndPlcCntrl().getPlcObj().getStatus();
          }
          this.plcSave_FillSysFlds();
          this.plcSave_FillLists(false);
          if (this.plcSave(false)) {
            if (Tools.isEmpty(this.plcObj.getIns_Ref())) {
              JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperUpdated2", this.GetPlcText()));
            } else {
              JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperUpdated", this.GetPlcText()));
            }
          } else {
            this.plcObj.setStatus(currStatus);
            if (currStatus2ndPlc != null) {
              this.get2ndPlcCntrl().getPlcObj().setStatus(currStatus2ndPlc);
            }
          }
        } else {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
        }
      }
    }
  }

  public void plcSaveGF(ActionEvent ae) throws SQLException {
    this.bSaveGF = true;
    if (this.plcSave_doBeforeSave()) {
      if (this.plcValidateSave()) {
        NomPolicyStatus currStatus = this.plcObj.getStatus();
        NomPolicyStatus currStatus2ndPlc = null;
        Integer idPlc = this.plcObj.getPolicyID();
        Integer[] complexPlcIds = this.plcObj.getComplexPlcIds();
        boolean bRet = false;
        Integer id2ndPlc = null;
        this.plcObj.setStatus(this.nomsFacade.findNom(NomPolicyStatus.ACTIVE, NomPolicyStatus.class));
        this.plcObj.setPStatus(this.nomsFacade.findNom(NomPolicyOfferStatus.POLICA, NomPolicyOfferStatus.class));

        if (this.getbPlcCombined()) {
          currStatus2ndPlc = this.get2ndPlcCntrl().getPlcObj().getStatus();
          id2ndPlc = this.get2ndPlcCntrl().getPlcObj().getPolicyID();
          this.get2ndPlcCntrl().getPlcObj().setStatus(this.nomsFacade.findNom(NomPolicyStatus.ACTIVE, NomPolicyStatus.class));
          this.get2ndPlcCntrl().getPlcObj().setPStatus(this.nomsFacade.findNom(NomPolicyOfferStatus.POLICA, NomPolicyOfferStatus.class));
        }

        this.plcSave_FillSysFlds();
        this.plcSave_FillLists(true);

        //TODO - да се измисли по-умно като има време
        switch (this.operType) {
          case def.OPER_TYPE_NEW:
          case def.OPER_TYPE_RENEW:
          case def.OPER_TYPE_BONUS_MALUS:
            this.plcObj.setPolicyID(0);
            this.plcObj.setComplexPlcIds(null, 0);
            if (this.getbPlcCombined()) {
              this.get2ndPlcCntrl().getPlcObj().setPolicyID(0);
            }
            if (bRet = this.plcSave(true)) {
              JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperCreated", this.GetPlcText()));
              this.printElSmetka = !this.app.getVerInsOZOK();
            }
            break;
          case def.OPER_TYPE_EDIT:
            if (bRet = this.plcSave(false)) {
              JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperUpdated", this.GetPlcText()));
              this.printElSmetka = !this.app.getVerInsOZOK();
            }
            break;
          default:
            JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
            break;
        }
        if (!bRet) {
          this.plcObj.setPolicyID(idPlc);
          this.plcObj.setComplexPlcIds(complexPlcIds, 0);
          this.plcObj.setStatus(currStatus);
          if (this.getbPlcCombined()) {
            this.get2ndPlcCntrl().getPlcObj().setPolicyID(id2ndPlc);
            this.get2ndPlcCntrl().getPlcObj().setStatus(currStatus2ndPlc);
          }
        }
      }
    }
    this.bSaveGF = false;
  }

  public void plcSaveAnex(ActionEvent ae) throws SQLException {
    if (this.plcSave_doBeforeSave()) {
      if (this.plcValidateSave()) {
        if (this.bAnnexNew) {

          this.plcSave_FillSysFlds();
          this.plcSave_FillLists(false);

          this.fillAnnexDataOnSave(false, this.plcAnnexObj, this.plcObj, this.plcOldData);
          if (this.getbPlcCombined()) {
            this.fillAnnexDataOnSave(true, this.get2ndPlcCntrl().getPlcAnnexObj(), this.get2ndPlcCntrl().getPlcObj(), this.get2ndPlcCntrl().getPlcOldData());
          }
          if (this.plcSave(false)) {
            JsfUtil.addSuccessMessage(Tools.getMsg("Plc_AnexCreated"));
            this.printElSmetka = this.printElSmtkaOnAnex(true);
            this.anexesList = null;
            this.reloadPlcPrintMenu();
          }
          this.plcObj.setPlcAnnexObj(null);
          if (this.getbPlcCombined()) {
            this.get2ndPlcCntrl().getPlcObj().setPlcAnnexObj(null);
          }
        } else {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
        }
      }
    }
  }

  /*
  public void plcSaveOffer(ActionEvent ae) throws SQLException {
    if (this.plcSave_doBeforeSave()) {
      if (this.plcValidateSave()) {
        if (Tools.InList(this.operType, def.operType_VehicleOffer_New, def.operType_VehicleOffer_ReNew)) {
          NomPolicyStatus currStatus = this.plcObj.getStatus();
          Integer idPlc = this.plcObj.getPolicyID();
          this.plcObj.setPolicyID(0);

          this.plcObj.setStatus((NomPolicyStatus) this.nomsFacade.find(NomPolicyStatus.OFERTA, NomPolicyStatus.class));
          this.plcObj.setPStatus((NomPolicyOfferStatus) this.nomsFacade.find(NomPolicyOfferStatus.PREDLOJENIE, NomPolicyOfferStatus.class));

          this.plcSave_FillSysFlds();
          this.plcSave_FillLists(true);
          if (this.plcSave(true)) {
            JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperCreated", this.GetPlcText()));
          } else {
            this.plcObj.setStatus(currStatus);
            this.plcObj.setPolicyID(idPlc);
          }
        } else {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
        }
      }
    }
  }
   */
  public void plcDelAnnex(ActionEvent ae) {
    PlcAnnexBase lastAnnexObj = this.anexesList.get(this.anexesList.size() - 1);
    if (this.plcValidateDelAnnex(lastAnnexObj, this.getPlcPadejiMap())) {
      CmdInsPolicyAnexDelete_Params delParams = new CmdInsPolicyAnexDelete_Params();
      delParams.setAnnexId(lastAnnexObj.getAnnexId());
      delParams.setDelPrZaAnex(this.operTypeAnnexDelPredl());

      CmdResult res = this.anexDeleteFacade.Exec(this.sb.sessionInfo(), delParams);
      if (res.isOK()) {
        JsfUtil.addSuccessMessage(Tools.getMsg("Plc_AnnexDeleted"));
        this.anexesList.remove(lastAnnexObj);
        if ((this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) && this.operTypeRecover()) {
          this.plcStatusAfterSave = this.nomsFacade.findNom(NomPolicyStatus.ACTIVE, NomPolicyStatus.class);
          this.plcObj.setStatus(this.plcStatusAfterSave);
        }
      } else {
        JsfUtil.addErrorMessage(res.getErrorMsg());
      }
    }
  }

  public void plcIssuePlc(ActionEvent ae) throws SQLException {
    if (this.validatePlcIssuePlc()) {
      NomPolicyStatus currStatus = this.plcObj.getStatus();
      NomPolicyOfferStatus currPStatus = this.plcObj.getPStatus();
      boolean bIssuePlcFromPredl = this.operTypeIssuePlcFromPredl();

      this.plcObj.setStatus((NomPolicyStatus) this.nomsFacade.find(NomPolicyStatus.ACTIVE, NomPolicyStatus.class));
      this.plcObj.setPStatus((NomPolicyOfferStatus) this.nomsFacade.find(NomPolicyOfferStatus.POLICA, NomPolicyOfferStatus.class));

      this.plcSave_FillSysFlds();
      this.plcSave_FillLists(true);
      if (this.plcSave(true)) {
//        this.anexesList = null;
        switch (currStatus.getNomId()) {
          case NomPolicyStatus.PREDLOJENIE:
            JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperCreated", this.GetPlcText()));
            this.printElSmetka = !this.app.getVerInsOZOK();
            break;
          case NomPolicyStatus.PREDLOJENIE_ANNEX:
            JsfUtil.addSuccessMessage(Tools.getMsg("Plc_AnexCreated"));
            this.printElSmetka = this.printElSmtkaOnAnex(false);
            break;
        }
        JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperCreated", this.GetPlcText()));
        this.reloadPlcPrintMenu();
        if (this.hasPolicySecondAgent() && bIssuePlcFromPredl) {
          if (!this.saveSecondAgent()) {
            this.setOperType(def.OPER_TYPE_SECOND_AGENT);
            this.fs.getFsSecondAgent().SetViewMode(false);
          }
        }
      } else {
        this.plcObj.setStatus(currStatus);
        this.plcObj.setPStatus(currPStatus);
      }
    }
  }

  protected boolean validatePlcIssuePlc() {
    boolean bRet = true;
    if (this.operTypeIssuePlc()) {
      if (this.operTypeIssuePlcFromPredl()) {
//        if (!validateOfferIssue(this.plcObj.getOfferAgreeDate(), this.plcObj.getPlcCombType(), this.sb)) {
//          bRet = false;
//        }
        if (!this.plcValidateSrok()) {
          bRet = false;
        }
        if (!this.validateSecondAgent()) {
          bRet = false;
        }
      }
    } else {
      bRet = false;
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
    }
    return bRet;
  }

  public void plcSaveSecondAgent(ActionEvent ae) throws SQLException {
    if (this.validateSaveSecondAgent()) {
      this.saveSecondAgent();
    }
  }

  private boolean saveSecondAgent() throws SQLException {
    boolean bRet = true;
//    if (this.plcObj.getSecondAgentData().getAgent() != null) {
//      CmdInsPolicySecondAgentSave_Params params = new CmdInsPolicySecondAgentSave_Params();
//      params.setBorrowerId(this.plcObj.getSecondAgentData().getCustBorrower().getCustId());
//      params.setBcCode(this.plcObj.getSecondAgentData().getBcCode());
//      params.setSecondAgentId(this.plcObj.getSecondAgentData().getAgent().getAgentId());
//      params.setSecondAgentId(this.plcObj.getSecondAgentData().getAgent().getAgentId());
//      if (!Tools.isEmpty(this.plcObj.getComplexPlcDependencies())) {
//        for (Iterator<PlcDependenciesBase> it = this.plcObj.getComplexPlcDependencies().iterator(); it.hasNext();) {
//          PlcDependenciesBase dep = it.next();
//          params.addToPlcIdList(dep.getPlcID());
//        }
//      } else {
//        params.addToPlcIdList(this.plcObj.getPolicyID());
//      }
//      CmdResult res = this.cmdSecondAgentSave.Exec(this.sb.sessionInfo(), params);
//      bRet = res.isOK();
//      if (bRet) {
//        JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperSecondAgentCreated"));
//        this.setOperType(def.OPER_TYPE_VIEW);
//        this.fs.getFsSecondAgent().SetViewMode(true);
//      } else {
//        JsfUtil.addErrorMessage(res.getErrorMsg());
//      }
//    }
    return bRet;
  }

  private boolean validateSaveSecondAgent() {
    boolean bRet = true;
    if (this.operTypeSecondAgent()) {
      if (!this.validateSecondAgent()) {
        bRet = false;
      }
    } else {
      bRet = false;
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
    }
    return bRet;
  }

  private boolean validateSecondAgent() {
    boolean bRet = true;
//    if (this.hasPolicySecondAgent() && (this.operTypeSecondAgent() || this.operTypeIssuePlcFromPredl())) {
//      String alianzEik = this.utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "AlianzEIK", "");
//      if (this.plcObj.getSecondAgentData().getAgent() != null) {
//        if (!Tools.isEmpty(this.plcObj.getAgent().getAgentCode()) && (this.plcObj.getAgent().getAgentCode().equals(def.AGENT_CODE_1) || (this.plcObj.getAgent().getAgentCode().length() > 5 && this.plcObj.getAgent().getAgentCode().substring(3, 5).equals(def.AGENT_CODE_2)))
//                && !this.sb.HasPermission(Permissions.SECOND_AGENT_MAIN_AGENT_AAA96XX)) {
//          bRet = false;
//          JsfUtil.addErrorMessage(Tools.getMsg("Plc_SecondAgentId") + ": " + Tools.getMsg("P001-158"));
//        }
//        if (bRet) {
//          if (this.plcObj.getSecondAgentData().getBcCode() == null) {
//            bRet = false;
//            JsfUtil.addErrorMessage(Tools.getMsg("Plc_SecondAgentId") + ": " + Tools.getMsg("S001-005", Tools.getMsg("Plc_BcCode")));
//          }
//          if (Tools.isEmpty(this.plcObj.getSecondAgentData().getCustBorrower().getCustId())) {
//            bRet = false;
//            JsfUtil.addErrorMessage(Tools.getMsg("Plc_SecondAgentId") + ": " + Tools.getMsg("Plc_CustErr", Tools.getMsg("Plc_Borrower")));
//          }
//        }
//      } else {
//        if (this.operTypeSecondAgent() || this.plcObj.getSecondAgentData().getBcCode() != null || !Tools.isEmpty(this.plcObj.getSecondAgentData().getCustBorrower().getCustId())) {
//          bRet = false;
//          JsfUtil.addErrorMessage(Tools.getMsg("Plc_SecondAgentId") + ": " + Tools.getMsg("P001-160"));
//        }
//      }
//      if (this.operTypeIssuePlcFromPredl()) {
//        if (this.plcObj.getSecondAgentData().getAgent() == null) {
//          if (!Tools.isEmpty(this.plcObj.getCustVPolzaNa().getCustPin())
//                  && !Tools.isEmpty(alianzEik)
//                  && this.plcObj.getCustVPolzaNa().getCustPin().startsWith(alianzEik)) {
//            if (this.sb.HasPermission(Permissions.SECOND_AGENT_V_POLZA_NA_ALIANZ_BANK)
//                    || (!Tools.isEmpty(this.plcObj.getAgent().getAgentCode()) && (this.plcObj.getAgent().getAgentCode().equals(def.AGENT_CODE_1) || (this.plcObj.getAgent().getAgentCode().length() > 5 && this.plcObj.getAgent().getAgentCode().substring(3, 5).equals(def.AGENT_CODE_2))))
//                    || (!Tools.isEmpty(this.plcObj.getCampaignId()) && this.plcObj.getCampaignId().equals(def.CAMPAIGN_3))) {
//            } else {
//              bRet = false;
//              JsfUtil.addErrorMessage(Tools.getMsg("Plc_SecondAgentId") + ": " + Tools.getMsg("P001-159"));
//            }
//          }
//        }
//      }
//    }

    return bRet;
  }

  public void delSecondAgent(ActionEvent ae) throws SQLException {
//    if (this.validateDelSecondAgent()) {
//      this.plcObj.getSecondAgentData().setAgency(null);
//      this.plcObj.getSecondAgentData().setAgent(null);
//      this.plcObj.getSecondAgentData().setBcCode(null);
//      this.plcObj.getSecondAgentData().setCustBorrower(new Customer());
//      this.fillSecondAgentsItems(true);
//      if (!Tools.isEmpty(this.plcObj.getSecondAgentId())) {
//        CmdInsPolicySecondAgentChgSt_Params params = new CmdInsPolicySecondAgentChgSt_Params();
//        params.setPlcId(this.plcObj.getPolicyID());
//        CmdResult res = this.cmdSecondAgentChangeStatus.Exec(this.sb.sessionInfo(), params);
//        if (res.isOK()) {
//          JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperSecondAgentDeleted"));
//          this.plcObj.setSecondAgentId(0);
//        } else {
//          JsfUtil.addErrorMessage(res.getErrorMsg());
//        }
//      }
//    }
  }

  private boolean validateDelSecondAgent() {
    boolean bRet = true;
//    if (!Tools.isEmpty(this.plcObj.getSecondAgentId())) {
//      if (!Tools.skipQuestion(def.Q1, this.getSkipQuestions())) {
//        JsfUtil.addQuestionBox(def.Q1, Tools.getMsg("Act_Delete"));
//        this.setSkipQuestions(this.getSkipQuestions() + def.Q1 + "F");
//        bRet = false;
//      }
//    }
    return bRet;
  }

  public void plcAnnexOffer(ActionEvent ae) {
//    Res<CmdPolicyMove_Save_Result> cmdSaveMove = this.cmdPlcMoveSave.saveNewPlcMove(this.plcObj.getPolicyID(), this.plcObj.getPlcCombType(), NomPolicyOfferStatus.VYVEDENO, null, "Предложение за Анекс", this.sb.sessionInfo(), this.sb.getCurrentUser());
//    if (cmdSaveMove.isOK()) {
//      this.plcStatusAfterSave = this.utils.FindNom(NomPolicyStatus.class, NomPolicyStatus.PREDLOJENIE_ANNEX);
//      this.plcObj.setStatus(this.plcStatusAfterSave);
//      this.plcObj.setDispStatus(this.plcObj.getStatus());
//      JsfUtil.addSuccessMessage(Tools.getMsg("Sys_SaveOK"));
//    } else {
//      JsfUtil.addErrorMessage(cmdSaveMove.getErrorMsg());
//    }
  }

  private boolean plcAnnexOfferValidate(PlcAnnexBase annexToDel) {
    boolean bRet = true;
    //
    return bRet;
  }

  public void plcAnexes_Find() {
    CmdInsPolicyAnexFind_Params findParam = new CmdInsPolicyAnexFind_Params();
    findParam.setPolicyId(this.plcObj.getPolicyID());
    findParam.setAnnexStatus("T");

    CmdResult<CmdInsPolicyAnexFind_Result> res = this.anexFindFacade.Exec(this.sb.sessionInfo(), findParam);
    if (res.isOK()) {
      CmdInsPolicyAnexFind_Result findResult = res.getResponse();
      this.plcObj.setAnexesList(findResult.getPlcAnexList());
      if (this.getbPlcCombined()) {
        findParam.setPolicyId(this.get2ndPlcCntrl().getPlcObj().getPolicyID());
        findParam.setAnnexStatus("T");
        res = this.anexFindFacade.Exec(this.sb.sessionInfo(), findParam);
        if (res.isOK()) {
          findResult = res.getResponse();
          this.get2ndPlcCntrl().getPlcObj().setAnexesList(findResult.getPlcAnexList());
          if (this.plcObj.getAnexesList() != null && this.get2ndPlcCntrl().getPlcObj().getAnexesList() != null) {
            for (PlcAnnexBase plcAnnex : (List<PlcAnnexBase>) this.plcObj.getAnexesList()) {
              for (PlcAnnexBase plcAnnex2ndPlc : (List<PlcAnnexBase>) this.get2ndPlcCntrl().getPlcObj().getAnexesList()) {
                if (plcAnnex.getAnnexNo() == plcAnnex2ndPlc.getAnnexNo()) {
                  plcAnnex.setChStamp2ndPlc(plcAnnex2ndPlc);
                  break;
                }
              }
            }
          }
        } else {
          this.plcObj.setAnexesList(null);
          JsfUtil.addErrorMessage(res.getErrorMsg());
        }
      }
    } else {
      JsfUtil.addErrorMessage(res.getErrorMsg());
    }
  }

  private PlcAnnexBase plcAnex_Load(Integer anexId) {
    PlcAnnexBase anex = null;

    CmdResult<PlcAnnexBase> cmdAnexLoad = this.anexLoadFacade.plcAnex_Load(anexId, this.sb.sessionInfo());
    if (cmdAnexLoad.isOK()) {
      anex = cmdAnexLoad.getResponse();
    } else {
      JsfUtil.addErrorMessage(cmdAnexLoad.getErrorMsg());
    }
    return (anex);
  }

  public void plcLoad_AnnexView(PlcAnnexBase annexObj) throws SQLException {
    this.selectedPlcAnnex = annexObj;
    this.selectedPlcHistory = null;
    this.plcLoadPlcToObj(this.plcObj.getPolicyID(), this.plcObj.getComplexPlcId(), annexObj.getChStampPolicy());
    if (this.plcObj != null) {
      if (this.bLoadAnnexDataForAnnexView(annexObj)) {
        this.setPlcAnnexObj(this.plcAnex_Load(annexObj.getAnnexId()));
        this.bAnnexView = true;
      } else {
        this.setPlcAnnexObj(null);
        this.bAnnexView = false;
      }
      this.plcLoad_ShowPlc(false);
      JsfUtil.resetUIInputComponents();
    }
  }

  protected boolean bLoadAnnexDataForAnnexView(PlcAnnexBase annexObj) {
    return annexObj.getAnnexTypeId() != null && annexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.TEXT);
  }

  protected void setAnexData_Dozastrahovane() {

  }

  public void togglePlcHistoryPanel(ToggleEvent event) {
    if (event.getVisibility().equals(Visibility.VISIBLE)) {
      if (this.plcHistoryResult == null) {
        this.plcHistoryFind();
      }
    }
  }

  private void plcHistoryFind() {
    CmdInsPlcHistoryFind_Params findParam = new CmdInsPlcHistoryFind_Params();
    findParam.setPolicyId(this.plcObj.getPolicyID());

    CmdResult<CmdInsPlcHistoryFind_Result> res = this.cmdInsPlcHistoryFind.Exec(this.sb.sessionInfo(), findParam);
    if (res.isOK()) {
      this.plcHistoryResult = res.getResponse();
      if (this.getbPlcCombined()) {
        findParam = new CmdInsPlcHistoryFind_Params();
        findParam.setPolicyId(this.get2ndPlcCntrl().getPlcObj().getPolicyID());
        res = this.cmdInsPlcHistoryFind.Exec(this.sb.sessionInfo(), findParam);
        if (res.isOK()) {
          this.get2ndPlcCntrl().setPlcHistoryResult(res.getResponse());
          // combined Policies
        } else {
          this.plcHistoryResult = null;
          JsfUtil.addErrorMessage(res.getErrorMsg());
        }
      }
    } else {
      this.plcHistoryResult = null;
      JsfUtil.addErrorMessage(res.getErrorMsg());
    }
  }

  public void plcLoad_HistoryView(CmdInsPlcHistoryFind_ResultRow plc) throws SQLException {
    this.selectedPlcHistory = plc;
    this.selectedPlcAnnex = null;
    this.setPlcAnnexObj(null);
    this.bAnnexView = false;
    this.plcLoadPlcToObj(this.plcObj.getPolicyID(), this.plcObj.getComplexPlcId(), plc.getChStamp());
    if (this.plcObj != null) {
      this.plcLoad_ShowPlc(false);
      JsfUtil.resetUIInputComponents();
    }
  }

  public void postProcessSxlsxPlcHistory(Object document) throws UnsupportedEncodingException {
    SXSSFWorkbook workBook = (SXSSFWorkbook) document;
    SXSSFSheet sheet0 = workBook.getSheetAt(0);
    workBook.setSheetName(0, Tools.getMsg("Plc_PlcHistory"));

    SXLSXTools.autoWidthColumns(sheet0, sheet0.getRow(sheet0.getLastRowNum()).getPhysicalNumberOfCells());

    CellStyle intStyle = SXLSXTools.xlsCreateIntegerStyle(workBook);
    CellStyle stringStyle = SXLSXTools.xlsCreateStringStyle(workBook);
    String[] labels = {Tools.getMsg("Plc_Id"), Tools.getMsg("Plc_nomInspolicyinstype")};

    SXSSFSheet sheet1 = SXLSXTools.prepareNewSheet(workBook, Tools.getMsg("Plc_Plc"));
    SXLSXTools.xlsCreateHeader(workBook, sheet1, labels);
    SXLSXTools.xlsCreateCellInt(sheet1, this.plcObj.getPolicyID(), 1, 0, intStyle);
    SXLSXTools.xlsCreateCellNom(sheet1, this.plcObj.getPlcCombType(), 1, 1, stringStyle);
    for (int ii = 0; ii < labels.length; ii++) {
      sheet1.autoSizeColumn(ii);
    }
  }

  public SortMeta getPlcHistorySortBy() {
    return SortMeta.builder().field("correctNum").order(SortOrder.DESCENDING).build();
  }

  public void toggleCommissionFindPanel(ToggleEvent event) {
    if (event.getVisibility().equals(Visibility.VISIBLE)) {
      if (this.commissionFindResult == null) {
        this.commissionFind();
      }
    }
  }

  private void commissionFind() {
    CmdInsAgentsCommissionFind_Params params = new CmdInsAgentsCommissionFind_Params();
    params.setPolicyId(this.plcObj.getPolicyID());
    params.setAgentId(this.plcObj.getAgentNo());
    CmdResult<CmdListData_Result<CmdInsAgentsCommissionFind_Result>> findRes = this.cmdInsAgentsCommissionFind.Exec(this.sb.sessionInfo(), params);
    if (findRes.isOK()) {
      this.commissionFindResult = findRes.getResponse();
    } else {
      this.commissionFindResult = null;
      JsfUtil.addErrorMessage(findRes.getErrorMsg());
    }
  }

  public void postProcessAccumulation(Object document) throws UnsupportedEncodingException {
    SXSSFWorkbook workBook = (SXSSFWorkbook) document;
    SXSSFSheet sheet0 = workBook.getSheetAt(0);
    workBook.setSheetName(0, Tools.getMsg("Accumulation_Acc"));

    SXLSXTools.autoWidthColumns(sheet0, sheet0.getRow(sheet0.getLastRowNum()).getPhysicalNumberOfCells());
  }

  protected TreeNode createPfAccumulationTree() {
    TreeNode tree = new DefaultTreeNode();
    if (!Tools.isEmpty(this.plcObj.getAccumulationList()) && !Tools.isEmpty(this.plcObj.getPlcObjList())) {
      tree = new DefaultTreeNode(new AccumulationBase(), null);
      List<TreeNode> treeList = new ArrayList<>();
      Map<AccumulationBase, List<AccumulationBase>> accTempMap = new LinkedHashMap<>();
      for (Iterator<AccumulationBase> itAcc = this.plcObj.getAccumulationList().iterator(); itAcc.hasNext();) {
        AccumulationBase acc = itAcc.next();
        for (Iterator<PlcRowBase> itRow = this.plcObj.getPlcObjList().iterator(); itRow.hasNext();) {
          PlcRowBase baseRow = itRow.next();
          if (Tools.equals(acc.getObjectId(), baseRow.getID_Obj())) {
            treeList.add(new DefaultTreeNode(acc, tree));
            accTempMap.put(acc, new ArrayList<>());
            acc.setExportHeaderRowText(Tools.getMsg("Plc_ObjectData") + " " + acc.getObjectId().toString());
            acc.setCurrentPolicyObject(true);
            itAcc.remove();
          }
        }
      }
      if (!Tools.isEmpty(this.plcObj.getAccumulationList())) {
        for (Iterator<AccumulationBase> itAcc = this.plcObj.getAccumulationList().iterator(); itAcc.hasNext();) {
          AccumulationBase acc = itAcc.next();
          treeList.forEach((node) -> {
            AccumulationBase parentAcc = (AccumulationBase) node.getData();
            if (Tools.equals(acc.getAccumulationId(), parentAcc.getAccumulationId())) {
              AccumulationBase accTemp = acc.asObj();
              accTemp.setExportHeaderRowText(Tools.getMsg("Plc_ObjectData") + " " + parentAcc.getObjectId().toString());
              new DefaultTreeNode(accTemp, node);
              accTempMap.get(parentAcc).add(accTemp);
            }
          });
        }
      }
      this.plcObj.setAccumulationList(new ArrayList<>());
      accTempMap.forEach((key, value) -> {
        this.plcObj.getAccumulationList().add(key);
        if (!Tools.isEmpty(value)) {
          this.plcObj.getAccumulationList().addAll(value);
        }
      });
    }
    return tree;
  }

  public void togglePicturesPanel(ToggleEvent event) {
    if (event.getVisibility().equals(Visibility.VISIBLE)) {
      this.picturesCntrl.pictureFindList();
    }
  }

  public void plcSaveAnul(ActionEvent ae) {
    if (this.operTypeAnnul()) {
      int nModeAnnul = CmdInsPolicyPolicyDelete.MODE_ID_PLC;
      if (this.getbPlcCombined() || this.plcObj.getPlcCombType().isComplex()) {
        nModeAnnul = CmdInsPolicyPolicyDelete.MODE_ID_MAIN_PLC;
      }

      Res cmdDeletePlc = this.cmdInsPolicyPolicyDelete.plcDelete_OraIns(this.plcObj.getPolicyID(), this.sb.sessionInfo(), nModeAnnul, NomPolicyStatus.ANULIRANA_BLANKA);
      if (cmdDeletePlc.isOK()) {
        JsfUtil.addSuccessMessage(Tools.getMsg("Plc_OperAnuled", this.GetPlcText()));
        this.plcStatusAfterSave = this.utils.FindNom(NomPolicyStatus.class, NomPolicyStatus.ANULIRANA_BLANKA);
        this.plcObj.setStatus(this.plcStatusAfterSave);
        this.plcObj.setDispStatus(this.plcObj.getStatus());
        this.setViewMode(def.VIEW_MODE_VIEW);
        this.setOperType(def.OPER_TYPE_VIEW);
        this.setCancelBtnText();
      } else {
        JsfUtil.addErrorMessage(cmdDeletePlc.getErrorMsg());
      }
    } else {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
    }
  }

  public void plcSaveRecoverAnul(ActionEvent ae) {
    if (this.operTypeRecoverAnnul()) {
      Res cmdUndoAnulPlc = null;
      if (this.plcObj.getPlcCombType().isComplex()) {
        cmdUndoAnulPlc = this.cmdInsPolicyCmplxPlcUndoAnul.plcUndoAnul_OraIns(this.plcObj.getPolicyID(), this.sb.sessionInfo());
      } else {
        Res cmdAnulPlcLock = this.utils.LockSysObject(LockType.LockTypeInsPolicyPolicy, this.plcObj.getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
        if (cmdAnulPlcLock.isOK()) {
          cmdUndoAnulPlc = this.cmdPolicyDeleteUndo.plcUndoAnul_OraIns(this.plcObj.getPolicyID(), this.sb.sessionInfo());
        } else {
          JsfUtil.addErrorMessage(cmdAnulPlcLock.getErrorMsg());
        }
      }
      if (cmdUndoAnulPlc != null) {
        if (cmdUndoAnulPlc.isOK()) {
          JsfUtil.addSuccessMessage(Tools.getMsg("Plc_AnnexRecovered", this.GetPlcText()));
          this.plcStatusAfterSave = this.utils.FindNom(NomPolicyStatus.class, NomPolicyStatus.ACTIVE);
          this.plcObj.setStatus(this.plcStatusAfterSave);
          this.plcObj.setDispStatus(this.plcObj.getStatus());
          this.setViewMode(def.VIEW_MODE_VIEW);
          this.setOperType(def.OPER_TYPE_VIEW);
          this.setCancelBtnText();
        } else {
          if (!this.plcObj.getPlcCombType().isComplex()) {
            Res cmdAnulPlcUnlock = this.utils.UnLockSysObj2(def.LockTypeInsPolicyPolicy, this.plcObj.getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
            if (!cmdAnulPlcUnlock.isOK()) {
              JsfUtil.addErrorMessage(cmdAnulPlcUnlock.getErrorMsg());
            }
          }
          JsfUtil.addErrorMessage(cmdUndoAnulPlc.getErrorMsg());
        }
      }
    } else {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
    }
  }

  public void plcSaveRecover(ActionEvent ae) throws SQLException {
    if (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
      this.plcDelAnnex(ae);
    } else {
      if (this.plcSave_doBeforeSave()) {
        if (this.validatePlcAnnexes()) {
          O oldPlc = this.plcObj;
          PlcBase oldPlc2ndPlc = null;
          this.plcLoadPlcToObj(this.plcObj.getPolicyID(), this.plcObj.getComplexPlcId(), this.getPlcSecAnnexObj().getChStampOldPolicy());
          if (this.getbPlcCombined()) {
            oldPlc2ndPlc = this.get2ndPlcCntrl().getPlcObj();
            this.get2ndPlcCntrl().plcLoadPlcToObj(this.get2ndPlcCntrl().getPlcObj().getPolicyID(), 0, this.get2ndPlcCntrl().getPlcSecAnnexObj().getChStampOldPolicy());
            if (this.get2ndPlcCntrl().getPlcObj() == null) {
              this.plcObj = null;
              this.get2ndPlcCntrl().setPlcObj(oldPlc2ndPlc);
            }
          }
          if (this.plcObj != null) {
            this.fillAnnexDataOnSave(false, this.plcAnnexObj, this.plcObj, this.plcOldData);
            if (this.bFillPayTypeOnRecover()) {
              this.plcObj.setPayType(oldPlc.getPayType());
              this.plcObj.setIBAN(oldPlc.getIBAN());
            }
            if (oldPlc2ndPlc != null) {
              this.fillAnnexDataOnSave(false, this.get2ndPlcCntrl().getPlcAnnexObj(), this.get2ndPlcCntrl().getPlcObj(), this.get2ndPlcCntrl().getPlcOldData());
              if (this.bFillPayTypeOnRecover()) {
                this.get2ndPlcCntrl().getPlcObj().setPayType(oldPlc2ndPlc.getPayType());
                this.get2ndPlcCntrl().getPlcObj().setIBAN(oldPlc2ndPlc.getIBAN());
              }
            }
            this.plcSave_FillSysFlds();
            if (this.plcSave(false)) {
              JsfUtil.addSuccessMessage(Tools.getMsg("Plc_AnnexRecovered"));
              this.bAnnexNew = false;
              this.anexesList = null;
              if (oldPlc2ndPlc != null) {
                this.get2ndPlcCntrl().bAnnexNew = false;
                this.get2ndPlcCntrl().setAnexesList(null);
              }
            } else {
              this.plcObj = oldPlc;
              if (oldPlc2ndPlc != null) {
                this.get2ndPlcCntrl().setPlcObj(oldPlc2ndPlc);
              }
            }
            this.plcObj.setPlcAnnexObj(null);
            if (oldPlc2ndPlc != null) {
              this.get2ndPlcCntrl().getPlcObj().setPlcAnnexObj(null);
            }
          } else {
            this.plcObj = oldPlc;
          }
        }
      }
    }
  }

  private void fillAnnexDataOnSave(boolean bNewAnnex, PlcAnnexBase annexObj, PlcBase plc, PlcBase plcOld) {
    annexObj.setStatus("T");
//    annexObj.setAgentID(this.sb.getCurrentAgent().getAgentId());
    annexObj.setAgentID(plc.getAgentNo());
    annexObj.setPremiumOldVal(plcOld.getRV());
    annexObj.setPremiumNewVal(plc.getRV());
    this.fillAnnexPremiums(annexObj, plcOld.getRAmount(), plc.getRAmount());
    if (bNewAnnex) {
      this.setAnexData_Dozastrahovane();
    }
    plc.setPlcAnnexObj(annexObj);
  }

  protected void fillAnnexPremiums(PlcAnnexBase annexObj, BigDecimal oldRAmount, BigDecimal newRAmount) {
    annexObj.setPremiumOldAmount(oldRAmount);
    annexObj.setPremiumNewAmount(newRAmount);
  }

  protected boolean bFillPayTypeOnRecover() {
    return false;
  }

  public void plcSave_FillSysFlds() {

    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus()) {
      this.plcObj.setR_Oper(sb.getUserId());
    }
    if (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
      if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus()) {
        if (this.getbFillAgencyFromCurrentAgency()) {
          this.plcObj.setAg_No(this.sb.getCurrentAgency());
        }
        if (this.plcOldData != null) {
          this.plcObj.setOrigPlcId(this.plcOldData.getPolicyID());
        }
      }
      if (this.getEnableAgencyAgent()) {
        this.plcObj.setAgentNo(this.plcObj.getAgent().getAgentId());
      }
    }

//    this.klientCntrl.Save_FillSysFlds();
    if (this.getbFillCustPlatec() || Tools.isEmpty(this.plcObj.getCustPlatec().getCustId())) {
      this.plcObj.getCustKlient().copyTo(this.plcObj.getCustPlatec());
//      this.getPlatecCntrl().handleCustTypeChange(null);
//      this.getPlatecCntrl().LocationIdChange(null);
      //} else {
      //  this.platecCntrl.Save_FillSysFlds();
    }
    //TODO
    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus()) {
      this.plcObj.setRCmpDate(this.sb.getCurrDate());
      //this.plcObj.setTypePolica((NomInspolicyinstype) this.nomsFacade.find(this.getPlcType(), NomInspolicyinstype.class));

      //this.plcObj.setFlRenew(Tools.Bool2Str(this.operType.equals(def.OperType_ReNew)));
      //this.plcObj.setFledit(def.FlEditPlc_Yes);
    }

    // new
    if (Tools.isEmpty(this.plcObj.getPlcRow().getID_Obj())) {
      this.plcObj.getPlcRow().setRowNo(-1);
    }
    this.plcObj.setCodPolica(this.GetCodPolica());

    if (!this.app.getVerInsAllianz() && !this.app.getVerInsEZK() && !this.app.getVerInsMVIns()) {
      if (this.plcOldData != null) {
        if (!this.plcOldData.getCustKlient().getCustPin().equals(this.plcObj.getCustKlient().getCustPin())) {
          this.plcObj.getCustKlient().setCustId(0);
        }
        if (!this.plcOldData.getCustPlatec().getCustPin().equals(this.plcObj.getCustPlatec().getCustPin())) {
          this.plcObj.getCustPlatec().setCustId(0);
        }
        if (this.plcObj.getCustVPolzaNa() != null && !this.plcOldData.getCustVPolzaNa().getCustPin().equals(this.plcObj.getCustVPolzaNa().getCustPin())) {
          this.plcObj.getCustVPolzaNa().setCustId(0);
        }
        if (this.plcObj.getCustSobstvenik() != null && !this.plcOldData.getCustSobstvenik().getCustPin().equals(this.plcObj.getCustSobstvenik().getCustPin())) {
          this.plcObj.getCustSobstvenik().setCustId(0);
        }
        if (this.plcObj.getCustLizingopoluchatel() != null && !this.plcOldData.getCustLizingopoluchatel().getCustPin().equals(this.plcObj.getCustLizingopoluchatel().getCustPin())) {
          this.plcObj.getCustLizingopoluchatel().setCustId(0);
        }
        if (this.plcObj.getCustPylnomoshtnik() != null && !this.plcOldData.getCustPylnomoshtnik().getCustPin().equals(this.plcObj.getCustPylnomoshtnik().getCustPin())) {
          this.plcObj.getCustPylnomoshtnik().setCustId(0);
        }
        /*
      if (this.plcObj.getPlcRow().getMpsObj() != null && !this.plcOldData.getPlcRow().getMpsObj().getVhVin().equals(this.plcObj.getPlcRow().getMpsObj().getVhVin())) {
        this.plcObj.getPlcRow().getMpsObj().setVhId(0);
      }
         */
      }
    }
  }

  public void plcSave_FillLists(boolean bNewRowNo) {
    if (!Tools.isEmpty(this.plcObj.getPadejiMap())) {
      for (Iterator<Map.Entry<String, List<PlcPadejiBase>>> it = this.plcObj.getPadejiMap().entrySet().iterator(); it.hasNext();) {
        Map.Entry<String, List<PlcPadejiBase>> entry = it.next();
        List<PlcPadejiBase> padejiList = entry.getValue();
        //if (padejiList != null) {
        //  this.plcObj.getPadejiList().clear();
        //}
        if (padejiList != null) {
          for (PlcPadejiBase oPadej : padejiList) {
            //PlcPadejiBase pp = oPadej.asPlcPadejiBase();
            if (oPadej.getID_Padej() != null && oPadej.getID_Padej() < 0) {
              oPadej.setID_Padej(null);
            }
            //this.plcObj.addPadej(pp);
          }
        }
      }
    }

    if (this.plcObj.getStikeriList() != null) {
      for (PlcStikeriBase oStiker : (List<PlcStikeriBase>) this.plcObj.getStikeriList()) {
        if (oStiker.getStickerId() != null && oStiker.getStickerId() < 0) {
          oStiker.setStickerId(null);
        }
        if (oStiker.getSdocTypeId() != null) {
          oStiker.setSerialKey(oStiker.getSdocTypeId().getCode2());
        }
      }
    }
    if (this.getbPlcCombined()) {
      this.get2ndPlcCntrl().plcSave_FillLists(bNewRowNo);
    }
  }

  protected void fillCoversCoverType(PlcCoverBase cover, String coverType) {
    if (Tools.isEmpty(cover.getCoverId())) {
      cover.setCoverType(coverType);
    }
  }

  private boolean plcSave(boolean bNew) throws SQLException {
    boolean bRet;
    CmdInsPolicyPolicyXXXSave_Result saveResult;
    int iSave = this.checkSaveMode();
    if (iSave != def.SAVE_MODE_SECOND_POLICY) {
      if (iSave == def.SAVE_MODE_BOTH_POLICIES) {
        this.get2ndPlcCntrl().getPlcObj().getCustKlient().setCustPin(null);
        if (this.get2ndPlcCntrl().getPlcObj().getCustSobstvenik() != null) {
          this.get2ndPlcCntrl().getPlcObj().getCustSobstvenik().setCustPin(null);
        }
        if (this.get2ndPlcCntrl().getPlcObj().getCustPlatec() != null) {
          this.get2ndPlcCntrl().getPlcObj().getCustPlatec().setCustPin(null);
        }
        if (this.get2ndPlcCntrl().getPlcObj().getCustVPolzaNa() != null) {
          this.get2ndPlcCntrl().getPlcObj().getCustVPolzaNa().setCustPin(null);
        }
        if (this.get2ndPlcCntrl().getPlcObj().getCustDriver() != null) {
          this.get2ndPlcCntrl().getPlcObj().getCustDriver().setCustPin(null);
          this.get2ndPlcCntrl().getPlcObj().getCustDriver().setCustName(null);
        }
        if (this.get2ndPlcCntrl().getPlcObj().getCustAcquirer() != null) {
          this.get2ndPlcCntrl().getPlcObj().getCustAcquirer().setCustPin(null);
        }
        if (this.get2ndPlcCntrl().getPlcObj().getCustNewOwner() != null) {
          this.get2ndPlcCntrl().getPlcObj().getCustNewOwner().setCustPin(null);
        }
        if (this.get2ndPlcCntrl().getPlcObj().getCustPolzvatel() != null) {
          this.get2ndPlcCntrl().getPlcObj().getCustPolzvatel().setCustPin(null);
        }
        this.plcObj.setPlcDepCombinedPlc(new PlcDependenciesBase());
        this.plcObj.getPlcDepCombinedPlc().setPlcData(this.get2ndPlcCntrl().getPlcObj());
      }
      CmdResult<CmdInsPolicyPolicyXXXSave_Result> cmdResult = this.getSaveFacade().Exec(this.sb.sessionInfo(), this.plcObj);
      bRet = cmdResult.isOK();
      if (bRet) {
        saveResult = cmdResult.getResponse();
        this.plcSave_GetResData(saveResult);
        if (this.getbPlcCombined() && iSave == def.SAVE_MODE_MAIN_POLICY) {
          this.utils.UnLockSysObj2(def.LockTypeInsPolicyPolicy, this.get2ndPlcCntrl().getPlcObj().getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
        }
        if (!Tools.isEmpty(saveResult.getWarningsList())) {
          JsfUtil.addWarningMessages(saveResult.getWarningsList());
        }
      } else {
        if (this.app.getVerInsAsset() && this.plcType.equals(NomInsPolicyType.KASKO) && !Tools.isEmpty(cmdResult.getResultCode()) && cmdResult.getResultCode().equals(OraInsCmdAbstract.activePolicyKasko_Error)) {
          if (!Tools.skipQuestion(def.Q4, this.getSkipQuestions())) {
            JsfUtil.addQuestionBox(def.Q4, cmdResult.getErrorMsg() + " " + Tools.getMsg("Sys_AreYouSure"));
            this.setSkipQuestions(this.getSkipQuestions() + def.Q4 + "F");
          }
        } else {
          JsfUtil.addErrorMessage(cmdResult.getErrorMsg());
        }
      }
    } else {
      CmdResult<CmdInsPolicyPolicyXXXSave_Result> cmdResult2ndPlc = this.get2ndPlcCntrl().getSaveFacade().Exec(this.sb.sessionInfo(), this.get2ndPlcCntrl().getPlcObj());
      bRet = cmdResult2ndPlc.isOK();
      if (bRet) {
        CmdInsPolicyPolicyXXXSave_Result saveResult2ndPlc = cmdResult2ndPlc.getResponse();
        this.get2ndPlcCntrl().getPlcObj().setPolicyID(saveResult2ndPlc.getPlcID());
        this.get2ndPlcCntrl().getPlcObj().setBlankNo(saveResult2ndPlc.getBlankNum());
        this.get2ndPlcCntrl().getPlcObj().setCodPolica(saveResult2ndPlc.getPlcCode());
        this.get2ndPlcCntrl().getPlcObj().setStatus((NomPolicyStatus) this.nomsFacade.find(saveResult2ndPlc.getPlcStatus(), NomPolicyStatus.class));
        this.get2ndPlcCntrl().getPlcObj().setPStatus((NomPolicyOfferStatus) this.nomsFacade.find(saveResult2ndPlc.getPlcPStatus(), NomPolicyOfferStatus.class));
        this.utils.UnLockSysObj2(def.LockTypeInsPolicyPolicy, this.plcObj.getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
        if (!Tools.isEmpty(saveResult2ndPlc.getWarningsList())) {
          JsfUtil.addWarningMessages(saveResult2ndPlc.getWarningsList());
        }
      } else {
        JsfUtil.addErrorMessage(cmdResult2ndPlc.getErrorMsg());
      }
    }
    if (bRet) {
      this.setOperType(def.OPER_TYPE_VIEW);
      this.setViewMode(def.VIEW_MODE_VIEW);
      this.setCancelBtnText();
      this.picturesCntrl.init("uiTopMessage", NomPictureType.POLICY, this.plcObj.getPolicyID(), new String[]{this.plcObj.getIns_Ref(), this.plcObj.getBlankNo()});
      this.plcSave_DoAfterSuccessSave();
    }
    this.plcSave_doAfterSave();
    return bRet;
  }

  /* 1 - Записва се само основната полица (нормален запис);
   2 - Запис и за двете полици;
   3 - записва се само подчинената полица;
   4 - Записва само основната полица без да откючва подчинената (не се ползва)*/
  protected int checkSaveMode() {
    int iRet = def.SAVE_MODE_MAIN_POLICY;
    if (this.getbPlcCombined()) {
      iRet = def.SAVE_MODE_BOTH_POLICIES;
    }

    return iRet;
  }

  public void plcSave_doAfterSave() {
  }

  public void plcSave_DoAfterSuccessSave() {
  }

  protected void plcSave_GetResData(CmdInsPolicyPolicyXXXSave_Result resData) {
    this.plcObj.setPolicyID(resData.getPlcID());
    this.plcObj.setIns_Ref(resData.getPlcNum());
    this.plcObj.setBlankNo(resData.getBlankNum());
    //this.plcObj.set(resData.getAgID        ();
    //this.plcObj.set(resData.getPlcType     ();
    //this.plcObj.set(resData.getComplexPlcNo();
    this.plcObj.setMainPlcID(resData.getIdMainPlc());
    this.plcObj.setComplexPlcId(resData.getComplexPlcId());
    this.plcObj.setCodPolica(resData.getPlcCode());
    this.plcStatusAfterSave = this.nomsFacade.findNom(resData.getPlcStatus(), NomPolicyStatus.class);
    this.plcObj.setStatus(this.plcStatusAfterSave);
    this.plcObj.setPStatus((NomPolicyOfferStatus) this.nomsFacade.find(resData.getPlcPStatus(), NomPolicyOfferStatus.class));
    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || this.plcOldData == null || !Tools.equals(this.plcOldData.getStatus(), this.plcObj.getStatus())) {
      this.plcObj.setDispStatus(this.plcObj.getStatus());
    }
  }

  public void plcLoadByID() throws SQLException {
    if (!Tools.isEmpty(this.plcID)
            && (this.operType.equals(def.OPER_TYPE_EDIT)
            || this.operType.equals(def.OPER_TYPE_NEW_BY_ID)
            || this.operType.equals(def.OPER_TYPE_VIEW)
            || this.operTypeIssuePlc()
            || this.operTypeImportPersons()
            || this.operTypeEngLetterNew()
            || this.operTypeDuePremium()
            || this.operTypeAnnexDelPredl())) {

      if (this.getObjParam() != null) {
        //TODO - не е добре
        this.plcObj = (O) this.getObjParam();
        if (this.plcObj == null) {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_CurrNotFound"));
        } else {
          Integer plcId = this.plcObj.getPolicyID();
          this.setEditBtnText();
          // валидации на състоянието на полицата според операцията
          this.validatePlcSearch();
          if (this.plcObj == null) {
            this.setPlcSearchId(plcId);
          }
        }

      } else {
        switch (this.plcTypeOraIns.getNomType()) {
          case COMPLEX:
            this.plcLoadPlcToObj(0, this.plcID, 0);
            break;
          default:
            this.plcLoadPlcToObj(this.plcID, 0, 0);
            break;
        }
        if (this.plcObj == null) {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_CurrNotFound"));
        } else {
          if (this.isNewPlcByOperType()) {
            if (!validatePlcCurrencyOnRenew(this.plcObj)) {
              this.plcObj = null;
            }
          }
        }
      }

      //this.sb.setPlcObj(null);
      this.plcID = 0;

      if (this.plcObj != null) {
        boolean bCont = true;

        // търсене и валидации на подчинената полица
        if (this.plcObj.getPlcDepCombinedPlc() != null) {
          this.plcObj.setFlComb(true);
          this.set2ndPlcCntrl();
          if (this.get2ndPlcCntrl() != null) {
            this.get2ndPlcCntrl().plcLoadPlcToObj(this.plcObj.getPlcDepCombinedPlc().getPlcID(), 0, 0);
            if (this.get2ndPlcCntrl().getPlcObj() == null) {
              if (this.operTypeEdit()) {
                this.utils.UnLockSysObj2(def.LockTypeInsPolicyPolicy, this.plcObj.getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
              }
              this.plcObj = null;
              bCont = false;
            }
          }
        }
        // търсене и валидации на основната полица
        this.plcSearchAndValidateMainPlc();
        if (this.plcObj == null) {
          bCont = false;
        }

        if (bCont) {
          this.changePlcType();
          this.plcOldData = this.asPlc();
          if (this.operType.equals(def.OPER_TYPE_NEW_BY_ID)) {
            this.setOperType(def.OPER_TYPE_NEW);
            this.setCancelBtnText();
            this.plcObj.setPolicyID(0);
            //
            this.plcInitOnRenew();
            this.plcLoad_DoAfterReNew();
          }

          this.plcLoad_SetViewMode();

          this.plcLoad_doAfterLoad();
          this.plcLoad_FillDependencies();
          if (!this.getOperType().equals(def.OPER_TYPE_VIEW)) {
            this.setOtsWrPrFS();
            this.handleBlancTypeChange(null);
          }
          //обработка на втората полица
          if (this.get2ndPlcCntrl() != null) {
            if (this.plcObj.getFlComb()) {
              if (this.get2ndPlcCntrl().getPlcObj() != null) {
                this.get2ndPlcCntrl().setPlcOldData(this.get2ndPlcCntrl().getPlcObj().asPlc(true));
                if (this.operTypeNew()) {
                  this.get2ndPlcCntrl().setOperType(def.OPER_TYPE_NEW);
                }
                this.get2ndPlcCntrl().plcLoad_SetViewMode();
                this.get2ndPlcCntrl().plcLoad_doAfterLoad();
              }
            } else {
              this.get2ndPlcCntrl().getFs().SetViewMode(true, getViewMode(), "", "", this.permEditPolicy);
            }
          }
        }
      }
    }
    //JsfUtil.throwFacesMessage(this.toString() + " .plcLoadByID() - ");
  }

  public void setOtsWrPrFS() {
    //if (this.app.getVerInsAsset() || this.app.getVerInsOZK() || this.app.getVerInsOZOK()) {
    if (!this.fs.isEditWithoutPerm() && !this.operTypeIssuePlcFromPredl()) {
      this.getFs().setRAmount(!this.permDuePrem);
      //}
      this.getFs().setTax(!this.sb.HasPermission(Permissions.PLC_EDIT_TAX));
    }
    if (!this.permEditFlRenew) {
      this.getFs().setPreizdavane(true);
    }
    if (!this.sb.hasPermissionFldEdit(UsersPermissionsFld.PREDL_MOVE_MCP)) {
      this.getFs().setMcp(true);
    }
    if (!this.sb.hasPermissionFldEdit(UsersPermissionsFld.PREDL_MOVE_APTP)) {
      this.getFs().setAptp(true);
    }
  }

  public void plcPrepareNew() throws SQLException {
    this.plcObj.setStatus(new NomPolicyStatus());
    this.plcObj.setAgentNo(null);
    this.plcObj.setAgent(this.sb.getUserDefaultAgent());

    this.handleContractDateValueChange(null);
    this.SetExpiringDate(this.plcObj.getFrom_Date(), true);
    this.setOtsNadFS(null);
    this.setOtsWrPrFS();
  }

  public void plcLoad_doAfterLoad() throws SQLException {
    if (!this.getViewMode().equals(def.VIEW_MODE_VIEW) && !this.fs.isEditWithoutPerm()) {
      this.SetExpiringDate(this.plcObj.getFrom_Date(), false);
      if (this.getRenderPadejiDFZPremCol()) {
        this.handle_cbVPolzaNaDFZ_OnChange(true);
      }
      this.payType_Change(true, true);
    }
    if (!Tools.isEmpty(this.plcObj.getPadejiMap())) {
      for (Iterator<Map.Entry<String, List<PlcPadejiBase>>> it = this.plcObj.getPadejiMap().entrySet().iterator(); it.hasNext();) {
        Map.Entry<String, List<PlcPadejiBase>> entry = it.next();
        this.plcSortPadejiByID(entry.getValue());
      }
    }
    this.getFirstPadejIDs();
    this.OtsNad_doAfterLoad();
    this.PadejiCalcDFZ_doAfterLoad();
    this.fillNomVal();
    this.custContCntrl.initComm(this.plcObj.getPolicyID().toString(), CustContactsController.CallerMode.POLICY, this.operTypeViewOnLoad(), this.plcObj.getCustKlient().getCustId());
    this.custContCntrl.setActiveTabIdx(1);
    /*
    this.klientCntrl.setCustObj(this.plcObj.getCustKlient());
    this.platecCntrl.setCustObj(this.plcObj.getCustPlatec());
    this.vPolzaNaCntrl.setCustObj(this.plcObj.getCustVPolzaNa());
    if (this.sobstvenikCntrl != null) {
      this.sobstvenikCntrl.setCustObj(this.plcObj.getCustSobstvenik());
    }
    if (this.lizingopoluchatelCntrl != null) {
      this.lizingopoluchatelCntrl.setCustObj(this.plcObj.getCustLizingopoluchatel());
    }
    if (this.pylnomoshtnikCntrl != null) {
      this.pylnomoshtnikCntrl.setCustObj(this.plcObj.getCustPylnomoshtnik());
    }
     */
    //if (this.app.getVerInsAsset() || this.app.getVerInsNadejda() || this.app.getVerInsOZK() || this.app.getVerInsOZOK()) {
    if (!Tools.isEmpty(this.plcObj.getAnexesList())) {
      if (this.operTypeRecover()) {
        this.plcLoad_FillAnnexBreakData();
      } else {
        this.anexesList = this.getPlcAnnexesActive();
        if (this.app.getVerInsOZOK()) {
          this.plcObj.setAnexesList(null);
        }
      }
    }
    if (this.app.getVerInsOZK()) {
      if (this.operTypeEditIskane()) {
        this.plcObj.setReg_Date(this.sb.getCurrDate());
      }
    }
    if (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
      this.fillAgentFindRow(false);
//      if (this.hasPolicySecondAgent() && (this.operTypeSecondAgent() || this.operTypeIssuePlcFromPredl()) && this.showSecondAgentSection) {
//        if (this.plcObj.getSecondAgentData().getAgency() == null && this.plcObj.getSecondAgentData().getAgent() == null) {
//          this.plcObj.getSecondAgentData().setAgency(this.sb.getCurrentAgency());
//          if (this.operTypeSecondAgent()) {
//            this.handleSecondAgentAgencyChange(null);
//          } else {
//            this.fillSecondAgentsItems(true);
//          }
//        }
//      }
    }
    this.picturesCntrl.init("uiTopMessage", NomPictureType.POLICY, this.plcObj.getPolicyID(), new String[]{this.plcObj.getIns_Ref(), this.plcObj.getBlankNo()});
    //}
    if (this.isNewPlcByOperType() && this.plcObj.isConvertedBGNtoEUR()) {
      FacesMessage message = new FacesMessage(FacesMessage.SEVERITY_WARN, "", Tools.getMsg("Plc_PlcConvertedBGNtoEUR"));
      PrimeFaces.current().dialog().showMessageDynamic(message);
    }
  }

  protected void fillAgentFindRow(boolean fillFromAllAgents) {
    if (this.plcObj.getAgent() == null && !Tools.isEmpty(this.plcObj.getAgentNo())) {
      this.plcObj.setAgent(this.sb.getAgent(this.plcObj.getAgentNo()));
      if (this.plcObj.getAgent() == null) {
        // ако не е от тези, с които има право да работи
        if (fillFromAllAgents || !this.isNewPlcByOperType()) {
          CmdInsAgentsAgentFindRow newAgent = this.utilsIns.agentLoad(this.plcObj.getAgentNo(), null, this.sb.sessionInfo());
          this.plcObj.setAgent(newAgent);
          if (this.getPlcAgencyAgentSI() != null) {
            this.getPlcAgencyAgentSI().add(newAgent);
          }
        }
      }
      if (this.plcOldData != null && this.plcObj.getAgent() != null) {
        this.plcOldData.setAgent(this.plcObj.getAgent().asCmdInsAgentsAgentFindRow());
      }
    }
  }

  public void plcLoad_FillDependencies() {
    //if (this.plcObj.getDrivingAreaId() != null && !this.plcObj.getDrivingAreaId().getNomStatus().equals("T")) {
    //  this.nomsCntrl.FillNomDrivingArea(true);
    //}
    if (this.plcObj.getBlancType() != null && !("," + this.plcObj.getBlancType().getFlagnew() + ",").contains("," + this.getPlcType() + ",")) {
      this.FillNomFormtype(true);
    }
    /*
    this.klientCntrl.FillDependencies();
    this.vPolzaNaCntrl.FillDependencies();
    this.platecCntrl.FillDependencies();

    if (sobstvenikCntrl != null) {
      this.sobstvenikCntrl.FillDependencies();
    }
    if (pylnomoshtnikCntrl != null) {
      this.pylnomoshtnikCntrl.FillDependencies();
    }
    if (lizingopoluchatelCntrl != null) {
      this.lizingopoluchatelCntrl.FillDependencies();
    }
     */
    //this.handleDiscountExtraCalc(null);
    //this.SetExpiringDate(this.plcObj.getComencingDate(), false);
    //this.handleAmountChange(null);
    //this.handleLimitAmountChange(null);
  }

  public void doFindRegClaimsUntilAnnex(PlcAnnexBase annex, boolean showError) {

  }

  public boolean plcSave_doBeforeSave() throws SQLException {
    return (true);
  }

  public void handleCancelDateChange(AjaxBehaviorEvent event) {
  }

  public void nomCancelationreasonChange(AjaxBehaviorEvent event) {
    nomCancelationreasonChange(null, this.plcAnnexObj);
  }

  protected void nomCancelationreasonChange(String policyType, PlcAnnexBase annexBreak) {
    if (this.app.getVerInsOZK() || this.app.getVerInsOZOK()) {
      this.handleAnexRetPremCalc(policyType, annexBreak);
    } else {
      if (this.app.getVerInsAsset() || this.app.getVerInsNadejda()) {
        if (!this.plcAnnexObj.getCancelReasonId().getNomId().equals(NomCancelationreason.OTHER)) {
          this.plcAnnexObj.setCancelReasonTxt(null);
          if (this.plcAnnexObj.getCancelReasonId().getNomId().equals(NomCancelationreason.NEPLATENA_VNOSKA)) {
            annexBreak.setUsedPremiaAmount(annexBreak.getAnnexPay());
            this.annexKonsSumChange(policyType, annexBreak);
          }
        }
      }
    }
  }

  public boolean IsBlankTypeAuto(String sBlankType) {
    return (sBlankType != null && Tools.rPad(sBlankType, 4, "0").equals(NomFormtype.AUTO_COMMON));
  }

  public void StikeriRowEditListener(AjaxBehaviorEvent event) {
  }

  public void stikeriRowEditInitListener(AjaxBehaviorEvent event) {
  }

  public boolean RenderStikeriAmount(String StikeriType) {
    return true;
  }

  public boolean getShowVhAddData54() {
    return false;
  }

  public boolean getRenderStikeriEditor() {
    return this.plcObj.getStatus() == null || this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE);
  }

  public boolean RenderStikeriRowEditorColumn(String stikeriType) {
    return (this.operTypeNew() || this.operTypeReNew() || this.operTypeEditIskane());
  }

  public boolean RenderStikeriRowEditor(String stikeriType, PlcStikeriBase stiker) {
    return true;
  }

  public void StikeriDelRow(PlcStikeriBase stiker, String stType) {
    if (this.StikeriCanChange(stType, "DEL", stiker)) {
      if (stType.equals(NomSdoctype.BLANK_TYPE_STIKER)) {
        if (stiker.getStickerId() != null && stiker.getStickerId() > 0) {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_StikerErr2", Tools.getMsg("Plc_StikerL")));
        } else {
          this.plcObj.getStikeriList().remove(stiker);
        }
      } else {
        this.app.logWarning("StikeriDelRow stType NA");
      }
    }
  }

  private boolean StikeriCanChange(String stType, String operType, PlcStikeriBase currStiker) {
    return true;
  }

  public boolean RenderStikeriAddBtn(String stikeriType) {
    return (this.operTypeNew() || this.operTypeReNew() || this.operTypeEditIskane());
  }

  public void StikeriAddRow(String stType) {
    if (this.StikeriCanChange(stType, "ADD", null)) {
      if (stType.equals(NomSdoctype.BLANK_TYPE_STIKER)) {
        this.AddNewStiker(this.plcObj.getStikeriList(), stType);
      } else {
        this.app.logWarning("StikeriAddRow StikeriType NA");
      }
    }
  }

  private void AddNewStiker(List<PlcStikeriBase> ps, String stType) {
    PlcStikeriBase stiker = new PlcStikeriBase();
    stiker.setStickerVal(def.SYS_CURR);
    stiker.setStatus((NomStickerstatus) this.nomsFacade.find(NomStickerstatus.ACTIVE, NomStickerstatus.class));
    stiker.setStickerId(-(ps.size() + 1));
    if ((this.operTypeNew() || this.operTypeReNew()) && stType.equals(NomSdoctype.BLANK_TYPE_STIKER)) {
      if (this.app.getVerInsBulIns()) {
        stiker.setStickerAmount(new BigDecimal(utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "PremStiker", "0")).multiply(BigDecimal.valueOf(this.plcObj.getIn_Count())));
      }
      if (this.plcObj.getIn_Count() == 1) {
        stiker.setComencingDate(this.plcObj.getFrom_Date());
        stiker.setExpiringDate(this.plcObj.getTo_Date());
      }
    }
    if (stType.equals(NomSdoctype.BLANK_TYPE_STIKER)) {
      String stikerDefaultID = utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "StikerDefaultID", "");
      if (!Tools.isEmpty(stikerDefaultID)) {
        stiker.setSdocTypeId((NomSdoctype) this.nomsFacade.find(stikerDefaultID, NomSdoctype.class));
      }
    }
    ps.add(stiker);
  }

  public boolean disableStikeriRowEditor(String stikeriType) {
    return false;
  }

  public void annexAddIns_AddNewClaim() {
    if (this.plcAnnexObj != null) {
      this.plcAnnexObj.addToPlcAnnexClaimList(new PlcAnnexClaim());
    }
  }

  @Override
  public void handle_In_Count_Change(AjaxBehaviorEvent event) {
  }

  public void custNKIDChange(Integer custRole, boolean bAfterLoad) {
  }

  public void plcCustTypeChange(Integer custRole, boolean bAfterLoad) {
  }

  public void stikeriAmountCalculate() {
    // премия по стикер може да се въвежда само в БулИнс
    // при нов/подновяване/редакция на чернова има само активни стикери
    if (this.app.getVerInsBulIns()
            && this.plcObj.getStikeriList() != null
            && (this.operTypeNew()
            || this.operTypeReNew()
            || this.operTypeEditIskane())) {
      for (Iterator it = this.plcObj.getStikeriList().iterator(); it.hasNext();) {
        PlcStikeriBase oStiker = (PlcStikeriBase) it.next();
        oStiker.setStickerAmount(new BigDecimal(utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "PremStiker", "0")).multiply(BigDecimal.valueOf(this.plcObj.getIn_Count())));
      }
    }
  }

  protected BigDecimal getStikeriTotalAmount() {
    BigDecimal stAmount = BigDecimal.ZERO.setScale(2);
    if (this.plcObj.getStikeriList() != null) {
      for (Iterator it = this.plcObj.getStikeriList().iterator(); it.hasNext();) {
        PlcStikeriBase oStiker = (PlcStikeriBase) it.next();
        if (Tools.InList(oStiker.getStatus().getNomId(), NomStickerstatus.ACTIVE, NomStickerstatus.CANCELED)) {
          stAmount = stAmount.add(oStiker.getStickerAmount());
        }
      }
    }
    return stAmount;
  }

  protected void anexBreakCalcTaxAmount(String plcType, List<PlcPadejiBase> padejiList) {
    //#1012074
    if (operTypeAnnexBreak()) {
      if (this.plcObj.getTax()) {
        BigDecimal taxAmount = this.GetPadejiAmount(padejiList)[1];
        this.setTaxAmountOnAnnexBreak(plcType, taxAmount);
        this.setTaxWrittenSum(this.plcObj.getRAmount().add(this.plcObj.getTaxAmount()));
        this.setTotalPlcSum((this.getTaxWrittenSum()));
      }
    }
  }

  protected void setTaxAmountOnAnnexBreak(String plcType, BigDecimal taxAmount) {
    this.plcObj.setTaxAmount(taxAmount);
  }

  protected void setRAmountOnAnnexBreak(String plcType, BigDecimal rAmount) {
    this.plcObj.setRAmount(rAmount);
  }

  //
  /*
   * падежи
   */
  //
  @Override
  public void PadejiRowEditListener(RowEditEvent event) {
    String policyType = (String) event.getComponent().getAttributes().get("plcType");
    List<PlcPadejiBase> padejiList = (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(policyType);
    PlcPadejiBase padej = (PlcPadejiBase) event.getObject();
    this.PadejiTaxCalc(policyType, padejiList, padej);
    this.anexBreakCalcTaxAmount(policyType, padejiList);
  }

  public void PadejiTaxCalc(String plcType, List<PlcPadejiBase> padejiList, PlcPadejiBase oPadej) {
    if (this.plcObj.getTax() && oPadej != null && oPadej.getVid_Padej() != null && !oPadej.getVid_Padej().getNomId().equals(NomMaturitytype.GF_PREM)) {
      if (this.getRenderPadejiDFZPremCol()) {
        this.calcPadejDFZPremAmn(oPadej);
        oPadej.setTaxBaseAmnt(oPadej.getPadej_Amount().subtract(oPadej.getDFZPrem_Amnt()));
      } else {
        oPadej.setTaxBaseAmnt(oPadej.getPadej_Amount());
      }

      if (!Tools.isEmpty(oPadej.getTaxBaseAmnt()) && padejiList.size() > 1 && padejiList.indexOf(oPadej) == (padejiList.size() - 1) && !this.operTypeAnnexBreak()) {
        BigDecimal[] amn = this.GetPadejiAmount(padejiList);
        BigDecimal premiums[] = this.getPremiumsToReDistribute(plcType);
        BigDecimal plcRAmount = premiums[0];
        BigDecimal plcTaxAmount = premiums[1];
        if (amn[0].compareTo(plcRAmount) == 0) {
          oPadej.setTaxIzchislAmnt(plcTaxAmount.subtract(amn[1]).add(oPadej.getTaxIzchislAmnt()).setScale(2));
        } else {
          oPadej.setTaxIzchislAmnt(oPadej.getTaxBaseAmnt().multiply(this.getTaxPremProc()).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
        }
      } else {
        oPadej.setTaxIzchislAmnt(oPadej.getTaxBaseAmnt().multiply(this.getTaxPremProc()).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
      }
    } else {
      oPadej.setTaxBaseAmnt(BigDecimal.ZERO);
      oPadej.setTaxIzchislAmnt(BigDecimal.ZERO);
    }
  }

  @Override
  public void padejiCalcObshtPlan() {
  }

  @Override
  public void PadejiCalc(String PadejiPlcType) {
    if ((this.app.getVerInsAsset() || this.app.getVerInsNadejda() || this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) && this.operTypeAnnexBreak()) {
      this.plcObj.clearPadejiSums(PadejiPlcType);
      this.addPadejVyzstPrekr(PadejiPlcType, this.plcAnnexObj);
    } else {
      if ((this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) && this.operTypeAnnexNew()) {
        this.reDistributeOnAnnex(PadejiPlcType);
      } else {
        BigDecimal stAmn = BigDecimal.ZERO, sfAmn = BigDecimal.ZERO;
        BigDecimal premiums[] = this.getPremiumsToReDistribute(PadejiPlcType);
        BigDecimal rAmount = premiums[0];
        BigDecimal taxAmount = premiums[1];
        BigDecimal prcInDfzFavour = BigDecimal.ZERO;
        if (this.getRenderPadejiDFZPremCol()) {
          prcInDfzFavour = this.getInDFZFavourPrc().multiply(this.plcObj.getPrcDFZFavour()).divide(Tools.TEN_THOUSAND, 6, RoundingMode.HALF_UP);
        }

        this.ReDistribute(
                PadejiPlcType,
                "T",
                (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(PadejiPlcType),
                rAmount,
                this.plcObj.getRV(),
                null,
                this.getFirstPadejDate(),
                this.plcObj.getTo_Date(),
                this.plcObj.getIn_Count(),
                this.MustFillPlcPlan(PadejiPlcType),
                this.FillPlcPlan(PadejiPlcType, "T", this.plcObj.getIn_Count(), null, this.getFirstPadejDate(), this.plcObj.getTo_Date(), rAmount, this.plcObj.getRV(), taxAmount, this.plcObj.getGF(), stAmn, sfAmn, BigDecimal.ZERO.setScale(2), 0),
                false,
                this.plcObj.getTax(),
                BigDecimal.ZERO,
                prcInDfzFavour,
                this.plcObj.getGF(),
                stAmn,
                sfAmn,
                taxAmount,
                BigDecimal.ZERO.setScale(2),
                0);

        this.setFirstPadejIDs(PadejiPlcType);
      }
    }
  }

  protected BigDecimal[] getPremiumsToReDistribute(String plcType) {
    BigDecimal[] ret = {this.plcObj.getRAmount(), this.plcObj.getTaxAmount(), BigDecimal.ZERO.setScale(2)};
    if (this.plcOldData != null) {
      ret[2] = this.plcOldData.getRAmount();
    }
    return ret;
  }

  protected void addPadejVyzstPrekr(String policyType, PlcAnnexBase annexBreak) {
    if (annexBreak != null) {
      if (!Tools.isEmpty(annexBreak.getReturnPremiaAmount())) {
        this.AddNewPadej(policyType, (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(policyType), null, NomMaturitytype.VYZST_BREAK, this.plcObj.getRV(), annexBreak.getReturnPremiaAmount().negate(), NomMaturitytype.PODVID_NORMALEN, this.plcAnnexObj.getAnnexDate());
      } else {
        this.anexBreakCalcTaxAmount(policyType, (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(policyType));
      }
    }
  }

  protected void reDistributeOnAnnex(String plcType) {
    List<PlcPadejiBase> padejiList = (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(plcType);
    List<PlcPadejiBase> padejiOldList = (List<PlcPadejiBase>) this.plcOldData.getPadejiMap().get(plcType);
    padejiList.clear();
    BigDecimal premiumToRedistribute = BigDecimal.ZERO.setScale(2);
    BigDecimal padejiPaidAmount = BigDecimal.ZERO.setScale(2);
    if (Tools.isEmpty(this.getPlcAnnexObj().getAnnexPremium_Amn())) {
      BigDecimal premiums[] = this.getPremiumsToReDistribute(plcType);
      BigDecimal rAmount = premiums[0];
      BigDecimal rAmountOld = premiums[2];
      premiumToRedistribute = rAmount.subtract(rAmountOld);
    } else {
      premiumToRedistribute = this.getPlcAnnexObj().getAnnexPremium_Amn();
    }
    if (premiumToRedistribute.compareTo(BigDecimal.ZERO) == 0) {
      if (!Tools.isEmpty(padejiOldList)) {
        for (PlcPadejiBase padejOld : (List<PlcPadejiBase>) padejiOldList) {
          PlcPadejiBase plcPadej = padejOld.asPlcPadejiBase();
          if (this.plcObj.getDFZFavour()) {
            this.calcPadejDFZPremAmn(plcPadej);
          }
          this.plcObj.addPadej(plcType, plcPadej);
        }
      }
    } else {
      List<PlcPadejiBase> padejiWithPremium = new ArrayList<>();
      BigDecimal nPerSum = BigDecimal.ZERO, totalPerSum = BigDecimal.ZERO.setScale(2);
      boolean bNegativePremium = premiumToRedistribute.compareTo(BigDecimal.ZERO) == -1;
      Integer annexVnoski = 0;
      if (bNegativePremium || this.getPlcAnnexObj().getAnnexInCounts() > 1) {
        if (!Tools.isEmpty(padejiOldList)) {
          for (PlcPadejiBase padejOld : padejiOldList) {
            if ((bNegativePremium || Tools.isEmpty(padejOld.getID_Anex())) && Tools.isEmpty(padejOld.getElSmetkaID()) && Tools.isEmpty(padejOld.getNa4isl_Premia()) && Tools.isEmpty(padejOld.getVnesena_Premia())) {
              annexVnoski++;
            }
            padejiPaidAmount = padejiPaidAmount.add(padejOld.getVnesena_Premia());
          }
        }
      }
      boolean bDeferredPayment = false;
      if (!this.app.getVerInsAllianz() && !this.app.getVerInsEZK() && !this.app.getVerInsMVIns()) {
        if (bNegativePremium) {
          bDeferredPayment = annexVnoski > 0;
        } else {
          bDeferredPayment = annexVnoski > 0 && this.getPlcAnnexObj().getAnnexInCounts() > 1;
          annexVnoski++;
        }
        if (bDeferredPayment) {
          nPerSum = premiumToRedistribute.divide(new BigDecimal(annexVnoski), 2, RoundingMode.HALF_UP);
        }
      }
      if (!Tools.isEmpty(padejiOldList)) {
        for (PlcPadejiBase padejOld : padejiOldList) {
          PlcPadejiBase plcPadej = padejOld.asPlcPadejiBase();
          if (this.plcObj.getDFZFavour()) {
            this.calcPadejDFZPremAmn(plcPadej);
          }
          this.plcObj.addPadej(plcType, plcPadej);
          if (bDeferredPayment) {
            if (nPerSum.compareTo(BigDecimal.ZERO) > 0) {
              if (Tools.isEmpty(plcPadej.getID_Anex()) && Tools.isEmpty(plcPadej.getElSmetkaID()) && Tools.isEmpty(plcPadej.getNa4isl_Premia()) && Tools.isEmpty(plcPadej.getVnesena_Premia())) {
                totalPerSum = totalPerSum.add(nPerSum);
                this.AddNewPadej(plcType, padejiList, null, NomMaturitytype.NDP, this.plcObj.getRV(), nPerSum, NomMaturitytype.PODVID_NORMALEN, plcPadej.getData_Padej());
              }
            } else {
              if (Tools.isEmpty(plcPadej.getElSmetkaID()) && Tools.isEmpty(plcPadej.getNa4isl_Premia()) && Tools.isEmpty(plcPadej.getVnesena_Premia())) {
                totalPerSum = totalPerSum.add(nPerSum);
                BigDecimal nDiff = plcPadej.getPadej_Amount().add(nPerSum);
                if (nDiff.compareTo(BigDecimal.ZERO) == -1) {
                  plcPadej.setPadej_Amount(BigDecimal.ZERO.setScale(2));
                  totalPerSum = totalPerSum.subtract(nDiff);
                } else {
                  plcPadej.setPadej_Amount(nDiff);
                  padejiWithPremium.add(plcPadej);
                }
                this.PadejiTaxCalc(plcType, padejiList, plcPadej);
              }
            }
          }
        }
      }
      if (bDeferredPayment) {
        nPerSum = premiumToRedistribute.subtract(totalPerSum);
        if (totalPerSum.compareTo(BigDecimal.ZERO) > 0) {
          this.AddNewPadej(plcType, padejiList, null, NomMaturitytype.NDP, this.plcObj.getRV(), nPerSum, NomMaturitytype.PODVID_NORMALEN, this.getPlcAnnexObj().getAnnexDate());
        } else {
          if (!Tools.isEmpty(padejiWithPremium)) {
            ListIterator li = padejiWithPremium.listIterator(padejiWithPremium.size());
            while (li.hasPrevious()) {
              if (nPerSum.compareTo(BigDecimal.ZERO) != 0) {
                PlcPadejiBase oPadej = (PlcPadejiBase) li.previous();
                BigDecimal nDiff = oPadej.getPadej_Amount().add(nPerSum);
                if (nDiff.compareTo(BigDecimal.ZERO) == -1) {
                  oPadej.setPadej_Amount(BigDecimal.ZERO.setScale(2));
                  nPerSum = nDiff;
                } else {
                  oPadej.setPadej_Amount(nDiff);
                  nPerSum = BigDecimal.ZERO;
                }
                this.PadejiTaxCalc(plcType, padejiList, oPadej);
              } else {
                break;
              }
            }
          }
          if (nPerSum.compareTo(BigDecimal.ZERO) == -1) {
            this.AddNewPadej(plcType, padejiList, null, NomMaturitytype.VYZST_ANNEX, this.plcObj.getRV(), nPerSum, NomMaturitytype.PODVID_NORMALEN, this.plcAnnexObj.getAnnexDate());
          }
        }
      } else {
        if (bNegativePremium) {
          if (premiumToRedistribute.abs().compareTo(padejiPaidAmount) < 1) {
            this.AddNewPadej(plcType, padejiList, null, NomMaturitytype.VYZST_ANNEX, this.plcObj.getRV(), premiumToRedistribute, NomMaturitytype.PODVID_NORMALEN, this.plcAnnexObj.getAnnexDate());
          }
        } else {
          this.AddNewPadej(plcType, padejiList, null, NomMaturitytype.NDP, this.plcObj.getRV(), premiumToRedistribute, NomMaturitytype.PODVID_NORMALEN, this.getPlcAnnexObj().getAnnexDate());
        }
      }
      this.PadejiTaxCalc(plcType, padejiList, (PlcPadejiBase) padejiList.get(padejiList.size() - 1));
    }
  }

  protected Date getFirstPadejDate() {
    return Tools.max(this.plcObj.getFrom_Date(), this.plcObj.getReg_Date());
  }

  private void getFirstPadejIDs() {
    if (this.bGetFirstPadejIDs()) {
      this.plcOldPadejId = new HashMap<>();
      for (Iterator<Map.Entry<String, List<PlcPadejiBase>>> it = this.plcObj.getPadejiMap().entrySet().iterator(); it.hasNext();) {
        Map.Entry<String, List<PlcPadejiBase>> entry = it.next();
        if (!Tools.isEmpty(entry.getValue())) {
          PlcPadejiBase oldPadej = (PlcPadejiBase) entry.getValue().get(0);
          Integer[] padejIds = {oldPadej.getID_Padej(), oldPadej.getID_Plan()};
          this.plcOldPadejId.put(entry.getKey(), padejIds);
        }
      }
    }
  }

  protected void setFirstPadejIDs(String plcType) {
    if (this.bGetFirstPadejIDs()) {
      if (!Tools.isEmpty(this.plcOldPadejId)) {
        List<PlcPadejiBase> padejiList = (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(plcType);
        if (!Tools.isEmpty(padejiList)) {
          Integer[] padejIds = this.plcOldPadejId.get(plcType);
          if (padejIds != null) {
            PlcPadejiBase oldPadej = padejiList.get(0);
            oldPadej.setID_Padej(padejIds[0]);
            oldPadej.setID_Plan(padejIds[1]);
          }
        }
      }
    }
  }

  private boolean bGetFirstPadejIDs() {
    return ((this.operTypeEdit() && this.plcObj.getStatus() != null && !this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.CHERNOVA)) || this.operTypeIssuePlcFromPredl() || this.operTypeImportPersons() || this.operTypeDuePremium()) && !Tools.isEmpty(this.plcObj.getPadejiMap());
  }

  protected void recalcPadejiOnPlcIssue() {
    if (this.operTypeIssuePlcFromPredl()) {
      this.PadejiCalc(this.getPlcType());
    }
  }

  // този се вика само от хтмл-тата
  @Override
  public void PadejiAddRow(String plcType) {
    this.padejiAddRow(plcType, this.plcAnnexObj);
  }

  protected void padejiAddRow(String plcType, PlcAnnexBase annexBreak) {
    if ((this.app.getVerInsOZK() || this.app.getVerInsOZOK())
            && this.operTypeAnnexBreak()
            && annexBreak != null
            && !Tools.isEmpty(annexBreak.getReturnPremiaAmount())) {
      this.AddNewPadej(plcType, (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(plcType), null, NomMaturitytype.VYZST_BREAK, this.plcObj.getRV(), annexBreak.getReturnPremiaAmount().negate(), NomMaturitytype.PODVID_NORMALEN, this.plcAnnexObj.getCancelDate());
    } else {
      this.AddNewPadej(plcType, (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(plcType), null, NomMaturitytype.NDP, this.plcObj.getRV(), null, NomMaturitytype.PODVID_NORMALEN, null);
    }
  }

  protected boolean AddNewPadej(String plcType, List<PlcPadejiBase> padejiList, String basePlc, String type, String codVal, BigDecimal nAmount, int podVid, Date dDate) {
    PlcPadejiBase padej = new PlcPadejiBase();
    boolean bRet;

    padej.setPadej_ByWhat(0);
    padej.setID_Plan(0);//TODO - не е баш това
    padej.setVid_Plan(PlcPadejiBase.PLAN_TYPE_NORMAL);
    padej.setID_Padej(-(padejiList.size() + 1));
    padej.setVid_Padej((NomMaturitytype) this.nomsFacade.find(type, NomMaturitytype.class));
    padej.setPodvid_Padej(podVid);
    padej.FillPadejCodVal(codVal);
    padej.setPadej_Amount(nAmount);
    padej.setData_Padej(dDate);

    if (!Tools.isEmpty(nAmount)) {
      this.PadejiTaxCalc(plcType, padejiList, padej);
    }
    bRet = padejiList.add(padej);

    if (!Tools.isEmpty(nAmount)) {
      this.anexBreakCalcTaxAmount(plcType, padejiList);
    }
    return bRet;
  }

  @Override
  public void PadejiDelRow(String plcType, Object padej) {
    PlcPadejiBase plcPadej = (PlcPadejiBase) padej;
    boolean bDeleted = false;
    boolean bCont = true;
    if (this.getDisablePadejiDelBtn(plcPadej)) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperationNA"));
      bCont = false;
    }
    if (bCont) {
      List<PlcPadejiBase> padejiList = (List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(plcType);
      if ((this.plcObj.getStatus() != null && this.plcObj.getStatus().getNomId() != null)
              && !this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.CHERNOVA)) {
        int oldPadejCount = 0;
        for (PlcPadejiBase oPadej : padejiList) {
          if (oPadej.getID_Padej() > 0) {
            oldPadejCount++;
          }
        }
        if (oldPadejCount > 1 || (oldPadejCount == 1 && padejiList.size() > 1 && plcPadej.getID_Padej() < 0)) {
          if (plcPadej.getID_Padej() < 0 || plcPadej.getPodvid_Padej() != NomMaturitytype.PODVID_ASSISTANCE) {
            if (Tools.isEmpty(plcPadej.getVnesena_Premia()) && Tools.isEmpty(plcPadej.getNa4isl_Premia())) {
              padejiList.remove(plcPadej);
              bDeleted = true;
            } else {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_PadejDelNachPlatPrem"));
            }
          } else {
            JsfUtil.addErrorMessage(Tools.getMsg("Plc_PadejDelAssistance", Tools.getMsg("PlcKasko_Assistance")));
          }
        } else {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_PadejDeleteAll"));
        }
      } else {
        padejiList.remove(plcPadej);
        bDeleted = true;
      }
      if (bDeleted) {
        this.anexBreakCalcTaxAmount(plcType, padejiList);
      }
    }
  }

  private BigDecimal[] GetPadejiAmount(List<PlcPadejiBase> padejiList) {
    BigDecimal amn[] = {BigDecimal.ZERO, BigDecimal.ZERO};

    if (padejiList != null) {
      for (PlcPadejiBase oPadej : padejiList) {
        if (oPadej.getVid_Padej().getNomId().equals(NomMaturitytype.NDP)
                || oPadej.getVid_Padej().getNomId().equals(NomMaturitytype.VYZST_ANNEX)
                || oPadej.getVid_Padej().getNomId().equals(NomMaturitytype.VYZST_BREAK)) {
          amn[0] = amn[0].add(oPadej.getPadej_Amount());
        }
        amn[1] = amn[1].add(oPadej.getTaxIzchislAmnt());
      }
    }
    amn[0].setScale(2);
    amn[1].setScale(2);

    return (amn);
  }

  protected abstract boolean CheckPolicies_GF_OF(String typePolica, boolean lOnly_TypeCheck, boolean lSS);

  public abstract boolean MustFillPlcPlan(String plcType);

  // 1:1 cavo
  protected List<PlcPadejiBase> FillPlcPlan(String plcType, String cBasePlc, int nVnoski, Date firstPadejDate, Date dtReg_Date, Date dtTo_Date, BigDecimal wrPrem, String wrPremCurr, BigDecimal taxAmount, BigDecimal sleGF, BigDecimal sleStikerAmn, BigDecimal sleSertifAmn, BigDecimal sleAssistancePremia, int nDays) {
    List<PlcPadejiBase> aPlan = new ArrayList<>();
    int ii, nPer, nLoop;
    Date dDate = null;
    PlcPadejiBase currPadej;
    BigDecimal nCurrSum = BigDecimal.ZERO, nPerSum = BigDecimal.ZERO, nDif;

    if (this.MustFillPlcPlan(plcType)) {

      if (!Tools.isEmpty(sleAssistancePremia)) {
        if (this.AppendPadej(plcType, wrPremCurr, null, cBasePlc, "0", aPlan, NomMaturitytype.PODVID_ASSISTANCE, null)) {
          currPadej = aPlan.get(aPlan.size() - 1);
          currPadej.setData_Padej(dtReg_Date);
          currPadej.setPadej_Amount(sleAssistancePremia);
          currPadej.setPadej_CodVal(wrPremCurr);
        }
      }
      BigDecimal bd = new BigDecimal(Tools.CalcNumMonthsBettween2Dates(dtReg_Date, dtTo_Date) / nVnoski);
      nPer = bd.setScale(0, RoundingMode.DOWN).intValue();

      if (this.app.getVerInsHDI()) {
        nLoop = nVnoski - 1;
      } else {
        nLoop = nVnoski;
      }

      for (ii = 1; ii <= nLoop; ii++) {

        dDate = Tools.Add2Date(dtReg_Date, nDays, (ii - 1) * nPer, 0, false);
        //if (dDate.getDay() != dtReg_Date.getDay()) {
        //  dDate = Tools.EndOfMonth(dDate);
        //}

        if (this.app.getVerInsHDI()) {
          nPerSum = wrPrem.add(taxAmount).divide(new BigDecimal(nVnoski), 0, RoundingMode.CEILING).divide(this.getTaxPremProc().divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP).add(BigDecimal.ONE), 2, RoundingMode.HALF_UP);
        } else {
          if (this.app.getVerInsBulIns()) {
            if (plcType.equals(NomInsPolicyType.MTPL) || plcType.equals(NomInsPolicyType.KASKO)) {//TODO - да се направи по умно
              nPerSum = wrPrem.divide(new BigDecimal(nVnoski), 2, RoundingMode.HALF_UP);
            } else {
              nPerSum = wrPrem.divide(new BigDecimal(nVnoski), 0, RoundingMode.HALF_UP);
            }
          } else {
            if (this.app.getVerInsOZK() || this.app.getVerInsOZOK() || this.app.getVerInsNadejda()) {
              nPerSum = wrPrem.divide(new BigDecimal(nVnoski), 0, RoundingMode.HALF_UP);
            } else {
              nPerSum = wrPrem.divide(new BigDecimal(nVnoski), 2, RoundingMode.HALF_UP);
            }
          }
        }

        if (this.AppendPadej(plcType, wrPremCurr, null, cBasePlc, "0", aPlan, NomMaturitytype.PODVID_NORMALEN, null)) {
          currPadej = aPlan.get(aPlan.size() - 1);
          if (ii == 1 && !Tools.isEmpty(firstPadejDate)) {
            currPadej.setData_Padej(firstPadejDate);
          } else {
            currPadej.setData_Padej(dDate);
          }
          currPadej.setPadej_Amount(nPerSum);
          currPadej.setPadej_CodVal(wrPremCurr);
        }
        nCurrSum = nCurrSum.add(nPerSum);
      }

      if (this.app.getVerInsHDI()) {

        dDate = Tools.Add2Date(dtReg_Date, 0, (nVnoski - 1) * nPer, 0, false);
        //if (dDate.getDay() != dtReg_Date.getDay()) {
        //  dDate = Tools.EndOfMonth(dDate);
        //}
        nPerSum = wrPrem.subtract(nCurrSum);
        if (this.AppendPadej(plcType, wrPremCurr, null, cBasePlc, "0", aPlan, NomMaturitytype.PODVID_NORMALEN, null)) {
          currPadej = aPlan.get(aPlan.size() - 1);
          currPadej.setData_Padej(dDate);
          currPadej.setPadej_Amount(nPerSum);
          currPadej.setPadej_CodVal(wrPremCurr);
        }

      } else {

        if (this.app.getVerInsBulIns()) {
          if (plcType.equals(NomInsPolicyType.MTPL) || plcType.equals(NomInsPolicyType.KASKO)) {//TODO - да се направи по умно
            nDif = wrPrem.subtract(wrPrem.divide(new BigDecimal(nVnoski), 2, RoundingMode.HALF_UP).multiply(new BigDecimal(nVnoski)));
          } else {
            nDif = wrPrem.subtract(wrPrem.divide(new BigDecimal(nVnoski), 0, RoundingMode.HALF_UP).multiply(new BigDecimal(nVnoski)));
          }
        } else {
          if (this.app.getVerInsOZK() || this.app.getVerInsOZOK() || this.app.getVerInsNadejda() || this.app.getVerInsHDI()) {
            nDif = wrPrem.subtract(wrPrem.divide(new BigDecimal(nVnoski), 0, RoundingMode.HALF_UP).multiply(new BigDecimal(nVnoski)));
          } else {
            nDif = wrPrem.subtract(wrPrem.divide(new BigDecimal(nVnoski), 2, RoundingMode.HALF_UP).multiply(new BigDecimal(nVnoski)));
          }
        }

        if (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns() || nDif.compareTo(BigDecimal.ZERO) < 0) {
          currPadej = aPlan.get(aPlan.size() - 1);
        } else {
          currPadej = aPlan.get(!Tools.isEmpty(sleAssistancePremia) ? 1 : 0);
        }
        currPadej.setPadej_Amount(currPadej.getPadej_Amount().add(nDif));

        if (plcType.equals(NomInsPolicyType.MTPL)) {// TODO - да се направи по умно
          if (this.AppendPadej(plcType, wrPremCurr, null, cBasePlc, "0", aPlan, NomMaturitytype.PODVID_NORMALEN, null)) {
            currPadej = aPlan.get(aPlan.size() - 1);
            if (ii == 1 && !Tools.isEmpty(firstPadejDate)) {
              currPadej.setData_Padej(firstPadejDate);
            } else {
              currPadej.setData_Padej(dDate);
            }
            currPadej.setPadej_Amount(sleGF);
            currPadej.setPadej_CodVal(wrPremCurr);
          }
        }

        if (this.app.getVerInsBulIns()) {
          if (plcType.equals(NomInsPolicyType.MTPL)) {
            if (this.AppendPadej(plcType, wrPremCurr, null, cBasePlc, "0", aPlan, NomMaturitytype.PODVID_NORMALEN, null)) {
              currPadej = aPlan.get(aPlan.size() - 1);
              currPadej.setData_Padej(dDate);
              currPadej.setPadej_Amount(sleStikerAmn);
              currPadej.setPadej_CodVal(wrPremCurr);
            }
            if (this.AppendPadej(plcType, wrPremCurr, null, cBasePlc, "0", aPlan, NomMaturitytype.PODVID_NORMALEN, null)) {
              currPadej = aPlan.get(aPlan.size() - 1);
              currPadej.setData_Padej(dDate);
              currPadej.setPadej_Amount(sleSertifAmn);
              currPadej.setPadej_CodVal(wrPremCurr);
            }
          }
        }

      }

    }

    return (aPlan);
  }

  public boolean AppendPadej(String plcType, String codVal, BigDecimal nAmount, String basePlc, String type, List<PlcPadejiBase> padejiList, int podVid, Date dDate) {
    return (this.AddNewPadej(plcType, padejiList, basePlc, type, codVal, nAmount, podVid, dDate));
  }

  // 1:1 cavo
  // няма такова лайно.
  protected void ReDistribute(String typePolica, String cBasePlc, List<PlcPadejiBase> padeji, BigDecimal wrPrem, String wrPremCurr, Date firstPadejDate, Date dFrom_Date, Date dTo_Date, int nBroiVnoski, boolean lHasPadeji, List<PlcPadejiBase> aPadeji, boolean lComplex, boolean lHasTax, BigDecimal nGfAmtInPremDue, BigDecimal nPrcInDfzFavour, BigDecimal SumGF, BigDecimal SumStiker, BigDecimal SumSertifikat, BigDecimal taxAmount, BigDecimal sleAssistancePremia, Integer delayedPaymentDays) {
    int nPer, ii, jj, kk = 0, nAddVnoski = Tools.isEmpty(sleAssistancePremia) ? 0 : 1;
    BigDecimal nSumPer = BigDecimal.ZERO, nTaxProc, nTaxBase = BigDecimal.ZERO, nSumTax = BigDecimal.ZERO, nSumTaxIzchisl = BigDecimal.ZERO, nDFZPrem = BigDecimal.ZERO, nSumDFZ = BigDecimal.ZERO, nPrcDFZ_Amt = BigDecimal.ZERO;
    boolean lPerMonth, lExit = false;
    boolean lFillDulj = true, lFlag1 = true, lFlag2 = true, lFlag3 = true, lFlag4 = true, lFirs = true, lSecond = true, lThird = true;
    Date dNew;
    String cVidPdj;
    PlcPadejiBase currPadej = null, padej, oPadej;

    nTaxProc = getTaxPremProc();

    if (!lComplex) {
      padeji.clear();
    }
    if (delayedPaymentDays == null) {
      delayedPaymentDays = 0;
    }

    if (lFillDulj) {
      if (lHasPadeji) {
        // aPadeji - Дата, Валута, Премия
        for (ii = 0; ii < aPadeji.size(); ii++) {
          oPadej = aPadeji.get(ii);
          //for (PlcPadejiBase oPadej : aPadeji) {
          //  ii = aPadeji.indexOf(oPadej) + 1;
          if (CheckPolicies_GF_OF(typePolica, true, false)) {
            //if (this.app.getVerInsOZK() || this.app.getVerInsOZOK() || this.app.getVerInsNadejda() || this.app.getVerInsBulIns() || this.app.getVerInsAsset()) {
            if (lFirs) {
              if (this.AppendPadej(typePolica, oPadej.getPadej_CodVal(), null, cBasePlc, NomMaturitytype.GF_PREM, padeji, oPadej.getPodvid_Padej(), null)) {
                currPadej = padeji.get(padeji.size() - 1);
                currPadej.setData_Padej(oPadej.getData_Padej());
                ii = aPadeji.size() - 1;
                currPadej.setPadej_Amount(aPadeji.get(ii).getPadej_Amount());
                if (Tools.isEmpty(currPadej.getPadej_Amount())) {
                  padeji.remove(currPadej);
                }
                ii = -1;
              }
              lFirs = false;
            } else {
              if (this.AppendPadej(typePolica, oPadej.getPadej_CodVal(), null, cBasePlc, NomMaturitytype.NDP, padeji, oPadej.getPodvid_Padej(), null)) {
                currPadej = padeji.get(padeji.size() - 1);
                currPadej.setData_Padej(oPadej.getData_Padej());
                currPadej.setPadej_Amount(oPadej.getPadej_Amount());
                if (Tools.isEmpty(currPadej.getPadej_Amount())) {
                  padeji.remove(currPadej);
                }
              }
              if (ii == aPadeji.size() - 1 - 1) {//-1 за java-та и -1 за предпоследен
                lExit = true;
              }
            }
            /*
            } else {
              if (this.AppendPadej(oPadej.getPadej_CodVal(), null, cBasePlc, NomMaturitytype.NDP, padeji, oPadej.getPodvid_Padej(), null)) {
                currPadej = padeji.get(padeji.size() - 1);
                currPadej.setData_Padej(oPadej.getData_Padej());
                currPadej.setPadej_Amount(oPadej.getPadej_Amount());
                if (Tools.isEmpty(currPadej.getPadej_Amount())) {
                  padeji.remove(currPadej);
                }
              }
            }
             */
          } else {
            if (CheckPolicies_GF_OF(typePolica, false, true)) {
              //if (this.app.getVerInsOZK() || this.app.getVerInsOZOK() || this.app.getVerInsNadejda() || this.app.getVerInsBulIns() || this.app.getVerInsAsset()) {
              if (lFirs) {
                jj = aPadeji.size() - 1;
                padej = aPadeji.get(jj - 2);
                String padejType;
                padejType = NomMaturitytype.GF_PREM;
                if (!Tools.isEmpty(padej.getPadej_Amount()) && this.AppendPadej(typePolica, oPadej.getPadej_CodVal(), null, cBasePlc, padejType, padeji, oPadej.getPodvid_Padej(), null)) {
                  currPadej = padeji.get(padeji.size() - 1);
                  currPadej.setData_Padej(oPadej.getData_Padej());
                  ii = aPadeji.size() - 1;
                  padej = aPadeji.get(ii - 2);
                  currPadej.setPadej_Amount(padej.getPadej_Amount());
                }
                ii = -1;
                lFirs = false;
                /*
                } else {
                  if (lSecond) {
                    jj = aPadeji.size() - 1;
                    padej = aPadeji.get(jj - 1);
                    String padejType;
                    padejType = NomMaturitytype.STIKERI;
                    if (!Tools.isEmpty(padej.getPadej_Amount()) && this.AppendPadej(oPadej.getPadej_CodVal(), null, cBasePlc, padejType, padeji, oPadej.getPodvid_Padej(), null)) {
                      currPadej = padeji.get(padeji.size() - 1);
                      currPadej.setData_Padej(oPadej.getData_Padej());
                      ii = aPadeji.size() - 1;
                      padej = aPadeji.get(ii - 1);
                      currPadej.setPadej_Amount(padej.getPadej_Amount());
                      this.PadejiTaxCalc(currPadej);
                      nSumTaxIzchisl = nSumTaxIzchisl.add(currPadej.getTaxIzchislAmnt());
                    }
                    ii = -1;
                    lSecond = false;
                  } else {
                    if (lThird) {
                      jj = aPadeji.size() - 1;
                      padej = aPadeji.get(jj);
                      if (!Tools.isEmpty(padej.getPadej_Amount()) && this.AppendPadej(oPadej.getPadej_CodVal(), null, cBasePlc, NomMaturitytype.SERTIFI, padeji, oPadej.getPodvid_Padej(), null)) {
                        currPadej = padeji.get(padeji.size() - 1);
                        currPadej.setData_Padej(oPadej.getData_Padej());
                        ii = aPadeji.size() - 1;
                        padej = aPadeji.get(ii);
                        currPadej.setPadej_Amount(padej.getPadej_Amount());
                        this.PadejiTaxCalc(currPadej);
                        nSumTaxIzchisl = nSumTaxIzchisl.add(currPadej.getTaxIzchislAmnt());
                      }
                      ii = -1;
                      lThird = false;
                    } else {
                      if (!Tools.isEmpty(oPadej.getPadej_Amount()) && this.AppendPadej(oPadej.getPadej_CodVal(), null, cBasePlc, NomMaturitytype.NDP, padeji, oPadej.getPodvid_Padej(), null)) {
                        currPadej = padeji.get(padeji.size() - 1);
                        currPadej.setData_Padej(oPadej.getData_Padej());
                        currPadej.setPadej_Amount(oPadej.getPadej_Amount());
                      }
                      if (ii == aPadeji.size() - 1 - 3) {
                        lExit = true;
                      }
                    }
                  }
                }
                 */
              } else {
                if (!Tools.isEmpty(oPadej.getPadej_Amount()) && this.AppendPadej(typePolica, oPadej.getPadej_CodVal(), null, cBasePlc, NomMaturitytype.NDP, padeji, oPadej.getPodvid_Padej(), null)) {
                  currPadej = padeji.get(padeji.size() - 1);
                  currPadej.setData_Padej(oPadej.getData_Padej());
                  currPadej.setPadej_Amount(oPadej.getPadej_Amount());
                }
              }
            } else {
              if (!Tools.isEmpty(oPadej.getPadej_Amount()) && this.AppendPadej(typePolica, oPadej.getPadej_CodVal(), null, cBasePlc, NomMaturitytype.NDP, padeji, oPadej.getPodvid_Padej(), null)) {
                currPadej = padeji.get(padeji.size() - 1);
                currPadej.setData_Padej(oPadej.getData_Padej());
                currPadej.setPadej_Amount(oPadej.getPadej_Amount());
              }
            }
          }
          if (lHasTax && ii >= 0 && currPadej != null) { // Данъчна основа и дължим данък

            // nPrcInDfzFavour != 0, когата сумата за ДФЗ е част от дължимата премия
            // nGfAmtInPremDue != 0, когато сумата за ГФ е част от дъжимата премия
            nDFZPrem = Tools.round(nPrcInDfzFavour.multiply(oPadej.getPadej_Amount()), 2);
            if (nDFZPrem.compareTo(BigDecimal.ZERO) == 1) {//ако nDFZPrem е по-голямо от нула
              nSumPer = oPadej.getPadej_Amount().subtract(nDFZPrem);
              nPrcDFZ_Amt = Tools.round(nPrcInDfzFavour.multiply(oPadej.getPadej_Amount()), 2);
            } else {
              nSumPer = oPadej.getPadej_Amount().subtract(nGfAmtInPremDue.divide(new BigDecimal(nBroiVnoski + nAddVnoski), 2, RoundingMode.HALF_UP));
            }
            if ((ii + 1) < (nBroiVnoski + nAddVnoski)) {
              // за всички падежи без последния
              nSumTax = nSumTax.add(nSumPer);
              currPadej.setTaxIzchislAmnt(nSumPer.multiply(nTaxProc).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
              nSumTaxIzchisl = nSumTaxIzchisl.add(currPadej.getTaxIzchislAmnt());

              nSumDFZ = nSumDFZ.add(nPrcDFZ_Amt);
            } else {
              // за последния падеж
              if (nDFZPrem.compareTo(BigDecimal.ZERO) == 1) {
                nSumPer = wrPrem.add(sleAssistancePremia).subtract(Tools.round(nPrcInDfzFavour.multiply(wrPrem), 2)).subtract(nSumTax);
              } else {
                nSumPer = wrPrem.add(sleAssistancePremia).subtract(nGfAmtInPremDue).subtract(nSumTax);
              }
              nSumTax = nSumTax.add(nSumPer);
              //nSumTaxIzchisl - до момента разнесен по падежите дължим данък
              //currPadej.setTaxIzchislAmnt(nSumTax.multiply(nTaxProc).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP).subtract(nSumTaxIzchisl));
              currPadej.setTaxIzchislAmnt(taxAmount.subtract(nSumTaxIzchisl));
            }
            currPadej.setTaxBaseAmnt(nSumPer);
            currPadej.setTaxBaseVal(oPadej.getTaxBaseVal());
            currPadej.setTaxIzchislVal(oPadej.getTaxBaseVal());
          }
          if (lExit) {
            break;
          }
        }
      } else {
        // !lHasPadeji
        if (!Tools.isEmpty(sleAssistancePremia)) {
          if (this.AppendPadej(typePolica, wrPremCurr, null, cBasePlc, NomMaturitytype.NDP, padeji, NomMaturitytype.PODVID_ASSISTANCE, null)) {
            currPadej = padeji.get(padeji.size() - 1);
            currPadej.setData_Padej(dFrom_Date);
            currPadej.setPadej_Amount(sleAssistancePremia);
            currPadej.setPadej_CodVal(wrPremCurr);
            currPadej.setTaxBaseAmnt(sleAssistancePremia);
            currPadej.setTaxIzchislAmnt(sleAssistancePremia.multiply(nTaxProc).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
            nSumTax = nSumTax.add(currPadej.getTaxBaseAmnt());
            nSumTaxIzchisl = nSumTaxIzchisl.add(currPadej.getTaxIzchislAmnt());
          }
        }

        while (kk == 0) {
          lPerMonth = (Tools.CalcNumMonthsBettween2Dates(dFrom_Date, dTo_Date) >= nBroiVnoski);
          if (!lPerMonth) {
            nPer = Tools.round(BigDecimal.valueOf(Tools.InsPlc_NDays(dFrom_Date, dTo_Date) / nBroiVnoski), 0).intValue();
          } else {
            BigDecimal bd = new BigDecimal(Tools.CalcNumMonthsBettween2Dates(dFrom_Date, dTo_Date) / nBroiVnoski);
            nPer = bd.setScale(0, RoundingMode.DOWN).intValue();
          }
          if (!Tools.isEmpty(wrPrem)) {
            nSumPer = wrPrem.divide(new BigDecimal(nBroiVnoski), 2, RoundingMode.HALF_UP);
            nDFZPrem = Tools.round(nPrcInDfzFavour.multiply(wrPrem), 2);
            nPrcDFZ_Amt = Tools.round(nPrcInDfzFavour.multiply(nSumPer), 2);
            if (nDFZPrem.compareTo(BigDecimal.ZERO) == 1) {
              nTaxBase = nSumPer.subtract(nPrcDFZ_Amt);
            } else {
              nTaxBase = wrPrem.subtract(nGfAmtInPremDue).divide(new BigDecimal(nBroiVnoski), 2, RoundingMode.HALF_UP);
            }
          }

          for (ii = 1; ii <= nBroiVnoski; ii++) {
            if (!CheckPolicies_GF_OF(typePolica, false, false) && !CheckPolicies_GF_OF(typePolica, false, true)) {
              cVidPdj = NomMaturitytype.NDP;
            } else {
              if (CheckPolicies_GF_OF(typePolica, false, false)) {
                if (!lFlag1) {
                  cVidPdj = NomMaturitytype.GF_PREM;
                } else {
                  cVidPdj = NomMaturitytype.NDP;
                }
              } else {
                if (CheckPolicies_GF_OF(typePolica, false, true)) {
                  if (lFlag1) {
                    cVidPdj = NomMaturitytype.NDP;
                  } else {
                    if (lFlag2 && !lFlag3 && !lFlag4) {
                      cVidPdj = NomMaturitytype.GF_PREM;
                    } else {
                      if (lFlag2 && lFlag3 && !lFlag4) {
                        cVidPdj = NomMaturitytype.STIKERI;
                      } else {
                        if (lFlag2 && lFlag3 && lFlag4) {
                          cVidPdj = NomMaturitytype.SERTIFI;
                        } else {
                          cVidPdj = "";
                        }
                      }
                    }
                  }
                } else {
                  cVidPdj = "";
                }
              }
            }

            if ((lComplex)
                    || (lFlag1 && this.AppendPadej(typePolica, wrPremCurr, null, cBasePlc, cVidPdj, padeji, NomMaturitytype.PODVID_NORMALEN, null))
                    || (!lFlag1 && lFlag2 && !lFlag3 && !lFlag4 && !Tools.isEmpty(SumGF) && this.AppendPadej(typePolica, wrPremCurr, null, cBasePlc, cVidPdj, padeji, NomMaturitytype.PODVID_NORMALEN, null))
                    || (!lFlag1 && lFlag2 && lFlag3 && !lFlag4 && !Tools.isEmpty(SumStiker) && this.AppendPadej(typePolica, wrPremCurr, null, cBasePlc, cVidPdj, padeji, NomMaturitytype.PODVID_NORMALEN, null))
                    || (!lFlag1 && lFlag2 && lFlag3 && lFlag4 && !Tools.isEmpty(SumSertifikat) && this.AppendPadej(typePolica, wrPremCurr, null, cBasePlc, cVidPdj, padeji, NomMaturitytype.PODVID_NORMALEN, null))) {
              currPadej = padeji.get(padeji.size() - 1);
              if (!lPerMonth) {
                dNew = Tools.Add2Date(dFrom_Date, (ii - 1) * nPer, 0, 0, false);
              } else {
                dNew = Tools.Add2Date(dFrom_Date, delayedPaymentDays, (ii - 1) * nPer, 0, false);
              }
              if (ii == 1 && !Tools.isEmpty(firstPadejDate)) {
                dNew = firstPadejDate;
              }
              //Ina4e ako datata e razli4na ot 01.mm , naprimer 15.mm zakrugliava kum kraia na mesec
              //  if( Day( dNew )!=Day( dFrom_Date ) )
              //    dNew=EndOfMonth( dNew )
              //  endif
              //this.CArrServer:FIELDPUT( bcm2Fld( bcm_PlcPdj_Data_Padej   ), dFrom_Date+(ii-1)*nPer )
              if (!lComplex) {
                currPadej.setData_Padej(dNew);
              }
              if (ii < nBroiVnoski) {
                currPadej.setPadej_Amount(nSumPer);
                if ((cVidPdj.compareTo(NomMaturitytype.NDP) == 0 || cVidPdj.compareTo(NomMaturitytype.VYZST_ANNEX) == 0 || cVidPdj.compareTo(NomMaturitytype.VYZST_BREAK) == 0) && lHasTax) { // Данъчна основа и дължим данък
                  currPadej.setTaxBaseAmnt(nTaxBase);
                  nSumTax = nSumTax.add(nTaxBase);
                  nSumDFZ = nSumDFZ.add(nPrcDFZ_Amt);
                  currPadej.setTaxIzchislAmnt(nTaxBase.multiply(nTaxProc).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
                  currPadej.setDFZPrem_Amnt(nPrcDFZ_Amt);
                  nSumTaxIzchisl = nSumTaxIzchisl.add(currPadej.getTaxIzchislAmnt());
                }
                currPadej.setTaxBaseVal(wrPremCurr);
                currPadej.setTaxIzchislVal(wrPremCurr);
                if (CheckPolicies_GF_OF(typePolica, false, false)) {
                  if (padeji.size() == 2) {
                    currPadej.setPadej_Amount(SumGF);
                  }
                } else {
                  if (CheckPolicies_GF_OF(typePolica, false, true)) {
                    if (padeji.size() == 2) {
                      currPadej.setPadej_Amount(SumGF);
                    }
                  }
                }
              } else {
                if (lFlag1) {
                  currPadej.setPadej_Amount(wrPrem.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))));
                  if ((cVidPdj.compareTo(NomMaturitytype.NDP) == 0 || cVidPdj.compareTo(NomMaturitytype.VYZST_ANNEX) == 0 || cVidPdj.compareTo(NomMaturitytype.VYZST_BREAK) == 0) && lHasTax) { // Данъчна основа и дължим данък
                    if (nDFZPrem.compareTo(BigDecimal.ZERO) == 1) {
                      nTaxBase = Tools.round(wrPrem.multiply(BigDecimal.ONE.subtract(nPrcInDfzFavour)), 2).subtract(Tools.round(nTaxBase.multiply(new BigDecimal(nBroiVnoski - 1)), 2));
                      nPrcDFZ_Amt = wrPrem.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1)).subtract(nTaxBase));
                    } else {
                      nTaxBase = wrPrem.subtract(nGfAmtInPremDue).subtract(Tools.round(nTaxBase.multiply(new BigDecimal(nBroiVnoski - 1)), 2));
                    }
                    currPadej.setTaxBaseAmnt(nTaxBase);
                    nSumTax = nSumTax.add(nTaxBase);
                    currPadej.setTaxIzchislAmnt(nSumTax.multiply(nTaxProc).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP).subtract(nSumTaxIzchisl));
                  }
                  currPadej.setTaxBaseVal(wrPremCurr);
                  currPadej.setTaxIzchislVal(wrPremCurr);
                  currPadej.setDFZPrem_Amnt(nDFZPrem.subtract(nSumDFZ));
                  if (CheckPolicies_GF_OF(typePolica, false, false)) {
                    lFlag2 = false;
                    lFlag3 = false;
                    lFlag4 = false;
                  } else {
                    if (CheckPolicies_GF_OF(typePolica, false, true)) {
                      lFlag2 = false;
                      lFlag3 = false;
                      lFlag4 = false;
                    }
                  }
                }
                if (CheckPolicies_GF_OF(typePolica, false, false) && lFlag2) {
                  currPadej.setPadej_Amount(SumGF.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))));
                } else {
                  if (CheckPolicies_GF_OF(typePolica, false, true) && lFlag2 && !lFlag3 && !lFlag4) {
                    currPadej.setPadej_Amount(SumGF.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))));
                  } else {
                    if (CheckPolicies_GF_OF(typePolica, false, true) && lFlag2 && lFlag3 && !lFlag4) {
                      currPadej.setPadej_Amount(SumStiker.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))));
                      if ((this.app.getVerInsBulIns()) && lHasTax) {
                        currPadej.setTaxBaseAmnt(SumStiker.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))));
                        currPadej.setTaxIzchislAmnt(SumStiker.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))).multiply(nTaxProc).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
                      }
                    } else {
                      if (CheckPolicies_GF_OF(typePolica, false, true) && lFlag2 && lFlag3 && lFlag4) {
                        currPadej.setPadej_Amount(SumSertifikat.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))));
                        if ((this.app.getVerInsBulIns()) && lHasTax) {
                          currPadej.setTaxBaseAmnt(SumSertifikat.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))));
                          currPadej.setTaxIzchislAmnt(SumSertifikat.subtract(nSumPer.multiply(new BigDecimal(nBroiVnoski - 1))).multiply(nTaxProc).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
                        }
                      }
                    }
                  }
                }
              }
              if (Tools.isEmpty(currPadej.getPadej_Amount())) {
                padeji.remove(currPadej);
              }
            }
          }

          if (CheckPolicies_GF_OF(typePolica, true, false)) {
            /*if (!this.app.getVerInsOZK() && !this.app.getVerInsOZOK() && !this.app.getVerInsNadejda() && !this.app.getVerInsBulIns() && !this.app.getVerInsAsset()) {
              kk = 1;
            } else {
             */
            if (lFlag2) {
              kk = 1;
            } else {
              lFlag1 = false;
              lFlag2 = true;
            }
            //}
          } else {
            if (CheckPolicies_GF_OF(typePolica, false, true)) {
              /*if (!this.app.getVerInsOZK() && !this.app.getVerInsOZOK() && !this.app.getVerInsNadejda() && !this.app.getVerInsBulIns() && !this.app.getVerInsAsset()) {
                kk = 1;
              } else {
               */
              if (lFlag2 && lFlag3 && lFlag4) {
                kk = 1;
              } else {
                lFlag1 = false;
                if (!lFlag2) {
                  lFlag2 = true;
                } else {
                  if (!lFlag3) {
                    lFlag3 = true;
                  } else {
                    if (!lFlag4) {
                      lFlag4 = true;
                    }
                  }
                }
              }
              //}
            } else {
              kk = 1;
            }
          }
        }
      }
    }
  }

  //
  /*
   * END падежи
   */
  //
  //
  /*
   * отстъпки/надбавки
   */
  //
  protected String otsNadLevel() {
    return null;
  }

  @Override
  public void OtsNad_RowEditListener(RowEditEvent event) {
    //this.PadejiTaxCalc((PlcPadejiBase) event.getObject());
  }

  public List<PlcOtsNadBase> OtsNad_FillList(String plcTypeOraIns, String levelApply, boolean bCheckValidity) {
    List<NomInsPolicyDiscountType> nomOtsNadList = this.nomsCntrl.getNomInsPolicyDiscountTypeList();
    List<PlcOtsNadBase> plcOtsNadList = new ArrayList<>();
    PlcOtsNadBase otsNad;
    String otsNadAdded = ",";

    if (nomOtsNadList != null) {
      for (NomInsPolicyDiscountType obj : nomOtsNadList) {
        if ((levelApply == null || levelApply.equals(obj.getNomLevel()))
                && (Tools.isEmpty(obj.getNomAppliedTo()) || ("," + obj.getNomAppliedTo() + ",").contains("," + plcTypeOraIns + ","))
                && !this.OtsNad_Skip(obj, null, bCheckValidity)
                && !("," + otsNadAdded + ",").contains("," + obj.getNomId() + ",")) {// TODO - за ХДИ има дублирани отс/над "161"
          otsNad = new PlcOtsNadBase();
          otsNad.setType(obj);
          otsNad.setLevelApply((NomOtsNadLevel) this.nomsFacade.find(obj.getNomLevel(), NomOtsNadLevel.class));
          otsNad.setDimension(
                  (NomOtsNadDimension) this.nomsFacade.find(obj.getNomDimension(), NomOtsNadDimension.class));
          otsNad.FillCodVal(!Tools.isEmpty(this.plcObj.getRV()) ? this.plcObj.getRV() : def.SYS_CURR);
          otsNad.setWayToApply(
                  (NomOtsNadWayToApply) this.nomsFacade.find(NomOtsNadWayToApply.SUMARNO, NomOtsNadWayToApply.class));
          otsNad.setPokritie_ID(obj.getNomCover());
          if (otsNad.getLevelApply() != null && Tools.InList(otsNad.getLevelApply().getNomId(), NomOtsNadLevel.OBJ, NomOtsNadLevel.OBJ_COVER)) {
            if (Tools.isEmpty(this.plcObj.getPlcRow().getRowNo())) {
              otsNad.setObjNoPlc(-1);
            } else {
              otsNad.setObjNoPlc(this.plcObj.getPlcRow().getRowNo());
            }
          }

          plcOtsNadList.add(otsNad);
          otsNadAdded += obj.getNomId() + ",";
        }
      }
    }
    return (plcOtsNadList);
  }

  private void OtsNad_doAfterLoad() {
    boolean bCheckValidity = this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus();
    String policyTypeOraIns = this.plcObj.getPlcCombType().getNomId();
    //полица
    this.matchDiscExtra(null, policyTypeOraIns, bCheckValidity);
    //обекти
    if (this.plcObj.getPlcObjList() != null) {
      for (PlcRowBase row : (List<PlcRowBase>) this.plcObj.getPlcObjList()) {
        this.matchDiscExtra(row, policyTypeOraIns, bCheckValidity);
      }
    }
    //обект
    if (this.plcObj.applyDiscExtraForSingleObject() && this.plcObj.getPlcRow() != null) {
      this.matchDiscExtra(this.plcObj.getPlcRow(), policyTypeOraIns, bCheckValidity);
    }
  }

  private void matchDiscExtra(PlcRowBase row, String plcTypeOraIns, boolean bCheckValidity) {
    List<PlcOtsNadBase> dbOtsNadList;
    List<PlcOtsNadBase> tmpOtsNadList;
    boolean disableColumn = true;
    if (row == null) {
      //полица
      dbOtsNadList = this.OtsNad_FillList(plcTypeOraIns, this.otsNadLevel(), bCheckValidity);
      tmpOtsNadList = this.plcObj.getOtsNadList();
      this.plcObj.setOtsNadList(new ArrayList());
    } else {
      //обект
      dbOtsNadList = this.OtsNad_FillList(plcTypeOraIns, NomOtsNadLevel.OBJ, bCheckValidity);
      dbOtsNadList.addAll(this.OtsNad_FillList(plcTypeOraIns, NomOtsNadLevel.OBJ_COVER, bCheckValidity));
      tmpOtsNadList = row.getOtsNadList();
      row.setOtsNadList(new ArrayList());
    }
    for (PlcOtsNadBase otsNadTemplate : dbOtsNadList) {
      for (PlcOtsNadBase otsNad : tmpOtsNadList) {
        if (Tools.equals(otsNadTemplate.getType(), otsNad.getType())) {
          otsNad.CopyToObject(otsNadTemplate);
          break;
        }
      }
      if (!this.OtsNad_Skip(otsNadTemplate.getType(), otsNadTemplate, true)) {
        this.disableOtsNadRowEditor(otsNadTemplate);
        if (disableColumn) {
          disableColumn = otsNadTemplate.getDisableRowEditor();
        }
        if (row == null) {
          this.plcObj.addOtsNad(otsNadTemplate);
        } else {
          row.addOtsNad(otsNadTemplate);
        }
      }
    }
    if (disableColumn) {
      if (row == null) {
        this.fs.setOtsNad(disableColumn);
      } else {
        this.fs.getPlcRowFSC().setOtsNad(disableColumn);
      }
    }
  }

  protected void disableOtsNadRowEditor(PlcOtsNadBase otsNad) {
    switch (otsNad.getType().getNomDiscOrExtra().getNomId()) {
      case NomOtsNadType.DISCOUNT:
        otsNad.setDisableRowEditor(!this.permEditDiscounts);
        break;
      case NomOtsNadType.EXTRA:
        otsNad.setDisableRowEditor(!this.permEditExtras);
        break;
    }
  }

  protected void setOtsNadFS(PlcRowBase row) {
    List<PlcOtsNadBase> otsNadList;
    if (row == null) {
      otsNadList = this.plcObj.getOtsNadList();
    } else {
      otsNadList = row.getOtsNadList();
    }
    if (!Tools.isEmpty(otsNadList)) {
      boolean disableColumn = true;
      for (PlcOtsNadBase otsNad : otsNadList) {
        this.disableOtsNadRowEditor(otsNad);
        if (disableColumn) {
          disableColumn = otsNad.getDisableRowEditor();
        }
      }
      if (disableColumn) {
        if (row == null) {
          this.fs.setOtsNad(disableColumn);
        } else {
          this.fs.getPlcRowFSC().setOtsNad(disableColumn);
        }
      }
    }
  }

  protected void setRowOtsNadFS(PlcRowBase row) {
    if (!Tools.isEmpty(row.getOtsNadList())) {
      boolean disableColumn = true;
      for (Iterator<PlcOtsNadBase> it = row.getOtsNadList().iterator(); it.hasNext();) {
        PlcOtsNadBase otsNad = it.next();
        this.disableOtsNadRowEditor(otsNad);
        if (disableColumn) {
          disableColumn = otsNad.getDisableRowEditor();
        }
      }
      if (disableColumn) {
        this.fs.getPlcRowFSC().setOtsNad(disableColumn);
      }
    }
  }

  @Override
  public void handleOtsNadValueChange(PlcOtsNadBase otsNad) {
    otsNad.setFlEdited("T");
  }

  protected void PadejiCalcDFZ_doAfterLoad() {
    if (this.plcObj.getDFZFavour()) {
      if (!Tools.isEmpty(this.plcObj.getPadejiMap())) {
        for (Iterator<Map.Entry<String, List<PlcPadejiBase>>> itMap = this.plcObj.getPadejiMap().entrySet().iterator(); itMap.hasNext();) {
          Map.Entry<String, List<PlcPadejiBase>> entry = itMap.next();
          for (Iterator<PlcPadejiBase> itList = entry.getValue().iterator(); itList.hasNext();) {
            PlcPadejiBase currPadej = itList.next();
            this.calcPadejDFZPremAmn(currPadej);
          }
        }
      }
    }
  }

  private void calcPadejDFZPremAmn(PlcPadejiBase padej) {
    if (Tools.InList(padej.getVid_Padej(), NomMaturitytype.NDP, NomMaturitytype.VYZST_ANNEX, NomMaturitytype.VYZST_BREAK)) {
      padej.setDFZPrem_Amnt(padej.getPadej_Amount().multiply(this.plcObj.getPrcDFZFavour()).multiply(this.getInDFZFavourPrc()).divide(Tools.TEN_THOUSAND, 2, RoundingMode.HALF_UP));
    }
  }

  private PlcOtsNadBase OtsNad_GetCalcedSum(String cDiscType, List<PlcOtsNadBase> otsNadList) {
    PlcOtsNadBase ret = null;

    if (otsNadList != null) {
      for (PlcOtsNadBase currOtsNad : otsNadList) {
        if (currOtsNad.getType().getNomId().equals(cDiscType)) {
          ret = currOtsNad.asPlcOtsNadBase();
        }
      }
    }

    return (ret);
  }

  // 1:1 cavo ApplyOtsNad
  //method ApplyOtsNad( nPrem as real8, cVal as string, cCoverID:="" as string, cOTS_NAD_ALL:='ALL' as string,;
  //                  lHowToApply:=true as logic, lRecalcSums:=true as logic,;
  //                  aCalcRazprOtsNad:=nil as usual, lPosledowatelno:=false as logic ) as array strict class COtsNad_Control
  public BigDecimal[] OtsNad_ApplyOtsNad(BigDecimal nPrem, String cVal, String cCoverID, String cOTS_NAD_ALL,
          boolean lHowToApply, boolean lRecalcSums,
          List aCalcRazprOtsNad, boolean lPosledowatelno, String ActiveLevel, List<PlcOtsNadBase> otsNadList, String[] otsNadSkip, String policyType, String[] otsNadApplyLast) {
    // lHowToApply == true  от nPrem вади първо отстъпките и върху полученото число прилага надбавките
    // lHowToApply == false от nPrem вади първо отстъпките и прилага надбавките

    // lPosledowatelno == true  Изчисляването на отстъпките и надбавките да бъде последователно.
    // Пр: Застрахователна премия 1000 лв. 1000 лв -10%(отстъпка) = 900 лв. -25%(остстъпка) = 675 лв.
    // lPosledowatelno == false Изчисляването на отстъпките и надбавките да бъде сумарно
    // Пр: Застрахователна премия 1000 лв. 1000 лв - ( 10%(отстъпка)+25%(остстъпка) ) = 650 лв.
    // ако трябва да смята отс/над при анекс разпределено
    // aCalcRazprOtsNad трябва да има структурата:
    // { Старата изчислена премия преди прилагането на отс/над, Валута на старата премия,;
    //   коефицент за периода на анекса, Стара дължима премия }
    int jj, nSign;
    BigDecimal nRetPrem = nPrem;
    BigDecimal nPlcOts_AgCommiss = BigDecimal.ZERO;
    String cLevelApply;
    List<PlcOtsNadBase> otsNadApplyLastList = new ArrayList<>();
    BigDecimal[] aTmpProc = {BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO}, aTmpSum = {BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO}; // { отс, над }

    if (!Tools.isEmpty(nPrem)) {
      if (Tools.isEmpty(cCoverID)) {
        if (ActiveLevel.equals(NomOtsNadLevel.PLC)) {
          cLevelApply = NomOtsNadLevel.PLC;
        } else {
          cLevelApply = NomOtsNadLevel.OBJ;
        }
      } else {
        if (ActiveLevel.equals(NomOtsNadLevel.PLC)) {
          cLevelApply = "CP";
        } else {
          cLevelApply = "C";
        }
      }
      if (otsNadList != null) {
        for (jj = 1; jj <= 2; jj++) {
          for (PlcOtsNadBase currOtsNad : otsNadList) {
            if (otsNadSkip != null && Tools.InList(currOtsNad.getType().getNomId(), otsNadSkip)) {
              continue;
            } else {
              if (otsNadApplyLast != null) {
                boolean bFound = false;
                for (int kk = 0; kk < otsNadApplyLast.length; kk++) {
                  if (otsNadApplyLast[kk].equals(currOtsNad.getType().getNomId())) {
                    bFound = true;
                    if (jj == 2) {
                      otsNadApplyLastList.add(kk, currOtsNad);
                    }
                    break;
                  }
                }
                if (bFound) {
                  continue;
                }
              }
            }
            if (this.app.getVerInsBulIns()) {
              // Булинс - Отстъпката за сметка на агентската комисионна се прилага СЛЕД като всички останали надбавки и отстъпки са приложени.
              if (currOtsNad.getLevelApply().getNomId().equals(cLevelApply)) {
                nPlcOts_AgCommiss = currOtsNad.getValue();
              }
            } else {
              if ((jj == 1) == (currOtsNad.getType().getNomDiscOrExtra().getNomId().equals("D"))) {
                nSign = currOtsNad.getType().getNomDiscOrExtra().getNomId().equals("D") ? 1 : 2;
                if (currOtsNad.getLevelApply().getNomId().equals(cLevelApply)
                        && (Tools.isEmpty(cCoverID) || cCoverID.equals(currOtsNad.getPokritie_ID()))) {
                  if (cOTS_NAD_ALL.equals(def.OTSNAD_ALL)
                          || currOtsNad.getType().getNomDiscOrExtra().getNomId().equals(cOTS_NAD_ALL)) {
                    this.calcOtsNad(aTmpSum, aTmpProc, currOtsNad, lRecalcSums, aCalcRazprOtsNad, lPosledowatelno, nRetPrem, cVal, policyType, jj);
                  }
                }
              }
            }
          }//for
          if (!this.proportionDiscount) { //за HDI
            if (!lPosledowatelno) {
              aTmpSum[jj] = aTmpSum[jj].add(nRetPrem.multiply(aTmpProc[jj].divide(Tools.HUNDRED)).setScale(2, RoundingMode.HALF_UP));
            }
          }
          if (lHowToApply || jj == 2) {
            if (aCalcRazprOtsNad != null) {
              ;
              //aTmpSum[1] - сумата на отстъпките разпределено
              //aTmpSum[2] - сумата на надбавките разпределено
              //nPremOtsNadAn:=nPrem-nSumOtsAnex
              //aCalcRazprOtsNad[1]-=nOldSumOtsAnex
            }
            nRetPrem = nPrem.subtract(aTmpSum[1]).add(aTmpSum[2]);
          }
        }//for

        if (!Tools.isEmpty(nPlcOts_AgCommiss)) {
          // Булинс - Отстъпката за сметка на агентската комисионна се прилага СЛЕД като всички останали надбавки и отстъпки са приложени.
          nPlcOts_AgCommiss = nRetPrem.multiply(nPlcOts_AgCommiss).divide(Tools.HUNDRED).setScale(2, RoundingMode.HALF_UP);
          aTmpSum[1] = aTmpSum[1].add(nPlcOts_AgCommiss);
          nRetPrem = nRetPrem.subtract(nPlcOts_AgCommiss);
        }
        if (!Tools.isEmpty(otsNadApplyLastList)) {
          for (PlcOtsNadBase otsNad : otsNadApplyLastList) {
            jj = otsNad.getType().getNomDiscOrExtra().getNomId().equals("D") ? 1 : 2;
            BigDecimal calcedSum = this.calcOtsNad(aTmpSum, null, otsNad, lRecalcSums, aCalcRazprOtsNad, false, nRetPrem, cVal, policyType, jj);
            if (jj == 1) {
              nRetPrem = nRetPrem.subtract(calcedSum);
            } else {
              nRetPrem = nRetPrem.add(calcedSum);
            }
          }
        }
      }
    }
    BigDecimal[] ret = {nRetPrem, aTmpSum[1], aTmpSum[2]};
    return (ret);
  }

  private BigDecimal calcOtsNad(BigDecimal[] aTmpSum, BigDecimal[] aTmpProc, PlcOtsNadBase currOtsNad, boolean lRecalcSums, List aCalcRazprOtsNad, boolean lPosledowatelno, BigDecimal nRetPrem, String cVal, String policyType, int jj) {
    BigDecimal calcedSum = BigDecimal.ZERO;
    if (this.proportionDiscount) { // new за HDI
      if (lRecalcSums) {
        if (aCalcRazprOtsNad != null) {
          ;
          /*
                           * aOldSum = this.OtsNad_GetCalcedSum(currOtsNad.getType().getNomId());// self:OldOtsNad:GetCalcedSum() aOldVal =
                           * aOldSum;//self:OldOtsNad:GetValue(currOtsNad.getType()) if( currOtsNad.getDimension().getNomId().equals("%") ){ nRazprSum =
                           * Tools.GetExactSum( aOldSum.getValue(), aOldSum.getCodVal(), cVal, "FIXING", this.plcObj.getFrom_Date(), false )-; (GetExactSum(
                           * aCalcRazprOtsNad[1], aCalcRazprOtsNad[2], cVal, "FIXING", self:PlcFromDate )*aOldVal[2]/100)*aCalcRazprOtsNad[3]+;
                           * (nPremOtsNadAn*currOtsNad.getValue]/100)*aCalcRazprOtsNad[3] nOldSumOtsAnex+=GetExactSum( aCalcRazprOtsNad[1], aCalcRazprOtsNad[2],
                           * cVal, "FIXING", self:PlcFromDate )*aOldVal[2]/100 nSumOtsAnex+=nPremOtsNadAn*currOtsNad.getValue]/100 } else {
                           * nRazprSum:=GetExactSum( aOldSum.getValue(), aOldSum.getCodVal(), cVal, "FIXING", self:PlcFromDate )-; GetExactSum( aOldVal[2],
                           * aOldVal[1], cVal, "FIXING", self:PlcFromDate )*aCalcRazprOtsNad[3]+; GetExactSum( currOtsNad.getValue], currOtsNad.getCodVal],
                           * cVal, "FIXING",self:PlcFromDate)*aCalcRazprOtsNad[3] } currOtsNad.getCalcedSum():=Truncate( nRazprSum,, cVal )
                           *
           */
        } else {
          if (currOtsNad.getDimension().getNomId().equals("%")) {
            if (lPosledowatelno) {
              calcedSum = nRetPrem.subtract(aTmpSum[jj]).multiply(currOtsNad.getValue().divide(Tools.HUNDRED)).setScale(2, RoundingMode.HALF_UP);
            } else {
              calcedSum = nRetPrem.multiply(currOtsNad.getValue().divide(Tools.HUNDRED)).setScale(2, RoundingMode.HALF_UP);
            }
          } else {
            calcedSum = utils.GetExactSum(currOtsNad.getValue(), currOtsNad.getCodVal(), cVal, def.XchgRateType_Fixing, this.plcObj.getFrom_Date(), this.sb.getCurrentAgency().getUniqcode());
          }
          if (policyType == null) {
            currOtsNad.setCalcedSum(calcedSum);
          } else {
            currOtsNad.getCalcedSumMap().put(policyType, calcedSum);
          }
        }
        currOtsNad.setCalcedSumVal(cVal);
        BigDecimal currRate = this.utils.Get_Curs(cVal, def.SYS_CURR, def.XchgRateType_Fixing, this.plcObj.getFrom_Date(), this.sb.getCurrentAgency().getUniqcode());
        if (Tools.equals(cVal, def.BGN_CURR) && Tools.isInEuroZone(null)) {
          currOtsNad.setCalcedSumCurs(currRate.setScale(def.CURR_RATE_SCALE, RoundingMode.DOWN));
        } else {
          currOtsNad.setCalcedSumCurs(currRate);
        }
      }
      aTmpSum[jj] = aTmpSum[jj].add(calcedSum);
    } else {
      if (currOtsNad.getDimension().getNomId().equals("%")) {
        if (lPosledowatelno) {
          calcedSum = nRetPrem.subtract(aTmpSum[jj]).multiply(aTmpProc[jj].divide(Tools.HUNDRED)).setScale(2, RoundingMode.HALF_UP);
        } else {
          if (aTmpProc != null) {
            aTmpProc[jj] = aTmpProc[jj].add(currOtsNad.getValue());
          } else {
            calcedSum = nRetPrem.multiply(currOtsNad.getValue().divide(Tools.HUNDRED)).setScale(2, RoundingMode.HALF_UP);
          }
        }
      } else {
        calcedSum = utils.GetExactSum(currOtsNad.getValue(), currOtsNad.getCodVal(), cVal, def.XchgRateType_Fixing, this.plcObj.getFrom_Date(), this.sb.getCurrentAgency().getUniqcode());
      }
      aTmpSum[jj] = aTmpSum[jj].add(calcedSum);
    }
    return calcedSum;
  }

  public boolean OtsNad_Skip(NomInsPolicyDiscountType otsNad, PlcOtsNadBase currOtsNad, boolean bCheckValidity) {
    boolean bSkip = false;
    if (bCheckValidity) {
      Date validityDate;
      if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || Tools.isEmpty(this.plcObj.getRCmpDate())) {
        validityDate = this.sb.getCurrDate();
      } else {
        validityDate = this.plcObj.getRCmpDate();
      }
      if (!Tools.isEmpty(otsNad.getNomValidFromDate())) {
        Date validFrom = Tools.toDate(otsNad.getNomValidFromDate(), "yyyy-MM-dd");
        if (!Tools.isEmpty(validFrom) && validFrom.after(validityDate)) {
          bSkip = true;
        }
      }
      if (!bSkip && !Tools.isEmpty(otsNad.getNomValidToDate())) {
        Date validTo = Tools.toDate(otsNad.getNomValidToDate(), "yyyy-MM-dd");
        if (!Tools.isEmpty(validTo) && validTo.before(validityDate)) {
          bSkip = true;
        }
      }
      if (bSkip && currOtsNad != null && !Tools.isEmpty(currOtsNad.getValue())) {
        bSkip = false;
      }
    }
    return bSkip;
  }

  public void OtsNad_SetValue(List<PlcOtsNadBase> otsNadList, String otsNadType, BigDecimal valueToSet) {
    if (otsNadList != null) {
      for (PlcOtsNadBase currOtsNad : otsNadList) {
        if (currOtsNad.getType().getNomId().equals(otsNadType)) {
          currOtsNad.setValue(valueToSet);
          break;
        }
      }
    }
  }

  public BigDecimal OtsNad_GetValue(List<PlcOtsNadBase> otsNadList, String otsNadType) {
    PlcOtsNadBase otsNad = this.OtsNad_GetRow(otsNadList, otsNadType);
    if (otsNad != null) {
      return otsNad.getValue();
    } else {
      return BigDecimal.ZERO.setScale(2);
    }

  }

  public BigDecimal OtsNad_GetCalcedSum(List<PlcOtsNadBase> otsNadList, String otsNadType) {
    PlcOtsNadBase otsNad = this.OtsNad_GetRow(otsNadList, otsNadType);
    if (otsNad != null) {
      return otsNad.getCalcedSum();
    } else {
      return BigDecimal.ZERO.setScale(2);
    }

  }

  protected PlcOtsNadBase OtsNad_GetRow(List<PlcOtsNadBase> otsNadList, String otsNadType) {
    PlcOtsNadBase otsNad = null;
    if (otsNadList != null) {
      for (PlcOtsNadBase currOtsNad : otsNadList) {
        if (currOtsNad.getType().getNomId().equals(otsNadType)) {
          otsNad = currOtsNad;
          break;
        }
      }
    }
    return otsNad;
  }

  //
  /*
   * END отстъпки/надбавки
   */
  //
  /*
   * валидации
   */
  //
  public boolean plcValidateSave() throws SQLException {
    boolean bRet = true;

    // Общи
    if (!this.validatePlcCurrencyOnNew()) {
      bRet = false;
    }
    if (!this.plcValidateSrok()) {
      bRet = false;
    }

    if (!plcValidateCust()) {
      bRet = false;
    }

    if (this.app.getVerInsAsset() || this.app.getVerInsOZK() || this.app.getVerInsMVIns()) {
      if (!this.skipPayTypeValidation() && this.bSaveGF && this.plcObj.getPayType() == null) {
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_FinancePart") + ": " + Tools.getMsg("S001-005", Tools.getMsg("ElSmetki_PayType")));
        bRet = false;
      }
      if (this.operTypeEdit()) {
        if (!validateEditAfterXXHours(this.plcObj, utils, sb)) {
          bRet = false;
        }
      }
    }

    /*
     * if (!plcValidateCustDriver()) { bRet = false; }
     *
     *
     */
//    if (!this.klientCntrl.custSaveValidate()) {
//      bRet = false;
//    }
    if (!plcValidateAgencyAgent()) {
      bRet = false;
    }
    if (!plcValidateNumberOfInstallGreater1()) {
      bRet = false;
    }
    if (!plcValidatePadeji()) {
      bRet = false;
    }
    if (!plcValidateWrittenPremium()) {
      bRet = false;
    }

    //
    if (Tools.InList(this.operType, def.OPER_TYPE_NEW, def.OPER_TYPE_RENEW, def.OPER_TYPE_BONUS_MALUS, def.OPER_TYPE_EDIT)) {
      if (!plcValidateComencingDate()) {
        bRet = false;
      }
    }
    if (!this.validateOtsNadList(this.plcObj.getOtsNadList())) {
      bRet = false;
    }
//
//    if (!this.validateCust()) {
//      bRet = false;
//    }

    // АНЕКСИ
    if (!this.validatePlcAnnexes()) {
      bRet = false;
    }

    return bRet;
  }

  protected boolean plcValidateSrok() {
    boolean bRet = true;
    if (!plcValidateContractAfterCurrDate()) {
      bRet = false;
    }
    if (!plcValidateComencingContractDate()) {
      bRet = false;
    }
    if (!plcValidateComencingAfterContractDate()) {
      bRet = false;
    }
    if (!plcValidateExpiringAfterComencingDate()) {
      bRet = false;
    }
    if (!plcValidateExpiringDate()) {
      bRet = false;
    }
    if (!plcValidateComencingTime()) {
      bRet = false;
    }
    if (!plcValidateExpiringTime()) {
      bRet = false;
    }
    if (!plcValidateExpiringAfterComencingTime()) {
      bRet = false;
    }
    return bRet;
  }

  protected boolean plcValidateAnnexBreakTotalPaidPrem() {
    return false;
  }

  public boolean plcValidateDelAnnex(PlcAnnexBase annexToDel, Map<String, List<PlcPadejiBase>> padeji) {
    boolean bRet = true;
    if (!this.validateDelAnnexPlcPadeji(annexToDel, padeji)) {
      bRet = false;
    }
    return bRet;
  }

  private boolean validateDelAnnexPlcPadeji(PlcAnnexBase annexToDel, Map<String, List<PlcPadejiBase>> padeji) {
    boolean bRet = true;
    if (!Tools.isEmpty(padeji)) {
      List<Integer> annexIdList = new ArrayList<>();
      annexIdList.add(annexToDel.getAnnexId());
      if (!Tools.isEmpty(annexToDel.getAnnexObjMap())) {
        annexToDel.getAnnexObjMap().forEach((key, value) -> {
          if (!Tools.isEmpty(value.getAnnexId())) {
            annexIdList.add(value.getAnnexId());
          }
        });
      }
      for (Iterator<Map.Entry<String, List<PlcPadejiBase>>> it = this.plcObj.getPadejiMap().entrySet().iterator(); it.hasNext();) {
        Map.Entry<String, List<PlcPadejiBase>> entry = it.next();
        if (!Tools.isEmpty(entry.getValue())) {
          for (PlcPadejiBase padej : entry.getValue()) {
            if (annexIdList.contains(padej.getID_Anex())
                    && (!Tools.isEmpty(padej.getNa4isl_Premia()) || !Tools.isEmpty(padej.getVnesena_Premia()) || padej.getdSmDate() != null || padej.getSmetkiCount() > 0)) {
              if (this.operTypeRecover()) {
                JsfUtil.addErrorMessage(Tools.getMsg("Plc_HaveNachPlatSumVyzstPrekr", this.plcObj.getIns_Ref()));
              } else {
                JsfUtil.addErrorMessage(Tools.getMsg("Plc_HaveNachPlatSumDelAnnex"));
              }
              bRet = false;
              break;
            }
          }
        }
        if (!bRet) {
          break;
        }
      }
    }
    return bRet;
  }

  protected boolean validatePlcAnnexes() {
    boolean bRet = true;
    if (this.plcAnnexObj != null && this.plcAnnexObj.getAnnexTypeId() != null) {

      if (this.app.getVerInsAsset() || this.app.getVerInsOZK() || this.app.getVerInsMVIns()) {
        if (!this.skipPayTypeValidation() && this.plcObj.getPayType() == null && this.printElSmtkaOnAnex(true)) {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_FinancePart") + ": " + Tools.getMsg("S001-005", Tools.getMsg("ElSmetki_PayType")));
          bRet = false;
        }
      }

      if (!validateAnexNum()) {
        bRet = false;
      }

      if (!validateAnexComTime()) {
        bRet = false;
      }
      if (!validateAnexExpTime()) {
        bRet = false;
      }
      if (!validateAnexRegTime()) {
        bRet = false;
      }
      if (!validateAnexComBeforeAnexExpDate()) {
        bRet = false;
      }
      if (!validateAnexComencingDate()) {
        bRet = false;
      }
      if (!validateAnnexExpiringDate()) {
        bRet = false;
      }
      if (!validateAnexDateAfterContractDate()) {
        bRet = false;
      }
      if (this.operTypeAnnexBreak()) {
        if (!validateAnexPlcCancelDate()) {
          bRet = false;
        }
        if (!validateAnexBreak(null, this.plcAnnexObj)) {
          bRet = false;
        }
      } else {
        if (this.operTypeRecover()) {
          if (!this.validateAnexDateAfterPlcCancelDate()) {
            bRet = false;
          }
        }
      }
    }

    return bRet;
  }

  protected boolean plcValidateContractAfterCurrDate() {
    boolean bRet = true;
    if (this.plcObj.getReg_Date().after(sb.getCurrDate())) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-004"));
      bRet = false;
    }
    return bRet;
  }

  protected boolean plcValidateComencingContractDate() {
    boolean bRet = true;
    if (!this.sb.HasPermission(Permissions.permPlc_ComencingDateAfter6Months)) {
      Calendar cal = Calendar.getInstance();
      cal.setTime(this.plcObj.getReg_Date());
      cal.set(Calendar.MONTH, cal.get(Calendar.MONTH) + 6);
      if (this.plcObj.getFrom_Date().after(cal.getTime())) {
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-005"));
        bRet = false;
      }
    }
    if (!this.permChangeContractDate) {
      if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeIssuePlcFromPredl() || this.operTypeEdit()) {
        Date controlDate;
        if (this.operTypeEdit() && !this.operTypeEditIskane()) {
          controlDate = this.plcOldData.getFrom_Date();
        } else {
          controlDate = this.sb.getCurrDate();
        }
        if (this.plcObj.getFrom_Date().before(controlDate)) {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-067", Tools.DMYtoString(controlDate)));
          bRet = false;
        }
      }
    }
    return bRet;
  }

  protected boolean plcValidateComencingAfterContractDate() {
    boolean bRet = true;
    if (!this.isPolicyForOldPeriod() && this.plcObj.getFrom_Date().before(this.plcObj.getReg_Date())) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-006"));
      bRet = false;
    }
    return bRet;
  }

  protected boolean plcValidateExpiringAfterComencingDate() {
    boolean bRet = true;
    if (this.plcObj.getTo_Date().before(this.plcObj.getFrom_Date())) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-007"));
      bRet = false;
    }
    return bRet;
  }

  protected boolean plcValidateExpiringDate() {
    boolean bRet = true;
    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeEdit() || this.operTypeIssuePlcFromPredl()) {
      if (this.plcObj.getMonth() != null && !Tools.InList(this.plcObj.getMonth().getNomId(), def.NOM_NOT_SELECTED, NomPeriod.OTHER)) {
        if (this.plcObj.getFrom_Date() != null && this.plcObj.getTo_Date() != null) {
          Date calculatedExpDate = this.calcPlcExpiringDate(this.plcObj.getFrom_Date());
          if (calculatedExpDate != null && !this.plcObj.getTo_Date().equals(calculatedExpDate)) {
            JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-150"));
            bRet = false;
          }
        }
      }
    }
    return bRet;
  }

  protected boolean plcValidateComencingDate() {
    boolean bRet = true;
    String addDays = utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "CommencingDateAfterCurrDate", "");
    if (!Tools.isEmpty(addDays)) {
      Calendar cal = Calendar.getInstance();
      cal.setTime(sb.getCurrDate());
      cal.set(Calendar.DAY_OF_MONTH, cal.get(Calendar.DAY_OF_MONTH) + Integer.valueOf(addDays).intValue());
      if (this.plcObj.getFrom_Date().after(cal.getTime())) {
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-044", addDays));
        bRet = false;
      }
    }
    return bRet;
  }

  protected boolean plcValidateExpiringAfterComencingTime() {
    boolean bRet = true;
    String expTime = this.plcObj.getToTime();
    if (/*(this.app.getVerInsOZK() || this.app.getVerInsOZOK() || this.app.getVerInsNadejda() || this.app.getVerInsAsset()) &&*/!expTime.equals(def.timePlcEnd_2)) {
      GregorianCalendar expTimeCal = new GregorianCalendar();
      expTime = expTime.replace(":", "");
      int hours = Integer.parseInt(expTime.substring(0, 2));
      int minutes = Integer.parseInt(expTime.substring(2, 4));
      int seconds = Integer.parseInt(expTime.substring(4, 6));
      expTimeCal.set(Calendar.HOUR_OF_DAY, hours);
      expTimeCal.set(Calendar.MINUTE, minutes);
      expTimeCal.set(Calendar.SECOND, seconds + 1);
      expTime = Tools.HMS(expTimeCal.getTime());
    }
    if (!(plcObj.getFrom_Date().before(plcObj.getTo_Date()) || plcObj.getFromTime().compareTo(expTime) < 0)) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-009"));
      bRet = false;
    }
    return bRet;
  }

  private boolean plcValidateCust() {
    boolean bRet = true;
    if (this.plcObj.isbCheckCustInIcap()) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_SearchIcapError"));
      bRet = false;
    }
    if (Tools.isEmpty(this.plcObj.getCustKlient().getCustId())) {
      if (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_CustErr", this.getCustClientLabel()));
      } else {
        JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.component.UIInput.REQUIRED", Tools.getMsg("Plc_Customer") + ": " + Tools.getMsg("Cust_EGNBULENCH")));
      }
      bRet = false;
//    } else {
//      if (Tools.isEmpty(this.plcObj.getCustKlient().getApprMarketing())) {
//        JsfUtil.addErrorMessage(Tools.getMsg("Plc_SaveCustErr", this.plcObj.getCustKlient().getCustPin()));
//        bRet = false;
//      }
    }
    if (bRet) {
      if (!this.fs.getFsKlient().isCustPin()) {
        if (this.allowedCustKlientCustTypes != null && !Tools.InList(this.plcObj.getCustKlient().getCustTypeId(), this.allowedCustKlientCustTypes)) {
          JsfUtil.addErrorMessage(this.getCustClientLabel() + ": " + Tools.getMsg("Cust_ErrSelect5"));
          bRet = false;
        }
      }
      if (!this.plcValidateApprCustElComm()) {
        bRet = false;
      }
    }

    return bRet;
  }

  protected boolean plcValidateApprCustElComm() {
    boolean bRet = true;
    if (this.app.getVerInsAllianz()) {
      if (this.operTypeNew() || this.operTypeNewByID() || this.operTypeReNew() || this.operTypeEditIskane()) {
        if (this.plcObj.getCustKlient().getCustTypeId() != null && this.plcObj.getCustKlient().getCustTypeId().getNomId().equals(NomCusttype.CITIZEN)) {
          if (Tools.isEmpty(this.plcObj.getApprCustElComm())) {
            JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.component.UIInput.REQUIRED", this.getCustClientLabel() + ": " + Tools.getMsg("Cust_ApprElCommWithInsCust")));
            bRet = false;
          }
        }
      }
    }

    return bRet;
  }

  public String getCustClientLabel() {
    return Tools.getMsg("Plc_Zastrahovan");
  }

  private boolean plcValidateComencingTimeAfterCurrDate() {
    boolean bRet = true;
    if (this.plcObj.getReg_Date().equals(this.plcObj.getFrom_Date())) {
      String addMinutes = utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "CommencingTimeAfterCurrDate", "");
      if (!Tools.isEmpty(addMinutes)) {
        GregorianCalendar comTimeCal = new GregorianCalendar();
        comTimeCal.set(GregorianCalendar.MINUTE, comTimeCal.get(GregorianCalendar.MINUTE) + Integer.valueOf(addMinutes).intValue());
        if (this.plcObj.getFromTime().compareTo(Tools.HMS(comTimeCal.getTime())) < 0) {
          comTimeCal.set(GregorianCalendar.MINUTE, comTimeCal.get(GregorianCalendar.MINUTE) - Integer.valueOf(addMinutes).intValue());
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-045", "(" + Tools.HMS(comTimeCal.getTime()) + ")"));
          bRet = false;
        }
      }
    }
    return bRet;
  }

  protected boolean plcValidateComencingTime() {
    boolean bRet = true;
    if (!Tools.correctTime(this.plcObj.getFromTime())) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-008", Tools.getMsg("Plc_ComencingDate")));
      bRet = false;
    }
    if (bRet) {
      if (this.plcObj.getReg_Date().equals(this.plcObj.getFrom_Date())) {
        if (!this.permChangeContractDate) {
          if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeIssuePlcFromPredl() || this.operTypeEdit()) {
            Date comDate = Tools.AddHMStoDate(new GregorianCalendar(), this.plcObj.getFromTime(), 0, 0, 0);
            Date controlDate;
            if (this.operTypeEdit() && !this.operTypeEditIskane()) {
              controlDate = Tools.AddHMStoDate(new GregorianCalendar(), this.plcOldData.getFromTime(), 0, 0, 0);
            } else {
              GregorianCalendar valDate = new GregorianCalendar();
              valDate.set(GregorianCalendar.HOUR_OF_DAY, valDate.get(GregorianCalendar.HOUR_OF_DAY) + 1);
              valDate.set(GregorianCalendar.MINUTE, 0);
              valDate.set(GregorianCalendar.SECOND, 0);
              controlDate = valDate.getTime();
            }
            if (comDate.before(controlDate)) {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-064", Tools.HMS(controlDate)));
              bRet = false;
            }
          }
        }
      }
    }
    return bRet;
  }

  protected boolean plcValidateExpiringTime() {
    boolean bRet = true;
    if (!Tools.correctTime(this.plcObj.getToTime())) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-008", Tools.getMsg("Plc_ExpiringDate")));
      bRet = false;
    }
    return bRet;
  }

  protected boolean plcValidateAgencyAgent() throws NumberFormatException {
    boolean bRet = true;
//    if (this.getEnableAgencyAgent()) {
//      if (this.plcObj.getAgent() == null) {
//        JsfUtil.addErrorMessage(Tools.getMsg("Plc_UserRightsErrorAgent2"));
//      }
//      if (Tools.isEmpty(this.AgencyIDAgentID)) {
//        JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.component.UIInput.REQUIRED", Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("Plc_AgencyID") + "/" + Tools.getMsg("Plc_AgentID")));
//      } else {
//        int idx = this.AgencyIDAgentID.indexOf(",");
//        if (idx > 0) {
//          String agency = this.AgencyIDAgentID.substring(0, idx);
//          int agent = Integer.parseInt(this.AgencyIDAgentID.substring(idx + 1));
//          if ((!this.app.getVerInsAsset() && !this.app.getVerInsAllianz() && (!(this.app.getVerInsOZK() || this.app.getVerInsOZOK()) || !this.operTypeEditIskane())) && (!agency.equals(this.sb.getCurrentAgency().getNomId()) || agent != this.sb.getCurrentAgent().getAgentId())) {
//            JsfUtil.addErrorMessage(Tools.getMsg("P001-010"));
//          } else {
//            this.plcObj.setAg_No((NomAgencies) this.nomsFacade.find(agency, NomAgencies.class));
//            this.plcObj.setAgentNo(agent);
//            bRet = true;
//          }
//        } else {
//          JsfUtil.addErrorMessage(Tools.getMsg("P001-010"));
//        }
//      }
//    } else {
//      if (Tools.isEmpty(this.plcObj.getAgentNo()) || this.plcObj.getAg_No() == null) {
//        JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.component.UIInput.REQUIRED", Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("Plc_AgencyID") + "/" + Tools.getMsg("Plc_AgentID")));
//      } else {
//        bRet = true;
//      }
//    }
    return bRet;
  }

  private boolean plcValidateNumberOfInstallGreater1() {
    boolean bRet = true;
//    if (this.isNewPlcByOperType() || this.operTypeEdit()) {
//      if (Tools.InList(this.plcTypeOraIns, NomInsComplexPolicyType.INDIVIDUAL_SOLUTION_COMPANY, NomInsComplexPolicyType.INDUSTRIAL_SOLUTION)
//              && this.isShortPeriodPolicy() && this.plcObj.getIn_Count() > 1) {
//        JsfUtil.addErrorMessage(Tools.getMsg("Plc_PolicyData") + ": " + Tools.getMsg("P001-022"));
//        bRet = false;
//      }
//    }
    return bRet;
  }

  protected boolean isShortPeriodPolicy() {
    boolean bRet = false;
    if (!Tools.isEmpty(this.plcObj.getFrom_Date()) && !Tools.isEmpty(this.plcObj.getTo_Date())) {
      boolean bLimitValueIsNewMonth = !Tools.incompleteTime(this.plcObj.getFromTime()) && this.plcObj.getFromTime().compareTo(this.plcObj.getToTime()) < 0;
      int months = Tools.monthsBetween(this.plcObj.getFrom_Date(), this.plcObj.getTo_Date(), bLimitValueIsNewMonth);
      bRet = months < 12;
    }
    return bRet;
  }
//  protected boolean plcValidateAzisic(NomInsPolicyAZISIC azisic, String msgId, String azisicHeader) {
//    boolean bRet = true;
//    if (this.isNewPlcByOperType() && !Tools.isEmpty(azisic) && !Tools.Str2Bool(azisic.getNomStatus())) {
//      JsfUtil.addErrorMessage(Tools.getMsg("AZISIC_InvalidValue", azisic.getAzisicCode(), (azisicHeader + ": " + Tools.getMsg("AZISIC_Code")), Tools.DMYtoString(azisic.getValidDate())));
//      bRet = false;
//    }
//    if (bRet) {
//      if (this.operTypeNew() || this.operTypeReNew() || this.operTypeEdit()) {
//        if (!this.sb.HasPermission(Permissions.PLC_SKIP_AZISIC_REQUIRED_FIELDS)) {
//          if (Tools.isEmpty(azisic)) {
//            JsfUtil.addErrorMessage(msgId, Tools.getMsg("S001-005", azisicHeader + ": " + Tools.getMsg("AZISIC_Code")));
//            bRet = false;
//          } else {
//            if (Tools.isEmpty(azisic.getNomName())) {
//              JsfUtil.addErrorMessage(msgId, Tools.getMsg("S001-005", azisicHeader + ": " + Tools.getMsg("AZISIC_Name")));
//              bRet = false;
//            }
//            if (Tools.isEmpty(azisic.getNomNameEN())) {
//              JsfUtil.addErrorMessage(msgId, Tools.getMsg("S001-005", azisicHeader + ": " + Tools.getMsg("AZISIC_NameEn")));
//              bRet = false;
//            }
//            if (Tools.isEmpty(azisic.getRiskFire())) {
//              JsfUtil.addErrorMessage(msgId, Tools.getMsg("S001-005", azisicHeader + ": " + Tools.getMsg("AZISIC_RiskFire")));
//              bRet = false;
//            }
//          }
//        }
//        if (bRet) {
//          if (!this.plcValidateAzisicAddValidations(azisic, msgId)) {
//            bRet = false;
//          }
//        }
//      }
//    }
//    return bRet;
//  }
//  protected boolean plcValidateAzisicAddValidations(NomInsPolicyAZISIC azisic, String msgId) {
//    return true;
//  }
//  public List<NomInsPolicyAZISIC> findAzisicForAutoComplete(String query) {
//    FacesContext context = FacesContext.getCurrentInstance();
//    boolean emptyNaceCode = Tools.Str2Bool((String) UIComponent.getCurrentComponent(context).getAttributes().get("emptyNaceCode"));
//    String specificAzCodes = (String) UIComponent.getCurrentComponent(context).getAttributes().get("specificAzCodes");
//    String specificCodesCmp = Tools.isEmpty(specificAzCodes) ? null : NomInsPolicyAZISIC.AZISIC_CODES_DELIMITER.concat(specificAzCodes).concat(NomInsPolicyAZISIC.AZISIC_CODES_DELIMITER);
//    this.fillAzisicNomList();
//    List<String> nomIdList = new ArrayList<>();
//    if (!Tools.isEmpty(this.azisicNomList)) {
//      this.azisicNomList.forEach(nom -> {
//        if (Tools.isEmpty(specificCodesCmp)) {
//          if ((emptyNaceCode || !Tools.isEmpty(nom.getNaceCode())) && (nom.getAzisicCode().startsWith(query) || nom.getNomName().contains(query) || nom.getNomNameEN().contains(query))) {
//            nomIdList.add(nom.getNomId());
//          }
//        } else {
//          if (specificCodesCmp.contains(NomInsPolicyAZISIC.AZISIC_CODES_DELIMITER.concat(nom.getAzisicCode()).concat(NomInsPolicyAZISIC.AZISIC_CODES_DELIMITER))) {
//            nomIdList.add(nom.getNomId());
//          }
//        }
//      });
//    }
//    List<NomInsPolicyAZISIC> azList = new ArrayList<>();
//    if (!Tools.isEmpty(nomIdList)) {
//      azList = this.nomsFacade.findAllByIDs(NomInsPolicyAZISIC.class, nomIdList);
//    }
//    return azList;
//  }
//
//  protected NomInsPolicyAZISIC findAzisicByNaceCode(String naceCode) {
//    NomInsPolicyAZISIC retAzisic = null;
//    if (!Tools.isEmpty(naceCode)) {
//      this.fillAzisicNomList();
//      if (!Tools.isEmpty(this.azisicNomList)) {
//        for (CmdAZISICNomRow nom : this.azisicNomList) {
//          if (Tools.equals(nom.getNaceCode(), naceCode)) {
//            retAzisic = this.nomsFacade.findNom(nom.getNomId(), NomInsPolicyAZISIC.class);
//            break;
//          }
//        }
//      }
//    }
//    return retAzisic;
//  }
//
//  protected List<NomInsPolicyAZISIC> findAzisicByAzisicCodeList(String azisicCode) {
//    List<NomInsPolicyAZISIC> azisicList = null;
//    if (!Tools.isEmpty(azisicCode)) {
//      this.fillAzisicNomList();
//      if (!Tools.isEmpty(this.azisicNomList)) {
//        azisicList = new ArrayList<>();
//        for (CmdAZISICNomRow nom : this.azisicNomList) {
//          if (Tools.equals(nom.getAzisicCode(), azisicCode)) {
//            NomInsPolicyAZISIC azisic = this.nomsFacade.findNom(nom.getNomId(), NomInsPolicyAZISIC.class);
//            if (azisic != null) {
//              azisicList.add(azisic);
//            }
//          }
//        }
//      }
//    }
//    return azisicList;
//  }
//
//  private void fillAzisicNomList() {
//    CmdAZISICNomGet2Date_Params params = new CmdAZISICNomGet2Date_Params();
//    if (Tools.isEmpty(this.plcObj.getReg_Date())) {
//      params.setPlcContractDate(this.sb.getCurrDate());
//    } else {
//      params.setPlcContractDate(this.plcObj.getReg_Date());
//    }
//    if (this.lastAzisicParams == null || !Tools.equals(this.lastAzisicParams.getPlcContractDate(), params.getPlcContractDate())) {
//      CmdResult<CmdListData_Result<CmdAZISICNomRow>> res = this.cmdAZISICNomGet2Date.Exec(this.sb.sessionInfo(), params);
//      if (res.isOK()) {
//        this.azisicNomList = res.getResponse().getResultList();
//        this.lastAzisicParams = params;
//      } else {
//        this.azisicNomList = null;
//        FacesMessage message = new FacesMessage(FacesMessage.SEVERITY_ERROR, "", res.getErrorMsg());
//        PrimeFaces.current().dialog().showMessageDynamic(message);
//      }
//    }
//  }

  protected boolean validateCommReduction() {
    boolean bRet = true;
    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeEdit()) {
      if (this.plcObj.isFlCommReduction()) {
        boolean bValRequired = true;
        if (this.isMinPremCommReduction()) {
          JsfUtil.addErrorMessage(Tools.getMsg("P001-162"));
          bRet = false;
          bValRequired = false;
        }
        if (this.OtsNad_GetValue(this.plcObj.getOtsNadList(), NomInsPolicyDiscountType.SLUJITELI).compareTo(BigDecimal.ZERO) != 0) {
          JsfUtil.addErrorMessage(Tools.getMsg("P001-163"));
          bRet = false;
          bValRequired = false;
        }
        if (this.operTypeNew() || this.operTypeReNew() || this.operTypeEditIskane()) {
          if (Tools.nvl(this.agentCommission, BigDecimal.ZERO).compareTo(BigDecimal.ZERO) < 1) {
            JsfUtil.addErrorMessage(Tools.getMsg("P001-164"));
            bRet = false;
            bValRequired = false;
          }
        }
        if (bValRequired) {
          if (!JsfUtil.validateRequiredFields(new Pair(Tools.getMsg("Plc_AgentCommReduction") + ": " + Tools.getMsg("Plc_CommReductionPercent"), this.plcObj.getCommReductPercent()))) {
            bRet = false;
          } else {
            if (this.plcObj.getCommReductPercent().compareTo(Tools.HUNDRED) == 1) {
              JsfUtil.addErrorMessage(Tools.getMsg("P001-136", Tools.getMsg("Plc_AgentCommReduction") + ": " + Tools.getMsg("Plc_CommReductionPercent"), Tools.HUNDRED.setScale(2).toString()));
              bRet = false;
            }
          }
        }
      }
    }
    return bRet;
  }

  protected boolean isMinPremCommReduction() {
    return false;
  }

  protected boolean plcValidatePadeji() {
    boolean bRet = true;
    for (Iterator<Map.Entry<String, List<PlcPadejiBase>>> it = this.plcObj.getPadejiMap().entrySet().iterator(); it.hasNext();) {
      Map.Entry<String, List<PlcPadejiBase>> entry = it.next();
      List<PlcPadejiBase> padejiList = entry.getValue();
      String policyType = entry.getKey();
      BigDecimal padejSum = BigDecimal.ZERO.setScale(2);
      BigDecimal gfPremPadejSum = BigDecimal.ZERO.setScale(2);
      BigDecimal padejiTaxAmount = BigDecimal.ZERO.setScale(2);
      BigDecimal assistancePadejiSum = BigDecimal.ZERO.setScale(2);
      BigDecimal padejiPaidAmount = BigDecimal.ZERO.setScale(2);
      BigDecimal padejiRecoveryAmount = BigDecimal.ZERO.setScale(2);
      int assistancePadejiCount = 0;
      int NDPCount = 0;
      PlcPadejiBase firstNdpPadej = null;
      Date padejiMinDate = null, assistancePadejiDate = null;
      boolean bRequiredField;
      List<Date> datesGF = new ArrayList<>();
      boolean errGF = false;
      //TODO - тая тъпня да се интелектуализира
      for (PlcPadejiBase currPadej : padejiList) {
        bRequiredField = false;
        if (Tools.isEmpty(currPadej.getData_Padej())) {
          JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.component.UIInput.REQUIRED", this.getPadejiLabel(policyType) + ": " + Tools.getMsg("Plc_PadejDate")));
          bRequiredField = true;
          bRet = false;
        }
        switch (currPadej.getVid_Padej().getNomId()) {
          case NomMaturitytype.GF_PREM:
            gfPremPadejSum = gfPremPadejSum.add(currPadej.getPadej_Amount());
            if (!errGF) {
              // виж предния коментар ;)
              if (datesGF.contains(currPadej.getData_Padej())) {
                JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-144", currPadej.getVid_Padej().getNomName(), Tools.DMYtoString(currPadej.getData_Padej())));
                bRet = false;
                errGF = true;
              } else {
                datesGF.add(currPadej.getData_Padej());
              }
            }
            break;
          default:
            if (currPadej.getPodvid_Padej() == NomMaturitytype.PODVID_ASSISTANCE) {
              assistancePadejiSum = assistancePadejiSum.add(currPadej.getPadej_Amount());
              assistancePadejiCount++;
              assistancePadejiDate = currPadej.getData_Padej();
            } else {
              padejSum = padejSum.add(currPadej.getPadej_Amount());
              if (!Tools.isEmpty(currPadej.getData_Padej()) && (padejiMinDate == null || currPadej.getData_Padej().before(padejiMinDate))) {
                padejiMinDate = currPadej.getData_Padej();
              }
            }
            if (currPadej.getVid_Padej().getNomId().equals(NomMaturitytype.NDP)) {
              NDPCount++;
              if (firstNdpPadej == null) {
                firstNdpPadej = currPadej;
              }
            }
            break;
        }
        padejiTaxAmount = padejiTaxAmount.add(currPadej.getTaxIzchislAmnt());
        padejiPaidAmount = padejiPaidAmount.add(currPadej.getVnesena_Premia());

        if (!bRequiredField) {
          if (currPadej.getData_Padej().before(this.plcObj.getReg_Date())) {
            JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-031"));
            bRet = false;
          }
          if (this.operTypeNew() || this.operTypeReNew() || this.operTypeEdit() || (this.operTypeAnnexNew() && (currPadej.getID_Padej() == null || currPadej.getID_Padej() <= 0))) {
            if (currPadej.getData_Padej().after(this.plcObj.getTo_Date()) && !this.isPolicyForOldPeriod() && !this.permPadejiAfterPlcExpDate) {
              JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-032"));
              bRet = false;
            }
          }
          if (this.isEmptyNewPadej(currPadej.getID_Padej(), currPadej.getPadej_Amount())) {
            JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-124", Tools.getMsg("Plc_PadejPadej")));
            bRet = false;
          }
          if (Tools.InList(currPadej.getVid_Padej().getNomId(), NomMaturitytype.VYZST_BREAK, NomMaturitytype.VYZST_ANNEX)) {
            padejiRecoveryAmount = padejiRecoveryAmount.add(currPadej.getPadej_Amount()).subtract(currPadej.getVnesena_Premia());
          } else {
            if (currPadej.getPadej_Amount().compareTo(currPadej.getVnesena_Premia()) == -1) {
              JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-033"));
              bRet = false;
            }
          }
        }
      } //
      if (!this.validateFirstNdpPadejDate(policyType, firstNdpPadej)) {
        bRet = false;
      }
      if (NDPCount > def.plcPadeji_NDPMaxCount && !this.skipNDPMaxCountCheck()) {
        JsfUtil.addErrorMessage(Tools.getMsg("P001-063", def.plcPadeji_NDPMaxCount));
        bRet = false;
      }
      if (gfPremPadejSum.compareTo(this.plcObj.getGF()) != 0) {
        JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-035"));
        bRet = false;
      } //
      if (!this.plcValidatePadejiAmount(policyType, padejSum, padejiTaxAmount, assistancePadejiSum, assistancePadejiCount, padejiMinDate, assistancePadejiDate)) {
        bRet = false;
      }
      if (this.app.getVerInsAsset() || this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
        if (padejiRecoveryAmount.negate().compareTo(padejiPaidAmount) == 1) {
          JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-133", padejiRecoveryAmount.toString(), padejiPaidAmount.toString()));
          bRet = false;
        }
      }
    }
    return bRet;
  }

  protected boolean validateFirstNdpPadejDate(String policyType, PlcPadejiBase firstNdpPadej) {
    boolean bRet = true;
    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeEdit()) {
      if (firstNdpPadej != null && !Tools.isEmpty(firstNdpPadej.getData_Padej()) && !Tools.isEmpty(this.getFirstPadejDate())) {
        if (firstNdpPadej.getData_Padej().compareTo(this.getFirstPadejDate()) != 0 && !this.permSavePadejiValidate) {
          JsfUtil.addErrorMessage(this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-155"));
          bRet = false;
        }
      }
    }
    return bRet;
  }

  public boolean plcValidatePadejiAmount(String plcType, BigDecimal padejiAmount, BigDecimal padejiTaxAmount, BigDecimal padejiAssistanceAmount, int assistancePadejiCount, Date padejiMinDate, Date assistancePadejiDate) {
    boolean bRet;

    bRet = true;
    BigDecimal premiums[] = this.getPremiumsToReDistribute(plcType);
    BigDecimal plcRAmount = premiums[0];
    BigDecimal plcTaxAmount = premiums[1];
    BigDecimal plcRAmountOld = premiums[2];

    if (padejiAmount.compareTo(plcRAmount.subtract(padejiAssistanceAmount)) != 0) {
      JsfUtil.addErrorMessage(this.getPadejiLabel(plcType) + ": " + Tools.getMsg("P001-034", plcRAmount.subtract(padejiAssistanceAmount).subtract(padejiAmount).toString()));
      bRet = false;
    }
    //
    if (this.plcOldData == null
            || !Tools.equals(plcRAmountOld, plcRAmount)
            || this.plcOldData.getTax() != this.plcObj.getTax()) {// не е очень хитро, ма не ща да разбутвам
      if (!Tools.equals(padejiTaxAmount, plcTaxAmount)) {
        JsfUtil.addErrorMessage(this.getPadejiLabel(plcType) + ": " + Tools.getMsg("P001-037", plcTaxAmount.subtract(padejiTaxAmount).toString()));
        bRet = false;
      }
    }
    return (bRet);
  }

  protected boolean validateComplexPlcPadejiDates(String mainPolicyType) {
    boolean bRet = true;
    if (this.operTypeNew() || this.operTypeNewByID() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeEdit()) {
      Set<Date> mainPlcPadejiDates = new HashSet();
      boolean bExitLoop = false;
      ((List<PlcPadejiBase>) this.plcObj.getPadejiMap().get(mainPolicyType)).forEach(padeji -> mainPlcPadejiDates.add(padeji.getData_Padej()));
      for (Map.Entry<String, List<PlcPadejiBase>> entry : (Set<Map.Entry<String, List<PlcPadejiBase>>>) this.plcObj.getPadejiMap().entrySet()) {
        if (!entry.getKey().equals(mainPolicyType)) {
          for (PlcPadejiBase padej : entry.getValue()) {
            if (!mainPlcPadejiDates.contains(padej.getData_Padej())) {
              JsfUtil.addErrorMessage(Tools.getMsg("P001-154"));
              bRet = false;
              bExitLoop = true;
              break;
            }
          }
          if (bExitLoop) {
            break;
          }
        }
      }
    }
    return bRet;
  }

  private boolean isEmptyNewPadej(Integer padejId, BigDecimal padejAmount) {
    return (Tools.isEmpty(padejAmount) && (padejId == null || padejId <= 0));
  }

  protected boolean isPolicyForOldPeriod() {
    return false;
  }

  public String getPadejiLabel(String plcType) {
    return Tools.getMsg("Plc_Padeji");
  }

  public String getAnnexBreakLabel(String plcType) {
    return this.menuTerminationLabel;
  }

  public String getPlcName(String plcType) {
    String plcName = this.plcNamesMap.get(plcType);
    if (Tools.isEmpty(plcName)) {
      plcName = this.app.getPlcName(plcType);
      this.plcNamesMap.put(plcType, plcName);
    }
    return plcName;
  }

  @Override
  public boolean validatePadejPremium(FacesContext context, UIComponent component, Object value) {
    if (value == null) {
      return false;
    }
    boolean bRet = true, bInvalidValue = false;
    String msg;
    Collection<FacesMessage> msgs = new ArrayList<>();
    BigDecimal padejAmount = (BigDecimal) value;
    Integer padejId = (Integer) component.getAttributes().get("padejId");
    String policyType = (String) component.getAttributes().get("policyType");
    SelectOneMenu padejKindComponent = (SelectOneMenu) component.findComponent("NomMaturitytype01");
    NomMaturitytype padejKind = (NomMaturitytype) padejKindComponent.getValue();
    if (this.isEmptyNewPadej(padejId, padejAmount)) {
      msg = this.getPadejiLabel(policyType) + ": " + Tools.getMsg("P001-124", Tools.getMsg("Plc_PadejPadej"));
      msgs.add(new FacesMessage(FacesMessage.SEVERITY_ERROR, msg, msg));
      bRet = false;
    }
    if (Tools.InList(padejKind.getNomId(), NomMaturitytype.VYZST_ANNEX, NomMaturitytype.VYZST_BREAK)) {
      if (padejAmount.compareTo(BigDecimal.ZERO) == 1) {
        bInvalidValue = true;
      }
    } else {
      if (padejAmount.compareTo(BigDecimal.ZERO) == -1) {
        bInvalidValue = true;
      }
    }
    if (bInvalidValue) {
      msg = this.getPadejiLabel(policyType) + ": " + Tools.getMsg("S001-004", padejAmount.toString(), Tools.getMsg("Plc_PadejAmount"));
      msgs.add(new FacesMessage(FacesMessage.SEVERITY_ERROR, msg, msg));
      bRet = false;
    }
    if (!bRet) {
      throw new ValidatorException(msgs);
    }

    return bRet;
  }

  protected boolean skipNDPMaxCountCheck() {
    return this.sb.HasPermission(Permissions.permPlc_NoLimitPadejiNDP);
  }

  public boolean plcValidateWrittenPremium() {
    boolean bRet = true;
    BigDecimal valFrom = this.getPlcValidateWrittenPremiumMinVal();
    if (this.operTypeAnnexBreak()) {
      valFrom = BigDecimal.ZERO;
    }
    if (this.plcObj.getRAmount().compareTo(valFrom) == -1 || this.plcObj.getRAmount().compareTo(new BigDecimal("9999999999.00")) == 1) {
      JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.validator.DoubleRangeValidator.NOT_IN_RANGE", valFrom.setScale(2).toString(), "9,999,999,999.00", Tools.getMsg("Plc_FinancePart") + ": " + Tools.getMsg("Plc_WrittenPremium")));
      bRet = false;
    }
    return bRet;
  }

  protected BigDecimal getPlcValidateWrittenPremiumMinVal() {
    return BigDecimal.ONE;
  }

  protected boolean skipPayTypeValidation() {
    return false;
  }

  public boolean plcValidateObjTotalPremiumDue() {
    boolean bRet = true;
    BigDecimal valFrom = new BigDecimal("0.01").setScale(2);

    if (this.plcObj.getPlcRow().getObjTotalPremiumDue().getAmount().compareTo(valFrom) == -1 || this.plcObj.getPlcRow().getObjTotalPremiumDue().getAmount().compareTo(new BigDecimal("9999999999.00")) == 1) {
      JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.validator.DoubleRangeValidator.NOT_IN_RANGE", valFrom.setScale(2).toString(), "9,999,999,999.00", Tools.getMsg("Plc_FinancePart") + ": " + Tools.getMsg("Plc_ObjTotPremDue_Amn")));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexNum() {
    boolean bRet = true;
    if (this.plcAnnexObj.getAnnexNo() <= this.plcObj.getBroiAnexes()) {
      JsfUtil.addErrorMessage(Tools.getMsg("P001-051"));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexComTime() {
    boolean bRet = true;
    if (!Tools.correctTime(plcAnnexObj.getAnnexComTime())) {
      JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-008", Tools.getMsg("PlcAnex_AnnexComTime")));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexExpTime() {
    boolean bRet = true;
    if (!Tools.correctTime(plcAnnexObj.getAnnexExpTime())) {
      JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-008", Tools.getMsg("PlcAnex_AnnexExpTime")));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexRegTime() {
    boolean bRet = true;
    if (!Tools.correctTime(this.plcAnnexObj.getAnnexRegTime())) {
      JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-008", Tools.getMsg("PlcAnex_AnnexRegTime")));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexComBeforeAnexExpDate() {
    boolean bRet = true;
    if (plcAnnexObj.getAnnexComDate().after(plcAnnexObj.getAnnexExpDate())) {
      JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-052"));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexDateAfterContractDate() {
    boolean bRet = true;
    if (plcAnnexObj.getAnnexDate().before(plcObj.getReg_Date())) {
      JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-054"));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexComencingDate() {
    boolean bRet = true;
    if (plcAnnexObj.getAnnexComDate().before(plcObj.getFrom_Date()) || plcAnnexObj.getAnnexComDate().after(plcObj.getTo_Date())) {
      JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-053"));
      bRet = false;
    }
    if (!this.skipAnnexComDateAnnexDateValidation()) {
      if (plcAnnexObj.getAnnexComDate().before(plcAnnexObj.getAnnexDate())) {
        JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-107"));
        bRet = false;
      }
    }
    return bRet;
  }

  protected boolean skipAnnexComDateAnnexDateValidation() {
    return false;
  }

  private boolean validateAnnexExpiringDate() {
    boolean bRet = true;
    if (this.plcAnnexObj.getAnnexTypeId() == null || !this.plcAnnexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.SROK)) {
      if (this.plcAnnexObj.getAnnexExpDate().before(this.plcObj.getFrom_Date()) || this.plcAnnexObj.getAnnexExpDate().after(this.plcObj.getTo_Date())) {
        JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-168"));
        bRet = false;
      }
    }
    return bRet;
  }

  private boolean validateAnexPlcCancelDate() {
    boolean bRet = true;
    if (plcAnnexObj.getCancelDate() != null && (plcAnnexObj.getCancelDate().before(plcObj.getFrom_Date()) || plcAnnexObj.getCancelDate().after(plcObj.getTo_Date()))) {
      JsfUtil.addErrorMessage(menuTerminationLabel + ": " + Tools.getMsg("P001-055"));
      bRet = false;
    }
    return bRet;
  }

  private boolean validateAnexDateAfterPlcCancelDate() {
    boolean bRet = true;
    if (this.plcObj.getAnuliraneDate() != null && this.plcAnnexObj.getAnnexDate().before(this.plcObj.getAnuliraneDate())) {
      JsfUtil.addErrorMessage(this.getPlcAnnexLabel(this.plcAnnexObj, false) + ": " + Tools.getMsg("P001-140"));
      bRet = false;
    }
    return bRet;
  }

  protected boolean validateAnexBreak(String plcType, PlcAnnexBase annexBreak) {
    boolean bRet = true;
    if (!validateAnexBreak_UsedPremGreaterThanPaid(plcType, annexBreak)) {
      bRet = false;
    }
    if (annexBreak.getAnnexUsePrPercent().compareTo(Tools.HUNDRED) == 1) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("P001-056"));
      bRet = false;
    }
    if (annexBreak.getAnnexOtherDedPercent().compareTo(Tools.HUNDRED) == 1) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("P001-057"));
      bRet = false;
    }
    if (annexBreak.getUsedPremiaAmount().compareTo(annexBreak.getAnnexPlan()) == 1) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("P001-058"));
      bRet = false;
    }
    if (annexBreak.getOtherDeducAmount().compareTo(annexBreak.getAnnexPlan()) == 1) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("P001-059"));
      bRet = false;
    }
    if (annexBreak.getUsedPremiaAmount().compareTo(annexBreak.getAnnexPay()) == 1) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("P001-060"));
      bRet = false;
    }
    if (annexBreak.getReturnPremiaAmount().compareTo(annexBreak.getAnnexPay()) == 1) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("P001-061"));
      bRet = false;
    }
    if (this.plcValidateAnnexBreakTotalPaidPrem() && !Tools.isEmpty(annexBreak.getAnnexPlan()) && Tools.isEmpty(annexBreak.getAnnexPay())) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("P001-166"));
      bRet = false;
    }

    return bRet;
  }

  protected boolean validateOtsNadList(List<PlcOtsNadBase> otsNadList) {
    boolean bRet = true;
    boolean bValidateDiscount = false;
//    if (this.isNewPlcByOperType() || this.operTypeEdit()) {
//      if (Tools.InList(this.plcTypeOraIns,
//              NomInsComplexPolicyType.INDIVIDUAL_SOLUTION_COMPANY,
//              NomInsComplexPolicyType.INDIVIDUAL_SOLUTION_PERSON,
//              NomInsComplexPolicyType.INDUSTRIAL_SOLUTION)) {
//        bValidateDiscount = this.isShortPeriodPolicy();
//      }
//    }
    if (!Tools.isEmpty(otsNadList)) {
      for (PlcOtsNadBase otsNad : otsNadList) {
        if (otsNad.getValue().compareTo(BigDecimal.ZERO) == -1) {
          bRet = false;
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_OtsNadLabel") + ": " + Tools.getMsg("P001-123"));
          break;
        }
        if (otsNad.getType().isDiscount()) {
          if (bValidateDiscount && !Tools.isEmpty(otsNad.getValue())) {
            bRet = false;
            JsfUtil.addErrorMessage(Tools.getMsg("Plc_OtsNadLabel") + ": " + Tools.getMsg("P001-170"));
            break;
          }
        }
      }
    }
    return bRet;
  }

  protected boolean validateUserDiscount(List<PlcOtsNadBase> otsNadList, String nomId, String discountId) {
    boolean bRet = true;
    BigDecimal maxUserDiscount = this.sb.getCurrentUser().permissionNomPlcGetValue1(nomId);
//    if (!Tools.isEmpty(maxUserDiscount)) {
    PlcOtsNadBase userDiscount = this.OtsNad_GetRow(otsNadList, discountId);
    if (userDiscount != null) {
      if (userDiscount.getValue().compareTo(maxUserDiscount) > 0) {
        JsfUtil.addErrorMessage(Tools.getMsg("P001-175", userDiscount.getType().toString(), maxUserDiscount.toPlainString()));
        bRet = false;
      }
    }
//    }
    return bRet;
  }

  //
  /*
   * END валидации
   */
  //
  //
  @Override
  public void handleWrittenPremiumChange(AjaxBehaviorEvent event) {
    this.WrittenPremiumChange(null);
  }

  public void handleWrittenPremiumChange() {
    this.WrittenPremiumChange(null);
  }

  public void WrittenPremiumChange(String plcType) {
    if (this.plcObj.getTax()) {
      if (this.getRenderPadejiDFZPremCol()) {
        this.plcObj.setTaxBase(this.plcObj.getRAmount().subtract((this.plcObj.getRAmount().multiply(this.getInDFZFavourPrc()).multiply(this.plcObj.getPrcDFZFavour())).divide(Tools.TEN_THOUSAND, 2, RoundingMode.HALF_UP)));
      } else {
        this.plcObj.setTaxBase(this.plcObj.getRAmount());
      }
    } else {
      this.plcObj.setTaxBase(BigDecimal.ZERO);
    }
    this.taxBaseChange(false, plcType);
  }

  public void taxBaseChange(boolean bAfterLoad, String plcType) {
    if (!bAfterLoad) {
      this.calcTaxAmount(plcType);
    }
    this.setTaxWrittenSum(this.plcObj.getRAmount().add(this.plcObj.getTaxAmount()));
    this.setTotalPlcSum(this.getTaxWrittenSum());
  }

  protected void calcTaxAmount(String plcType) {
    this.plcObj.setTaxAmount(this.plcObj.getTaxBase().multiply(this.getTaxPremProc()).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
  }

  @Override
  public void handle_PayType_Change(AjaxBehaviorEvent event) throws SQLException {
    this.payType_Change(false, true);
  }

  private void payType_Change(boolean bAfterLoad, boolean bChangeFs) {
    if (this.plcObj.getPayType() != null && this.plcObj.getPayType().getNomId().equals(NomElSmetkiPayType.BANK_ACC)) {
      if (!bAfterLoad) {
        if (this.plcObj.getAgent() == null) {
          this.plcObj.setIBAN(null);
        } else {
          NomInsPolicyIBAN nomIban = this.nomsFacade.getNomInsPolicyIBAN(this.plcObj.getAgent());
          if (Tools.isEmpty(nomIban)) {
            this.plcObj.setIBAN(null);
          } else {
            this.plcObj.setIBAN(nomIban.getIBAN());
          }
        }
      }
      if (bChangeFs) {
        this.fs.setIBAN(!this.sb.HasPermission(Permissions.permElSmetki_EditIBAN));
      }
    } else {
      if (!bAfterLoad) {
        this.plcObj.setIBAN(null);
      }
      if (bChangeFs) {
        this.fs.setIBAN(true);
      }
    }
  }

  private SelectItem[] FilterNomFormtype() {
    List<NomFormtype> fType = this.nomsCntrl.getNomBlanktypeOrdBySeria();
    List<NomFormtype> fTypeRes = new ArrayList();

    if (fType != null) {
      String plct = "," + this.getPlcType() + ",";
      for (NomFormtype oNom : fType) {
        if ((oNom.getInstypes() == null || ("," + oNom.getInstypes() + ",").contains(plct))
                && (!Tools.isEmpty(oNom.getFlagnew()) && ("," + oNom.getFlagnew() + ",").contains(plct))) {
          fTypeRes.add(oNom);
        }
      }
    }
    nomFormtype = JsfUtil.getSelectItems(fTypeRes, true);
    return nomFormtype;
  }

  private SelectItem[] FilterPlcSearchNomFormtype() {
    List<NomFormtype> fType = this.nomsCntrl.getNomBlanktype();
    List<NomFormtype> fTypeRes = new ArrayList();

    if (fType != null) {
      String plct = "," + this.plcType + ",";
      for (NomFormtype oNom : fType) {
        if (oNom.getInstypes() == null || ("," + oNom.getInstypes() + ",").contains(plct)) {
          fTypeRes.add(oNom);
        }
      }
    }
    plcSearchNomFormtype = JsfUtil.getSelectItems(fTypeRes, true);

    return plcSearchNomFormtype;
  }

  public void FillNomFormtype(boolean bAll) {
    if (bAll) {
      this.nomFormtype = JsfUtil.getSelectItems(this.nomsCntrl.getNomBlanktype(), false);
    } else {
      this.nomFormtype = this.FilterNomFormtype();
    }
  }

  @Override
  public SelectItem[] getNomElSmetkiPayType() {
    if (this.nomElSmetkiPayType == null) {
      if (this.app.getVerInsAsset() || this.app.getVerInsMVIns()) {
        if (this.fs.getPayType()) {
          this.nomElSmetkiPayType = this.nomsCntrl.getNomElSmetkiPayType();
        } else {
          List<NomElSmetkiPayType> payTypeList = new ArrayList<>();
          for (NomElSmetkiPayType payType : this.nomsCntrl.getNomElSmetkiPayTypeList_Active()) {
            if ((payType.getNomId().equals(NomElSmetkiPayType.CARD) && !this.sb.HasPermission(Permissions.permElSmetki_PayType_WithCard))
                    || (payType.getNomId().equals(NomElSmetkiPayType.ONLINE) && !this.sb.getCurrentUser().HasPermission(Permissions.permElSmetki_PayType_Online))) {
              continue;
            }
            payTypeList.add(payType);
          }
          this.nomElSmetkiPayType = JsfUtil.getSelectItems(payTypeList, true);
        }
      } else {
        this.nomElSmetkiPayType = this.nomsCntrl.getNomElSmetkiPayType();
      }
    }
    return nomElSmetkiPayType;
  }

  @Override
  public void handleAgentChange(AjaxBehaviorEvent event) {
    this.payType_Change(false, false);
  }

  @Override
  public void handleContractDateValueChange(AjaxBehaviorEvent event) {
    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeIssuePlcFromPredl() || this.operTypeEditIskane()) {
      if (event == null) {
        this.plcObj.setFrom_Date(Tools.Add2Date(this.plcObj.getReg_Date(), 1, 0, 0, false));
      }
      if (this.plcObj.getReg_Date().equals(this.plcObj.getFrom_Date())) {
        if (this.plcObj.getMonth().getNomId().equals(NomPeriod.YEAR_1)) {
          GregorianCalendar glassFishDate = new GregorianCalendar();
          GregorianCalendar comDate = new GregorianCalendar();
          comDate.setTime(this.plcObj.getFrom_Date());
          if (glassFishDate.get(GregorianCalendar.HOUR_OF_DAY) == 23) {
            comDate.set(GregorianCalendar.DAY_OF_MONTH, comDate.get(GregorianCalendar.DAY_OF_MONTH) + 1);
            this.plcObj.setTo_Date(Tools.YMD(comDate.getTime()));
          }
        }
      }
      this.ComencingTimeCalc(this.plcObj.getReg_Date(), this.plcObj.getFrom_Date());
    }
    this.recalcPadejiOnPlcIssue();
  }

  public void handleComencingDateValueChange(AjaxBehaviorEvent event) {
    if (this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeIssuePlcFromPredl() || this.operTypeEditIskane()) {
      ComencingTimeCalc(null, this.plcObj.getFrom_Date());
    } else {
      this.SetExpiringDate(this.plcObj.getFrom_Date(), true);
    }
    this.recalcPadejiOnPlcIssue();
  }

  public void handleExpiringDateValueChange(AjaxBehaviorEvent event) {
  }

  public void handle_nDay_Count_Change(AjaxBehaviorEvent event) {
    this.calcExpiringDateByDayCount();
  }

  protected void calcExpiringDateByDayCount() {
    if (!Tools.isEmptyOrNegative(this.plcObj.getnDay_Count())) {
      this.plcObj.setTo_Date(Tools.YMD(Tools.Add2Date(this.plcObj.getFrom_Date(), this.plcObj.getnDay_Count() - 1, 0, 0, false)));
    }
  }

  public void ComencingTimeChange(AjaxBehaviorEvent event) {
//    if (!Tools.incompleteTime(this.plcObj.getFromTime())) {
//      if (/*(this.app.getVerInsOZK() || this.app.getVerInsOZOK() || this.app.getVerInsNadejda() || this.app.getVerInsAsset()) &&*/!this.plcObj.getFromTime().equals(def.timePlcStart)) {
//        if (this.app.getVerInsAsset() && this.plcObj.getFrom_Date().equals(this.plcObj.getReg_Date())) {
//          this.plcObj.setToTime(def.timePlcEnd_2);
//        } else {
//          String comTime = this.plcObj.getFromTime();
//          GregorianCalendar expTime = new GregorianCalendar();
//          comTime = comTime.replace(":", "");
//          int hours = Integer.parseInt(comTime.substring(0, 2));
//          int minutes = Integer.parseInt(comTime.substring(2, 4));
//          int seconds = Integer.parseInt(comTime.substring(4, 6));
//          expTime.set(Calendar.HOUR_OF_DAY, hours);
//          expTime.set(Calendar.MINUTE, minutes);
//          expTime.set(Calendar.SECOND, seconds - 1);
//          this.plcObj.setToTime(Tools.HMS(expTime.getTime()));
//        }
//      } else {
//        if (this.plcObj.getFromTime().equals(def.timePlcStart)
//                || (this.app.getVerInsBulIns()
//                && (this.operType.equals(def.OPER_TYPE_NEW) || this.operType.equals(def.OPER_TYPE_RENEW))
//                && this.plcObj.getMonth().getNomId().equals(NomPeriod.YEAR_1))) {
//          this.plcObj.setToTime(def.timePlcEnd_2);
//        } else {
//          this.plcObj.setToTime(this.plcObj.getFromTime());
//        }
//      }
//    } else {
//      this.plcObj.setToTime("");
//    }
    this.SetExpiringDate(this.plcObj.getFrom_Date(), true);
  }

  protected void ComencingTimeCalc(Date contractDate, Date comencingDate) {
    GregorianCalendar contDate = new GregorianCalendar();
    GregorianCalendar comDate = new GregorianCalendar();
    if (contractDate != null) {
      this.plcObj.setReg_Date(contractDate);
    }
    if (comencingDate != null) {
      this.plcObj.setFrom_Date(comencingDate);
    }
    comDate.setTime(this.plcObj.getFrom_Date());
    if (this.plcObj.getReg_Date().equals(this.plcObj.getFrom_Date())) {
      if (!this.permChangeContractDate) {
        comDate.set(GregorianCalendar.HOUR_OF_DAY, contDate.get(GregorianCalendar.HOUR_OF_DAY) + 1);
        comDate.set(GregorianCalendar.MINUTE, 0);
        comDate.set(GregorianCalendar.SECOND, 0);
      }
      this.plcObj.setFromTime(Tools.HMS(comDate.getTime()));
    } else {
      if (this.app.getVerInsAsset() || this.app.getVerInsMVIns()) {
        comDate.set(GregorianCalendar.HOUR_OF_DAY, 0);
        this.plcObj.setFromTime(Tools.HMS(comDate.getTime()));
      }
    }
    ComencingTimeChange(null);
  }

  public void handlePeriodChange(AjaxBehaviorEvent event) {
    this.SetExpiringDate(this.plcObj.getFrom_Date(), true);
  }

  protected void SetExpiringDate(Date dDate, boolean bCalc) {
    if (this.plcObj.getMonth() == null
            || this.plcObj.getMonth().getNomId().equals(def.NOM_NOT_SELECTED)
            || this.plcObj.getMonth().getNomId().equals(NomPeriod.OTHER)) {
      if (!this.fs.isMonth()) {
        this.fs.setTo_Date(false);
        this.fs.setToTime(true);
      }
    } else {
      this.fs.setTo_Date(true);
      this.fs.setToTime(true);
      if (bCalc) {
        this.ExpiringDateCalc(dDate);
      }
    }
  }

  protected Date calcPlcExpiringDate(Date dComencingDate) {
    int aValues[];
    Date dNewDate;
    aValues = Tools.InsPlc_Srok2Values(this.plcObj.getMonth().getNomId());
    if (!Tools.incompleteTime(this.plcObj.getFromTime()) && this.plcObj.getFromTime().compareTo(this.plcObj.getToTime()) < 0) {
      aValues[0]--;
    }
    dNewDate = Tools.Add2Date(dComencingDate, aValues[0], aValues[1], aValues[2], false);
    return dNewDate == null ? null : Tools.YMD(dNewDate);
  }

  protected void ExpiringDateCalc(Date dComencingDate) {
    Date plcExpDate = this.calcPlcExpiringDate(dComencingDate);
    this.plcObj.setTo_Date(Tools.YMD(plcExpDate));
  }

  @Override
  public void handleBlancTypeChange(AjaxBehaviorEvent event) {
    if (this.plcObj.getBlancType() == null || this.plcObj.getBlancType().getNomId().startsWith(NomFormtype.AUTO_COMMON)) {
      this.fs.setBlankNo(true);
      if (event != null) {
        this.plcObj.setBlankNo(null);
      }
    } else {
      this.fs.setBlankNo(false);
    }
  }

  @Override
  public void handleFlManualBlankNoChange(AjaxBehaviorEvent event) {
    if (this.plcObj.isFlManualBlankNo()) {
      this.fs.setBlankNo(false);
    } else {
      this.fs.setBlankNo(true);
      this.plcObj.setBlankNo(null);
    }
  }

  @Override
  public void handlePreizdavaneChange(AjaxBehaviorEvent event) {
    this.plcObj.setPreizdavaneTemp(Tools.Bool2Str(this.getPlcObj().getPreizdavane()));
  }

  @Override
  public void handle_PolicyVal_Change(AjaxBehaviorEvent event) {
    this.plcObj.FillPlcCodVal(this.plcObj.getPolicyVal());
    if (!Tools.isEmpty(this.plcObj.getPadejiMap())) {
      this.plcObj.getPadejiMap().forEach((key, value) -> {
        List<PlcPadejiBase> padejiList = (List<PlcPadejiBase>) value;
        if (!Tools.isEmpty(padejiList)) {
          padejiList.forEach(oPadej -> {
            PlcPadejiBase padej = (PlcPadejiBase) oPadej;
            padej.FillPadejCodVal(PlcControllerBase.this.plcObj.getPolicyVal());
          });
        }
      });
    }
    if (this.plcObj.getOtsNadList() != null) {
      this.plcObj.getOtsNadList().forEach((oOtsNad) -> {
        PlcOtsNadBase otsNad = (PlcOtsNadBase) oOtsNad;
        otsNad.FillCodVal(this.plcObj.getPolicyVal());
      });
    }
    if (this.plcObj.getPlcObjList() != null) {
      this.plcObj.getPlcObjList().forEach((oRow) -> {
        PlcRowBase row = (PlcRowBase) oRow;
        row.FillPlcCodVal(this.plcObj.getPolicyVal());
      });
    }
  }

  public void selectAddressPostCodeFromAc(AddressBase address) {
    if (address.getPostCode() != null) {
      address.setCity(address.getPostCode().getNomCityId());
    }
  }

  public void addressPostCodeChange(AddressBase address) {
  }

  public void selectAddressCityFromAc(AddressBase address) {
    address.setPostCode(null);
    if (address.getCity() != null) {
      if (!Tools.isEmpty(address.getCity().getNomCitypostcodeCollection())) {
        for (NomCitypostcode pk : address.getCity().getNomCitypostcodeCollection()) {
          if (Tools.Str2Bool(pk.getNomStatus())) {
            address.setPostCode(pk);
            break;
          }
        }
      }
    }
  }

  public void addressCityChange(AddressBase address) {
  }

  public void handleObjTotalPremiumDueChange() {
  }

  public void handleFlCommReductionChange(AjaxBehaviorEvent event) {
    this.flCommReductionChange(false);
  }

  protected void flCommReductionChange(boolean bAfterLoad) {
    if (this.plcObj.isFlCommReduction()) {
      this.fs.setCommReductPercent(false);
    } else {
      this.fs.setCommReductPercent(true);
      if (!bAfterLoad) {
        this.plcObj.setCommReductPercent(null);
        this.commReductPercentChange(true);
      }
    }
  }

  public void handleCommReductPercentChange(AjaxBehaviorEvent event) {
    this.commReductPercentChange(true);
  }

  protected void commReductPercentChange(boolean bCalcOtsNad) {
    BigDecimal chisl = (Tools.HUNDRED.subtract(Tools.nvl(this.agentCommission, BigDecimal.ZERO))).multiply(Tools.TEN_THOUSAND);
    BigDecimal znam = Tools.TEN_THOUSAND.subtract(Tools.nvl(this.agentCommission, BigDecimal.ZERO).multiply(Tools.HUNDRED.subtract(this.plcObj.getCommReductPercent())));
    BigDecimal commReductionPercent = Tools.HUNDRED.subtract(chisl.divide(znam, 2, RoundingMode.HALF_UP));
    this.OtsNad_SetValue(this.plcObj.getOtsNadList(), NomInsPolicyDiscountType.NAMALEN_KOMISION, commReductionPercent);
  }

  public void handleCrossSellingTextChange(AjaxBehaviorEvent event) {
    this.crossSellingTextChange(false);
  }

  protected void crossSellingTextChange(boolean bAfterLoad) {
    if (Tools.isEmpty(this.plcObj.getCrossSellingText())) {
      this.fs.setCrossSellingDate(true);
      if (!bAfterLoad) {
        this.plcObj.setCrossSellingDate(null);
      }
    } else {
      this.fs.setCrossSellingDate(false);
      if (!bAfterLoad) {
        if (Tools.isEmpty(this.plcObj.getCrossSellingDate())) {
          this.plcObj.setCrossSellingDate(this.sb.getCurrDate());
        }
      }
    }
  }

  public void handleCrossSellingDateChange(AjaxBehaviorEvent event) {
  }

  public void handleApprCustElCommChange(AjaxBehaviorEvent abe) {
  }

  @Override
  public MenuModel getPlcPrintMenu() {
    if (plcPrintMenu == null) {
      this.plcPrintMenu = new DefaultMenuModel();
      this.initPlcPrintMenu();
    }
    return plcPrintMenu;
  }

  private void reloadPlcPrintMenu() {
    plcPrintMenu = null;
  }

  protected void initPlcPrintMenu() {
    NomPolicyStatus plcStatus = this.getPlcOldOrSaveStatus();
    if (Tools.InList(plcStatus, NomPolicyStatus.PREDLOJENIE, NomPolicyStatus.PREDLOJENIE_ANNEX)) {
      this.fillPlcPrintMenuOffer(plcStatus);
    } else {
      if (plcStatus == null || !plcStatus.getNomId().equals(NomPolicyStatus.PREKRATENA)) {
        this.fillPlcPrintMenuPolicy(plcStatus);
//        this.fillPlcPrintMenuDebitNote(plcStatus);
      }
      if (this.operTypeView()
              && this.renderAnexPrintBtnInPlc()
              && this.plcObj != null
              && plcStatus != null
              && Tools.InList(plcStatus, NomPolicyStatus.ACTIVE, NomPolicyStatus.PREKRATENA)
              && (this.bAnnexNew || (this.plcOldData != null && this.plcOldData.getStatus() != null && this.plcOldData.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE_ANNEX)))) {
        this.fillPlcPrintMenu("Btn_Print_Annex", WhatToPrint.Annex, NomStoredDocs.ANNEX);
      }
    }
  }

  protected void fillPlcPrintMenu(String label, WhatToPrint whatToPrint, String storedDocId) {
    DefaultMenuItem menuItem = DefaultMenuItem.builder().value(Tools.getMsg(label)).icon("ui-icon-print").build();
    NomStoredDocs storedDocType = this.nomsFacade.findNom(storedDocId, NomStoredDocs.class);
    if (whatToPrint == WhatToPrint.Annex) {
      menuItem.setCommand("#{cntrl" + this.getCntrlPolicyType() + ".anexPrint()}");
    } else {
      menuItem.setCommand("#{cntrl" + this.getCntrlPolicyType() + ".plcPrint('" + whatToPrint + "', '" + storedDocId + "')}");
    }
    if (storedDocType != null && storedDocType.isStoreOnPrintWwwIns()) {
      menuItem.setAjax(true);
      menuItem.setUpdate(":uiTopMessage PlcPrintDlg");
      menuItem.setOncomplete("goTop(args.validationFailed, args.bJavaValidationFailed);");
    } else {
      menuItem.setAjax(false);
    }
    menuItem.setImmediate(true);
    this.plcPrintMenu.getElements().add(menuItem);
  }

  protected void fillPlcPrintMenuOffer(NomPolicyStatus plcStatus) {
    this.fillPlcPrintMenu("Btn_Print_Offer", WhatToPrint.Policy, NomStoredDocs.OFFER);
  }

  protected void fillPlcPrintMenuPolicy(NomPolicyStatus plcStatus) {
    this.fillPlcPrintMenu("Btn_Print_Policy", WhatToPrint.Policy, NomStoredDocs.POLICY);
  }

  protected void fillPlcPrintMenuDebitNote(NomPolicyStatus plcStatus) {
    this.fillPlcPrintMenu("Btn_Print_DebitNote", WhatToPrint.DebitNote, NomStoredDocs.DEBIT_NOTE);
    this.fillPlcPrintMenu("Btn_Print_Receipt", WhatToPrint.Receipt, NomStoredDocs.RECEIPT);
  }

  @Override
  public Res<PrintInfo> getPrintStream(WhatToPrint whatToPrint, NomStoredDocs storedDocType, Object objToPrint, Object objToPrint2) throws JRException, IOException, SQLException {
    if (whatToPrint == WhatToPrint.Annex) {
      return doGetAnnexPrintStream((PlcAnnexBase) objToPrint, (PlcBase) objToPrint2, storedDocType);
    } else {
      return doGetPlcPrintStream(whatToPrint, (PlcRowBase) objToPrint, storedDocType);
    }
  }

  public void plcPrint(WhatToPrint whatToPrint, String storedDocId) throws JRException, IOException, SQLException {
    boolean bPrint = true;
    if (whatToPrint == WhatToPrint.Receipt || whatToPrint == WhatToPrint.DebitNote) {
      if (this.selectedPadejForPrint == null) {
        bPrint = false;
        if (whatToPrint == WhatToPrint.DebitNote) {
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_PadejForDebitNoteNotSelected"));
        } else {
          if (whatToPrint == WhatToPrint.Receipt) {
            JsfUtil.addErrorMessage(Tools.getMsg("Plc_PadejForReceiptNotSelected"));
          }
        }
      }
//    } else if (whatToPrint == WhatToPrint.Policy || whatToPrint == WhatToPrint.Policy_EN) {
//      Res valPlcPrintRes = this.plcObj.validatePredlPrint(this.getPlcOldOrSaveStatus());
//      if (!valPlcPrintRes.isOK()) {
//        bPrint = false;
//        JsfUtil.addErrorMessage(valPlcPrintRes.getErrorMsg());
//      }
    }
    if (bPrint) {
      NomStoredDocs storedDocType = this.nomsFacade.findNom(storedDocId, NomStoredDocs.class);
      this.printPlcOrShowDlg(whatToPrint, storedDocType, null);
    }
  }

  protected void printPlcOrShowDlg(WhatToPrint whatToPrint, NomStoredDocs storedDocType, PlcRowBase currentRow) throws JRException, IOException, SQLException {
//    if (storedDocType != null && storedDocType.isStoreOnPrintWwwIns()) {
//      boolean renewDoc = storedDocType.isRenewDoc() && this.operTypeEditOnLoad() && this.plcObj.getDispStatus() != null && this.plcObj.getDispStatus().getNomId().equals(NomPolicyStatus.ACTIVE);
//      this.storedDocsPrint.init(whatToPrint, "PlcPrintDlg", this.plcObj.getPolicyID(), null, storedDocType, storedDocType.getNomName(), currentRow, null, renewDoc);
//    } else {
    this.doPlcPrint(whatToPrint, currentRow, storedDocType);
//    }
  }

  private Res<PrintInfo> doGetPlcPrintStream(WhatToPrint whatToPrint, PlcRowBase currentRow, NomStoredDocs storedDocType) throws JRException, IOException, SQLException {
    Res<PrintInfo> res = new Res(false);
    boolean bPrintAnnexBreak = this.getPrintAnnexBreak();
    boolean bLoadAnnexes = bPrintAnnexBreak;
    NomPolicyStatus plcStatus = this.getPlcOldOrSaveStatus();
    boolean bSkipStatusCheck = bPrintAnnexBreak || Tools.InList(plcStatus, NomPolicyStatus.PREDLOJENIE, NomPolicyStatus.PREDLOJENIE_ANNEX);
    Res<PlcBase> cmdLoadPlc = this.policiesFacade.plcPrepareForPrint_OraIns(this.plcObj.getPolicyID(), this.plcObj.getPlcCombType(), this.plcObj.getComplexPlcId(), null, this.sb.sessionInfo(), 0, 0, bSkipStatusCheck, bLoadAnnexes, null);
    if (cmdLoadPlc.isOK()) {
      PlcBase printObj = cmdLoadPlc.getResponse();
      boolean bPrint = true;
      if (currentRow != null) {
        printObj.printSingleRow(currentRow);
      }
      if (whatToPrint == WhatToPrint.DebitNote) {
        printObj.getFirstUnPaidPadeji(this.selectedPadejForPrint);
        Res valDebitNoteRes = printObj.validateDebitNotePrint();
        if (valDebitNoteRes.isOK()) {
          printObj.setTodayCurrRate(this.utils.Get_Curs(printObj.getPolicyVal(), def.SYS_CURR, def.XchgRateType_Fixing, this.sb.getCurrDate(), this.sb.getCurrentAgency().getUniqcode()));
        } else {
          res.setError(valDebitNoteRes.getErrorMsg());
          bPrint = false;
        }
//      } else if (whatToPrint == WhatToPrint.Policy || whatToPrint == WhatToPrint.Policy_EN) {
//        Res valPlcPrintRes = printObj.validatePredlPrint(printObj.getStatus());
//        if (!valPlcPrintRes.isOK()) {
//          res.setError(valPlcPrintRes.getErrorMsg());
//          bPrint = false;
//        }
      } else {
        if (whatToPrint == WhatToPrint.Receipt) {
          printObj.getPaidPadeji(this.selectedPadejForPrint);
          Res valReceiptRes = printObj.validateReceiptPrint();
          if (!valReceiptRes.isOK()) {
            res.setError(valReceiptRes.getErrorMsg());
            bPrint = false;
          }
        }
      }
      ArrayList<PrintInfo> printInfoList = new ArrayList<>();
      if (bPrint) {
        if (bPrintAnnexBreak) {
          whatToPrint = WhatToPrint.AnnexBreak;
          Res cmdAnnexBreakForPrint = this.policiesFacade.plcPrepareForPrintAnnex(printObj, null, this.sb.sessionInfo());
          if (!cmdAnnexBreakForPrint.isOK()) {
            bPrint = false;
            res.setError(cmdAnnexBreakForPrint.getErrorMsg());
          }
          if (bPrint && printObj.getPlcDepCombinedPlc() != null && printObj.getPlcDepCombinedPlc().getPlcData() != null) {
            cmdAnnexBreakForPrint = this.policiesFacade.plcPrepareForPrintAnnex(printObj.getPlcDepCombinedPlc().getPlcData(), null, this.sb.sessionInfo());
            if (!cmdAnnexBreakForPrint.isOK()) {
              bPrint = false;
              res.setError(cmdAnnexBreakForPrint.getErrorMsg());
            }
          }
        }
        printInfoList.add(new PrintInfo(printObj, this.getPlcPrintFileName(printObj, whatToPrint), storedDocType, this.plcObj.getPolicyID(), null, def.OrgSystem_WWWIns, this.sb.sessionInfo()));
        if (whatToPrint == WhatToPrint.Policy) {
          if (this.printDeclaration(printObj)) {
            NomStoredDocs declStDocType = this.nomsFacade.findNom(NomStoredDocs.DECLARATION, NomStoredDocs.class);
            printInfoList.add(new PrintInfo(printObj, this.getPlcPrintFileName(printObj, WhatToPrint.Declaration), declStDocType, this.plcObj.getPolicyID(), null, def.OrgSystem_WWWIns, this.sb.sessionInfo()));
          }
          if (this.printGdpr(printObj)) {
            NomStoredDocs gdprStDocType = this.nomsFacade.findNom(NomStoredDocs.GDPR, NomStoredDocs.class);
            printInfoList.add(new PrintInfo(printObj, this.getPlcPrintFileName(printObj, WhatToPrint.GDPR), gdprStDocType, this.plcObj.getPolicyID(), null, def.OrgSystem_WWWIns, this.sb.sessionInfo()));
          }
        }
      }
      if (bPrint) {
        bPrint = this.printElSmetki(printInfoList, printObj, res);
      }
      if (bPrint) {
        res = this.rb.getPrintStream(printInfoList, false);
      }
    } else {
      res.setError(cmdLoadPlc.getErrorMsg());
    }
    return res;
  }

  private void doPlcPrint(WhatToPrint whatToPrint, PlcRowBase currentRow, NomStoredDocs storedDocType) throws JRException, IOException, SQLException {
    Res<PrintInfo> res = this.doGetPlcPrintStream(whatToPrint, currentRow, storedDocType);
    if (res.isOK()) {
      this.rb.printData2(res.getResponse());
    } else {
      JsfUtil.addErrorMessage(res.getErrorMsg());
    }
  }

  private boolean printElSmetki(ArrayList<PrintInfo> printInfoList, PlcBase printObj, Res<PrintInfo> res) throws SQLException {
    boolean bRet = true;
    if (this.printElSmetka || this.printElSmetka2ndPlc) {
      if (this.printElSmetka) {
        Res<ElSmetkiLoad> cmdPrepareElSmetka = this.policiesFacade.plcPrepareElSmetkaForPrintOraIns(Tools.InList(this.operTypeOnLoad, def.OPER_TYPE_ANNEX_NEW/*, def.operType_AnnexOfferToAnnex*/), printObj, this.elSmetkaId, this.sb.sessionInfo());
        if (cmdPrepareElSmetka.isOK()) {
          printInfoList.add(new PrintInfo(cmdPrepareElSmetka.getResponse(), PrintCntrlInterface.WhatToPrint.ElSmetka.name(), null, null, null, def.OrgSystem_WWWIns, this.sb.sessionInfo()));
        } else {
          res.setError(cmdPrepareElSmetka.getErrorMsg());
          bRet = false;
        }
      } else {
        if (printObj.getPlcDepCombinedPlc() != null && printObj.getPlcDepCombinedPlc().getPlcData() != null) {
          Res<ElSmetkiLoad> cmdPrepareElSmetka = this.policiesFacade.plcPrepareElSmetkaForPrintOraIns(Tools.InList(this.operTypeOnLoad, def.OPER_TYPE_ANNEX_NEW/*, def.operType_AnnexOfferToAnnex*/), printObj.getPlcDepCombinedPlc().getPlcData(), this.elSmetkaId, this.sb.sessionInfo());
          if (cmdPrepareElSmetka.isOK()) {
            printInfoList.add(new PrintInfo(cmdPrepareElSmetka.getResponse(), PrintCntrlInterface.WhatToPrint.ElSmetka.name(), null, null, null, def.OrgSystem_WWWIns, this.sb.sessionInfo()));
          } else {
            res.setError(cmdPrepareElSmetka.getErrorMsg());
            bRet = false;
          }
        }
      }
    }
    return bRet;
  }

  public void anexPrint() throws JRException, IOException, SQLException {
    NomPolicyStatus plcStatus = this.getPlcOldOrSaveStatus();
    boolean bSkipStatusCheck = plcStatus != null && plcStatus.getNomId().equals(NomPolicyStatus.PREKRATENA);
    boolean bLoadAnnexes = true;
    Res<PlcBase> cmdLoadPlc = this.policiesFacade.plcPrepareForPrint_OraIns(this.plcObj.getPolicyID(), this.plcObj.getPlcCombType(), this.plcObj.getComplexPlcId(), null, this.sb.sessionInfo(), 0, 0, bSkipStatusCheck, bLoadAnnexes, null);
    if (cmdLoadPlc.isOK()) {
      PlcBase printObj = cmdLoadPlc.getResponse();
      PlcAnnexBase annexObjForPrint = null;
      if (!Tools.isEmpty(printObj.getAnexesList())) {
        if (this.plcAnnexObj != null) {
          for (Iterator<PlcAnnexBase> it = printObj.getAnexesList().iterator(); it.hasNext();) {
            PlcAnnexBase anex = it.next();
            if (Tools.equals(anex.getStatus(), "T") && Tools.equals(anex.getAnnexNo(), this.plcAnnexObj.getAnnexNo())) {
              annexObjForPrint = anex;
              break;
            }
          }
        } else {
          annexObjForPrint = ((PlcAnnexBase) printObj.getAnexesList().get(printObj.getAnexesList().size() - 1));
        }
      }
      if (annexObjForPrint != null) {
        this.printAnnexOrShowDlg(annexObjForPrint, printObj);
      } else {
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_AnnexNotFound"));
      }
    } else {
      JsfUtil.addErrorMessage(cmdLoadPlc.getErrorMsg());
    }
  }

  public void anexPrint(PlcAnnexBase annexObj) throws JRException, IOException, SQLException {
    this.selectedPlcAnnex = annexObj;
    this.selectedPlcHistory = null;
    this.printAnnexOrShowDlg(annexObj, null);
  }

  protected void printAnnexOrShowDlg(PlcAnnexBase annexObj, PlcBase printPlc) throws JRException, IOException, SQLException {
    NomStoredDocs storedDocType = this.getAnnexStoredDocsType(annexObj);
//    if (storedDocType != null && storedDocType.isStoreOnPrintWwwIns()) {
//      if (annexObj.getbPrintCurrPlcOnly()) {
//        this.storedDocsPrint.init(WhatToPrint.Policy, "PlcPrintDlg", this.plcObj.getPolicyID(), null, storedDocType, storedDocType.getNomName(), annexObj, printPlc, false);
//      } else {
//        String printLabel = storedDocType.getNomName().concat(annexObj.getAnnexTypeId() == null ? "" : " - ".concat(annexObj.getAnnexTypeId().getNomName()));
//        this.storedDocsPrint.init(WhatToPrint.Annex, "PlcPrintDlg", annexObj.getAnnexId(), null, storedDocType, printLabel, annexObj, printPlc, false);
//      }
//    } else {
    this.doAnnexPrint(annexObj, printPlc, storedDocType);
//    }
  }

  private Res<PrintInfo> doGetAnnexPrintStream(PlcAnnexBase annexObj, PlcBase printPlc, NomStoredDocs storedDocType) throws JRException, IOException, SQLException {
    boolean bRet = true;
    Res<PrintInfo> res = new Res(false);
    PlcBase printObj = null;
    if (printPlc != null) {
      printObj = printPlc;
    } else {
      boolean bPrintAnnexBreakCurrState = annexObj.getAnnexTypeId() != null && annexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.BREAK);
      Res<PlcBase> cmdLoadPlc = this.policiesFacade.plcPrepareForPrint_OraIns(this.plcObj.getPolicyID(), this.plcObj.getPlcCombType(), this.plcObj.getComplexPlcId(), null, this.sb.sessionInfo(), annexObj.getChStampPolicy2(), annexObj.getChStampPolicy2ndPlc(), bPrintAnnexBreakCurrState, false, null);
      if (cmdLoadPlc.isOK()) {
        printObj = cmdLoadPlc.getResponse();
      } else {
        res.setError(cmdLoadPlc.getErrorMsg());
        bRet = false;
      }
    }
    if (bRet && printObj != null) {
      if (annexObj.getbPrintCurrPlcOnly()) {
        ArrayList<PrintInfo> printInfoList = new ArrayList<>();
        printInfoList.add(new PrintInfo(printObj, this.getPlcPrintFileName(printObj, null), storedDocType, printObj.getPolicyID(), null, def.OrgSystem_WWWIns, this.sb.sessionInfo()));
        res = this.rb.getPrintStream(printInfoList, false);
      } else {
        Res<PlcBase> cmdLoadPlcPrevState = this.policiesFacade.loadPlc_OraIns(this.plcObj.getPolicyID(), this.plcObj.getPlcCombType(), null, false, this.sb.sessionInfo(), annexObj.getChStampOldPolicy(), false, this.plcObj.getComplexPlcId(), null, 0, false, null);
        if (cmdLoadPlcPrevState.isOK()) {
          printObj.setPlcPrevState(cmdLoadPlcPrevState.getResponse());
          PlcAnnexBase annexForPrint = this.plcAnex_Load(annexObj.getAnnexId());
          if (annexForPrint != null) {
            printObj.setPlcAnnexObj(annexForPrint);
            if (!Tools.isEmpty(annexObj.getAnnexObjMap())) {
              for (Iterator<Map.Entry<String, PlcAnnexBase>> it = annexObj.getAnnexObjMap().entrySet().iterator(); it.hasNext();) {
                Map.Entry<String, PlcAnnexBase> entry = it.next();
                annexForPrint = this.plcAnex_Load(entry.getValue().getAnnexId());
                if (annexForPrint != null) {
                  printObj.getPlcAnnexObj().addToAnnexObjMap(entry.getKey(), annexForPrint);
                } else {
                  bRet = false;
                  break;
                }
              }
            }
          } else {
            bRet = false;
          }
          if (bRet) {
            if (printObj.getPlcDepCombinedPlc() != null && printObj.getPlcDepCombinedPlc().getPlcData() != null && annexObj.getChStampPolicy2ndPlc() != null) {
              cmdLoadPlcPrevState = this.policiesFacade.loadPlc_OraIns(printObj.getPlcDepCombinedPlc().getPlcData().getPolicyID(), printObj.getPlcDepCombinedPlc().getPlcData().getInsPolicyType(), null, false, this.sb.sessionInfo(), annexObj.getChStampOldPolicy2ndPlc(), false, 0, null, 0, false, null);
              if (cmdLoadPlcPrevState.isOK()) {
                printObj.getPlcDepCombinedPlc().getPlcData().setPlcPrevState(cmdLoadPlcPrevState.getResponse());
                printObj.getPlcDepCombinedPlc().getPlcData().setPlcAnnexObj(this.plcAnex_Load(annexObj.getAnnexId2ndPlc()));
              } else {
                bRet = false;
                res.setError(cmdLoadPlcPrevState.getErrorMsg());
              }
            }
          }
          if (bRet) {
            if (!this.app.getVerInsAllianz() && !this.app.getVerInsEZK() && !this.app.getVerInsMVIns()) {
              Res cmdGetFinData = this.policiesFacade.policyGetFinancialData_OraIns(printObj, this.sb.sessionInfo());
              if (cmdGetFinData.isOK()) {
                if (printObj.getPlcDepCombinedPlc() != null && printObj.getPlcDepCombinedPlc().getPlcData() != null && printObj.getPlcDepCombinedPlc().getPlcData().getPlcAnnexObj() != null) {
                  cmdGetFinData = this.policiesFacade.policyGetFinancialData_OraIns(printObj.getPlcDepCombinedPlc().getPlcData(), this.sb.sessionInfo());
                  if (!cmdGetFinData.isOK()) {
                    bRet = false;
                    res.setError(cmdGetFinData.getErrorMsg());
                  }
                }
              } else {
                res.setError(cmdGetFinData.getErrorMsg());
                bRet = false;
              }
            }
          }
          if (bRet) {
            printObj.prepareAnnexForPrint();
            ArrayList<PrintInfo> printInfoList = new ArrayList<>();
            printInfoList.add(new PrintInfo(printObj, getAnexPrintFileName(printObj), storedDocType, printObj.getPlcAnnexObj().getAnnexId(), null, def.OrgSystem_WWWIns, this.sb.sessionInfo()));
            if (bRet) {
              bRet = this.printElSmetki(printInfoList, printObj, res);
            }
            if (bRet) {
              res = this.rb.getPrintStream(printInfoList, false);
            }
          }

        } else {
          res.setError(cmdLoadPlcPrevState.getErrorMsg());
          bRet = false;
        }
      }
    }
    return res;
  }

  private void doAnnexPrint(PlcAnnexBase annexObj, PlcBase printPlc, NomStoredDocs storedDocType) throws JRException, IOException, SQLException {
    Res<PrintInfo> res = this.doGetAnnexPrintStream(annexObj, printPlc, storedDocType);
    if (res.isOK()) {
      this.rb.printData2(res.getResponse());
    } else {
      JsfUtil.addErrorMessage(res.getErrorMsg());
    }
  }

  private NomStoredDocs getAnnexStoredDocsType(PlcAnnexBase annexObj) {
    NomStoredDocs storedDocType;
    if (annexObj.getbPrintCurrPlcOnly()) {
      storedDocType = this.nomsFacade.findNom(NomStoredDocs.POLICY, NomStoredDocs.class);
    } else {
      storedDocType = this.nomsFacade.findNom(NomStoredDocs.ANNEX, NomStoredDocs.class);
    }
    return storedDocType;
  }

  public boolean getAnnexPrintAjax(PlcAnnexBase annexObj) {
    NomStoredDocs storedDocType = getAnnexStoredDocsType(annexObj);
    return storedDocType != null && storedDocType.isStoreOnPrintWwwIns();
  }

  private String getPlcPrintFileName(PlcBase printObj, WhatToPrint whatToPrint) {
    String printFileName;
    if (whatToPrint == WhatToPrint.AnnexBreak || whatToPrint == WhatToPrint.Receipt || whatToPrint == WhatToPrint.DebitNote) {
      printFileName = whatToPrint.name();
    } else {
      String plcPrintType = Tools.isEmpty(printObj.getPlcCombType().getObjectType()) ? printObj.getPlcCombType().getNomId() : printObj.getPlcCombType().getObjectType();
      printFileName = "plc" + new Formatter().format("%03d", Integer.valueOf(plcPrintType)).toString();
      if (printObj.getPlcDepCombinedPlc() != null) {
        if (printObj.getPlcDepCombinedPlc().getPlcData() != null) {
          printFileName += printObj.getPlcDepCombinedPlc().getPlcData().getInsPolicyType().getNomId();
        }
      }
      if (whatToPrint != null && whatToPrint != WhatToPrint.Policy) {
        printFileName += "_" + whatToPrint.name();
      }
    }
    return printFileName;
  }

  protected String getAnexPrintFileName(PlcBase printObj) {
    String anexPrintFileName = WhatToPrint.Annex.name() + new Formatter().format("%03d", Integer.valueOf(printObj.getPlcCombType().getNomId())).toString();
    if (printObj.getPlcAnnexObj() != null && printObj.getPlcAnnexObj().getAnnexTypeId() != null) {
      anexPrintFileName += printObj.getPlcAnnexObj().getAnnexTypeId().getNomId();
    }
    return anexPrintFileName;
  }

  protected boolean printDeclaration(PlcBase printObj) {
    return false;
  }

  protected boolean printGdpr(PlcBase printObj) {
    return false;
  }

  public void plcChangeData() {
    //this.fs.SetViewMode_ChangeData();
  }

  public String plcSaveCancel() {
    if (this.unLockPlcOnCancel()) {
      return (this.sb.goHome());
    } else {
      return null;
    }
  }

  public boolean unLockPlcOnCancel() {
    boolean bRet = true;
    if (this.plcObj != null
            && (this.operTypeAnnexNew()
            || this.operTypeAnnexBreak()
            || this.operTypeRecover()
            || this.operTypeEdit()
            || this.operTypeAnnul()
            || (this.operTypeAnnexDelPredl() && this.plcTypeOraIns.isComplex())
            || this.operTypeImportPersons()
            || this.operTypeEngLetterNew()
            || this.operTypeDuePremium()
            || this.operTypeImportFamilyMembers()
            || this.operTypeIssuePlc()
            || this.operTypeDel())) {
      Res cmdUnlock = utils.UnLockSysObj2(def.LockTypeInsPolicyPolicy, this.plcObj.getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
      if (cmdUnlock.isOK()) {
        cmdUnlock = this.unLockComplexPolicy(cmdUnlock);
      }
      if (cmdUnlock.isOK()) {
        if (this.getbPlcCombined() && this.get2ndPlcCntrl().getPlcObj() != null) {
          cmdUnlock = utils.UnLockSysObj2(def.LockTypeInsPolicyPolicy, this.get2ndPlcCntrl().getPlcObj().getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
          if (!cmdUnlock.isOK()) {
            JsfUtil.addErrorMessage(cmdUnlock.getErrorMsg());
            bRet = false;
          }
        }
      } else {
        JsfUtil.addErrorMessage(cmdUnlock.getErrorMsg());
        bRet = false;
      }
    }
    return bRet;
  }

  public String plcNewOperation() {
    if (this.plcStatusAfterSave == null) {
      this.unLockPlcOnCancel();
    }
    Integer policyId;
    if (this.operTypeNew() || this.operTypeReNew()) {
      policyId = this.plcOldData.getPolicyID();
    } else {
      policyId = this.plcObj.getPolicyID();
    }
    return this.sb.prepareAction(def.ACTION_PREDL_FIND, AppMenu.createAction(policyId.toString()));
  }

  public String GetPlcText() {
    if (Tools.isEmpty(this.plcObj.getIns_Ref())) {
      if (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
        return (Tools.getMsg("Plc_PreU2"));
      } else {
        return (Tools.getMsg("Plc_PreU"));
      }
    } else {
      return (Tools.getMsg("Plc_PlcU"));
    }
  }

  public String getCancelBtnText() {
    return cancelBtnText;
  }

  public void setCancelBtnText() {
    if (Tools.isEmpty(this.operType) || this.operTypeView()) {
      this.cancelBtnText = Tools.getMsg("Btn_Home");
    } else {
      this.cancelBtnText = Tools.getMsg("Btn_Cancel");
    }
  }

  public String getEditBtnText() {
    return editBtnText;
  }

  protected void setEditBtnText() {
    if (this.plcObj.getStatus() != null && !Tools.isEmpty(this.plcObj.getIns_Ref())) {
      this.editBtnText = Tools.getMsg("Btn_SavePlc");
    } else {
      this.editBtnText = Tools.getMsg("Btn_SavePrd");
    }
  }

  public void plcLoadPlcToObj(Integer plcID, Integer mainPlcId, Integer chStamp) {
    CmdResult<O> res = this.getLoadFacade().Exec(this.sb.sessionInfo(), this.GetLoadParams(plcID, mainPlcId, chStamp));
    if (res.isOK()) {
      this.plcObj = res.getResponse();
      this.setEditBtnText();
      if (this.plcObj.getRowCount() > 1) {
        this.plcObj = null;
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_TooManyObj"));
      }
    } else {
      this.plcObj = null;
      JsfUtil.addErrorMessage(res.getErrorMsg());
    }
//    if (this.plcObj != null) {
//      if (!Tools.isEmpty(this.plcObj.getSecondAgentId())) {
//        CmdResult secondAgentRes = this.policiesFacade.loadSecondAgentData(this.plcObj, this.sb.sessionInfo());
//        if (!secondAgentRes.isOK()) {
//          JsfUtil.addErrorMessage(secondAgentRes.getErrorMsg());
//          this.plcObj = null;
//        }
//      }
//    }
  }

  @Override
  public void plcSearchBySelectedId(ActionEvent event) throws SQLException {
    if (this.plcSearchSelectedRow != null) {
      this.plcSearchPlc(this.plcSearchSelectedRow.getPolicyId());
    } else {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_RowNotSelected"));
    }
  }

  protected void plcSearchPlc(Integer policyId) throws SQLException {
    this.plcObj = null;
    if (plcSearchBlankType == null) {
      plcSearchBlankType = new NomFormtype();
    }

    this.plcLoadPlcToObj(policyId, 0, 0);
    if (this.plcObj != null) {
      this.changePlcType();
      if (this.operTypeAnnexDel()) {
        this.setPlcPadejiMap(this.plcObj.getPadejiMap());
      }
    }
    this.plcLoad_FillPlcSecAnnexObj();

    // валидации на състоянието на полицата според операцията
    this.validatePlcSearch();

    // търсене и валидации на подчинената полица
    this.plcSearchAndValidate2ndPlc();

    // търсене и валидации на основната полица
    this.plcSearchAndValidateMainPlc();

    // show plc
    this.plcLoad_ShowPlc(true);
    if (this.getbPlcCombined()) {
      this.get2ndPlcCntrl().plcLoad_ShowPlc(true);
    }
    //this.plcObj != null
  }

  public void plcLoad_ShowPlc(boolean initOldData) throws SQLException {
    if (this.plcObj != null) {

      if (initOldData) {
        this.plcOldData = this.asPlc();
      }
      //this.plcInitLists();
      this.plcLoad_SetViewMode();

      if (operType.equals(def.OPER_TYPE_RENEW)) {
        this.plcInitOnRenew();
        this.plcLoad_DoAfterReNew();
      }

      if (this.bAnnexNew) {
        this.PrepareDefaultsAnex();
      }

      this.plcLoad_doAfterLoad();
      this.plcLoad_FillDependencies();

      if (this.bAnnexNew) {
        this.handleAnexTypeChange(null);
        this.plcLoad_FillAnexTypeCombo(this.plcAnnexObj);
      }
    }
  }

  @Override
  public void findPlcList() throws SQLException {
    this.plcSearchResultList = null;
    this.plcSearchSelectedRow = null;
    if (this.plcValidateSearchPlc()) {
      if (Tools.isEmpty(this.plcSearchNum) && Tools.isEmpty(this.plcSearchBlankNum) && Tools.isEmpty(this.plcSearchId) && Tools.isEmpty(this.plcSearchInsCustPin)
              && (!Tools.isEmpty(this.plcSearchCustPin) || !Tools.isEmpty(this.plcSearchCustName) || !Tools.isEmpty(this.plcSearchMainPlcNum) || !Tools.isEmpty(this.plcSearchDKN) || !Tools.isEmpty(this.plcSearchVIN))) {
        CmdInsPolicyPolicyFind_Params params = new CmdInsPolicyPolicyFind_Params();
        params.setStatus("~");
        params.setCustomerPin(this.plcSearchCustPin);
        params.setCustomerName(Tools.toUC(this.plcSearchCustName));
        params.setVhRegNo(this.plcSearchDKN);
        params.setVhVin(this.plcSearchVIN);
        params.setMainPlcNo(this.plcSearchMainPlcNum);
        if (this.plcTypeOraIns == null || this.plcTypeOraIns.isGroupTypeNone()) {
          params.setPolicyType(this.plcTypeOraIns);
        } else {
          params.setPolicyGroupType(this.plcTypeOraIns.getGroupType());
        }
        params.setpStatusList(new ArrayList<>());
        this.nomsCntrl.getNomPolicyOfferStatus().forEach((pStatus) -> {
          params.getpStatusList().add(pStatus.getNomId());
        });
        if (this.plcTypeOraIns == null) {
          params.setFindType(CmdInsPolicyPolicyFind_Params.FIND_TYPE_PLC_AND_COMPLEX);
        } else {
          if (this.plcTypeOraIns.isComplex()) {
            params.setFindType(CmdInsPolicyPolicyFind_Params.FIND_TYPE_COMPLEX);
          } else {
            params.setFindType(CmdInsPolicyPolicyFind_Params.FIND_TYPE_POLICY);
          }
        }
        CmdResult<CmdInsPolicyPolicyFind_Result> res = this.cmdPoliciFind.Exec(this.sb.sessionInfo(), params);
        if (res.isOK()) {
          CmdInsPolicyPolicyFind_Result result = res.getResponse();
          if (!Tools.isEmpty(result.getPlcList())) {
            if (result.getPlcList().size() == 1) {
              this.plcSearchPlc(result.getPlcList().get(0).getPlcCombId());
            } else {
              this.plcSearchResultList = result.getPlcList();
            }
          } else {
            JsfUtil.addErrorMessage(Tools.getMsg("Plc_NotFound"));
          }
        } else {
          JsfUtil.addErrorMessage(res.getErrorMsg());
        }
      } else {
        this.plcSearchPlc(this.plcSearchId);
      }
    }
  }

  protected void plcLoad_DoAfterReNew() {
  }

  public void plcLoad_FillPlcSecAnnexObj() {
    if (this.operTypeRecover()) {
      if (this.plcObj != null) {
        if (!Tools.isEmpty(this.plcObj.getAnexesList())) {
          this.anexesList = this.getPlcAnnexesActive();
          PlcAnnexBase annexObj = null;
          if (!Tools.isEmpty(this.anexesList)) {
            PlcAnnexBase annexObjTmp;
            for (int ii = this.anexesList.size() - 1; ii >= 0; ii--) {
              annexObjTmp = this.anexesList.get(ii);
              if (annexObjTmp.getStatus().equals("T") && annexObjTmp.getAnnexTypeId().getNomId().equals(NomAnnextype.BREAK)) {
                annexObj = annexObjTmp;
                break;
              }
            }
          }
          if (annexObj != null) {
            this.setPlcSecAnnexObj(this.plcAnex_Load(annexObj.getAnnexId()));
            if (this.getPlcSecAnnexObj() != null) {
              this.getPlcSecAnnexObj().setChStampOldPolicy(annexObj.getChStampOldPolicy());
              if (!Tools.isEmpty(annexObj.getAnnexObjMap())) {
                for (Iterator<Map.Entry<String, PlcAnnexBase>> it = annexObj.getAnnexObjMap().entrySet().iterator(); it.hasNext();) {
                  Map.Entry<String, PlcAnnexBase> entry = it.next();
                  PlcAnnexBase foundAnnex = this.plcAnex_Load(entry.getValue().getAnnexId());
                  if (foundAnnex != null) {
                    foundAnnex.setChStampOldPolicy(entry.getValue().getChStampOldPolicy());
                    this.getPlcSecAnnexObj().addToAnnexObjMap(entry.getKey(), foundAnnex);
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  private void plcLoad_FillAnnexBreakData() {
    if (this.getPlcSecAnnexObj() != null) {
      this.plcLoad_FillAnexTypeCombo(this.getPlcSecAnnexObj());
      this.plcLoad_FillAnexBreak_cbCancelReason();
      this.annexNoChange(this.getPlcSecAnnexObj());
      if (!this.app.getVerInsAllianz() && !this.app.getVerInsEZK() && !this.app.getVerInsMVIns()) {
        this.showAnnexForm = true;
      }
      this.getFs().setPadejiEdit(true);
      this.getFs().setPadejiCalc(true);
    }
  }

  public void validatePlcSearch() {
    if (this.plcObj != null) {
      boolean bRet = true;
      if (this.operTypeEdit()
              || this.operTypeAnnul()
              || this.bAnnexNew
              || this.operTypeRecover()
              || this.operTypeRecoverAnnul()) {
        if (this.operTypeEdit()) {
          if (!validateOfferEditPermissions(this.plcObj, this.sb.getCurrentUser())) {
            bRet = false;
          }
        }
        if (bRet && !validateEditFromDiffUser(this.plcObj, this.sb)) {
          bRet = false;
        }
        if (bRet && !validateEditFromDiffAgency(this.plcObj, this.sb, this.app)) {
          bRet = false;
        }
        if (bRet) {
          if (false) {//!this.plcObj.getFledit().equals(def.FlEditPlc_Yes)) {
            JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", this.plcObj.getIns_Ref(), this.plcObj.getStatus().getNomName()));
            bRet = false;
          } else {
            if (this.operTypeRecover()) {
              if (!this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREKRATENA) || Tools.isEmpty(this.getPlcAnnexesActive())) {
                JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", this.plcObj.getIns_Ref(), this.plcObj.getStatus().getNomName()));
                bRet = false;
              }
              if (bRet) {
                if (this.getPlcSecAnnexObj() == null) {
                  JsfUtil.addErrorMessage(Tools.getMsg("P001-148", this.plcObj.getIns_Ref()));
                  bRet = false;
                } else {
                  if (!this.plcValidateDelAnnex(this.getPlcSecAnnexObj(), this.plcObj.getPadejiMap())) {
                    bRet = false;
                  }
                }
              }
            } else {
              if (this.bAnnexNew) {
                if (this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.ACTIVE)
                        || this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PLATENA)
                        || this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PLATENA_CHASTICHNO)) {
                  if (this.operTypeAnnexBreak() && this.plcValidateAnnexBreakTotalPaidPrem()) {
                    if (Tools.isEmpty(this.plcObj.getPlcAnnexBreakTotalPaidPrem())) {
                      JsfUtil.addErrorMessage(Tools.getMsg("P001-166"));
                      bRet = false;
                    }
                  }
                } else {
                  JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", this.plcObj.getIns_Ref(), this.plcObj.getStatus().getNomName()));
                  bRet = false;
                }
              } else {
                if (this.operTypeRecoverAnnul()) {
                  if (!this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.ANULIRANA_BLANKA)) {
                    JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", this.plcObj.getIns_Ref(), this.plcObj.getStatus().getNomName()));
                    bRet = false;
                  }
                }
              }
            }
          }
          if (bRet && this.operTypeEdit()) {
            if (!validateSearchEdit(this.plcObj, this.sb, this.app, this.utils)) {
              bRet = false;
            }
          }
        }
      } else {
        switch (this.operType) {
          case def.OPER_TYPE_RENEW:
//          if ((this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE)
//                  && (this.plcObj.getPStatus().getNomId().equals(NomPolicyOfferStatus.PREDLOJENIE)
//                  || this.plcObj.getPStatus().getNomId().equals(NomPolicyOfferStatus.IZTRITA)))) {
//            JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", this.plcObj.getIns_Ref()));
//            bRet = false;
//          }
            if (!validatePlcCurrencyOnRenew(this.plcObj)) {
              bRet = false;
            }
            break;
          case def.OPER_TYPE_NEW_BY_ID:
            if (!validatePlcCurrencyOnRenew(this.plcObj)) {
              bRet = false;
            }
            break;
          case def.OPER_TYPE_ANNEX_DEL:
            boolean bPlcStatusError;
            if (this.app.getVerInsOZOK()) {
              bPlcStatusError = !Tools.InList(this.plcObj.getStatus().getNomId(), NomPolicyStatus.ACTIVE, NomPolicyStatus.PREKRATENA);
            } else {
              bPlcStatusError = !this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.ACTIVE);
            }
            if (bPlcStatusError) {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", this.plcObj.getIns_Ref(), this.plcObj.getStatus().getNomName()));
              bRet = false;
            } else {
              if (Tools.isEmpty(this.getPlcAnnexesActive())) {
                JsfUtil.addErrorMessage(Tools.getMsg("Plc_AnexActiveNo", this.plcObj.getIns_Ref()));
                bRet = false;
              }
            }
            break;
          case def.OPER_TYPE_PREDL_ANNEX:
            if (this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.ACTIVE)) {
              if (Tools.isEmpty(this.getPlcAnnexesActive())) {
                JsfUtil.addErrorMessage(Tools.getMsg("Plc_AnexActiveNo", this.plcObj.getIns_Ref()));
                bRet = false;
              }
            } else {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_PlcNotInStatus2", this.utils.FindNom(NomPolicyStatus.class, NomPolicyStatus.ACTIVE)));
              bRet = false;
            }
            break;
          case def.OPER_TYPE_PREDL_ANNEX_DEL:
            if (!this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE_ANNEX)) {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_PlcNotInStatus2", this.utils.FindNom(NomPolicyStatus.class, NomPolicyStatus.PREDLOJENIE_ANNEX)));
              bRet = false;
            }
            break;
          case def.OPER_TYPE_VIEW:
            if ((this.app.getVerInsAsset() || this.app.getVerInsAllianz() || this.app.getVerInsNadejda() || this.app.getVerInsEZK() || this.app.getVerInsMVIns())
                    && !Tools.InList(this.plcObj.getStatus().getNomId(), NomPolicyStatus.ACTIVE, NomPolicyStatus.PREDLOJENIE, NomPolicyStatus.PREDLOJENIE_ANNEX, NomPolicyStatus.PREKRATENA, NomPolicyStatus.ANULIRANA_BLANKA)) {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", this.plcObj.getIns_Ref(), this.plcObj.getStatus().getNomName()));
              bRet = false;
            }
            break;
          case def.OPER_TYPE_SECOND_AGENT:
          case def.OPER_TYPE_SEND_PLC_DOCS:
          case def.OPER_TYPE_ENG_LETTER_NEW:
            if (!this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.ACTIVE)) {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_PlcNotInStatus2", this.utils.FindNom(NomPolicyStatus.class, NomPolicyStatus.ACTIVE)));
              bRet = false;
            }
            break;
          case def.OPER_TYPE_IMPORT_PERSONS:
            if (!this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE)) {
              JsfUtil.addErrorMessage(Tools.getMsg("Plc_PlcNotInStatus2", this.utils.FindNom(NomPolicyStatus.class, NomPolicyStatus.PREDLOJENIE)));
              bRet = false;
            } else {
              if (!this.plcObj.getPStatus().getNomId().equals(NomPolicyOfferStatus.SYGLASUVANO)) {
                JsfUtil.addErrorMessage(Tools.getMsg("Plc_OfferNotInStatus2", this.utils.FindNom(NomPolicyOfferStatus.class, NomPolicyOfferStatus.SYGLASUVANO)));
                bRet = false;
              }
            }
            break;
        }
      }
      if (!this.plcSearch_AdditionalValidations()) {
        bRet = false;
      }
      if (!bRet) {
        if (this.lockPolicyOnLoad(null)) {
          this.utils.UnLockSysObj2(def.LockTypeInsPolicyPolicy, this.plcObj.getPolicyID(), def.OrgSystem_OraIns, this.sb.sessionInfo(), 0);
          this.unLockComplexPolicy(null);
        }
        this.plcObj = null;
      }
    }
  }

  private void plcSearchAndValidate2ndPlc() throws SQLException {
    if (this.plcObj != null) {
      this.set2ndPlcCntrl();
      if (this.get2ndPlcCntrl() != null) {
        if (this.plcObj.getPlcDepCombinedPlc() != null) {
          this.plcObj.setFlComb(true);
          this.get2ndPlcCntrl().plcLoadPlcToObj(this.plcObj.getPlcDepCombinedPlc().getPlcID(), 0, 0);
          if (this.get2ndPlcCntrl().getPlcObj() != null) {
            if (this.operTypeAnnexDel()) {
              this.get2ndPlcCntrl().setPlcPadejiMap(this.get2ndPlcCntrl().getPlcObj().getPadejiMap());
            }
            this.get2ndPlcCntrl().plcLoad_FillPlcSecAnnexObj();
            this.get2ndPlcCntrl().validatePlcSearch();
            if (this.get2ndPlcCntrl().getPlcObj() == null) {
              this.plcObj = null;
            }
          } else {
            this.plcObj = null;
          }
        } else {
          this.get2ndPlcCntrl().getFs().SetViewMode(true, getViewMode(), "", "", this.permEditPolicy);
        }
      }
    }
  }

  protected void plcSearchAndValidateMainPlc() throws SQLException {

  }

  public boolean plcSearch_AdditionalValidations() {
    return true;
  }

  protected Res unLockComplexPolicy(Res cmdUnlock) {
    return cmdUnlock;
  }

  private static boolean isEditAfterXXHours(String plcStatus, int hours, PlcBase plc, SessionBean sb) {
    if (!plcStatus.equals(NomPolicyStatus.PREDLOJENIE)) {
      if (!sb.HasPermission(Permissions.permPlc_EditPlcAfterXXHours)) {
        GregorianCalendar regDateCal = new GregorianCalendar();
        regDateCal.setTime(plc.getRCmpDate());
        Date cmpDate = Tools.AddHMStoDate(regDateCal, plc.getRCmpTime(), hours, 0, 0);
        if (!new Date().before(cmpDate)) {
          return true;
        }
      }
    }
    return false;
  }

  private static boolean validateEditAfterXXHours(PlcBase plc, Utils utils, SessionBean sb) {
    boolean bRet = true;
    Integer xxHours;
    xxHours = Integer.valueOf(utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "PolicyEditXXHours", "0"));
    if (isEditAfterXXHours(plc.getStatus().getNomId(), xxHours, plc, sb)) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperUpdateError", xxHours));
      bRet = false;
    }
    return bRet;
  }

  public static boolean validateOfferEditPermissions(PlcBase plc, Users currentUser) {
    boolean bRet = true;
    if (plc.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE) && plc.getPStatus() != null) {
      PermNomType permNomType = NomPolicyOfferStatus.PERMISSION.get(plc.getPStatus().getNomId());
      if (permNomType != null && permNomType != PermNomType.notPresent) {
        if (!currentUser.hasPermissionNomPlc(plc.getPlcCombType().getNomId(), permNomType)) {
          bRet = false;
          JsfUtil.addErrorMessage(Tools.getMsg("Plc_OperUpdateOfferPermError", plc.getPStatus()));
        }
      }
    }
    return bRet;
  }

  public static boolean validateEditFromDiffUser(PlcBase plc, SessionBean sb) {
    boolean bRet = true;
    if (!sb.HasPermission(Permissions.permPlc_EditPlcFromDiffUser)) {
      if (!plc.getR_Oper().equals(sb.getUserId())) {
        bRet = false;
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_UserRightsErrorUser"));
      }
    }
    return bRet;
  }

  public static boolean validateEditFromDiffAgency(PlcBase plc, SessionBean sb, App app) {
    boolean bRet = true;
    if (app.getVerInsAllianz() || app.getVerInsEZK() || app.getVerInsMVIns()) {
      if (bRet && !plc.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE)
              && !Tools.equals(plc.getAg_No(), sb.getCurrentAgency())
              && !sb.HasPermission(Permissions.PLC_EDIT_PLC_FROM_DIFF_AGENCY)) {
        bRet = false;
        JsfUtil.addErrorMessage(Tools.getMsg("PlcMove_EditPlcErr"));
      }
    }
    return bRet;
  }

  public static boolean validateSearchEdit(PlcBase plc, SessionBean sb, App app, Utils utils) {
    boolean bRet = true;
    if (plc.getStatus().getNomId().equals(NomPolicyStatus.ANULIRANA_BLANKA)) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_EditNA", plc.getIns_Ref(), plc.getStatus().getNomName()));
      bRet = false;
    } else {
      if (plc.getBroiAnexes() > 0) {
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_AnexActive", plc.getIns_Ref()));
        bRet = false;
      } else {
        if (app.getVerInsAsset() || app.getVerInsMVIns()) {
          if (!validateEditAfterXXHours(plc, utils, sb)) {
            bRet = false;
          }
        }
      }
    }
    return bRet;
  }

  public static boolean validateOfferIssue(Date offerAgreeDate, NomInsPolicyTypeBase plcCombType, SessionBean sb) {
    boolean bRet = true;
//    if (!Tools.isEmpty(offerAgreeDate) && !Tools.isEmpty(plcCombType.getOfferAgreeDays()) && !sb.HasPermission(Permissions.PLC_ISSUE_AFTER_XX_AGR)) {
//      if (!Tools.Add2Date(offerAgreeDate, plcCombType.getOfferAgreeDays(), 0, 0, true).after(sb.getCurrDate())) {
//        bRet = false;
//        JsfUtil.addErrorMessage(Tools.getMsg("Plc_OfferAgreeError", plcCombType.getOfferAgreeDays()));
//      }
//    }
    return bRet;
  }

  public static boolean validatePlcCurrencyOnRenew(PlcBase plc) {
    boolean bRet = true;
//    if (plc != null && Tools.equals(plc.getPolicyVal(), def.BGN_CURR) && Tools.isInEuroZone(null)) {
//      bRet = false;
//      JsfUtil.addErrorMessage(Tools.getMsg("Plc_RenewEuroTransitionError"));
//    }
    return bRet;
  }

  public boolean validatePlcCurrencyOnNew() {
    boolean bRet = true;
    if (this.isNewPlcByOperType()) {
      if (Tools.equals(this.plcObj.getPolicyVal(), def.BGN_CURR) && Tools.isInEuroZone(null)) {
        bRet = false;
        JsfUtil.addErrorMessage(Tools.getMsg("Plc_NewEuroTransitionError"));
      }
    }
    return bRet;
  }

  private void plcSortPadejiByID(List<PlcPadejiBase> padeji) {
    if (!Tools.isEmpty(padeji)) {
      Collections.sort((List<PlcPadejiBase>) padeji, (PlcPadejiBase pp1, PlcPadejiBase pp2) -> {
        return pp1.getID_Padej().compareTo(pp2.getID_Padej());
      });
    }
  }

  public boolean plcValidateSearchPlc() {
    boolean bRet = true;

    if (Tools.isEmpty(this.plcSearchNum) && Tools.isEmpty(this.plcSearchBlankNum)
            && Tools.isEmpty(this.plcSearchId) && Tools.isEmpty(this.plcSearchCustPin)
            && Tools.isEmpty(this.plcSearchCustName) && Tools.isEmpty(this.plcSearchInsCustPin)
            && Tools.isEmpty(this.plcSearchMainPlcNum)
            && Tools.isEmpty(this.plcSearchDKN) && Tools.isEmpty(this.plcSearchVIN)) {
      JsfUtil.addErrorMessage(Tools.getMsg("Plc_NotEnoughParams"));
      bRet = false;
    }
    if (this.app.getVerInsBulIns()) {
      if (this.plcSearchBlankType == null && !Tools.isEmpty(this.plcSearchBlankNum)) {
        JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.component.UIInput.REQUIRED", Tools.getMsg("Plc_FormTypeID")));
        bRet = false;
      }
      if (this.plcSearchBlankType != null && Tools.isEmpty(this.plcSearchBlankNum)) {
        JsfUtil.addErrorMessage(Tools.getMsgJSF("jakarta.faces.component.UIInput.REQUIRED", Tools.getMsg("Plc_FormNumber")));
        bRet = false;
      }
    }
    return bRet;
  }

  private boolean validateAnexBreak_UsedPremGreaterThanPaid(String plcType, PlcAnnexBase annexBreak) {
    boolean bRet = true;
    if (annexBreak.getUsedPremiaAmount().add(annexBreak.getOtherDeducAmount()).compareTo(annexBreak.getAnnexPay()) == 1) {
      JsfUtil.addErrorMessage(this.getAnnexBreakLabel(plcType) + ": " + Tools.getMsg("PlcAnex_UsedPremGreaterThanPaidPrem"));
      bRet = false;
    }
    return bRet;
  }

  /*
  public void plcSearchCustMPS_Fill(SearchCustMPSResult custMPSResult) throws SQLException {
    if (this.plcObj != null) {
      this.klientCntrl.setSearchEGN(plcSearchEGN);
      this.klientCntrl.FillCustDataFromOraIns(custMPSResult.getCustKlient() != null ? custMPSResult.getCustKlient() : custMPSResult.getCustSobstvenik());
    }
  }
   */
  public void plcLoad_SetViewMode() {
    switch (this.operType) {
      case def.OPER_TYPE_NEW:
      case def.OPER_TYPE_RENEW:
      case def.OPER_TYPE_BONUS_MALUS:
        this.setViewMode(def.VIEW_MODE_NEW);
        this.setOtsWrPrFS();
        break;
      case def.OPER_TYPE_EDIT:
        this.setViewMode(def.VIEW_MODE_EDIT);
        this.setOtsWrPrFS();
        break;
      default:
        this.setViewMode(def.VIEW_MODE_VIEW);
        break;
    }
    this.setPlcType(this.getPlcType());
  }

  private void plcLoad_FillAnexTypeCombo(PlcAnnexBase annexObj) {
    List<NomAnnextype> anx = this.nomsFacade.findAllActiveOrderBy(NomAnnextype.class, true, "nomName");
    if (annexObj.getAnnexTypeId() == null) {
      List<NomAnnextype> anxRes = new ArrayList();
      if (anx != null) {
        String plcTypeSep = NomAnnextype.PLC_TYPE_SEP;
        if (this.app.getVerInsAllianz() || this.app.getVerInsEZK()) {
          plcTypeSep = NomAnnextype.PLC_TYPE_SEP_2;
        }
        if (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) {
          String plct = plcTypeSep + this.getPlcType() + plcTypeSep;
          for (NomAnnextype oNom : anx) {
            if (Tools.isEmpty(oNom.getInstypes()) || (plcTypeSep + oNom.getInstypes() + plcTypeSep).contains(plct)) {
              if (!Tools.InList(oNom.getNomId(), NomAnnextype.STIKER, NomAnnextype.SERTIF, NomAnnextype.BREAK, NomAnnextype.RECOVER)
                      || (this.operTypeRecover() && oNom.getNomId().equals(NomAnnextype.BREAK))) {
                if (!bSkipAnex(oNom.getNomId())) {
                  anxRes.add(oNom);
                }
              }
            }
          }
        } else {
          String plct = plcTypeSep + this.getPlcType() + plcTypeSep;
          boolean bGOZP = (this.app.getVerInsOZK() || this.app.getVerInsOZOK() || this.app.getVerInsNadejda() || this.app.getVerInsAsset());
          for (NomAnnextype oNom : anx) {
            if (!oNom.getNomId().equals(NomAnnextype.STIKER) && !oNom.getNomId().equals(NomAnnextype.SERTIF) && !oNom.getNomId().equals(NomAnnextype.BREAK) && !oNom.getNomId().equals(NomAnnextype.RECOVER)) {
              if ((plcTypeSep + oNom.getInstypes() + plcTypeSep).contains(plct) || (bGOZP && ((plcTypeSep + oNom.getInstypes() + plcTypeSep).contains(plcTypeSep + NomInsPolicyType.MTPL + plcTypeSep)))) {
                if (!bSkipAnex(oNom.getNomId())) {
                  anxRes.add(oNom);
                }
              }
            }
          }
        }
      }
      this.nomAnnexType = JsfUtil.getSelectItems(anxRes, true);
    } else {
      this.nomAnnexType = JsfUtil.getSelectItems(anx, true);
    }
  }

  public void plcLoad_FillAnexBreak_cbCancelReason() {

    List<NomCancelationreason> anxCancelReasonList = this.nomsFacade.findAllActive(NomCancelationreason.class);
    List<NomCancelationreason> anxCancelReasonFilteredList = new ArrayList();
    if (anxCancelReasonList != null) {
      String plct = "," + this.getPlcType() + ",";
      for (NomCancelationreason oNom : anxCancelReasonList) {
        if (Tools.isEmpty(oNom.getInstypes()) || ("," + oNom.getInstypes() + ",").contains(plct)) {
          anxCancelReasonFilteredList.add(oNom);
        }
      }
    }
    this.nomCancelationreason = JsfUtil.getSelectItems(anxCancelReasonFilteredList, true);
  }

  protected boolean bSkipAnex(String anexId) {
    return false;
  }

  public void handleAnexTypeChange(AjaxBehaviorEvent event) throws SQLException {
    if (this.plcAnnexObj.getAnnexTypeId() == null) {
      this.fs.SetViewMode(true, this.getViewMode(), this.getStatusFromOldData(), this.getPStatusFromOldData(), this.permEditPolicy);
    } else {
      this.nomElSmetkiPayType = null; // за да може да презареди номенклатурата
      this.fs.SetViewModeAnex(this.plcAnnexObj, this.getViewMode(), this.getStatusFromOldData(), this.getPStatusFromOldData());
    }
  }

  public void handleAnexNoChange(AjaxBehaviorEvent event) {
    this.annexNoChange(this.plcAnnexObj);
  }

  private void annexNoChange(PlcAnnexBase annexObj) {
    if (annexObj.getAnnexNo() == null) {
      annexObj.setAnnexNum(null);
    } else {
      annexObj.setAnnexNum(this.plcObj.getIns_Ref() + "/" + annexObj.getAnnexNo());
    }
  }

  public void handleAnnexDateChange(AjaxBehaviorEvent event) {
  }

  public void handleAnnexComDateChange(AjaxBehaviorEvent event) {
  }

  public void handleAnnexExpDateChange(AjaxBehaviorEvent event) {
  }

  public void handleAnexKonsProcChange(AjaxBehaviorEvent event) {
    this.annexKonsProcChange(null, this.plcAnnexObj);
  }

  public void handleAnexKonsProcChange(String policyType, PlcAnnexBase annexBreak) {
    this.annexKonsProcChange(policyType, annexBreak);
  }

  private void annexKonsProcChange(String policyType, PlcAnnexBase annexBreak) {
    annexBreak.setUsedPremiaAmount(annexBreak.getAnnexPlan().multiply(annexBreak.getAnnexUsePrPercent()).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
    this.handleAnexRetPremCalc(policyType, annexBreak);
  }

  public void handleAnexKonsSumChange(AjaxBehaviorEvent event) {
    this.annexKonsSumChange(null, this.plcAnnexObj);
  }

  public void handleAnexKonsSumChange(String policyType, PlcAnnexBase annexBreak) {
    this.annexKonsSumChange(policyType, annexBreak);
  }

  private void annexKonsSumChange(String policyType, PlcAnnexBase annexBreak) {
    if (!Tools.isEmpty(annexBreak.getAnnexPlan())) {
      annexBreak.setAnnexUsePrPercent(annexBreak.getUsedPremiaAmount().multiply(Tools.HUNDRED).divide(annexBreak.getAnnexPlan(), 2, RoundingMode.HALF_UP));
    } else {
      annexBreak.setAnnexUsePrPercent(BigDecimal.ZERO);
    }
    this.handleAnexRetPremCalc(policyType, annexBreak);
  }

  public void handleAnexUdrProcChange(AjaxBehaviorEvent event) {
    this.annexUdrProcChange(null, this.plcAnnexObj);
  }

  public void handleAnexUdrProcChange(String policyType, PlcAnnexBase annexBreak) {
    this.annexUdrProcChange(policyType, annexBreak);
  }

  private void annexUdrProcChange(String policyType, PlcAnnexBase annexBreak) {
    BigDecimal plcAmount = annexBreak.getAnnexPlan();
    if (this.app.getVerInsOZK() || this.app.getVerInsOZOK()) {
      plcAmount = annexBreak.getAnnexPay();
    }
    annexBreak.setOtherDeducAmount(plcAmount.multiply(annexBreak.getAnnexOtherDedPercent()).divide(Tools.HUNDRED, 2, RoundingMode.HALF_UP));
    this.handleAnexRetPremCalc(policyType, annexBreak);
  }

  public void handleAnexUdrSumChange(AjaxBehaviorEvent event) {
    this.annexUdrSumChange(null, this.plcAnnexObj);
  }

  public void handleAnexUdrSumChange(String policyType, PlcAnnexBase annexBreak) {
    this.annexUdrSumChange(policyType, annexBreak);

  }

  private void annexUdrSumChange(String policyType, PlcAnnexBase annexBreak) {
    if (!Tools.isEmpty(annexBreak.getAnnexPlan())) {
      BigDecimal plcAmount = annexBreak.getAnnexPlan();
      if (this.app.getVerInsOZK() || this.app.getVerInsOZOK()) {
        plcAmount = annexBreak.getAnnexPay();
      }
      if (!Tools.isEmpty(plcAmount)) {
        annexBreak.setAnnexOtherDedPercent(annexBreak.getOtherDeducAmount().multiply(Tools.HUNDRED).divide(plcAmount, 2, RoundingMode.HALF_UP));
      } else {
        annexBreak.setAnnexOtherDedPercent(BigDecimal.ZERO);
      }
    } else {
      annexBreak.setAnnexOtherDedPercent(BigDecimal.ZERO);
    }
    this.handleAnexRetPremCalc(policyType, annexBreak);
  }

  public void handleAnnexGeneralRecoveryPremChange(AjaxBehaviorEvent event) {
    this.annexGeneralRecoveryPremChange(null, this.plcAnnexObj);
  }

  public void handleAnnexGeneralRecoveryPremChange(String policyType, PlcAnnexBase annexBreak) {
    this.annexGeneralRecoveryPremChange(policyType, annexBreak);
  }

  private void annexGeneralRecoveryPremChange(String policyType, PlcAnnexBase annexBreak) {
    annexBreak.setReturnPremiaAmount(annexBreak.getAnnexGeneralRecovery().multiply(Tools.HUNDRED).divide(Tools.HUNDRED.add(this.getTaxPremProc()), 2, RoundingMode.HALF_UP));
    BigDecimal usedPremiaAmount = (annexBreak.getAnnexPay().subtract(annexBreak.getReturnPremiaAmount())).max(BigDecimal.ZERO.setScale(2));
    annexBreak.setUsedPremiaAmount(usedPremiaAmount);
    annexBreak.setAnnexUsePrPercent(annexBreak.getUsedPremiaAmount().multiply(Tools.HUNDRED).divide(annexBreak.getAnnexPlan(), 2, RoundingMode.HALF_UP));
    annexBreak.setOtherDeducAmount(BigDecimal.ZERO.setScale(2));
    annexBreak.setAnnexOtherDedPercent(BigDecimal.ZERO.setScale(2));

    this.annexGeneralRecoveryPremCalc(policyType, annexBreak);
  }

  private void handleAnexRetPremCalc(String policyType, PlcAnnexBase annexBreak) {
    annexBreak.setReturnPremiaAmount(BigDecimal.valueOf(Math.max(annexBreak.getAnnexPay().subtract(annexBreak.getUsedPremiaAmount()).subtract(annexBreak.getOtherDeducAmount()).doubleValue(), 0)));

    BigDecimal tpp = this.getTaxPremProc();
    BigDecimal nTaxForRet = BigDecimal.ZERO;
    if (this.plcObj.getTax()) {
      nTaxForRet = annexBreak.getReturnPremiaAmount().multiply(tpp).divide(Tools.HUNDRED);
    }

    annexBreak.setAnnexGeneralRecovery(annexBreak.getReturnPremiaAmount().add(nTaxForRet));
    this.annexGeneralRecoveryPremCalc(policyType, annexBreak);
  }

  private void annexGeneralRecoveryPremCalc(String policyType, PlcAnnexBase annexBreak) {
    annexBreak.setCornachislAmount(BigDecimal.valueOf(Math.max(annexBreak.getUsedPremiaAmount().add(annexBreak.getOtherDeducAmount()).subtract(annexBreak.getAnnexCharged()).doubleValue(), 0)));

    if ((this.app.getVerInsOZK() || this.app.getVerInsOZOK())
            && this.plcAnnexObj.getCancelReasonId() != null
            && !this.plcAnnexObj.getCancelReasonId().getNomId().equals(NomCancelationreason.NEPLATENA_VNOSKA)) {
      this.setRAmountOnAnnexBreak(policyType, annexBreak.getUsedPremiaAmount().add(annexBreak.getOtherDeducAmount()));
//      this.plcObj.setRAmount(annexBreak.getUsedPremiaAmount().add(annexBreak.getOtherDeducAmount()));
    } else {
      this.setRAmountOnAnnexBreak(policyType, annexBreak.getUsedPremiaAmount());
//      this.plcObj.setRAmount(annexBreak.getUsedPremiaAmount());
    }

    this.WrittenPremiumChange(policyType);
  }

  private BigDecimal getPropCoef(Date periodStartDate, Date periodEndDate, Date plcFromDate, Date plcToDate) {
    BigDecimal propCoef = BigDecimal.ONE.setScale(2);
    if (bAnnexNew && !Tools.isEmpty(periodStartDate) && !Tools.isEmpty(periodEndDate)) {
      double annexDays = Math.abs(Tools.daysBetween(periodStartDate, periodEndDate)) + 1;
      double plcDays = Math.abs(Tools.daysBetween(plcFromDate, plcToDate)) + 1;
      propCoef = BigDecimal.valueOf(annexDays / plcDays);
    }
    return propCoef;
  }

  protected BigDecimal calcAnnexPropPrem(BigDecimal newCalcPrem, BigDecimal oldCalcPrem, BigDecimal oldPremium, Date plcFromDate, Date plcToDate) {
    Date annexComDate = null, annexExpDate = null;
    if (this.getPlcAnnexObj() != null) {
      annexComDate = this.getPlcAnnexObj().getAnnexComDate();
      annexExpDate = this.getPlcAnnexObj().getAnnexExpDate();
    }
    BigDecimal annexCalcPrem = newCalcPrem.subtract(oldCalcPrem);
    BigDecimal prem = oldPremium.add((annexCalcPrem.multiply(this.getPropCoef(annexComDate, annexExpDate, plcFromDate, plcToDate))).setScale(2, RoundingMode.HALF_UP));
    return prem.max(BigDecimal.ZERO.setScale(2));
  }

  protected BigDecimal calcAnnexPropPremForPeriod(BigDecimal newCalcPrem, Date periodStartDate, Date periodEndDate, Date plcFromDate, Date plcToDate) {
    BigDecimal prem = newCalcPrem.multiply(this.getPropCoef(periodStartDate, periodEndDate, plcFromDate, plcToDate)).setScale(2, RoundingMode.HALF_UP);
    return prem.max(BigDecimal.ZERO.setScale(2));
  }

  protected BigDecimal calcPlcPropPremForPeriod(BigDecimal annualPrem, Date plcFromDate, Date plcToDate, NomPeriod month) {
    if (!Tools.isEmpty(plcFromDate) && !Tools.isEmpty(plcToDate)
            && (month == null || !month.getNomId().equals(NomPeriod.YEAR_1))) {
      double per1 = Math.abs(Tools.daysBetween(plcFromDate, plcToDate)) + 1;
      double per2 = Math.abs(Tools.daysBetween(plcFromDate, Tools.Add2Date(plcFromDate, 0, 0, 1, true)));
      BigDecimal prem = annualPrem.multiply(BigDecimal.valueOf(per1 / per2)).setScale(2, RoundingMode.HALF_UP);
      return prem.max(BigDecimal.ZERO.setScale(2));
    } else {
      return annualPrem;
    }
  }

  protected BigDecimal calcAnnexPropPrem2(BigDecimal newPlcPerPrem, BigDecimal oldPlcPerPrem, BigDecimal oldPrem, Date plcFromDate, Date plcToDate, Date plcFromDateOld, Date plcToDateOld) {
    double newPerAnnex = Math.abs(Tools.daysBetween(this.plcAnnexObj.getAnnexComDate(), plcToDate)) + 1; // Брой дни валидност на анекса нов
    double oldPerAnnex = Math.abs(Tools.daysBetween(this.plcAnnexObj.getAnnexComDate(), plcToDateOld)) + 1; // Брой дни валидност на анекса стар
    double newPerPlc = Math.abs(Tools.daysBetween(plcFromDate, plcToDate)) + 1; // Брой дни валидност на полицата нов
    double oldPerPlc = Math.abs(Tools.daysBetween(plcFromDateOld, plcToDateOld)) + 1; // Брой дни валидност на полицата стар
    BigDecimal oldCalcPrem = oldPlcPerPrem.multiply(BigDecimal.valueOf(oldPerAnnex / oldPerPlc)).setScale(2, RoundingMode.HALF_UP);
    BigDecimal newCalcPrem = newPlcPerPrem.multiply(BigDecimal.valueOf(newPerAnnex / newPerPlc)).setScale(2, RoundingMode.HALF_UP);

    return (oldPrem.add(newCalcPrem).subtract(oldCalcPrem)).max(BigDecimal.ZERO.setScale(2));
  }

  /*
   * END Анекси
   */
  //
  /*
   * END обработки, value change methods и др. подобни
   */
  //
  /*
   * getters and setters
   */
  protected void initEJBsBeansFacades(Utils utils, PoliciesFacade policiesFacade, NomsFacade nomsFacade, UsersFacade usersFacade, SessionBean sb, App app, F fs, NomsController nomsCntrl) {
    this.utils = utils;
    this.policiesFacade = policiesFacade;
    this.nomsFacade = nomsFacade;
    this.usersFacade = usersFacade;
    this.sb = sb;
    this.app = app;
    this.fs = fs;
    this.nomsCntrl = nomsCntrl;
  }

  public boolean getRenderSaveEditBtn() {
    return this.operTypeEdit();
  }

  public boolean getRenderSaveGFBtn() {
    return this.operTypeSaveGF();
  }

  public boolean getRenderSaveNewBtn() {
    return false && this.isNewPlcByOperType();
  }

  /*
   * параметри за търсене на полица
   */
  @Override
  public String getPlcSearchNum() {
    return plcSearchNum;
  }

  @Override
  public void setPlcSearchNum(String plcSearchNum) {
    this.plcSearchNum = plcSearchNum;
  }

  @Override
  public String getPlcSearchNumLabel() {
    return Tools.getMsg("PlcGO_Num");
  }

  @Override
  public boolean getRenderPlcSearchMainPlcParams() {
    return false;
  }

  @Override
  public String getPlcSearchMainPlcNumLabel() {
    return Tools.getMsg("Plc_MtplNumber");
  }

  @Override
  public String getPlcSearchMainPlcNum() {
    return plcSearchMainPlcNum;
  }

  @Override
  public void setPlcSearchMainPlcNum(String plcSearchMainPlcNum) {
    this.plcSearchMainPlcNum = plcSearchMainPlcNum;
  }

  @Override
  public Integer getPlcSearchId() {
    return plcSearchId;
  }

  @Override
  public void setPlcSearchId(Integer plcSearchId) {
    this.plcSearchId = plcSearchId;
  }

  @Override
  public String getPlcSearchBlankNum() {
    return plcSearchBlankNum;
  }

  @Override
  public void setPlcSearchBlankNum(String plcSearchBlankNum) {
    this.plcSearchBlankNum = plcSearchBlankNum;
  }

  @Override
  public String getPlcSearchCustPin() {
    return plcSearchCustPin;
  }

  @Override
  public void setPlcSearchCustPin(String plcSearchCustPin) {
    this.plcSearchCustPin = plcSearchCustPin;
  }

  @Override
  public String getPlcSearchInsCustPin() {
    return plcSearchInsCustPin;
  }

  @Override
  public void setPlcSearchInsCustPin(String plcSearchInsCustPin) {
    this.plcSearchInsCustPin = plcSearchInsCustPin;
  }

  @Override
  public boolean getRenderPlcSearchInsCustPin() {
    return false;
  }

  @Override
  public CmdInsPolicyPolicyFind_ResultRow getPlcSearchSelectedRow() {
    return plcSearchSelectedRow;
  }

  @Override
  public void setPlcSearchSelectedRow(CmdInsPolicyPolicyFind_ResultRow plcSearchSelectedRow) {
    this.plcSearchSelectedRow = plcSearchSelectedRow;
  }

  @Override
  public List<CmdInsPolicyPolicyFind_ResultRow> getPlcSearchResultList() {
    return plcSearchResultList;
  }

  @Override
  public void setPlcSearchResultList(List<CmdInsPolicyPolicyFind_ResultRow> plcSearchResultList) {
    this.plcSearchResultList = plcSearchResultList;
  }

  /*
  public String getPlcSearchEGN() {
    return plcSearchEGN;
  }

  public void setPlcSearchEGN(String plcSearchEGN) {
    this.plcSearchEGN = plcSearchEGN;
  }
   */
  @Override
  public String getPlcSearchCustName() {
    return plcSearchCustName;
  }

  @Override
  public void setPlcSearchCustName(String plcSearchCustName) {
    this.plcSearchCustName = plcSearchCustName;
  }

  @Override
  public String getPlcSearchDKN() {
    return plcSearchDKN;
  }

  @Override
  public void setPlcSearchDKN(String plcSearchDKN) {
    this.plcSearchDKN = Tools.toUC(plcSearchDKN);
  }

  @Override
  public NomFormtype getPlcSearchBlankType() {
    return plcSearchBlankType;
  }

  @Override
  public void setPlcSearchBlankType(NomFormtype plcSearchBlankType) {
    this.plcSearchBlankType = plcSearchBlankType;
  }

  @Override
  public String getPlcSearchVIN() {
    return plcSearchVIN;
  }

  @Override
  public void setPlcSearchVIN(String plcSearchVIN) {
    this.plcSearchVIN = Tools.toUC(plcSearchVIN);
  }

  public String getPlcSearchAssistanceTalon() {
    return plcSearchAssistanceTalon;
  }

  public void setPlcSearchAssistanceTalon(String plcSearchAssistanceTalon) {
    this.plcSearchAssistanceTalon = Tools.toUC(plcSearchAssistanceTalon);
  }

  /*
   * END параметри за търсене на полица
   */
  public SelectItem[] getNomFormtype() {
    if (this.nomFormtype == null) {
      nomFormtype = this.FilterNomFormtype();
    }
    return nomFormtype;
  }

  public void setNomFormtype(SelectItem[] nomFormtype) {
    this.nomFormtype = nomFormtype != null ? nomFormtype.clone() : null;
  }

  public SelectItem[] getPlcSearchNomFormtype() {
    if (this.plcSearchNomFormtype == null) {
      plcSearchNomFormtype = this.FilterPlcSearchNomFormtype();
    }
    return plcSearchNomFormtype;
  }

  protected BigDecimal getTaxPremProc() {
    return taxPremProc;
  }

  public String getStatusFromOldData() {
    if (this.plcOldData != null && this.plcOldData.getStatus() != null && this.plcOldData.getStatus().getNomId() != null) {
      return plcOldData.getStatus().getNomId();
    } else {
      return "";
    }
  }

  public String getPStatusFromOldData() {
    if (this.plcOldData != null && this.plcOldData.getPStatus() != null && this.plcOldData.getPStatus().getNomId() != null) {
      return plcOldData.getPStatus().getNomId();
    } else {
      return "";
    }
  }

  public boolean getEnableAgencyAgent() {
    return (Tools.InList(this.operType, def.OPER_TYPE_NEW, def.OPER_TYPE_RENEW, def.OPER_TYPE_BONUS_MALUS)
            || ((this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) && Tools.InList(this.operType, def.OPER_TYPE_EDIT) && this.plcObj != null && !this.plcObj.getHasPlcElSmNachPlatSum())
            || (!this.app.getVerInsOZK() && this.operType.equals(def.OPER_TYPE_EDIT) && this.plcOldData != null && this.plcOldData.getStatus() != null && this.plcOldData.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE) && this.plcOldData.getPStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE)));
  }

  public boolean getShowPlcForm() {
    return this.showPlcForm();
  }

  public boolean getShowPlcTypeForm() {
    return this.showPlcForm();
  }

  private boolean showPlcForm() {
    return this.operType != null && (this.operTypeNew() || this.operTypeBonusMalus() || (this.plcObj != null && !Tools.isEmpty(this.plcObj.getPolicyID())));
  }

  @Override
  public boolean getRenderPadejiRowEditor(Object padej) {
    PlcPadejiBase plcPadej = (PlcPadejiBase) padej;
    if (this.app.getVerInsHDI()) {
      return !(this.operTypeAnnexNew()
              && this.plcAnnexObj != null
              && this.plcAnnexObj.getAnnexTypeId() != null
              && this.plcAnnexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.PREM_OTSROCH)
              && (!Tools.isEmpty(plcPadej.getNa4isl_Premia()) || !Tools.isEmpty(plcPadej.getVnesena_Premia())));
    } else {
      return (plcPadej.getdSmDate() == null && !this.operTypeRecover());
    }
  }

  @Override
  public boolean getDisablePadejiDelBtn(Object padej) {
    PlcPadejiBase plcPadej = (PlcPadejiBase) padej;
    if (this.app.getVerInsHDI()) {
      return (this.operTypeAnnexNew()
              && this.plcAnnexObj != null
              && this.plcAnnexObj.getAnnexTypeId() != null
              && this.plcAnnexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.PREM_OTSROCH)
              && (!Tools.isEmpty(plcPadej.getNa4isl_Premia()) || !Tools.isEmpty(plcPadej.getVnesena_Premia())));
    } else {
      if (this.app.getVerInsAllianz() || this.app.getVerInsEZK()) {
        return !Tools.isEmpty(plcPadej.getNa4isl_Premia()) || !Tools.isEmpty(plcPadej.getVnesena_Premia()) || !Tools.isEmpty(plcPadej.getNa4isl_Comm()) || !Tools.isEmpty(plcPadej.getDuljima_Comm());
      } else {
        return plcPadej.getdSmDate() != null || plcPadej.getSmetkiCount() > 0 || this.operTypeRecover();
      }
    }
  }

  public boolean getRenderCalculateTrfBtn() {
    return (this.getShowPlcForm()
            && (this.getOperType().equals(def.OPER_TYPE_NEW)
            || this.getOperType().equals(def.OPER_TYPE_RENEW)
            || this.getOperType().equals(def.OPER_TYPE_BONUS_MALUS)
            || (this.getOperType().equals(def.OPER_TYPE_EDIT) && !this.fs.isEditWithoutPerm())));
  }

  public boolean getShowPlcSearchForm() {
    return (!Tools.InList(this.operType, def.OPER_TYPE_NEW, def.OPER_TYPE_NEW_BY_ID, def.OPER_TYPE_PREDL_ANNEX_DEL, def.OPER_TYPE_PREDL_TO_PLC, def.OPER_TYPE_E_MANUAL)
            && (this.plcObj == null || Tools.isEmpty(this.plcObj.getPolicyID())));
  }

  public boolean getShowInsTypeForm() {
    return this.operTypeNew() || this.operTypeBonusMalus() || (this.plcObj != null && !Tools.isEmpty(this.plcObj.getPolicyID()));
  }

  public boolean getShowAnnexForm() {
    return (this.showAnnexForm);
  }

  public boolean getShowPlcAnexTextForm() {
    return ((this.bAnnexNew || this.bAnnexView)
            && this.plcAnnexObj.getAnnexTypeId() != null
            && this.plcAnnexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.TEXT));
  }

  public boolean requireAnnexReason() {
    return false;
  }

  public boolean getShowPlcAnexClaimAddInsForm() {
    return (this.bAnnexNew && this.plcAnnexObj.getAnnexTypeId() != null);
  }

  public boolean getShowPlcAnexBreakForm() {
    return (this.bAnnexNew && this.plcAnnexObj.getAnnexTypeId() != null
            && this.plcAnnexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.BREAK)) || this.operTypeRecover();
  }

  public boolean getRenderAnexList() {
    return ((this.operTypeView() || this.operTypeAnnexDel() || this.operTypeAnnexDelPredl() || this.operTypeAnnexOffer()
            || (this.operTypeRecover() && (this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns())))
            && !this.operTypeEngLetter()
            && !Tools.isEmpty(this.anexesList));
  }

  public boolean getRenderPlcHistory() {
    return (this.operTypeViewOnLoad() && !this.operTypeEngLetter() && this.permPlcHistory);
  }

  public boolean getRenderPlcHistoryExportBtn() {
    return this.getRenderPlcHistory() && this.plcHistoryResult != null && !Tools.isEmpty(this.plcHistoryResult.getPlcHistoryList());
  }

  public boolean getRenderPlcCommissions() {
    return (this.operTypeViewOnLoad() && !this.operTypeEngLetter() && this.permCommissions);
  }

  public boolean disableAccumulation() {
    return !this.permAccumulation;
  }

  public boolean getRenderAccumulation() {
    return this.operTypeViewOnLoad();
  }

  public boolean getRenderPicturesPanel() {
    return (this.operTypeView() && this.permPlcPictures);
  }

  public boolean disableAnnexDate() {
    return this.operTypeRecover() ? !this.sb.HasPermission(Permissions.permPlc_AnnexRecoverEditAnnexDate) : !this.sb.HasPermission(Permissions.permPlc_EditAnnexDate);
  }

  public boolean disableAnnexComDate() {
    return this.operTypeRecover() ? !this.sb.HasPermission(Permissions.permPlc_AnnexRecoverEditAnnexDate) : false;
  }

  public boolean disableAnnexNo() {
    return false;
  }

  public boolean disableAnnexUsedPremia() {
    return !this.sb.HasPermission(Permissions.PLC_EDIT_ANNEX_USED_PREM);
  }

  protected boolean validateNomStatus() {
    return this.operTypeNew() || this.operTypeNewByID() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeEdit() || this.operTypeAnnexObsht();
  }

  protected boolean validateVhBrandModelDescription() {
    return !(this.operTypeAnnexBreak() || this.operTypeAnnul() || this.operTypeRecover());
  }

  protected boolean validateNomStatusOnNewPlc() {
    return this.operTypeNew() || this.operTypeNewByID() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeEditIskane();
  }

  public boolean operTypeNew() {
    return this.operType.equals(def.OPER_TYPE_NEW);
  }

  public boolean operTypeNewByID() {
    return this.operType.equals(def.OPER_TYPE_NEW_BY_ID);
  }

  public boolean operTypeReNew() {
    return this.operType.equals(def.OPER_TYPE_RENEW);
  }

  public boolean operTypeBonusMalus() {
    return this.operType.equals(def.OPER_TYPE_BONUS_MALUS);
  }

  public boolean operTypeEdit() {
    return this.operType.equals(def.OPER_TYPE_EDIT);
  }

  public boolean operTypeView() {
    return this.operType.equals(def.OPER_TYPE_VIEW);
  }

  public boolean operTypeViewOnLoad() {
    return this.operTypeOnLoad.equals(def.OPER_TYPE_VIEW);
  }

  public boolean operTypeEditOnLoad() {
    return this.operTypeOnLoad.equals(def.OPER_TYPE_EDIT);
  }

  public boolean operTypeEditIskane() {
    return this.operType.equals(def.OPER_TYPE_EDIT)
            && this.plcOldData != null && this.plcOldData.getStatus() != null && this.plcOldData.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE);
  }

  public boolean isNewPlcByOperType() {
    return this.operTypeNew() || this.operTypeReNew() || this.operTypeBonusMalus() || this.operTypeNewByID();
  }

  public boolean operTypeAnnul() {
    return this.operType.equals(def.OPER_TYPE_ANNUL);
  }

  @Override
  public boolean operTypeRecoverAnnul() {
    return this.operType.equals(def.OPER_TYPE_ANNUL_RECOVER);
  }

  public boolean operTypeAnnexNew() {
    return this.operType.equals(def.OPER_TYPE_ANNEX_NEW);
  }

  public boolean operTypeAnnexBreak() {
    return (this.operType.equals(def.OPER_TYPE_ANNEX_BREAK));
  }

  public boolean operTypeAnnexStikeri() {
    return (this.operType.equals(def.OPER_TYPE_ANNEX_STIKERI));
  }

  public boolean operTypeAnnexSertifi() {
    return (this.operType.equals(def.OPER_TYPE_ANNEX_SERTIFI));
  }

  public boolean operTypeDel() {
    return (this.operType.equals(def.OPER_TYPE_DEL));
  }

  public boolean operTypeAnnexDel() {
    return (this.operType.equals(def.OPER_TYPE_ANNEX_DEL));
  }

  public boolean operTypeAnnexDelPredl() {
    return (this.operType.equals(def.OPER_TYPE_PREDL_ANNEX_DEL));
  }

  public boolean operTypeAnnexOffer() {
    return (this.operType.equals(def.OPER_TYPE_PREDL_ANNEX));
  }

  public boolean operTypeIssuePlc() {
    return (this.operType.equals(def.OPER_TYPE_PREDL_TO_PLC));
  }

  public boolean operTypeIssuePlcFromPredl() {
    return this.operTypeIssuePlc() && this.plcObj != null && this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE);
  }

  public boolean operTypeSecondAgent() {
    return (this.operType.equals(def.OPER_TYPE_SECOND_AGENT));
  }

  public boolean operTypeRecover() {
    return (this.operType.equals(def.OPER_TYPE_ANNEX_RECOVER));
  }

  @Override
  public boolean operTypeDuePremium() {
    return (this.operType.equals(def.OPER_TYPE_DUE_PREMIUM));
  }

  @Override
  public boolean operTypeImportPersons() {
    return false;
  }

  @Override
  public boolean operTypeImportFamilyMembers() {
    return false;
  }

  @Override
  public boolean operTypeEngLetterNew() {
    return this.operType.equals(def.OPER_TYPE_ENG_LETTER_NEW);
  }

  @Override
  public boolean operTypeEngLetterView() {
    return this.operType.equals(def.OPER_TYPE_ENG_LETTER_VIEW);
  }

  @Override
  public boolean operTypeEngLetterEdit() {
    return this.operType.equals(def.OPER_TYPE_ENG_LETTER_EDIT);
  }

  @Override
  public boolean operTypeEngLetter() {
    return this.operTypeEngLetterNew() || this.operTypeEngLetterView() || this.operTypeEngLetterEdit();
  }

  @Override
  public boolean operTypeSendDocs2Cust() {
    return (this.operType.equals(def.OPER_TYPE_SEND_PLC_DOCS));
  }

  public boolean operTypeAnnexObsht() {
    return this.operTypeAnnexNew() && this.bAnnexNew && this.plcAnnexObj.getAnnexTypeId() != null && this.plcAnnexObj.getAnnexTypeId().getNomId().equals(NomAnnextype.OBSHT);
  }

  protected boolean operTypeAnnexObshtDopRisk() {
    return this.operTypeAnnexNew() && this.getPlcAnnexObj().getAnnexTypeId() != null && this.getPlcAnnexObj().getAnnexTypeId().getNomId().equals(NomAnnextype.OBSHT_DOP_RISK);
  }

  protected boolean operTypeAnnexSrok() {
    return this.operTypeAnnexNew() && this.getPlcAnnexObj().getAnnexTypeId() != null && this.getPlcAnnexObj().getAnnexTypeId().getNomId().equals(NomAnnextype.SROK);
  }

  public boolean operTypeAnnexBroiLica() {
    return this.operTypeAnnexNew() && this.getPlcAnnexObj().getAnnexTypeId() != null && this.getPlcAnnexObj().getAnnexTypeId().getNomId().equals(NomAnnextype.BROI_LICA);
  }

  public boolean operTypeSaveGF() {
    return (this.operType.equals(def.OPER_TYPE_NEW)
            || this.operType.equals(def.OPER_TYPE_RENEW)
            || this.operType.equals(def.OPER_TYPE_BONUS_MALUS)
            || (this.operType.equals(def.OPER_TYPE_EDIT))
            && this.plcOldData != null && this.plcOldData.getStatus() != null && this.plcOldData.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE) && this.plcOldData.getPStatus().getNomId().equals(NomPolicyOfferStatus.PREDLOJENIE));
  }

  public boolean disableAnnexType(PlcAnnexBase annexObj) {
    return (annexObj != null
            && annexObj.getAnnexTypeId() != null
            && annexObj.getAnnexTypeId().getNomId() != null);// за да не може да пипат повече ако веднъж са избрали
  }

  @Override
  public boolean getRenderPadejiPaidCols() {
    return (this.plcObj != null && !Tools.isEmpty(this.plcObj.getIns_Ref()));
  }

  @Override
  public boolean renderPadejiSelection() {
    return this.renderPrintDebitNote();
  }

  @Override
  public boolean renderPrintBtn() {
    NomPolicyStatus plcStatus = this.getPlcOldOrSaveStatus();
    return this.operTypeView() && (Tools.InList(plcStatus, NomPolicyStatus.ACTIVE, NomPolicyStatus.PREDLOJENIE, NomPolicyStatus.PREDLOJENIE_ANNEX)
            || (this.plcStatusAfterSave != null && this.plcStatusAfterSave.getNomId().equals(NomPolicyStatus.PREKRATENA)))
            && !Tools.isEmpty(this.getPlcPrintMenu().getElements()); // това трябва да е последно
  }

  private boolean renderPrintDebitNote() {
    NomPolicyStatus plcStatus = this.getPlcOldOrSaveStatus();
    return this.operTypeView() && plcStatus != null && plcStatus.getNomId().equals(NomPolicyStatus.ACTIVE);
  }

  public boolean renderPrintGCBtn() {
    return false;
  }

  public boolean renderRecoverBtn() {
    return this.operTypeRecover()
            && (this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREKRATENA))
            && this.permDelAnnexBreak;
  }

  public boolean renderAnnexDelBtn() {
    return this.operTypeAnnexDel()
            && !Tools.isEmpty(this.anexesList)
            && this.permDelAnnex;
  }

  @Override
  public boolean renderAnnexDelPredlBtn() {
    return operTypeAnnexDelPredl()
            && !Tools.isEmpty(this.anexesList)
            && this.permDelAnnex;
  }

  @Override
  public boolean renderAnnexOfferBtn() {
    NomPolicyStatus plcStatus = this.getPlcOldOrSaveStatus();
    return this.operType.equals(def.OPER_TYPE_PREDL_ANNEX)
            && plcStatus != null && plcStatus.getNomId().equals(NomPolicyStatus.ACTIVE)
            && !Tools.isEmpty(this.anexesList);
  }

  @Override
  public boolean renderSendDocs2CustBtn() {
    return this.operTypeSendDocs2Cust();
  }

  protected NomPolicyStatus getPlcOldOrSaveStatus() {
    NomPolicyStatus plcStatus = null;
    if (this.plcStatusAfterSave != null) {
      plcStatus = this.plcStatusAfterSave;
    } else {
      if (this.plcOldData != null) {
        plcStatus = this.plcOldData.getStatus();
      }
    }
    return plcStatus;
  }

  @Override
  public boolean renderIssuePlcBtn() {
    return operTypeIssuePlc()
            && this.plcObj.getPStatus().getNomId().equals(NomPolicyOfferStatus.SYGLASUVANO);
  }

  @Override
  public boolean renderSecondAgentBtn() {
    return operTypeSecondAgent()
            && this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.ACTIVE);
  }

  @Override
  public boolean renderNewOperBtn() {
    boolean bRet = this.bRenderNewOperBtn;
    if (bRet) {
      if (this.operTypeNew() || this.operTypeReNew()) {
        bRet = this.plcOldData != null && !Tools.isEmpty(this.plcOldData.getPolicyID());
      } else {
        bRet = this.plcObj != null && !Tools.isEmpty(this.plcObj.getPolicyID());
      }
    }
    return bRet;
  }

  @Override
  public boolean getRenderPadejiDFZPremCol() {
    return this.plcType != null && this.plcType.equals(NomInsPolicyType.PROPERTY_LEGAL_ENTITY);
  }

  @Override
  public boolean getDisablePadejiGroupBtn() {
    return false;
  }

  @Override
  public boolean renderPadejiGroupBtn() {
    return !this.fs.isPadejiObshtPlan();
  }

  @Override
  public boolean getRenderPadejiCalcBtn() {
    boolean bRet = false;
    if (!this.fs.isPadejiCalc()) {
      if (this.operTypeEdit()) {
        bRet = this.renderPadejiCalcBtnOnEdit();
      } else {
        if (this.operTypeAnnexBreak()) {
          bRet = this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns() || (this.app.getVerInsAsset() || (this.app.getVerInsNadejda() && this.plcAnnexObj != null && this.plcAnnexObj.getCancelReasonId() != null && this.plcAnnexObj.getCancelReasonId().getNomId().equals(NomCancelationreason.NEPLATENA_VNOSKA)));
        } else {
          bRet = true;
        }
      }
    }
    return bRet;
  }

  protected boolean renderPadejiCalcBtnOnEdit() {
    return (this.app.getVerInsAsset() || this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns() || this.app.getVerInsNadejda())
            && this.plcObj != null
            && !this.plcObj.getHasPlcElSmNachPlatSum();
  }

  @Override
  public boolean getRenderPadejiEditBtn(String plcType) {
    boolean bRet = false;
    if (!this.fs.isPadejiEdit()) {
      if (this.permEditPadeji) {
        bRet = true;
      } else {
        if (this.bAnnexNew && !this.operTypeAnnexBreak()) {
          bRet = this.renderPadejiEditBtnOnAnnex(plcType);
        }
      }
    }
    return bRet;
  }

  protected boolean renderPadejiEditBtnOnAnnex(String plcType) {
    boolean bRet = false;
    if (this.plcObj != null && this.getPlcOldData() != null) {
      BigDecimal premiums[] = this.getPremiumsToReDistribute(plcType);
      bRet = premiums[2].compareTo(premiums[0]) == 1;
    }
    return bRet;
  }

  public boolean getRenderMcp() {
    return this.sb.hasPermissionFld(UsersPermissionsFld.PREDL_MOVE_MCP);
  }

  public boolean getRenderAptp() {
    return this.sb.hasPermissionFld(UsersPermissionsFld.PREDL_MOVE_APTP);
  }

  protected boolean hasPolicySecondAgent() {
    return false;
  }

  public boolean isShowSecondAgentSection() {
    return showSecondAgentSection;
  }

  public boolean isExpanedSecondAgentSection() {
    return expanedSecondAgentSection;
  }

  public String getCntrlPolicyType() {
    if (!Tools.isEmpty(this.plcTypeOraIns)) {
      if (!this.plcTypeOraIns.isGroupTypeNone() && !Tools.isEmpty(this.plcTypeOraIns.getObjectType())) {
        return this.plcTypeOraIns.getObjectType();
      }
    }
    return this.getPlcType();
  }

  public String getPlcType() {
    return plcType;
  }

  public void setPlcType(String plcType) {
    this.plcType = plcType;
    this.fillPlcTypes(plcType);
  }

  protected void fillPlcTypes(String plcType) {
//    this.plcTypeNom = ((NomInspolicyinstype) this.nomsFacade.find(plcType, NomInspolicyinstype.class));
    this.plcTypeOraIns = this.utils.FindNom(NomInsPolicyType.class, plcType);
  }

  protected void changePlcType() {
  }

  public NomInspolicyinstype getPlcTypeNom() {
    return plcTypeNom;
  }

  public void setPlcTypeNom(NomInspolicyinstype plcTypeNom) {
    this.plcTypeNom = plcTypeNom;
  }

  public String getViewMode() {
    return viewMode;
  }

  public void setViewMode(String viewMode) {
    this.viewMode = viewMode;
    this.fs.SetViewMode(viewMode.equals(def.VIEW_MODE_VIEW), this.getViewMode(), this.getStatusFromOldData(), this.getPStatusFromOldData(), this.permEditPolicy);
//    this.klientCntrl.getFs().SetViewMode(viewMode.equals(def.VIEW_MODE_VIEW));
//    this.fs.setFsKlient(klientCntrl.getFs());
//    this.vPolzaNaCntrl.getFs().SetViewMode(viewMode.equals(def.VIEW_MODE_VIEW));
//    this.platecCntrl.getFs().SetViewMode(viewMode.equals(def.VIEW_MODE_VIEW));
    if (!viewMode.equals(def.VIEW_MODE_VIEW) && (this.operTypeNew() || this.operTypeNewByID() || this.operTypeBonusMalus() || this.operTypeReNew() || this.operTypeEditIskane() || this.operTypeEdit())) {
      this.fs.setReg_Date(!this.permChangeContractDate);
    }
    if (this.operTypeIssuePlcFromPredl()) {
      this.setViewModeIssuePlcFromPredl();
    } else {
      if (this.operTypeSecondAgent()) {
        if (this.permSecondAgent) {
          this.fs.getFsSecondAgent().SetViewMode(false);
        }
      }
    }
  }

  protected void setViewModeIssuePlcFromPredl() {
    this.fs.setReg_Date(!this.permChangeContractDate);
    this.fs.SetViewModeIssuePlcFromPredl();
    if (this.hasPolicySecondAgent()) {
      if (this.permSecondAgent) {
        this.showSecondAgentSection = true;
        this.fs.getFsSecondAgent().SetViewMode(false);
      }
//        this.expanedSecondAgentSection = true;
    }
  }

  public String getOperType() {
    return operType;
  }

  public void setOperType(String TypeMode) {
    this.operType = TypeMode;
  }

//  public String getUniqCodeAgentID() {
//    if (Tools.isEmpty(AgencyIDAgentID)) {
//      if (this.plcObj.getAg_No() != null
//              && !Tools.isEmpty(this.plcObj.getAg_No().getNomId())
//              && !Tools.isEmpty(this.plcObj.getAgentNo())) {
//        this.AgencyIDAgentID = this.plcObj.getAg_No().getNomId() + "," + this.plcObj.getAgentNo();
//      }
//    }
//    return AgencyIDAgentID;
//  }
//  public void setUniqCodeAgentID(String UniqCodeAgentID) {
//    this.AgencyIDAgentID = UniqCodeAgentID;
//  }
  private String getUniqCodeAgent() {
//    if (!Tools.isEmpty(this.sb.getCurrentAgent().getAgency()) && !Tools.isEmpty(this.sb.getCurrentAgent().getAgentId())) {
//      return (this.sb.getCurrentAgent().getAgency() + "," + this.sb.getCurrentAgent().getAgentId());
//    } else {
//      return (null);
//    }
    return null;
  }

  public List<CmdInsAgentsAgentFindRow> getPlcAgencyAgentSI() {
    if (this.plcAgencyAgentSI == null) {
      this.plcAgencyAgentSI = new ArrayList<>();
      this.plcAgencyAgentSI.add(new CmdInsAgentsAgentFindRow(0, "", def.NOM_NOT_SELECTED));
      if (!Tools.isEmpty(this.sb.getCurrentAgents())) {
        this.plcAgencyAgentSI.addAll(this.sb.getCurrentAgents());
      }
    }
    return plcAgencyAgentSI;
  }

  public SelectItem[] getSecondAgents() {
    if (this.secondAgents == null) {
      this.fillSecondAgentsItems(null);
    }
    return secondAgents;
  }

  public void setSecondAgents(SelectItem[] secondAgents) {
    this.secondAgents = secondAgents;
  }

  private void fillSecondAgentsItems(Boolean bAgentStatus) {
//    SelectItem[] items = null;
//    CmdResult<CmdInsAgentsAgentFind_Result> agnFind = null;
//    if (this.plcObj.getSecondAgentData().getAgency() != null) {
//      agnFind = this.utilsIns.agentsLoad(this.plcObj.getSecondAgentData().getAgency(), true, bAgentStatus, this.sb.sessionInfo());
//    } else {
//      if (!Tools.isEmpty(this.nomsCntrl.getNomAgenciesList())) {
//        agnFind = this.utilsIns.agentsLoad(this.nomsCntrl.getNomAgenciesList(), true, true, this.sb.sessionInfo());
//      }
//    }
//    if (agnFind != null && agnFind.isOK()) {
//      if (!Tools.isEmpty(agnFind.getResponse().getAgentsList())) {
//        int ii = 0;
//        items = new SelectItem[agnFind.getResponse().getAgentsList().size() + 1];
//        items[ii] = new SelectItem("", def.NOM_NOT_SELECTED);
//        ii++;
//        for (CmdInsAgentsAgentFindRow agn : agnFind.getResponse().getAgentsList()) {
//          items[ii++] = new SelectItem(agn, agn.toStringSecondAgent());
//        }
//      }
//    }
//    if (items == null) {
//      items = new SelectItem[1];
//      items[0] = new SelectItem("", def.NOM_NOT_SELECTED);
//    }
//    this.secondAgents = items;
  }

  public void handleSecondAgentAgencyChange(AjaxBehaviorEvent event) {
//    this.fillSecondAgentsItems(true);
//    if (this.secondAgents != null && this.secondAgents.length == 2) {
//      this.plcObj.getSecondAgentData().setAgent((CmdInsAgentsAgentFindRow) this.secondAgents[1].getValue());
//    } else {
//      this.plcObj.getSecondAgentData().setAgent(null);
//    }
//    this.handleSecondAgentAgentChange(event);
  }

  public void handleSecondAgentAgentChange(AjaxBehaviorEvent event) {
//    if (this.plcObj.getSecondAgentData().getAgent() != null) {
//      this.plcObj.getSecondAgentData().setBcCode(this.nomsFacade.findNom(this.plcObj.getSecondAgentData().getAgent().getSecAgentBAE(), NomBankCenters.class));
//    } else {
//      this.plcObj.getSecondAgentData().setBcCode(null);
//    }
  }

  /*
  public void setPlcAgencyAgentSI(SelectItem[] plcAgencyAgentSI) {
    this.plcAgencyAgentSI = plcAgencyAgentSI;
  }
   */
//  public String getUniqCodeAgentAsText() {
//    Usersagents ua = null;
//    if (!Tools.isEmpty(this.plcObj.getAgentNo())) {
//      ua = this.sb.getCurrentUser().getAgents(this.plcObj.getAgentNo());
//      if (ua != null) {
//        // TODO - а агенцията в policies може ли да е друга!?
//        this.usersFacade.LoadAgentData(ua.getUsers());
//      } else {
//        if (this.app.getVerInsOZK()) {
//          ua = this.usersFacade.LoadAgentData(this.plcObj.getAgentNo(), 0);
//        }
//      }
//    }
//    return ua == null ? null : ua.toStringNom();
//return null;
//  }
  public void annexBreakCalcDeduction(ActionEvent ae) {
    boolean bCont = true;
    if (this.plcAnnexObj.getCancelDate().before(this.plcObj.getFrom_Date())) {
      JsfUtil.addErrorMessage(Tools.getMsg("P001-055"));
      bCont = false;
    }
    if (bCont) {
      this.annexBreakCalcDeduction(null, this.plcAnnexObj, this.plcObj.getFrom_Date(), this.plcObj.getTo_Date());
    }
  }

  protected void annexBreakCalcDeduction(String policyType, PlcAnnexBase annexBreak, Date plcFromDate, Date plcToDate) {
    double annexDays = Tools.max(Tools.daysBetween(plcFromDate, this.plcAnnexObj.getCancelDate()), 0);
    double plcDays = Tools.daysBetween(plcFromDate, plcToDate) + 1;
    BigDecimal periodCoef = BigDecimal.valueOf(annexDays / plcDays);
    annexBreak.setUsedPremiaAmount(annexBreak.getAnnexPay().min(annexBreak.getAnnexPlan().multiply(periodCoef).setScale(2, RoundingMode.HALF_UP)));

    this.annexKonsSumChange(policyType, annexBreak);
  }

  public boolean renderCalcDeductionBtn() {
    return this.operTypeAnnexBreak();
  }

  public boolean renderCancelReasonTxt() {
    return (this.app.getVerInsAsset() || this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) && (this.operTypeAnnexBreak() || operTypeView() || operTypeRecover());
  }

  public boolean getRenderStornoCommis() {
    return true;
  }

  public boolean disableCancelReasonTxt() {
    return !((this.app.getVerInsAsset() || this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) && this.operTypeAnnexBreak() && this.plcAnnexObj.getCancelReasonId() != null
            && this.plcAnnexObj.getCancelReasonId().getNomId().equals(NomCancelationreason.OTHER));
  }

  public boolean printElSmtkaOnAnex(boolean bNew) {
    boolean bRet = false;
    if (!this.app.getVerInsOZOK() && !this.plcObj.getStatus().getNomId().equals(NomPolicyStatus.PREDLOJENIE_ANNEX)) {
      for (Iterator<Map.Entry<String, List<PlcPadejiBase>>> it = this.plcObj.getPadejiMap().entrySet().iterator(); it.hasNext();) {
        Map.Entry<String, List<PlcPadejiBase>> entry = it.next();
        List<PlcPadejiBase> padejiList = entry.getValue();
        if (!Tools.isEmpty(padejiList)) {
          for (PlcPadejiBase ppb : padejiList) {
            if (bNew) {
              if (ppb.getID_Padej() <= 0 && Tools.InList(ppb.getVid_Padej().getNomId(), NomMaturitytype.NDP, NomMaturitytype.STIKERI, NomMaturitytype.SERTIFI) && ppb.getData_Padej() != null && ppb.getData_Padej().compareTo(this.plcAnnexObj.getAnnexDate()) == 0) {
                bRet = true;
                break;
              }
            } else {
              if (this.plcAnnexObj != null && Tools.InList(ppb.getVid_Padej().getNomId(), NomMaturitytype.NDP, NomMaturitytype.STIKERI, NomMaturitytype.SERTIFI) && Tools.equals(ppb.getID_Anex(), this.plcAnnexObj.getAnnexId()) && ppb.getData_Padej() != null && ppb.getData_Padej().compareTo(this.plcAnnexObj.getAnnexDate()) == 0) {
                bRet = true;
                break;
              }
            }
          }
        }
        if (bRet) {
          break;
        }
      }
    }
    return bRet;
  }

  public void handle_cbVPolzaNaDFZ_OnChange(AjaxBehaviorEvent event) {
    this.handle_cbVPolzaNaDFZ_OnChange(false);
  }

  protected void handle_cbVPolzaNaDFZ_OnChange(boolean bAfterLoad) {
    if (this.plcObj.getDFZFavour()) {
      this.getFs().setPrcDFZFavour(false);
      if (!bAfterLoad) {
        this.plcObj.setPrcDFZFavour(Tools.HUNDRED);
      }
    } else {
      this.getFs().setPrcDFZFavour(true);
      if (!bAfterLoad) {
        this.plcObj.setPrcDFZFavour(BigDecimal.ZERO.setScale(2));
      }
    }
    if (!bAfterLoad) {
      this.handle_VPolzaNaDFZAmn_OnChange(null);
    }
  }

  public void handleFirstRegDateChange(AjaxBehaviorEvent event) {
//    if (this.plcObj.getPlcRow().getMpsObj().getVhFirstRegDate() != null) {
//      this.plcObj.getPlcRow().getMpsObj().setVhManifactureYear(Tools.getYearFromDate(this.plcObj.getPlcRow().getMpsObj().getVhFirstRegDate()));
//    }
  }

  public List<PlcAnnexBase> getPlcAnnexesActive() {
    List<PlcAnnexBase> plcAnexesList = null;
    if (!Tools.isEmpty(this.plcObj.getAnexesList())) {
      plcAnexesList = new ArrayList<>();
      for (Iterator it = this.plcObj.getAnexesList().iterator(); it.hasNext();) {
        PlcAnnexBase currAnnexObj = (PlcAnnexBase) it.next();
        if (currAnnexObj.getStatus().equals("T")) {
          plcAnexesList.add(currAnnexObj);
        }
      }
    }
    return plcAnexesList;
  }

  public NomCancelationreason getCancelReasonId() {
    if (this.operTypeRecover()) {
      return this.getPlcSecAnnexObj().getCancelReasonId();
    } else {
      return this.plcAnnexObj.getCancelReasonId();
    }
  }

  public void setCancelReasonId(NomCancelationreason cancelReasonId) {
    if (this.operTypeRecover()) {
      this.getPlcSecAnnexObj().setCancelReasonId(cancelReasonId);
    } else {
      this.plcAnnexObj.setCancelReasonId(cancelReasonId);
    }
  }

  public String getPlcAnnexLabel(PlcAnnexBase annexObj, boolean bLabelOnly) {
    String annexLabel = "PlcAnex_Label";
    if ((this.app.getVerInsAllianz() || this.app.getVerInsEZK() || this.app.getVerInsMVIns()) && this.operTypeRecover()) {
      annexLabel = "PlcAnex_LabelBreak";
    } else {
      if (annexObj != null && annexObj.getAnnexTypeId() != null) {
        switch (annexObj.getAnnexTypeId().getNomId()) {
          case NomAnnextype.BREAK:
            annexLabel = "PlcAnex_LabelBreak";
            break;
          case NomAnnextype.RECOVER:
            annexLabel = "PlcAnex_LabelRecover";
            break;
        }
      }
    }

    return Tools.getMsg(annexLabel);
  }

  protected String getContactCuMessage() {
    String errorMessage = null;
    String phoneNumber = utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "Policy_ContactInfo_Phone", "");
    String email = utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "Policy_ContactInfo_Email", "");
    if (Tools.isEmpty(phoneNumber)) {
      if (!Tools.isEmpty(email)) {
        errorMessage = Tools.getMsg("Plc_ContactCuEmail", email);
      }
    } else {
      if (Tools.isEmpty(email)) {
        errorMessage = Tools.getMsg("Plc_ContactCuPhoneNum", phoneNumber);
      } else {
        errorMessage = Tools.getMsg("Plc_ContactCuPhoneNumEmail", phoneNumber, email);
      }
    }
    return errorMessage;
  }

  protected boolean getbFillCustPlatec() {
    return false;
  }

  protected boolean getbFillAgencyFromCurrentAgency() {
    return true;
  }

  protected boolean getPrintAnnexBreak() {
    return false;
  }

  protected Boolean getAutoFillAgencyAgent() {
    return Tools.Str2Bool(utils.GetIniValue(def.UNIQCODE_ALL, "InsPolicy", "AutoFillAgencyAgent", "F"));
  }

  public void handle_VPolzaNaDFZAmn_OnChange(AjaxBehaviorEvent event) {
    this.WrittenPremiumChange(null);
  }

  public boolean SeatsChange() {
    return false;
  }

  public boolean getVhManifDateRequired() {
    return true;
  }

  public boolean isVhFirstRegDateRequired() {
    return true;
  }

  public boolean isVhFieldRequired() {
    return true;
  }

  public boolean isVhRegNoRequired() {
    return true;
  }

  public boolean isVhColorRequired() {
    return this.app.getVerInsAsset();
  }

  public boolean isVhRegDatesRequired() {
    return true;
  }

  public boolean isVhWheelRequired() {
    return true;
  }

  public boolean isVhSeatsCountRequired() {
    return true;
  }

  public boolean getRenderAnnexReasons() {
    return false;
  }

  public boolean renderAnexPrintBtn(PlcAnnexBase annexObj) {
    boolean bRender = annexObj != null && annexObj.getAnnexTypeId() != null;
    if (bRender && annexObj.equals(this.getAnexesList().get(this.getAnexesList().size() - 1))) {
      NomPolicyStatus plcStatus = this.getPlcOldOrSaveStatus();
      bRender = plcStatus != null && !plcStatus.getNomId().equals(NomPolicyStatus.PREDLOJENIE_ANNEX);
    }
    return bRender;
  }

  public boolean renderAnexPrintBtnInPlc() {
    return true;
  }

  public boolean getShowSearchPlcCustSec() {
    return this.operTypeNew() || this.operTypeBonusMalus();
  }

  public App getApp() {
    return app;
  }

  @Override
  public String getBlankNoName() {
    return Tools.getMsg("Plc_BlankNum");
  }

  @Override
  public boolean getRenderBlankNo() {
    return true;
  }

  @Override
  public boolean getRenderBlankType() {
    return false;
  }

  @Override
  public boolean getRenderFlManualBlankNo() {
    return this.isNewPlcByOperType() && this.sb.HasPermission(Permissions.PLC_FL_MANUAL_BLANK_NO);
  }

  @Override
  public boolean getRenderPreizdavane() {
    return true;
  }

  @Override
  public String getRenewName() {
    return Tools.getMsg("Plc_Preizd");
  }

  @Override
  public boolean getRenderComencingDate() {
    return true;
  }

  @Override
  public boolean getRenderComencingTime() {
    return true;
  }

  @Override
  public boolean getRenderExpiringDate() {
    return true;
  }

  @Override
  public boolean getRenderExpiringTime() {
    return true;
  }

  @Override
  public boolean getRenderDaysCount() {
    return false;
  }

  @Override
  public boolean getRenderContractCommission() {
    return this.permCommissions;
  }

  @Override
  public boolean getRenderContractCommissionFin() {
    return this.getRenderContractCommission();
  }

  /*
  public CustomerBaseFSC2 getFsKlient() {
    return fsKlient;
  }

  public void setFsKlient(CustomerBaseFSC2 fsKlient) {
    this.fsKlient = fsKlient;
  }

  public CustomerBaseFSC2 getFsLizingopoluchatel() {
    return fsLizingopoluchatel;
  }

  public void setFsLizingopoluchatel(CustomerBaseFSC2 fsLizingopoluchatel) {
    this.fsLizingopoluchatel = fsLizingopoluchatel;
  }

  public CustomerBaseFSC2 getFsPylnomoshtnik() {
    return fsPylnomoshtnik;
  }

  public void setFsPylnomoshtnik(CustomerBaseFSC2 fsPylnomoshtnik) {
    this.fsPylnomoshtnik = fsPylnomoshtnik;
  }

  public CustomerBaseFSC2 getFsSobstvenik() {
    return fsSobstvenik;
  }

  public void setFsSobstvenik(CustomerBaseFSC2 fsSobstvenik) {
    this.fsSobstvenik = fsSobstvenik;
  }

  public CustomerBaseFSC2 getFsVPolzaNa() {
    return fsVPolzaNa;
  }

  public void setFsVPolzaNa(CustomerBaseFSC2 fsVPolzaNa) {
    this.fsVPolzaNa = fsVPolzaNa;
  }

  public CustomerBaseFSC2 getFsPlatec() {
    return fsPlatec;
  }

  public void setFsPlatec(CustomerBaseFSC2 fsPlatec) {
    this.fsPlatec = fsPlatec;
  }
   */
  public F getFs() {
    return fs;
  }

  public BigDecimal getTaxWrittenSum() {
    return taxWrittenSum == null ? BigDecimal.ZERO.setScale(2) : taxWrittenSum;
  }

  public void setTaxWrittenSum(BigDecimal taxWrittenSum) {
    this.taxWrittenSum = taxWrittenSum;
  }

  @Override
  public BigDecimal getNadSum() {
    return nadSum == null ? BigDecimal.ZERO.setScale(2) : nadSum;
  }

  @Override
  public void setNadSum(BigDecimal nadSum) {
    this.nadSum = nadSum;
  }

  @Override
  public BigDecimal getOtsSum() {
    return otsSum == null ? BigDecimal.ZERO.setScale(2) : otsSum;
  }

  @Override
  public void setOtsSum(BigDecimal otsSum) {
    this.otsSum = otsSum;
  }

  public BigDecimal getNadSumObj() {
    return nadSumObj == null ? BigDecimal.ZERO.setScale(2) : nadSumObj;
  }

  public void setNadSumObj(BigDecimal nadSumObj) {
    this.nadSumObj = nadSumObj;
  }

  public BigDecimal getOtsSumObj() {
    return otsSumObj == null ? BigDecimal.ZERO.setScale(2) : otsSumObj;
  }

  public void setOtsSumObj(BigDecimal otsSumObj) {
    this.otsSumObj = otsSumObj;
  }

  public BigDecimal getTotalPremium() {
    return totalPremium == null ? BigDecimal.ZERO.setScale(2) : totalPremium;
  }

  public void setTotalPremium(BigDecimal totalPremium) {
    this.totalPremium = totalPremium;
  }

  public BigDecimal getTotalPlcSum() {
    return totalPlcSum == null ? BigDecimal.ZERO.setScale(2) : totalPlcSum;
  }

  public void setTotalPlcSum(BigDecimal totalPlcSum) {
    this.totalPlcSum = totalPlcSum;
  }

  @Override
  public Collection<NomMaturitytype> getNomMaturitytype() {
    if (this.nomMaturitytype == null) {
      List<String> IDs = new ArrayList<>();

      IDs.add(NomMaturitytype.NDP);

      if (this.bAnnexNew) {
        IDs.add(NomMaturitytype.VYZST_ANNEX);
        IDs.add(NomMaturitytype.VYZST_BREAK);

      }

      this.nomMaturitytype = this.nomsFacade.findAllActiveByIDs(NomMaturitytype.class, IDs);
    }
    return nomMaturitytype;
  }

  @Override
  public SelectItem[] getNomPeriod() {
    if (this.nomPeriod == null) {
      this.fillNomPeriod();
    }
    return nomPeriod;
  }

  public void fillNomPeriod() {
    List<NomPeriod> periodList = new ArrayList<>();
    if (this.bFilterPlcSrok()) {
      String pType = ",".concat(this.plcTypeOraIns.getNomId()).concat(",");
      for (NomPeriod period : this.nomsCntrl.getNomPeriodList()) {
        if (!Tools.isEmpty(period.getPlcTypes())
                && ",".concat(period.getPlcTypes()).concat(",").contains(pType)) {
          periodList.add(period);
        }
      }
    }
    if (Tools.isEmpty(periodList)) {
      this.nomPeriod = this.nomsCntrl.getNomPeriod();
    } else {
      this.nomPeriod = JsfUtil.getSelectItems(periodList, true);
    }
  }

  @Override
  public SelectItem[] getNomVal() {
    if (this.nomVal == null) {
      this.fillNomVal();
    }
    return nomVal;
  }

  protected void fillNomVal() {
    List<NomValTabl> nomList;
    if (this.canSelectAllCurrencies()) {
      nomList = this.nomsFacade.findAllActive(NomValTabl.class);
    } else {
      List<String> valIDs = new ArrayList<>();
      valIDs.add(def.BGN_CURR);
      valIDs.add(def.EURO_CURR);
      this.addCurrenciesToNomVal(valIDs);
      nomList = this.nomsFacade.findAllActiveByIDs(NomValTabl.class, valIDs);
    }
    if (this.shouldRemoveBgnCurrFromList()) {
      nomList.remove(new NomValTabl(def.BGN_CURR));
    }
    this.nomVal = JsfUtil.getSelectItems(nomList, false);
  }

  protected void addCurrenciesToNomVal(List<String> valIDs) {
  }

  protected boolean canSelectAllCurrencies() {
    return false;
  }

  private boolean shouldRemoveBgnCurrFromList() {
    boolean bRet = false;
    if (!def.SYS_CURR.equals(def.BGN_CURR)) {
      O plc = this.isNewPlcByOperType() ? this.plcObj : this.getPlcOldData();
      bRet = plc == null || Tools.isEmpty(plc.getPolicyVal()) || !Tools.equals(plc.getPolicyVal(), def.BGN_CURR);
      if (bRet) {
        bRet = this.shouldRemoveBgnCurrFromList_CheckOtherCond(plc);
      }
    }
    return bRet;
  }

  protected boolean shouldRemoveBgnCurrFromList_CheckOtherCond(O plc) {
    return true;
  }

  protected boolean bFilterPlcSrok() {
    return false;
  }

  public O getCurrent() {
    return this.plcObj;
  }

  public String getBlankNumText() {
    return blankNumText;
  }

  public String getMPSSeatsSize() {
    return MPSSeatsSize;
  }

  public SelectItem[] getNomAnnexType() {
    return nomAnnexType;
  }

  public void setNomAnnexType(SelectItem[] nomAnnexType) {
    this.nomAnnexType = nomAnnexType.clone();
  }

  public PlcAnnexBase getPlcAnnexObj() {
    return plcAnnexObj;
  }

  public SelectItem[] getNomCancelationreason() {
    return nomCancelationreason;
  }

  public void setNomCancelationreason(SelectItem[] nomCancelationreason) {
    this.nomCancelationreason = nomCancelationreason.clone();
  }

  public void setPlcAnnexObj(PlcAnnexBase plcAnnexObj) {
    this.plcAnnexObj = plcAnnexObj;
  }

  public boolean isbAnnexNew() {
    return bAnnexNew;
  }

  public PoliciesFacade getPoliciesFacade() {
    return policiesFacade;
  }

  /*
  public CustControllerBase getvPolzaNaCntrl() {
    return vPolzaNaCntrl;
  }

  public void setvPolzaNaCntrl(CustControllerBase vPolzaNaCntrl) {
    this.vPolzaNaCntrl = vPolzaNaCntrl;
  }
   */
  public String getPreUpdateFlds() {
    return preUpdateFlds;
  }
//
//  public String getAgencyIDAgentID() {
//    return AgencyIDAgentID;
//  }
//
//  public void setAgencyIDAgentID(String AgencyIDAgentID) {
//    this.AgencyIDAgentID = AgencyIDAgentID;
//  }

  public O getPlcOldData() {
    return plcOldData;
  }

  public void setPlcOldData(O plcOldData) {
    this.plcOldData = plcOldData;
  }

  public void setBlankNumText(String blankNumText) {
    this.blankNumText = blankNumText;
  }

  public O getPlcObj() {
    return plcObj;
  }

  public void setPlcObj(O plcObj) {
    this.plcObj = plcObj;
  }

  public BigDecimal getInDFZFavourPrc() {
    return inDFZFavourPrc;
  }

  public void setInDFZFavourPrc(BigDecimal inDFZFavourPrc) {
    this.inDFZFavourPrc = inDFZFavourPrc;
  }

  public List<PlcAnnexBase> getAnexesList() {
    return anexesList;
  }

  public void setAnexesList(List<PlcAnnexBase> anexesList) {
    this.anexesList = anexesList;
  }

  public boolean isbAnnexView() {
    return bAnnexView;
  }

  public String getSkipQuestions() {
    return skipQuestions;
  }

  public void setSkipQuestions(String skipQuestions) {
    this.skipQuestions = skipQuestions;
  }

  public String getChRequestQuestions() {
    return chRequestQuestions;
  }

  public void setChRequestQuestions(String chRequestQuestions) {
    this.chRequestQuestions = chRequestQuestions;
  }

  public String getPlcSearchVINLastSym() {
    return plcSearchVINLastSym;
  }

  public Map<String, List<PlcPadejiBase>> getPlcPadejiMap() {
    return plcPadejiMap;
  }

  public void setPlcPadejiMap(Map<String, List<PlcPadejiBase>> plcPadejiMap) {
    this.plcPadejiMap = plcPadejiMap;
  }

  public PlcAnnexBase getPlcSecAnnexObj() {
    return plcSecAnnexObj;
  }

  public void setPlcSecAnnexObj(PlcAnnexBase plcSecAnnexObj) {
    this.plcSecAnnexObj = plcSecAnnexObj;
  }

  public void setPlcSearchVINLastSym(String plcSearchVINLastSym) {
    this.plcSearchVINLastSym = Tools.toUC(plcSearchVINLastSym);
  }

  public PlcPadejiBase getSelectedPadejForPrint() {
    return selectedPadejForPrint;
  }

  public void setSelectedPadejForPrint(PlcPadejiBase selectedPadejForPrint) {
    this.selectedPadejForPrint = selectedPadejForPrint;
  }

  public PlcPadejiBase getEmptySelectedPadejForPrint() {
    return emptySelectedPadejForPrint;
  }

  public void setEmptySelectedPadejForPrint(PlcPadejiBase emptySelectedPadejForPrint) {
    this.emptySelectedPadejForPrint = emptySelectedPadejForPrint;
  }

  protected PlcControllerBase get2ndPlcCntrl() {
    return null;
  }

  protected void set2ndPlcCntrl() throws SQLException {

  }

  protected boolean getbPlcCombined() {
    return false;
  }

  /*
   * END getters and setters
   */
  @Override
  public void custDlgShow(Customer cust, String smallSecId, CustomerSmallBaseFSC fss) {
    custSelect.init(cust, smallSecId, CustSelectMode.CUST, fss);
  }

  public CustSelect getCustSelect() {
    return custSelect;
  }

  public boolean isbRenderNewOperBtn() {
    return bRenderNewOperBtn;
  }

  public void setbRenderNewOperBtn(boolean bRenderNewOperBtn) {
    this.bRenderNewOperBtn = bRenderNewOperBtn;
  }

  public CmdInsPlcHistoryFind_Result getPlcHistoryResult() {
    return plcHistoryResult;
  }

  public void setPlcHistoryResult(CmdInsPlcHistoryFind_Result plcHistoryResult) {
    this.plcHistoryResult = plcHistoryResult;
  }

  public PlcAnnexBase getSelectedPlcAnnex() {
    return selectedPlcAnnex;
  }

  public CmdInsPlcHistoryFind_ResultRow getSelectedPlcHistory() {
    return selectedPlcHistory;
  }

  @Override
  public Object getStoredDocsPrint() {
    return null;
  }

  public CmdListData_Result<CmdInsAgentsCommissionFind_Result> getCommissionFindResult() {
    return commissionFindResult;
  }

  public List<CmdInsAgentsCommissionFind_Result> getSelectedCommList() {
    return selectedCommList;
  }

  public void setSelectedCommList(List<CmdInsAgentsCommissionFind_Result> selectedCommList) {
    this.selectedCommList = selectedCommList;
  }

  public DataTableCustomExporter getDataTableExporter() {
    return dataTableExporter;
  }

  public TreeNode getAccumulationTree() {
    return accumulationTree;
  }

  public void setAccumulationTree(TreeNode accumulationTree) {
    this.accumulationTree = accumulationTree;
  }

  public PicturesCntrl getPicturesCntrl() {
    return picturesCntrl;
  }

  public CustContactsController getCustContCntrl() {
    return custContCntrl;
  }

}
