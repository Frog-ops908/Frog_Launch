unit apputils;

{$mode objfpc}{$H+}

interface

function TakePart(var S: string): string;
function ResolvePath(const APath: string): string;
function GreetingText: string;
function AppsFilePath: string;
procedure EnsureAppsFile;
function ErrorText(code: Integer): string;
function GetCurrentUserName: string;
function SettingsFilePath: string;

implementation

uses
  Classes, SysUtils;

function GetCurrentUserName: string;
begin
  Result := GetEnvironmentVariable ('USERNAME');
end;

function SettingsFilePath: string;
begin
  ForceDirectories(GetAppConfigDir(False));
  Result := GetappConfigDir(False) + 'settings.ini';
end;

function GreetingText: string;
var
  h, m, s, ms: Word;
begin
  DecodeTime(Now, h, m, s, ms);
  if (h >= 5) and (h < 12) then Result := 'Доброе утро, ' + GetCurrentUserName + '!'
  else if (h >=12) and (h <= 16) then Result := 'Добрый день, ' + GetCurrentUserName + '!'
  else if (h >= 17) and (h < 22) then Result := 'Добрый вечер, ' + GetCurrentUserName + '!'
  else Result := 'Доброй ночи, ' + GetCurrentUserName + '!';
end;

 function ErrorText(code: Integer): string;
 begin
   case code of
     2, 3: Result := 'Не найдено';
     5: Result := 'Нет доступа';
     31: Result := 'Нет программы для октрытия этого файла';
   else
     Result := 'Не удалось заупстить программу (код ошибки ' + IntToStr(code) + ').';
   end;
 end;

function AppsFilePath: string;
var
  dir: string;
begin
  dir := GetAppConfigDir (False);
  ForceDirectories(dir);          // создаёт папку, если её ещё нет
  Result := dir + 'apps.txt';
end;

procedure EnsureAppsFile;
var
  newPath, oldPath: string;
  lines: TStringList;
begin
  newPath := AppsFilePath;
  if FileExists(newPath) then Exit;

  oldPath := ExtractFilePath(ParamStr(0)) + 'apps.txt';
  lines := TStringList.Create;
  try
    if FileExists(oldPath) then
      lines.LoadFromFile(oldPath)
    else
      begin
        lines.Add('# Название | Путь | Иконка |');
        lines.Add('Блокнот|notepad.exe|');
        lines.Add('Калькуоятор|calc.exe|');
      end;
      lines.SaveToFile(newPath);
    finally
      lines.Free;
    end;
end;


// откусывает от строки первое поле до '|'
function TakePart(var S: string): string;
var
  p: Integer;
begin
  p := Pos('|', S);
  if p = 0 then
  begin
    Result := S;
    S := '';
  end
  else
  begin
    Result := Copy(S, 1, p - 1);
    Delete(S, 1, p);
  end;
end;

// подставляет значения переменных Windows вместо %Имя%
function ExpandVars(const S: string): string;
const
  Names: array[0..6] of string = ('ProgramFiles', 'ProgramFiles(x86)',
    'ProgramW6432', 'LOCALAPPDATA', 'APPDATA', 'USERPROFILE', 'SystemRoot');
var
  i: Integer;
begin
  Result := S;
  for i := 0 to High(Names) do
    Result := StringReplace(Result, '%' + Names[i] + '%',
      GetEnvironmentVariable(Names[i]), [rfReplaceAll, rfIgnoreCase]);
end;

// из списка вариантов через ';' возвращает первый существующий полный путь.
// Для сайтов и shell: возвращает адрес как есть. Если ничего нет, пустую строку.
function ResolvePath(const APath: string): string;
var
  parts: TStringList;
  i: Integer;
  cand, full: string;
begin
  Result := '';

  if (Pos('http://', LowerCase(APath)) = 1) or (Pos('https://', LowerCase(APath)) = 1)
    or (Pos('shell:', LowerCase(APath)) = 1) then
  begin
    Result := APath;
    Exit;
  end;

  parts := TStringList.Create;
  try
    parts.Delimiter := ';';
    parts.StrictDelimiter := True;
    parts.DelimitedText := APath;

    for i := 0 to parts.Count - 1 do
    begin
      cand := ExpandVars(Trim(parts[i]));
      if cand = '' then Continue;

      if Pos('\', cand) = 0 then
        full := FileSearch(cand, GetEnvironmentVariable('PATH'))
      else
        full := cand;

      if (full <> '') and FileExists(full) then
      begin
        Result := full;
        Exit;
      end;
    end;
  finally
    parts.Free;
  end;
end;

end.
