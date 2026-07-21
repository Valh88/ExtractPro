unit GameViewPlay;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse,
  ClientMatchmakingSystem, ClientEventBus;

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
    SearchBtn: TCastleButton;
    FMatchmakingSystem: TClientMatchmakingSystem;
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
    procedure OnSearchPress(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure OnMMState(const Event: TClientGameEvent);
    property MatchmakingSystem: TClientMatchmakingSystem read FMatchmakingSystem write FMatchmakingSystem;
  private
    FSoloFrame: TCastleImageControl;
    FPartyFrame: TCastleImageControl;
    procedure OnSoloClick(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure OnPartyClick(const Sender: TCastleUserInterface;
      const Event: TInputPressRelease; var Handled: Boolean);
    procedure UpdatePartySizeUI;
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
var
  SI, PI: TCastleImageControl;
begin
  inherited;
  LeftPanel := PlayPanel.DesignedComponent('LeftPanel') as TCastleImageControl;
  ModeTitle := PlayPanel.DesignedComponent('ModeTitle') as TCastleLabel;
  MapImage := PlayPanel.DesignedComponent('MapImage') as TCastleImageControl;
  Duration := PlayPanel.DesignedComponent('Duration') as TCastleLabel;
  ModeIcons := PlayPanel.DesignedComponent('ModeIcons') as TCastleHorizontalGroup;
  SearchBtn := PlayPanel.DesignedComponent('SearchBtn') as TCastleButton;
  SearchBtn.OnPress := @OnSearchPress;

  FSoloFrame := PlayPanel.DesignedComponent('SoloFrame') as TCastleImageControl;
  FPartyFrame := PlayPanel.DesignedComponent('PartyFrame') as TCastleImageControl;
  SI := PlayPanel.DesignedComponent('SoloIcon') as TCastleImageControl;
  SI.OnPress := @OnSoloClick;
  PI := PlayPanel.DesignedComponent('PartyIcon') as TCastleImageControl;
  PI.OnPress := @OnPartyClick;

  if FMatchmakingSystem <> nil then
  begin
    UpdatePartySizeUI;
    case FMatchmakingSystem.State of
      msIdle:     SearchBtn.Caption := 'SEARCH';
      msPending:  SearchBtn.Caption := '...';
      msSearching: SearchBtn.Caption := 'CANCEL';
    end;
  end;

  GlobalClientEventBus.Subscribe(cgeMatchmakingStateChanged, @OnMMState);
end;

procedure TViewPlay.Stop;
begin
  GlobalClientEventBus.Unsubscribe(@OnMMState);
  inherited;
end;

procedure TViewPlay.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
end;

procedure TViewPlay.OnSearchPress(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if FMatchmakingSystem = nil then Exit;
  case FMatchmakingSystem.State of
    msIdle:      FMatchmakingSystem.Enqueue;
    msPending:   ;
    msSearching: FMatchmakingSystem.Dequeue;
  end;
  Handled := True;
end;

procedure TViewPlay.OnMMState(const Event: TClientGameEvent);
begin
  if Event.Amount > 0.7 then
    SearchBtn.Caption := 'CANCEL'
  else if Event.Amount > 0.2 then
    SearchBtn.Caption := '...'
  else
    SearchBtn.Caption := 'SEARCH';
end;

procedure TViewPlay.OnSoloClick(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if FMatchmakingSystem = nil then Exit;
  if FMatchmakingSystem.State <> msIdle then Exit;
  FMatchmakingSystem.PartySize := 1;
  UpdatePartySizeUI;
end;

procedure TViewPlay.OnPartyClick(const Sender: TCastleUserInterface;
  const Event: TInputPressRelease; var Handled: Boolean);
begin
  if FMatchmakingSystem = nil then Exit;
  if FMatchmakingSystem.State <> msIdle then Exit;
  FMatchmakingSystem.PartySize := 3;
  UpdatePartySizeUI;
end;

procedure TViewPlay.UpdatePartySizeUI;
begin
  if FMatchmakingSystem = nil then Exit;
  FSoloFrame.Exists := FMatchmakingSystem.PartySize = 1;
  FPartyFrame.Exists := FMatchmakingSystem.PartySize = 3;
end;

end.
