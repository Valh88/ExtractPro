unit AuthServer;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, variants,
  mormot.core.base,
  mormot.core.os,
  mormot.core.text,
  mormot.core.unicode,
  mormot.core.variants,
  mormot.crypt.core,
  mormot.db.raw.sqlite3,
  mormot.net.http,
  mormot.net.server,
  AuthTypes;

type
  TAuthServer = class
  private
    FServer: THttpServer;
    FPort: Word;
    FDB: TSqlDataBase;
    FValidator: IAuthValidator;
    function OnRequest(Ctxt: THttpServerRequestAbstract): cardinal;
    function HandleLogin(Ctxt: THttpServerRequestAbstract): cardinal;
    function HandleRegister(Ctxt: THttpServerRequestAbstract): cardinal;
    function HandleValidate(Ctxt: THttpServerRequestAbstract): cardinal;
    procedure InitDB;
    function CreateUser(const Login, Password, Email: string): TAuthResponse;
    function AuthenticateUser(const Login, Password: string): TAuthResponse;
    function ValidateSession(const Token: string): TAuthResult;
    procedure CleanExpiredSessions;
  public
    constructor Create(const APort: Word = AUTH_SERVER_DEFAULT_PORT);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Validator: IAuthValidator read FValidator;
  end;

  TAuthServerValidator = class(TInterfacedObject, IAuthValidator)
  private
    FServer: TAuthServer;
  public
    constructor Create(AServer: TAuthServer);
    function ValidateToken(const Token: string): TAuthResult;
  end;

implementation

{ TAuthServerValidator }

constructor TAuthServerValidator.Create(AServer: TAuthServer);
begin
  inherited Create;
  FServer := AServer;
end;

function TAuthServerValidator.ValidateToken(const Token: string): TAuthResult;
begin
  Result := FServer.ValidateSession(Token);
end;

{ TAuthServer }

constructor TAuthServer.Create(const APort: Word);
begin
  inherited Create;
  FPort := APort;
  FDB := nil;
  FServer := nil;
end;

destructor TAuthServer.Destroy;
begin
  Stop;
  inherited;
end;

procedure TAuthServer.InitDB;
begin
  FDB := TSqlDataBase.Create(FPort.ToString + '.db');
  FDB.Execute('CREATE TABLE IF NOT EXISTS users(' +
    'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    'login TEXT UNIQUE NOT NULL,' +
    'password_hash TEXT NOT NULL,' +
    'email TEXT,' +
    'created_at INTEGER NOT NULL)');
  FDB.Execute('CREATE TABLE IF NOT EXISTS sessions(' +
    'token TEXT PRIMARY KEY,' +
    'user_id INTEGER NOT NULL,' +
    'created_at INTEGER NOT NULL,' +
    'expires_at INTEGER NOT NULL)');
end;

function TAuthServer.CreateUser(const Login, Password, Email: string): TAuthResponse;
var
  Salt, Hash: RawByteString;
  Req: TSqlRequest;
begin
  Result.Success := False;
  Salt := TAesPrng.Main.FillRandom(16);
  Hash := Pbkdf2HmacSha256(RawByteString(Password), Salt, 60000, 32);
  Req.Prepare(FDB.DB,
    'INSERT INTO users(login, password_hash, email, created_at) VALUES(?,?,?,?)');
  try
    Req.Bind(1, RawUtf8(Login));
    Req.Bind(2, BinToHex(Salt) + ':' + BinToHex(Hash));
    if Email <> '' then
      Req.Bind(3, RawUtf8(Email))
    else
      Req.BindNull(3);
    Req.Bind(4, Int64(NowUtc * SecsPerDay));
    if Req.Step <> SQLITE_DONE then
    begin
      Result.ErrorMsg := 'User already exists';
      Exit;
    end;
  except
    on E: ESqlite3Exception do
    begin
      Result.ErrorMsg := 'User already exists';
      Exit;
    end;
  end;
  Result.UserId := FDB.LastInsertRowID;
  Result.Login := Login;
  Result.Success := True;
end;

function TAuthServer.AuthenticateUser(const Login, Password: string): TAuthResponse;
var
  Req, TokenReq: TSqlRequest;
  DbHash, SaltHex, HashHex, TokenHex: RawUtf8;
  UserId: Int64;
  TokenRaw: TBytes;
begin
  Result.Success := False;
  Req.Prepare(FDB.DB, 'SELECT id, password_hash FROM users WHERE login = ?');
  try
    Req.Bind(1, RawUtf8(Login));
    if Req.Step <> SQLITE_ROW then
    begin
      Result.ErrorMsg := 'Invalid login or password';
      Exit;
    end;
    UserId := Req.FieldInt(0);
    DbHash := Req.FieldPUtf8(1);
  finally
    Req.Close;
  end;
  SaltHex := Copy(DbHash, 1, Pos(':', DbHash) - 1);
  HashHex := Copy(DbHash, Pos(':', DbHash) + 1, MaxInt);
  if HashHex <> BinToHex(
    Pbkdf2HmacSha256(RawByteString(Password), HexToBin(SaltHex), 60000, 32)) then
  begin
    Result.ErrorMsg := 'Invalid login or password';
    Exit;
  end;
  SetLength(TokenRaw, AUTH_TOKEN_SIZE);
  TAesPrng.Main.FillRandom(@TokenRaw[0], AUTH_TOKEN_SIZE);
  TokenHex := BinToHex(RawByteString(TokenRaw));
  TokenReq.Prepare(FDB.DB,
    'INSERT INTO sessions(token, user_id, created_at, expires_at) VALUES(?,?,?,?)');
  try
    TokenReq.Bind(1, TokenHex);
    TokenReq.Bind(2, UserId);
    TokenReq.Bind(3, Int64(NowUtc * SecsPerDay));
    TokenReq.Bind(4, Int64((NowUtc + AUTH_SESSION_EXPIRE_HOURS / 24) * SecsPerDay));
    if TokenReq.Step <> SQLITE_DONE then
    begin
      Result.ErrorMsg := 'Failed to create session';
      Exit;
    end;
  finally
    TokenReq.Close;
  end;
  Result.Success := True;
  Result.SessionToken := Utf8ToString(TokenHex);
  Result.UserId := UserId;
  Result.Login := Login;
end;

function TAuthServer.ValidateSession(const Token: string): TAuthResult;
var
  Req: TSqlRequest;
begin
  Result.Valid := False;
  CleanExpiredSessions;
  Req.Prepare(FDB.DB,
    'SELECT u.id, u.login FROM sessions s ' +
    'JOIN users u ON u.id = s.user_id ' +
    'WHERE s.token = ? AND s.expires_at > ?');
  try
    Req.Bind(1, RawUtf8(Token));
    Req.Bind(2, Int64(NowUtc * SecsPerDay));
    if Req.Step <> SQLITE_ROW then
      Exit;
    Result.UserId := Req.FieldInt(0);
    Result.Login := Req.FieldPUtf8(1);
    Result.Valid := True;
  finally
    Req.Close;
  end;
end;

procedure TAuthServer.CleanExpiredSessions;
begin
  FDB.Execute(RawUtf8('DELETE FROM sessions WHERE expires_at <= ' +
    IntToStr(Int64(NowUtc * SecsPerDay))));
end;

function TAuthServer.OnRequest(Ctxt: THttpServerRequestAbstract): cardinal;
var
  Url: RawUtf8;
begin
  Url := Ctxt.Url;
  if Ctxt.Method = 'POST' then
  begin
    if Url = '/api/auth/login' then
      Exit(HandleLogin(Ctxt));
    if Url = '/api/auth/register' then
      Exit(HandleRegister(Ctxt));
    if Url = '/api/auth/validate' then
      Exit(HandleValidate(Ctxt));
  end;
  Ctxt.OutContent := VariantToUtf8(_Obj(['error', 'Not found']));
  Ctxt.OutContentType := 'application/json';
  Result := 404;
end;

function TAuthServer.HandleLogin(Ctxt: THttpServerRequestAbstract): cardinal;
var
  Json: variant;
  Login, Password: string;
  Resp: TAuthResponse;
begin
  Json := _JsonFast(Ctxt.InContent);
  Login := string(VariantToUtf8(Json.UserName));
  Password := string(VariantToUtf8(Json.PassWord));
  WriteLn(StdErr, '[AuthServer] POST /api/auth/login user=', Login);
  if (Login = '') or (Password = '') then
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['error', 'Login and password required']));
    Ctxt.OutContentType := 'application/json';
    WriteLn(StdErr, '[AuthServer] Login FAILED: empty login/password');
    Exit(400);
  end;
  Resp := AuthenticateUser(Login, Password);
  Ctxt.OutContentType := 'application/json';
  if Resp.Success then
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj([
      'success', True, 'token', RawUtf8(Resp.SessionToken),
      'user_id', Resp.UserId, 'login', RawUtf8(Resp.Login)]));
    WriteLn(StdErr, '[AuthServer] Login OK: user_id=', Resp.UserId, ', login=', Resp.Login);
    Result := 200;
  end
  else
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['success', False, 'error', RawUtf8(Resp.ErrorMsg)]));
    WriteLn(StdErr, '[AuthServer] Login FAILED: ', Resp.ErrorMsg);
    Result := 401;
  end;
end;

function TAuthServer.HandleRegister(Ctxt: THttpServerRequestAbstract): cardinal;
var
  Json: variant;
  Login, Password, Email: string;
  Resp: TAuthResponse;
begin
  Json := _JsonFast(Ctxt.InContent);
  Login := string(VariantToUtf8(Json.UserName));
  Password := string(VariantToUtf8(Json.PassWord));
  Email := string(VariantToUtf8(Json.Email));
  WriteLn(StdErr, '[AuthServer] POST /api/auth/register user=', Login);
  if (Login = '') or (Password = '') then
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['error', 'Login and password required']));
    Ctxt.OutContentType := 'application/json';
    WriteLn(StdErr, '[AuthServer] Register FAILED: empty login/password');
    Exit(400);
  end;
  if Length(Password) < 4 then
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['error', 'Password too short (min 4 chars)']));
    Ctxt.OutContentType := 'application/json';
    WriteLn(StdErr, '[AuthServer] Register FAILED: password too short');
    Exit(400);
  end;
  Resp := CreateUser(Login, Password, Email);
  Ctxt.OutContentType := 'application/json';
  if Resp.Success then
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['success', True, 'user_id', Resp.UserId, 'login', RawUtf8(Resp.Login)]));
    WriteLn(StdErr, '[AuthServer] Register OK: user_id=', Resp.UserId, ', login=', Resp.Login);
    Result := 201;
  end
  else
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['success', False, 'error', RawUtf8(Resp.ErrorMsg)]));
    WriteLn(StdErr, '[AuthServer] Register FAILED: ', Resp.ErrorMsg);
    Result := 409;
  end;
end;

function TAuthServer.HandleValidate(Ctxt: THttpServerRequestAbstract): cardinal;
var
  Json: variant;
  Token: string;
  AuthResult: TAuthResult;
begin
  Json := _JsonFast(Ctxt.InContent);
  Token := string(VariantToUtf8(Json.Token));
  WriteLn(StdErr, '[AuthServer] POST /api/auth/validate token=', Copy(Token, 1, 8), '...');
  if Token = '' then
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['valid', False, 'error', 'Token required']));
    Ctxt.OutContentType := 'application/json';
    WriteLn(StdErr, '[AuthServer] Validate FAILED: empty token');
    Exit(400);
  end;
  AuthResult := ValidateSession(Token);
  Ctxt.OutContentType := 'application/json';
  if AuthResult.Valid then
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['valid', True, 'user_id', AuthResult.UserId, 'login', RawUtf8(AuthResult.Login)]));
    WriteLn(StdErr, '[AuthServer] Validate OK: user_id=', AuthResult.UserId);
  end
  else
  begin
    Ctxt.OutContent := VariantToUtf8(_Obj(['valid', False, 'error', 'Invalid or expired token']));
    WriteLn(StdErr, '[AuthServer] Validate FAILED: invalid/expired token');
  end;
  Result := 200;
end;

procedure TAuthServer.Start;
begin
  if FServer <> nil then
    Exit;
  InitDB;
  FServer := THttpServer.Create(RawUtf8(FPort.ToString), nil, nil, 'AuthServer', 4);
  FServer.OnRequest := @OnRequest;
  FValidator := TAuthServerValidator.Create(Self);
end;

procedure TAuthServer.Stop;
begin
  FValidator := nil;
  FServer.Free;
  FServer := nil;
  FDB.Free;
  FDB := nil;
end;

end.