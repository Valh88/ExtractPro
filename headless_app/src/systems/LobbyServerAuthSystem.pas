unit LobbyServerAuthSystem;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  LobbySystemBase, LobbyWorld, AuthTypes, AuthServer;

type
  TLobbyServerAuthSystem = class(TLobbySystemBase)
  private
    FAuth: TAuthServer;
    FValidator: IAuthValidator;
  public
    constructor Create(ALobbyWorld: TLobbyWorldBase; APort: Word);
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single); override;
    property Validator: IAuthValidator read FValidator;
  end;

implementation

{ TLobbyServerAuthSystem }

constructor TLobbyServerAuthSystem.Create(ALobbyWorld: TLobbyWorldBase; APort: Word);
begin
  inherited Create(ALobbyWorld);
  FAuth := TAuthServer.Create(APort);
  FAuth.Start;
  FValidator := FAuth.Validator;
end;

destructor TLobbyServerAuthSystem.Destroy;
begin
  FValidator := nil;
  FAuth.Stop;
  FAuth.Free;
  inherited;
end;

procedure TLobbyServerAuthSystem.Update(const SecondsPassed: Single);
begin
end;

end.
