unit main_unit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, Windows, BGRABitmap, BGRABitmapTypes, frogcard, apputils, LazUTF8, frogchip, Menus, LCLType, IniFiles, singleinst;

type
  TAppItem = record
    Name: string;
    Path: string;
    Icon: string;
    Category: string;
    Line: Integer;
  end;

  { TMainForm }

    TMainForm = class(TForm)
    edtSearch: TEdit;
    imgLogo: TImage;
    imgBackground: TImage;
    lblClock: TLabel;
    lblDate: TLabel;
    lblBrand: TLabel;
    lblVersion: TLabel;
    lblEmpty: TLabel;
    lblTitle: TLabel;
    dlgOpen: TOpenDialog;
    pnlSearchHint: TPanel;
    tmrToast: TTimer;
    tmrClock: TTimer;
    tmrDelete: TTimer;
    tmrResize: TTimer;
    procedure btnAddClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure edtSearchEnter(Sender: TObject);
    procedure edtSearchExit(Sender: TObject);
    procedure edtSearchKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure FormWindowStateChange(Sender: TObject);
    procedure lblTitleDblClick(Sender: TObject);
    procedure pnlSearchHintClick(Sender: TObject);
    procedure tmrClockTimer(Sender: TObject);
    procedure tmrDeleteTimer(Sender: TObject);
    procedure tmrResizeTimer(Sender: TObject);
    procedure tmrToastTimer(Sender: TObject);


  private
    FBgOriginal: TBGRABitmap;
    FBgScaled: TBGRABitmap;
    FApps: array of TAppItem;
    FDeleteIdx: Integer;
    FCategory: string;
    FMenu: TPopupMenu;
    FMenuAction: Integer;
    FAddChip: TFrogChip;
    FSearchBack: TFrogChip;
    FPrevState: TWindowState;
    FFullScreen: Boolean;
    FPrevBounds: TRect;
    FToast: TFrogChip;
    FToastPhase: Integer;
    FToastTicks: Integer;
    FTray: TTrayIcon;
    FTrayMenu: TPopupMenu;
    FBalloonShown: Boolean;
    FQuitting: Boolean;
    procedure ToggleFullScreen;
    procedure LaunchApp(const AppPath: string);
    procedure BuildCards;
    procedure CardClick (Sender: TObject);
    procedure RefreshBackdrop;
    procedure layoutCards;
    procedure LoadApps;
    procedure ClearCards;
    procedure CardMouseDown (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure RemoveApp (idx: Integer);
    procedure ApplyFilter;
    procedure RefreshCategories;
    procedure ChipClick(Sender: TObject);
    procedure BuildMenu;
    procedure MenuChangeCategory(Sender: TObject);
    procedure MenuDelete(Sender: TObject);
    procedure ChangeCategory(idx: Integer);
    function NormalizeCategory(const S: string): string;
    procedure UpdateSearchHint;
    procedure UpdateClock;
    procedure ShowToast (const AText: string);
    procedure ToastClick(Sender: TObject);
    procedure LoadWindowState;
    procedure SaveWindowState;
    procedure BuildTray;
    procedure TrayToggle(Sender: TObject);
    procedure TrayOpen(Sender: TObject);
    procedure TrayExit(Sender: TObject);
    procedure TrayAdd(Sender: TObject);
    procedure ShowTrayBalloon;

  public

  end;

var
  MainForm: TMainForm;

implementation
{$R *.lfm}

const
  CardW = 140;
  CardH = 100;
  Gap = 20;
  SideMargin = 40;
  TopMargin = 240;
  AppVersion = '0.1.0-alpha';

procedure TMainForm.UpdateClock;
const
  Months: array[1..12] of string = ('января', 'февраля', 'Марта', 'Апреля',
    'Мая', 'Июня', 'Июля', 'Августа', 'Сентября', 'Октября', 'Ноября', 'Декабря');
var
  y, m, d: Word;
begin
  lblClock.Caption := FormatDateTime('hh:nn', Now);
  DecodeDate(Date, y, m, d);
  lblDate.Caption := IntToStr(d) + ' ' + Months[m] + ' ' + IntToStr(y);
  layoutCards;

end;

procedure TMainForm.ToastClick(Sender: TObject);
begin
  if (FToastPhase = 1) or (FToastPhase = 2) then
    FToastPhase := 3
end;

procedure TMainForm.UpdateSearchHint;
begin
  pnlSearchHint.Visible := (edtSearch.Text = '') and (not edtSearch.Focused);
end;

procedure TMainForm.BuildMenu;
var
  mi: TMenuItem;
begin
  FMenu := TPopupMenu.Create(Self);

  mi := TMenuItem.Create(FMenu);
  mi.Caption := 'Изменить категорию';
  mi.OnClick := @MenuChangeCategory;
  FMenu.Items.Add(mi);

  mi := TMenuItem.Create(FMenu);
  mi.Caption := 'Удалить';
  mi.Onclick := @MenuDelete;
  FMenu.Items.Add(mi);
end;

procedure TMainForm.ClearCards;
var
  i:Integer;
begin
 for i := ControlCount - 1 downto 0 do
  if Controls[i] is TFrogCard then
    Controls[i].Free;

end;
procedure TMainForm.LaunchApp (const AppPath:string);
var
  res: HINST;
  begin
     res := ShellExecute(0, 'open',PChar (AppPath) , nil, nil, SW_SHOWNORMAL);
   if res <= 32 then
     ShowMessage (ErrorText(Integer(res)));
  end;
procedure TMainForm.BuildCards;
    var
       i:Integer;
       card: TFrogCard;
    begin
     ClearCards;
      for i := 0 to High(FApps) do
      begin
        card := TFrogCard.Create(Self);
        card.Parent := Self;
        card.Tag := i;
        card.CaptionText := FApps[i].Name;
        card.OnClick := @CardClick;
        card.OnMouseDown := @CardMouseDown;
        if FApps[i].Icon <> '' then
      card.LoadImageIcon(ExtractFilePath(Application.ExeName) + 'assets\' + FApps[i].Icon)
    else
      card.LoadIconFrom(FApps[i].Path);
      end;

      RefreshCategories;
      ApplyFilter;
      LayoutCards;
      RefreshBackdrop;
    end;
procedure TMainForm.ApplyFilter;
var
   i: Integer;
   c: TFrogCard;
   q, cat: string;
begin
 q := UTF8LowerCase(Trim(edtSearch.Text));
 cat := UTF8LowerCase(FCategory);

 for i := 0 to ControlCount - 1 do
 if Controls[i] is TFrogCard then
   begin
     c := Controls[i] as TFrogCard;
     c.Visible:= ((q = '') or (Pos(q, UTF8LowerCase(FApps[c.Tag].Name)) > 0))
     and ((cat = '') or (UTF8LowerCase(FApps[c.Tag].Category) = cat));


   end;
end;

procedure TMainForm.RefreshCategories;
var
  cats: TStringList;
  i: Integer;
  chip: TFrogChip;
begin

  for i := ControlCount - 1 downto 0 do
    if (Controls[i] is TFrogChip) and (Controls[i] as TFrogChip).IsCategory then
      Controls[i].Free;

  cats := TStringList.Create;
  try

    cats.Sorted := True;
    cats.Duplicates := dupIgnore;
    for i := 0 to High(FApps) do
      if FApps[i].Category <> '' then
        cats.Add(FApps[i].Category);


    if (FCategory <> '') and (cats.IndexOf(FCategory) < 0) then
      FCategory := '';


    for i := -1 to cats.Count - 1 do
    begin
      chip := TFrogChip.Create(Self);
      chip.Parent := Self;
      chip.IsCategory := True;
      if i < 0 then
        chip.CaptionText := 'Все'
      else
        chip.CaptionText := cats[i];
      chip.Tag := i + 1;
      chip.OnClick := @ChipClick;
      chip.FitWidth;
      if i < 0 then
        chip.Selected := (FCategory = '')
      else
        chip.Selected := (cats[i] = FCategory);
    end;
  finally
    cats.Free;
  end;
end;


procedure TMAinForm.LoadApps;
var
   fileName: string;
   lines: TStringList;
   i, n: Integer;
   rest: string;
begin
 SetLength (FApps, 0);
 fileName := AppsFilePath;
 if not FileExists(fileName) then
   begin
     ShowMessage('Не найден файл со списком программ: ' + fileName);
     Exit;
   end;
 lines := TStringList.Create;
 try
   lines.LoadFromFile(fileName);

   for i := 0 to lines.Count - 1 do
   begin
     rest := Trim(lines[i]);
     if (rest = '' ) or (rest[1]='#') then Continue;

     n:=Length(FApps);
     SetLength(FApps, n+1);
     FApps[n].Line := i;
     FApps[n].Name := Trim(TakePart(rest));
     FApps[n].Path := ResolvePath(Trim(TakePart(rest)));
     FApps[n].Icon := Trim(TakePart(rest));
     FApps[n].Category := Trim(TakePart(rest));

     if (FApps[n].Name = '') or (FApps[n].Path = '') then SetLength(FApps, n);
     end;
   finally
     lines.Free;
   end;
end;
procedure TMainForm.CardClick(Sender: TObject);
begin
  LaunchApp(FApps[(Sender as TComponent).Tag].Path);
end;
procedure TMainForm.CardMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
 if Button <> mbRight then Exit;
 FDeleteIdx := (Sender as TComponent).Tag;
 FMenu.PopUp;
end;
procedure TMainForm.RemoveApp (idx: Integer);
var
   lines: TStringList;
   fileName, s: string;
   ln: Integer;
begin
 if (idx < 0) or (idx > High(FApps)) then Exit;

 if MessageDlg ('Удалить «' + FApps[idx].Name+ '» из Лаунчера? ' + 'Сама программа останется на компьютере.' , mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;

 fileName := AppsFilePath;
 ln := FApps[idx].Line;

 lines := TStringList.Create;
 try
   lines.LoadFromFile(fileName);

   if (ln >= 0) and (ln < lines.Count) then
     begin
       s := Trim(lines[ln]);
       if SameText(Trim(TakePart(s)), FApps[idx].Name) then
         begin
           lines.Delete (ln);
           lines.SaveToFile (fileName);

         end;
     end;
 finally
   lines.Free;
 end;

 LoadApps;
 BuildCards;
end;

procedure TMainForm.RefreshBackdrop;
var
  i: Integer;
begin
  if FBgOriginal = nil then Exit;
  if (ClientWidth < 1) or (ClientHeight < 1) then Exit;

  FreeAndNil(FBgScaled);
  FBgScaled := FBgOriginal.Resample(ClientWidth, ClientHeight) as TBGRABitmap;

  for i := 0 to ControlCount - 1 do
    if Controls[i] is TFrogCard then
    begin
      (Controls[i] as TFrogCard).Backdrop := FBgScaled;
      (Controls[i] as TFrogCard).RebuildGlass;
    end;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  bgFile: string;
  logofile: string;
begin
 FAddChip := TFrogChip.Create(Self);
 FAddChip.Parent := Self;
 FAddChip.CaptionText := '+ Добавить программу';
 FAddChip.FontSize := 13;
 FAddChip.Height := 30;
 FAddChip.Accent := True;
 FAddChip.FitWidth;
 FAddChip.OnClick := @btnAddClick;
 lblTitle.Font.Color := $00B8EFA0;

 FSearchBack := TFrogChip.Create(Self);
 FSearchBack.Parent := Self;
 FSearchBack.CaptionText := '';
 FSearchBack.OnClick := @pnlSearchHintClick;

 edtSearch.BorderStyle := bsNone;
 edtSearch.Color := $00182012;        // тёмно-зелёный, подберёшь на глаз
 edtSearch.Font.Color := clWhite;
 edtSearch.Font.Name := 'Segoe UI';


 edtSearch.Font.Size := 11;
 edtSearch.BringToFront;
 pnlSearchHint.BringToFront;
 edtSearch.TabStop := False;
 pnlSearchHint.Font.Color := $03B4E38F;

  bgFile := ExtractFilePath(Application.ExeName) + 'assets\forest_bg.jpg';
  if FileExists(bgFile) then
    FBgOriginal := TBGRABitmap.Create(bgFile)
  else
    ShowMessage('Не найден фон: ' + bgFile);

  logofile := ExtractFilePath(Application.ExeName) + 'assets\logo.png';
  if FileExists(bgFile) then
    imgLogo.Picture.LoadFromFile(logoFile)
  else
    ShowMessage('Не найден логотип: ' + logoFile);

  lblVersion.Caption := 'v' + AppVersion;

  UpdateClock;
  UpdateSearchHint;
  EnsureAppsFile;
  LoadApps;
  BuildMenu;
  BuildTray;
  BuildCards;
  LoadWindowState;
  ShowToast(GreetingText);
end;

procedure TMainForm.btnAddClick(Sender: TObject);
var
  fileName, title, appsFile: string;
  lines: TStringList;
  i: Integer;
  cat: string;
begin
 if not dlgOpen.Execute then Exit;

 fileName := dlgOpen.FileName;

 for i := 0 to High(FApps) do
   if SameText (FApps[i].Path , fileName) then
   begin;
     ShowMessage (' Эта программа уже в списке ');
     Exit;
   end;

 title := InputBox('Новая программа', 'Название на карточке:' , ChangeFileExt(ExtractFileName(fileName), ''));
 title := StringReplace(title, '|', '', [rfReplaceAll]);
 if Trim(title) = '' then Exit;

 cat := InputBox('Новая программа' , 'Категория :' , '');
 cat := Trim(StringReplace(cat, '|', '', [rfReplaceAll]));

 for i := 0 to High(FApps) do
  if (FApps[i].Category <> '') and
     (UTF8LowerCase(FApps[i].Category) = UTF8LowerCase(cat)) then
    cat := FApps[i].Category;

 appsFile := AppsFilePath;

lines := TstringList.Create;
try
  if FileExists(appsFile) then
    lines.LoadFromFile(appsFile);
  lines.Add(title + '|' + fileName + '||' + cat );
  lines.SaveToFile(appsFile);
finally
  lines.Free;
end;

 LoadApps;
 BuildCards;

end;

function TMainForm.NormalizeCategory(const S: string): string;
var
  i: Integer;
begin
  Result := Trim(StringReplace(S, '|', '', [rfReplaceAll]));
  for i := 0 to High(FApps) do
    if (FApps[i].Category <> '') and (UTF8LowerCase(FApps[i].Category) = UTF8LowerCase(Result)) then
    begin
      Result := FApps[i].Category;
      Exit;
    end;
end;

procedure TMainForm.edtSearchChange(Sender: TObject);
begin
 UpdateSearchHint;
 ApplyFilter;
 LayoutCards;
 tmrResize.Enabled := False;
 tmrResize.Enabled := True;
end;

procedure TMainForm.edtSearchEnter(Sender: TObject);
begin
  UpdateSearchHint;
end;

procedure TMainForm.edtSearchExit(Sender: TObject);
begin
  UpdateSearchHint;
end;

procedure TMainForm.edtSearchKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  i: Integer;
begin
  if (Key <> VK_RETURN) or (Trim(edtSearch.Text) = '') then Exit;
  for i := 0 to ControlCount - 1 do
    begin
      if (Controls[i] is TFrogCard) and (Controls[i].Visible) then
        begin
          LaunchApp(FApps[Controls[i].Tag].Path);
          Key := 0;
          Exit;
        end;
    end;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if FQuitting then
    begin
      if FTray <> nil then FTray.Visible := False;
      SaveWindowState;
    end
    else
    begin
      CloseAction := caNone;
      Hide;
      ShowTrayBalloon;
    end;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
 LayoutCards;
 tmrResize.Enabled := False;
 tmrResize.Enabled := True;
end;

procedure TMainForm.FormWindowStateChange(Sender: TObject);
begin
  if WindowState = wsMinimized then
    begin
      Hide;
      WindowState := wsNormal;
      ShowTrayBalloon;
    end;
end;

procedure TMainForm.lblTitleDblClick(Sender: TObject);
begin
  Hide;
  if FTray <> nil then FTray.Visible := True;
end;

procedure TMainForm.pnlSearchHintClick(Sender: TObject);
begin
  edtSearch.SetFocus;
end;

procedure TMainForm.tmrClockTimer(Sender: TObject);
begin
  UpdateClock;
  if ShowRequested then
    TrayOpen (nil);
end;

procedure TMainForm.tmrDeleteTimer(Sender: TObject);
begin
  tmrDelete.Enabled := False;
  if FMenuAction = 1 then
   ChangeCategory(FDeleteIdx)
  else
    RemoveApp(FDeleteIdx);
end;

procedure TMainForm.tmrResizeTimer(Sender: TObject);
begin
 tmrResize.Enabled := False;
 RefreshBackdrop;

end;

procedure TMainForm.tmrToastTimer(Sender: TObject);
var
  targetTop: Integer;
begin
  targetTop := ClientHeight - FToast.Height - 70;
  case FToastPhase of
    1: begin
      FToast.Top := FToast.Top - 4;
      if FToast.Top <= targetTop then
      begin
        FToast.Top := targetTop;
        FToastPhase := 2;
        FToastTicks := 0;
      end;
    end;
    2: begin
      FToastTicks := FToastTicks + 1;
      if FToastTicks >= 125 then FToastPhase := 3;
    end;
    3: begin
      FToast.Top := FToast.Top + 4;
      if FToast.Top <= -FToast.Height then
      begin
        FToast.Visible := False;
        FToastPhase := 0;
        tmrToast.Enabled := False;
      end;
    end;
    4: begin
      FToastTicks := FToastTicks + 1;
      if FToastTicks >= 15 then
      begin
        FToast.Left := (ClientWidth - FToast.Width) div 2;
        FToast.Top := ClientHeight;      // теперь размер окна уже настоящий
        FToast.Visible := True;
        FToast.BringToFront;
        FToastPhase := 1;
      end;
    end;
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
 FBgScaled.Free;
  FBgOriginal.Free;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_F11 then
  begin
    ToggleFullScreen;
    Key := 0;
  end
  else if (Key = VK_ESCAPE) and FFullScreen and (edtSearch.Text = '') then
  begin
    ToggleFullScreen;
    Key := 0;
  end;
end;

procedure TMainForm.ToggleFullScreen;
begin
  if not FFullScreen then
  begin
    FPrevState := WindowState;       // запоминаем, каким окно было
    WindowState := wsNormal;
    FPrevBounds := BoundsRect;       // и где оно стояло
    BorderStyle := bsNone;           // убираем рамку и заголовок
    BoundsRect := Monitor.BoundsRect; // растягиваем на весь монитор
    FFullScreen := True;
  end
  else
  begin
    BorderStyle := bsSizeable;       // возвращаем рамку
    BoundsRect := FPrevBounds;       // прежнее место и размер
    WindowState := FPrevState;       // и прежнее состояние (обычное или развёрнутое)
    FFullScreen := False;
  end;
end;

procedure TMAinForm.LayoutCards;
var
  i, n, cols, gridW, startX, col, row, k: Integer;
  groupW, groupX: Integer;
  chipW, chipX: Integer;
  c: TFrogCard;
  chip: TFrogChip;
begin
 n := 0;
 for i := 0 to ControlCount - 1 do
   if (Controls[i] is TFrogCard) and (Controls[i].Visible) then
   n := n+1;

 if Length(FApps)=0 then lblEmpty.Caption := 'Список пуст. Нажмите «Добавить программу»'
 else
   lblEmpty.Caption := ('Ничего не найдено');


 cols := (ClientWidth - 2 * SideMargin + Gap) div (CardW + Gap);

 if cols > n then cols := n;
 if cols < 1 then cols := 1;

 gridW := cols * CardW + (cols - 1) * Gap;
 startX := (ClientWidth - gridW) div 2;

 groupW := imgLogo.Width + 16 + lblTitle.Width;
 groupX := (ClientWidth - groupW) div 2;

 imgLogo.Left := groupX;
 imgLogo.Top := 30;

 lblTitle.Left := groupX + imgLogo.Width + 16;
 lblTitle.Top := imgLogo.Top + (imgLogo.Height - lblTitle.Height) div 2;

 if FAddChip <> nil then
 begin
   FAddChip.Left := ClientWidth - FAddChip.Width - 20;
   FAddChip.Top := 20;
 end;

 lblDate.Left := 24;
 lblDate.Top := ClientHeight - lblDate.Height - 20;
 lblDate.Font.Color := $00B0E38F;

 lblClock.Left := 24;
 lblClock.Top := lblDate.Top - lblClock.Height;
 lblClock.Font.Color := $00B0E38F;

 lblBrand.Left := (ClientWidth - lblBrand.Width) div 2;
 lblBrand.Top := ClientHeight - lblBrand.Height - 20;
 lblBrand.Font.Color := $00B0E38F;

 lblVersion.Left := ClientWidth - lblVersion.Width - 24;;
 lblVersion.Top := ClientHeight - lblVersion.Height - 20;
 lblVersion.Font.Color := $00B0E38F;

 if FSearchBack <> nil then
 begin
   FSearchBack.Left := 20;
   FSearchBack.Top := 20;
   FSearchBack.Width := 260;
   FSearchBack.Height := 40;
   edtSearch.Left := FSearchBack.Left + 18;
   edtSearch.Top := FSearchBack.Top + (FSearchBack.Height - edtSearch.Height) div 2;
   edtSearch.Width := FSearchBack.Width - 36;
   pnlSearchHint.SetBounds(edtSearch.Left, edtSearch.Top, edtSearch.Width, edtSearch.Height);
   edtSearch.BringToFront;
   pnlSearchHint.BringToFront;
 end;

 lblEmpty.Left := (ClientWidth - lblEmpty.Width) div 2;
 lblEmpty.Top := TopMargin + 20;
 lblEmpty.Visible := (n = 0);

 if (FToast <> nil) and FToast.Visible then
 begin
   FToast.Left := (ClientWidth - FToast.Width) div 2;
   if FToastPhase = 2 then
     FToast.Top := ClientHeight - FToast.Height - 70;
 end;

 ChipW := 0;
 for i := 0 to ControlCount - 1 do
   if (Controls[i] is TFrogChip) and (Controls[i] as TFrogChip).IsCategory then
     chipW := ChipW + Controls[i].Width + 11;
 ChipX := (ClientWidth - ChipW) div 2;

 for i := 0 to ControlCount - 1 do
   if (Controls[i] is TFrogChip) and (Controls[i] as TFrogChip).IsCategory then
  begin
    chip := Controls[i] as TFrogChip;
    chip.Left := chipX;
    chip.Top := 140;
    chipX := chipX + chip.Width + 11;
  end;

 k := 0;
 for i := 0 to ControlCount - 1 do
   if Controls[i] is TFrogCard then
   begin
     c:= Controls[i] as TFrogCard;
     if c.Visible then
       begin
         col := k mod cols;
         row := k div cols;
         c.SetBounds(startX + col * (CardW+Gap), TopMargin + row * (CardH + Gap), CardW, CardH);
         k := k+1
       end;
   end;
 end;
procedure TMainForm.ChipClick(Sender: TObject);
var
  i: Integer;
begin
  if (Sender as TComponent).Tag = 0 then
    FCategory := ''
  else
    FCategory := (Sender as TFrogChip).CaptionText;

  for i := 0 to ControlCount - 1 do
    if Controls[i] is TFrogChip then
      (Controls[i] as TFrogChip).Selected := (Controls[i] = Sender);

edtSearchChange(Sender);
end;

procedure TMainForm.MenuChangeCategory(Sender: TObject);
begin
  FMenuAction := 1;
  tmrDelete.Enabled := True;
end;

procedure TMainForm.MenuDelete(Sender: TObject);
begin
  FMenuAction := 0;
  tmrDelete.Enabled := True;
end;

procedure TMainForm.ChangeCategory(idx: Integer);
var
  lines: TStringList;
  fileName, s, nm, rawPath, ic, newCat: string;
  ln: Integer;
begin
  if (idx < 0) or (idx > High(FApps)) then
    Exit;

  newCat := InputBox('Категория', 'Новая категория для «' + FApps[idx].Name + '» (пусто = без категории):', FApps[idx].Category);
  newCat := NormalizeCategory(newCat);

  fileName := AppsFilePath;
  ln := FApps[idx].Line;

  lines := TStringList.Create;
  try
    lines.LoadFromFile(fileName);
    if (ln >= 0) and (ln < lines.Count) then
      begin
        s := Trim(lines[ln]);
        nm := TakePart(s);
        rawPath := TakePart(s);
        ic := TakePart(s);
        if SameText(Trim(nm), FApps[idx].Name) then
          begin
            lines[ln] := TrimRight(Nm) + '|' + TrimRight(rawPath) + '|' + TrimRight(ic) + '|' + newCat;
            lines.SaveToFile(fileName);
          end;
      end;
  finally
    lines.Free
  end;

  LoadApps;
  BuildCards;
end;

procedure TMainForm.ShowToast(const AText: string);
begin
  if FToast = nil then
    begin
      FToast := TFrogChip.Create(Self);
      FToast.Parent := Self;
      FToast.Accent := True;
      FToast.FontSize := 20;
      FToast.Height := 64;
      FToast.OnClick := @ToastClick;
    end;
   FToast.CaptionText := AText;
   FToast.FitWidth;
   FToast.Width := FToast.Width + 40;
   FToast.Visible := False;       // пока невидима
   FToastPhase := 4;              // 4 = ждём, пока окно примет окончательный размер
   FToastTicks := 0;
   tmrToast.Enabled := True;
end;

procedure TMainForm.SaveWindowState;
var
  ini: TIniFile;
begin
  if FFullScreen then
    ToggleFullScreen;
  ini := TIniFile.Create(SettingsFilePath);
  try
    ini.WriteBool('Window', 'Maximized', WindowState = wsMaximized);
    if WindowState = wsNormal then
      begin
          ini.WriteInteger('Window', 'Left', Left);
          ini.WriteInteger('Window', 'Top', Top);
          ini.WriteInteger('Window', 'Width', Width);
          ini.WriteInteger('Window', 'Height', Height);
        end;
     finally
       ini.Free;
     end;
  end;

procedure TMainForm.LoadWindowState;
var
  ini: TIniFile;
  l, t, w, h: Integer;
begin
  ini := TIniFile.Create(SettingsFilePath);
  try
    l := ini.ReadInteger('Window', 'Left', 0);
    t := ini.ReadInteger('Window', 'Top', 0);
    w := ini.ReadInteger('Window', 'Width', 0);
    h := ini.ReadInteger('Window', 'Height', 0);
    if (w >= Constraints.MinWidth) and (h >= Constraints.MinHeight) and
       (w >= 100) and (h >= 100) and
       (w <= Screen.DesktopWidth - 100) and
       (h <= Screen.DesktopHeight - 100) then
         begin
           Position := poDesigned;
           SetBounds(l, t, w, h);
         end;
    if ini.ReadBool('Window', 'Maximized', False) then
      WindowState := wsMaximized;
  finally
    ini.Free;
  end;
end;

procedure TMainForm.BuildTray;
var
  mi: TMenuItem;
begin
  FTrayMenu := TPopupMenu.Create(Self);

  mi := TMenuItem.Create(FTrayMenu);
  mi.Caption := 'Развернуть';
  mi.OnClick := @TrayOpen;
  FTrayMenu.Items.Add(mi);

  mi := TMenuItem.Create(FTrayMenu);
  mi.Caption := 'Добавить программу';
  mi.OnClick := @TrayAdd;
  FTrayMenu.Items.Add(mi);

  mi := TMenuItem.Create(FTrayMenu);
  mi.Caption := 'Выход';
  mi.OnClick := @TrayExit;
  FTrayMenu.Items.Add(mi);

  FTray := TTrayIcon.Create(Self);
  FTray.Icon.LoadFromFile('assets/icon.ico');
  //FTray.Icon.Assign(Application.Icon);
  FTray.Hint := 'Frog_Launch v' + AppVersion;
  FTray.PopupMenu := FTrayMenu;
  FTray.OnClick := @TrayToggle;
  FTray.Visible := True;
end;

procedure TMainForm.TrayOpen(Sender: TObject);
begin
  Show;
  if WindowState = wsMinimized then
    WindowState := wsNormal;
  Application.BringToFront;
end;

procedure TMainForm.TrayToggle(Sender: TObject);
begin
  if  Visible and  (WindowState <> wsMinimized) then
    Hide
  else
    TrayOpen(Sender);
end;

procedure TMainForm.TrayExit(Sender: TObject);
begin
  FQuitting := True;
  Close;
end;

procedure TMainForm.TrayAdd(Sender: TObject);
begin
  TrayOpen(Sender);
  btnAddClick(Sender);
end;

procedure TMainForm.ShowTrayBalloon;
begin
  if FBalloonShown or (FTray = nil) then Exit;
  FBalloonShown := True;
  FTray.BalloonTitle := 'Frog_Launch';
  FTray.BalloonHint := 'Frog_Launch продолжает работать в трее';
  FTray.BalloonFlags := bfInfo;
  FTray.BalloonTimeOut := 3000;
  FTray.ShowBalloonHint;
end;

initialization
  if not SingleInstanceOK then
    Halt (0);

end.

