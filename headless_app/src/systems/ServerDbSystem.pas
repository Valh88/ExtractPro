unit ServerDbSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  mormot.core.base,
  DbCore, DbAccounts, DbItems, DbSession, DbConfig,
  WorldSystemBase, GameWorld;

type
  TServerDbSystem = class(TWorldSystemBase)
  private
    FDatabase: TGameDatabase;
    FDBFileName: TFileName;
  public
    constructor Create(AWorldObj: TGameWorld; const aDBFileName: TFileName); reintroduce;
    destructor Destroy; override;

    property Database: TGameDatabase read FDatabase;
    property DBFileName: TFileName read FDBFileName;

    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

{
  ── Асинхронные запросы к БД ─────────────────────────────────────────
  Все Add/Update/Delete в таблицы, зарегистрированные через
  AsyncStartBatch, попадают в потокобезопасную очередь в памяти
  (спинлок TLightLock, ~0.001ms) и НЕ блокируют главный 60 FPS цикл.

  Реальная запись в SQLite3 происходит в фоновом потоке
  (TRestBackgroundTimer) — раз в N секунд или при накоплении
  порога записей.

  ── Чтение (всегда синхронно, блокирует ~0.1-1ms) ─────────────────
    var
      Svr: TGameWorldServer;
      Login: RawUtf8;
    begin
      Svr := WorldObj as TGameWorldServer;
      if Svr.DbSystem = nil then Exit;
      Login := Svr.DbSystem.Database.GetConfig('server.name', '?');
      WriteLn('Server: ', Login);
    end;

  ── Асинхронная запись (не блокирует) ─────────────────────────────
    var
      Stats: TOrmPlayerStats;
    begin
      Stats := TOrmPlayerStats.Create;
      Stats.Account := AccountObj;
      Stats.TotalKills := 5;
      Stats.RaidsPlayed := 1;
      Svr.DbSystem.Database.AsyncAdd(Stats, True);
      // Объект Stats освобождается вызывающим кодом после AsyncAdd
    end;

  ── Асинхронное обновление ────────────────────���───────────────────
    Stats.IDValue := existingId;
    Stats.TotalKills := Stats.TotalKills + 1;
    Svr.DbSystem.Database.AsyncUpdate(Stats);

  ── Асинхронное удаление ──────────────────────────────────────────
    Svr.DbSystem.Database.AsyncDelete(TOrmPlayerItem, itemId);

  ── Важно ─────────────────────────────────────────────────────────
  • AsyncAdd/Update/Delete — только для таблиц в AsyncStartBatch.
  • Для остальных таблиц — синхронный Orm.Add/Orm.Update, блокирует.
  • Объект TOrm* живёт только на время вызова. После AsyncAdd
    можно делать Free (mORMot2 копирует данные в batch-буфер).
  • На останове сервера AsyncStopBatch дожидается флеша очередей.
}

{ TServerDbSystem }

constructor TServerDbSystem.Create(AWorldObj: TGameWorld; const aDBFileName: TFileName);

  procedure SeedDefaults;
  var
    cfg: TOrmServerConfig;
  begin
    if FDatabase.Orm.TableRowCount(TOrmServerConfig) > 0 then
      Exit;

    cfg := TOrmServerConfig.Create;
    try
      cfg.Key := 'server.version';
      cfg.Value := '1.0.0';
      FDatabase.Orm.Add(cfg, True);
    finally
      cfg.Free;
    end;

    cfg := TOrmServerConfig.Create;
    try
      cfg.Key := 'server.name';
      cfg.Value := 'ExtractPro Server';
      FDatabase.Orm.Add(cfg, True);
    finally
      cfg.Free;
    end;
  end;

begin
  inherited Create(AWorldObj);
  FDBFileName := aDBFileName;
  FDatabase := TGameDatabase.Create(aDBFileName);
  SeedDefaults;
  FDatabase.AsyncStartBatch(TOrmPlayerStats, 5, 500);
  FDatabase.AsyncStartBatch(TOrmSessionPlayer, 5, 500);
  FDatabase.AsyncStartBatch(TOrmGameSession, 5, 50);
  FDatabase.AsyncStartBatch(TOrmPlayerItem, 5, 500);
end;

destructor TServerDbSystem.Destroy;
begin
  FDatabase.AsyncStopBatch(TOrmPlayerStats);
  FDatabase.AsyncStopBatch(TOrmSessionPlayer);
  FDatabase.AsyncStopBatch(TOrmGameSession);
  FDatabase.AsyncStopBatch(TOrmPlayerItem);
  FDatabase.Free;
  inherited;
end;

procedure TServerDbSystem.Update(const SecondsPassed: Single);
begin
end;

end.
