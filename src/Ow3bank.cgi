#!/usr/bin/perl

############ Дефинираме пакет за приложението ########################################

package Ow3bank;  # Главен пакет на приложението
use strict;       # Настройва PERL да мрънка за всички недоуточнености.
# ~bc_if_def WARNINGS_FATAL
use warnings FATAL => 'all';
=pod
 ~bc_else
use warnings;
=cut
# ~bc_end_if WARNINGS_FATAL

############ Зареждане на стандартни библиотеки ########################################

use HTML::Template;               # Готова библиотека от Internet за обработка на HTML темплейти
use CGI qw(-compile :standard );  # Зарежда библиотеката CGI
use CGI::Carp qw( fatalsToBrowser set_message );
use threads;
use POSIX qw(strftime);

BEGIN {

  sub HandleErrors {
    my($ErrorMsg)  = shift;
    my(%DTemplate) = ();
    my(%DataRef)   = ();

    &ToolsW3User::WriteLog($Ow3bank::LOG_ERROR, $ErrorMsg.'('.&ToolsW3User::GetCallStack(0, 6).')');

    if ($Ow3bank::gEmptyLoadingPageMsg) {
      &ToolsW3User::GenerateLoadingPageMsg(\%DTemplate);
    }
    &ShowResult(\%DTemplate, \%DataRef, $Ow3bank::ID_ERR_SYSTEM_ERROR);
  }
  set_message(\&HandleErrors);
}

use Date::Calc qw ( check_date Day_of_Year Decode_Date_EU Add_Delta_Days );
use Time::HiRes qw( gettimeofday );
use DBD::Oracle qw( :ora_types );
use Text::CSV_XS;
use MIME::Base64;
use Encode;
use Crypt::OpenSSL::RSA;
$CGI::POST_MAX = 1024*30000;  # max 30MB posts
use LWP::UserAgent;
use OpenThought;

use Digest::SHA1 qw(sha1_hex);
use Digest::HMAC_MD5 qw(hmac_md5_hex);
use PDF::WebKit;
use List::MoreUtils qw(first_index);
use Math::Random;
use Crypt::DH;
use Crypt::Random qw( makerandom );
use Crypt::Primes qw( maurer );
use URI::Escape qw( uri_escape );
use Number::Format;
use JSON;

#  $CGI::DISABLE_UPLOADS = 1;       # no uploads

############ Буфериране на STDOUT ########################################
# За да не се буферира изхода към STDOUT е необходимо да се разкоментират следните редове:
# Под cgi-bin - противно на написаното в документацията '$| = 1;', както и 'use English;$OUTPUT_AUTOFLUSH=1;' не работят!
#use IO::Handle;
#STDOUT->autoflush(1);
# Под mod_perl - долните два реда трябва да са разкоментирани, както и редовете в сорса, които гласят '$Ow3bank::requestIO->rflush();'
use Apache2::RequestIO ();
$Ow3bank::requestIO = shift;

############ Зареждане на потребителски библиотеки ########################################
use lib '/data/www2/perl/Transact/user/lib';  # Добавя пътека към библиотеките ??? - ако се напълни от променлива, гърми.
use OmCSessionW3User;                      # Библиотека за работа със сесиите
use OmCUserW3User;
use OmUserStringsW3User;
use OmToolsW3User;
use OmDBAccessW3User;
use OmSumSubW3User;

# TODO: Всички .pl трябва да станат на .pm

require 'OlHBank.pl';                # Библиотека с процедури, специфични за W3H.
require 'OlCommon.pl';               # Библиотека с общи процедури.
require 'OlPicture.pl';              # Библиотека с функции за пикчъросване.

require 'OlProcessOPID_SMETKI.pl';
require 'OlProcessOPID_SYSTEM.pl';
require 'OlProcessOPID_TRANS.pl';
require 'OlProcessOPID_REPORT.pl';
require 'OlProcessOPID_REQUEST.pl';

require 'OlTeh_SMETKI.pl';
require 'OlTeh_TRANS.pl';
require 'OlTeh_VALIDATE.pl';
require 'OlTeh_REPORT.pl';
require 'OlTeh_SECURITY.pl';
require 'OlRTFConf.pl';
require 'OlTeh_REQUEST.pl';
require 'OlTeh_REG_CUST.pl';

require 'admin/OlTeh_W3A_ADMIN.pl';          # Библиотека с процедури за администриране на системата.
require 'admin/OlTeh_W3A_VALIDATE.pl';       # Библиотека с процедури за валидация на данните от HTML формата.
require 'admin/OlProcessOPID_W3A_ADMIN.pl';  # Библиотека с процедури за обработка на OPID-ите.

require 'bank/OlTeh_BankW3_VALIDATE.pl';            # Библиотека с процедури за валидация на данните от HTML формата.
require 'bank/OlTeh_BankW3_Operations.pl';          # Библиотека с процедури за заявки и операции, свързани с тях, които се извършват през банковия модул
require 'bank/OlTeh_BankW3_REPORT.pl';              # Библиотека с процедури за обработка на OPID-ите.
require 'bank/OlProcessOPID_BankW3_Operations.pl';  # Библиотека с процедури за обработка на OPID-ите за заявки и операции, свързани с тях, които се извършват през банковия модул
require 'bank/OlProcessOPID_BankW3_REPORT.pl';      # Библиотека с процедури за обработка на OPID-ите.

################## MAIN #########################################################################################
&main();

sub main {
# ~bc_if_def USER_WWW
  $Ow3bank::DEFAULT_LANGUAGE = 'EN';
=pod
 ~bc_else
  $Ow3bank::DEFAULT_LANGUAGE = 'BG';
=cut
# ~bc_end_if USER_WWW

  $Ow3bank::gUI_MSG_TYPE       = 0;
  $Ow3bank::bValidatingRequest = 0;
  $Ow3bank::oCGI               = new CGI;
  my($RequestData) = ();
  $RequestData       = $Ow3bank::oCGI->Vars;  # Изчитаме данните, предадени по HTTP POST
  $Ow3bank::oSession = ();

  $Ow3bank::RequestData = {%$RequestData};
  for (keys %$Ow3bank::RequestData) {
    $Ow3bank::RequestData->{$_} = &ToolsW3User::UTF8_to_cp1251($Ow3bank::RequestData->{$_});
  }

  if (!$RequestData->{'ACTION'}) {

    # При заявка от ефактура ACTION-a се подава като GET параметър
    my($ActionGET) = $Ow3bank::oCGI->url_param('ACTION');
    if (
        $ActionGET &&
        ($ActionGET eq 'EFAKT_REQUEST' ||
         $ActionGET eq 'EFAKT_STATUSCHECK' ||
         $ActionGET eq 'PSD2_CONSENT_REQUEST' ||
         $ActionGET eq 'PSD2_PAYBUFO_REQUEST' ||
         $ActionGET eq 'PSD2_PREVOUT_REQUEST' ||
         $ActionGET eq 'PSD2_AUTHENTICATION_REQUEST')
      ) {
      $RequestData->{'ACTION'} = $ActionGET;
    }
  }

  my(%StatisticsData) = ();  # Тук ще пазим данните за начало на изпълнение на OPID и др., който се отразяват в Statistics
  $StatisticsData{'OPID_START'} = &ToolsW3User::GetCurrentDateTimeString('dd.mm.yyyy hh:mn:ss');

  my(%DataForm)      = ();   # Тук ще пазим обработените данни от параметрите предаадени по HTTP
  my(%DTemplate)     = ();   # Тук ще пазим данните, които ще се изпращат към потребителя.
  my(%DTemplateAjax) = ();   # Тук ще пазим данните, които ще се изпращат към потребителя когато заявката е AJAX.
  my(%HBankEnv)      = ();
  my($ErrCGI)        = 0;

  if (!&ToolsW3User::ReplaceRemoteAddress()) {
    $ErrCGI = $Ow3bank::ID_ERR_SYSTEM_ERROR;
  }

  $Ow3bank::gSID    = $RequestData->{'SID'};  # global Session ID
  $Ow3bank::gUserID = '';
  $Ow3bank::gOPID   = '';

  if (
      !$Ow3bank::gLanguage ||
      ($Ow3bank::gLanguage ne 'BG' &&
       $Ow3bank::gLanguage ne 'EN') ||
      !$RequestData->{'ACTION'} ||
      $RequestData->{'ACTION'} eq 'ACCESS'
    ) {
    if ($RequestData->{'LANGUAGE'} && &inListS($RequestData->{'LANGUAGE'}, ['BG', 'EN'])) {
      $Ow3bank::gLanguage = $RequestData->{'LANGUAGE'};
    } else {
      $Ow3bank::gLanguage = $Ow3bank::DEFAULT_LANGUAGE;
    }
  }
  $Ow3bank::gLanguage            = uc($Ow3bank::gLanguage);
  $Ow3bank::gEmptyContentType    = 1;
  $Ow3bank::gEmptyLoadingPageMsg = 1;

  ($Ow3bank::gSecStampBegin, $Ow3bank::gMicroStampBegin) = gettimeofday();
  $Ow3bank::gMicroStampBegin = int($Ow3bank::gMicroStampBegin/1000);
  $Ow3bank::gMicroStampBegin = sprintf("%03d", $Ow3bank::gMicroStampBegin);

  &SetGlobal();  # Инициализира работната среда за приложението

  &ToolsW3User::SetGlobalOPID();  # Инициализира хеша с OPID-и

  if ($Ow3bank::oCGI->cgi_error()) {
    &ToolsW3User::WriteLog($Ow3bank::LOG_ERROR, $Ow3bank::oCGI->cgi_error());
    $ErrCGI = $Ow3bank::ID_ERR_SYSTEM_ERROR;
  }

  if ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User &&
      &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome', 'DisableOPIDAccess', 'F') eq $Ow3bank::TRUE) {
    if (!$ENV{'SSL_CLIENT_M_SERIAL'} && $RequestData->{'SSL_CLIENT_M_SERIAL'}) {
      $ENV{'SSL_CLIENT_M_SERIAL'} = $RequestData->{'SSL_CLIENT_M_SERIAL'};
    }
    if (!$ENV{'SSL_SERVER_M_SERIAL'} && $RequestData->{'SSL_SERVER_M_SERIAL'}) {
      $ENV{'SSL_SERVER_M_SERIAL'} = $RequestData->{'SSL_SERVER_M_SERIAL'};
    }
    if (!$ENV{'SSL_CLIENT_V_END'} && $RequestData->{'SSL_CLIENT_V_END'}) {
      $ENV{'SSL_CLIENT_V_END'} = $RequestData->{'SSL_CLIENT_V_END'};
    }
    delete $RequestData->{'SSL_CLIENT_M_SERIAL'};
    delete $RequestData->{'SSL_SERVER_M_SERIAL'};
    delete $RequestData->{'SSL_CLIENT_V_END'};
  } else {
    if (!$RequestData->{'ACTION'}) {
      $RequestData->{'ACTION'} = 'ACCESS';
    }
  }

  &PrepareHTTPData($RequestData, \%DataForm);

  if (!$RequestData->{'ACTION'}) {
    $ErrCGI = $Ow3bank::ID_ERR_SYSTEM_ERROR;
  }
  if (&ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_SHOW_PAY_INFO_DOC ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_SHOW_PRODUCT_DOGOVOR ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_SHOW_CONTRACT ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_SHOW_SERTIF_INSTRUCTIONS ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_DOWNLOAD_ZIP_FILE ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_ORACAM_GET_BLOB ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_SHOW_CRED_CARD_IZVL_DETAILS_PDF ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_PRINT_BLOB_PDF ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_CAPTCHA_GET ||
      &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_HEALTH_CHECK) {

    # TODO: това изброяване е време да се оправи. ама не му е сега времето :-D
    $Ow3bank::gEmptyContentType = 1;
  } elsif (exists $RequestData->{'XML_PREPARE'}) {
    my $charset = 'UTF-16';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
    print "Content-Type: application/xml;charset=$charset;\r\nContent-Disposition: attachment;\r\n\n";
    $Ow3bank::gEmptyContentType = 0;
  } elsif ((exists $RequestData->{'PDF_PREPARE'}) ||
           &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFO_PDF) {
    if (-e $Ow3bank::HBankEnv{'PDF_TOOL_PATH'}) {
      $Ow3bank::gEmptyContentType = 1;
    } else {
      print "Content-Type: text/html;\r\n\n";
      $Ow3bank::gEmptyContentType = 0;
      $ErrCGI                     = $Ow3bank::ID_STR_PDF_TOOL_NOT_FOUND;
    }
  } elsif (&ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_EFAKT_STATUSCHECK) {
    print "Content-Type: text/plain\r\n\n";
    $Ow3bank::gEmptyContentType = 0;

    #} elsif (&ToolsW3User::DeCryptOPID($RequestData->{'ACTION'}) == $Ow3bank::OPID_NEW_TAN) {

    #my $charset = 'windows-1251';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
    #print "Content-Type: text/html;charset=$charset\r\n\n";
    #$Ow3bank::gEmptyContentType    = 1;
    #$Ow3bank::gEmptyLoadingPageMsg = 1;
  } elsif (not exists $RequestData->{'EXEL_PREPARE'}) {
    my $charset = 'UTF-8';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
    print "Content-Type: text/html;charset=$charset\r\n\n";
    $Ow3bank::gEmptyContentType = 0;
  } else {
    print "Content-Type: application/vnd.ms-excel;charset=windows-1251\r\n\n";
    $Ow3bank::gEmptyContentType = 1;
  }

  &GenerateStatistics($Ow3bank::STAT_INSERT_NEW, \%StatisticsData, $RequestData);
  $Ow3bank::gStatisticsID = $StatisticsData{'FLD_ID'};

  # валидира се за блокирано IP
  if (&ToolsW3User::CheckValidityOfHTMLRequest($ENV{'REMOTE_ADDR'}))  # TODO - Да се разпише тази функция. Описана е в lHBank.pl
  {
    $StatisticsData{'ID_ERR'} = $Ow3bank::ID_ERR_ACCESS_DENIED;
    &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);

    &ToolsW3User::GenerateLoadingPageMsg($RequestData);
    &ToolsW3User::WriteError($Ow3bank::ID_ERR_ACCESS_DENIED);
  }

  if (&IsTimeForAdministrativeMode()) {
    &ToolsW3User::GenerateLoadingPageMsg($RequestData);
    &ShowResult(\%DTemplate, \%DataForm, $Ow3bank::ID_ERR_SYSTEM_BUSY);
  }

=pod
 ~bc_if_def ADMIN_WWW
  if (&IsAccessList())  # Ako imame ograni4enie na IP adresi za modula
  {
    if (not &IsIpInAccessList($ENV{'REMOTE_ADDR'})) {
      if (!$Ow3bank::gEmptyContentType) {
        &ToolsW3User::GenerateLoadingPageMsg($RequestData);
      }
      &ToolsW3User::WriteError($Ow3bank::ID_ERR_ACCESS_DENIED);
    }
  }
=cut
# ~bc_end_if ADMIN_WWW

=pod
 ~bc_if_def BANK_WWW
  &ValidateHTTPData($RequestData, \%DataForm, \%DTemplate);
=cut
# ~bc_end_if BANK_WWW

  $DataForm{'OPID'}       = &ToolsW3User::DeCryptOPID($RequestData->{'ACTION'});
  $StatisticsData{'OPID'} = $DataForm{'OPID'};

  $Ow3bank::gOPID = ${$Ow3bank::OPID{$DataForm{'OPID'}}}[0];  #$Dummy;
  $Ow3bank::gOPID = '' unless $Ow3bank::gOPID;
  &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "OPID_START : ".$Ow3bank::gOPID);
  &DBW3User::dbms_set_module("OPID_START=".$Ow3bank::gOPID);

  $StatisticsData{'OPID_PARAMS'} = &ToolsW3User::ParamsHash($RequestData, 1);
  &ToolsW3User::WriteLog($Ow3bank::LOG_PARAMS, "PARAMS :     ".$StatisticsData{'OPID_PARAMS'});

  #///////////////////////////////////////////////////////////////////////////////////////////////////////

  if ($ErrCGI) {
    &ShowResult(\%DTemplate, \%DataForm, $ErrCGI);
  }

  if ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User) {
    if ($DataForm{'OPID'} == $Ow3bank::OPID_CONNECT_AND_LOGIN) {
      $DataForm{'SID'}           = $RequestData->{'SID'};
      $DataForm{'USER_NAME'}     = $RequestData->{'USER_NAME'};
      $DataForm{'USER_PASSWORD'} = $RequestData->{'USER_PASSWORD'};
      $DataForm{'CAPTCHA'}       = $RequestData->{'CAPTCHA'};

      #$Ow3bank::gLanguage        = $RequestData->{'LANGUAGE'};
      &SetInterfaceLang($Ow3bank::oSession->GetInterfaceLang());
      &ProcessOPID_CONNECT_AND_LOGIN(\%DTemplate, \%DataForm, \%StatisticsData);
      $StatisticsData{'ACTION'}     = 'CONNECT_LOGIN';
      $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
      $Ow3bank::HBankEnv{'SID'}     = $DTemplate{'SID'};
      &CalculateTime(\%StatisticsData);
      &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
      &ShowResult(\%DTemplate, \%DataForm);
    }
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_ACCESS) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    $StatisticsData{'ACTION'}     = 'CONNECT';
    $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_EFAKT_REQUEST) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    &ProcessOPID_EFAKTURA_REQUEST(\%DTemplate, \%DataForm, $RequestData);
    $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ToolsW3User::GenerateLoadingPageMsg($RequestData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_EFAKT_STATUSCHECK) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    &ProcessOPID_EFAKT_STATUSCHECK(\%DTemplate, $RequestData);
    $DataForm{'EFAKTURA_RESP'}    = $RequestData->{'EFAKTURA_RESP'};
    $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_CONSENT_REQUEST) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    &ProcessOPID_PSD2_CONSENT_REQUEST(\%DTemplate, \%DataForm, $RequestData);
    $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_PAYBUFO_REQUEST) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    &ProcessOPID_PSD2_PAYBUFO_REQUEST(\%DTemplate, \%DataForm, $RequestData);
    $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_PREVOUT_REQUEST) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    &ProcessOPID_PSD2_PREVOUT_REQUEST(\%DTemplate, \%DataForm, $RequestData);
    $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_AUTHENTICATION_REQUEST) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    &ProcessOPID_PSD2_AUTHENTICATION_REQUEST(\%DTemplate, \%DataForm, $RequestData);
    $StatisticsData{'SESSION_ID'} = $DTemplate{'SID'};
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if ($DataForm{'OPID'} == $Ow3bank::OPID_HEALTH_CHECK) {
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm);
  }

=pod
 ~bc_if_def BANK_WWW
  if ($DataForm{'OPID'} == $Ow3bank::OPID_GET_REQUEST_HTML) {
    $DataForm{'CALLED_FROM_DAEMON'} = 1;
    &ProcessOPID_ACCESS(\%DTemplate, \%DataForm);
    $Ow3bank::gSID = $DTemplate{'SID'};
    $DataForm{'SID'} = $DTemplate{'SID'};
  }
=cut
# ~bc_end_if BANK_WWW
  #///////////////////////////////////////////////////////////////////////////////////////////////////////

  # Във всички следващи случи SID вече е генериран

  if ($DataForm{'OPID'} != $Ow3bank::OPID_GET_REQUEST_HTML) {
    $DataForm{'SID'} = $RequestData->{'SID'};
  }
  $Ow3bank::HBankEnv{'SID'}     = $DataForm{'SID'};
  $StatisticsData{'SESSION_ID'} = $Ow3bank::HBankEnv{'SID'};

  if (!$Ow3bank::gOPID && $RequestData->{'ACTION'}) {
    &ToolsW3User::WriteError($Ow3bank::ID_ERR_INVALID_OPID);
  }

  if (!$DataForm{'OPID'} ||
      $DataForm{'OPID'} == $Ow3bank::OPID_EXT_USER_REG ||
      $DataForm{'OPID'} == $Ow3bank::OPID_EXT_USER_ACTIVATE_MAIL) {

    # Във всички други случаи SID вече е генериран
  } else {
    if (!$DataForm{'SID'}) {

      #  &CalculateTime(\%StatisticsData);
      $StatisticsData{'ID_ERR'} = $Ow3bank::ID_ERR_EMPTY_SID_FIELD;
      &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);
      &ToolsW3User::WriteError($Ow3bank::ID_ERR_EMPTY_SID_FIELD);
    }
  }

  #///////////////////////////////////////////////////////////////////////////////////////////////////////

  if ($DataForm{'OPID'} == $Ow3bank::OPID_LOGIN_VERIFICATION) {
    &SetInterfaceLang($RequestData->{'LANGUAGE'});
    if (!&ValidateLoginData($RequestData, \%DataForm)) {

      #&ToolsW3User::WriteLoginAttempt($RequestData, 'F');
      $StatisticsData{'ID_ERR'} = $Ow3bank::ID_ERR_INVALID_PASSWORD;
      &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);
      &ToolsW3User::WriteError($Ow3bank::ID_ERR_INVALID_PASSWORD);
    }

# ~bc_if_def USER_WWW
    &ProcessOPID_LOGIN_VERIFICATION(\%DTemplate, \%DataForm, \%StatisticsData);
# ~bc_end_if USER_WWW

=pod
 ~bc_if_def BANK_WWW
    &ProcessOPID_LOGIN_VERIFICATION_BM(\%DTemplate, \%DataForm, \%StatisticsData);
=cut
# ~bc_end_if BANK_WWW

=pod
 ~bc_if_def ADMIN_WWW
    &ProcessOPID_LOGIN_VERIFICATION_AM(\%DTemplate, \%DataForm, \%StatisticsData);
=cut
# ~bc_end_if ADMIN_WWW

    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    &ShowResult(\%DTemplate, \%DataForm, 0);
  }

  #///////////////////////////////////////////////////////////////////////////////////////////////////////

  $Ow3bank::oSession = OCSessionW3User->New(\%DataForm, \%Ow3bank::HBankEnv);
  my($nError) = $Ow3bank::oSession->GetLastError();

  $Ow3bank::gSID    = $Ow3bank::oSession->GetSID();
  $Ow3bank::gUserID = $Ow3bank::oSession->GetUserID();

  &SetInterfaceLang($Ow3bank::oSession->GetInterfaceLang());

=pod
 ~bc_if_not_def USER_WWW
  @Ow3bank::RightsArr = split(/\,/, ${&GetCurrentBankUserRights($Ow3bank::gUserID, 0)});
=cut
# ~bc_end_if USER_WWW

  if ($DataForm{'OPID'} == $Ow3bank::OPID_CHANGE_LANGUAGE) {
    &SetInterfaceLang($RequestData->{'LANGUAGE'});
    &ToolsW3User::ProcessOPID_CHANGE_LANGUAGE(\%DTemplate, \%DataForm);
    &CalculateTime(\%StatisticsData);
    &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
    if ($Ow3bank::oSession->GetUserID()) {
      &ToolsW3User::GenerateLoadingPageMsg($RequestData);
      $DTemplate{'UNREAD_MSG_CNT'} = &HasUnReadedBankMsg($Ow3bank::oSession->GetUserID());
    }
    &ShowResult(\%DTemplate, \%DataForm);
  }

  if (
    $RequestData->{'ACTION'} ne 'SHOW_SERTIF_INSTRUCTIONS' &&
    $RequestData->{'ACTION'} ne 'DOWNLOAD_ZIP_FILE' &&
    $RequestData->{'ACTION'} ne 'SHOW_CRED_CARD_IZVL_DETAILS_PDF' &&
    $RequestData->{'ACTION'} ne 'OPID_PRINT_BLOB_PDF' &&

    #$RequestData->{'ACTION'} ne 'NEW_TAN' &&
    $RequestData->{'ACTION'} ne 'CAPTCHA_GET' && !$RequestData->{'AJAX_CALL'}
    ) {
    &ToolsW3User::GenerateLoadingPageMsg($RequestData);
  }

  if ($nError != $Ow3bank::ERR_NO_ERROR) {
    $StatisticsData{'ID_ERR'} = $nError;
    &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);
    &ToolsW3User::WriteError($nError);
  }

  if ($DataForm{'OPID'} != $Ow3bank::OPID_SIGN_OUT &&
      $DataForm{'OPID'} != $Ow3bank::OPID_SHOW_CONDITIONS &&
      $DataForm{'OPID'} != $Ow3bank::OPID_SHOW_TAN_BY_SMS_ON_LOGIN &&
      $DataForm{'OPID'} != $Ow3bank::OPID_CAPTCHA_GET &&
      $DataForm{'OPID'} != $Ow3bank::OPID_EXT_USER_REG &&
      $DataForm{'OPID'} != $Ow3bank::OPID_EXT_USER_ACTIVATE_MAIL) {
    if ((($Ow3bank::oSession->IsUserFirstAcc) || &IsUserExpired($Ow3bank::oSession->GetUserID())) &&
        ($DataForm{'OPID'} != $Ow3bank::OPID_PASS_CHNG_CONF) &&
        ($DataForm{'OPID'} != $Ow3bank::OPID_PASS_CHNG_CONF_BM) &&
        ($DataForm{'OPID'} != $Ow3bank::OPID_REJECT_CHNG_PASS) &&
        ($DataForm{'OPID'} != $Ow3bank::OPID_SEND_TAN_BY_SMS) &&
        ($DataForm{'OPID'} != $Ow3bank::OPID_SEND_TAN_BY_SMS_AJAX) &&
        ($DataForm{'OPID'} != $Ow3bank::OPID_ZUI_TAN_BY_SMS_AUTH)) {
      if ($Ow3bank::oSession->GetRightOTP()) {
        $DataForm{'OPER_TYPE'} = 'PIN';
      } else {
        $DataForm{'OPER_TYPE'} = 'PSW';
      }
      $DataForm{'OPID'} = $Ow3bank::OPID_PASS_CHNG;
      $Ow3bank::oSession->SetIS_ACTIVE('T');
      $Ow3bank::oSession->UpdateSession();
    }
# ~bc_if_def USER_WWW
    else {
      $DTemplate{'UNREAD_MSG_CNT'} = &HasUnReadedBankMsg($Ow3bank::oSession->GetUserID());
    }
# ~bc_end_if USER_WWW
  }

  &DBW3User::dbms_set_module("OPID_PRE_VALIDATE_START=".$Ow3bank::gOPID);
  if (&PreValidateData(\%DataForm, \%StatisticsData, \%DTemplateAjax) == 0) {
    &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);
    &DBW3User::dbms_set_module("OPID_PRE_VALIDATE_FINISHED_ERR=".$Ow3bank::gOPID);
  } else {
    &DBW3User::dbms_set_module("OPID_PRE_VALIDATE_FINISHED_OK=".$Ow3bank::gOPID);
  }

  my($AccessError) = &VerifyAccess(\%DataForm);

  if ($AccessError || $DataForm{'OPID'} eq 'INVALID') {
    $StatisticsData{'ID_ERR'} = $Ow3bank::ID_ERR_SEQURITY_VIOLATION;
    &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);
    &ToolsW3User::WriteError($Ow3bank::ID_ERR_SEQURITY_VIOLATION, $AccessError);
  }

  #замества в %DataForm всички единични и двойни кавички с интервал
  if ($DataForm{'OPID'} && $DataForm{'OPID'} != $Ow3bank::OPID_SAVE_VAL) {
    foreach (keys %DataForm) {
      if (defined $DataForm{$_}) {
        $DataForm{$_} =~ s/\"/ /g;  #замества " с интервал
        $DataForm{$_} =~ s/\'/ /g;  #замества ' с интервал
      }
    }
  }

  #///////////////////////////////////////////////////////////////////////////////////////////////////////
  # Ако сме в демо версията, не може да се правят - запис, оторизация и изтриване
  # !!! Задължително всички OPID-и за запис, оторизация и изтриване се описват във функцията CheckOPID !!!
  #///////////////////////////////////////////////////////////////////////////////////////////////////////

  if ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User) {
    if ($Ow3bank::HBankEnv{'DEMO_VERSION'} eq $Ow3bank::TRUE) {
      &CheckOPID(\%DataForm);
    }
    if ($Ow3bank::oSession->GetUserField('USER_REG_PROCESSING')) {
      if (
          !&inListN(
                    $DataForm{'OPID'},
                    [
                     $Ow3bank::OPID_SIGN_OUT,           $Ow3bank::OPID_CLOSE_SESSION,     $Ow3bank::OPID_PASS_CHNG,                $Ow3bank::OPID_PASS_CHNG_CONF,
                     $Ow3bank::OPID_LOCK_ACCOUNT,       $Ow3bank::OPID_LOCK_ACCOUNT_CONF, $Ow3bank::OPID_REJECT_CHNG_PASS,         $Ow3bank::OPID_EXCEL_SETTINGS_FORM,
                     $Ow3bank::OPID_SET_EXCEL_SETTINGS, $Ow3bank::OPID_SEND_TAN_BY_SMS,   $Ow3bank::OPID_SHOW_TAN_BY_SMS_ON_LOGIN, $Ow3bank::OPID_SEND_TAN_BY_SMS_AJAX,
                     $Ow3bank::OPID_LOGIN_CHNG, $Ow3bank::OPID_LOGIN_CHNG_CONF, $Ow3bank::OPID_LOGIN_VERIFICATION, $Ow3bank::OPID_LOGIN_VERIFICATION_BY_TAN, $Ow3bank::OPID_AJAX_VALIDATION,
                     $Ow3bank::OPID_ZUI_SHOW,           $Ow3bank::OPID_ZUI_TAN_BY_SMS_AUTH, $Ow3bank::OPID_ZUI_TAN_BY_SMS_REJECT, $Ow3bank::OPID_EXT_USER_REG,   $Ow3bank::OPID_EXT_USER_ACTIVATE_MAIL, $Ow3bank::OPID_REG_CUST_SHOW,
                     $Ow3bank::OPID_REG_CUST_SHOW_LAST, $Ow3bank::OPID_REG_CUST_SAVE1,      $Ow3bank::OPID_REG_CUST_SAVE2,        $Ow3bank::OPID_REG_CUST_SAVE3, $Ow3bank::OPID_SHOW_PAY_INFO_DOC
                    ]
                   )
        ) {
        $DataForm{'OPID'} = $Ow3bank::OPID_SIGN_OUT;
        $Ow3bank::oSession->CloseSession();
      }
    }
  }

  #///////////////////////////////////////////////////////////////////////////////////////////////////////
  #  От тук надолу могат да се редят всички останали действия, извършвани от системата.
  #///////////////////////////////////////////////////////////////////////////////////////////////////////

  if (
      ((!$Ow3bank::oSession->GetPSD2ConsentID()) && (!$Ow3bank::oSession->GetPSD2AuthenticationID()) && (!$Ow3bank::oSession->GetPSD2PaybufoID()) && (!$Ow3bank::oSession->GetPSD2PrevoutID())) ||
      ($DataForm{'OPID'} != $Ow3bank::OPID_ZUI_SHOW &&
       $DataForm{'OPID'} != $Ow3bank::OPID_ZUI_TAN_BY_SMS_AUTH &&
       $DataForm{'OPID'} != $Ow3bank::OPID_ZUI_TAN_BY_SMS_REJECT)
    ) {
    &MarkMenuByOPID(\%DTemplate, \%DataForm);
  }

  my $action = &ToolsW3User::EnCryptOPID($DataForm{'OPID'});
  if ($DataForm{'AJAX_CALL'} && $DataForm{'ERROR_FOUND'}) {

    # ако е AJAX и има грешка при валидация - не искаме да изпълнява OPID-a
    &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "PROCESS_OPID $action: SKIP");
  } else {
    &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "PROCESS_OPID $action: BEGIN");

# ~bc_if_def USER_WWW
    if ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNTS) {&ProcessOPID_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_MOVING) {&ProcessOPID_ACCOUNT_MOVING(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_PAYMENTS) {&ProcessOPID_ACCOUNT_PAYMENTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_INFO) {&ProcessOPID_ACCOUNT_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI)      {&ProcessOPID_ACCOUNT_PARAGONI(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_IBAN) {&ProcessOPID_ACCOUNT_PARAGONI(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFO) {&ProcessOPID_ACCOUNT_PARAGONI_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFOXML) {&ProcessOPID_ACCOUNT_PARAGONI_INFOXML(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFO_PRINT) {&ProcessOPID_ACCOUNT_PARAGONI_INFO_PRINT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFO_PDF) {&ProcessOPID_ACCOUNT_PARAGONI_INFO_PDF(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_MOVING_FORM) {&ProcessOPID_MOVING_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_MOVING_INFO) {&ProcessOPID_MOVING_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATE_SALDO) {&ProcessOPID_DATE_SALDO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VALIOR_SALDO) {&ProcessOPID_VALIOR_SALDO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CLIENTS) {&ProcessOPID_CLIENTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CLIENT_ACCS) {&ProcessOPID_CLIENT_ACCS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_VAL_FIX_FORM) {&ProcessOPID_SHOW_VAL_FIX_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_VAL_FIX) {&ProcessOPID_SHOW_VAL_FIX(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_BANK_MSG_FORM) {&ProcessOPID_SHOW_BANK_MSG_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_BANK_MSG_LIST) {&ProcessOPID_SHOW_BANK_MSG_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_BANK_MSG_INFO) {&ProcessOPID_SHOW_BANK_MSG_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_ZAPORI) {&ProcessOPID_ACCOUNT_ZAPORI(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT) {&ProcessOPID_NEW_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_SAVE) {&ProcessOPID_NEW_ACCOUNT_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_EDIT) {&ProcessOPID_NEW_ACCOUNT_EDIT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIEW) {&ProcessOPID_NEW_ACCOUNT_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_O) {&ProcessOPID_NEW_ACCOUNT_O(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN) {$Ow3bank::oSession->VirtualIBANReq() ? &ProcessOPID_NEW_ACCOUNT_VIRTUAL_IBAN(\%DTemplate, \%DataForm) : 0;}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_SAVE) {$Ow3bank::oSession->VirtualIBANReq() ? &ProcessOPID_NEW_ACCOUNT_VIRTUAL_IBAN_SAVE(\%DTemplate, \%DataForm) : 0;}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_EDIT) {$Ow3bank::oSession->VirtualIBANReq() ? &ProcessOPID_NEW_ACCOUNT_VIRTUAL_IBAN_EDIT(\%DTemplate, \%DataForm) : 0;}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_VIEW) {$Ow3bank::oSession->VirtualIBANReq() ? &ProcessOPID_NEW_ACCOUNT_VIRTUAL_IBAN_VIEW(\%DTemplate, \%DataForm) : 0;}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_O) {$Ow3bank::oSession->VirtualIBANReq() ? &ProcessOPID_NEW_ACCOUNT_VIRTUAL_IBAN_O(\%DTemplate, \%DataForm) : 0;}

    ####### Раплащания
    ################## 311
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_311) {&ProcessOPID_NEW_311(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_311) {&ProcessOPID_SAVE_311(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_311) {&ProcessOPID_EDIT_311(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_311) {&ProcessOPID_O_311(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_311) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    ################## 312
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_312) {&ProcessOPID_NEW_312(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_312) {&ProcessOPID_SAVE_312(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_312) {&ProcessOPID_EDIT_312(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_312) {&ProcessOPID_O_312(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_312) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_312) {&ProcessOPID_VIEW_312(\%DTemplate, \%DataForm);}

    ################## 313
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_313) {&ProcessOPID_NEW_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_313) {&ProcessOPID_SAVE_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_313) {&ProcessOPID_EDIT_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_313) {&ProcessOPID_O_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_313) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    ################## INCASO
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_INCASO) {&ProcessOPID_NEW_INCASO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_INCASO) {&ProcessOPID_SAVE_INCASO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_INCASO) {&ProcessOPID_EDIT_INCASO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_INCASO) {&ProcessOPID_O_INCASO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_INCASO) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    ################## 413
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_413) {&ProcessOPID_NEW_413(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_413) {&ProcessOPID_SAVE_413(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_413) {&ProcessOPID_EDIT_413(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_413) {&ProcessOPID_O_413(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_413) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    ################## VAL
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VAL) {&ProcessOPID_NEW_VAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_VAL) {&ProcessOPID_SAVE_VAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_DECLARATION_1) {&ProcessOPID_SAVE_DECLARATION_1(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_DECLARATION_2) {&ProcessOPID_SAVE_DECLARATION_2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_VAL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_VAL) {&ProcessOPID_EDIT_VAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_VAL) {&ProcessOPID_O_VAL(\%DTemplate, \%DataForm);}

    ################## DECLARATION
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_DECLARATION) {&ProcessOPID_NEW_DECLARATION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_DECLARATION) {&ProcessOPID_SAVE_DECLARATION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_DECLARATION) {&ProcessOPID_EDIT_DECLARATION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_DECLARATION) {&ProcessOPID_O_DECLARATION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_DECLARATION) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    ################## FREE_MSG
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FREE_MSG) {&ProcessOPID_NEW_FREE_MSG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_FREE_MSG) {&ProcessOPID_SAVE_FREE_MSG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FREE_MSG) {&ProcessOPID_EDIT_FREE_MSG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_FREE_MSG) {&ProcessOPID_O_FREE_MSG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_FREE_MSG) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_OTKAZ_MSG) {&ProcessOPID_NEW_OTKAZ_MSG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_OTKAZ_MSG) {&ProcessOPID_SAVE_OTKAZ_MSG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_OTKAZ_MSG) {&ProcessOPID_VIEW_OTKAZ_MSG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_OTKAZ_MSG) {&ProcessOPID_O_OTKAZ_MSG(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_OTORIZE_ERROR) {&ProcessOPID_OTORIZE_ERROR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_MASIV) {&ProcessOPID_O_MASIV(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_MASOTORIZE_ERROR) {&ProcessOPID_MASOTORIZE_ERROR(\%DTemplate, \%DataForm);}

    ################## TRANS_REPORT

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_311) {&ProcessOPID_VIEW_311(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_313) {&ProcessOPID_VIEW_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_INCASO) {&ProcessOPID_VIEW_INCASO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_413) {&ProcessOPID_VIEW_413(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VAL) {&ProcessOPID_VIEW_VAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_DECLARATION) {&ProcessOPID_VIEW_DECLARATION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FREE_MSG) {&ProcessOPID_VIEW_FREE_MSG(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_311_IN) {&ProcessOPID_VIEW_311_IN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_313_IN) {&ProcessOPID_VIEW_313_IN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_INCASO_IN) {&ProcessOPID_VIEW_INCASO_IN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VAL_IN) {&ProcessOPID_VIEW_VAL_IN(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_TRANS_FORM) {&ProcessOPID_TRANS_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SND_TRANS_FORM) {&ProcessOPID_SND_TRANS_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RCV_TRANS_FORM) {&ProcessOPID_RCV_TRANS_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IN_TRANS_FORM) {&ProcessOPID_IN_TRANS_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IZVL_FORM) {&ProcessOPID_IZVL_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_SND_TRANS) {&ProcessOPID_SHOW_SND_TRANS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_RCV_TRANS) {&ProcessOPID_SHOW_RCV_TRANS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_IN_TRANS) {&ProcessOPID_SHOW_IN_TRANS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_IZVL) {&ProcessOPID_SHOW_IZVL(\%DTemplate, \%DataForm, \%DTemplateAjax);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CREDITS) {&ProcessOPID_CREDITS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CREDITS_PLAN) {&ProcessOPID_CREDITS_PLAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS) {&ProcessOPID_CARDS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_AUTHORIZATIONS_FORM) {&ProcessOPID_CARDS_AUTHORIZATIONS_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_AUTHORIZATIONS_SHOW) {&ProcessOPID_CARDS_AUTHORIZATIONS_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_TRANSACTIONS_SHOW) {&ProcessOPID_CARDS_TRANSACTIONS_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_TRANSACTIONS_FORM) {&ProcessOPID_CARDS_TRANSACTIONS_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_CHANGEPIN) {&ProcessOPID_CARDS_CHANGEPIN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_CHANGEPIN_SAVE) {&ProcessOPID_CARDS_CHANGEPIN_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_CHANGEPIN_O) {&ProcessOPID_CARDS_CHANGEPIN_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_CHANGEPIN_VIEW) {&ProcessOPID_CARDS_CHANGEPIN_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_CHANGEPIN_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_INFO) {&ProcessOPID_CARDS_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_BLOCK) {&ProcessOPID_CARDS_BLOCK(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_BLOCK_SAVE) {&ProcessOPID_CARDS_BLOCK_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_BLOCK_O) {&ProcessOPID_CARDS_BLOCK_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_BLOCK_VIEW) {&ProcessOPID_CARDS_BLOCK_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_BLOCK_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_UNBLOCK) {&ProcessOPID_CARDS_UNBLOCK(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_UNBLOCK_SAVE) {&ProcessOPID_CARDS_UNBLOCK_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_UNBLOCK_O) {&ProcessOPID_CARDS_UNBLOCK_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_UNBLOCK_VIEW) {&ProcessOPID_CARDS_UNBLOCK_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_UNBLOCK_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_LIMITS) {&ProcessOPID_CARDS_LIMITS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_LIMITS_SAVE) {&ProcessOPID_CARDS_LIMITS_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_LIMITS_O) {&ProcessOPID_CARDS_LIMITS_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_LIMITS_VIEW) {&ProcessOPID_CARDS_LIMITS_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_LIMITS_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_BIZNES) {&ProcessOPID_NEW_CREDIT_BIZNES(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_BIZNES_SAVE) {&ProcessOPID_NEW_CREDIT_BIZNES_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_BIZNES_O) {&ProcessOPID_NEW_CREDIT_BIZNES_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_BIZNES_VIEW) {&ProcessOPID_NEW_CREDIT_BIZNES_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA) {&ProcessOPID_NEW_CREDIT_ALTERNATIVA(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA_SAVE) {&ProcessOPID_NEW_CREDIT_ALTERNATIVA_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA_O) {&ProcessOPID_NEW_CREDIT_ALTERNATIVA_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA_VIEW) {&ProcessOPID_NEW_CREDIT_ALTERNATIVA_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE) {&ProcessOPID_NEW_CREDIT_RAZVITIE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE_SAVE) {&ProcessOPID_NEW_CREDIT_RAZVITIE_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE_O) {&ProcessOPID_NEW_CREDIT_RAZVITIE_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE_VIEW) {&ProcessOPID_NEW_CREDIT_RAZVITIE_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VISA) {&ProcessOPID_NEW_VISA(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VISA_SAVE) {&ProcessOPID_NEW_VISA_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VISA_O) {&ProcessOPID_NEW_VISA_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VISA_VIEW) {&ProcessOPID_NEW_VISA_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_MNO) {&ProcessOPID_NEW_MNO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BLOB_VALUES) {&ProcessOPID_BLOB_VALUES(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BLOB_VALUES_DETAILS) {&ProcessOPID_BLOB_VALUES_DETAILS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_PAY_INFO) {&ProcessOPID_SHOW_PAY_INFO(\%DTemplate, \%DataForm);}

    ####### Системни функции

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SIGN_OUT) {&ProcessOPID_SIGN_OUT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CLOSE_SESSION) {&ProcessOPID_CLOSE_SESSION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PASS_CHNG) {&ProcessOPID_PASS_CHNG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PASS_CHNG_CONF) {&ProcessOPID_PASS_CHNG_CONF(\%DTemplate, \%DataForm, \%DTemplateAjax);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOCK_ACCOUNT) {&ProcessOPID_LOCK_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOCK_ACCOUNT_CONF) {&ProcessOPID_LOCK_ACCOUNT_CONF(\%DTemplate, \%DataForm, \%DTemplateAjax);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REJECT_CHNG_PASS) {&ProcessOPID_REJECT_CHNG_PASS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EXCEL_SETTINGS_FORM) {&ProcessOPID_EXCEL_SETTINGS_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SET_EXCEL_SETTINGS) {&ProcessOPID_SET_EXCEL_SETTINGS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CONTRAGENT_LIST) {&ProcessOPID_SHOW_CONTRAGENT_LIST(\%DTemplate, \%DataForm, \%DTemplateAjax);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ADD_CONTRAGENT) {&ProcessOPID_ADD_CONTRAGENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_CONTRAGENT) {&ProcessOPID_DEL_CONTRAGENT(\%DTemplate, \%DataForm);}

    ###### Свободни съобщения - както са били в WinHOME
    #Продажба на валута
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FM2) {&ProcessOPID_NEW_FM2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_FM2) {&ProcessOPID_SAVE_FM2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FM2) {&ProcessOPID_EDIT_FM2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM2) {&ProcessOPID_VIEW_FM2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_FM2) {&ProcessOPID_O_FM2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_FM2) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    #Покупка на валута
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FM6) {&ProcessOPID_NEW_FM6(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_FM6) {&ProcessOPID_SAVE_FM6(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FM6) {&ProcessOPID_EDIT_FM6(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM6) {&ProcessOPID_VIEW_FM6(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_FM6) {&ProcessOPID_O_FM6(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_FM6) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    #Нареждане за телекс
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FM7) {&ProcessOPID_NEW_FM7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_FM7) {&ProcessOPID_SAVE_FM7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FM7) {&ProcessOPID_EDIT_FM7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM7) {&ProcessOPID_VIEW_FM7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_FM7) {&ProcessOPID_O_FM7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_FM7) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    #Плаваща декларация ЗМИП
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_DEC2) {&ProcessOPID_NEW_DEC2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_DEC2) {&ProcessOPID_SAVE_DEC2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_DEC2) {&ProcessOPID_EDIT_DEC2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_DEC2) {&ProcessOPID_VIEW_DEC2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_DEC2) {&ProcessOPID_O_DEC2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_DEC2) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    #Декларация чл6-КЗОО - задълж. обшествено осигуряване
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FM14) {&ProcessOPID_NEW_FM14(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_FM14) {&ProcessOPID_SAVE_FM14(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FM14) {&ProcessOPID_EDIT_FM14(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM14) {&ProcessOPID_VIEW_FM14(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_FM14) {&ProcessOPID_O_FM14(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_FM14) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FM11) {&ProcessOPID_NEW_FM11(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_FM11) {&ProcessOPID_SAVE_FM11(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FM11) {&ProcessOPID_EDIT_FM11(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM11) {&ProcessOPID_VIEW_FM11(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_FM11) {&ProcessOPID_O_FM11(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_FM11) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEC_NAR28_NEW) {&ProcessOPID_DEC_NAR28_NEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEC_NAR28_SAVE) {&ProcessOPID_DEC_NAR28_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEC_NAR28_EDIT) {&ProcessOPID_DEC_NAR28_EDIT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEC_NAR28_VIEW) {&ProcessOPID_DEC_NAR28_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEC_NAR28_O) {&ProcessOPID_DEC_NAR28_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEC_NAR28_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    # IBAN

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_311) {&ProcessOPID_VIEW_IBAN_311(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_313) {&ProcessOPID_VIEW_IBAN_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_INCASO) {&ProcessOPID_VIEW_IBAN_INCASO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_VAL) {&ProcessOPID_VIEW_IBAN_VAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_DECLARATION) {&ProcessOPID_VIEW_IBAN_DECLARATION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_413) {&ProcessOPID_VIEW_IBAN_413(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_312) {&ProcessOPID_VIEW_IBAN_312(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_FM2) {&ProcessOPID_VIEW_IBAN_FM2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_FM6) {&ProcessOPID_VIEW_IBAN_FM6(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_311_IN) {&ProcessOPID_VIEW_IBAN_311_IN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_312_IN) {&ProcessOPID_VIEW_IBAN_312_IN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_313_IN) {&ProcessOPID_VIEW_IBAN_313_IN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_INCASO_IN) {&ProcessOPID_VIEW_IBAN_INCASO_IN(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_STAT_FORM) {&ProcessOPID_NEW_STAT_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_STAT_FORM) {&ProcessOPID_SAVE_STAT_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_STAT_FORM) {&ProcessOPID_EDIT_STAT_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_STAT_FORM) {&ProcessOPID_O_STAT_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_STAT_FORM) {&ProcessOPID_VIEW_STAT_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_STAT_FORM) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FREEOPERS) {&ProcessOPID_NEW_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_FREEOPERS) {&ProcessOPID_SAVE_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FREEOPERS) {&ProcessOPID_EDIT_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_FREEOPERS) {&ProcessOPID_O_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FREEOPERS) {&ProcessOPID_VIEW_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_FREEOPERS) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FREEOPERS_IN) {&ProcessOPID_VIEW_FREEOPERS_IN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_MY_ACCOUNTS) {&ProcessOPID_MY_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_PRODUCT) {&ProcessOPID_NEW_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_PRODUCT) {&ProcessOPID_SAVE_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_PRODUCT) {&ProcessOPID_O_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_PRODUCT) {&ProcessOPID_EDIT_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_PRODUCT) {&ProcessOPID_VIEW_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_PRODUCT) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CALC_PRODUCT) {&ProcessOPID_CALC_PRODUCT(\%DTemplate, \%DataForm, \%DTemplateAjax);}

    #Демонстрационна версия
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEMO_VERSION) {&ProcessOPID_DEMO(\%DTemplate, \%DataForm);}

    #валутен калкулатор
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CALCULATOR) {&ProcessOPID_CALCULATOR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CALCULATOR_SHOW) {&ProcessOPID_CALCULATOR_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CALCULATOR_CALC) {&ProcessOPID_CALCULATOR_CALC(\%DTemplate, \%DataForm, \%DTemplateAjax);}

    #Технологията е в процес на разработване
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WORK_IN_PROGRESS) {&ProcessOPID_WORK_IN_PROGRESS(\%DTemplate, \%DataForm);}

    #Лихвен калкулатор за депозити
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_PROD_LIHV_CALC) {&ProcessOPID_SHOW_PROD_LIHV_CALC(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PROD_LIHV_CALCULATE) {&ProcessOPID_PROD_LIHV_CALCULATE(\%DTemplate, \%DataForm);}

    #Импорт на файл
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_IMPORT_FILE) {&ProcessOPID_SHOW_IMPORT_FILE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IMPORT_FILE) {&ProcessOPID_IMPORT_FILE(\%DTemplate, \%DataForm);}

    #Контрагенти
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CONTRAGENT) {&ProcessOPID_NEW_CONTRAGENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_CONTRAGENT) {&ProcessOPID_EDIT_CONTRAGENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CONTRAGENT) {&ProcessOPID_SAVE_CONTRAGENT(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_INSTRUCTIONS) {&ProcessOPID_SHOW_INSTRUCTIONS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CONDITIONS) {&ProcessOPID_SHOW_CONDITIONS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEPOSITS) {&ProcessOPID_DEPOSITS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEPOSIT_INFO) {&ProcessOPID_DEPOSIT_INFO(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_OVERDRAFT) {&ProcessOPID_NEW_OVERDRAFT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_OVERDRAFT) {&ProcessOPID_SAVE_OVERDRAFT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_OVERDRAFT) {&ProcessOPID_O_OVERDRAFT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_OVERDRAFT) {&ProcessOPID_VIEW_OVERDRAFT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_OVERDRAFT) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CREDITS_PERSON) {&ProcessOPID_SHOW_CREDITS_PERSON(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CREDITS_FIRM) {&ProcessOPID_SHOW_CREDITS_FIRM(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CARDS) {&ProcessOPID_SHOW_CARDS(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_BUYSELLVAL) {&ProcessOPID_NEW_BUYSELLVAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_BUYSELLVAL) {&ProcessOPID_EDIT_BUYSELLVAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_BUYSELLVAL) {&ProcessOPID_SAVE_BUYSELLVAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_BUYSELLVAL) {&ProcessOPID_O_BUYSELLVAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_BUYSELLVAL) {&ProcessOPID_VIEW_BUYSELLVAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_BUYSELLVAL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_CLIENT) {&ProcessOPID_EDIT_CLIENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CLIENT) {&ProcessOPID_SAVE_CLIENT(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VISA_CREDIT_CARD) {&ProcessOPID_NEW_VISA_CREDIT_CARD(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_VISA_CREDIT_CARD) {&ProcessOPID_SAVE_VISA_CREDIT_CARD(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_VISA_CREDIT_CARD) {&ProcessOPID_O_VISA_CREDIT_CARD(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VISA_CREDIT_CARD) {&ProcessOPID_VIEW_VISA_CREDIT_CARD(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_VISA_CREDIT_CARD) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_IZVL) {&ProcessOPID_CARDS_IZVL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_MASIV) {&ProcessOPID_DELETE_MASIV(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CONSUMER_LOAN) {&ProcessOPID_NEW_CONSUMER_LOAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CONSUMER_LOAN) {&ProcessOPID_SAVE_CONSUMER_LOAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_CONSUMER_LOAN) {&ProcessOPID_O_CONSUMER_LOAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CONSUMER_LOAN) {&ProcessOPID_VIEW_CONSUMER_LOAN(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_MORTGAGE_LOAN) {&ProcessOPID_NEW_MORTGAGE_LOAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_MORTGAGE_LOAN) {&ProcessOPID_SAVE_MORTGAGE_LOAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_MORTGAGE_LOAN) {&ProcessOPID_O_MORTGAGE_LOAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_MORTGAGE_LOAN) {&ProcessOPID_VIEW_MORTGAGE_LOAN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_GENERATE_PLAN) {&ProcessOPID_GENERATE_PLAN(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CONTRAGENT_VAL) {&ProcessOPID_NEW_CONTRAGENT_VAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_CONTRAGENT_VAL) {&ProcessOPID_EDIT_CONTRAGENT_VAL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CONTRAGENT_VAL) {&ProcessOPID_SAVE_CONTRAGENT_VAL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_DEPOSITS) {&ProcessOPID_SHOW_DEPOSITS(\%DTemplate, \%DataForm);}

    #Добавяне на сметка
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_REQ_ACCOUNTS) {&ProcessOPID_NEW_REQ_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REQ_ACCOUNTS) {&ProcessOPID_SAVE_REQ_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_REQ_ACCOUNTS) {&ProcessOPID_EDIT_REQ_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_ACCOUNTS) {&ProcessOPID_VIEW_REQ_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_REQ_ACCOUNTS) {&ProcessOPID_DEL_REQ_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_REQ_ACCOUNTS) {&ProcessOPID_O_REQ_ACCOUNTS(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CHOOSE_CLIENT) {&ProcessOPID_CHOOSE_CLIENT(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REQ_PAY_INFO) {&ProcessOPID_SAVE_REQ_PAY_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_REQ_PAY_INFO) {&ProcessOPID_O_REQ_PAY_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_PAY_INFO) {&ProcessOPID_VIEW_REQ_PAY_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_REQ_PAY_INFO) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_BANK_UNREAD_MSG_LIST) {&ProcessOPID_SHOW_BANK_UNREAD_MSG_LIST(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CLOSE_PRODUCT) {&ProcessOPID_CLOSE_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CLOSE_PRODUCT) {&ProcessOPID_SAVE_CLOSE_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_CLOSE_PRODUCT) {&ProcessOPID_EDIT_CLOSE_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_CLOSE_PRODUCT) {&ProcessOPID_O_CLOSE_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CLOSE_PRODUCT) {&ProcessOPID_VIEW_CLOSE_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_CLOSE_PRODUCT) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PRODUCT_OPERATIONS) {&ProcessOPID_PRODUCT_OPERATIONS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REOPEN_PRODUCT) {&ProcessOPID_REOPEN_PRODUCT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_PRODUCT_DOGOVOR) {&ProcessOPID_SHOW_PRODUCT_DOGOVOR(\%DataForm);}

    #SMS/Email известяване
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_NOTIFICATIONS) {&ProcessOPID_SHOW_NOTIFICATIONS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CUST_NOTIFICATION_REQ) {&ProcessOPID_NEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_CUST_NOTIFICATION_REQ) {&ProcessOPID_O_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CUST_NOTIFICATION_REQ) {&ProcessOPID_SAVE_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CUST_NOTIFICATION_REQ) {&ProcessOPID_VIEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACC_NOTIFICATION_REQ) {&ProcessOPID_NEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_ACC_NOTIFICATION_REQ) {&ProcessOPID_O_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_ACC_NOTIFICATION_REQ) {&ProcessOPID_SAVE_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_ACC_NOTIFICATION_REQ) {&ProcessOPID_VIEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_LOGIN_NOTIFICATION_REQ) {&ProcessOPID_NEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_LOGIN_NOTIFICATION_REQ) {&ProcessOPID_O_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_LOGIN_NOTIFICATION_REQ) {&ProcessOPID_SAVE_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_LOGIN_NOTIFICATION_REQ) {&ProcessOPID_VIEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_REG_PAY_NOTIFICATION_REQ) {&ProcessOPID_NEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_REG_PAY_NOTIFICATION_REQ) {&ProcessOPID_O_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REG_PAY_NOTIFICATION_REQ) {&ProcessOPID_SAVE_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REG_PAY_NOTIFICATION_REQ) {&ProcessOPID_VIEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CARD_NOTIFICATION_REQ) {&ProcessOPID_NEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_CARD_NOTIFICATION_REQ) {&ProcessOPID_O_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CARD_NOTIFICATION_REQ) {&ProcessOPID_SAVE_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CARD_NOTIFICATION_REQ) {&ProcessOPID_VIEW_NOTIFICATION_REQ(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_NOTIFICATION_REQ) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NOTIFICATION_CHANGE_STATUS) {&ProcessOPID_NOTIFICATION_CHANGE_STATUS(\%DTemplate, \%DataForm);}

    #Изключване на сметка
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_EXCLUDE_ACCOUNT) {&ProcessOPID_NEW_EXCLUDE_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_EXCLUDE_ACCOUNT) {&ProcessOPID_SAVE_EXCLUDE_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_EXCLUDE_ACCOUNT) {&ProcessOPID_O_EXCLUDE_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_EXCLUDE_ACCOUNT) {&ProcessOPID_VIEW_EXCLUDE_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_EXCLUDE_ACCOUNT) {&ProcessOPID_DEL_REQ_ACCOUNTS(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_REQ_PARAGONI) {&ProcessOPID_NEW_REQ_PARAGONI(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REQ_PARAGONI) {&ProcessOPID_SAVE_REQ_PARAGONI(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_REQ_PARAGONI) {&ProcessOPID_O_REQ_PARAGONI(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_PARAGONI) {&ProcessOPID_VIEW_REQ_PARAGONI(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_REQ_PARAGONI) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    #Справки Себра
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_REQ_SEBRA_REPORT) {&ProcessOPID_NEW_REQ_SEBRA_REPORT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REQ_SEBRA_REPORT) {&ProcessOPID_SAVE_REQ_SEBRA_REPORT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_REQ_SEBRA_REPORT) {&ProcessOPID_O_REQ_SEBRA_REPORT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_SEBRA_REPORT) {&ProcessOPID_VIEW_REQ_SEBRA_REPORT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_REQ_SEBRA_REPORT) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_SEBRA_DAY_REPORT) {&ProcessOPID_SHOW_SEBRA_DAY_REPORT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_SEBRA_MSG_REPORT) {&ProcessOPID_SHOW_SEBRA_MSG_REPORT(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_REQ_ACCOUNTS_JUR) {&ProcessOPID_NEW_REQ_ACCOUNTS_JUR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REQ_ACCOUNTS_JUR) {&ProcessOPID_SAVE_REQ_ACCOUNTS_JUR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_REQ_ACCOUNTS_JUR) {&ProcessOPID_EDIT_REQ_ACCOUNTS_JUR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_ACCOUNTS_JUR) {&ProcessOPID_VIEW_REQ_ACCOUNTS_JUR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_REQ_ACCOUNTS_JUR) {&ProcessOPID_O_REQ_ACCOUNTS_JUR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SEND_TAN_BY_SMS) {&ProcessOPID_SEND_TAN_BY_SMS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_TAN_BY_SMS_ON_LOGIN) {&ProcessOPID_SHOW_TAN_BY_SMS_ON_LOGIN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SEND_TAN_BY_SMS_AUTH) {&ProcessOPID_SEND_TAN_BY_SMS_AUTH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SEND_TAN_BY_SMS_REJECT) {&ProcessOPID_SEND_TAN_BY_SMS_REJECT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SEND_TAN_BY_SMS_AJAX) {&ProcessOPID_SEND_TAN_BY_SMS_AJAX(\%DTemplate, \%DataForm, \%DTemplateAjax);}

    #Бисера 7
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VAL_B7) {&ProcessOPID_NEW_VAL_B7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_VAL_B7) {&ProcessOPID_SAVE_VAL_B7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VAL_B7) {&ProcessOPID_VIEW_VAL_B7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_VAL_B7) {&ProcessOPID_O_VAL_B7(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_FC_TRANSFER_SHOW_PANEL) {&ProcessOPID_FC_TRANSFER_SHOW_PANEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_FC_TRANSFER_VERIF) {&ProcessOPID_FC_TRANSFER_VERIF(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_FC_TRANSFER_SHOW_FORM) {&ProcessOPID_FC_TRANSFER_SHOW_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_TARGET2) {&ProcessOPID_SAVE_TARGET2(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_AUTH_IMP_PCKG_PANEL) {&ProcessOPID_SHOW_AUTH_IMP_PCKG_PANEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_IMP_PCKG) {&ProcessOPID_O_IMP_PCKG(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CALL_CENTER_REQ) {&ProcessOPID_SHOW_CALL_CENTER_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CALL_CENTER_REQ) {&ProcessOPID_SAVE_CALL_CENTER_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_CALL_CENTER_REQ) {&ProcessOPID_O_CALL_CENTER_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_CALL_CENTER_REQ) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CALL_CENTER_REQ) {&ProcessOPID_VIEW_CALL_CENTER_REQ(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_REGULAR_PAYMENTS) {&ProcessOPID_SHOW_REGULAR_PAYMENTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEACTIVATE_REGULAR_PAYMENT) {&ProcessOPID_DEACTIVATE_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_PAYED_REGULAR_PAYMENTS_LIST) {&ProcessOPID_SHOW_PAYED_REGULAR_PAYMENTS_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_NEW_REGULAR_PAYMENT) {&ProcessOPID_SHOW_NEW_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_DEACTIVATE_REGULAR_PAYMENT) {&ProcessOPID_O_DEACTIVATE_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_311_REGULAR_PAYMENT) {&ProcessOPID_SAVE_311_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_313_REGULAR_PAYMENT) {&ProcessOPID_SAVE_313_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_311_REGULAR_PAYMENT) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_313_REGULAR_PAYMENT) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_311_REGULAR_PAYMENT) {&ProcessOPID_O_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_313_REGULAR_PAYMENT) {&ProcessOPID_O_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_311_REGULAR_PAYMENT) {&ProcessOPID_VIEW_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_313_REGULAR_PAYMENT) {&ProcessOPID_VIEW_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_PAY_TO_OWN_ACCOUNT) {&ProcessOPID_NEW_PAY_TO_OWN_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_PAY_TO_OWN_ACCOUNT) {&ProcessOPID_SAVE_PAY_TO_OWN_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_PAY_TO_OWN_ACCOUNT) {&ProcessOPID_O_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_PAY_TO_OWN_ACCOUNT) {&ProcessOPID_VIEW_REGULAR_PAYMENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_PAY_TO_OWN_ACCOUNT) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_MEMORIAL_ORDER) {&ProcessOPID_VIEW_MEMORIAL_ORDER(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VISA_VIRTU_REQ) {&ProcessOPID_NEW_VISA_VIRTU_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_VISA_VIRTU_REQ) {&ProcessOPID_SAVE_VISA_VIRTU_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_VISA_VIRTU_REQ) {&ProcessOPID_O_VISA_VIRTU_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VISA_VIRTU_REQ) {&ProcessOPID_VIEW_VISA_VIRTU_REQ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_VISA_VIRTU_REQ) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_3DS_VIRTU_SHOW) {&ProcessOPID_3DS_VIRTU_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_3DS_VIRTU_O) {&ProcessOPID_O_FREE_MSG(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ASK_CONFIDENTIAL_INFO) {&ProcessOPID_ASK_CONFIDENTIAL_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CONFIDENTIAL_INFO) {&ProcessOPID_SHOW_CONFIDENTIAL_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CHANGE_CVVAUTH) {&ProcessOPID_NEW_CHANGE_CVVAUTH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CHANGE_CVVAUTH) {&ProcessOPID_SAVE_CHANGE_CVVAUTH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_CHANGE_CVVAUTH) {&ProcessOPID_O_CHANGE_CVVAUTH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_CHANGE_CVVAUTH) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CHANGE_CVVAUTH) {&ProcessOPID_VIEW_VISA_VIRTU_REQ(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOGIN_CHNG) {&ProcessOPID_LOGIN_CHNG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOGIN_CHNG_CONF) {&ProcessOPID_LOGIN_CHNG_CONF(\%DTemplate, \%DataForm, \%DTemplateAjax);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SSL_REQ_SHOW) {&ProcessOPID_SSL_REQ_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SSL_REQ_SAVE) {&ProcessOPID_SSL_REQ_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SSL_ACTIVATE_SHOW) {&ProcessOPID_SSL_ACTIVATE_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SSL_ACTIVATE_SAVE) {&ProcessOPID_SSL_ACTIVATE_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SSL_REQ_SKIP_SHOW) {&ProcessOPID_SSL_REQ_SKIP_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SSL_GET_CERT_SHOW) {&ProcessOPID_SSL_GET_CERT_SHOW(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_RIGHTS_SHOW) {&ProcessOPID_USER_RIGHTS_SHOW(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_REQ_CRED_CARD_IZVL) {&ProcessOPID_NEW_REQ_CRED_CARD_IZVL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REQ_CRED_CARD_IZVL) {&ProcessOPID_SAVE_REQ_CRED_CARD_IZVL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_REQ_CRED_CARD_IZVL) {&ProcessOPID_O_REQ_CRED_CARD_IZVL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_CRED_CARD_IZVL) {&ProcessOPID_VIEW_REQ_CRED_CARD_IZVL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_REQ_CRED_CARD_IZVL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CRED_CARD_IZVL) {&ProcessOPID_SHOW_CRED_CARD_IZVL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CRED_CARD_IZVL_DETAILS) {&ProcessOPID_SHOW_CRED_CARD_IZVL_DETAILS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CRED_CARD_IZVL_DETAILS_PDF) {&ProcessOPID_SHOW_CRED_CARD_IZVL_DETAILS_PDF(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_SHOW) {&ProcessOPID_DATAMAX_REG_PAY_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_PENDING_BILLS_SHOW) {&ProcessOPID_DATAMAX_PENDING_BILLS_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_PAYED_BILLS_SHOW) {&ProcessOPID_DATAMAX_PAYED_BILLS_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_NEW) {&ProcessOPID_DATAMAX_REG_PAY_NEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_CHOOSE_CLIENT) {&ProcessOPID_DATAMAX_CHOOSE_CLIENT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_SAVE) {&ProcessOPID_DATAMAX_REG_PAY_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_VIEW) {&ProcessOPID_DATAMAX_REG_PAY_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_EDIT) {&ProcessOPID_DATAMAX_REG_PAY_EDIT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_ACTIVATE) {&ProcessOPID_DATAMAX_REG_PAY_ACTIVATE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_CHOOSE_MERCHANT) {&ProcessOPID_DATAMAX_CHOOSE_MERCHANT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_PENDING_BILLS_VIEW) {&ProcessOPID_DATAMAX_PENDING_BILLS_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_PAYED_BILLS_VIEW) {&ProcessOPID_DATAMAX_PAYED_BILLS_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_CANCEL) {&ProcessOPID_DATAMAX_REG_PAY_CANCEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_PENDING_BILLS_PAY) {&ProcessOPID_DATAMAX_PENDING_BILLS_PAY(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_DEL_SHOW) {&ProcessOPID_DATAMAX_REG_PAY_DEL_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DATAMAX_REG_PAY_DEL) {&ProcessOPID_DATAMAX_REG_PAY_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CURR_TRANSL_CHAMELEON) {&ProcessOPID_NEW_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CURR_TRANSL_CHAMELEON) {&ProcessOPID_SAVE_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_O_CURR_TRANSL_CHAMELEON) {&ProcessOPID_O_CURR_TRANSL_CHAMELEON(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_CURR_TRANSL_CHAMELEON) {&ProcessOPID_EDIT_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CURR_TRANSL_CHAMELEON) {&ProcessOPID_VIEW_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEL_CURR_TRANSL_CHAMELEON) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SSL_EXP_DATE_SHOW) {&ProcessOPID_SSL_EXP_DATE_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CONTRAGENT_313) {&ProcessOPID_NEW_CONTRAGENT_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_CONTRAGENT_313) {&ProcessOPID_EDIT_CONTRAGENT_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_CONTRAGENT_313) {&ProcessOPID_SAVE_CONTRAGENT_313(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CUST_CHANGE_SHOW) {&ProcessOPID_CUST_CHANGE_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CUST_CHANGE_SAVE) {&ProcessOPID_CUST_CHANGE_SAVE(\%DTemplate, \%DataForm, \%DTemplateAjax);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_KEP_SHOW) {&ProcessOPID_REG_KEP_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_KEP_SAVE) {&ProcessOPID_REG_KEP_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_KEP_NEW) {&ProcessOPID_REG_KEP_NEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EFAKT_RESPONSE) {&ProcessOPID_EFAKT_RESPONSE(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACCOUNT_INFO_SAVE) {&ProcessOPID_ACCOUNT_INFO_SAVE(\%DTemplate, \%DataForm);}

    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERDOCS_NEW) {&ProcessOPID_USERDOCS_NEW(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERDOCS_SAVE) {&ProcessOPID_USERDOCS_SAVE(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERDOCS_EDIT) {&ProcessOPID_USERDOCS_EDIT(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERDOCS_O) {&ProcessOPID_USERDOCS_O(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERDOCS_VIEW) {&ProcessOPID_USERDOCS_VIEW(\%DTemplate, \%DataForm);}
    #elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERDOCS_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOGIN_VERIFICATION_BY_TAN) {&ProcessOPID_LOGIN_VERIFICATION_BY_TAN(\%DTemplate, \%DataForm);}

    #Импорт Масов превод на работни заплати
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IMP_SALARY_SHOW) {&ProcessOPID_IMP_SALARY_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IMP_SALARY_SAVE) {&ProcessOPID_IMP_SALARY_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IMP_SALARY_O) {&ProcessOPID_IMP_SALARY_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IMP_SALARY_VIEW) {&ProcessOPID_IMP_SALARY_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IMP_SALARY_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_START_ACCOUNTS) {&ProcessOPID_START_ACCOUNTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SEBRA_REPORT_SEARCH) {&ProcessOPID_SEBRA_REPORT_SEARCH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_SEBRA_MSG_REPORT2) {&ProcessOPID_SHOW_SEBRA_MSG_REPORT2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_SEBRA_LIMITS_REPORT) {&ProcessOPID_SHOW_SEBRA_LIMITS_REPORT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_AJAX_VALIDATION) {&ProcessOPID_AJAX_VALIDATION(\%DTemplate, \%DataForm, \%DTemplateAjax);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_AJAX_GET_ACCOUNT_INFO) {&ProcessOPID_AJAX_GET_ACCOUNT_INFO(\%DTemplate, \%DataForm, \%DTemplateAjax);}

    # elsif ($DataForm{'OPID'} == $Ow3bank::OPID_TOPUP_PREPAID_CARD_NEW) {&ProcessOPID_TOPUP_PREPAID_CARD_NEW(\%DTemplate, \%DataForm);}
    # elsif ($DataForm{'OPID'} == $Ow3bank::OPID_TOPUP_PREPAID_CARD_SAVE) {&ProcessOPID_TOPUP_PREPAID_CARD_SAVE(\%DTemplate, \%DataForm);}
    # elsif ($DataForm{'OPID'} == $Ow3bank::OPID_TOPUP_PREPAID_CARD_EDIT) {&ProcessOPID_TOPUP_PREPAID_CARD_EDIT(\%DTemplate, \%DataForm);}
    # elsif ($DataForm{'OPID'} == $Ow3bank::OPID_TOPUP_PREPAID_CARD_DEL) {&ProcessOPID_DEL(\%DTemplate, \%DataForm);}
    # elsif ($DataForm{'OPID'} == $Ow3bank::OPID_TOPUP_PREPAID_CARD_O) {&ProcessOPID_TOPUP_PREPAID_CARD_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_TOPUP_PREPAID_CARD_VIEW) {&ProcessOPID_TOPUP_PREPAID_CARD_VIEW(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_CONSENT_INFO) {&ProcessOPID_PSD2_CONSENT_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_CONSENT_O) {&ProcessOPID_PSD2_CONSENT_O(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_REVOKE_CONSENT) {&ProcessOPID_PSD2_REVOKE_CONSENT(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_AUTHENTICATION_INFO) {&ProcessOPID_PSD2_AUTHENTICATION_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PSD2_AUTHENTICATION_O) {&ProcessOPID_PSD2_AUTHENTICATION_O(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ZUI_SHOW) {&ProcessOPID_ZUI_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ZUI_TAN_BY_SMS_AUTH) {&ProcessOPID_ZUI_TAN_BY_SMS_AUTH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ZUI_TAN_BY_SMS_REJECT) {&ProcessOPID_ZUI_TAN_BY_SMS_REJECT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EXT_USER_REG) {&ProcessOPID_EXT_USER_REG(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EXT_USER_ACTIVATE_MAIL) {&ProcessOPID_EXT_USER_ACTIVATE_MAIL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_CUST_SHOW) {&ProcessOPID_REG_CUST_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_CUST_SHOW_LAST) {&ProcessOPID_REG_CUST_SHOW_LAST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_CUST_SAVE1) {&ProcessOPID_REG_CUST_SAVE1(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_CUST_SAVE2) {&ProcessOPID_REG_CUST_SAVE2(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_CUST_SAVE3) {&ProcessOPID_REG_CUST_SAVE3(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SUM_SUB_STEP_UP_TAN_BY_SMS_AUTH) {&ProcessOPID_SUM_SUB_STEP_UP_TAN_BY_SMS_AUTH(\%DTemplate, \%DataForm);}

# ~bc_end_if USER_WWW

    if ($DataForm{'OPID'} == $Ow3bank::OPID_REG_KEP_EDIT) {&ProcessOPID_REG_KEP_EDIT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_KEP_EDIT_SAVE) {&ProcessOPID_REG_KEP_EDIT_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CAPTCHA_GET) {
      my $CaptchaContent = &ToolsW3User::ProcessOPID_CAPTCHA_GET();
      print $CaptchaContent;
      &ToolsW3User::HaltScript();
    } elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_MSG_PAGE) {
      &ProcessOPID_SHOW_MSG_PAGE(\%DTemplate, \%DataForm);
    }

    ################################################ А Д М И Н И С Т Р А Т О Р С К И    М О Д У Л #############################################

=pod
 ~bc_if_def ADMIN_WWW
    if ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_WWW_USER_LIST) {&ProcessOPID_SHOW_WWW_USER_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_BANK_USER_LIST) {&ProcessOPID_SHOW_BANK_USER_LIST(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_MODIFY_USER) {&ProcessOPID_WWW_MODIFY_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_DELETE_USER) {&ProcessOPID_WWW_DELETE_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_LOCK_USER) {&ProcessOPID_WWW_LOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_UNLOCK_USER) {&ProcessOPID_WWW_UNLOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_EDIT_USER) {&ProcessOPID_WWW_EDIT_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_UPDATE_USER) {&ProcessOPID_WWW_UPDATE_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_ENTER_NEW_USER) {&ProcessOPID_WWW_ENTER_NEW_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_INSERT_USER) {&ProcessOPID_WWW_INSERT_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_CHNG_USER_PASS) {&ProcessOPID_WWW_CHNG_USER_PASS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_SET_NEW_PUK) {&ProcessOPID_WWW_SET_NEW_PUK(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_SET_NEW_PASS_AND_PUK) {&ProcessOPID_WWW_SET_NEW_PASS_AND_PUK(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SEBRA_RIGHTS_EDIT) {&ProcessOPID_SEBRA_RIGHTS_EDIT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SEBRA_RIGHTS_SAVE) {&ProcessOPID_SEBRA_RIGHTS_SAVE(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_MODIFY_USER) {&ProcessOPID_BANK_MODIFY_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_DELETE_USER) {&ProcessOPID_BANK_DELETE_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_LOCK_USER) {&ProcessOPID_BANK_LOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_UNLOCK_USER) {&ProcessOPID_BANK_UNLOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_EDIT_USER) {&ProcessOPID_BANK_EDIT_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_UPDATE_USER) {&ProcessOPID_BANK_UPDATE_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_ENTER_NEW_USER) {&ProcessOPID_BANK_ENTER_NEW_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_INSERT_USER) {&ProcessOPID_BANK_INSERT_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_SET_NEW_PUK) {&ProcessOPID_BANK_SET_NEW_PUK(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_CHNG_USER_PASS) {&ProcessOPID_BANK_CHNG_USER_PASS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_SET_NEW_PASS_AND_PUK) {&ProcessOPID_BANK_SET_NEW_PASS_AND_PUK(\%DTemplate, \%DataForm);}

    ####### Специфични за потребителите на WWW

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ENTER_BUSER_RIGHTS) {&ProcessOPID_ENTER_BUSER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_INSERT_BUSER_RIGHTS) {&ProcessOPID_INSERT_BUSER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_BUSER_RIGHTS) {&ProcessOPID_DELETE_BUSER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PRINT_BUSER) {&ProcessOPID_PRINT_BUSER(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ENTER_USER_RIGHTS) {&ProcessOPID_ENTER_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_INSERT_USER_RIGHTS) {&ProcessOPID_INSERT_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_USER_RIGHTS) {&ProcessOPID_DELETE_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_USER_RIGHTS) {&ProcessOPID_EDIT_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PRINT_USER) {&ProcessOPID_PRINT_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_TAN) {&ProcessOPID_NEW_TAN(\%DTemplate, \%DataForm);}

    #    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_TAN) {&ProcessOPID_DELETE_TAN(\%DTemplate, \%DataForm);}

    ####### Системни функции

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CLOSE_SESSION) {&ProcessOPID_CLOSE_SESSION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SIGN_OUT) {&ProcessOPID_SIGN_OUT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PASS_CHNG) {&ProcessOPID_PASS_CHNG_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PASS_CHNG_CONF_BM) {&ProcessOPID_PASS_CHNG_CONF_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOCK_ACCOUNT) {&ProcessOPID_LOCK_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOCK_ACCOUNT_CONF) {&ProcessOPID_LOCK_ACCOUNT_CONF(\%DTemplate, \%DataForm);}

    ######## Търсачка
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_FIND_USER_FORM) {&ProcessOPID_SHOW_FIND_USER_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_FIND_USER) {&ProcessOPID_FIND_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REJECT_CHNG_PASS) {&ProcessOPID_REJECT_CHNG_PASS(\%DTemplate, \%DataForm);}

    ### Други
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ADD_ACCESS_LIST) {&ProcessOPID_ADD_ACCESS_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_INSERT_IP) {&ProcessOPID_INSERT_IP(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_IP) {&ProcessOPID_DELETE_IP(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_BLOCKED_IPS) {&ProcessOPID_SHOW_BLOCKED_IPS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_LOCKED_IP) {&ProcessOPID_DELETE_LOCKED_IP(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_KEP_SEARCH) {&ProcessOPID_REG_KEP_SEARCH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REG_KEP_FIND) {&ProcessOPID_REG_KEP_FIND(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EFAKTURA_CHANGE_PASS_SHOW) {&ProcessOPID_EFAKTURA_CHANGE_PASS_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EFAKTURA_CHANGE_PASS_NEW_REQUEST) {&ProcessOPID_EFAKTURA_CHANGE_PASS_NEW_REQUEST(\%DTemplate, \%DataForm);}

    ### WinHome
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_SHIPHERS) {&ProcessOPID_EDIT_SHIPHERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ENTER_NEW_SHIPHRE) {&ProcessOPID_ENTER_NEW_SHIPHRE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_INSERT_SHIPHRE) {&ProcessOPID_INSERT_SHIPHRE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_INSERT_CODE) {&ProcessOPID_INSERT_CODE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_CODE) {&ProcessOPID_EDIT_CODE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_CODE) {&ProcessOPID_DELETE_CODE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_SHIPHRE) {&ProcessOPID_EDIT_SHIPHRE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_SHIPHRE) {&ProcessOPID_DELETE_SHIPHRE(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_FIRST_EXPORT) {&ProcessOPID_FIRST_EXPORT(\%DTemplate, \%DataForm);}

    ### Разпределен подпис
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_SHOW_USER_KOMPLEKT) {&ProcessOPID_RP_SHOW_USER_KOMPLEKT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_KOMPLEKT_NEW_CUST) {&ProcessOPID_RP_KOMPLEKT_NEW_CUST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_KOMPLEKT_SAVE_CUST) {&ProcessOPID_RP_KOMPLEKT_SAVE_CUST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_KOMPLEKT_DELETE_CUST) {&ProcessOPID_RP_KOMPLEKT_DELETE_CUST(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_FILES_LIST) {&ProcessOPID_SHOW_FILES_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_FILE) {&ProcessOPID_NEW_FILE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_IMPORT_FILE_AM) {&ProcessOPID_IMPORT_FILE_AM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_FILE) {&ProcessOPID_EDIT_FILE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_FILE) {&ProcessOPID_DELETE_FILE(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_START_ACCOUNTS_MSG_SHOW) {&ProcessOPID_START_ACCOUNTS_MSG_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_START_ACCOUNTS_MSG_SAVE) {&ProcessOPID_START_ACCOUNTS_MSG_SAVE(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_STATISTICS_PSW_FIND) {&ProcessOPID_STATISTICS_PSW_FIND(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_STATISTICS_PSW_SHOW) {&ProcessOPID_STATISTICS_PSW_SHOW(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_FIND_SHOW) {&ProcessOPID_RP_HEADER_FIND_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_FIND_LIST) {&ProcessOPID_RP_HEADER_FIND_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_SHOW) {&ProcessOPID_RP_HEADER_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_SAVE) {&ProcessOPID_RP_HEADER_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_EDIT) {&ProcessOPID_RP_HEADER_EDIT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_VIEW) {&ProcessOPID_RP_HEADER_VIEW(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_MANAGE_TAN_LIST) {&ProcessOPID_MANAGE_TAN_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_MANAGE_TAN_DEL) {&ProcessOPID_MANAGE_TAN_DEL(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BUDGET_OFFICER_SHOW) {&ProcessOPID_BUDGET_OFFICER_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BUDGET_OFFICER_FIND) {&ProcessOPID_BUDGET_OFFICER_FIND(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BUDGET_OFFICER_ADD) {&ProcessOPID_BUDGET_OFFICER_ADD(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BUDGET_OFFICER_DEL) {&ProcessOPID_BUDGET_OFFICER_DEL(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BUDGET_OFFICER_SAVE) {&ProcessOPID_BUDGET_OFFICER_SAVE(\%DTemplate, \%DataForm);}

    #OTP
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_OTP_INFO_SHOW) {&ProcessOPID_OTP_INFO_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_OTP_INFO_TOKEN_SEARCH) {&ProcessOPID_OTP_INFO_TOKEN_SEARCH(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_OTP_INFO_TOKEN_ACTIVATE) {&ProcessOPID_OTP_INFO_TOKEN_ACTIVATE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_OTP_INFO_TOKEN_DEACTIVATE) {&ProcessOPID_OTP_INFO_TOKEN_DEACTIVATE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_OTP_INFO_TOKEN_STATUS_CHECK) {&ProcessOPID_OTP_INFO_TOKEN_STATUS_CHECK(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SET_NEW_PIN) {&ProcessOPID_WWW_SET_NEW_PIN(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERS_WITH_FEW_TANS_SHOW) {&ProcessOPID_USERS_WITH_FEW_TANS_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERS_WITH_FEW_TANS_RESULTS) {&ProcessOPID_USERS_WITH_FEW_TANS_RESULTS(\%DTemplate, \%DataForm);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_AJAX_LOAD_SCRATCH_CARD) {&ProcessOPID_AJAX_LOAD_SCRATCH_CARD(\%DTemplate, \%DataForm, \%DTemplateAjax);}

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_HEALTH_CHECK_REPORTS_SHOW) {&ProcessOPID_HEALTH_CHECK_REPORTS_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ZUI_CLEAR) {&ProcessOPID_ZUI_CLEAR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_FIRSTACCESS_CLEAR) {&ProcessOPID_FIRSTACCESS_CLEAR(\%DTemplate, \%DataForm);}
=cut
# ~bc_end_if ADMIN_WWW

=pod
 ~bc_if_def BANK_WWW
    if ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_413) {&ProcessOPID_VIEW_413_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_DECLARATION) {&ProcessOPID_VIEW_DECLARATION_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FREE_MSG) {&ProcessOPID_VIEW_FREE_MSG_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_OTKAZ_MSG) {&ProcessOPID_VIEW_OTKAZ_MSG_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VAL)      {&ProcessOPID_VIEW_VAL_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_VAL) {&ProcessOPID_VIEW_VAL_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VAL_B7) {&ProcessOPID_VIEW_VAL_B7(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SET_STATUS) {&ProcessOPID_SET_STATUS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_REPORT_FORM) {&ProcessOPID_SHOW_REPORT_FORM_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_OPERATIONS) {&ProcessOPID_SHOW_OPERATIONS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_MSG_LIST_FORM) {&ProcessOPID_SHOW_MSG_LIST_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_MSG_LIST) {&ProcessOPID_SHOW_MSG_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_MSG_INFO) {&ProcessOPID_SHOW_MSG_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_MSG_FORM) {&ProcessOPID_SHOW_MSG_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_MSG) {&ProcessOPID_SAVE_MSG(\%DTemplate, \%DataForm);}

    ####### Системни функции

    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CLOSE_SESSION) {&ProcessOPID_CLOSE_SESSION(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SIGN_OUT) {&ProcessOPID_SIGN_OUT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PASS_CHNG) {&ProcessOPID_PASS_CHNG_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PASS_CHNG_CONF_BM) {&ProcessOPID_PASS_CHNG_CONF_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOCK_ACCOUNT) {&ProcessOPID_LOCK_ACCOUNT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_LOCK_ACCOUNT_CONF) {&ProcessOPID_LOCK_ACCOUNT_CONF(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_USER_LIST) {&ProcessOPID_SHOW_USER_LIST_BM(\%DTemplate, \%DataForm);}

    ######## Търсачка
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REJECT_CHNG_PASS) {&ProcessOPID_REJECT_CHNG_PASS(\%DTemplate, \%DataForm);}

    ######## Свободни съобщения от WinHome
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM6) {&ProcessOPID_VIEW_FM6_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM2) {&ProcessOPID_VIEW_FM2_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_311) {&ProcessOPID_VIEW_311_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM14) {&ProcessOPID_VIEW_FM14_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_DEC2) {&ProcessOPID_VIEW_DEC2_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FM11) {&ProcessOPID_VIEW_FM11_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_312) {&ProcessOPID_VIEW_312_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_313) {&ProcessOPID_VIEW_313_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_INCASO) {&ProcessOPID_VIEW_INCASO_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DEC_NAR28_VIEW) {&ProcessOPID_DEC_NAR28_VIEW_BM(\%DTemplate, \%DataForm);}

    ####### IBAN
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_311) {&ProcessOPID_VIEW_IBAN_311_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_312) {&ProcessOPID_VIEW_IBAN_312_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_313) {&ProcessOPID_VIEW_IBAN_313_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_INCASO) {&ProcessOPID_VIEW_IBAN_INCASO_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_FM2) {&ProcessOPID_VIEW_IBAN_FM2_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_FM6) {&ProcessOPID_VIEW_IBAN_FM6_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_413) {&ProcessOPID_VIEW_IBAN_413_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_DECLARATION) {&ProcessOPID_VIEW_IBAN_DECLARATION_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_STAT_FORM) {&ProcessOPID_VIEW_STFM_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_FREEOPERS) {&ProcessOPID_VIEW_FREEOPERS_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_BLOCK_VIEW) {&ProcessOPID_CARDS_BLOCK_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_UNBLOCK_VIEW) {&ProcessOPID_CARDS_UNBLOCK_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_LIMITS_VIEW) {&ProcessOPID_CARDS_LIMITS_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CARDS_CHANGEPIN_VIEW) {&ProcessOPID_CARDS_CHANGEPIN_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_BIZNES_VIEW) {&ProcessOPID_NEW_CREDIT_BIZNES_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA_VIEW) {&ProcessOPID_NEW_CREDIT_ALTERNATIVA_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE_VIEW) {&ProcessOPID_NEW_CREDIT_RAZVITIE_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_VISA_VIEW) {&ProcessOPID_NEW_VISA_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_FIZ_VIEW) {&ProcessOPID_NEW_USER_FIZ_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_JUR_VIEW) {&ProcessOPID_NEW_USER_JUR_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_OVERDRAFT) {&ProcessOPID_VIEW_OVERDRAFT_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_VISA_CREDIT_CARD) {&ProcessOPID_VIEW_VISA_CREDIT_CARD_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CONSUMER_LOAN) {&ProcessOPID_VIEW_CONSUMER_LOAN_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_MORTGAGE_LOAN) {&ProcessOPID_VIEW_MORTGAGE_LOAN_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_ACCOUNTS) {&ProcessOPID_VIEW_REQ_ACCOUNTS_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_PAY_INFO) {&ProcessOPID_VIEW_REQ_PAY_INFO_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CLOSE_PRODUCT) {&ProcessOPID_VIEW_CLOSE_PRODUCT_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_PRODUCT) {&ProcessOPID_VIEW_PRODUCT_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIEW) {&ProcessOPID_NEW_ACCOUNT_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_VIEW) {&ProcessOPID_NEW_ACCOUNT_VIRTUAL_IBAN_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CUST_NOTIFICATION_REQ)  {&ProcessOPID_VIEW_NOTIFICATION_REQ_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_ACC_NOTIFICATION_REQ)   {&ProcessOPID_VIEW_NOTIFICATION_REQ_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_LOGIN_NOTIFICATION_REQ) {&ProcessOPID_VIEW_NOTIFICATION_REQ_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CARD_NOTIFICATION_REQ)  {&ProcessOPID_VIEW_NOTIFICATION_REQ_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_EXCLUDE_ACCOUNT) {&ProcessOPID_VIEW_EXCLUDE_ACCOUNT_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_PARAGONI) {&ProcessOPID_VIEW_REQ_PARAGONI_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_SEBRA_REPORT) {&ProcessOPID_VIEW_REQ_SEBRA_REPORT_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_REQ_JUR_PROCESSED) {&ProcessOPID_USER_REQ_JUR_PROCESSED(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_REQ_ACCOUNTS_JUR) {&ProcessOPID_VIEW_REQ_ACCOUNTS_JUR_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SAVE_REQ_ACCOUNTS_JUR) {&ProcessOPID_SAVE_REQ_ACCOUNTS_JUR_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACTIVATE_USER_PROFILE) {&ProcessOPID_ACTIVATE_USER_PROFILE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_NEW_ZIP_PASS) {&ProcessOPID_NEW_USER_NEW_ZIP_PASS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_CONTRACT) {&ProcessOPID_SHOW_CONTRACT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_BLOCKED_IPS_BM) {&ProcessOPID_SHOW_BLOCKED_IPS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_LOCKED_IP_BM) {&ProcessOPID_DELETE_LOCKED_IP(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_SHOW_FIND_USER_FORM_BM) {&ProcessOPID_SHOW_FIND_USER_FORM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_FIND_USER_BM) {&ProcessOPID_FIND_USER_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_LOCK_USER_BM) {&ProcessOPID_WWW_LOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_UNLOCK_USER_BM) {&ProcessOPID_WWW_UNLOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_LOCK_USER_BM) {&ProcessOPID_BANK_LOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_BANK_UNLOCK_USER_BM) {&ProcessOPID_BANK_UNLOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_REFUSE_REG_REQUEST) {&ProcessOPID_REFUSE_REG_REQUEST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_GENERATE_PUK_AND_TANS) {&ProcessOPID_GENERATE_PUK_AND_TANS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_FIZ) {&ProcessOPID_NEW_USER_FIZ(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_JUR) {&ProcessOPID_NEW_USER_JUR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_FIZ_SAVE_HEAD_INFO) {&ProcessOPID_NEW_USER_FIZ_SAVE_HEAD_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_FIZ_SAVE_DETAILS) {&ProcessOPID_NEW_USER_FIZ_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_JUR_SAVE_HEAD_INFO) {&ProcessOPID_NEW_USER_JUR_SAVE_HEAD_INFO(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_JUR_SAVE_DETAILS) {&ProcessOPID_NEW_USER_JUR_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_GET_REQUEST_HTML) {&ProcessOPID_GET_REQUEST_HTML(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACTIVATE_REG_REQUEST) {&ProcessOPID_ACTIVATE_REG_REQUEST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_REG_REQUEST) {&ProcessOPID_DELETE_REG_REQUEST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RETURN_FOR_EDITING) {&ProcessOPID_RETURN_FOR_EDITING(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_REG_REQUEST) {&ProcessOPID_EDIT_REG_REQUEST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_CANCEL_EDIT_REG_REQUEST) {&ProcessOPID_CANCEL_EDIT_REG_REQUEST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_REQ_NA_NEW) {&ProcessOPID_USER_REQ_NA_NEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_REQ_NA_VIEW) {&ProcessOPID_USER_REQ_NA_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_REQ_NA_SAVE) {&ProcessOPID_USER_REQ_NA_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_REQ_NA_DEL_FILE) {&ProcessOPID_USER_REQ_NA_DEL_FILE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_REQ_NA_LIST_FORM_SHOW) {&ProcessOPID_USER_REQ_NA_LIST_FORM_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USER_REQ_NA_LIST_SHOW) {&ProcessOPID_USER_REQ_NA_LIST_SHOW(\%DTemplate, \%DataForm);}

    #    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_NEW_USER_ADD_SCRATCH_CARD) {&ProcessOPID_NEW_USER_ADD_SCRATCH_CARD(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ADD_UPS_TO_USER_JUR) {&ProcessOPID_ADD_UPS_TO_USER_JUR(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACC_REQ_FIZ_SHOW) {&ProcessOPID_ACC_REQ_FIZ_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACC_REQ_FIZ_SAVE) {&ProcessOPID_ACC_REQ_FIZ_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACC_REQ_JUR_SHOW) {&ProcessOPID_ACC_REQ_JUR_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACC_REQ_JUR_SAVE) {&ProcessOPID_ACC_REQ_JUR_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACC_REQ_FIZ_VIEW) {&ProcessOPID_ACC_REQ_FIZ_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACC_REQ_JUR_VIEW) {&ProcessOPID_ACC_REQ_JUR_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ACTIVATE_ACC_REG_REQUEST) {&ProcessOPID_ACTIVATE_ACC_REG_REQUEST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RELOAD_REQUEST) {&ProcessOPID_RELOAD_REQUEST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_VIEW_CURR_TRANSL_CHAMELEON) {&ProcessOPID_VIEW_FREEOPERS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_USERDOCS_VIEW) {&ProcessOPID_USERDOCS_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ADD_TOKEN) {&ProcessOPID_ADD_TOKEN(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_GET_CUST_INFO_AJAX) {&ProcessOPID_GET_CUST_INFO_AJAX(\%DTemplate, \%DataForm, \%DTemplateAjax);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ENTER_USER_RIGHTS_BM) {&ProcessOPID_ENTER_USER_RIGHTS_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_MODIFY_USER) {&ProcessOPID_WWW_MODIFY_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_LOCK_USER) {&ProcessOPID_WWW_LOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_UNLOCK_USER) {&ProcessOPID_WWW_UNLOCK_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_CHNG_USER_PASS) {&ProcessOPID_WWW_CHNG_USER_PASS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_DELETE_USER) {&ProcessOPID_WWW_DELETE_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_SET_NEW_PUK) {&ProcessOPID_WWW_SET_NEW_PUK(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_EDIT_USER) {&ProcessOPID_WWW_EDIT_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_WWW_UPDATE_USER) {&ProcessOPID_WWW_UPDATE_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_ENTER_USER_RIGHTS) {&ProcessOPID_ENTER_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_EDIT_USER_RIGHTS) {&ProcessOPID_EDIT_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_INSERT_USER_RIGHTS) {&ProcessOPID_INSERT_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_DELETE_USER_RIGHTS) {&ProcessOPID_DELETE_USER_RIGHTS(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_FIND_SHOW) {&ProcessOPID_RP_HEADER_FIND_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_FIND_LIST) {&ProcessOPID_RP_HEADER_FIND_LIST(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_SHOW) {&ProcessOPID_RP_HEADER_SHOW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_SAVE) {&ProcessOPID_RP_HEADER_SAVE(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_EDIT) {&ProcessOPID_RP_HEADER_EDIT(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_RP_HEADER_VIEW) {&ProcessOPID_RP_HEADER_VIEW(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_PRINT_USER) {&ProcessOPID_PRINT_USER(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_TOPUP_PREPAID_CARD_VIEW) {&ProcessOPID_TOPUP_PREPAID_CARD_VIEW_BM(\%DTemplate, \%DataForm);}
    elsif ($DataForm{'OPID'} == $Ow3bank::OPID_AJAX_LOAD_SCRATCH_CARD) {&ProcessOPID_AJAX_LOAD_SCRATCH_CARD(\%DTemplate, \%DataForm, \%DTemplateAjax);}

=cut
# ~bc_end_if BANK_WWW

    &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "PROCESS_OPID $action: END");
  }

  &DBW3User::dbms_set_module("OPID_POST_VALIDATE_START=".$Ow3bank::gOPID);
  if (&PostValidateData(\%DataForm, \%DTemplate, \%StatisticsData) == 0) {
    &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);
    &DBW3User::dbms_set_module("OPID_POST_VALIDATE_FINISHED_ERR=".$Ow3bank::gOPID);
  } else {
    &DBW3User::dbms_set_module("OPID_POST_VALIDATE_FINISHED_OK=".$Ow3bank::gOPID);
  }

  &CalculateTime(\%StatisticsData);
  $StatisticsData{'USER_ID'}      = $Ow3bank::oSession->GetUserID();
  $StatisticsData{'USER_LOGINID'} = $Ow3bank::oSession->GetUserLoginID();
  &GenerateStatistics($Ow3bank::STAT_UPDATE_OPID, \%StatisticsData);
  &ShowResult(\%DTemplate, \%DataForm, 0, \%DTemplateAjax);

  #///////////////////////////////////////////////////////////////////////////////////////////////////////
  #  Финито, всяка от функциите се грижи да върне на потребителя резултатите.
  #///////////////////////////////////////////////////////////////////////////////////////////////////////

}  # sub main

sub ValidateHTTPData {
  my($RequestData)  = $_[0];
  my($DataFormRef)  = $_[1];
  my($DTemplateRef) = $_[2];

  for ((
        'ACTION',
        'SID',
        'LANGUAGE'
       )
    ) {
    if (!&ValidateHTTPParam($_, $RequestData->{$_}, 0)) {
      &ToolsW3User::GenerateLoadingPageMsg($RequestData);
      &ShowResult($DTemplateRef, $DataFormRef, $Ow3bank::ID_ERR_SEQURITY_VIOLATION);
    }
  }

  return 0;
}  # sub ValidateHTTPData

sub ValidateHTTPParam {
  my($ParamName)  = $_[0];
  my($ParamValue) = $_[1];
  my($Replace)    = $_[2];
  my($bRet)       = 1;

  if ($ParamValue) {
    my($ValidValue, $FieldError) = &CheckString_BM($ParamValue, 4000, $Replace);
    if ($FieldError) {
      $bRet = 0;
      &ToolsW3User::WriteLog($Ow3bank::LOG_ERROR, &UserStringsW3User::GetStringByID($Ow3bank::ID_ERR_SEQURITY_VIOLATION)." $ParamName - $FieldError - $ParamValue");
    }
  }

  return ($bRet);
}  # sub ValidateHTTPParam

sub PrepareHTTPData {
  my($RequestData) = $_[0];
  my($DataFormRef) = $_[1];
  my($fldParams)   = '';

  if (
      (!defined $DataFormRef->{'NEW_DOC'} || (defined $DataFormRef->{'NEW_DOC'} && $DataFormRef->{'NEW_DOC'} ne '1')) &&
      (((exists $RequestData->{'PRINT_PREPARE'}) && ($RequestData->{'PRINT_PREPARE'})) ||
       ((exists $RequestData->{'EXEL_PREPARE'}) && ($RequestData->{'EXEL_PREPARE'})) ||
       ((exists $RequestData->{'XML_PREPARE'})  && ($RequestData->{'XML_PREPARE'})))
    ) {
    $fldParams = 'PRINT_ACTIONS_PARAMS';
  } elsif (exists $RequestData->{'DATA_BROWSER_PARAMS'} && $RequestData->{'DATA_BROWSER_PARAMS'}) {
    $fldParams = 'DATA_BROWSER_PARAMS';
  } elsif (defined $RequestData->{'SHOW_BACK_BTN'} && $RequestData->{'SHOW_BACK_BTN'}) {
    $fldParams = 'BACK_ACTION_PARAMS';
  }

  for (keys %$RequestData) {
    $DataFormRef->{$_} = &ToolsW3User::UTF8_to_cp1251($RequestData->{$_});
  }

  if ($fldParams && $RequestData->{$fldParams}) {
    my(@PrintParams) = split($Ow3bank::PP_SEPARATOR, $RequestData->{$fldParams});
    for (my $ii = 0; $ii < @PrintParams; $ii += 2) {
      if ($fldParams ne 'DATA_BROWSER_PARAMS' ||
          $PrintParams[$ii] ne 'START_POSITION') {
        if ($PrintParams[$ii]) {
          $DataFormRef->{$PrintParams[$ii]} = &ToolsW3User::UTF8_to_cp1251($PrintParams[$ii+1]);
        }
      }
    }
  }

  $Ow3bank::CURR_ACTION_PARAMS = &GetActionParams($DataFormRef);

  return 0;
}  # PrepareHTTPData

sub FixParam {
  my $Value = $_[0];

  # Това е за да мине отварянето на файла през опцията -T - предпазваме името на файла от опасни символи
  if ($Value =~ m/^(.+)$/) {
    $Value = $1;
  }

  return $Value;
}  # FixParam

sub PreValidateData {
  my($DataRef)        = $_[0];
  my($StatisticsData) = $_[1];
  my($DTemplAjax)     = $_[2];

  my($FieldError)        = '';
  my($ValidateValue)     = '';
  my($ValidationDataRef) = '';

  return 2 if not exists ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[7];

  if (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[7] != 0) {
    $ValidationDataRef = &{${$Ow3bank::OPID{$DataRef->{'OPID'}}}[7]}($DataRef, $DTemplAjax);

    if (!$ValidationDataRef->{'SYS_OPID_NO_TO_PROCESS_IF_ERROR'}) {
      $ValidationDataRef->{'SYS_OPID_NO_TO_PROCESS_IF_ERROR'} = $DataRef->{'CALLED_FROM'};
    }

    for (@{$ValidationDataRef->{'SEQUENCE'}}) {

      my($Key) = $_;

      $DataRef->{'ERROR_FIELD'} = $Key;

      if ((not exists $DataRef->{$Key}) || (!($DataRef->{$Key})) || ($DataRef->{$Key} =~ m/^\s+$/)) {

        # ${$ValidationDataRef->{$Key}}[0] - validation function
        # ${$ValidationDataRef->{$Key}}[1] - function params
        # ${$ValidationDataRef->{$Key}}[2] - field label
        # ${$ValidationDataRef->{$Key}}[3] - field is required(0/1)
        # ${$ValidationDataRef->{$Key}}[4] - err field name in html(когато е различно от оригиналното($Key) - това са комботата(най-вече))
        if (!(${$ValidationDataRef->{$Key}}[3])) {
          my $Err = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_EMPTY_FIELD, [${$ValidationDataRef->{$Key}}[2]]);
          $StatisticsData->{'ID_ERR'}   = $Ow3bank::ID_STR_EMPTY_FIELD;
          $StatisticsData->{'ERR_TEXT'} = $Err;

          #$DataRef->{'ERROR_MSG'}       = &ToolsW3User::GenerateErrMsg($Err, 'ERR');
          if (!$DataRef->{'AJAX_CALL'}) {
            $DataRef->{'OPID'} = $ValidationDataRef->{'SYS_OPID_NO_TO_PROCESS_IF_ERROR'};
          }
          if (${$ValidationDataRef->{$Key}}[4]) {
            $DataRef->{'ERROR_FIELD'} = ${$ValidationDataRef->{$Key}}[4];
          } else {
            $DataRef->{'ERROR_FIELD'} = $Key;
          }
          $DataRef->{'ERROR_FOUND'} = 1;

          #$DataRef->{'ERROR_ID'} = $Ow3bank::ID_STR_EMPTY_FIELD;
          if ($ValidationDataRef->{'VALIDATION_MODE'} && $ValidationDataRef->{'VALIDATION_MODE'} eq 'ALL') {
            $DataRef->{'ERROR_MSG'} .= &ToolsW3User::GenerateErrMsg($Err, 'ERR')."<br>";
          } else {
            $DataRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg($Err, 'ERR');
            return (0);
          }
        }
      } else {
        if (ref(${$ValidationDataRef->{$Key}}[1]) eq 'ARRAY') {
          ($ValidateValue, $FieldError) = &{${$ValidationDataRef->{$Key}}[0]}($DataRef->{$Key}, @{${$ValidationDataRef->{$Key}}[1]});
        } else {
          ($ValidateValue, $FieldError) = &{${$ValidationDataRef->{$Key}}[0]}($DataRef->{$Key}, ${$ValidationDataRef->{$Key}}[1]);
        }

        $DataRef->{$Key} = $ValidateValue;

        $DTemplAjax->{$Key} = $DataRef->{$Key};

        if ($FieldError) {
          my $Err = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_INV_DATA_IN_FIELD, [${$ValidationDataRef->{$Key}}[2]]);

          #$DataRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg($Err.(($FieldError eq 1) ? "!" : " : $FieldError!"), 'ERR');
          if (!$DataRef->{'AJAX_CALL'}) {
            $DataRef->{'OPID'} = $ValidationDataRef->{'SYS_OPID_NO_TO_PROCESS_IF_ERROR'};
          }
          if (${$ValidationDataRef->{$Key}}[4]) {
            $DataRef->{'ERROR_FIELD'} = ${$ValidationDataRef->{$Key}}[4];
          } else {
            $DataRef->{'ERROR_FIELD'} = $Key;
          }
          $DataRef->{'ERROR_FOUND'}     = 1;
          $StatisticsData->{'ID_ERR'}   = $Ow3bank::ID_STR_INV_DATA_IN_FIELD;
          $StatisticsData->{'ERR_TEXT'} = $Err.(($FieldError eq 1) ? "!" : " : $FieldError!");
          if ($ValidationDataRef->{'VALIDATION_MODE'} && $ValidationDataRef->{'VALIDATION_MODE'} eq 'ALL') {
            $DataRef->{'ERROR_MSG'} .= &ToolsW3User::GenerateErrMsg($Err.(($FieldError eq 1) ? "!" : " : $FieldError!"), 'ERR')."<br>";
          } else {
            $DataRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg($Err.(($FieldError eq 1) ? "!" : " : $FieldError!"), 'ERR');
            return (0);
          }

          #return (0);
        }
      }
    }  # for (keys %$ValidationDataRef )

    #&ToolsW3User::WriteLog($Ow3bank::LOG_PARAMS, "ERROR_FOUND: ".$DataRef->{'ERROR_FOUND'}) if $DataRef->{'ERROR_FOUND'};
    #&ToolsW3User::WriteLog($Ow3bank::LOG_PARAMS, "ERROR_MSG: ".$DataRef->{'ERROR_MSG'}) if $DataRef->{'ERROR_MSG'};

    if (exists $ValidationDataRef->{'ADDITIONAL_RULES'}) {
      ($FieldError, $DataRef->{'ERROR_FIELD'}) = &{$ValidationDataRef->{'ADDITIONAL_RULES'}}($DataRef, $ValidationDataRef, $DTemplAjax);
      if ($FieldError) {
        $DataRef->{'ERROR_FOUND'} = 1;
        if ($ValidationDataRef->{'VALIDATION_MODE'} && $ValidationDataRef->{'VALIDATION_MODE'} eq 'ALL') {
          $DataRef->{'ERROR_MSG'} .= &ToolsW3User::GenerateErrMsg($FieldError, 'ERR');  #."<br>"
        } else {
          $DataRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg($FieldError, 'ERR');
        }

        #$DataRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg("$FieldError", 'ERR');
        #$StatisticsData->{'ID_ERR'}   = -1;          #пишем -1, защото нямаме стринг за грешката, а само поле, в което имам грешка
        #$StatisticsData->{'ERR_TEXT'} = $FieldError;
        #return (0);
      }
      if ($DataRef->{'ERROR_FOUND'}) {

        #&ToolsW3User::WriteLog($Ow3bank::LOG_PARAMS, "OPIDOPIDOPID: ".$DataRef->{'OPID'}) if $DataRef->{'OPID'};
        if (!$DataRef->{'AJAX_CALL'}) {
          $DataRef->{'OPID'} = $ValidationDataRef->{'SYS_OPID_NO_TO_PROCESS_IF_ERROR'};
        }

        #&ToolsW3User::WriteLog($Ow3bank::LOG_PARAMS, "OPIDOPIDOPID: ".$DataRef->{'OPID'}) if $DataRef->{'OPID'};
        #$DataRef->{'ERROR_FOUND'}     = 1;
        $StatisticsData->{'ID_ERR'}   = -1;          #пишем -1, защото нямаме стринг за грешката, а само поле, в което имам грешка
        $StatisticsData->{'ERR_TEXT'} = $FieldError;
        return (0);
      }
    }

  }

  #&ToolsW3User::WriteLog($Ow3bank::LOG_PARAMS, "ERROR_FOUND: ".$DataRef->{'ERROR_FOUND'}) if $DataRef->{'ERROR_FOUND'};
  #&ToolsW3User::WriteLog($Ow3bank::LOG_PARAMS, "ERROR_MSG: ".$DataRef->{'ERROR_MSG'}) if $DataRef->{'ERROR_MSG'};

  if (!&SessionCustIDEqualsOperCustID($DataRef->{'CUST_ID'})) {
    $StatisticsData->{'ID_ERR'} = $Ow3bank::ID_STR_CUST_NOT_FROM_SESSION1;
    my $Err = &UserStringsW3User::GetStringByID($StatisticsData->{'ID_ERR'});
    $StatisticsData->{'ERR_TEXT'} = $Err;
    $DataRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg($Err, 'ERR');
    if (!$DataRef->{'AJAX_CALL'}) {
      if ($ValidationDataRef && $ValidationDataRef->{'SYS_OPID_NO_TO_PROCESS_IF_ERROR'}) {
        $DataRef->{'OPID'} = $ValidationDataRef->{'SYS_OPID_NO_TO_PROCESS_IF_ERROR'};
      } else {
        $DataRef->{'OPID'} = 0;  #$Ow3bank::OPID_CLOSE_PRODUCT;
      }
    }
    $DataRef->{'ERROR_FOUND'} = 1;
    return (0);
  }

  return 1;
}  # PreValidateData

sub PostValidateData {
  my($DataRef)        = $_[0];
  my($DTemplateRef)   = $_[1];
  my($StatisticsData) = $_[2];

  if (!&SessionCustIDEqualsOperCustID($DTemplateRef->{'CUST_ID'})) {
    $StatisticsData->{'ID_ERR'} = $Ow3bank::ID_STR_CUST_NOT_FROM_SESSION2;
    my $Err = &UserStringsW3User::GetStringByID($StatisticsData->{'ID_ERR'});
    $StatisticsData->{'ERR_TEXT'} = $Err;
    $DataRef->{'ERROR_MSG'}       = &ToolsW3User::GenerateErrMsg($Err, 'ERR');
    $DataRef->{'OPID'}            = 0;
    $DataRef->{'ERROR_FOUND'}     = 1;
    return (0);
  } else {
    return (1);
  }

}  # PostValidateData

#////////////////////////////////////////////////////////////////////////////////////////////////////
#   &VerifyAccess - Проверява дали потребителя има права за достъп до заявените от него обекти.
#   Usage:
#     &VerifyAccess (\%DataForm);
#
#   Parameters :
#     \%DataForm  - референция къмн данните, постъпили от потребителя.
#   Return :
#     0 - Потребителя има необходимите права и всичко е наред.
#     1 - Потребителя няма необходимите права.
#
#////////////////////////////////////////////////////////////////////////////////////////////////////

sub VerifyAccess {
  my($DataRef) = $_[0];

  my($Type)     = 0;
  my(%SendData) = ();

=pod
 ~bc_if_def ADMIN_WWW
  if (($Ow3bank::oSession->IsAdmin) || ($DataRef->{'OPID'} eq $Ow3bank::OPID_SIGN_OUT)) {
    return 0;
  } else {
    return 1;
  }  # Лошо Гошо нямаш права!!!
=cut
# ~bc_end_if ADMIN_WWW

# ~bc_if_def USER_WWW
  return 0 if !${$Ow3bank::OPID{$DataRef->{'OPID'}}}[1];  # Ако действието е общо достъпно, т.е. $Ow3bank::DO_NOT_VALIDATE

  return 1 if !&SetDataForValidation($DataRef, \%SendData);

  return 2 if (($SendData{'NO_ACCOUNT'} eq $Ow3bank::VAR_NOT_DEFINED) ||
               ($SendData{'BANK_ID'} eq $Ow3bank::VAR_NOT_DEFINED));

  my($ValidValue, $FieldError) = (0, 0);
  if ($SendData{'NOACC_TYPE'} == $Ow3bank::VALIDATE_S4ET_ACC ||
      $SendData{'NOACC_TYPE'} == $Ow3bank::VALIDATE_CUST_ID) {
    if (!$SendData{'NO_ACCOUNT'}) {
      $FieldError = 1;
    }
  } else {
    ($ValidValue, $FieldError) = &Check_IBAN($SendData{'NO_ACCOUNT'});
    if ($FieldError) {
      if (&SetCUST_ID_to_NO_ACCOUNT($DataRef->{'OPID'})) {
        $FieldError = 0;
      }
    }
  }
  if ($FieldError) {
    &ToolsW3User::WriteLog($Ow3bank::LOG_ERROR, $FieldError);
  }
  return 3 if ($FieldError ||
               &ValidateBankID($SendData{'BANK_ID'}, 10));

  if ($SendData{'NOACC_TYPE'} == $Ow3bank::VALIDATE_CUST_ID) {
    return 4
      if &VerifyCustID(
                       $SendData{'NO_ACCOUNT'},
                       $SendData{'BANK_ID'},
                       $Ow3bank::oSession->GetUserID(),
                       $SendData{'ACCESS_TYPE'}
                      );
  } else {
    return 4
      if &VerifyAccount(
                        $SendData{'NO_ACCOUNT'},
                        $SendData{'BANK_ID'},
                        $Ow3bank::oSession->GetUserID(),
                        $SendData{'NOACC_TYPE'},
                        $SendData{'ACCESS_TYPE'}
                       );
  }
# ~bc_end_if USER_WWW

  if ($Ow3bank::HBankEnv{'CGI_MODE'} ne $Ow3bank::CGI_MODE_User) {

    # като се изтества да се махне иф-а за ЮБ
    if (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[9]) {
      my($HasPermission) = 0;
      my(@Actions) = split(',', ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[9]);
      for (my $ii = 0; $ii < @Actions; $ii++) {
        if (&HasPermissionForAction($Actions[$ii])) {
          $HasPermission = 1;
          last;
        }
      }
      if (!$HasPermission) {
        return 5;
      }
    }

    return 0 if !${$Ow3bank::OPID{$DataRef->{'OPID'}}}[1];  # Ако действието е общо достъпно

    return 1 if !&SetDataForValidation($DataRef, \%SendData);

    return 2 if ($SendData{'BANK_ID'} == $Ow3bank::VAR_NOT_DEFINED);

    return 3 if (&ValidateBankID($SendData{'BANK_ID'}, 10));

    return 4 if &VerifyBankID($Ow3bank::oSession->GetUserID(), $SendData{'BANK_ID'});
  }
  return 0;

}  #sub VerifyAccess

sub SetDataForValidation {
  my($DataRef)     = $_[0];
  my($SendDataRef) = $_[1];

  $SendDataRef->{'NOACC_TYPE'}  = ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[1];
  $SendDataRef->{'ACCESS_TYPE'} = ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[2];

  if (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[1] == $Ow3bank::VALIDATE_TRANS_KEY) {
    return 0 if ((not exists $DataRef->{'TRANS_KEY'}) || (!($DataRef->{'TRANS_KEY'} =~ m/^\d+$/)));

# ~bc_if_def USER_WWW
    if (&GetAccDataFromDB($DataRef, $SendDataRef)) {
      &GetAccDataFromDB($DataRef, $SendDataRef, 1);
    }
# ~bc_end_if USER_WWW

=pod
 ~bc_if_def BANK_WWW
    &GetAccDataFromDB_BM($DataRef, $SendDataRef);
=cut
# ~bc_end_if BANK_WWW
  } elsif (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[1] == $Ow3bank::VALIDATE_IBAN) {
    if ($DataRef->{'IBAN'}) {
      $SendDataRef->{'NO_ACCOUNT'} = $DataRef->{'IBAN'} ? $DataRef->{'IBAN'} : $Ow3bank::VAR_NOT_DEFINED;
    } elsif ($DataRef->{'NO_ACCOUNT'}) {
      $SendDataRef->{'NO_ACCOUNT'} = $DataRef->{'NO_ACCOUNT'} ? $DataRef->{'NO_ACCOUNT'} : $Ow3bank::VAR_NOT_DEFINED;
    } else {
      $SendDataRef->{'NO_ACCOUNT'} = $Ow3bank::VAR_NOT_DEFINED;
    }

    $SendDataRef->{'BANK_ID'} = $DataRef->{'BANK_ID'} ? $DataRef->{'BANK_ID'} : $Ow3bank::VAR_NOT_DEFINED;
  } else {
    &GetAccDataByOPID($DataRef, $SendDataRef);
  }

  return 1;
}  #sub SetDataForValidation

sub GetAccDataFromDB {
  my($DataRef)      = $_[0];
  my($SendDataRef)  = $_[1];
  my($SearchInArch) = $_[2];
  my($TableName)    = '';
  my($Fields)       = '';
  my($DBResult)     = '';
  my(@ReturnedData) = ();
  my($Ukey)         = $DataRef->{'TRANS_KEY'};
  my($BankID)       = 0;
  my($NoAcc)        = 0;
  my($CurrentOPID)  = 0;
  my($WhereField)   = 'U_KEY';

  $CurrentOPID = ($DataRef->{'OPID'} == $Ow3bank::OPID_OTORIZE_ERROR) ? &ToolsW3User::DeCryptOPID($DataRef->{'ACTION'}) : $DataRef->{'OPID'};

  if ($CurrentOPID == $Ow3bank::OPID_O_311 ||
      $CurrentOPID == $Ow3bank::OPID_DEL_311 ||
      $CurrentOPID == $Ow3bank::OPID_SAVE_311 ||
      $CurrentOPID == $Ow3bank::OPID_EDIT_311 ||
      $CurrentOPID == $Ow3bank::OPID_VIEW_311 ||
      $CurrentOPID == $Ow3bank::OPID_VIEW_IBAN_311) {
    if ($SearchInArch) {
      $TableName = 'PAYBUFO_A';
    } else {
      $TableName = 'PAYBUFO';
    }
    $Fields = 'UNIQCODE, ACCOUNTPAY, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_313 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_313 ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_313 ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_313 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_313 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_IBAN_313) {
    if ($SearchInArch) {
      $TableName = 'PAYBUFO_A';
    } else {
      $TableName = 'PAYBUFO';
    }
    $Fields = 'UNIQCODE, ACCOUNTPAY, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_INCASO ||
           $CurrentOPID == $Ow3bank::OPID_DEL_INCASO ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_INCASO ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_INCASO ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_INCASO ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_IBAN_INCASO) {
    if ($SearchInArch) {
      $TableName = 'REQBUFO_A';
    } else {
      $TableName = 'REQBUFO';
    }
    $Fields = 'UNIQCODE, ACCOUNTRCV, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_413 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_413 ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_413 ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_413 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_413 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_IBAN_413) {
    if ($SearchInArch) {
      $TableName = 'INCASOOUT_A';
    } else {
      $TableName = 'INCASOOUT';
    }
    $Fields = 'UNIQCODE, NOACC, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_VAL ||
           $CurrentOPID == $Ow3bank::OPID_DEL_VAL ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_VAL ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_VAL ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_VAL ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_IBAN_VAL) {
    if ($SearchInArch) {
      $TableName = 'PREVOUT_A';
    } else {
      $TableName = 'PREVOUT';
    }
    $Fields = 'uniqcode, id_expo, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_DECLARATION ||
           $CurrentOPID == $Ow3bank::OPID_DEL_DECLARATION) {
    $TableName = 'WITDRAWPAY';
    $Fields    = 'accbankid,  noacc';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_FREE_MSG ||
           $CurrentOPID == $Ow3bank::OPID_DEL_FREE_MSG ||
           $CurrentOPID == $Ow3bank::OPID_3DS_VIRTU_O) {
    $TableName = 'FREEMSG';
    $Fields    = 'cust_bankid, custid';
  } elsif ($CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_BIZNES_O ||
           $CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_BIZNES_VIEW ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CREDIT_BIZNES ||
           $CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA_O ||
           $CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA_VIEW ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CREDIT_ALTERNATIVA ||
           $CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE_O ||
           $CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE_VIEW ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CREDIT_RAZVITIE) {
    $TableName = 'CREDITS_REQ';
    $Fields    = 'CUST_BANKID, CUST_ID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_CARDS_BLOCK_O ||
           $CurrentOPID == $Ow3bank::OPID_CARDS_BLOCK_DEL ||
           $CurrentOPID == $Ow3bank::OPID_CARDS_UNBLOCK_O ||
           $CurrentOPID == $Ow3bank::OPID_CARDS_UNBLOCK_DEL ||
           $CurrentOPID == $Ow3bank::OPID_CARDS_LIMITS_O ||
           $CurrentOPID == $Ow3bank::OPID_CARDS_LIMITS_DEL ||
           $CurrentOPID == $Ow3bank::OPID_CARDS_CHANGEPIN_O ||
           $CurrentOPID == $Ow3bank::OPID_CARDS_CHANGEPIN_DEL) {
    $TableName = 'CARDS_OPERATIONS';

    #$Fields    = 'ID_CARD, USER_ID';
    $Fields = "(select min(UNIQCODE) ".                     #
      " from ACCOUNTS a ".                                  #
      "where (CUSTID,NOACCOUNT) in (select min(ID_CUST),".  #
      "min(ID_EXPO) ".                                      #
      " from CARDS b ".                                     #
      "where b.ID_CARD=CARDS_OPERATIONS.ID_CARD )), ".      #
                                                            #"b.STATUS = \'$Ow3bank::CardStatus_Active\')), ".             #
      "(select min(ID_CUST) ".                              #
      "  from CARDS c ".                                    #
      " where c.ID_CARD=CARDS_OPERATIONS.ID_CARD ) ";       #
                                                            #"c.STATUS = \'$Ow3bank::CardStatus_Active\') ";
  } elsif ($CurrentOPID == $Ow3bank::OPID_NEW_VISA_O ||
           $CurrentOPID == $Ow3bank::OPID_NEW_VISA_VIEW ||
           $CurrentOPID == $Ow3bank::OPID_DEL_VISA ||
           $CurrentOPID == $Ow3bank::OPID_O_VISA_VIRTU_REQ) {
    $TableName = 'CARDS_REQ';
    $Fields    = 'CUST_BANKID, CUST_ID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_CHANGE_CVVAUTH ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CHANGE_CVVAUTH) {
    $TableName = 'CARDS_REQ';
    $Fields    = 'CUST_BANKID, CUST_ID';
    $Ukey      = "( select req.ID_REQ_CARD from CARDS_REQ_CVVAUTH req where req.U_KEY = $DataRef->{'TRANS_KEY'} )";
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_OTKAZ_MSG ||
           $CurrentOPID == $Ow3bank::OPID_DEL_OTKAZ_MSG) {
    $TableName = 'FREEMSG';
    $Fields    = 'CUST_BANKID, CUSTID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_FM2 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_FM2 ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_FM2 ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_FM2 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_FM2) {
    if ($SearchInArch) {
      $TableName = 'FMSG2_A';
    } else {
      $TableName = 'FMSG2';
    }
    $Fields = 'UNIQCODE, CUSTID, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_FM6 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_FM6 ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_FM6 ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_FM6 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_FM6) {
    if ($SearchInArch) {
      $TableName = 'FMSG6_A';
    } else {
      $TableName = 'FMSG6';
    }
    $Fields = 'UNIQCODE, CUSTID, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_DEC2 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_DEC2) {
    $TableName = 'DEC2';
    $Fields    = 'UNIQCODE, CUSTID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_FM14 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_FM14) {
    $TableName = 'FMSG14';
    $Fields    = 'UNIQCODE, CUSTID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_312 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_312 ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_312 ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_312 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_312 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_IBAN_312) {
    if ($SearchInArch) {
      $TableName = 'PAYBUFO_A';
    } else {
      $TableName = 'PAYBUFO';
    }
    $Fields = 'UNIQCODE, ID_CUST, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_FM11 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_FM11) {
    $TableName = 'FMSG11';
    $Fields    = 'UNIQCODE, CUSTID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_STAT_FORM ||
           $CurrentOPID == $Ow3bank::OPID_DEL_STAT_FORM) {
    $TableName = 'FM_STAT_FORM';
    $Fields    = 'UNIQCODE, CUSTID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_FREEOPERS ||
           $CurrentOPID == $Ow3bank::OPID_DEL_FREEOPERS ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_FREEOPERS ||
           $CurrentOPID == $Ow3bank::OPID_O_CURR_TRANSL_CHAMELEON ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CURR_TRANSL_CHAMELEON ||
           $CurrentOPID == $Ow3bank::OPID_TOPUP_PREPAID_CARD_O ||
           $CurrentOPID == $Ow3bank::OPID_TOPUP_PREPAID_CARD_DEL ||
           $CurrentOPID == $Ow3bank::OPID_TOPUP_PREPAID_CARD_VIEW) {
    if ($SearchInArch) {
      $TableName = 'FREE_OPERS_A';
    } else {
      $TableName = 'FREE_OPERS';
    }
    $Fields = 'UNIQCODE, EXPO_SND, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_PRODUCT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_PRODUCT ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_O) {
    $TableName = 'PRODUCTS';
    $Fields    = 'UNIQCODE, IBAN_SND';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_OVERDRAFT ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_OVERDRAFT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_OVERDRAFT) {
    $TableName = 'CRED_C_OVERDRAFT';
    $Fields    = 'BANK_ID, IBAN';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_BUYSELLVAL ||
           $CurrentOPID == $Ow3bank::OPID_DEL_BUYSELLVAL ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_BUYSELLVAL ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_BUYSELLVAL ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_BUYSELLVAL) {
    my($IsSell) = 0;
    my($IsBuy)  = 0;
    if ($SearchInArch) {
      if ($IsSell = &CheckValOperType($Ukey, 'FMSG2_A')) {
        $TableName = 'FMSG2_A';
      } elsif ($IsBuy = &CheckValOperType($Ukey, 'FMSG6_A')) {
        $TableName = 'FMSG6_A';
      }
    } else {
      if ($IsSell = &CheckValOperType($Ukey, 'FMSG2')) {
        $TableName = 'FMSG2';
      } elsif ($IsBuy = &CheckValOperType($Ukey, 'FMSG6')) {
        $TableName = 'FMSG6';
      }
    }
    if (!$IsSell && !$IsBuy) {
      return 4;
    }
    $Fields = 'UNIQCODE, ACCOUNTBGL, CH_OPER, CH_DATE';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_VISA_CREDIT_CARD ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_VISA_CREDIT_CARD ||
           $CurrentOPID == $Ow3bank::OPID_DEL_VISA_CREDIT_CARD) {
    $TableName = 'CARDS_CRED_REQ';
    $Fields    = 'BANK_ID, CUST_ID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_CONSUMER_LOAN ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_CONSUMER_LOAN ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CONSUMER_LOAN) {
    $TableName = 'CRED_C_POTREBITELSKI';
    $Fields    = 'BANK_ID, CUST_ID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_MORTGAGE_LOAN ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_MORTGAGE_LOAN ||
           $CurrentOPID == $Ow3bank::OPID_DEL_MORTGAGE_LOAN) {
    $TableName = 'CRED_C_IPOTECHEN';
    $Fields    = 'BANK_ID, CUST_ID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_REQ_ACCOUNTS ||
           $CurrentOPID == $Ow3bank::OPID_O_EXCLUDE_ACCOUNT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_REQ_ACCOUNTS ||
           $CurrentOPID == $Ow3bank::OPID_DEL_EXCLUDE_ACCOUNT) {
    $TableName  = 'REQRIGHT_HEAD';
    $Fields     = 'BANK_ID, ID_CUST';
    $WhereField = 'ID_REQ';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_REQ_ACCOUNTS_JUR) {
    $TableName  = 'NEW_USERS_REQ';
    $Fields     = 'FIN_CENTYR';
    $WhereField = 'U_KEY';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_REQ_PAY_INFO ||
           $CurrentOPID == $Ow3bank::OPID_DEL_REQ_PAY_INFO ||
           $CurrentOPID == $Ow3bank::OPID_O_CALL_CENTER_REQ ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CALL_CENTER_REQ) {
    $TableName = 'PAYINFOREG';
    $Fields    = 'BANK_ID, CUST_ID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_CLOSE_PRODUCT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_CLOSE_PRODUCT) {
    $TableName = 'FREE_OPERS';
    $Fields    = 'UNIQCODE, EXPO_SND';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_CUST_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_LOGIN_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_ACC_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_REG_PAY_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_REQ_PARAGONI ||
           $CurrentOPID == $Ow3bank::OPID_O_REQ_CRED_CARD_IZVL ||
           $CurrentOPID == $Ow3bank::OPID_DEL_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_DEL_REQ_PARAGONI ||
           $CurrentOPID == $Ow3bank::OPID_DEL_REQ_CRED_CARD_IZVL ||
           $CurrentOPID == $Ow3bank::OPID_O_CARD_NOTIFICATION_REQ) {
    $TableName = 'MSGCONF_REQ_WEB2ORA';
    $Fields    = 'BANK_ID, CUST_ID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_REQ_SEBRA_REPORT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_REQ_SEBRA_REPORT) {
    $TableName = 'REQ_REPORTS';
    $Fields    = 'ID_BANK, ID_CUST';
  }

  elsif ($CurrentOPID == $Ow3bank::OPID_O_VAL_B7 ||
         $CurrentOPID == $Ow3bank::OPID_DEL_VAL_B7) {
    $TableName = 'B7_CREDPAY';
    $Fields    = 'UNIQCODE, AT01_SND_IBAN';
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_DEACTIVATE_REGULAR_PAYMENT ||
           $CurrentOPID == $Ow3bank::OPID_O_311_REGULAR_PAYMENT ||
           $CurrentOPID == $Ow3bank::OPID_O_313_REGULAR_PAYMENT ||
           $CurrentOPID == $Ow3bank::OPID_O_PAY_TO_OWN_ACCOUNT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_311_REGULAR_PAYMENT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_313_REGULAR_PAYMENT ||
           $CurrentOPID == $Ow3bank::OPID_DEL_PAY_TO_OWN_ACCOUNT) {
    $TableName = 'REGULAR_PAYMENTS_REQ';
    $Fields    = 'UNIQCODE, ID_EXPO';
  } elsif ($CurrentOPID == $Ow3bank::OPID_DATAMAX_PAY_O) {
    $TableName = "(select regp.UNIQCODE, ".     #
      " bill.ID_EXPO,  ".                       #
      " bill.U_KEY     ".                       #
      " from COMMUNALPAY_REG_PAY regp,      ".  #
      " COMMUNALPAY_PENDING_BILLS bill ".       #
      " where bill.U_KEY = $Ukey and       ".   #
      " bill.ID_REG_PAY = regp.ID_REG)";

    $Fields = 'UNIQCODE, ID_EXPO';
  } elsif ($CurrentOPID == $Ow3bank::OPID_USERDOCS_O ||
           $CurrentOPID == $Ow3bank::OPID_USERDOCS_DEL) {
    $TableName = 'USER_DOCS';
    $Fields    = 'UNIQCODE, CUSTID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_DEC_NAR28_O ||
           $CurrentOPID == $Ow3bank::OPID_DEC_NAR28_DEL) {
    $TableName = 'DEC_NAR28';
    $Fields    = 'UNIQCODE, CUSTID';
  } elsif ($CurrentOPID == $Ow3bank::OPID_IMP_SALARY_O ||
           $CurrentOPID == $Ow3bank::OPID_IMP_SALARY_DEL) {
    $TableName  = 'IMP_SALARY_HEADER';
    $Fields     = 'UNIQCODE, IBAN_EMPL';
    $WhereField = 'ID_HEAD';
  } elsif ($CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_O ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIEW ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_EDIT ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_DEL ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_O ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_VIEW ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_EDIT ||
           $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_DEL) {
    $TableName = 'PRODUCTS';
    $Fields    = 'UNIQCODE, DT_EXPO';
  }

  my($Sql) = "select ".  #
    "$Fields ".          #
    "from ".             #
    "$TableName ".       #
    "where ".            #
    "$WhereField = $Ukey ";

  if ($SearchInArch) {
    if ($TableName ne 'MSGCONF_REQ_WEB2ORA') {
      $Sql = " select * from ($Sql order by CH_DATE desc nulls last) where rownum = 1";
    }
  }
  $DBResult = &DBW3User::ExecuteSQLStatement($Sql, 0, 0, 0, 1);

  @ReturnedData = &DBW3User::FetchRow(\$DBResult);

  if (!@ReturnedData) {
    return 4;
  }

  if ($TableName eq 'PREVOUT' ||
      $TableName eq 'PREVOUT_A' ||
      $TableName eq 'REGULAR_PAYMENTS_REQ' ||
      $CurrentOPID == $Ow3bank::OPID_DATAMAX_PAY_O ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_O ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIEW ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_EDIT ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_DEL ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_O ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_VIEW ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_EDIT ||
      $CurrentOPID == $Ow3bank::OPID_NEW_ACCOUNT_VIRTUAL_IBAN_DEL) {
    $SendDataRef->{'NOACC_TYPE'} = $Ow3bank::VALIDATE_S4ET_ACC;
  } elsif ($CurrentOPID == $Ow3bank::OPID_O_312 ||
           $CurrentOPID == $Ow3bank::OPID_DEL_312 ||
           $CurrentOPID == $Ow3bank::OPID_SAVE_312 ||
           $CurrentOPID == $Ow3bank::OPID_EDIT_312 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_312 ||
           $CurrentOPID == $Ow3bank::OPID_VIEW_IBAN_312 ||
           $CurrentOPID == $Ow3bank::OPID_O_CUST_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_ACC_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_LOGIN_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_REG_PAY_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_DEL_NOTIFICATION_REQ ||
           $CurrentOPID == $Ow3bank::OPID_O_REQ_PARAGONI ||
           $CurrentOPID == $Ow3bank::OPID_DEL_REQ_PARAGONI ||
           $CurrentOPID == $Ow3bank::OPID_O_REQ_CRED_CARD_IZVL ||
           $CurrentOPID == $Ow3bank::OPID_DEL_REQ_CRED_CARD_IZVL ||
           $TableName eq 'DEC2' ||
           $TableName eq 'FREEMSG' ||
           $TableName eq 'CARDS_OPERATIONS' ||
           $TableName eq 'CREDITS_REQ' ||
           $TableName eq 'CARDS_REQ' ||
           $TableName eq 'FMSG11' ||
           $TableName eq 'FMSG14' ||
           $TableName eq 'FM_STAT_FORM' ||
           $TableName eq 'CARDS_CRED_REQ' ||
           $TableName eq 'CRED_C_POTREBITELSKI' ||
           $TableName eq 'CRED_C_IPOTECHEN' ||
           $TableName eq 'REQRIGHT_HEAD' ||
           $TableName eq 'PAYINFOREG' ||
           $TableName eq 'REQ_REPORTS' ||
           $TableName eq 'USER_DOCS' ||
           $TableName eq 'DEC_NAR28') {
    $SendDataRef->{'NOACC_TYPE'} = $Ow3bank::VALIDATE_CUST_ID;
  } else {
    $SendDataRef->{'NOACC_TYPE'} = $Ow3bank::VALIDATE_IBAN;
  }

  if (scalar @ReturnedData >= 2) {
    $BankID = $ReturnedData[0] ? $ReturnedData[0] : 0;
    $NoAcc  = $ReturnedData[1] ? $ReturnedData[1] : 0;

    $SendDataRef->{'BANK_ID'}    = $BankID ? $BankID : $Ow3bank::VAR_NOT_DEFINED;
    $SendDataRef->{'NO_ACCOUNT'} = $NoAcc  ? $NoAcc  : $Ow3bank::VAR_NOT_DEFINED;

    if (scalar @ReturnedData == 4) {
      $SendDataRef->{'CH_OPER'} = $ReturnedData[2];
      $SendDataRef->{'CH_DATE'} = $ReturnedData[3];
    }

  } else {
    $SendDataRef->{'BANK_ID'}    = $Ow3bank::VAR_NOT_DEFINED;
    $SendDataRef->{'NO_ACCOUNT'} = $Ow3bank::VAR_NOT_DEFINED;
  }

  return 0;
}  #sub GetAccDataFromDB

sub GetAccDataByOPID {
  my($DataRef)     = $_[0];
  my($SendDataRef) = $_[1];

  if (&SetCUST_ID_to_NO_ACCOUNT($DataRef->{'OPID'})) {
    $SendDataRef->{'NO_ACCOUNT'} = $DataRef->{'CUST_ID'} ? $DataRef->{'CUST_ID'} : $Ow3bank::VAR_NOT_DEFINED;
    $SendDataRef->{'BANK_ID'}    = $DataRef->{'BANK_ID'} ? $DataRef->{'BANK_ID'} : $Ow3bank::VAR_NOT_DEFINED;
  } else {
    $SendDataRef->{'NO_ACCOUNT'} = $DataRef->{'NO_ACCOUNT'} ? $DataRef->{'NO_ACCOUNT'} : $Ow3bank::VAR_NOT_DEFINED;
    $SendDataRef->{'BANK_ID'}    = $DataRef->{'BANK_ID'}    ? $DataRef->{'BANK_ID'}    : $Ow3bank::VAR_NOT_DEFINED;
  }
  return 0;
}  #sub GetAccDataByOPID

sub SetCUST_ID_to_NO_ACCOUNT {
  my($OPID) = $_[0];

  return (
    $OPID == $Ow3bank::OPID_SAVE_FREE_MSG ||                    #
      $OPID == $Ow3bank::OPID_SAVE_OTKAZ_MSG ||                 #
      $OPID == $Ow3bank::OPID_SAVE_FM2 ||                       #
      $OPID == $Ow3bank::OPID_SAVE_FM6 ||                       #
      $OPID == $Ow3bank::OPID_SAVE_DEC2 ||                      #
      $OPID == $Ow3bank::OPID_SAVE_FM14 ||                      #
      $OPID == $Ow3bank::OPID_SAVE_312 ||                       #
      $OPID == $Ow3bank::OPID_SAVE_FM11 ||                      #
      $OPID == $Ow3bank::OPID_SAVE_STAT_FORM ||                 #
      $OPID == $Ow3bank::OPID_SAVE_BUYSELLVAL ||                #
      $OPID == $Ow3bank::OPID_SAVE_VISA_CREDIT_CARD ||          #
      $OPID == $Ow3bank::OPID_SAVE_CONSUMER_LOAN ||             #
      $OPID == $Ow3bank::OPID_SAVE_MORTGAGE_LOAN ||             #
      $OPID == $Ow3bank::OPID_SAVE_REQ_ACCOUNTS ||              #
      $OPID == $Ow3bank::OPID_SAVE_REQ_ACCOUNTS_JUR ||          #
      $OPID == $Ow3bank::OPID_SAVE_REQ_PAY_INFO ||              #
      $OPID == $Ow3bank::OPID_SAVE_ACC_NOTIFICATION_REQ ||      #
      $OPID == $Ow3bank::OPID_SAVE_CUST_NOTIFICATION_REQ ||     #
      $OPID == $Ow3bank::OPID_SAVE_LOGIN_NOTIFICATION_REQ ||    #
      $OPID == $Ow3bank::OPID_SAVE_REG_PAY_NOTIFICATION_REQ ||  #
      $OPID == $Ow3bank::OPID_SAVE_REQ_PARAGONI ||              #
      $OPID == $Ow3bank::OPID_SAVE_REQ_SEBRA_REPORT ||          #
      $OPID == $Ow3bank::OPID_NEW_VISA_SAVE ||                  #
      $OPID == $Ow3bank::OPID_SAVE_CALL_CENTER_REQ ||           #
      $OPID == $Ow3bank::OPID_SAVE_VISA_VIRTU_REQ ||            #
      $OPID == $Ow3bank::OPID_SAVE_REQ_CRED_CARD_IZVL ||        #
      $OPID == $Ow3bank::OPID_SAVE_CARD_NOTIFICATION_REQ ||     #
      $OPID == $Ow3bank::OPID_USERDOCS_SAVE ||                  #
      $OPID == $Ow3bank::OPID_CUST_CHANGE_SAVE ||               #
      $OPID == $Ow3bank::OPID_DEC_NAR28_SAVE ||                 #
      $OPID == $Ow3bank::OPID_SHOW_SEBRA_MSG_REPORT2 ||         #
      $OPID == $Ow3bank::OPID_SHOW_SEBRA_LIMITS_REPORT
  );
}  #sub SetCUST_ID_to_NO_ACCOUNT

#////////////////////////////////////////////////////////////////////////////////////////////////////
#   &ShowResult - Показва резултата от заявката в BROWSER.
#   Usage:
#     &ShowResult (\%DTemplate,\%Data);
#
#   Parameters :
#     \%DTemplate - референция към хеш съдържаща данните, които да се покажат на потребителя.
#     \%DataRef   - референция към данните, постъпили от потребителя.
#     $Error      - флаг за зареждане на Template за грешка
#   Return :
#     Прекратява работата на скрипта.
#
#////////////////////////////////////////////////////////////////////////////////////////////////////

sub ShowResult {
  my($DTemplateRef) = $_[0];
  my($DataRef)      = $_[1];
  my($Error)        = $_[2] ? $_[2] : 0;
  my($DTemplAjax)   = $_[3];
  my($WelcomeMsg)   = $_[4] ? $_[4] : '';
  my($ErrorMsg)     = $_[5] ? $_[5] : '';

  my($TemplateName)   = '';
  my($oTemplate)      = 0;
  my($InterfaceLang)  = $Ow3bank::gLanguage;
  my(%StatisticsData) = ();

  my($SecHTMLStampBegin, $MicroHTMLStampBegin) = gettimeofday();
  $MicroHTMLStampBegin = int($MicroHTMLStampBegin/1000);

  $StatisticsData{'HTML_START'} = "to_date(\'".&ToolsW3User::GetCurrentDateTimeString('dd.mm.yyyy hh:mn:ss')."\',\'dd-mm-yyyy hh24:mi:ss\')";

  $DataRef->{'OPID'} = $DataRef->{'OPID'} ? $DataRef->{'OPID'} : '';
  &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "SHOW_RESULT - Error: $Error");

  if (
      !$Ow3bank::bValidatingRequest &&
      (
       !$Error ||
       ($Error != $Ow3bank::ID_ERR_ACCESS_DENIED &&
        $Error != $Ow3bank::ID_ERR_CANT_CONNECT_TO_DB)
      )
    ) {

    # накрая се валидира заявката - винаги, без значение как са приключили предходните проверки
    # последователността е такава, за да имаме сесията и за да знаем опита за вход дали е успешен или не
    my $UserID = $Ow3bank::oSession ? $Ow3bank::oSession->GetUserID() : 0;
    my($ErrReq, $AddErrReq) = &ToolsW3User::ValidateRequest($Ow3bank::RequestData, $UserID, $Error);
    if (!$Error || $Error == $Ow3bank::ERR_NO_ERROR) {
      $Error = $ErrReq;
    }
  }

  if ($Ow3bank::gOPID eq 'HEALTH_CHECK') {
    $Ow3bank::gEmptyLoadingPageMsg = 0;
    if (!$Error) {
      print "Content-Type: text/html;charset=UTF-8\r\n\n";
    } else {
      print "Content-Type: text/html;charset=UTF-8\r\nStatus: 500\r\n\n";
    }
  } else {
    &ToolsW3User::SetSystemTmplVars($DTemplateRef, 0);
    if (!$Error) {

      #if ($Ow3bank::gEmptyContentType) {
      #  #if ($Ow3bank::gOPID eq 'NEW_TAN') {
      #  #  my $charset = 'UTF-8';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
      #  #  print "Content-Type: text/html;charset=$charset\r\n\n";
      #  #  if ($DataRef->{'ERROR_FOUND'}) {
      #  #    $Ow3bank::gEmptyLoadingPageMsg = 1;
      #  #  } else {
      #  #    $Ow3bank::gEmptyLoadingPageMsg = 0;
      #  #  }
      #  #}
      #}

      if (
        $Ow3bank::gEmptyLoadingPageMsg &&
        $Ow3bank::gOPID &&
        (
         $Ow3bank::gOPID eq 'LOGIN_VERIFICATION' ||
         $Ow3bank::gOPID eq 'CONNECT_AND_LOGIN'     #||
                                                    #($Ow3bank::gOPID eq 'NEW_TAN' &&
                                                    # $DataRef->{'ERROR_FOUND'})
        )
        ) {
        &ToolsW3User::GenerateLoadingPageMsg();
      }

      if (
          exists $DataRef->{'OPID'} &&
          $DataRef->{'OPID'} &&
          ($DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_PAY_INFO_DOC ||
           $DataRef->{'OPID'} == $Ow3bank::OPID_HEALTH_CHECK)
        ) {
        1;
      } elsif ((exists $DataRef->{'PRINT_PREPARE'}) ||
               (exists $DataRef->{'PDF_PREPARE'})) {
        if (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]) {
          $DTemplateRef->{${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]} = 1;
        } else {
          $DTemplateRef->{'INCLUDE_MSG_PAGE'} = 1;
        }
        $DTemplateRef->{'PRINT_PREPARE'} = 1;

        delete $DTemplateRef->{'XLS_NAME'};
        delete $DTemplateRef->{'XML_NAME'};
        delete $DTemplateRef->{'PDF_NAME'};
        delete $DTemplateRef->{'CAN_EDIT'}    if (exists $DTemplateRef->{'CAN_EDIT'});
        delete $DTemplateRef->{'CAN_OTORIZE'} if (exists $DTemplateRef->{'CAN_OTORIZE'});

        $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::PT_FRAME, $InterfaceLang);

        #&ToolsW3User::WriteLog($Ow3bank::LOG_ERROR, $DataRef->{'OPID'});
        if ($DataRef->{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFO_PRINT) {
          $DTemplateRef->{'PDF_PREPARE'} = 1;
        }

=pod
 ~bc_if_not_def USER_WWW
        #if (${$Ow3bank::OPID{"$DataRef->{'OPID'}"}}[6]) {
        #  $TemplateName = ${$Ow3bank::OPID{"$DataRef->{'OPID'}"}}[6];
        #} else {
        #  if (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]) {
        #    $DTemplateRef->{${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]} = 1;
        #  }
        #  $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::PT_FRAME, $InterfaceLang);
        #}
=cut
# ~bc_end_if USER_WWW

      } elsif (exists $DataRef->{'EXEL_PREPARE'}) {
        if (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]) {
          $DTemplateRef->{${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]} = 1;
        } else {
          $DTemplateRef->{'INCLUDE_MSG_PAGE'} = 1;
        }

        delete $DTemplateRef->{'XLS_NAME'};
        delete $DTemplateRef->{'XML_NAME'};
        delete $DTemplateRef->{'PDF_NAME'};
        delete $DTemplateRef->{'CAN_EDIT'}    if (exists $DTemplateRef->{'CAN_EDIT'});
        delete $DTemplateRef->{'CAN_OTORIZE'} if (exists $DTemplateRef->{'CAN_OTORIZE'});
        $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::EXCEL_FRAME, $InterfaceLang);
      } elsif (exists $DataRef->{'XML_PREPARE'}) {
        if (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]) {
          $DTemplateRef->{${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]} = 1;
        } else {
          $DTemplateRef->{'INCLUDE_MSG_PAGE'} = 1;
        }
        delete $DTemplateRef->{'XLS_NAME'};
        delete $DTemplateRef->{'XML_NAME'};
        delete $DTemplateRef->{'PDF_NAME'};
        delete $DTemplateRef->{'CAN_EDIT'}    if (exists $DTemplateRef->{'CAN_EDIT'});
        delete $DTemplateRef->{'CAN_OTORIZE'} if (exists $DTemplateRef->{'CAN_OTORIZE'});
        $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::EXCEL_FRAME, $InterfaceLang);
      } else {
        if (
            !$Ow3bank::gOPID ||
            (
             $DataRef->{'OPID'} &&
             (
              $DataRef->{'OPID'} == $Ow3bank::OPID_ACCESS ||
              $DataRef->{'OPID'} == $Ow3bank::OPID_EXT_USER_REG ||
              $DataRef->{'OPID'} == $Ow3bank::OPID_EXT_USER_ACTIVATE_MAIL ||
              $DataRef->{'OPID'} == $Ow3bank::OPID_EFAKT_REQUEST ||
              $DataRef->{'OPID'} == $Ow3bank::OPID_PSD2_CONSENT_REQUEST ||
              $DataRef->{'OPID'} == $Ow3bank::OPID_PSD2_PAYBUFO_REQUEST ||
              $DataRef->{'OPID'} == $Ow3bank::OPID_PSD2_PREVOUT_REQUEST ||
              $DataRef->{'OPID'} == $Ow3bank::OPID_PSD2_AUTHENTICATION_REQUEST ||
              ($DataRef->{'OPID'} == $Ow3bank::OPID_CHANGE_LANGUAGE &&
                !$Ow3bank::oSession->GetUserID)
             )
            )
          ) {
          $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::HT_LOGIN_MAIN, $InterfaceLang);
          $DTemplateRef->{'PRE_LOAD'} = 1;
        } else {
          $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::HT_LOGIN, $InterfaceLang);
        }

        $DTemplateRef->{'SCRIPT_NAME'} = $Ow3bank::HBankEnv{'FULL_CGI_NAME'};
        if (exists $DataRef->{'ERROR_MSG'}) {
          $DTemplateRef->{'ERROR_MSG'} = $DataRef->{'ERROR_MSG'};
        }
        if (not exists $DTemplateRef->{'SID'}) {
          $DTemplateRef->{'SID'} = $DataRef->{'SID'} ? $DataRef->{'SID'} : $Ow3bank::HBankEnv{'SID'};
        }
        if (exists $DataRef->{'OPID'} && $DataRef->{'OPID'} && ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]) {
          $DTemplateRef->{${$Ow3bank::OPID{$DataRef->{'OPID'}}}[3]} = 1;
        } else {
          $DTemplateRef->{'INCLUDE_MSG_PAGE'} = 1;
        }
        if (
          exists $DataRef->{'OPID'} &&
          (
            !$DataRef->{'OPID'} ||
            ($DataRef->{'OPID'} != $Ow3bank::OPID_ACCESS &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_EXT_USER_REG &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_EXT_USER_ACTIVATE_MAIL &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_SIGN_OUT &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_SHOW_CONDITIONS &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_GENERATE_PLAN &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_GET_REQUEST_HTML &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_EFAKT_REQUEST &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_PSD2_CONSENT_REQUEST &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_PSD2_PAYBUFO_REQUEST &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_PSD2_PREVOUT_REQUEST &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_PSD2_AUTHENTICATION_REQUEST &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_CHANGE_LANGUAGE &&
              $DataRef->{'OPID'} != $Ow3bank::OPID_HEALTH_CHECK) ||
            ($DataRef->{'OPID'} == $Ow3bank::OPID_CHANGE_LANGUAGE &&
              $Ow3bank::oSession &&
              $Ow3bank::oSession->GetUserID)  # ако юзера се е логнал=> показваме лявото меню
          )
          ) {
          if (($Ow3bank::oSession) && (!$DataRef->{'OPID'} || $DataRef->{'OPID'} != $Ow3bank::OPID_EFAKT_STATUSCHECK)) {
            $DTemplateRef->{'USER_FULL_NAME'} = $Ow3bank::oSession->GetUserFullName();
            &SetUserCustDataLV($DTemplateRef, $DataRef, 'TOP_CUST_LV');
            if ($Ow3bank::oSession->GetUserLIRetries() >= &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome', 'MAX_INVALID_PASS_ATTEMPTS', 0)) {
              &ToolsW3User::WriteError($Ow3bank::ID_ERR_SEQURITY_VIOLATION);
            }
          }

          if ((exists $DataRef->{'OPID'} && $DataRef->{'OPID'}) && (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[4] == 1) && (!defined $DataRef->{'NEW_DOC'} || (defined $DataRef->{'NEW_DOC'} && $DataRef->{'NEW_DOC'} ne '1'))) {
            &AddPrintPage($DataRef, $DTemplateRef, 0);
          } elsif ((exists $DataRef->{'OPID'} && $DataRef->{'OPID'}) && ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[4] == 2 && (!defined $DataRef->{'NEW_DOC'} || (defined $DataRef->{'NEW_DOC'} && $DataRef->{'NEW_DOC'} ne '1'))) {
            &AddPrintPage($DataRef, $DTemplateRef, 1);
          } elsif ((exists $DataRef->{'OPID'} && $DataRef->{'OPID'}) && ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[4] == 3 && (!defined $DataRef->{'NEW_DOC'} || (defined $DataRef->{'NEW_DOC'} && $DataRef->{'NEW_DOC'} ne '1'))) {
            &AddPrintPage($DataRef, $DTemplateRef, 1, 1);
          } elsif ((exists $DataRef->{'OPID'} && $DataRef->{'OPID'}) && ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[4] == 4 && (!defined $DataRef->{'NEW_DOC'} || (defined $DataRef->{'NEW_DOC'} && $DataRef->{'NEW_DOC'} ne '1'))) {
            &AddPrintPage($DataRef, $DTemplateRef, 0, 0, 1);
          }

          if ($DataRef->{'OPID'} && ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[5]) {
            &AddDataBrowser($DataRef, $DTemplateRef);
          }

          # това не се ползва
          #if  ( ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[9] )
          #  {$DTemplateRef->{'HELP_PAGE_LINK'} = 'help/'.${$Ow3bank::OPID{$DataRef->{'OPID'}}}[9];}

          if (exists $DTemplateRef->{'CAN_OTORIZE'} && $DTemplateRef->{'CAN_OTORIZE'} == 1) {
            if ($Ow3bank::oSession->GetUserAuthType() eq $Ow3bank::AuthTypeOTP) {
              $DTemplateRef->{'USE_OTP'} = 1;
            }
            $DataRef->{'TRANS_KEY'} = $DataRef->{'TRANS_KEY'} ? $DataRef->{'TRANS_KEY'} : $DTemplateRef->{'TRANS_KEY'};
            if ($Ow3bank::oSession->GetUserTanSMS() || ($Ow3bank::oSession->GetUserAuthType() eq $Ow3bank::AuthTypeTANBySMS)) {
              $DTemplateRef->{'OPID_SEND_TAN_BY_SMS'}   = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SEND_TAN_BY_SMS);
              $DTemplateRef->{'CAN_REQUEST_TAN_ON_SMS'} = 1;
            }
            $DTemplateRef->{'USE_KEP'}   = $Ow3bank::oSession->GetUserUseKEP();
            $DTemplateRef->{'DATA_HASH'} = $DataRef->{'DATA_HASH'};
          }
          if (exists $DTemplateRef->{'CAN_OTORIZE'} && $DTemplateRef->{'CAN_OTORIZE'} == 1) {
            $DataRef->{'TRANS_KEY'} = $DataRef->{'TRANS_KEY'} ? $DataRef->{'TRANS_KEY'} : $DTemplateRef->{'TRANS_KEY'};
            if (&MustAuthorizeWithTANCode($DataRef, $Ow3bank::oSession->GetUserTanCodeSum())) {
              $DTemplateRef->{'OPID_SEND_TAN_BY_SMS'}   = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SEND_TAN_BY_SMS);
              $DTemplateRef->{'CAN_REQUEST_TAN_ON_SMS'} = $Ow3bank::oSession->GetUserTanSMS();
            }
          }
          &Prepare_oFrameParameters($DTemplateRef, $DataRef);
        } elsif (exists $DataRef->{'OPID'} && $DataRef->{'OPID'} && $DataRef->{'OPID'} == $Ow3bank::OPID_GENERATE_PLAN) {

          if (($DataRef->{'OPID'}) &&
              (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[4] == 1) &&
              (!defined $DataRef->{'NEW_DOC'} || (defined $DataRef->{'NEW_DOC'} && $DataRef->{'NEW_DOC'} ne '1'))) {
            &AddPrintPage($DataRef, $DTemplateRef, 0);
          } elsif (${$Ow3bank::OPID{$DataRef->{'OPID'}}}[4] == 2 &&
                   (!defined $DataRef->{'NEW_DOC'} || (defined $DataRef->{'NEW_DOC'} && $DataRef->{'NEW_DOC'} ne '1'))) {
            &AddPrintPage($DataRef, $DTemplateRef, 1);
          }

        }

      }
    } else { 
      # при грешка #
      ##############
      #Ако няма Content-type сеткаме по default text/html
      if ($Ow3bank::gEmptyContentType) {
        my $charset = 'UTF-8';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
        print "Content-Type: text/html;charset=$charset\r\n\n";
      }

      if ($Ow3bank::gEmptyLoadingPageMsg) {

        # някаква кретения се заформи тука
        if (
            !$Ow3bank::gOPID ||
            ($Ow3bank::gOPID ne 'LOGIN_VERIFICATION' &&
             $Ow3bank::gOPID ne 'CONNECT_AND_LOGIN') ||
            !($Error == $Ow3bank::ID_ERR_INVALID_PASSWORD || $Error == $Ow3bank::ID_ERR_INVALID_USERNAME || $Error == $Ow3bank::ID_ERR_INVALID_CAPTCHA || $Error == $Ow3bank::ID_STR_INVALID_OTP)
          ) {
          &ToolsW3User::GenerateLoadingPageMsg();
        }
      }

      $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::HT_LOGIN, $InterfaceLang);
      $DTemplateRef->{'INCLUDE_SYSTEM_ERROR'} = 1;

      if ($Error != $Ow3bank::ID_ERR_CANT_CONNECT_TO_DB) {
        $StatisticsData{'ID_ERR'} = $Error;
        &GenerateStatistics($Ow3bank::STAT_UPDATE_ERR, \%StatisticsData);
      }

      if (&UserStringsW3User::GetStringByID($Error)) {
        if ($Error == $Ow3bank::ID_ERR_SESSION_EXPIRED) {
          my $UserID      = $Ow3bank::oSession->GetUserID();
          my $UserTimeOut = 0;

          if ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_Bank ||
              $Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_Admin) {
            $UserTimeOut = $Ow3bank::HBankEnv{'SID_INACTIVITY_TIMEOUT_B'};
          } else {
            $UserTimeOut = $Ow3bank::HBankEnv{'SID_INACTIVITY_TIMEOUT_U'};
          }

          $UserTimeOut =~ /^(\d+):(\d\d):(\d\d)$/;
          $UserTimeOut = int(($1*3600+$2*60+$3)/60);

          if ($UserID) {
            $UserTimeOut = int(&GetUserTimeOut($UserID)/60);
          }

          $DTemplateRef->{'WELLCOME_MSG'} = &ToolsW3User::GenerateErrMsg(&UserStringsW3User::GetStringByID($Error, [$UserTimeOut]), 'ERR');
        } else {
          if ($WelcomeMsg) {
            $DTemplateRef->{'WELLCOME_MSG'} = &ToolsW3User::GenerateErrMsg($WelcomeMsg, 'ERR');
          } else {
            $DTemplateRef->{'WELLCOME_MSG'} = &ToolsW3User::GenerateErrMsg(&UserStringsW3User::GetStringByID($Error), 'ERR');
          }
        }
      }
      if ($Error == $Ow3bank::ID_ERR_SESSION_EXPIRED ||
          $Error == $Ow3bank::ID_ERR_TOO_MANY_INV_LA_BY_UN ||
          $Error == $Ow3bank::ID_ERR_TOO_MANY_LA_BY_UN ||
          $Error == $Ow3bank::ID_ERR_ACCOUNT_IS_LOCKED) {
        $DTemplateRef->{'INCLUDE_MESSAGE_WITH_ENTER_BUTTON'} = 1;
        $DTemplateRef->{'ERROR_MSG'}                         = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_LOGIN_AGAIN);
        $DTemplateRef->{'HIDE_USER'}                         = 1;
      } elsif (($Error == $Ow3bank::ID_ERR_INVALID_PASSWORD) ||
               ($Error == $Ow3bank::ID_ERR_INVALID_USERNAME) ||
               ($Error == $Ow3bank::ID_ERR_INVALID_CAPTCHA) ||
               ($Error == $Ow3bank::ID_STR_INVALID_OTP)) {
        if (
            !$DataRef->{'OPID'} ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_ACCESS ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_EXT_USER_REG ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_EXT_USER_ACTIVATE_MAIL ||
            ($DataRef->{'OPID'} == $Ow3bank::OPID_CHANGE_LANGUAGE &&
             !$Ow3bank::oSession->GetUserID)
          ) {
          $TemplateName = &ToolsW3User::GetTemplateName($Ow3bank::HT_LOGIN_MAIN, $InterfaceLang);
          $DTemplateRef->{'PRE_LOAD'} = 1;
          if ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User &&
              $Ow3bank::oSession &&
              $Ow3bank::oSession->GetUserLIRetries >= &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome_LoginAttempts', 'MAX_INVALID_LA_WO_CAPTCHA', 0)) {
            $DTemplateRef->{'SHOW_CAPTCHA'} = 1;
          }
          delete $DTemplateRef->{'INCLUDE_SYSTEM_ERROR'};
        }
        $DTemplateRef->{'INCLUDE_LOGIN_PAGE'} = 1;
        $DTemplateRef->{'HIDE_USER'}          = 1;
        if ($Ow3bank::HBankEnv{'OTP'} eq 'T') {
          $DTemplateRef->{'SHOW_OTP'} = 1;
        }

        $DTemplateRef->{'SCRIPT_NAME'} = $Ow3bank::HBankEnv{'FULL_CGI_NAME'};
        $DTemplateRef->{'SID'}         = $Ow3bank::HBankEnv{'SID'};
        if ($Ow3bank::gOPID eq 'CONNECT_AND_LOGIN') {
          $DTemplateRef->{'OPID_LOGIN'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CONNECT_AND_LOGIN);
        } else {
          $DTemplateRef->{'OPID_LOGIN'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_LOGIN_VERIFICATION);
        }
        $DTemplateRef->{'OPID_SIGN_OUT'}    = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SIGN_OUT);
        $DTemplateRef->{'OPID_CAPTCHA_GET'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CAPTCHA_GET);

      } elsif ($Error == $Ow3bank::ID_ERR_USER_HAS_OPEN_SESSION) {
        if ($Ow3bank::HBankEnv{'DEMO_VERSION'} eq 'F') {
          $DTemplateRef->{'INCLUDE_CLOSE_OLD_SESSION'} = 1;
          $DTemplateRef->{'HIDE_USER'}                 = 1;
          $DTemplateRef->{'SCRIPT_NAME'}               = $Ow3bank::HBankEnv{'FULL_CGI_NAME'};
          $DTemplateRef->{'SID'}                       = $Ow3bank::HBankEnv{'SID'};
          $DTemplateRef->{'OPID_CLOSE_SESSION'}        = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CLOSE_SESSION);
          if (!$DTemplateRef->{'ERROR_MSG'}) {
            $DTemplateRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg(&UserStringsW3User::GetStringByID($Ow3bank::ID_STR_ENTER_PUK), 'NOTE');
          }
          if ($Ow3bank::oSession->GetUserLIRetries() >= &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome', 'MAX_INVALID_PASS_ATTEMPTS', 0)) {
            &ToolsW3User::WriteError($Ow3bank::ID_ERR_SEQURITY_VIOLATION);
          }
          delete $DTemplateRef->{'INCLUDE_SYSTEM_ERROR'};
        } else {
          &ProcessOPID_CLOSE_SESSION($DTemplateRef, $DataRef);
        }
      } elsif ($Error == $Ow3bank::ID_STR_LOGIN_NO_CERTIFICATE) {
        $DTemplateRef->{'INCLUDE_LOGIN_TAN_BY_SMS'}       = 1;
        $DTemplateRef->{'HIDE_USER'}                      = 1;
        $DTemplateRef->{'SCRIPT_NAME'}                    = $Ow3bank::HBankEnv{'FULL_CGI_NAME'};
        $DTemplateRef->{'SID'}                            = $Ow3bank::HBankEnv{'SID'};
        $DTemplateRef->{'ERROR_MSG'}                      = &ToolsW3User::GenerateErrMsg(&UserStringsW3User::GetStringByID($Ow3bank::ID_STR_LOGIN_NO_CERTIFICATE), 'ERR');
        $DTemplateRef->{'WELLCOME_MSG'}                   = '';
        $DTemplateRef->{'OPID_LOGIN_VERIFICATION_BY_TAN'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_LOGIN_VERIFICATION_BY_TAN);
        $DTemplateRef->{'OPID_SHOW_TAN_BY_SMS_ON_LOGIN'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_TAN_BY_SMS_ON_LOGIN);
      } elsif (($Error == $Ow3bank::ID_ERR_SEQURITY_VIOLATION) ||
               ($Error == $Ow3bank::ID_ERR_TOO_MANY_INV_LA_BY_PW) ||
               ($Error == $Ow3bank::ID_ERR_EMPTY_DATA)) {

        if ($Error == $Ow3bank::ID_ERR_SEQURITY_VIOLATION) {

# ~bc_if_def USER_WWW
          # ай ш и пенитраторите аз...
          if ($Ow3bank::HBankEnv{'DEMO_VERSION'} eq "T") {
            $DTemplateRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg(&UserStringsW3User::GetStringByID($Ow3bank::ID_ERR_BLOCKED_IP), 'NOTE');

            #$Ow3bank::oSession->LockIP();
          } else {
            $DTemplateRef->{'ERROR_MSG'} = &ToolsW3User::GenerateErrMsg(&UserStringsW3User::GetStringByID($Ow3bank::ID_STR_ACCESS_BLOCKED), 'NOTE');
            &LockUserAccount($Ow3bank::oSession->GetUserID(), $Ow3bank::TBL_USERS, $Ow3bank::TRUE, $Ow3bank::LockSysOper, &UserStringsW3User::GetStringByID($Ow3bank::ID_ERR_SEQURITY_VIOLATION));
          }
=pod
 ~bc_else
          &LockUserAccount($Ow3bank::oSession->GetUserID(), 'BANK_USERS', '1', $Ow3bank::LockSysOper);
          $DTemplateRef->{'ERROR_MSG'} = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_BLOCKED_ACCESS);
=cut
# ~bc_end_if USER_WWW

        } else {
          $DTemplateRef->{'ERROR_MSG'} = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_BLOCKED_ACCESS);
        }
      } elsif ($Error == $Ow3bank::ID_ERR_SYSTEM_BUSY) {
        $DTemplateRef->{'ERROR_MSG'} = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_SYSTEM_BUSY);
      } elsif ($Error == $Ow3bank::ID_STR_INCORRECT_SERT_SERIAL_NUM) {
        $DTemplateRef->{'ERROR_MSG'} = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_SERT_SERIAL_INFO);
        $Ow3bank::oSession->CloseSession();
      } elsif ($Error == $Ow3bank::ERR_INI_FILE_NOT_FOUND) {
        $DTemplateRef->{'ERROR_MSG'} = &UserStringsW3User::GetStringByID($Ow3bank::ERR_INI_FILE_NOT_FOUND);
      } elsif ($Error == $Ow3bank::ID_STR_EFAKTURA_SIGN_ERR) {
        $DTemplateRef->{'WELLCOME_MSG'} = &ToolsW3User::GenerateErrMsg(&UserStringsW3User::GetStringByID($Ow3bank::ID_STR_EFAKTURA_RQ02_INVALID_SIGN, 0, '', \%Ow3bank::EFAKTURA_ERR), 'ERR');
        $DTemplateRef->{'ERROR_MSG'} = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_CONNECT_BANK);
      } else {
        if ($ErrorMsg) {
          $DTemplateRef->{'ERROR_MSG'} = $ErrorMsg;
        } else {
          $DTemplateRef->{'ERROR_MSG'} = &UserStringsW3User::GetStringByID($Ow3bank::ID_STR_CONNECT_BANK);
        }
      }
    }

    if (
        !$Error &&
        $DataRef->{'OPID'} &&
        ($DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_PAY_INFO_DOC ||
         $DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_PRODUCT_DOGOVOR ||
         $DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_CONTRACT)
      ) {
      my($FileData, $ContentType, $FileName) = &ProcessOPID_REQ_GET_BLOB($DataRef->{'FILE_NAME'});

      if ($FileData) {
        if ($ContentType) {
          print "Content-Type: $ContentType;charset=windows-1251\r\n\n";
        } else {
          print "Content-Type: application/octet-stream;charset=windows-1251;\r\nContent-Disposition: attachment; filename=\"$FileName\"\r\n\n";
        }

        if (
            $DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_PRODUCT_DOGOVOR ||
            ($DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_CONTRACT &&
             $DataRef->{'CONTRACT_TYPE'})
          ) {
          $FileData = &GenerateRTF($DataRef, $FileData);
        }
        print $FileData;
        &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $FileData);
      } else {
        &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "OPID=".$Ow3bank::gOPID." - ".&UserStringsW3User::GetStringByID($Ow3bank::ID_STR_FILE_NOT_FOUND, [$DataRef->{'FILE_NAME'}]));
      }
    } elsif (!$Error && $DataRef->{'OPID'} && ($DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_SERTIF_INSTRUCTIONS)) {
      my($FileError) = &REQ_GET_FILE($Ow3bank::HBankEnv{'SERTIF_INSTR_FILE'});

      if ($FileError) {
        my $charset = 'UTF-8';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
        print "Content-Type: text/html;charset=$charset\r\n\n";
        $DTemplateRef->{'WELLCOME_MSG'} = &ToolsW3User::GenerateErrMsg($FileError, 'ERR');

        $DTemplateRef->{'ERROR_MSG'} = "Moля, свържете се с администратора на системата<br> на телефон: ".$Ow3bank::HBankEnv{'CURR_BANK_PHONE_ADMIN'}." или<br> e-mail: ".$Ow3bank::HBankEnv{'CURR_BANK_EMAIL_ADMIN'}.".";
        &ToolsW3User::GenerateLoadingPageMsg($DataRef);
      }
    } elsif (!$Error && $DataRef->{'OPID'} && ($DataRef->{'OPID'} == $Ow3bank::OPID_DOWNLOAD_ZIP_FILE)) {
      my($FileData) = &GetZipFile($DataRef->{'BLOB_ID'});

      if ($FileData) {
        print "Content-Type: application/attachment\r\n\n";
        print $FileData;
        &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $FileData);
      } else {
        my $charset = 'UTF-8';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
        print "Content-Type: text/html;charset=$charset\r\n\n";
        $DTemplateRef->{'WELLCOME_MSG'} = &ToolsW3User::GenerateErrMsg('Zip файлът не може да бъде изтеглен.', 'ERR');
        $DTemplateRef->{'ERROR_MSG'} = "Moля, свържете се с администратора на системата<br> на телефон: ".$Ow3bank::HBankEnv{'CURR_BANK_PHONE_ADMIN'}." или<br> e-mail: ".$Ow3bank::HBankEnv{'CURR_BANK_EMAIL_ADMIN'}.".";
        &ToolsW3User::GenerateLoadingPageMsg($DataRef);
      }
    } elsif (!$Error && $DataRef->{'OPID'} && ($DataRef->{'OPID'} == $Ow3bank::OPID_ORACAM_GET_BLOB)) {

      #my($CmdResult, $ErrMsg) = &ExecuteORACAMCmd('CmdReqGetBLOB', [$DataRef->{'BLOB_ID'}], $Ow3bank::oSession->GetORACAM_SID());
      #if ($ErrMsg) {
      #  &ToolsW3User::WriteError($Ow3bank::ID_ERR_SYSTEM_ERROR, $ErrMsg);
      #} else {
      #  print "Content-Type: application/x-pkcs12 pfx;charset=windows-1251\r\n\n";
      #  print $CmdResult->[0][0];
      #  &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $CmdResult->[0][0]);
      #}
    } elsif (!$Error && $DataRef->{'OPID'} && ($DataRef->{'OPID'} == $Ow3bank::OPID_HEALTH_CHECK)) {
      1;
    }
    elsif (
           !$Error &&
           $DataRef->{'OPID'} &&
           ($DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_CRED_CARD_IZVL_DETAILS_PDF ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_PRINT_BLOB_PDF)
      ) {
      my(@PDFData) = ();
      if ($DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_CRED_CARD_IZVL_DETAILS_PDF) {
        @PDFData = @{&GetCreditCardIzvlDetailsPDF($DataRef->{'ID_IZVL'})};
      } elsif ($DataRef->{'OPID'} == $Ow3bank::OPID_PRINT_BLOB_PDF) {
        @PDFData = @{&GetBlobToPDFData($DataRef)};
      }

      if ($PDFData[1]) {
        print "Content-Type: application/pdf;\r\nContent-Disposition: attachment;\r\n\n".$PDFData[1];
      } else {
        my $charset = 'UTF-8';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
        print "Content-Type: text/html;charset=$charset\r\n\n";
        $Ow3bank::gEmptyContentType = 0;
        delete $DataRef->{'PDF_PREPARE'};
        delete $DataRef->{'ACTION'};
        &ToolsW3User::GenerateLoadingPageMsg($DTemplateRef);
        &ToolsW3User::WriteError($Ow3bank::ID_ERR_SYSTEM_ERROR);
      }
    } elsif ($DataRef->{'AJAX_CALL'}) {

      if ($Error) {
        &AJAX_CALL_ERROR($Error, 'Error during execution.');
      } else {
        if ($DataRef->{'AJAX_CALL_JSON'}) {
          &AJAX_CALL_GET_RESPONSE_JSON($DTemplAjax);
        } else {

          # грешка от валидация
          if ($DataRef->{'ERROR_FOUND'}) {
            $DTemplAjax->{'topSectionMsgID'} = $DataRef->{'ERROR_MSG'};
          } else {

            # ако има бутони за навигация и те са ajax
            if ($DataRef->{'OPID'} && ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[5] && $DTemplateRef->{'AJAX_CALL_NAVIGATION'}) {
              my %DataBrowserParams;

              $DataBrowserParams{'SCRIPT_NAME'}           = $DTemplateRef->{'SCRIPT_NAME'};
              $DataBrowserParams{'SID'}                   = $DTemplateRef->{'SID'};
              $DataBrowserParams{'DATA_BROWSER_ACCTIONS'} = $DTemplateRef->{'DATA_BROWSER_ACCTIONS'};
              $DataBrowserParams{'DATA_BROWSER_PARAMS'}   = $DTemplateRef->{'DATA_BROWSER_PARAMS'};
              $DataBrowserParams{'AJAX_CALL_NAVIGATION'}  = $DTemplateRef->{'AJAX_CALL_NAVIGATION'};
              $DataBrowserParams{'FIRST_POSITION'}        = $DTemplateRef->{'FIRST_POSITION'};
              $DataBrowserParams{'LAST_POSITION'}         = $DTemplateRef->{'LAST_POSITION'};
              $DataBrowserParams{'TOTAL'}                 = $DTemplateRef->{'TOTAL'};
              $DataBrowserParams{'BEGIN'}                 = $DTemplateRef->{'BEGIN'};
              $DataBrowserParams{'FIRST'}                 = $DTemplateRef->{'FIRST'};
              $DataBrowserParams{'PREV'}                  = $DTemplateRef->{'PREV'};
              $DataBrowserParams{'NEXT'}                  = $DTemplateRef->{'NEXT'};
              $DataBrowserParams{'LAST'}                  = $DTemplateRef->{'LAST'};
              $DataBrowserParams{'PREVIOUS'}              = $DTemplateRef->{'PREVIOUS'};

              $DTemplAjax->{'navigationPageID'} = &AJAX_CALL_GET_RESPONSE_HTML('AddDataBrowser', \%DataBrowserParams);
            }

          }
          my($AjaxCallComplete) = '';
          if ($DTemplAjax->{'AjaxCallComplete'}) {
            $AjaxCallComplete = $DTemplAjax->{'AjaxCallComplete'};
            delete $DTemplAjax->{'AjaxCallComplete'};
          }
          if ($DTemplateRef->{'PRINT_ACTIONS_PARAMS'}) {
            $DTemplAjax->{'PRINT_ACTIONS_PARAMS'} = $DTemplateRef->{'PRINT_ACTIONS_PARAMS'};
          }
          &AJAX_CALL_RESPONSE($DTemplAjax, $AjaxCallComplete);
        }
      }
    } else {
      $ENV{'HTML_TEMPLATE_ROOT'} = $Ow3bank::HBankEnv{'TEMPLATES_DIR'};

      my $includes = '';
      foreach (keys %$DTemplateRef) {
        if ($DTemplateRef->{$_}) {
          if ($_ ne 'AJAX_CALL_RESPONSE') {
            $DTemplateRef->{$_} =~ s/"/&quot;/g;
            if ($_ =~ m/^INCLUDE_.+$/i) {
              $includes .= "<TMPL_IF name=$_><\/TMPL_IF>\n";
            }
          }
        }
      }

      my $contentFileName = '';

      # тук са страници, които не са обвързани с конкретен OPID, но могат да се "запалят" автоматично при кой да е OPID според конкретни условия
      if ($DTemplateRef->{'INCLUDE_MESSAGE_WITH_ENTER_BUTTON'}) {
        $contentFileName = "ErrTooManyInvalidLA_$Ow3bank::gLanguage.html";
      } elsif ($DTemplateRef->{'INCLUDE_CLOSE_OLD_SESSION'}) {
        $contentFileName = "ErrSessUsed_$Ow3bank::gLanguage.html";
      } elsif ($DTemplateRef->{'INCLUDE_LOGIN_TAN_BY_SMS'}) {
        $contentFileName = "oLoginTanBySms_$Ow3bank::gLanguage.html";
      }

      my $templateData = &ToolsW3User::ReadFile($ENV{'HTML_TEMPLATE_ROOT'}.$TemplateName);
      $templateData .= "\n$includes";

      if ($templateData) {
        if (!$contentFileName) {
          if ($DataRef->{'OPID'}) {
            $contentFileName = ${$Ow3bank::OPID{$DataRef->{'OPID'}}}[6];
          }
        }
        if (!$contentFileName) {
          $contentFileName = 'oMsgPage.html';
        }
        $templateData =~ s/<SCON_INCLUDE name=CONTENT_FILE_NAME>/<TMPL_INCLUDE name=\"$contentFileName\">/;
      }
      if ($DTemplateRef->{'INCLUDE_LEFT_MENU'}) {
        my $leftMenuFileName = "LeftMenu".$Ow3bank::HBankEnv{'CGI_MODE'}."_".$Ow3bank::gLanguage.".html";
        $templateData =~ s/<SCON_INCLUDE name=LEFT_MENU_FILE_NAME>/<TMPL_INCLUDE name=\"$leftMenuFileName\">/;
      } else {
        $templateData =~ s/<SCON_INCLUDE name=LEFT_MENU_FILE_NAME>//;
      }

      &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "OPID   : $DataRef->{'OPID'}, TemplateName - $TemplateName, contentFileName - $contentFileName, includes - $includes");
      if ($DTemplateRef->{'ERROR_MSG'}) {
        &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "DTemplateRef - gUI_MSG_TYPE: $Ow3bank::gUI_MSG_TYPE, ERROR_MSG: $DTemplateRef->{'ERROR_MSG'}");
      }
      if ($DataRef->{'ERROR_MSG'}) {
        &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "DataRef - gUI_MSG_TYPE: $Ow3bank::gUI_MSG_TYPE, ERROR_MSG: $DataRef->{'ERROR_MSG'}");
      }
      &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "OPID   :     End of data preparation");

      &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "HTML   :     Start of looking for html");

      #&BrowseHash($DTemplateRef, 1);
      $oTemplate = HTML::Template->new(scalarref    => \$templateData,
                                       max_includes => 5);

      &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "HTML   :     End of looking for html");

      $DTemplateRef->{'USER_MODE'}  = 0;
      $DTemplateRef->{'BANK_MODE'}  = 0;
      $DTemplateRef->{'ADMIN_MODE'} = 0;
      if ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User) {
        $DTemplateRef->{'USER_MODE'} = 1;
      } elsif ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_Bank) {
        $DTemplateRef->{'BANK_MODE'} = 1;
      } elsif ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_Admin) {
        $DTemplateRef->{'ADMIN_MODE'} = 1;
      }

      $DTemplateRef->{'UI_MSG_TYPE_SUCCESS'} = 0;
      $DTemplateRef->{'UI_MSG_TYPE_NOTE'}    = 0;
      $DTemplateRef->{'UI_MSG_TYPE_ERROR'}   = 0;
      if ($Ow3bank::gUI_MSG_TYPE == $Ow3bank::UI_MSG_TYPE_SUCCESS) {
        $DTemplateRef->{'UI_MSG_TYPE_SUCCESS'} = 1;
      } elsif ($Ow3bank::gUI_MSG_TYPE == $Ow3bank::UI_MSG_TYPE_NOTE) {
        $DTemplateRef->{'UI_MSG_TYPE_NOTE'} = 1;
      } elsif ($Ow3bank::gUI_MSG_TYPE == $Ow3bank::UI_MSG_TYPE_ERROR) {
        $DTemplateRef->{'UI_MSG_TYPE_ERROR'} = 1;
      }

      if ($DTemplateRef->{'PRINT_PAGE'} ||
          $DTemplateRef->{'EXEL_PAGE'} ||
          $DTemplateRef->{'PDF_PAGE'} ||
          $DTemplateRef->{'XML_PAGE'} ||
          $DTemplateRef->{'BLOB_PDF_PAGE'}) {
        $DTemplateRef->{'SHOW_EXPORT_PANEL'} = 1;
      }

      &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "HTML   :     Start of html preparation");

      #&BrowseHash($DTemplateRef, 1);
      $oTemplate->param($DTemplateRef);

      &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "HTML   :     End of html preparation");
      if (exists $DataRef->{'XML_PREPARE'}) {
        if ($DataRef->{'OPID'} &&
            $DataRef->{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFOXML) {
          my($HtmlData) = &PrepareHTML_To_XML_AccParagoniDBank($oTemplate->output, $Ow3bank::oSession->GetUserID());
          print $HtmlData;
          &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $HtmlData);
        } else {
          print '';
        }
      } elsif (exists $DataRef->{'EXEL_PREPARE'}) {
        my $ExcelHeader = '';
        if ($DataRef->{'EXPORT_NO'}) {
          $ExcelHeader = $DTemplateRef->{'ERROR_MSG'.$DataRef->{'EXPORT_NO'}};
        } else {
          $ExcelHeader = $DTemplateRef->{'ERROR_MSG'};
        }
        $ExcelHeader =~ s/<br>/\n/gi;

        my $XLSData = &FormatXLSFile($oTemplate->output, $Ow3bank::oSession->GetUserID(), $ExcelHeader);
        if (!$XLSData) {
          $XLSData = "\n";  # поради някаква причина ако резултата е празен IE се шашка :-|
        }
        print $XLSData;
        &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $XLSData);
      } elsif (exists $DataRef->{'PRINT_PREPARE'}) {
        my($HtmlData) = '';
        if ($DataRef->{'OPID'} == $Ow3bank::OPID_NEW_USER_JUR_VIEW ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_NEW_USER_FIZ_VIEW) {
          $HtmlData = &ToolsW3User::cp1251_to_UTF8(&Prepare4PrintDynamicControls($oTemplate->output));
          print &ToolsW3User::ReplaceSID($DTemplateRef->{'SID'}, $HtmlData, $Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User && &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome', 'DisableOPIDAccess', 'F') eq $Ow3bank::TRUE);
          &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $HtmlData);

          #} elsif ($DataRef->{'OPID'} == $Ow3bank::OPID_NEW_TAN) {
          #  $HtmlData = &ToolsW3User::cp1251_to_cp866(&Cnvt2UC(&Prepare4Print($oTemplate->output)));  #&Prepare4Print($oTemplate->output);#
          #  print &ToolsW3User::ReplaceSID($DTemplateRef->{'SID'}, $HtmlData, $Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User && &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome', 'DisableOPIDAccess', 'F') eq $Ow3bank::TRUE);
          #  &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $HtmlData);
        } else {
          $HtmlData = &ToolsW3User::cp1251_to_UTF8(&Prepare4Print($oTemplate->output));
          print &ToolsW3User::ReplaceSID($DTemplateRef->{'SID'}, $HtmlData, $Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User && &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome', 'DisableOPIDAccess', 'F') eq $Ow3bank::TRUE);
          &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $HtmlData);
        }
      } elsif (exists $DataRef->{'PDF_PREPARE'}) {
        my($PDFData)  = '';
        my($printURL) = '';
        my($cgiName)  = $Ow3bank::HBankEnv{'PROTOCOL_HOST_ORA_WEB'};

        $ENV{'PATH'} = &FixParam($ENV{'PATH'});

        $cgiName =~ s/^https/http/;

        #$DataRef->{'EXT_HTML'}      = 'INCLUDE_ACCOUNT_PARAGONI_INFO_PDF';                                       #'oAccountParagoniInfoPDF_'.$Ow3bank::gLanguage.'.html';
        #$DataRef->{'EXT_HTML_FILE'} = "oAccountParagoniInfoPDF_$Ow3bank::gLanguage.html";
        $DataRef->{'PRINT_PREPARE'} = 1;
        $DataRef->{'EXPORT_TO_PDF'} = 1;
        $printURL                   = "$cgiName?_R_A_=".$Ow3bank::HBankEnv{'IP'}."&".&GetActionParams($DataRef);
        $printURL                   = &FixParam($printURL);

        my $orientation = 'Portrait';

        if ($DataRef->{'OPID'} == $Ow3bank::OPID_ACCOUNT_PARAGONI_INFO_PDF) {
          $orientation = 'Landscape';
        }
        PDF::WebKit->configure(
          sub {
            $_->wkhtmltopdf($Ow3bank::HBankEnv{'PDF_TOOL_PATH'});

            #$_->default_options->{'--zoom'} = '-1.4';
            $_->default_options->{'--orientation'} = $orientation;
          }
        );
        if ($DataRef->{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_VAL) {
          PDF::WebKit->configure(
            sub {
              $_->default_options->{'--margin-top'}    = '0.5in';
              $_->default_options->{'--margin-bottom'} = '0.2in';
            }
          );
        }

        my($WebKit) = PDF::WebKit->new($printURL);

        eval {$PDFData = $WebKit->to_pdf;};

        if ($@) {
          my $charset = 'UTF-8';  # това е само заради ултраедит-а. като види Content-Type...UTF-?? и нещо отваря кофти цги-то
          print "Content-Type: text/html;charset=$charset\r\n\n";
          $Ow3bank::gEmptyContentType = 0;
          delete $DataRef->{'PDF_PREPARE'};
          delete $DataRef->{'ACTION'};
          &ToolsW3User::GenerateLoadingPageMsg($DTemplateRef);
          &ToolsW3User::WriteError($Ow3bank::ID_ERR_SYSTEM_ERROR, $@);
        } else {
          &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $PDFData);
          print "Content-Type: application/pdf;\r\nContent-Disposition: attachment;\r\n\n".$PDFData;
        }
      } elsif ($DataRef->{'OPID'} && $DataRef->{'OPID'} == $Ow3bank::OPID_EFAKT_STATUSCHECK) {
        &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, $DataRef->{'EFAKTURA_RESP'});
        print &ToolsW3User::cp1251_to_UTF8($DataRef->{'EFAKTURA_RESP'});
        $Ow3bank::oSession->CloseSession();
      } else {
        my($HtmlData) = &ToolsW3User::cp1251_to_UTF8(&ToolsW3User::RemoveEmptyLine($oTemplate->output));
        print &ToolsW3User::ReplaceSID($DTemplateRef->{'SID'}, $HtmlData, $Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User && &ToolsW3User::GetIniValue($Ow3bank::UNIQCODE_ALL, 'WWWHome', 'DisableOPIDAccess', 'F') eq $Ow3bank::TRUE);
        &ToolsW3User::WriteLog($Ow3bank::LOG_HTML, $HtmlData);
      }
    }
  }

  my($SecStampEnd, $MicroStampEnd) = gettimeofday();
  $MicroStampEnd = int($MicroStampEnd/1000);
  my($SecBusy) = ($SecStampEnd.'.'.$MicroStampEnd)-($Ow3bank::gSecStampBegin.'.'.$Ow3bank::gMicroStampBegin);

  if ($Error != $Ow3bank::ID_ERR_CANT_CONNECT_TO_DB) {
    my($SecHTMLPrep) = ($SecStampEnd.'.'.$MicroStampEnd)-($SecHTMLStampBegin.'.'.$MicroHTMLStampBegin);
    $StatisticsData{'HTML_END'} = "to_date(\'".  #
      &ToolsW3User::GetCurrentDateTimeString('dd.mm.yyyy hh:mn:ss')."\',\'dd-mm-yyyy hh24:mi:ss\')";
    $StatisticsData{'HTML_DUR'}  = $SecHTMLPrep;
    $StatisticsData{'TOTAL_DUR'} = $SecBusy;
    &GenerateStatistics($Ow3bank::STAT_UPDATE_HTML, \%StatisticsData);
  }

  if ($Error != $Ow3bank::ID_ERR_CANT_CONNECT_TO_DB) {
    &DBW3User::dbms_set_module("OPID_FINISHED=".$Ow3bank::gOPID);
  }
  &ToolsW3User::WriteLog($Ow3bank::LOG_OPID, "OPID_END :   ".$Ow3bank::gOPID." $SecBusy sec\n");
  &ToolsW3User::HaltScript();
}

#////////////////////////////////////////////////////////////////////////////////////////////////////
#   Prepare_oFrameParameters - Подготвя параметрите за %DTemplate, предназначени за "oFrameTemplate.html"
#
#   Usage:
#     &Prepare_oFrameParameters(\%DTemplate, $CellWidth, $IncludeSection);
#
#   Parameters :
#     \%DTemplate     - Референция към хеш, в който ще се попълват данните
#
#
#   Return :
#     0 - винаги.
#
#////////////////////////////////////////////////////////////////////////////////////////////////////
sub Prepare_oFrameParameters {
  my($DTemplateRef) = $_[0];
  my($DataRef)      = $_[1];
  my(@RightsArr)    = ();

  if ($Ow3bank::oSession && $Ow3bank::oSession->GetUserID) {
    if ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_User) {
      if ($DataRef->{'OPID'} && $DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_TAN_BY_SMS_ON_LOGIN) {
        $DTemplateRef->{'OPID_CHANGE_LANGUAGE'} = 0;
      } elsif ($Ow3bank::oSession->GetEFaktID()) {
        $DTemplateRef->{'OPID_CHANGE_LANGUAGE'} = 0;
      } else {
        $DTemplateRef->{'OPID_CHANGE_LANGUAGE'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CHANGE_LANGUAGE);
      }
      if (
          $DataRef->{'OPID'} && (
                                    ($Ow3bank::oSession->GetEFaktID() || $DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_TAN_BY_SMS_ON_LOGIN)
                                 ||
                                 (
                                  ($Ow3bank::oSession->GetUserDEPOCUST() eq 'T') &&
                                  ((&HasUserOnlyOnlineDepositWithZeroSaldo($Ow3bank::oSession->GetUserID())) &&
                                   (!&HasUserRightsForAccounts($Ow3bank::oSession->GetUserID(), $Ow3bank::ExpoType_OnlineDeposit)))
                                 ) ||
                                 (($DataRef->{'OPID'} == $Ow3bank::OPID_CONNECT_AND_LOGIN) &&
                                  $Ow3bank::oSession->GetUserMUST_USE_ST()) ||
                                 ($DataRef->{'OPID'} == $Ow3bank::OPID_ZUI_SHOW ||
                                  $DataRef->{'OPID'} == $Ow3bank::OPID_ZUI_TAN_BY_SMS_AUTH ||
                                  $DataRef->{'OPID'} == $Ow3bank::OPID_ZUI_TAN_BY_SMS_REJECT)
          ) ||
          ($Ow3bank::oSession->GetPSD2ConsentID() ||
           $Ow3bank::oSession->GetPSD2PaybufoID() ||
           $Ow3bank::oSession->GetPSD2PrevoutID() ||
           $Ow3bank::oSession->GetPSD2AuthenticationID())
        ) {
        $DTemplateRef->{'INCLUDE_LEFT_MENU'} = 0;
      } else {
        $DTemplateRef->{'INCLUDE_LEFT_MENU'} = 1;
      }

      my($CustType) = &GetCustType($Ow3bank::oSession->GetUserCustID());

      &AddBackBtnPage($DataRef, $DTemplateRef);

      if (($Ow3bank::oSession->GetRightOTP()) ||
          ($Ow3bank::oSession->GetUserAuthType() eq $Ow3bank::AuthTypeOTP)) {
        $DTemplateRef->{'SHOW_CHANGE_PIN'} = 1;
      }

      if (!$Ow3bank::oSession->GetRightOTP()) {
        $DTemplateRef->{'SHOW_CHANGE_PASS'} = 1;
      }

      if ($Ow3bank::oSession->GetUserField('USER_REG_PROCESSING')) {
        $DTemplateRef->{'USER_REG_PROCESSING'} = 1;
      }

      $DTemplateRef->{'OPID_PASS_CHNG'}         = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_PASS_CHNG);
      $DTemplateRef->{'OPID_SHOW_INSTRUCTIONS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_INSTRUCTIONS);
      $DTemplateRef->{'OPID_LOCK_ACCOUNT'}      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_LOCK_ACCOUNT);
      if ($Ow3bank::oSession->GetEFaktID() && $DataRef->{'OPID'}) {
        if ($DataRef->{'OPID'} == $Ow3bank::OPID_NEW_311 ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_SAVE_311 ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_O_311 ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_VIEW_IBAN_311 ||
            $DataRef->{'OPID'} == $Ow3bank::OPID_SAVE_DECLARATION_2) {
          $DTemplateRef->{'OPID_EFAKT_RESPONSE'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_EFAKT_RESPONSE);
        }
      } else {
        $DTemplateRef->{'OPID_SIGN_OUT'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SIGN_OUT);
      }
      $DTemplateRef->{'OPID_AJAX_VALIDATION'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_AJAX_VALIDATION);

      #???
      $DTemplateRef->{'OPID_SHOW_PAY_INFO_DOC'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_PAY_INFO_DOC);

      if (!$DTemplateRef->{'USER_REG_PROCESSING'}) {
        $DTemplateRef->{'OPID_ACCOUNTS'}       = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ACCOUNTS);
        $DTemplateRef->{'OPID_CLIENTS'}        = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CLIENTS);
        $DTemplateRef->{'OPID_SND_TRANS_FORМ'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SND_TRANS_FORM);
        $DTemplateRef->{'OPID_RCV_TRANS_FORМ'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_RCV_TRANS_FORM);
        $DTemplateRef->{'OPID_IN_TRANS_FORМ'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_IN_TRANS_FORM);
        $DTemplateRef->{'OPID_IZVL_FORM'}      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_IZVL_FORM);

        #$DTemplateRef->{'OPID_NEW_311'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_311);

        $DTemplateRef->{'OPID_NEW_313'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_313);

        #$DTemplateRef->{'OPID_NEW_INCASO'}           = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_INCASO);
        #$DTemplateRef->{'OPID_NEW_DECLARATION'}      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_DECLARATION);
        $DTemplateRef->{'OPID_NEW_FREE_MSG'}         = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_FREE_MSG);
        $DTemplateRef->{'OPID_EXCEL_SETTINGS_FORM'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_EXCEL_SETTINGS_FORM);
        $DTemplateRef->{'OPID_SHOW_CONTRAGENT_LIST'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_CONTRAGENT_LIST);
        $DTemplateRef->{'OPID_ADD_CONTRAGENT'}       = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ADD_CONTRAGENT);
        $DTemplateRef->{'OPID_DEL_CONTRAGENT'}       = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_DEL_CONTRAGENT);

        $DTemplateRef->{'OPID_SHOW_VAL_FIX_FORM'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_VAL_FIX_FORM);
        $DTemplateRef->{'OPID_SHOW_BANK_MSG_FORM'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_BANK_MSG_FORM);

        #свободни съобщения
        $DTemplateRef->{'OPID_NEW_FM6'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_FM6);
        $DTemplateRef->{'OPID_NEW_FM2'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_FM2);
        $DTemplateRef->{'OPID_NEW_DEC2'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_DEC2);

        #$DTemplateRef->{'OPID_NEW_FM14'}      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_FM14);
        $DTemplateRef->{'OPID_NEW_FM11'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_FM11);

        # $DTemplateRef->{'OPID_NEW_STAT_FORM'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_STAT_FORM);

        #$DTemplateRef->{'OPID_NEW_PRODUCT'}       = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_PRODUCT);
        $DTemplateRef->{'OPID_WORK_IN_PROGRESS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_WORK_IN_PROGRESS);

        $DTemplateRef->{'OPID_SHOW_IMPORT_FILE'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_IMPORT_FILE);

        $DTemplateRef->{'BLOB_TYPE_313'} = $Ow3bank::BlobType_BudgetTEU;

        $DTemplateRef->{'OPID_BLOB_VALUES'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_BLOB_VALUES);

        #$DTemplateRef->{'OPID_SHOW_CARDS'}                = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_CARDS);
        $DTemplateRef->{'OPID_NEW_BUYSELLVAL'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_BUYSELLVAL);

        #$DTemplateRef->{'OPID_CARDS_IZVL'}                = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS_IZVL);
        $DTemplateRef->{'OPID_SHOW_BANK_UNREAD_MSG_LIST'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_BANK_UNREAD_MSG_LIST);

        #$DTemplateRef->{'OPID_CREDITS'}                   = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CREDITS);
        #$DTemplateRef->{'OPID_DEPOSITS'}                  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_DEPOSITS);

        #Бисера 7
        #$DTemplateRef->{'OPID_NEW_VAL_B7'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_VAL_B7);

        #$DTemplateRef->{'OPID_FC_TRANSFER_SHOW_PANEL'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_FC_TRANSFER_SHOW_PANEL);
        $DTemplateRef->{'OPID_NEW_VAL'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_VAL);
        if (&CheckUserCanOpenDepositByType($Ow3bank::CITIZEN_DEFINE, $Ow3bank::oSession->GetUserID(), $Ow3bank::OPID_FOR_BROWSE) &&
            (!$Ow3bank::gLanguage || $Ow3bank::gLanguage eq $Ow3bank::LangBG)) {
          $DTemplateRef->{'OPID_SHOW_CALL_CENTER_REQ'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_CALL_CENTER_REQ);
        }
        $DTemplateRef->{'OPID_CALCULATOR'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CALCULATOR);
        if (&CheckSebraReportAccess($Ow3bank::oSession->GetUserID(), $Ow3bank::OPID_FOR_BROWSE)) {
          $DTemplateRef->{'OPID_NEW_REQ_SEBRA_REPORT'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_REQ_SEBRA_REPORT);
        }

        $DTemplateRef->{'OPID_LOGIN_CHNG'}       = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_LOGIN_CHNG);
        $DTemplateRef->{'OPID_USER_RIGHTS_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USER_RIGHTS_SHOW);

        $DTemplateRef->{'OPID_SHOW_PAY_INFO'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_PAY_INFO);
        $DTemplateRef->{'OPID_NEW_FREEOPERS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_FREEOPERS);

        #$DTemplateRef->{'OPID_SHOW_REGULAR_PAYMENTS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_REGULAR_PAYMENTS);
        #if (&HasUserRightForCards($Ow3bank::OPID_FOR_PAY)) {
        #  $DTemplateRef->{'OPID_CARDS_BLOCK'}     = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS_BLOCK);
        #  $DTemplateRef->{'OPID_CARDS_LIMITS'}    = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS_LIMITS);
        #  $DTemplateRef->{'OPID_CARDS_CHANGEPIN'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS_CHANGEPIN);
        #}
        #$DTemplateRef->{'OPID_CARDS_AUTHORIZATIONS_FORM'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS_AUTHORIZATIONS_FORM);
        #$DTemplateRef->{'OPID_CARDS_TRANSACTIONS_FORM'}   = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS_TRANSACTIONS_FORM);

        #$DTemplateRef->{'OPID_CARDS_PAYMENT'}             = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS_PAYMENT);

        #$DTemplateRef->{'OPID_SHOW_CREDITS_PERSON'}       = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_CREDITS_PERSON);
        #$DTemplateRef->{'OPID_SHOW_CREDITS_FIRM'}         = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_CREDITS_FIRM);
        $DTemplateRef->{'OPID_SHOW_NOTIFICATIONS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_NOTIFICATIONS);

        #$DTemplateRef->{'OPID_DATAMAX_CHOOSE_CLIENT'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_DATAMAX_CHOOSE_CLIENT);

        $DTemplateRef->{'OPID_NEW_ACCOUNT'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_ACCOUNT);

        #if (!(exists $DataRef->{'DONOT_SHOW_EXCLUDE'}) || !($DataRef->{'DONOT_SHOW_EXCLUDE'})) {
        #  $DTemplateRef->{'OPID_NEW_EXCLUDE_ACCOUNT'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_EXCLUDE_ACCOUNT);
        #}
        if ($Ow3bank::oSession->GetUserCustID()) {
          if ($CustType eq $Ow3bank::CITIZEN_DEFINE) {
            $DTemplateRef->{'OPID_CHOOSE_CLIENT'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CHOOSE_CLIENT);
          }
        } else {
          if (&HasUserRightsForAccType($Ow3bank::CITIZEN_DEFINE)) {
            $DTemplateRef->{'OPID_CHOOSE_CLIENT'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CHOOSE_CLIENT);
          }

          #$DTemplateRef->{'OPID_SHOW_DEPOSITS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_DEPOSITS);
        }

        #$DTemplateRef->{'OPID_CARDS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CARDS);

        if ($CustType ne $Ow3bank::CITIZEN_DEFINE) {
          $DTemplateRef->{'OPID_SEBRA_REPORT_SEARCH'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SEBRA_REPORT_SEARCH);
        } elsif ($CustType ne $Ow3bank::FIRM_DEFINE) {

          #$DTemplateRef->{'OPID_SHOW_DEPOSITS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_DEPOSITS);
        }

        #    $DTemplateRef->{'OPID_USERDOCS_NEW'}         = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USERDOCS_NEW);

        if (&GetUserCustCount($Ow3bank::oSession->GetUserID()) > 1) {
          $DTemplateRef->{'OPID_CUST_CHANGE_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CUST_CHANGE_SHOW);
          $DTemplateRef->{'OPID_CUST_CHANGE_SAVE'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_CUST_CHANGE_SAVE);
        }
        if ($Ow3bank::oSession->GetUserID() && $Ow3bank::oSession->GetUserUseKEP()) {
          $DTemplateRef->{'OPID_REG_KEP_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_REG_KEP_SHOW);
          $DTemplateRef->{'OPID_REG_KEP_SAVE'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_REG_KEP_SAVE);
        }
        if (&CheckAccChameleonRights($Ow3bank::OPID_FOR_PAY)) {
          $DTemplateRef->{'OPID_NEW_CURR_TRANSL_CHAMELEON'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_CURR_TRANSL_CHAMELEON);
        }
        $DTemplateRef->{'OPID_DEC_NAR28_NEW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_DEC_NAR28_NEW);

        #    $DTemplateRef->{'OPID_IMP_SALARY_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_IMP_SALARY_SHOW);
        $DTemplateRef->{'OPID_START_ACCOUNTS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_START_ACCOUNTS);

        #if (&HasClient312($Ow3bank::OPID_FOR_PAY)) {
        #  $DTemplateRef->{'OPID_NEW_312'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_312);
        #}
        # $DTemplateRef->{'OPID_TOPUP_PREPAID_CARD_NEW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_TOPUP_PREPAID_CARD_NEW);
      }

    } elsif ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_Admin) {
      $DTemplateRef->{'OPID_PASS_CHNG'}                     = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_PASS_CHNG);
      $DTemplateRef->{'OPID_SIGN_OUT'}                      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SIGN_OUT);
      $DTemplateRef->{'OPID_SHOW_BANK_USER_LIST'}           = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_BANK_USER_LIST);
      $DTemplateRef->{'OPID_STATISTICS_PSW_FIND'}           = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_STATISTICS_PSW_FIND);
      $DTemplateRef->{'OPID_SHOW_FILES_LIST'}               = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_FILES_LIST);
      $DTemplateRef->{'OPID_USER_REQ_SC_GEN_PACKS_SHOW'}    = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USER_REQ_SC_GEN_PACKS_SHOW);
      $DTemplateRef->{'OPID_USER_REQ_SC_MANAGE_PACKS_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USER_REQ_SC_MANAGE_PACKS_SHOW);
      $DTemplateRef->{'OPID_USER_REQ_SC_PACKS_REPORT'}      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USER_REQ_SC_PACKS_REPORT);
      $DTemplateRef->{'OPID_USER_REQ_SC_MANAGE_CARDS_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USER_REQ_SC_MANAGE_CARDS_SHOW);
      $DTemplateRef->{'OPID_LOCK_ACCOUNT'}                  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_LOCK_ACCOUNT);
      $DTemplateRef->{'OPID_START_ACCOUNTS_MSG_SHOW'}       = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_START_ACCOUNTS_MSG_SHOW);

      $DTemplateRef->{'INCLUDE_LEFT_MENU'} = 1;

      if (($Ow3bank::oSession->IsAdmin()) && (not $Ow3bank::oSession->IsSuperVisor())) {
        $DTemplateRef->{'OPID_SHOW_FIND_USER_FORM'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_FIND_USER_FORM);
        $DTemplateRef->{'OPID_SHOW_WWW_USER_LIST'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_WWW_USER_LIST);
        $DTemplateRef->{'OPID_SHOW_BLOCKED_IPS'}    = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_BLOCKED_IPS);

        #$DTemplateRef->{'OPID_REG_KEP_SEARCH'}      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_REG_KEP_SEARCH);
        if (&HasPermissionForAction('ORACAM_CERT')) {
          $DTemplateRef->{'OPID_ORACAM_GEN_CERT_SHOW'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ORACAM_GEN_CERT_SHOW);
          $DTemplateRef->{'OPID_ORACAM_FIND_CERT_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ORACAM_FIND_CERT_SHOW);
          $DTemplateRef->{'OPID_ORACAM_RECONNECT'}      = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ORACAM_RECONNECT);
        }

        #$DTemplateRef->{'OPID_BUDGET_OFFICER_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_BUDGET_OFFICER_SHOW);
        $DTemplateRef->{'OPID_RP_HEADER_FIND_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_RP_HEADER_FIND_SHOW);
      } elsif ($Ow3bank::oSession->IsSuperVisor()) {
        $DTemplateRef->{'OPID_ADD_ACCESS_LIST'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ADD_ACCESS_LIST);
      }

      #$DTemplateRef->{'OPID_EFAKTURA_CHANGE_PASS_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_EFAKTURA_CHANGE_PASS_SHOW);
      $DTemplateRef->{'OPID_USERS_WITH_FEW_TANS_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USERS_WITH_FEW_TANS_SHOW);

      $DTemplateRef->{'OPID_HEALTH_CHECK_REPORTS_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_HEALTH_CHECK_REPORTS_SHOW);
    } elsif ($Ow3bank::HBankEnv{'CGI_MODE'} eq $Ow3bank::CGI_MODE_Bank) {
      if ($DataRef->{'OPID'} && $DataRef->{'OPID'} == $Ow3bank::OPID_SHOW_USER_LIST) {
        $DTemplateRef->{'INCLUDE_LEFT_MENU'} = 0;
      } else {
        $DTemplateRef->{'INCLUDE_LEFT_MENU'} = 1;
      }

      $DTemplateRef->{'OPID_PASS_CHNG'}          = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_PASS_CHNG);
      $DTemplateRef->{'OPID_SIGN_OUT'}           = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SIGN_OUT);
      $DTemplateRef->{'OPID_SHOW_REPORT_FORM'}   = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_REPORT_FORM);
      $DTemplateRef->{'OPID_SHOW_MSG_LIST_FORM'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_MSG_LIST_FORM);
      $DTemplateRef->{'OPID_SHOW_USER_LIST'}     = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_USER_LIST);

      #$DTemplateRef->{'OPID_ADD_UPS_TO_USER_JUR'}        = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ADD_UPS_TO_USER_JUR);
      #$DTemplateRef->{'OPID_USER_REQ_NA_NEW'}            = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USER_REQ_NA_NEW);
      #$DTemplateRef->{'OPID_USER_REQ_NA_LIST_FORM_SHOW'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_USER_REQ_NA_LIST_FORM_SHOW);
      #$DTemplateRef->{'OPID_ACC_REQ_FIZ_SHOW'}           = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ACC_REQ_FIZ_SHOW);
      #$DTemplateRef->{'OPID_ACC_REQ_JUR_SHOW'}           = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_ACC_REQ_JUR_SHOW);
      $DTemplateRef->{'OPID_LOCK_ACCOUNT'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_LOCK_ACCOUNT);
      $DTemplateRef->{'OPID_SHOW_MSG_FORM'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_MSG_FORM);

      if (&HasPermissionForAction('BLOCKED_IP')) {
        $DTemplateRef->{'OPID_SHOW_BLOCKED_IPS'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_BLOCKED_IPS_BM);
      }
      if (&HasPermissionForAction('WWW_USERS_LIST')) {
        $DTemplateRef->{'OPID_SHOW_FIND_USER_FORM'} = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_SHOW_FIND_USER_FORM_BM);
      }
      if (&HasPermissionForAction('NEW_USER_REQ')) {
        $DTemplateRef->{'SHOW_MENU_USER_REQ'} = 1;
        $DTemplateRef->{'OPID_NEW_USER_FIZ'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_USER_FIZ);
        $DTemplateRef->{'OPID_NEW_USER_JUR'}  = &ToolsW3User::EnCryptOPID($Ow3bank::OPID_NEW_USER_JUR);
      }
    }
  }

  return (0);
}  # sub Prepare_oFrameParameters

sub CheckBrowserVer {
  if ($ENV{'HTTP_USER_AGENT'} =~ m/MSIE\s(\d).(\d)/) {
    my($PrVer) = $1;
    my($SbVer) = $2;

    if ($PrVer >= 5) {
      return 1;
    } else {
      return 0;
    }
  } else {
    return 0;
  }
}  #sub CheckBrowserVer

sub IsUserExpired {
  my($UserID)       = $_[0];
  my($DBResult)     = '';
  my(@ReturnedData) = ();
  my($FldPrefix)    = '';
  my($TableName)    = 'BANK_USERS';

# ~bc_if_def USER_WWW
  $FldPrefix = 'FLD';
  $TableName = $Ow3bank::TBL_USERS;
# ~bc_end_if USER_WWW

  $DBResult = &DBW3User::ExecuteSQLStatement(
    "select ".                                                                      #
      $FldPrefix."USERID ".                                                         #
      "from $TableName ".                                                           #
      " where ".$FldPrefix."USERID = $UserID and ".                                 #
      " sysdate >= ".$FldPrefix."EXPIRE_DATE + $Ow3bank::HBankEnv{'EXPIRE_TIME'} ",
    0, 0, 0, 1
                                      );

  @ReturnedData = &DBW3User::FetchRow(\$DBResult);

  return $ReturnedData[0];
}  #sub IsUserExpired

#////////////////////////////////////////////////////////////////////////////////////////////////////
#   ComparesDate  - Сравнява дати.
#
#   Usage:
#     &ComparesDate($Date1,$Date2);
#
#   Parameters :
#     $Date1 - първа дата.
#     $Date2 - втора дата.
#   Return :
#     0 - Първата Дата не е по - голяма от втората.
#     1 - Първата Дата е по - голяма
#////////////////////////////////////////////////////////////////////////////////////////////////////

sub ComparesDate {
  my($Date1) = $_[0];
  my($Date2) = $_[1];
  my($Year1, $Year2) = '';
  my($Days1, $Days2) = '';

  $Date1 =~ m/(\d{4})(.)(\d{2})(.)(\d{2})/g;
  $Year1 = $1;
  $Days1 = Day_of_Year($1, $3, $5);
  $Date2 =~ m/(\d{4})(.)(\d{2})(.)(\d{2})/g;
  $Year2 = $1;
  $Days2 = Day_of_Year($1, $3, $5);

  if ($Year1 < $Year2) {return (0);}

  elsif ($Year1 == $Year2)  # това е невероятно. браво на нас
  {
    if ($Days1 <= $Days2) {
      return (0);
    } else {
      return (1);
    }
  } else {
    return (1);
  }

}

sub FormatXLSFile {
  my($HtmlFormatedString) = $_[0];
  my($UserID)             = $_[1];
  my($ExcelHeader)        = $_[2];

  my(@HTMLRows)          = ();
  my($XLSFormatedString) = '';
  my($bFound)            = 0;
  my($NumberOfCol)       = 0;
  my($DataCnt)           = 0;
  my($DataType)          = 0;
  @HTMLRows = split /\n/, $HtmlFormatedString;
  my(%ExcelSettings) = ();
  &GetUserExelSettings($UserID, \%ExcelSettings);

  if ($ExcelHeader) {
    $XLSFormatedString .= $ExcelHeader."\n\n";
  }

  for (@HTMLRows) {
    my($Line) = &Cnvt2UC($_);

    if ($bFound == 1)  # Трябва да търсим заглавиятя на колонките
    {
      if ($Line =~ m/ID=\"non_print/i) {
        next;
      }
      if ($Line =~ m/>(.+)<\/TH>/gi) {
        my($ColName) = $1;
        if ($ColName =~ m/(.+)<span/i) {
          $ColName = $1;
        }
        $ColName =~ s/<BR>/ /gi;
        $ColName =~ s/<BR\/>/ /gi;
        $ColName =~ s/<BR \/>/ /gi;
        $ColName =~ s/<B>//gi;
        $ColName =~ s/<\/B>//gi;
        $ColName =~ s/NBSP/ /gi;
        $ColName =~ s/;//g;
        $ColName =~ s/&//g;
        $ColName =~ s/ +/ /g;
        $ColName = &ToolsW3User::AllTrim($ColName);

        if (length($ColName) > 0 && $ColName !~ m/<IMG SRC=/i) {
          $XLSFormatedString .= "\"$ColName\""."\t";
          $NumberOfCol = $NumberOfCol+1;
        }
      }
    } elsif ($bFound == 2)  # Данните
    {
      if ($Line =~ m/<IMG/i) {
        next;
      }
      if ($Line =~ m/ID=\"STRING\"/gi) {
        $DataType = 1;
      } elsif ($Line =~ m/ID=\"NUMBER\"/gi) {
        $DataType = 2;

      } elsif ($Line =~ m/ID=\"DATE\"/gi) {
        $DataType = 3;
      } else {
        $DataType = 1;
      }

      if (!($Line =~ m/NON_PRINT/gi) &&
          $Line =~ m/>(.*)<\/TD>/gi) {
        my($Data) = $1;
        $Data = &ToolsW3User::AllTrim($Data);
        $Data =~ s/<BR>/ /gi;
        $Data =~ s/<BR\/>/ /gi;
        $Data =~ s/<BR \/>/ /gi;
        $Data =~ s/<B>//gi;
        $Data =~ s/<\/B>//gi;
        $Data =~ s/NBSP/ /gi;
        $Data =~ s/;//g;
        $Data =~ s/&//g;
        $Data =~ s/ +/ /g;
        while ($Data =~ m/<.*?>(.*)<\/.*?>/)  #ако в <td>-то има други тагове се разкарват
        {
          my($Data2) = $1;
          $Data =~ s/<.*?>(.*)<\/.*?>/$Data2/;
        }
        $Data =~ s/<.*?\/>//g;
        if ($DataType == 2) {
          $Data =~ s/\./$ExcelSettings{'DECIMAL_SEPARATOR'}/g;

          $Data =~ s/\s+//g;
          $XLSFormatedString .= "$Data"."\t";
        } elsif ($DataType == 3) {
          $Data = &TO_DATE_FUNC($Data, $ExcelSettings{'DATE_FORMAT'});
          $XLSFormatedString .= "$Data"."\t";
        } else {
          $XLSFormatedString .= "\"".chr(160)."$Data\""."\t";
        }

        $DataCnt = $DataCnt+1;

        if ($DataCnt == $NumberOfCol) {
          $DataCnt = 0;
          $XLSFormatedString =~ s/\t$/\n/g;
        }
      }
    }

    #&ToolsW3User::WriteLog($Ow3bank::LOG_ERROR, "bFound ".$bFound);

    if ($bFound != -1) {
      if ($Line =~ m/<thead/gi) {
        $bFound = 1;  #Започваме да четем заглавията
      } elsif ($Line =~ m/<tbody/gi) {
        if ($bFound == 1) {
          $XLSFormatedString =~ s/\t$/\n/g;
        }

        $bFound = 2;  #Започваме да четем данните
      } elsif ($Line =~ m/\/TABLE/g) {
        if ($bFound == 2) {
          $bFound = 0;

          # спираме, защото това е следваща таблица, а това засега не го можем
          last;
        }
      }
    }

  }

  return ($XLSFormatedString);
}  #sub FormatXLSFile

sub Prepare4Print {
  my($HtmlFormatedString) = $_[0];
  my(@HTMLRows)           = ();
  my($FormatedString)     = '';

  $HtmlFormatedString =~ s/^\s+\n//mg;
  $HtmlFormatedString =~ s/^\n//mg;

  @HTMLRows = split /\n/, $HtmlFormatedString;

  for (@HTMLRows) {
    my($Line) = $_;
    if (($Line =~ m/type=\"radio\"/i) ||
        ($Line =~ m/type=radio/i) ||
        ($Line =~ m/type=\"checkbox\"/i) ||
        ($Line =~ m/type=checkbox/i)) {
      $FormatedString .= $Line."\n";
      next;
    } elsif (($Line =~ m/href=/i) ||
             ($Line =~ m/type=submit/i) ||
             ($Line =~ m/type=\"submit\"/i) ||
             ($Line =~ m/type=image/i) ||
             ($Line =~ m/type=\"image\"/i)) {
      next;
    } else {
      $Line =~ s/disabled/readonly/ig;
      $FormatedString .= $Line."\n";
    }
  }

  return ($FormatedString);
}  #sub Prepare4Print

sub Prepare4PrintDynamicControls {
  my($HtmlFormatedString) = $_[0];
  my(@HTMLRows)           = ();
  my($FormatedString)     = '';

  $HtmlFormatedString =~ s/^\s+\n//mg;
  $HtmlFormatedString =~ s/^\n//mg;

  @HTMLRows = split /\n/, $HtmlFormatedString;

  for (@HTMLRows) {
    my($Line) = $_;
    if (($Line =~ m/type=\"radio\"/i) ||
        ($Line =~ m/type=\radio/i) ||
        ($Line =~ m/type=\"checkbox\"/i) ||
        ($Line =~ m/type=\checkbox/i)) {
      $FormatedString .= $Line."\n";
      next;
    }

=pod
       elsif( ($Line =~ m/href=/i)            ||
              ($Line =~ m/type=\submit/i   )  ||
              ($Line =~ m/type=\"submit\"/i)  ||
              ($Line =~ m/type=\image/i   )   ||
              ($Line =~ m/type=\"image\"/i)   ||
              ($Line =~ m/<img/i   )
            )
         {
           next;
         }
=cut

    else {
      $Line =~ s/disabled/readonly/ig;
      $FormatedString .= $Line."\n";
    }
  }
  return ($FormatedString);
}  #sub Prepare4PrintDynamicControls

sub HasUnReadedBankMsg {
  my($UserID)       = $_[0];
  my($DBResult)     = '';
  my(@ReturnedData) = ();
  $DBResult = &DBW3User::ExecuteSQLStatement(
    "select ".                                                                      #
      "count(*) ".                                                                  #
      "from ".                                                                      #
      "BANKMSG ".                                                                   #
      "where ".                                                                     #
      "(USERID in (0, $UserID) ) and ".                                             #
      "(UNIQCODE = 0 or ".                                                          #
      " UNIQCODE in ( ".                                                            #
      "select ".                                                                    #
      "distinct UNIQCODE ".                                                         #
      " from ".                                                                     #
      " UCRELATION ".                                                               #
      "where USERID = $UserID ) )  and ".                                           #
      " to_date(SNDDATE || ' ' || SNDTIME, 'yyyy.mm.dd hh24:mi:ss') >= ( select ".  #
      "  nvl( FLDCREATED, to_date( '01.01.1001', 'dd.mm.yyyy' )) ".                 #
      " from  ".                                                                    #
      "$Ow3bank::TBL_USERS ".                                                       #
      " where ".                                                                    #
      " FLDUSERID = $UserID ) and ".                                                #
      "MSGID not in ( ".                                                            #
      "select ".                                                                    #
      "MSGID ".                                                                     #
      "from   ".                                                                    #
      "READMSG ".                                                                   #
      "where ".                                                                     #
      "USERID = $UserID ) ", 0, 0, 0, 1
  );

  @ReturnedData = &DBW3User::FetchRow(\$DBResult);

  if (@ReturnedData) {return $ReturnedData[0];}
  return 0;
}  #sub HasUnReadedBankMsg

sub REQ_GET_FILE {
  my($filename) = $_[0];

  my($nOffset)     = 0;
  my($nBufferSize) = 10240;
  my($aBuffer)     = '';
  my($nBytesRead)  = 0;
  my($sResult)     = '';

  unless (open(HANDLE, $filename)) {
    &ToolsW3User::WriteLog($Ow3bank::LOG_ERROR, "File not found: $filename");
    return ($Ow3bank::ID_STR_CANT_OPEN_FILE);
  }

  binmode(HANDLE, ':raw');

  while (1) {
    seek(HANDLE, $nOffset, 0);
    $nBytesRead = read(HANDLE, $aBuffer, $nBufferSize);
    print $aBuffer;
    if ($nBytesRead < $nBufferSize) {exit;}
    $nOffset += $nBufferSize;
  }

  close(HANDLE);

  return (0);
}  # sub REQ_GET_FILE

sub GetAccDataFromDB_BM {
  my($DataRef)      = $_[0];
  my($SendDataRef)  = $_[1];
  my($TableName)    = '';
  my($Fields)       = '';
  my($DBResult)     = '';
  my(@ReturnedData) = ();
  my($Ukey)         = $DataRef->{'TRANS_KEY'};
  my($BankID)       = 0;
  my($NoAcc)        = 0;
  my($CurrentOPID)  = 0;
  my($WhereField)   = 'U_KEY';

  $CurrentOPID = $DataRef->{'OPID'};

  $TableName = $DataRef->{'WHAT'} if ((exists $DataRef->{'WHAT'}) && ($DataRef->{'WHAT'} =~ m/^\w+$/));

  if (($CurrentOPID == $Ow3bank::OPID_VIEW_413) || ($TableName eq 'INCASOOUT')) {
    $TableName = 'INCASOOUT';

    #$Fields    = 'bankid';
    $Fields = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_DECLARATION) || ($TableName eq 'WITDRAWPAY')) {
    $TableName = 'WITDRAWPAY';

    #       $Fields    = 'bankid';
    $Fields = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_FREE_MSG) || ($TableName eq 'FREEMSG')) {
    $TableName = 'FREEMSG';

    #       $Fields    = 'bankid';
    $Fields = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_FM6) || ($TableName eq 'FMSG6')) {
    $TableName = 'FMSG6';
    $Fields    = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_FM2) || ($TableName eq 'FMSG2')) {
    $TableName = 'FMSG2';
    $Fields    = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_FM14) || ($TableName eq 'FMSG14')) {
    $TableName = 'FMSG14';
    $Fields    = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_DEC2) || ($TableName eq 'DEC2')) {
    $TableName = 'DEC2';
    $Fields    = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_FM11) || ($TableName eq 'FMSG11')) {
    $TableName = 'FMSG11';
    $Fields    = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_STAT_FORM) || ($TableName eq 'FM_STAT_FORM')) {
    $TableName = 'FM_STAT_FORM';
    $Fields    = 'uniqcode';
  } elsif (($CurrentOPID == $Ow3bank::OPID_CARDS_BLOCK_VIEW || $CurrentOPID == $Ow3bank::OPID_CARDS_UNBLOCK_VIEW || $CurrentOPID == $Ow3bank::OPID_CARDS_LIMITS_VIEW) ||
           ($TableName eq 'CARDS_OPERATIONS')) {
    $TableName = 'CARDS_OPERATIONS';
    $Fields    = 'CUST_BANKID';
  } elsif (($CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_BIZNES_VIEW || $CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_ALTERNATIVA_VIEW || $CurrentOPID == $Ow3bank::OPID_NEW_CREDIT_RAZVITIE_VIEW) ||
           ($TableName eq 'CREDITS_REQ')) {
    $TableName = 'CREDITS_REQ';
    $Fields    = 'FIN_CENTYR';
  }

  elsif (($CurrentOPID == $Ow3bank::OPID_NEW_VISA_VIEW) || ($TableName eq 'CARDS_REQ')) {
    $TableName = 'CARDS_REQ';
    $Fields    = 'FC';
  }

  elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_OVERDRAFT) || ($TableName eq 'CRED_C_OVERDRAFT')) {
    $TableName = 'CRED_C_OVERDRAFT';
    $Fields    = 'FIN_CENTYR';
  }

  elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_VISA_CREDIT_CARD) || ($TableName eq 'CARDS_CRED_REQ')) {
    $TableName = 'CARDS_CRED_REQ';
    $Fields    = 'FIN_CENTYR';
  }

  elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_CONSUMER_LOAN) || ($TableName eq 'CRED_C_POTREBITELSKI')) {
    $TableName = 'CRED_C_POTREBITELSKI';
    $Fields    = 'FIN_CENTYR';
  }

  elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_MORTGAGE_LOAN) || ($TableName eq 'CRED_C_IPOTECHEN')) {
    $TableName = 'CRED_C_IPOTECHEN';
    $Fields    = 'FIN_CENTYR';
  }

  elsif (($CurrentOPID == $Ow3bank::OPID_NEW_USER_FIZ_VIEW) || ($TableName eq 'NEW_USERS_REQ')) {
    $TableName = 'NEW_USERS_REQ';
    $Fields    = 'FIN_CENTYR';
  }

  elsif (($CurrentOPID == $Ow3bank::OPID_NEW_USER_JUR_VIEW) || ($TableName eq 'NEW_USERS_REQ')) {
    $TableName = 'NEW_USERS_REQ';
    $Fields    = 'FIN_CENTYR';
  } elsif (($CurrentOPID == $Ow3bank::OPID_VIEW_REQ_ACCOUNTS) || ($TableName eq 'REQRIGHT_HEAD')) {
    $TableName  = 'FM_STAT_FORM';
    $Fields     = 'BANK_ID';
    $WhereField = 'ID_REQ';
  } elsif (($CurrentOPID == $Ow3bank::OPID_USERDOCS_VIEW) || ($TableName eq 'USER_DOCS')) {
    $TableName = 'USER_DOCS';
    $Fields    = 'UNIQCODE';
  } elsif (($CurrentOPID == $Ow3bank::OPID_DEC_NAR28_VIEW) || ($TableName eq 'DEC_NAR28')) {
    $TableName = 'DEC_NAR28';
    $Fields    = 'UNIQCODE';
  }

  $DBResult = &DBW3User::ExecuteSQLStatement(
    "select ".        #
      "$Fields ".     #
      "from ".        #
      "$TableName ".  #
      "where ".       #
      "u_key = $Ukey ", 0, 0, 0, 1
  );

  @ReturnedData = &DBW3User::FetchRow(\$DBResult);

  $SendDataRef->{'BANK_ID'} = $ReturnedData[0] ? $ReturnedData[0] : $Ow3bank::VAR_NOT_DEFINED;

  return 0;
}  #sub GetAccDataFromDB_BM
