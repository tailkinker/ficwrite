unit dcommon;

// Contains the things needed by pretty much every other unit.

interface

uses
  video;
  
type
  TCursor = record
    Paragraph: SizeInt;
    Position: SizeInt;
  end;

const
  BackgroundColour : Cardinal = Blue shl 12;
  TextColour : Cardinal = LightGray shl 8;
  TextColourDim : Cardinal = DarkGray shl 8;
  StatusBackgroundColour : Cardinal = LightGray shl 12;
  StatusTextColour : cardinal = Black shl 8;
  PARAGRAPH_MARKER = #$81;

implementation

end.
