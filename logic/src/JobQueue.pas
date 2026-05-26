unit JobQueue;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses
  SysUtils, Classes, Variants, SyncObjs;

type
  TJobResult = reference to procedure(const Success: Boolean; const Data: Variant);
  TJobProc = reference to procedure(const OnResult: TJobResult);

  TJobTask = class
  public
    Job: TJobProc;
    OnResult: TJobResult;
    Background: Boolean;
    Started: Boolean;
    Done: Boolean;
    ResultSuccess: Boolean;
    ResultData: Variant;
  end;

  TJobCallback = class
  public
    OnResult: TJobResult;
    Success: Boolean;
    Data: Variant;
  end;

  TJobQueue = class
  private
    class var FQueue: TList;
    class var FBackgroundQueue: TList;
    class var FCallbackQueue: TList;
    class var FLock: TCriticalSection;
    class var FInitialized: Boolean;
    class procedure Initialize;
    class procedure ProcessMainQueue;
  public
    class procedure Post(const Job: TJobProc;
      const OnResult: TJobResult = nil;
      Background: Boolean = False);
    class procedure Update;
  end;

implementation

type
  TBackgroundThread = class(TThread)
  private
    FTask: TJobTask;
    procedure QueueCallback(Success: Boolean; const Data: Variant);
  protected
    procedure Execute; override;
  public
    constructor Create(Task: TJobTask);
  end;

constructor TBackgroundThread.Create(Task: TJobTask);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FTask := Task;
end;

procedure TBackgroundThread.QueueCallback(Success: Boolean; const Data: Variant);
var
  cb: TJobCallback;
begin
  cb := TJobCallback.Create;
  cb.OnResult := FTask.OnResult;
  cb.Success := Success;
  cb.Data := Data;
  TJobQueue.FLock.Enter;
  try
    TJobQueue.FCallbackQueue.Add(cb);
  finally
    TJobQueue.FLock.Leave;
  end;
  FTask.Free;
end;

procedure TBackgroundThread.Execute;
begin
  try
    FTask.Job(
      procedure (const Success: Boolean; const Data: Variant)
      begin
        QueueCallback(Success, Data);
      end
    );
  except
    QueueCallback(False, Null);
  end;
end;

{ TJobQueue }

class procedure TJobQueue.Initialize;
begin
  if not FInitialized then
  begin
    FQueue := TList.Create;
    FBackgroundQueue := TList.Create;
    FCallbackQueue := TList.Create;
    FLock := TCriticalSection.Create;
    FInitialized := True;
  end;
end;

class procedure TJobQueue.Post(const Job: TJobProc;
  const OnResult: TJobResult; Background: Boolean);
var
  Task: TJobTask;
begin
  Initialize;
  Task := TJobTask.Create;
  Task.Job := Job;
  Task.OnResult := OnResult;
  Task.Background := Background;

  FLock.Enter;
  try
    if Background then
      FBackgroundQueue.Add(Task)
    else
      FQueue.Add(Task);
  finally
    FLock.Leave;
  end;
end;

class procedure TJobQueue.ProcessMainQueue;
var
  i: Integer;
  Task: TJobTask;
  cb: TJobCallback;
begin
  i := 0;
  while i < FQueue.Count do
  begin
    Task := TJobTask(FQueue[i]);
    if not Task.Started then
    begin
      Task.Started := True;
      Task.Job(
        procedure (const Success: Boolean; const Data: Variant)
        begin
          Task.ResultSuccess := Success;
          Task.ResultData := Data;
          Task.Done := True;
        end
      );
    end;

    if Task.Done then
    begin
      if Assigned(Task.OnResult) then
        Task.OnResult(Task.ResultSuccess, Task.ResultData);
      Task.Free;
      FQueue.Delete(i);
    end
    else
      Inc(i);
  end;

  for i := 0 to FCallbackQueue.Count - 1 do
  begin
    cb := TJobCallback(FCallbackQueue[i]);
    if Assigned(cb.OnResult) then
      cb.OnResult(cb.Success, cb.Data);
    cb.Free;
  end;
  FCallbackQueue.Clear;
end;

class procedure TJobQueue.Update;
var
  i: Integer;
  Task: TJobTask;
begin
  if not FInitialized then Exit;

  FLock.Enter;
  try
    ProcessMainQueue;

    for i := 0 to FBackgroundQueue.Count - 1 do
    begin
      Task := TJobTask(FBackgroundQueue[i]);
      if not Task.Started then
      begin
        Task.Started := True;
        TBackgroundThread.Create(Task);
      end;
    end;
    FBackgroundQueue.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
