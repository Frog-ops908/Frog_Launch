program sait16;
var
  x: integer;
  found: boolean;
begin
  found := false;
  read(x);
  while x <> 0 do
  begin
    if x < 0 then
    begin
      writeln('Первое отрицательное число: ', x);
      found := true;
    end;
    read(x);
  end;
  if not found then
    writeln('Отрицательных чисел нет');
end.