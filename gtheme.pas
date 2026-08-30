unit gtheme;

{$mode objfpc}{$H+}
{$MODESWITCH ADVANCEDRECORDS} // Required in objfpc mode

interface

type
  tThemeEntry = record
    TextBackground,
    TextColour : byte;
    function TextAttr : cardinal;
  end;

var
  Normal,
  Dim,
  Block,
  BlockDim,
  Highlight,
  Status,
  StatusHighlight,
  StatusDim,
  Menu,
  MenuHighlight,
  MenuDim,
  Border : tThemeEntry;

const
  themeBlueWhite = 0;
  themeBlackWhite = 1;
  themeWhiteBlack = 2;
  
procedure SetTheme (aTheme : SizeInt);

implementation

const
  // Standard VGA Colors (0-7)
  Black        = 0;
  Blue         = 1;
  Green        = 2;
  Cyan         = 3;
  Red          = 4;
  Magenta      = 5;
  Brown        = 6; // Light Gray / Standard White on low intensity
  LightGray    = 7;
  LightGrey    = 7;

  // High Intensity / Bright VGA Colors (8-15)
  DarkGray     = 8;
  DarkGrey     = 8;
  LightBlue    = 9;
  LightGreen   = 10;
  LightCyan    = 11;
  LightRed     = 12;
  LightMagenta = 13;
  Yellow       = 14; // High-intensity Brown
  White        = 15; // Bright High-intensity White

function tThemeEntry.TextAttr : cardinal;
begin
  Result := (cardinal(TextBackground) shl 12) or (cardinal(TextColour) shl 8);
end;

procedure SetThemeBlueWhite;
begin
  Normal.TextBackground          := Blue;
  Normal.TextColour              := LightGray;

  Dim.TextBackground             := Blue;
  Dim.TextColour                 := DarkGray;

  Block.TextBackground           := LightGray;
  Block.TextColour               := Black;

  BlockDim.TextBackground        := LightGray;
  BlockDim.TextColour            := DarkGray;

  Highlight.TextBackground       := Blue;
  Highlight.TextColour           := Yellow;

  Status.TextBackground          := LightGray;
  Status.TextColour              := Black;

  StatusDim.TextBackground       := LightGray;
  StatusDim.TextColour           := DarkGray;

  StatusHighlight.TextBackground := LightGray;
  StatusHighlight.TextColour     := White;

  Menu.TextBackground            := Blue;
  Menu.TextColour                := LightGray;

  MenuHighlight.TextBackground   := Blue;
  MenuHighlight.TextColour       := White;

  MenuDim.TextBackground         := Blue;
  MenuDim.TextColour             := LightGray;

  Border.TextBackground          := Blue;
  Border.TextColour              := White;
end;

procedure SetTheme (aTheme : SizeInt);
begin
  case aTheme of
    0: SetThemeBlueWhite;
  end;
end;


end.