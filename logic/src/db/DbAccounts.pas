unit DbAccounts;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  mormot.core.base,
  mormot.orm.base,
  mormot.orm.core;

type
  TOrmGameAccount = class(TOrm)
  private
    fAuthUserId: Int64;
    fLogin: RawUtf8;
    fCreatedAt: TCreateTime;
    fLastLogin: TModTime;
  published
    property AuthUserId: Int64 read fAuthUserId write fAuthUserId;
    property Login: RawUtf8 read fLogin write fLogin stored AS_UNIQUE;
    property CreatedAt: TCreateTime read fCreatedAt write fCreatedAt;
    property LastLogin: TModTime read fLastLogin write fLastLogin;
  end;

  TOrmPlayerStats = class(TOrm)
  private
    fAccount: TOrmGameAccount;
    fRaidsPlayed: Int64;
    fRaidsExtracted: Int64;
    fTotalKills: Int64;
    fTotalDeaths: Int64;
    fTotalXp: Int64;
    fTotalDamageDealt: Double;
  published
    property Account: TOrmGameAccount read fAccount write fAccount;
    property RaidsPlayed: Int64 read fRaidsPlayed write fRaidsPlayed;
    property RaidsExtracted: Int64 read fRaidsExtracted write fRaidsExtracted;
    property TotalKills: Int64 read fTotalKills write fTotalKills;
    property TotalDeaths: Int64 read fTotalDeaths write fTotalDeaths;
    property TotalXp: Int64 read fTotalXp write fTotalXp;
    property TotalDamageDealt: Double read fTotalDamageDealt write fTotalDamageDealt;
  end;

implementation

end.
