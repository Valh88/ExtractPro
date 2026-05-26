unit JobQueueSystem;

{$mode objfpc}{$H+}

interface

uses
  WorldSystemBase, GameWorld, JobQueue;

type
  TJobQueueSystem = class(TWorldSystemBase)
  public
    procedure Update(const SecondsPassed: Single); override;
  end;

implementation

procedure TJobQueueSystem.Update(const SecondsPassed: Single);
begin
  TJobQueue.Update;
end;

end.
