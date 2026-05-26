unit DbSession;

{$mode objfpc}{$H+}

interface

uses
  mormot.core.base,
  mormot.orm.base,
  mormot.orm.core,
  DbAccounts;

type
  TOrmGameSession = class(TOrm)
  private
    fMapSeed: Int64;
    fStartedAt: TCreateTime;
    fEndedAt: TModTime;
    fPlayerCount: Integer;
    fStatus: Int64;
  published
    property MapSeed: Int64 read fMapSeed write fMapSeed;
    property StartedAt: TCreateTime read fStartedAt write fStartedAt;
    property EndedAt: TModTime read fEndedAt write fEndedAt;
    property PlayerCount: Integer read fPlayerCount write fPlayerCount;
    property Status: Int64 read fStatus write fStatus;
  end;

  TOrmSessionPlayer = class(TOrm)
  private
    fSession: TOrmGameSession;
    fAccount: TOrmGameAccount;
    fKills: Int64;
    fDeaths: Int64;
    fDamageDealt: Double;
    fExtracted: Boolean;
  published
    property Session: TOrmGameSession read fSession write fSession;
    property Account: TOrmGameAccount read fAccount write fAccount;
    property Kills: Int64 read fKills write fKills;
    property Deaths: Int64 read fDeaths write fDeaths;
    property DamageDealt: Double read fDamageDealt write fDamageDealt;
    property Extracted: Boolean read fExtracted write fExtracted;
  end;

implementation

end.
