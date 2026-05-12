unit ExtractionSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, help_types, EntityTypes, WorldTypes, GameConfig, Interfaces, EventBus,
  WorldSystemBase;

type
  TExtractionSystem = class(TWorldSystemBase)
  public
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

uses GameWorld;

function W(Obj: TObject): TGameWorld;
begin
  Result := Obj as TGameWorld;
end;

procedure TExtractionSystem.Update(const SecondsPassed: Single);
var
  Data: TGameWorldData;
  i: Integer;
  E: TGameEvent;
begin
  Data := W(FWorldObj).Data;
  for i := 0 to High(Data.Players) do
  begin
    if Data.Players[i].Status <> psInRaid then Continue;
    if not Data.Players[i].IsExtracting then Continue;

    Data.Players[i].ExtractionProgress := Data.Players[i].ExtractionProgress +
      SecondsPassed / GlobalConfig.ExtractionTime;

    if Data.Players[i].ExtractionProgress >= 1 then
    begin
      Data.Players[i].Status := psExtracted;
      E.EventType := gePlayerExtracted;
      E.EntityId := Data.Players[i].Id;
      W(FWorldObj).QueueEvent(E);
    end;
  end;
end;

end.
