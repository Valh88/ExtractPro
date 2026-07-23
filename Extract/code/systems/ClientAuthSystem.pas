unit ClientAuthSystem;

{$mode objfpc}{$H+}
{$modeswitch functionreferences}
{$modeswitch anonymousfunctions}

interface

uses
  SysUtils, Classes,
  Interfaces, AuthTypes, AuthClient,
  CastleKeysMouse,
  System.Threading, GameConfig;

type
  TAuthRequestKind = (arkNone, arkLogin, arkRegister);

  TAuthRequestResult = record
    Kind: TAuthRequestKind;
    Success: Boolean;
    Token: string;
    UserId: Int64;
    UserLogin: string;
    ErrorMsg: string;
  end;

  TAuthRequestEvent = procedure(Sender: TObject; const Result: TAuthRequestResult) of object;

  TClientAuthSystem = class(TInterfacedObject, IWorldSystem)
  private
    FClient: TAuthClient;
    FToken: string;
    FUserId: Int64;
    FLogin: string;
    FTask: ITask;
    FAsyncResult: TAuthRequestResult;
    FOnAuthResult: TAuthRequestEvent;
    procedure DoAuth(const ALogin, APassword, AEmail: string; AKind: TAuthRequestKind);
  public
    constructor Create(const AServerUrl: string = '');
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single);
    function Press(const Event: TInputPressRelease): Boolean;
    procedure LoginAsync(const ALogin, APassword: string);
    procedure RegisterAsync(const ALogin, APassword, AEmail: string);
    property Token: string read FToken;
    property UserId: Int64 read FUserId;
    property UserLogin: string read FLogin;
    property OnAuthResult: TAuthRequestEvent read FOnAuthResult write FOnAuthResult;
  end;

implementation

{ TClientAuthSystem }

constructor TClientAuthSystem.Create(const AServerUrl: string);
var
  Url: string;
begin
  inherited Create;
  if AServerUrl <> '' then
    Url := AServerUrl
  else
    Url := 'http://' + GlobalConfig.ServerHost + ':' + IntToStr(GlobalConfig.AuthPort);
  FClient := TAuthClient.Create(Url);
  FTask := nil;
  FToken := '';
  FUserId := 0;
  FLogin := '';
  FOnAuthResult := nil;
  FillChar(FAsyncResult, SizeOf(FAsyncResult), 0);
end;

destructor TClientAuthSystem.Destroy;
begin
  if FTask <> nil then
  begin
    FTask.Cancel;
    FTask := nil;
  end;
  FClient.Free;
  inherited;
end;

procedure TClientAuthSystem.DoAuth(const ALogin, APassword, AEmail: string;
  AKind: TAuthRequestKind);
var
  Client: TAuthClient;
  Resp: TAuthResponse;
  Res: TAuthRequestResult;
begin
  Client := TAuthClient.Create(FClient.ServerUrl);
  try
    FillChar(Res, SizeOf(Res), 0);
    Res.Kind := AKind;
    case AKind of
      arkLogin:
      begin
        Resp := Client.Login(ALogin, APassword);
        Res.Success := Resp.Success;
        Res.Token := Resp.SessionToken;
        Res.UserId := Resp.UserId;
        Res.UserLogin := Resp.Login;
        Res.ErrorMsg := Resp.ErrorMsg;
      end;
      arkRegister:
      begin
        Resp := Client.Register(ALogin, APassword, AEmail);
        Res.Success := Resp.Success;
        Res.Token := Resp.SessionToken;
        Res.UserId := Resp.UserId;
        Res.UserLogin := Resp.Login;
        Res.ErrorMsg := Resp.ErrorMsg;
      end;
    end;
    FAsyncResult := Res;
  finally
    Client.Free;
  end;
end;

procedure TClientAuthSystem.Update(const SecondsPassed: Single);
begin
  if (FTask <> nil) and (FTask.Status = TTaskStatus.Completed) then
  begin
    if FAsyncResult.Success then
    begin
      FToken := FAsyncResult.Token;
      FUserId := FAsyncResult.UserId;
      FLogin := FAsyncResult.UserLogin;
    end;
    if Assigned(FOnAuthResult) then
      FOnAuthResult(Self, FAsyncResult);
    FTask := nil;
  end;
end;

procedure TClientAuthSystem.LoginAsync(const ALogin, APassword: string);
begin
  if FTask <> nil then Exit;
  FillChar(FAsyncResult, SizeOf(FAsyncResult), 0);
  FTask := TTask.Run(procedure
  begin
    DoAuth(ALogin, APassword, '', arkLogin);
  end);
end;

procedure TClientAuthSystem.RegisterAsync(const ALogin, APassword, AEmail: string);
begin
  if FTask <> nil then Exit;
  FillChar(FAsyncResult, SizeOf(FAsyncResult), 0);
  FTask := TTask.Run(procedure
  begin
    DoAuth(ALogin, APassword, AEmail, arkRegister);
  end);
end;

function TClientAuthSystem.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := False;
end;

end.