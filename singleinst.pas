unit singleinst;

{$mode objfpc}{$H+}

interface

function SingleInstanceOK: Boolean;
function ShowRequested: Boolean;

implementation

uses
  Windows;

const
  MutexName = 'Frog_Launch_Single_Mutex';
  EventName = 'Frog_Launch_Show_Event';

var
  hMutex, hEvent: THandle;

function SingleInstanceOK: Boolean;
begin
  HMutex := CreateMutex(nil, False, PChar(MutexName));
  Result := GetLastError <> Error_ALREADY_EXISTS;
  hEvent := CreateEvent(nil, False, False, PChar(EventName));
  if (not Result) and (hEvent <> 0) then
    SetEvent(hEvent);
end;

function ShowRequested: Boolean;
begin
  Result := (hEvent <> 0) and (WaitForSingleObject(hEvent, 0) = WAIT_OBJECT_0);
end;

end.
