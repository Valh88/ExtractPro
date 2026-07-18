unit GameViewPlay;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse,
  ClientMatchmakingSystem;

type
  TViewPlay = class(TCastleView)
  published
    PlayPanel: TCastleDesign;
  public
    LeftPanel: TCastleImageControl;
    ModeTitle: TCastleLabel;
    MapImage: TCastleImageControl;
    Duration: TCastleLabel;
    ModeIcons: TCastleHorizontalGroup;
    SoloIcon: TCastleImageControl;
    PartyIcon: TCastleImageControl;
    SearchBtn: TCastleButton;
    FMatchmakingSystem: TClientMatchmakingSystem;
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
    procedure OnSearchPress(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure OnQueueStateChanged(Sender: TObject);
    property MatchmakingSystem: TClientMatchmakingSystem read FMatchmakingSystem write FMatchmakingSystem;
  end;

var
  ViewPlay: TViewPlay;

implementation

constructor TViewPlay.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/lobby_view/gameviewplay.castle-user-interface';
end;

procedure TViewPlay.Start;
begin
  inherited;
  LeftPanel := PlayPanel.DesignedComponent('LeftPanel') as TCastleImageControl;
  ModeTitle := PlayPanel.DesignedComponent('ModeTitle') as TCastleLabel;
  MapImage := PlayPanel.DesignedComponent('MapImage') as TCastleImageControl;
  Duration := PlayPanel.DesignedComponent('Duration') as TCastleLabel;
  ModeIcons := PlayPanel.DesignedComponent('ModeIcons') as TCastleHorizontalGroup;
  SoloIcon := PlayPanel.DesignedComponent('SoloIcon') as TCastleImageControl;
  PartyIcon := PlayPanel.DesignedComponent('PartyIcon') as TCastleImageControl;
  SearchBtn := PlayPanel.DesignedComponent('SearchBtn') as TCastleButton;
  SearchBtn.OnPress := @OnSearchPress;
  if FMatchmakingSystem <> nil then
  begin
    FMatchmakingSystem.OnStateChanged := @OnQueueStateChanged;
    OnQueueStateChanged(nil);
  end;
end;

procedure TViewPlay.Stop;
begin
  inherited;
  if FMatchmakingSystem <> nil then
    FMatchmakingSystem.OnStateChanged := nil;
end;

procedure TViewPlay.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
end;

procedure TViewPlay.OnSearchPress(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if FMatchmakingSystem = nil then Exit;
  if FMatchmakingSystem.State = msSearching then
    FMatchmakingSystem.Dequeue
  else
    FMatchmakingSystem.Enqueue;
  Handled := True;
end;

procedure TViewPlay.OnQueueStateChanged(Sender: TObject);
begin
  if FMatchmakingSystem.State = msSearching then
    SearchBtn.Caption := 'CANCEL'
  else
    SearchBtn.Caption := 'SEARCH';
end;

end.
