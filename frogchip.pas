unit frogchip;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, BGRABitmap, BGRABitmapTypes;

type
  TFrogChip = class(TGraphicControl)
  private
    FCaptionText: string;
    FSelected: Boolean;
    FHover: Boolean;
    FFontSize: Integer;
    FAccent: Boolean;
    FIsCategory: Boolean;
    procedure SetCaptionText(const AValue: string);
    procedure SetSelected(AValue: Boolean);

  protected
    procedure Paint; override;
    procedure MouseEnter; override;
    procedure MouseLeave; override;

  public
    constructor Create(AOwner: TComponent); override;
    procedure FitWidth;
    property CaptionText: string read FCaptionText write SetCaptionText;
    property Selected: Boolean read FSelected write SetSelected;
    property FontSize: Integer read FFontSize write FFontSize;
    property Accent: Boolean read FAccent write FAccent;
    property OnClick;
    property IsCategory: Boolean read FIsCategory write FIsCategory;

  end;

implementation

constructor TFrogChip.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   Width := 80;
   Height := 30;
   Cursor := crHandPoint;
   FFontSize := 10
end;

procedure TFrogChip.SetSelected(AValue: Boolean);
begin
   FSelected := AValue;
   Invalidate;
end;

Procedure TFrogChip.FitWidth;
begin
   Canvas.Font.Name := 'Segoe UI';
   Canvas.Font.Size := FFontSize;
   Width := Canvas.TextWidth(FCaptionText) + 28;
end;

procedure TFrogChip.SetCaptionText(const AValue: string);
begin
  FCaptionText := AValue;
  Invalidate;
end;

procedure TFrogChip.MouseEnter;
begin
   inherited MouseEnter;
   FHover := True;
   Invalidate;
end;

procedure TFrogchip.MouseLeave;
begin
   inherited MouseLeave;
   FHover := False;
   Invalidate;
end;

procedure TFrogChip.Paint;
var
  bmp: TBGRABitmap;
  tw, th: Integer;
  r: Integer;
begin
  bmp := TBGRABitmap.Create(Width, Height, BGRAPixelTransparent);
  r := Height div 2-1;
  try
    if FSelected or FAccent then
      bmp.RoundRectAntialias(1, 1, Width - 2, Height - 2, r, r,
        BGRA(34, 139, 34, 255), 1.5, BGRA(34, 139, 34, 110))
    else if FHover then
      bmp.RoundRectAntialias(1, 1, Width - 2, Height - 2, r, r,
        BGRA(255, 255, 255, 70), 1, BGRA(255, 255, 255, 40))
    else
      bmp.RoundRectAntialias(1, 1, Width - 2, Height - 2, r, r,
        BGRA(255, 255, 255, 40), 1, BGRA(10, 30, 20, 130));
    bmp.Draw(Canvas, 0, 0, False);
  finally
    bmp.Free;
  end;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := 'Segoe UI';   // тот же шрифт, что в FitWidth
  Canvas.Font.Size := FFontSize;
  if FSelected or FAccent then
    Canvas.Font.Color := clWhite
  else
    Canvas.Font.Color := $00D0D0D0;
  tw := Canvas.TextWidth(FCaptionText);
  th := Canvas.TextHeight(FCaptionText);
  Canvas.TextOut((Width - tw) div 2, (Height - th) div 2, FCaptionText);
end;

end.

