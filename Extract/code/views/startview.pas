unit StartView;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse,
  LobbyClient, ClientAuthSystem, GameViewLobby, GameConfig,
  ViewSwitchTransition, AnimationManager;

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
    destructor Destroy; override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
  private
    FLobbyClient: TLobbyClient;
    FConnecting: Boolean;
    FAnimManager: TAnimationManager;
    FTransition: TViewSwitchTransition;
    procedure OnTransitionCompleted(Sender: TObject);
    procedure ShowInfo(const ATitle, AText: String);
    procedure DoConnect(Sender: TObject);
    procedure DoRegister(Sender: TObject);
    procedure OnLoginResult(Sender: TObject; const Result: TAuthRequestResult);
    procedure OnRegisterResult(Sender: TObject; const Result: TAuthRequestResult);
  end;

var
  ViewStartView: TViewStartView;

implementation

uses SysUtils, CastleLog;

constructor TViewStartView.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/startview.castle-user-interface';
  FAnimManager := TAnimationManager.Create;
  FTransition := TViewSwitchTransition.Create;
  FTransition.OnCompleted := @OnTransitionCompleted;
end;

destructor TViewStartView.Destroy;
begin
  FreeAndNil(FTransition);
  FreeAndNil(FAnimManager);
  inherited;
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
  FAnimManager.Update(SecondsPassed);
  if FTransition <> nil then
    FTransition.Update(SecondsPassed);
  if FLobbyClient <> nil then
    FLobbyClient.Update(SecondsPassed);
end;

procedure TViewStartView.OnTransitionCompleted(Sender: TObject);
begin
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
    ShowInfo('', 'Connection successful');
    FLobbyClient.NetSystem.AuthToken := Result.Token;
    ViewLobby.JoinLobby(FLobbyClient, GlobalConfig.ServerHost, GlobalConfig.LobbyPort);
    FLobbyClient := nil;
    FTransition.Start(Container, Self, ViewLobby, FAnimManager, 0.5, 1.5);
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
  FLobbyClient.AuthSystem.LoginAsync(Login.Text, Password.Text);
end;

end.
