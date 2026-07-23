unit AuthClient;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, variants,
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
  WriteLn(StdErr, '[AuthClient] Login request: ', aLogin, ' -> ', FServerUrl, '/api/auth/login');
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
    WriteLn(StdErr, '[AuthClient] Login FAILED: connection failed');
    Exit;
  end;
  Json := _JsonFast(Resp);
  Result.Success := Json.success;
  Result.SessionToken := string(VariantToUtf8(Json.token));
  Result.UserId := Json.user_id;
  Result.Login := string(VariantToUtf8(Json.login));
  Result.ErrorMsg := string(VariantToUtf8(Json.error));
  if Result.Success then
    WriteLn(StdErr, '[AuthClient] Login OK: user_id=', Result.UserId, ', login=', Result.Login)
  else
    WriteLn(StdErr, '[AuthClient] Login FAILED: ', Result.ErrorMsg);
end;

function TAuthClient.Register(const aLogin, aPassword, aEmail: string): TAuthResponse;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WriteLn(StdErr, '[AuthClient] Register request: ', aLogin, ' -> ', FServerUrl, '/api/auth/register');
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
    WriteLn(StdErr, '[AuthClient] Register FAILED: connection failed');
    Exit;
  end;
  Json := _JsonFast(Resp);
  Result.Success := Json.success;
  Result.UserId := Json.user_id;
  Result.Login := string(VariantToUtf8(Json.login));
  Result.ErrorMsg := string(VariantToUtf8(Json.error));
  if Result.Success then
    WriteLn(StdErr, '[AuthClient] Register OK: user_id=', Result.UserId, ', login=', Result.Login)
  else
    WriteLn(StdErr, '[AuthClient] Register FAILED: ', Result.ErrorMsg);
end;

function TAuthClient.ValidateToken(const Token: string): TAuthResult;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WriteLn(StdErr, '[AuthClient] ValidateToken: token=', Copy(Token, 1, 8), '...');
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
    WriteLn(StdErr, '[AuthClient] ValidateToken FAILED: connection failed');
    Exit;
  end;
  Json := _JsonFast(Resp);
  Result.Valid := Json.valid;
  Result.UserId := Json.user_id;
  Result.Login := string(VariantToUtf8(Json.login));
  if Result.Valid then
    WriteLn(StdErr, '[AuthClient] ValidateToken OK: user_id=', Result.UserId)
  else
    WriteLn(StdErr, '[AuthClient] ValidateToken FAILED: invalid/expired');
end;

end.