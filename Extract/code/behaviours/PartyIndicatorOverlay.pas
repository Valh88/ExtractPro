unit PartyIndicatorOverlay;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  CastleVectors, CastleVectorsInternalSingle, CastleUIControls, CastleControls, CastleViewport, CastleTransform,
  GameWorld, ClientEventBus, help_types, Interfaces;

type
  { Оверлей индикаторов игроков пати. Рисуется поверх 3D-сцены (UI-слой),
    поэтому индикатор всегда одного размера и виден сквозь объекты.
    Подписывается на cgePartyInfo, позиционирует кружки над головами союзников. }
  TPartyIndicatorOverlay = class(TCastleUserInterface)
  private
    FViewport: TCastleViewport;
    FWorld: TGameWorld;
    FSubscribed: Boolean;
    FMembers: array of TEntityId;
    FIndicators: array of TCastleImageControl;
    FIndicatorIds: array of TEntityId;
    procedure OnPartyInfo(const Event: TClientGameEvent);
    procedure Subscribe;
    procedure Unsubscribe;
    procedure RebuildIndicators;
  public
    constructor Create(AOwner: TComponent; AViewport: TCastleViewport; AWorld: TGameWorld);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
  end;

implementation

uses GameWorldClient;

{ TPartyIndicatorOverlay }

constructor TPartyIndicatorOverlay.Create(AOwner: TComponent;
  AViewport: TCastleViewport; AWorld: TGameWorld);
begin
  inherited Create(AOwner);
  FViewport := AViewport;
  FWorld := AWorld;
  FullSize := true;
  Subscribe;
end;

destructor TPartyIndicatorOverlay.Destroy;
begin
  Unsubscribe;
  inherited;
end;

procedure TPartyIndicatorOverlay.Subscribe;
begin
  if FSubscribed then Exit;
  GlobalClientEventBus.Subscribe(cgePartyInfo, @OnPartyInfo);
  FSubscribed := True;
end;

procedure TPartyIndicatorOverlay.Unsubscribe;
begin
  if not FSubscribed then Exit;
  GlobalClientEventBus.Unsubscribe(@OnPartyInfo);
  FSubscribed := False;
end;

procedure TPartyIndicatorOverlay.OnPartyInfo(const Event: TClientGameEvent);
var
  P: TPartyInfoPayload;
begin
  P := TPartyInfoPayload(Event.Data);
  if P = nil then Exit;
  FMembers := P.Members;
  RebuildIndicators;
end;

procedure TPartyIndicatorOverlay.RebuildIndicators;
var
  I: Integer;
  Ind: TCastleImageControl;
  MainId: TEntityId;
begin
  for I := 0 to High(FIndicators) do
    FIndicators[I].Free;
  FIndicators := nil;
  FIndicatorIds := nil;

  MainId := (FWorld as TGameWorldClient).MainPlayerId;
  for I := 0 to High(FMembers) do
  begin
    if FMembers[I] = MainId then
      Continue;
    Ind := TCastleImageControl.Create(Self);
    Ind.Url := 'castle-data:/ui/party_indicator.png';
    Ind.Stretch := True;
    Ind.Width := 10;
    Ind.Height := 10;
    Ind.Exists := True;
    Ind.Translation := Vector2(-100, -100);
    InsertFront(Ind);
    SetLength(FIndicators, Length(FIndicators) + 1);
    FIndicators[High(FIndicators)] := Ind;
    SetLength(FIndicatorIds, Length(FIndicatorIds) + 1);
    FIndicatorIds[High(FIndicatorIds)] := FMembers[I];
  end;
end;

procedure TPartyIndicatorOverlay.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
var
  I: Integer;
  E: IGameEntity;
  Point: CastleVectorsInternalSingle.TGenericVector3;
  ScreenPos: TVector2;
begin
  inherited;
  for I := 0 to High(FIndicators) do
  begin
    if I > High(FIndicatorIds) then
      Break;
    E := FWorld.FindPlayerEntity(FIndicatorIds[I]);
    if (E = nil) or (E.Transform.World = nil) then
    begin
      if E <> nil then
        FIndicators[I].Exists := False;
      Continue;
    end;
    Point := CastleVectorsInternalSingle.TGenericVector3(
      E.Transform.WorldTranslation + Vector3(0, 1.9, 0));
    if FViewport.Camera = nil then
    begin
      FIndicators[I].Exists := False;
      Continue;
    end;
    if FViewport.Camera.Matrix.MultPoint(Point).Z >= 0 then
    begin
      FIndicators[I].Exists := False;
      Continue;
    end;
    ScreenPos := TVector2(FViewport.PositionFromWorld(
      Vector3(Point.X, Point.Y, Point.Z)));
    FIndicators[I].Translation := Vector2(ScreenPos.X - 5, ScreenPos.Y - 5);
    FIndicators[I].Exists := True;
  end;
end;

end.
