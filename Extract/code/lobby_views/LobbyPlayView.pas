unit LobbyPlayView;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TViewLobbyPlay = class(TCastleView)
  published
    LeftPanel: TCastleImageControl;
    ModeTitle: TCastleLabel;
    MapImage: TCastleImageControl;
    Duration: TCastleLabel;
    ModeIcons: TCastleHorizontalGroup;
    SoloIcon: TCastleImageControl;
    PartyIcon: TCastleImageControl;
    SearchBtn: TCastleButton;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

constructor TViewLobbyPlay.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/user_interfaces/PlayPanel.castle-user-interface';
end;

end.