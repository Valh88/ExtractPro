unit DbCore;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  mormot.core.base,
  mormot.core.os,
  mormot.orm.core,
  mormot.rest.core,
  mormot.rest.sqlite3,
  mormot.db.raw.sqlite3,
  DbAccounts,
  DbItems,
  DbSession,
  DbConfig;

type
  TGameDatabase = class
  private
    FLock: TOSLock;
    FModel: TOrmModel;
    FServer: TRestServerDB;
    function GetOrm: IRestOrm;
    function GetBackgroundTimer: TRestBackgroundTimer;
    function FindAccountByAuthIdUnsafe(AuthUserId: Int64): TOrmGameAccount;
  public
    constructor Create(const aFileName: TFileName);
    destructor Destroy; override;

    property Orm: IRestOrm read GetOrm;
    property Server: TRestServerDB read FServer;
    property Model: TOrmModel read FModel;
    property BackgroundTimer: TRestBackgroundTimer read GetBackgroundTimer;

    function FindAccountByAuthId(AuthUserId: Int64): TOrmGameAccount;
    function EnsureAccount(AuthUserId: Int64; const Login: RawUtf8): TID;
    function Retrieve(Table: TOrmClass; ID: TID): TOrm;
    function GetConfig(const Key, Default: RawUtf8): RawUtf8;
    procedure SetConfig(const Key, Value: RawUtf8);

    procedure AsyncStartBatch(Table: TOrmClass; SendSeconds: Integer = 5;
      PendingRowThreshold: Integer = 1000);
    procedure AsyncAdd(Value: TOrm; SendData: Boolean = True);
    procedure AsyncUpdate(Value: TOrm);
    procedure AsyncDelete(Table: TOrmClass; ID: TID);
    procedure AsyncStopBatch(Table: TOrmClass);
  end;

implementation

{ TGameDatabase }

constructor TGameDatabase.Create(const aFileName: TFileName);
begin
  inherited Create;
  FLock.Init;
  FModel := TOrmModel.Create([
    TOrmGameAccount,
    TOrmPlayerStats,
    TOrmItemDefinition,
    TOrmPlayerItem,
    TOrmGameSession,
    TOrmSessionPlayer,
    TOrmServerConfig
  ], 'extractpro');
  FServer := TRestServerDB.Create(FModel, aFileName);
  FServer.CreateMissingTables;
  FServer.DB.Synchronous := smOff;
  FServer.DB.LockingMode := lmExclusive;
end;

destructor TGameDatabase.Destroy;
begin
  FLock.Done;
  FServer.Free;
  FModel.Free;
  inherited;
end;

function TGameDatabase.GetOrm: IRestOrm;
begin
  Result := FServer.Orm;
end;

function TGameDatabase.GetBackgroundTimer: TRestBackgroundTimer;
begin
  Result := FServer.EnsureBackgroundTimerExists;
end;

function TGameDatabase.FindAccountByAuthIdUnsafe(AuthUserId: Int64): TOrmGameAccount;
begin
  TOrmGameAccount.AutoFree(Result, FServer.Orm,
    'AuthUserId = ?', [], [AuthUserId]);
end;

function TGameDatabase.FindAccountByAuthId(AuthUserId: Int64): TOrmGameAccount;
begin
  FLock.Lock;
  try
    Result := FindAccountByAuthIdUnsafe(AuthUserId);
  finally
    FLock.Unlock;
  end;
end;

function TGameDatabase.EnsureAccount(AuthUserId: Int64; const Login: RawUtf8): TID;
var
  acc: TOrmGameAccount;
begin
  FLock.Lock;
  try
    acc := FindAccountByAuthIdUnsafe(AuthUserId);
    if acc <> nil then
    begin
      Result := acc.IDValue;
      if acc.Login <> Login then
      begin
        acc.Login := Login;
        FServer.Orm.Update(acc);
      end;
      Exit;
    end;
    acc := TOrmGameAccount.Create;
    try
      acc.AuthUserId := AuthUserId;
      acc.Login := Login;
      Result := FServer.Orm.Add(acc, True);
    finally
      acc.Free;
    end;
  finally
    FLock.Unlock;
  end;
end;

function TGameDatabase.Retrieve(Table: TOrmClass; ID: TID): TOrm;
begin
  FLock.Lock;
  try
    Result := Table.Create;
    try
      if not FServer.Orm.Retrieve(ID, Result) then
        FreeAndNil(Result);
    except
      FreeAndNil(Result);
    end;
  finally
    FLock.Unlock;
  end;
end;

function TGameDatabase.GetConfig(const Key, Default: RawUtf8): RawUtf8;
var
  cfg: TOrmServerConfig;
begin
  FLock.Lock;
  try
    TOrmServerConfig.AutoFree(cfg, FServer.Orm, 'Key = ?', [], [Key]);
    if cfg <> nil then
      Result := cfg.Value
    else
      Result := Default;
  finally
    FLock.Unlock;
  end;
end;

procedure TGameDatabase.SetConfig(const Key, Value: RawUtf8);
var
  cfg: TOrmServerConfig;
begin
  FLock.Lock;
  try
    TOrmServerConfig.AutoFree(cfg, FServer.Orm, 'Key = ?', [], [Key]);
    if cfg <> nil then
    begin
      cfg.Value := Value;
      FServer.Orm.Update(cfg);
    end
    else
    begin
      cfg := TOrmServerConfig.Create;
      try
        cfg.Key := Key;
        cfg.Value := Value;
        FServer.Orm.Add(cfg, True);
      finally
        cfg.Free;
      end;
    end;
  finally
    FLock.Unlock;
  end;
end;

procedure TGameDatabase.AsyncStartBatch(Table: TOrmClass; SendSeconds: Integer;
  PendingRowThreshold: Integer);
begin
  FServer.EnsureBackgroundTimerExists;
  FServer.BackgroundTimer.AsyncBatchStart(Table, SendSeconds,
    PendingRowThreshold, 0, []);
end;

procedure TGameDatabase.AsyncAdd(Value: TOrm; SendData: Boolean);
begin
  if FServer.BackgroundTimer = nil then
    FServer.Orm.Add(Value, SendData)
  else
    FServer.BackgroundTimer.AsyncBatchAdd(Value, SendData, False);
end;

procedure TGameDatabase.AsyncUpdate(Value: TOrm);
begin
  if FServer.BackgroundTimer = nil then
    FServer.Orm.Update(Value)
  else
    FServer.BackgroundTimer.AsyncBatchUpdate(Value);
end;

procedure TGameDatabase.AsyncDelete(Table: TOrmClass; ID: TID);
begin
  if FServer.BackgroundTimer = nil then
    FServer.Orm.Delete(Table, ID)
  else
    FServer.BackgroundTimer.AsyncBatchDelete(Table, ID);
end;

procedure TGameDatabase.AsyncStopBatch(Table: TOrmClass);
begin
  if FServer.BackgroundTimer <> nil then
    FServer.BackgroundTimer.AsyncBatchStop(Table);
end;

end.
