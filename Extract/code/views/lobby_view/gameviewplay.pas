unit GameViewPlay;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

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
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
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
end;

procedure TViewPlay.Stop;
begin
  inherited;
end;

procedure TViewPlay.Update(const SecondsPassed: Single; var HandleInput: boolean);
begin
  inherited;
  { Executed every frame. }
end;

end.
