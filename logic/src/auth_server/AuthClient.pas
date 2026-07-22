unit AuthClient;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, variants,
  mormot.core.base,
  mormot.core.text,
  mormot.core.variants,
  mormot.net.client,
  mormot.net.sock,
  AuthTypes;

type
  THttpAuthSocket = class(THttpClientSocket)
  public
    procedure OpenHost(const AHost: string; APort: Word);
  end;

  TAuthClient = class
  private
    FHttp: THttpAuthSocket;
    FHost: string;
    FPort: Word;
  public
    constructor Create(const AHost: string = '::1'; APort: Word = AUTH_SERVER_DEFAULT_PORT);
    destructor Destroy; override;
    function Login(const aLogin, aPassword: string): TAuthResponse;
    function Register(const aLogin, aPassword, aEmail: string): TAuthResponse;
    function ValidateToken(const Token: string): TAuthResult;
    property Host: string read FHost write FHost;
    property Port: Word read FPort write FPort;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  WinSock2;
{$ENDIF}

type
  PAddrinfo = ^TAddrinfo;
  PPPAddrinfo = ^PAddrinfo;
  TAddrinfo = record
    ai_flags: Integer;
    ai_family: Integer;
    ai_socktype: Integer;
    ai_protocol: Integer;
    ai_addrlen: Integer;
    ai_addr: Pointer;
    ai_canonname: PAnsiChar;
    ai_next: PAddrinfo;
  end;

const
  AI_NUMERICHOST = $0004;
  AF_UNSPEC = 0;
  SOCK_STREAM = 1;

{$IFDEF MSWINDOWS}
function c_getaddrinfo(node, service: PAnsiChar; hints: PAddrinfo; res: PPPAddrinfo): Integer; stdcall; external 'ws2_32.dll' name 'getaddrinfo';
procedure c_freeaddrinfo(res: PAddrinfo); stdcall; external 'ws2_32.dll' name 'freeaddrinfo';
function c_gai_strerror(errcode: Integer): PAnsiChar; stdcall; external 'ws2_32.dll' name 'gai_strerror';
function c_socket(domain, type_, protocol: Integer): Integer; stdcall; external 'ws2_32.dll' name 'socket';
function c_connect(s: Integer; name: Pointer; namelen: Integer): Integer; stdcall; external 'ws2_32.dll' name 'connect';
function c_close(fd: Integer): Integer; stdcall; external 'ws2_32.dll' name 'closesocket';
{$ELSE}
function c_getaddrinfo(node, service: PAnsiChar; hints: PAddrinfo; res: PPPAddrinfo): Integer; cdecl; external 'c' name 'getaddrinfo';
procedure c_freeaddrinfo(res: PAddrinfo); cdecl; external 'c' name 'freeaddrinfo';
function c_gai_strerror(errcode: Integer): PAnsiChar; cdecl; external 'c' name 'gai_strerror';
function c_socket(domain, type_, protocol: Integer): Integer; cdecl; external 'c' name 'socket';
function c_connect(s: Integer; name: Pointer; namelen: Integer): Integer; cdecl; external 'c' name 'connect';
function c_close(fd: Integer): Integer; cdecl; external 'c' name 'close';
{$ENDIF}

{ THttpAuthSocket }

procedure THttpAuthSocket.OpenHost(const AHost: string; APort: Word);
var
  Hints: TAddrinfo;
  AddrRes: PAddrinfo;
  FD: Integer;
  Res: Integer;
  PortStr: string;
begin
  FillChar(Hints, SizeOf(Hints), 0);
  Hints.ai_flags := AI_NUMERICHOST;
  Hints.ai_family := AF_UNSPEC;
  Hints.ai_socktype := SOCK_STREAM;

  PortStr := IntToStr(APort);
  Res := c_getaddrinfo(PAnsiChar(AHost), PAnsiChar(PortStr), @Hints, @AddrRes);
  if Res <> 0 then
    raise ENetSock.Create(
      'getaddrinfo failed for ' + AHost + ':' + PortStr + ': ' + c_gai_strerror(Res),
      nil, []);
  try
    {$IFDEF MSWINDOWS}
    FD := WinSock2.socket(AddrRes^.ai_family, AddrRes^.ai_socktype, AddrRes^.ai_protocol);
    if FD = INVALID_SOCKET then
      raise ENetSock.Create(
        'Cannot create socket for ' + AHost + ':' + PortStr, nil, []);

    if WinSock2.connect(FD, AddrRes^.ai_addr, AddrRes^.ai_addrlen) <> 0 then
    begin
      WinSock2.closesocket(FD);
      raise ENetSock.Create(
        'Cannot connect to ' + AHost + ':' + PortStr, nil, []);
    end;
    {$ELSE}
    FD := c_socket(AddrRes^.ai_family, AddrRes^.ai_socktype, AddrRes^.ai_protocol);
    if FD < 0 then
      raise ENetSock.Create(
        'Cannot create socket for ' + AHost + ':' + PortStr, nil, []);

    if c_connect(FD, AddrRes^.ai_addr, AddrRes^.ai_addrlen) <> 0 then
    begin
      c_close(FD);
      raise ENetSock.Create(
        'Cannot connect to ' + AHost + ':' + PortStr, nil, []);
    end;
    {$ENDIF}

    Close;
    fSock := TNetSocket(PtrInt(FD));
    fServer := RawUtf8(AHost);
    fPort := RawUtf8(PortStr);
    fSocketLayer := nlTcp;
    fSocketFamily := nfUnknown;
    fFlags := [];
    ResetNetTlsContext(TLS);
    if fTimeOut = 0 then
      fTimeOut := 10000;
  finally
    c_freeaddrinfo(AddrRes);
  end;
end;

{ TAuthClient }

constructor TAuthClient.Create(const AHost: string; APort: Word);
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FHttp := nil;
end;

destructor TAuthClient.Destroy;
begin
  FHttp.Free;
  inherited;
end;

function TAuthClient.Login(const aLogin, aPassword: string): TAuthResponse;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WriteLn(StdErr, '[AuthClient] Login request: ', aLogin, ' -> ', FHost, ':', FPort);
  Result.Success := False;

  FHttp := THttpAuthSocket.Create(10000);
  try
    FHttp.OpenHost(FHost, FPort);
    FHttp.Request('/api/auth/login', 'POST', 0, '',
      VariantToUtf8(_Obj([
        'UserName', RawUtf8(aLogin),
        'PassWord', RawUtf8(aPassword)
      ])), 'application/json');
    Resp := FHttp.Http.Content;

    if Resp = '' then
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
  finally
    FreeAndNil(FHttp);
  end;
end;

function TAuthClient.Register(const aLogin, aPassword, aEmail: string): TAuthResponse;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WriteLn(StdErr, '[AuthClient] Register request: ', aLogin, ' -> ', FHost, ':', FPort);
  Result.Success := False;

  FHttp := THttpAuthSocket.Create(10000);
  try
    FHttp.OpenHost(FHost, FPort);
    FHttp.Request('/api/auth/register', 'POST', 0, '',
      VariantToUtf8(_Obj([
        'UserName', RawUtf8(aLogin),
        'PassWord', RawUtf8(aPassword),
        'Email', RawUtf8(aEmail)
      ])), 'application/json');
    Resp := FHttp.Http.Content;

    if Resp = '' then
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
  finally
    FreeAndNil(FHttp);
  end;
end;

function TAuthClient.ValidateToken(const Token: string): TAuthResult;
var
  Resp: RawUtf8;
  Json: variant;
begin
  WriteLn(StdErr, '[AuthClient] ValidateToken: token=', Copy(Token, 1, 8), '...');
  Result.Valid := False;

  FHttp := THttpAuthSocket.Create(10000);
  try
    FHttp.OpenHost(FHost, FPort);
    FHttp.Request('/api/auth/validate', 'POST', 0, '',
      VariantToUtf8(_Obj([
        'Token', RawUtf8(Token)
      ])), 'application/json');
    Resp := FHttp.Http.Content;

    if Resp = '' then
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
  finally
    FreeAndNil(FHttp);
  end;
end;

end.
