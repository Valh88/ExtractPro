unit StartView;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse,
  LobbyClient, ClientAuthSystem, GameViewLobby, GameConfig;

type
  TViewStartView = class(TCastleView)
  published
    Login: TCastleEdit;
    Password: TCastleEdit;
    Ok: TCastleButton;
    Reg: TCastleButton;
    Information: TCastleLabel;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
  private
    FLobbyClient: TLobbyClient;
    FConnecting: Boolean;
    procedure DoConnect(Sender: TObject);
    procedure DoRegister(Sender: TObject);
    procedure OnLoginResult(Sender: TObject; const Result: TAuthRequestResult);
    procedure OnRegisterResult(Sender: TObject; const Result: TAuthRequestResult);
    procedure OnLobbyConnected(Sender: TObject);
  end;

var
  ViewStartView: TViewStartView;

implementation

uses SysUtils, CastleLog;

constructor TViewStartView.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/startview.castle-user-interface';
end;

procedure TViewStartView.Start;
begin
  inherited;
  FConnecting := False;
  Ok.OnClick := @DoConnect;
  Reg.OnClick := @DoRegister;
end;

procedure TViewStartView.Stop;
begin
  if FLobbyClient <> nil then
    FreeAndNil(FLobbyClient);
  inherited;
end;

procedure TViewStartView.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  if FLobbyClient <> nil then
    FLobbyClient.Update(SecondsPassed);
end;

procedure TViewStartView.DoConnect(Sender: TObject);
begin
  if FConnecting then Exit;
  FConnecting := True;

  FLobbyClient := TLobbyClient.Create;
  FLobbyClient.AuthSystem.OnAuthResult := @OnLoginResult;
  FLobbyClient.NetSystem.OnConnected := @OnLobbyConnected;
  FLobbyClient.AuthSystem.LoginAsync(Login.Text, Password.Text);
end;

procedure TViewStartView.DoRegister(Sender: TObject);
begin
  if FConnecting then Exit;
  FConnecting := True;

  FLobbyClient := TLobbyClient.Create;
  FLobbyClient.AuthSystem.OnAuthResult := @OnRegisterResult;
  FLobbyClient.AuthSystem.RegisterAsync(Login.Text, Password.Text, '');
end;

procedure TViewStartView.OnLoginResult(Sender: TObject;
  const Result: TAuthRequestResult);
begin
  WritelnLog('StartView', 'OnLoginResult: success=%s', [BoolToStr(Result.Success, True)]);
  if Result.Success then
  begin
    Information.Text.Clear;
    Information.Text.Add('Token: ' + Result.Token);
    Information.Text.Add('Login: ' + Result.UserLogin + ' (id=' + IntToStr(Result.UserId) + ')');
    Information.Exists := True;
    FLobbyClient.NetSystem.AuthToken := Result.Token;
    FLobbyClient.Connect(GlobalConfig.ServerHost, GlobalConfig.LobbyPort);
  end
  else
  begin
    Information.Text.Clear;
    Information.Text.Add('Login failed: ' + Result.ErrorMsg);
    Information.Exists := True;
    FConnecting := False;
  end;
end;

procedure TViewStartView.OnRegisterResult(Sender: TObject;
  const Result: TAuthRequestResult);
begin
  WritelnLog('StartView', 'OnRegisterResult: success=%s', [BoolToStr(Result.Success, True)]);
  if not Result.Success then
  begin
    Information.Text.Clear;
    Information.Text.Add('Register failed: ' + Result.ErrorMsg);
    Information.Exists := True;
    FConnecting := False;
    Exit;
  end;
  Information.Text.Clear;
  Information.Text.Add('Register OK, logging in...');
  Information.Exists := True;
  FLobbyClient.AuthSystem.OnAuthResult := @OnLoginResult;
  FLobbyClient.NetSystem.OnConnected := @OnLobbyConnected;
  FLobbyClient.AuthSystem.LoginAsync(Login.Text, Password.Text);
end;

procedure TViewStartView.OnLobbyConnected(Sender: TObject);
begin
  WritelnLog('StartView', 'OnLobbyConnected');
  FConnecting := False;
  ViewLobby.SetLobbyClient(FLobbyClient);
  FLobbyClient := nil;
  Container.View := ViewLobby;
end;

end.
