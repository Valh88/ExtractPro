unit StartView;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse,
  LobbyClient, ClientAuthSystem, GameViewMain;

type
  TViewStartView = class(TCastleView)
  published
    Login: TCastleEdit;
    Password: TCastleEdit;
    Ok: TCastleButton;
    Reg: TCastleButton;
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

uses SysUtils;

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
  if Result.Success then
    FLobbyClient.Connect('127.0.0.1', 7777)
  else
    FConnecting := False;
end;

procedure TViewStartView.OnRegisterResult(Sender: TObject;
  const Result: TAuthRequestResult);
begin
  if not Result.Success then
  begin
    FConnecting := False;
    Exit;
  end;
  FLobbyClient.AuthSystem.OnAuthResult := @OnLoginResult;
  FLobbyClient.NetSystem.OnConnected := @OnLobbyConnected;
  FLobbyClient.AuthSystem.LoginAsync(Login.Text, Password.Text);
end;

procedure TViewStartView.OnLobbyConnected(Sender: TObject);
begin
  FConnecting := False;
  Container.View := ViewMain;
end;

end.
