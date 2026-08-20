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
    InfoDesign: TCastleDesign;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
  private
    FLobbyClient: TLobbyClient;
    FConnecting: Boolean;
    procedure ShowInfo(const ATitle, AText: String);
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
  if InfoDesign <> nil then
  begin
    InfoDesign.Parent.RemoveControl(InfoDesign);
    InsertFront(InfoDesign);
  end;
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

procedure TViewStartView.ShowInfo(const ATitle, AText: String);
var
  Title, Txt: TCastleLabel;
begin
  if InfoDesign = nil then Exit;
  Title := InfoDesign.DesignedComponent('InfoTitle') as TCastleLabel;
  Txt := InfoDesign.DesignedComponent('InfoText') as TCastleLabel;
  if Title <> nil then
    Title.Caption := ATitle;
  if Txt <> nil then
    Txt.Caption := AText;
  InfoDesign.Exists := True;
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
    ShowInfo('', 'Token: ' + Result.Token + sLineBreak +
      'Login: ' + Result.UserLogin + ' (id=' + IntToStr(Result.UserId) + ')');
    FLobbyClient.NetSystem.AuthToken := Result.Token;
    FLobbyClient.Connect(GlobalConfig.ServerHost, GlobalConfig.LobbyPort);
  end
  else
  begin
    ShowInfo('', 'Login failed: ' + Result.ErrorMsg);
    FConnecting := False;
  end;
end;

procedure TViewStartView.OnRegisterResult(Sender: TObject;
  const Result: TAuthRequestResult);
begin
  WritelnLog('StartView', 'OnRegisterResult: success=%s', [BoolToStr(Result.Success, True)]);
  if not Result.Success then
  begin
    ShowInfo('', 'Register failed: ' + Result.ErrorMsg);
    FConnecting := False;
    Exit;
  end;
  ShowInfo('', 'Register OK, logging in...');
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
