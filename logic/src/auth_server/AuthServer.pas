unit AuthServer;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes,
  mormot.core.base,
  mormot.core.os,
  mormot.core.text,
  mormot.core.log,
  mormot.crypt.core,
  mormot.orm.core,
  mormot.rest.core,
  mormot.rest.server,
  mormot.rest.sqlite3,
  mormot.rest.http.server,
  AuthTypes;

type
  TSQLAuthUser = class(TAuthUser)
  private
    fEmail: RawUtf8;
  published
    property Email: RawUtf8 index 100 read fEmail write fEmail;
  end;

  TSQLSession = class(TOrm)
  private
    fUserId: TID;
    fToken: RawUtf8;
    fCreatedAt: TTimeLog;
    fExpiresAt: TTimeLog;
  published
    property UserId: TID read fUserId write fUserId;
    property Token: RawUtf8 index 128 read fToken write fToken stored AS_UNIQUE;
    property CreatedAt: TTimeLog read fCreatedAt write fCreatedAt;
    property ExpiresAt: TTimeLog read fExpiresAt write fExpiresAt;
  end;

  TAuthRestServer = class(TRestServerDB)
  public
    procedure Login(Ctxt: TRestServerUriContext);
    procedure RegisterUser(Ctxt: TRestServerUriContext);
    procedure ValidateToken(Ctxt: TRestServerUriContext);
  end;

  TAuthServer = class
  private
    FPort: Word;
    FRest: TAuthRestServer;
    FHttp: TRestHttpServer;
    FValidator: IAuthValidator;
  public
    constructor Create(const APort: Word = AUTH_SERVER_DEFAULT_PORT);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Validator: IAuthValidator read FValidator;
  end;

  TAuthServerValidator = class(TInterfacedObject, IAuthValidator)
  private
    FServer: TAuthRestServer;
  public
    constructor Create(AServer: TAuthRestServer);
    function ValidateToken(const Token: string): TAuthResult;
  end;

implementation

{ TAuthServerValidator }

constructor TAuthServerValidator.Create(AServer: TAuthRestServer);
begin
  inherited Create;
  FServer := AServer;
end;

function TAuthServerValidator.ValidateToken(const Token: string): TAuthResult;
var
  Session: TSQLSession;
begin
  Result.Valid := False;
  Session := TSQLSession.Create(FServer.OrmInstance, 'Token=?', [StringToUtf8(Token)]);
  try
    if (Session.ID = 0) or (Session.ExpiresAt < NowUtc * SecsPerDay) then
      Exit;
    Result.UserId := Session.UserId;
    Result.Valid := True;
  finally
    Session.Free;
  end;
end;

{ TAuthRestServer }

procedure TAuthRestServer.Login(Ctxt: TRestServerUriContext);
var
  Login, Password: RawUtf8;
  User: TSQLAuthUser;
  HashHex: RawUtf8;
  TokenRaw: TBytes;
  Session: TSQLSession;
begin
  Login := Ctxt.InputUtf8['UserName'];
  Password := Ctxt.InputUtf8['PassWord'];
  if (Login = '') or (Password = '') then
  begin
    Ctxt.Error('Login and password required', 400);
    Exit;
  end;
  User := TSQLAuthUser.Create(OrmInstance, 'LogonName=?', [Login]);
  try
    if User.ID = 0 then
    begin
      Ctxt.Error('Invalid login or password', 401);
      Exit;
    end;
    HashHex := BinToHex(
      Pbkdf2HmacSha256(RawByteString(Password), HexToBin(User.PasswordHashHexa),
      60000, 32));
    if HashHex <> User.PasswordHashHexa then
    begin
      Ctxt.Error('Invalid login or password', 401);
      Exit;
    end;
    SetLength(TokenRaw, AUTH_TOKEN_SIZE);
    TAesPrng.Main.FillRandom(TokenRaw[0], AUTH_TOKEN_SIZE);
    Session := TSQLSession.Create;
    try
      Session.UserId := User.ID;
      Session.Token := BinToHex(RawByteString(TokenRaw));
      Session.CreatedAt := Int64(NowUtc * SecsPerDay);
      Session.ExpiresAt := Int64((NowUtc + AUTH_SESSION_EXPIRE_HOURS / 24) * SecsPerDay);
      if OrmInstance.Add(Session, True) = 0 then
      begin
        Ctxt.Error('Failed to create session', 500);
        Exit;
      end;
      Ctxt.Returns([
        'success', True,
        'token', Session.Token,
        'user_id', User.ID,
        'login', User.LogonName]);
    finally
      Session.Free;
    end;
  finally
    User.Free;
  end;
end;

procedure TAuthRestServer.RegisterUser(Ctxt: TRestServerUriContext);
var
  Login, Password, Email: RawUtf8;
  User: TSQLAuthUser;
begin
  Login := Ctxt.InputUtf8['UserName'];
  Password := Ctxt.InputUtf8['PassWord'];
  Email := Ctxt.InputUtf8['Email'];
  if (Login = '') or (Password = '') then
  begin
    Ctxt.Error('Login and password required', 400);
    Exit;
  end;
  if Length(Password) < 4 then
  begin
    Ctxt.Error('Password too short (min 4 chars)', 400);
    Exit;
  end;
  User := TSQLAuthUser.Create;
  try
    User.LogonName := Login;
    User.PasswordHashHexa := BinToHex(
      Pbkdf2HmacSha256(RawByteString(Password),
        TAesPrng.Main.FillRandom(16), 60000, 32));
    User.Email := Email;
    User.DisplayName := Login;
    if OrmInstance.Add(User, True) = 0 then
    begin
      Ctxt.Error('User already exists', 409);
      Exit;
    end;
    Ctxt.Returns(['success', True, 'user_id', User.ID, 'login', Login]);
  finally
    User.Free;
  end;
end;

procedure TAuthRestServer.ValidateToken(Ctxt: TRestServerUriContext);
var
  Tkn: RawUtf8;
  Session: TSQLSession;
  UserLogin: RawUtf8;
begin
  Tkn := Ctxt.InputUtf8['Token'];
  if Tkn = '' then
  begin
    Ctxt.Error('Token required', 400);
    Exit;
  end;
  Session := TSQLSession.Create(OrmInstance, 'Token=?', [Tkn]);
  try
    if (Session.ID = 0) or (Session.ExpiresAt < Int64(NowUtc * SecsPerDay)) then
    begin
      Ctxt.Returns(['valid', False, 'error', 'Invalid or expired token']);
      Exit;
    end;
    UserLogin := '';
    UserLogin := OrmInstance.OneFieldValue(TSQLAuthUser, 'LogonName', 'ID=?', [Session.UserId]);
    Ctxt.Returns(['valid', True, 'user_id', Session.UserId, 'login', UserLogin]);
  finally
    Session.Free;
  end;
end;

{ TAuthServer }

constructor TAuthServer.Create(const APort: Word);
begin
  inherited Create;
  FPort := APort;
  FRest := nil;
  FHttp := nil;
end;

destructor TAuthServer.Destroy;
begin
  Stop;
  inherited;
end;

procedure TAuthServer.Start;
begin
  if FRest <> nil then
    Exit;
  FRest := TAuthRestServer.CreateWithOwnModel(
    [TSQLAuthUser, TSQLSession], FPort.ToString + '.db', False, 'auth');
  FRest.ServiceMethodRegister('login', @FRest.Login, True, [mPOST]);
  FRest.ServiceMethodRegister('register', @FRest.RegisterUser, True, [mPOST]);
  FRest.ServiceMethodRegister('validate', @FRest.ValidateToken, True, [mPOST]);
  FHttp := TRestHttpServer.Create([FRest], RawUtf8(FPort.ToString), 4);
  FValidator := TAuthServerValidator.Create(FRest);
end;

procedure TAuthServer.Stop;
begin
  FValidator := nil;
  FHttp.Free;
  FHttp := nil;
  FRest.Free;
  FRest := nil;
end;

end.