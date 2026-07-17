unit GameViewMarket;

interface

uses Classes,
  CastleVectors, CastleUIControls, CastleControls, CastleKeysMouse;

type
  TViewMarket = class(TCastleView)
  published
    MarketDesign: TCastleDesign;
  public
    MarketBg: TCastleImageControl;
    MarketTitle: TCastleLabel;
    SearchEdit: TCastleEdit;
    FindBtn: TCastleButton;
    ItemsScroll: TCastleScrollView;
    ItemsList: TCastleVerticalGroup;
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
  end;

var
  ViewMarket: TViewMarket;

implementation

constructor TViewMarket.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/views/lobby_view/gameviewmarket.castle-user-interface';
end;

procedure TViewMarket.Start;
begin
  inherited;
  MarketDesign := DesignedComponent('MarketDesign') as TCastleDesign;
  MarketBg := MarketDesign.DesignedComponent('MarketBg') as TCastleImageControl;
  MarketTitle := MarketDesign.DesignedComponent('MarketTitle') as TCastleLabel;
  SearchEdit := MarketDesign.DesignedComponent('SearchEdit') as TCastleEdit;
  FindBtn := MarketDesign.DesignedComponent('FindBtn') as TCastleButton;
  ItemsScroll := MarketDesign.DesignedComponent('ItemsScroll') as TCastleScrollView;
  ItemsList := MarketDesign.DesignedComponent('ItemsList') as TCastleVerticalGroup;
end;

procedure TViewMarket.Stop;
begin
  inherited;
end;

end.
