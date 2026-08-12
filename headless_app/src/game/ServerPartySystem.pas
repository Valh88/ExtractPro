unit ServerPartySystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, CastleLog,
  GameWorld, WorldSystemBase, help_types;

type
  TPartyData = record
    TeamIndex: Byte;
    Members: array of TEntityId;
  end;

  TServerPartySystem = class(TWorldSystemBase)
  private
    FParties: array of TPartyData;
  public
    constructor Create(AWorldObj: TGameWorld);
    procedure Update(const SecondsPassed: Single); override;

    procedure SetParties(const AParties: array of TPartyData);
    procedure ResetParties;

    function PartyCount: Integer;
    function GetPartyTeam(const APartyIndex: Integer): Byte;
    function GetPartyMemberCount(const APartyIndex: Integer): Integer;
    function GetPartyMember(const APartyIndex: Integer; const AMemberIndex: Integer): TEntityId;
    function PartyIndexOfEntity(const AEntityId: TEntityId): Integer;
    function IsInSameParty(const AEntityId, BEntityId: TEntityId): Boolean;
  end;

implementation

{ TServerPartySystem }

constructor TServerPartySystem.Create(AWorldObj: TGameWorld);
begin
  inherited Create(AWorldObj);
end;

procedure TServerPartySystem.Update(const SecondsPassed: Single);
begin
end;

procedure TServerPartySystem.SetParties(const AParties: array of TPartyData);
var
  i: Integer;
begin
  FParties := nil;
  SetLength(FParties, Length(AParties));
  for i := 0 to High(AParties) do
    FParties[i] := AParties[i];
end;

procedure TServerPartySystem.ResetParties;
begin
  FParties := nil;
end;

function TServerPartySystem.PartyCount: Integer;
begin
  Result := Length(FParties);
end;

function TServerPartySystem.GetPartyTeam(const APartyIndex: Integer): Byte;
begin
  if (APartyIndex >= 0) and (APartyIndex < Length(FParties)) then
    Result := FParties[APartyIndex].TeamIndex
  else
    Result := 255;
end;

function TServerPartySystem.GetPartyMemberCount(const APartyIndex: Integer): Integer;
begin
  if (APartyIndex >= 0) and (APartyIndex < Length(FParties)) then
    Result := Length(FParties[APartyIndex].Members)
  else
    Result := 0;
end;

function TServerPartySystem.GetPartyMember(const APartyIndex: Integer; const AMemberIndex: Integer): TEntityId;
begin
  if (APartyIndex >= 0) and (APartyIndex < Length(FParties)) and
     (AMemberIndex >= 0) and (AMemberIndex < Length(FParties[APartyIndex].Members)) then
    Result := FParties[APartyIndex].Members[AMemberIndex]
  else
    Result := 0;
end;

function TServerPartySystem.PartyIndexOfEntity(const AEntityId: TEntityId): Integer;
var
  i, j: Integer;
begin
  for i := 0 to High(FParties) do
    for j := 0 to High(FParties[i].Members) do
      if FParties[i].Members[j] = AEntityId then
        Exit(i);
  Result := -1;
end;

function TServerPartySystem.IsInSameParty(const AEntityId, BEntityId: TEntityId): Boolean;
var
  Pa, Pb: Integer;
begin
  Pa := PartyIndexOfEntity(AEntityId);
  Pb := PartyIndexOfEntity(BEntityId);
  Result := (Pa >= 0) and (Pa = Pb);
end;

end.
