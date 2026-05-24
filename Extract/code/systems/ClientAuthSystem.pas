unit ClientAuthSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, SyncObjs,
  WorldSystemBase, GameWorld, AuthTypes, AuthClient;

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

  TAuthHttpThread = class(TThread)
  private
    FClient: TAuthClient;
    FKind: TAuthRequestKind;
    FLogin, FPassword, FEmail: string;
    FResult: TAuthRequestResult;
  protected
    procedure Execute; override;
  public
    constructor Create(const ALogin, APassword, AEmail: string; AKind: TAuthRequestKind;
      const AServerUrl: string);
    destructor Destroy; override;
    property Result: TAuthRequestResult read FResult;
  end;

  TClientAuthSystem = class(TWorldSystemBase)
  private
    FClient: TAuthClient;
    FToken: string;
    FUserId: Int64;
    FLogin: string;
    FThread: TAuthHttpThread;
    FLastResult: TAuthRequestResult;
    FOnAuthResult: TAuthRequestEvent;
  public
    constructor Create(AWorldObj: TGameWorld; const AServerUrl: string = '');
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    procedure LoginAsync(const ALogin, APassword: string);
    procedure RegisterAsync(const ALogin, APassword, AEmail: string);
    property Token: string read FToken;
    property UserId: Int64 read FUserId;
    property UserLogin: string read FLogin;
    property OnAuthResult: TAuthRequestEvent read FOnAuthResult write FOnAuthResult;
  end;

implementation

{ TAuthHttpThread }

constructor TAuthHttpThread.Create(const ALogin, APassword, AEmail: string;
  AKind: TAuthRequestKind; const AServerUrl: string);
begin
  inherited Create(False);
  FClient := TAuthClient.Create(AServerUrl);
  FKind := AKind;
  FLogin := ALogin;
  FPassword := APassword;
  FEmail := AEmail;
  FreeOnTerminate := False;
  FillChar(FResult, SizeOf(FResult), 0);
  FResult.Kind := AKind;
end;

destructor TAuthHttpThread.Destroy;
begin
  FClient.Free;
  inherited;
end;

procedure TAuthHttpThread.Execute;
var
  Resp: TAuthResponse;
begin
  case FKind of
    arkLogin:
    begin
      Resp := FClient.Login(FLogin, FPassword);
      FResult.Success := Resp.Success;
      FResult.Token := Resp.SessionToken;
      FResult.UserId := Resp.UserId;
      FResult.UserLogin := Resp.Login;
      FResult.ErrorMsg := Resp.ErrorMsg;
    end;
    arkRegister:
    begin
      Resp := FClient.Register(FLogin, FPassword, FEmail);
      FResult.Success := Resp.Success;
      FResult.Token := Resp.SessionToken;
      FResult.UserId := Resp.UserId;
      FResult.UserLogin := Resp.Login;
      FResult.ErrorMsg := Resp.ErrorMsg;
    end;
  end;
end;

{ TClientAuthSystem }

constructor TClientAuthSystem.Create(AWorldObj: TGameWorld; const AServerUrl: string);
begin
  inherited Create(AWorldObj);
  FClient := TAuthClient.Create(AServerUrl);
  FThread := nil;
  FToken := '';
  FUserId := 0;
  FLogin := '';
  FOnAuthResult := nil;
  FillChar(FLastResult, SizeOf(FLastResult), 0);
end;

destructor TClientAuthSystem.Destroy;
begin
  if FThread <> nil then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FThread.Free;
  end;
  FClient.Free;
  inherited;
end;

procedure TClientAuthSystem.Update(const SecondsPassed: Single);
begin
  if FThread <> nil then
  begin
    if FThread.Finished then
    begin
      FLastResult := FThread.Result;
      if FLastResult.Success and (FLastResult.Kind = arkLogin) then
      begin
        FToken := FLastResult.Token;
        FUserId := FLastResult.UserId;
        FLogin := FLastResult.UserLogin;
      end;
      if Assigned(FOnAuthResult) then
        FOnAuthResult(Self, FLastResult);
      FThread.Free;
      FThread := nil;
    end;
  end;
end;

procedure TClientAuthSystem.LoginAsync(const ALogin, APassword: string);
begin
  if FThread <> nil then
    Exit;
  FillChar(FLastResult, SizeOf(FLastResult), 0);
  FThread := TAuthHttpThread.Create(ALogin, APassword, '', arkLogin, FClient.ServerUrl);
end;

procedure TClientAuthSystem.RegisterAsync(const ALogin, APassword, AEmail: string);
begin
  if FThread <> nil then
    Exit;
  FillChar(FLastResult, SizeOf(FLastResult), 0);
  FThread := TAuthHttpThread.Create(ALogin, APassword, AEmail, arkRegister, FClient.ServerUrl);
end;

end.