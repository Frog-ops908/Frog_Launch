unit frogcard;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Controls, Graphics, ShellAPI,
  BGRABitmap, BGRABitmapTypes;

type
  TFrogCard = class(TGraphicControl)
  private
    FImageIcon: TBGRABitmap;
    FCaptionText: string;
    FBackdrop: TBGRABitmap;   // растянутый фон; он чужой, мы его не освобождаем
    FGlass: TBGRABitmap;      // готовое «стекло» (кэш)
    FGlow: TBGRABitmap;       // подсветка для наведения (кэш)
    FHover: Boolean;
    FIcon: HICON;             // иконка программы (0, если её нет)
    function CanUseBackdrop: Boolean;
    procedure SetCaptionText(const AValue: string);
  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RebuildGlass;
    procedure LoadIconFrom(const APath: string);
    property Backdrop: TBGRABitmap read FBackdrop write FBackdrop;
    property CaptionText: string read FCaptionText write SetCaptionText;
    property OnClick;
    property OnMouseDown;
    procedure LoadImageIcon(const AFile: string);
  end;

implementation

const
  CornerRadius = 10;   // скругление углов
  GlassBlur = 0;       // сила размытия

constructor TFrogCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 140;
  Height := 100;
  Cursor := crHandPoint;
end;

destructor TFrogCard.Destroy;
begin
  FreeAndNil(FGlass);
  FreeAndNil(FGlow);
  FreeAndNil(FImageIcon);
  if FIcon <> 0 then
    DestroyIcon(FIcon);
  inherited Destroy;
end;
procedure TFrogCard.LoadImageIcon(const AFile: string);
var
  src: TBGRABitmap;
begin
  FreeAndNil(FImageIcon);
  if FileExists(AFile) then
    begin
      src := TBGRABitmap.Create(AFile);
      FImageIcon := src.Resample (48, 48) as TBGRABitmap;
      src.Free
    end;
  Invalidate;
end;

procedure TFrogCard.SetCaptionText(const AValue: string);
begin
  FCaptionText := AValue;
  Invalidate;
end;

function TFrogCard.CanUseBackdrop: Boolean;
begin
  // фон можно использовать, если он есть и карточка целиком лежит внутри него
  Result := (FBackdrop <> nil)
    and (Left >= 0) and (Top >= 0)
    and (Left + Width <= FBackdrop.Width)
    and (Top + Height <= FBackdrop.Height);
end;

procedure TFrogCard.RebuildGlass;
var
  part, mask: TBGRABitmap;
begin
  FreeAndNil(FGlass);
  FreeAndNil(FGlow);
  if (Width < 2) or (Height < 2) then
    Exit;

  if CanUseBackdrop then
  begin
    // настоящее «стекло»: вырезка фона, размытие, тонировка, скругление
    part := FBackdrop.GetPart(Rect(Left, Top, Left + Width, Top + Height)) as TBGRABitmap;
    FGlass := part.FilterBlurRadial(GlassBlur, rbNormal) as TBGRABitmap;
    part.Free;
    FGlass.FillRect(0, 0, Width, Height, BGRA(40, 80, 60, 80), dmDrawWithTransparency);

    mask := TBGRABitmap.Create(Width, Height, BGRABlack);
    mask.FillRoundRectAntialias(0, 0, Width - 1, Height - 1,
      CornerRadius, CornerRadius, BGRAWhite);
    FGlass.ApplyMask(mask);
    mask.Free;
    FGlass.RoundRectAntialias(0.5, 0.5, Width - 1.5, Height - 1.5, CornerRadius, CornerRadius, BGRA(255, 255, 255, 60), 1, BGRAPixelTransparent);
  end
  else
  begin
    // упрощённое «стекло»: полупрозрачный скруглённый прямоугольник
    FGlass := TBGRABitmap.Create(Width, Height, BGRAPixelTransparent);
    FGlass.FillRoundRectAntialias(0, 0, Width - 1, Height - 1,
      CornerRadius, CornerRadius, BGRA(10, 30, 20, 150));
  end;

  // подсветка: зелёная рамка #228B22 и лёгкая заливка
  FGlow := TBGRABitmap.Create(Width, Height, BGRAPixelTransparent);
  FGlow.RoundRectAntialias(1, 1, Width - 2, Height - 2,
    CornerRadius, CornerRadius,
    BGRA(10, 30, 20, 130), 2, BGRA(34, 139, 34, 60));

  Invalidate;
end;

procedure TFrogCard.LoadIconFrom(const APath: string);
var
  full: string;
begin
  if FIcon <> 0 then
  begin
    DestroyIcon(FIcon);
    FIcon := 0;
  end;

  full := APath;
  // для коротких имён вроде notepad.exe ищем полный путь в папках из PATH
  if (Pos('\', full) = 0) and (Pos(':', full) = 0) then
    full := FileSearch(APath, GetEnvironmentVariable('PATH'));

  // у сайтов и приложений из магазина файла нет, иконки не будет
  if (full <> '') and FileExists(full) then
    FIcon := ExtractIcon(HInstance, PChar(full), 0);

  if FIcon = 1 then   // 1 значит «в файле нет иконок»
    FIcon := 0;

  Invalidate;
end;

procedure TFrogCard.MouseEnter;
begin
  inherited MouseEnter;
  FHover := True;
  Invalidate;
end;

procedure TFrogCard.MouseLeave;
begin
  inherited MouseLeave;
  FHover := False;
  Invalidate;
  // ЗАДАНИЕ: допиши сам (зеркально MouseEnter)
end;

procedure TFrogCard.Paint;
var
  tw, th: Integer;
begin
  if FGlass <> nil then
    FGlass.Draw(Canvas, 0, 0, False)    // False: учитывать прозрачность
  else
  begin
    Canvas.Brush.Color := $00201A10;
    Canvas.FillRect(0, 0, Width, Height);
  end;

  if FHover and (FGlow <> nil) then
    FGlow.Draw(Canvas, 0, 0, False);

  if FIcon <> 0 then
    DrawIconEx(Canvas.Handle, (Width - 48) div 2, 14, FIcon, 48, 48, 0, 0, DI_NORMAL);
  if FImageIcon <> nil then
    FImageIcon.Draw(Canvas, (Width - 48) div 2, 14, False);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe Print';
  Canvas.Font.Size := 10;
  Canvas.Font.Color := $00B0E38F;
  tw := Canvas.TextWidth(FCaptionText);
  th := Canvas.TextHeight(FCaptionText);
  Canvas.TextOut((Width - tw) div 2, Height - th - 14, FCaptionText);
end;

end.
