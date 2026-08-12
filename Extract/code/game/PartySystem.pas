unit PartySystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, CastleLog,
  GameWorld, WorldSystemBase, ClientEventBus, help_types;

type
  TPartySystem = class(TWorldSystemBase)
  private
    FSubscribed: Boolean;
    FTeamIndex: Byte;
    FMembers: array of TEntityId;
    procedure OnPartyInfo(const Event: TClientGameEvent);
    procedure Subscribe;
    procedure Unsubscribe;
  public
    constructor Create(AWorldObj: TGameWorld);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    function IsInParty: Boolean;
    function HasMember(const AEntityId: TEntityId): Boolean;
    function MemberCount: Integer;
    function GetMember(const AIndex: Integer): TEntityId;
    property TeamIndex: Byte read FTeamIndex;
  end;

implementation

{ TPartySystem }

constructor TPartySystem.Create(AWorldObj: TGameWorld);
begin
  inherited Create(AWorldObj);
  FTeamIndex := 255;
  Subscribe;
end;

destructor TPartySystem.Destroy;
begin
  Unsubscribe;
  inherited;
end;

procedure TPartySystem.Subscribe;
begin
  if FSubscribed then Exit;
  GlobalClientEventBus.Subscribe(cgePartyInfo, @OnPartyInfo);
  FSubscribed := True;
end;

procedure TPartySystem.Unsubscribe;
begin
  if not FSubscribed then Exit;
  GlobalClientEventBus.Unsubscribe(@OnPartyInfo);
  FSubscribed := False;
end;

procedure TPartySystem.OnPartyInfo(const Event: TClientGameEvent);
var
  P: TPartyInfoPayload;
  I: Integer;
  S: string;
begin
  P := TPartyInfoPayload(Event.Data);
  if P = nil then Exit;
  FTeamIndex := P.TeamIndex;
  FMembers := P.Members;
  S := '';
  for I := 0 to High(FMembers) do
    S := S + Format('%d ', [FMembers[I]]);
  WritelnLog('Client', 'PartySystem: team=%d members=%d [%s]',
    [FTeamIndex, Length(FMembers), S]);
end;

function TPartySystem.IsInParty: Boolean;
begin
  Result := Length(FMembers) > 1;
end;

function TPartySystem.HasMember(const AEntityId: TEntityId): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FMembers) do
    if FMembers[I] = AEntityId then
      Exit(True);
  Result := False;
end;

function TPartySystem.MemberCount: Integer;
begin
  Result := Length(FMembers);
end;

function TPartySystem.GetMember(const AIndex: Integer): TEntityId;
begin
  Result := FMembers[AIndex];
end;

procedure TPartySystem.Update(const SecondsPassed: Single);
begin
end;

end.
