unit WorldTypes;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes, help_types, EntityTypes;

type
  TDungeonRoom = record
    Bounds: TRectangle;
    RoomType: TRoomType;
    Connections: array of Integer;
  end;

  TDungeonRoomArray = array of TDungeonRoom;

  TGameWorldData = record
    Rooms: TDungeonRoomArray;
    Players: array of TPlayerData;
    Enemies: TEnemyArray;
    Items: TItemArray;
    ExtractionPoints: array of TVector2;
    procedure Init;
    procedure Free;
  end;

implementation

{ TGameWorldData }

procedure TGameWorldData.Init;
var
  i: Integer;
begin
  Rooms := nil;
  Players := nil;
  Enemies := nil;
  Items := nil;
  ExtractionPoints := nil;
end;

procedure TGameWorldData.Free;
var
  i: Integer;
begin
  for i := 0 to High(Rooms) do
    Rooms[i].Connections := nil;
  for i := 0 to High(Enemies) do
    Enemies[i].LootTable := nil;
  for i := 0 to High(Players) do
    Players[i].Free;
  Rooms := nil;
  Players := nil;
  Enemies := nil;
  Items := nil;
  ExtractionPoints := nil;
end;

end.
