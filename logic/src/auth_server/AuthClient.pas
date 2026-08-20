unit AuthClient;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, variants,
  CastleLog,
  mormot.core.base,
  mormot.core.text,
  mormot.core.variants,
  mormot.net.client,
  AuthTypes, GameConfig;

type
  TAuthClient = class
  private
    FHttp: IHttpClient;
    FServerUrl: string;
  public
    constructor Create(const AServerUrl: string = '');
    destructor Destroy; override;
    function Login(const aLogin, aPassword: string): TAuthResponse;
    function Register(const aLogin, aPassword, aEmail: string): TAuthResponse;
    function ValidateToken(const Token: string): TAuthResult;
    property ServerUrl: string read FServerUrl write FServerUrl;
  end;

implementation

constructor TAuthClient.Create(const AServerUrl: string);
begin
  inherited Create;
  FServerUrl := AServerUrl;
  if FServerUrl = '' then
    FServerUrl := 'http://' + GlobalConfig.ServerHost + ':' + IntToStr(GlobalConfig.AuthPort);
  FHttp := TSimpleHttpClient.Create;
end;

destructor TAuthClient.Destroy;
begin
  FHttp := nil;
  inherited;
end;

function TAuthClient.Login(const aLogin, aPassword: string): TAuthResponse;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WritelnLog('AuthClient', 'Login request: %s -> %s/api/auth/login', [aLogin, FServerUrl]);
  Result.Success := False;
  FHttp.Request(
    RawUtf8(FServerUrl + '/api/auth/login'),
    'POST', '',
    VariantToUtf8(_Obj([
      'UserName', RawUtf8(aLogin),
      'PassWord', RawUtf8(aPassword)
    ])), 'application/json');
  Resp := FHttp.Body;
  if FHttp.Status = 0 then
  begin
    Result.ErrorMsg := 'Connection failed';
    WritelnLog('AuthClient', 'Login FAILED: connection failed');
    Exit;
  end;
  Json := _JsonFast(Resp);
  Result.Success := Json.success;
  if Result.Success then
  begin
    Result.SessionToken := string(VariantToUtf8(Json.token));
    Result.UserId := Json.user_id;
    Result.Login := string(VariantToUtf8(Json.login));
  end;
  Result.ErrorMsg := string(VariantToUtf8(Json.error));
  if Result.Success then
    WritelnLog('AuthClient', 'Login OK: user_id=%d, login=%s', [Result.UserId, Result.Login])
  else
    WritelnLog('AuthClient', 'Login FAILED: %s', [Result.ErrorMsg]);
end;

function TAuthClient.Register(const aLogin, aPassword, aEmail: string): TAuthResponse;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WritelnLog('AuthClient', 'Register request: %s -> %s/api/auth/register', [aLogin, FServerUrl]);
  Result.Success := False;
  FHttp.Request(
    RawUtf8(FServerUrl + '/api/auth/register'),
    'POST', '',
    VariantToUtf8(_Obj([
      'UserName', RawUtf8(aLogin),
      'PassWord', RawUtf8(aPassword),
      'Email', RawUtf8(aEmail)
    ])), 'application/json');
  Resp := FHttp.Body;
  if FHttp.Status = 0 then
  begin
    Result.ErrorMsg := 'Connection failed';
    WritelnLog('AuthClient', 'Register FAILED: connection failed');
    Exit;
  end;
  Json := _JsonFast(Resp);
  Result.Success := Json.success;
  if Result.Success then
  begin
    Result.UserId := Json.user_id;
    Result.Login := string(VariantToUtf8(Json.login));
  end;
  Result.ErrorMsg := string(VariantToUtf8(Json.error));
  if Result.Success then
    WritelnLog('AuthClient', 'Register OK: user_id=%d, login=%s', [Result.UserId, Result.Login])
  else
    WritelnLog('AuthClient', 'Register FAILED: %s', [Result.ErrorMsg]);
end;

function TAuthClient.ValidateToken(const Token: string): TAuthResult;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WritelnLog('AuthClient', 'ValidateToken: token=%s...', [Copy(Token, 1, 8)]);
  Result.Valid := False;
  FHttp.Request(
    RawUtf8(FServerUrl + '/api/auth/validate'),
    'POST', '',
    VariantToUtf8(_Obj([
      'Token', RawUtf8(Token)
    ])), 'application/json');
  Resp := FHttp.Body;
  if FHttp.Status = 0 then
  begin
    WritelnLog('AuthClient', 'ValidateToken FAILED: connection failed');
    Exit;
  end;
  Json := _JsonFast(Resp);
  Result.Valid := Json.valid;
  Result.UserId := Json.user_id;
  Result.Login := string(VariantToUtf8(Json.login));
  if Result.Valid then
    WritelnLog('AuthClient', 'ValidateToken OK: user_id=%d', [Result.UserId])
  else
    WritelnLog('AuthClient', 'ValidateToken FAILED: invalid/expired');
end;

end.