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
  themeWordPerfect = 0;
  themeTypewriter = 1;
  themeTerminal = 2;
  themeCyberdeck = 3;
  
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

procedure SetThemeWordPerfect;
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

procedure SetThemeTerminal; // Black background, White text (Classic Terminal)
begin
  Normal.TextBackground          := Black;
  Normal.TextColour              := LightGray;

  Dim.TextBackground             := Black;
  Dim.TextColour                 := DarkGray;

  Block.TextBackground           := LightGray;
  Block.TextColour               := Black;

  BlockDim.TextBackground        := LightGray;
  BlockDim.TextColour            := DarkGray;

  Highlight.TextBackground       := Black;
  Highlight.TextColour           := White;

  Status.TextBackground          := LightGray;
  Status.TextColour              := Black;

  StatusDim.TextBackground       := LightGray;
  StatusDim.TextColour           := DarkGray;

  StatusHighlight.TextBackground := LightGray;
  StatusHighlight.TextColour     := White;

  Menu.TextBackground            := Black;
  Menu.TextColour                := LightGray;

  MenuHighlight.TextBackground   := Black;
  MenuHighlight.TextColour       := White;

  MenuDim.TextBackground         := Black;
  MenuDim.TextColour             := DarkGray;

  Border.TextBackground          := Black;
  Border.TextColour              := White;
end;

procedure SetThemeTypewriter; // White/LightGray background, Black text
begin
  Normal.TextBackground          := LightGray; // Max valid 3-bit background
  Normal.TextColour              := Black;

  Dim.TextBackground             := LightGray;
  Dim.TextColour                 := DarkGray;

  Block.TextBackground           := Black;
  Block.TextColour               := White;

  BlockDim.TextBackground        := Black;
  BlockDim.TextColour            := LightGray;

  Highlight.TextBackground       := LightGray;
  Highlight.TextColour           := Blue;

  Status.TextBackground          := Black;     // Fallback to Black for dark status bar
  Status.TextColour              := White;

  StatusDim.TextBackground       := Black;
  StatusDim.TextColour           := LightGray;

  StatusHighlight.TextBackground := Black;
  StatusHighlight.TextColour     := Blue;

  Menu.TextBackground            := LightGray;
  Menu.TextColour                := Black;

  MenuHighlight.TextBackground   := LightGray;
  MenuHighlight.TextColour       := Blue;

  MenuDim.TextBackground         := LightGray;
  MenuDim.TextColour             := DarkGray;

  Border.TextBackground          := LightGray;
  Border.TextColour              := Black;
end;

procedure SetThemeCyberdeck;
begin
  Normal.TextBackground          := Black;
  Normal.TextColour              := LightGray;

  Dim.TextBackground             := Black;
  Dim.TextColour                 := DarkGray;

  Block.TextBackground           := Green;
  Block.TextColour               := Black;

  BlockDim.TextBackground        := Green;
  BlockDim.TextColour            := DarkGray;

  Highlight.TextBackground       := Black;
  Highlight.TextColour           := White;

  Status.TextBackground          := Green;
  Status.TextColour              := Black;

  StatusDim.TextBackground       := Green;
  StatusDim.TextColour           := DarkGray;

  StatusHighlight.TextBackground := Green;
  StatusHighlight.TextColour     := White;

  Menu.TextBackground            := Black;
  Menu.TextColour                := LightGreen;

  MenuHighlight.TextBackground   := Black;
  MenuHighlight.TextColour       := White;

  MenuDim.TextBackground         := Black;
  MenuDim.TextColour             := DarkGray;

  Border.TextBackground          := Black;
  Border.TextColour              := LightGreen;
end;

procedure SetTheme (aTheme : SizeInt);
begin
  case aTheme of
    themeWordPerfect: SetThemeWordPerfect;
    themeTerminal: SetThemeTerminal;
    themeTypewriter: SetThemeTypewriter;
    themeCyberdeck: SetThemeCyberdeck;
  end;
end;


end.